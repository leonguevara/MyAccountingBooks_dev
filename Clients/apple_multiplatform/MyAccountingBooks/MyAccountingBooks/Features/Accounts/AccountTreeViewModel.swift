//
//  Features/Accounts/AccountTreeViewModel.swift
//  AccountTreeViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-03-22.
//  Developed with AI assistance.
//

import Foundation

/**
 View model managing state and business logic for the account tree screen.

 `AccountTreeViewModel` orchestrates the complete lifecycle of the chart of accounts:
 fetching accounts and balances concurrently, assembling the hierarchy, rolling up
 balances to placeholder parent accounts, building GnuCash-style full-path strings
 for account pickers, and providing real-time search/filter capabilities.

 # Responsibilities

 - **Account tree loading**: Fetches a flat account list and builds the hierarchy via
   `AccountTreeBuilder.build(from:)`.
 - **Balance integration**: Fetches leaf balances and maps them to accounts via `BalanceMap`.
 - **Balance rollup**: Recursively computes subtotal balances for placeholder parent
   accounts so that every node in the tree has a displayable balance.
 - **Account path map**: Builds a `[UUID: String]` dictionary of GnuCash-style colon-
   separated paths (e.g., `"Assets:Current Assets:Cash:Checking"`) for use in account
   pickers and search results.
 - **Search / filter**: Returns a search-filtered subtree that preserves parent nodes
   as containers for matching descendants.
 - **Duplicate prevention**: Skips redundant network loads when the same ledger is
   already loaded.
 - **Change notifications**: Responds to `.accountSaved` notifications to refresh
   the tree when accounts are created or modified.
 - **Error handling**: Captures failures in `errorMessage` for display as an alert.

 # Loading Workflow

 ```
 loadAccounts(ledgerID:token:)
   ├─ async let fetchAccounts  ──► AccountService.fetchAccounts
   ├─ async let fetchBalances  ──► AccountService.fetchBalances
   ├─ AccountTreeBuilder.build(from:)          → roots
   ├─ AccountTreeBuilder.buildPathMap(from:)   → accountPaths
   └─ rollUpBalances(_:)                       → balances (updated in-place)
 ```

 # Usage Example

 ```swift
 @State private var viewModel = AccountTreeViewModel()
 @Environment(AuthService.self) private var auth

 var body: some View {
     List(viewModel.filteredRoots, children: \.optionalChildren) { node in
         HStack {
             Text(node.name)
             Spacer()
             if let balanceResponse = viewModel.balances[node.id] {
                 Text(AmountFormatter.format(
                     balanceResponse.balance,
                     currencyCode: ledger.currencyCode,
                     decimalPlaces: ledger.decimalPlaces
                 ))
                 .monospacedDigit()
             }
         }
     }
     .searchable(text: $viewModel.searchText)
     .task(id: selectedLedger.id) {
         guard let token = auth.token else { return }
         await viewModel.loadAccounts(ledgerID: selectedLedger.id, token: token)
     }
     // Refresh when accounts are saved from the account form
     .onReceive(NotificationCenter.default.publisher(for: .accountSaved)) { notification in
         if let savedLedgerId = notification.object as? UUID,
            savedLedgerId == selectedLedger.id {
             Task {
                 guard let token = auth.token else { return }
                 await viewModel.forceReload(ledgerID: savedLedgerId, token: token)
             }
         }
     }
 }
 ```

 # State Summary

 | Property        | Type             | Description                                        |
 |-----------------|------------------|----------------------------------------------------|
 | `roots`         | `[AccountNode]`  | Top-level nodes with full subtree populated        |
 | `balances`      | `BalanceMap`     | API balances + rolled-up parent balances           |
 | `accountPaths`  | `[UUID: String]` | GnuCash-style full path per account (for pickers)  |
 | `searchText`    | `String`         | Current filter query; drives `filteredRoots`       |
 | `isLoading`     | `Bool`           | `true` while network operations are in flight      |
 | `errorMessage`  | `String?`        | Set on failure; `nil` when no error is present     |

 # Refreshing on Account Changes

 When accounts are created or edited via `AccountFormView`, the form's view model
 posts a `.accountSaved` notification with the ledger UUID. Views displaying the
 account tree should observe this notification and call `forceReload(ledgerID:token:)`
 to fetch the updated account structure.

 This ensures that newly created accounts appear immediately in the tree without
 requiring a manual refresh or app restart.

 - Important: All UI-state mutations occur on `@MainActor`. `loadAccounts` must be
   called from a `@MainActor` context (e.g., a SwiftUI `.task` modifier).
 - Note: Uses `loadedLedgerID` to prevent duplicate loads when the same ledger is
   already in memory. A new ledger ID always triggers a full reload. Use `forceReload`
   to bypass this guard when external changes require a refresh.
 - SeeAlso: `AccountTreeBuilder`, `AccountService`, `BalanceMap`, `AccountNode`,
   `forceReload(ledgerID:token:)`, `Notification.Name.accountSaved`
 */
@Observable
final class AccountTreeViewModel {

    // MARK: - State

    /// Root nodes of the account tree hierarchy.
    ///
    /// Contains top-level accounts with all children populated recursively by
    /// `AccountTreeBuilder.build(from:)`. Updated after every successful load.
    var roots: [AccountNode] = []

    /// Indicates whether a network operation is currently in progress.
    ///
    /// Set to `true` at the start of `loadAccounts` and reset to `false` when
    /// the operation completes, whether successfully or with an error.
    var isLoading = false

    /// An optional error message to display when operations fail.
    ///
    /// Set to the localized description of any thrown error during loading.
    /// Cleared to `nil` at the start of each new load attempt.
    var errorMessage: String?

    /// The current search query used to filter the account tree.
    ///
    /// When non-empty, `filteredRoots` returns a filtered subtree. Setting this
    /// to an empty string restores the full unfiltered tree.
    var searchText = ""

    /// Tracks the ledger ID of the most recently completed load to prevent duplicate requests.
    ///
    /// `loadAccounts` compares the incoming `ledgerID` against this value and skips
    /// the network round-trip if they match. Cleared implicitly when a new ledger is loaded.
    private var loadedLedgerID: UUID?

    /// Map of account IDs to their balance responses, including rolled-up parent balances.
    ///
    /// After loading, this map contains two kinds of entries:
    /// - **Leaf accounts**: `AccountBalanceResponse` values sourced directly from the API.
    /// - **Parent accounts**: Synthetic `AccountBalanceResponse` values whose `balanceNum`
    ///   is the recursive sum of all descendant `balanceNum` values.
    ///
    /// Look up a balance by account ID for O(1) access:
    /// ```swift
    /// let balance = viewModel.balances[node.id]?.balance ?? .zero
    /// ```
    ///
    /// - Note: Accounts absent from the map have no recorded balance and should be
    ///   treated as zero.
    var balances: BalanceMap = [:]

    /// GnuCash-style colon-separated full paths for every non-root account.
    ///
    /// Keys are account UUIDs; values are path strings assembled from the account's
    /// ancestor chain, e.g., `"Assets:Current Assets:Cash:Checking"`.
    ///
    /// Populated by `AccountTreeBuilder.buildPathMap(from:)` immediately after the
    /// tree is built. Used by account pickers in `PostTransactionView` to display
    /// unambiguous account labels instead of bare account names.
    ///
    /// ```swift
    /// let label = viewModel.accountPaths[account.id] ?? account.name
    /// ```
    ///
    /// - Note: The structural root account is excluded from the map; its immediate
    ///   children begin paths at depth 1.
    /// - SeeAlso: `AccountTreeBuilder.buildPathMap(from:)`
    var accountPaths: [UUID: String] = [:]

    // MARK: - Dependencies

    /// Service used to fetch accounts and balances from the backend.
    ///
    /// Provides `fetchAccounts(ledgerID:token:)` and `fetchBalances(ledgerID:token:)`.
    private let service = AccountService.shared

    // MARK: - Load

    /**
     Loads accounts and balances for the given ledger, builds the tree, computes
     rolled-up balances, and populates the GnuCash-style path map.

     This method orchestrates the complete loading workflow in five steps:

     1. **Duplicate prevention** — Returns immediately if `ledgerID` matches the
        last successfully loaded ledger.
     2. **Concurrent fetch** — Accounts and balances are requested in parallel via
        `async let` to minimize total latency.
     3. **Tree building** — `AccountTreeBuilder.build(from:)` converts the flat
        account array into a recursive `[AccountNode]` hierarchy stored in `roots`.
     4. **Path map** — `AccountTreeBuilder.buildPathMap(from:)` derives colon-
        separated full-path strings for every account and stores them in `accountPaths`.
     5. **Balance rollup** — `rollUpBalances(_:)` propagates leaf balances upward,
        inserting synthetic `AccountBalanceResponse` entries for all placeholder
        parent accounts.

     # Concurrent Loading

     ```swift
     async let flatAccounts = AccountService.shared.fetchAccounts(ledgerID:token:)
     async let balanceMap   = AccountService.shared.fetchBalances(ledgerID:token:)
     // Both requests are in-flight simultaneously
     roots    = AccountTreeBuilder.build(from: try await flatAccounts)
     balances = try await balanceMap
     ```

     # Balance Rollup

     After the tree is built, parent account balances are computed bottom-up:

     ```
     Assets ($10,000)              ← Rolled up
     ├─ Cash ($3,000)              ← Rolled up
     │  ├─ Checking ($2,000)      ← From API
     │  └─ Savings ($1,000)       ← From API
     └─ Investments ($7,000)      ← From API
     ```

     # Error Handling

     On any thrown error:
     - `errorMessage` is set to `error.localizedDescription`.
     - `isLoading` is reset to `false`.
     - `roots`, `balances`, and `accountPaths` retain their previous values.

     - Parameters:
       - ledgerID: The unique identifier of the ledger whose accounts to load.
       - token: A valid bearer authentication token for authorizing both requests.
     - Important: Must be called from a `@MainActor` context. In SwiftUI, use
       `.task(id: ledger.id)` to automatically re-trigger on ledger changes.
     - Note: Balance rollup and path map generation are automatic — the caller does not
       need to invoke `rollUpBalances` or `buildPathMap` separately.
     - SeeAlso: `rollUpBalances(_:)`, `AccountService.fetchAccounts(ledgerID:token:)`,
       `AccountService.fetchBalances(ledgerID:token:)`, `AccountTreeBuilder.buildPathMap(from:)`
     */
    @MainActor
    func loadAccounts(ledgerID: UUID, token: String) async {
        guard loadedLedgerID != ledgerID else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let flatAccounts = AccountService.shared.fetchAccounts(
                ledgerID: ledgerID, token: token
            )
            async let balanceMap = AccountService.shared.fetchBalances(
                ledgerID: ledgerID, token: token
            )
            roots        = AccountTreeBuilder.build(from: try await flatAccounts)
            accountPaths = AccountTreeBuilder.buildPathMap(from: roots)
            balances     = try await balanceMap

            rollUpBalances(roots)
            loadedLedgerID = ledgerID
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Balance Rollup

    /**
     Entry point for the balance rollup pass.

     Iterates over the top-level nodes and delegates to `computeSubtreeBalance(_:)`
     for any node that has children. Leaf nodes at the root level already have API-
     provided entries in `balances` and are left unchanged.

     Called once by `loadAccounts` after both `roots` and `balances` are populated.

     - Parameter nodes: The root-level `AccountNode` array to process.
     - Note: Mutates `balances` in-place by inserting synthetic `AccountBalanceResponse`
       entries for every parent account in the tree.
     - SeeAlso: `computeSubtreeBalance(_:)`, `firstDenom(in:)`
     */
    private func rollUpBalances(_ nodes: [AccountNode]) {
        for node in nodes {
            guard !node.children.isEmpty else { continue }
            let rolled = computeSubtreeBalance(node)
            let denom = firstDenom(in: node.children) ?? 100
            // Parent placeholders always roll up in base currency.
            // Native currency roll-up is meaningless when children have
            // different commodities, so we reuse the base values.
            balances[node.id] = AccountBalanceResponse(
                accountId:          node.id,
                balanceNum:         rolled,
                balanceDenom:       denom,
                nativeBalanceNum:   rolled,   // same as base for parents
                nativeBalanceDenom: denom
            )
        }
    }

    /**
     Recursively computes the net `balanceNum` for a node's entire subtree and
     stores a synthetic `AccountBalanceResponse` for every parent node visited.

     - **Leaf nodes**: Return the `balanceNum` from `balances`, or `0` if absent.
     - **Parent nodes**: Sum all children recursively, store the result in `balances`,
       then return the sum to the caller.

     The denominator for synthetic entries is taken from the first descendant that
     already has a balance entry, ensuring unit consistency within a subtree.

     - Parameter node: The node whose subtree balance to compute.
     - Returns: The net `balanceNum` for `node` and all its descendants.
     - Note: Marked `@discardableResult` because callers at the root level
       (`rollUpBalances`) only need the side-effect of populating `balances`,
       not the return value.
     - SeeAlso: `rollUpBalances(_:)`, `firstDenom(in:)`
     */
    @discardableResult
    private func computeSubtreeBalance(_ node: AccountNode) -> Int {
        if node.children.isEmpty {
            return balances[node.id]?.balanceNum ?? 0
        }

        let childSum = node.children.reduce(0) { sum, child in
            sum + computeSubtreeBalance(child)
        }

        let denom = firstDenom(in: node.children) ?? 100
        balances[node.id] = AccountBalanceResponse(
            accountId:    node.id,
            balanceNum:   childSum,
            balanceDenom: denom,
            nativeBalanceNum:   childSum,   // parents roll up in base currency
            nativeBalanceDenom: denom
        )

        return childSum
    }

    /**
     Returns the `balanceDenom` of the first node (depth-first) in `nodes` that has
     an entry in `balances`.

     Used to assign a consistent denominator to synthetic parent balance entries when
     building rolled-up values. If no descendant has a balance yet, the caller falls
     back to `100` (the standard 2-decimal-place currency denominator).

     - Parameter nodes: The sibling nodes to search, each with their own subtree.
     - Returns: The denominator from the first matched balance, or `nil` if none found.
     - SeeAlso: `computeSubtreeBalance(_:)`
     */
    private func firstDenom(in nodes: [AccountNode]) -> Int? {
        for node in nodes {
            if let b = balances[node.id] { return b.balanceDenom }
            if let d = firstDenom(in: node.children) { return d }
        }
        return nil
    }

    // MARK: - Filtered Roots

    /**
     Returns the account tree filtered by `searchText`, or the full `roots` array
     when `searchText` is blank.

     Filtering is case-insensitive and matches against `name`, `code`, and
     `accountTypeCode`. Parent nodes that do not match the query themselves are
     preserved as lightweight proxy containers when any of their descendants match.

     ```swift
     List(viewModel.filteredRoots, children: \.optionalChildren) { node in
         Text(node.name)
     }
     .searchable(text: $viewModel.searchText)
     ```

     - Note: Whitespace-only queries are treated as empty and return the full tree.
     - SeeAlso: `filterNodes(_:query:)`
     */
    var filteredRoots: [AccountNode] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return roots
        }
        return filterNodes(roots, query: searchText.lowercased())
    }

    // MARK: - Private Helpers

    /**
     Recursively filters `nodes` against `query`, preserving full subtrees for
     matching nodes and inserting proxy containers for parents of matching descendants.

     Matching is evaluated on three fields (all lowercased before comparison):
     - `node.name`
     - `node.code`
     - `node.accountTypeCode`

     When a node matches, it is included with **all** of its original children intact
     so the user sees the full context of a matching account. When a node does not
     match but has matching descendants, a proxy `AccountNode` is created with only
     the filtered children, acting as a structural breadcrumb in the result tree.

     - Parameters:
       - nodes: The sibling nodes at the current recursion depth.
       - query: The lowercased search string to match against.
     - Returns: A filtered array of `AccountNode` values containing only relevant nodes.
     - SeeAlso: `filteredRoots`
     */
    private func filterNodes(_ nodes: [AccountNode], query: String) -> [AccountNode] {
        var results: [AccountNode] = []
        for node in nodes {
            let matchesSelf = node.name.lowercased().contains(query)
                || (node.code?.lowercased().contains(query) ?? false)
                || (node.accountTypeCode?.lowercased().contains(query) ?? false)

            let filteredChildren = filterNodes(node.children, query: query)

            if matchesSelf {
                results.append(node)
            } else if !filteredChildren.isEmpty {
                let proxy = AccountNode(account: node.account, children: filteredChildren)
                results.append(proxy)
            }
        }
        return results
    }
    
    // MARK: - Force Reload
    
    /**
     Forces a complete reload of accounts and balances, bypassing the duplicate-prevention guard.
     
     This method clears `loadedLedgerID` before calling `loadAccounts(ledgerID:token:)`,
     ensuring that the network request is made even if the same ledger was previously loaded.
     
     ## When to Use
     
     Use `forceReload` when external changes have occurred that require fresh data from
     the backend:
     
     - **Account created**: A new account was added via `AccountFormView`
     - **Account edited**: An existing account's properties were modified
     - **Account deleted**: An account was removed (when deletion is implemented)
     - **Account moved**: An account's parent was changed, affecting the tree structure
     
     ## Normal Loading vs. Force Reload
     
     | Method              | Behavior                                                    |
     |---------------------|-------------------------------------------------------------|
     | `loadAccounts`      | Skips network request if `ledgerID` matches last load       |
     | `forceReload`       | Always performs network request, regardless of last load    |
     
     ## Usage with Notifications
     
     The primary use case is responding to `.accountSaved` notifications posted by
     `AccountFormViewModel` after successfully creating or updating an account:
     
     ```swift
     .onReceive(NotificationCenter.default.publisher(for: .accountSaved)) { notification in
         if let savedLedgerId = notification.object as? UUID,
            savedLedgerId == currentLedger.id {
             Task {
                 guard let token = auth.token else { return }
                 await viewModel.forceReload(ledgerID: savedLedgerId, token: token)
             }
         }
     }
     ```
     
     ## Flow
     
     1. Sets `loadedLedgerID = nil` to clear the duplicate-prevention guard
     2. Calls `loadAccounts(ledgerID:token:)` which now proceeds with the full load
     3. `loadAccounts` resets `loadedLedgerID` to the new ledger ID at the end
     
     ## Example: Manual Refresh Button
     
     ```swift
     ToolbarItem {
         Button {
             Task {
                 guard let token = auth.token else { return }
                 await viewModel.forceReload(ledgerID: ledger.id, token: token)
             }
         } label: {
             Label("Refresh", systemImage: "arrow.clockwise")
         }
     }
     ```
     
     - Parameters:
       - ledgerID: The unique identifier of the ledger to reload
       - token: A valid bearer authentication token
     
     - Note: This method runs on `@MainActor` like `loadAccounts`, ensuring UI updates
       happen on the main thread.
     - SeeAlso: `loadAccounts(ledgerID:token:)`, `Notification.Name.accountSaved`,
       `AccountFormViewModel.save(mode:token:)`
     */
    @MainActor
    func forceReload(ledgerID: UUID, token: String) async {
        loadedLedgerID = nil          // clear the guard
        await loadAccounts(ledgerID: ledgerID, token: token)
    }
}
