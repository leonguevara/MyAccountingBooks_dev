//
//  Features/Accounts/AccountTreeViewModel.swift
//  AccountTreeViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

/**
 View model managing state and business logic for the account tree screen with balances.
 
 `AccountTreeViewModel` orchestrates loading accounts and balances, building hierarchical
 structures, computing rolled-up balances for parent accounts, and providing search/filter
 capabilities for the account tree display.
 
 # Features
 - **Account Tree Loading**: Fetches accounts and builds hierarchical structure
 - **Balance Integration**: Loads balances and maps them to accounts
 - **Balance Rollup**: Automatically computes parent account balances from children
 - **Search/Filter**: Provides filtered tree view based on search query
 - **Duplicate Prevention**: Avoids redundant loads when ledger hasn't changed
 - **Error Handling**: Captures and exposes error messages for UI display
 
 # Balance Rollup Algorithm
 
 The view model automatically computes balances for placeholder (parent) accounts:
 1. Leaf accounts use balances from the API
 2. Parent accounts sum all descendant balances recursively
 3. Rolled-up balances are stored in the `balances` map for display
 
 This ensures parent accounts show their total including all child accounts,
 providing accurate subtotals for account categories.
 
 # Usage Example
 
 ```swift
 @State private var viewModel = AccountTreeViewModel()
 @Environment(AuthService.self) private var auth
 
 var body: some View {
     List(viewModel.filteredRoots, children: \.children) { node in
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
 }
 ```
 
 # State Management
 
 - `roots`: Top-level account nodes in the hierarchy
 - `balances`: Map of account IDs to balance responses (includes rolled-up values)
 - `searchText`: Current search query for filtering
 - `filteredRoots`: Computed property returning search-filtered results
 
 - Important: Balances are automatically rolled up to parent accounts after loading.
 - Note: Uses task ID to reload when ledger changes but prevents duplicate loads for same ledger.
 - SeeAlso: `AccountTreeBuilder`, `AccountService`, `BalanceMap`, `AccountNode`
 */
@Observable
final class AccountTreeViewModel {

    // MARK: - State

    /// Root nodes of the account tree hierarchy.
    ///
    /// Contains top-level accounts with all children populated recursively.
    /// Updated after successful account loading and tree building.
    var roots: [AccountNode] = []
    
    /// Indicates whether a network operation is currently in progress.
    ///
    /// Set to `true` during account/balance loading, `false` when complete or on error.
    var isLoading = false
    
    /// An optional error message to display when operations fail.
    ///
    /// Set when network requests fail or tree building encounters issues.
    var errorMessage: String?
    
    /// The current search query used to filter the account tree.
    ///
    /// When non-empty, `filteredRoots` returns a filtered view of the tree.
    /// Cleared to empty string to show full tree.
    var searchText = ""
    
    /// Tracks the last successfully loaded ledger ID to prevent duplicate loads.
    ///
    /// When `loadAccounts` is called with the same ledger ID, the load is skipped.
    private var loadedLedgerID: UUID?
    
    /// Map of account IDs to their balance responses, including rolled-up parent balances.
    ///
    /// This map contains:
    /// - **Leaf accounts**: Balances from the API
    /// - **Parent accounts**: Computed rollup of all descendant balances
    ///
    /// Access balances using account ID for O(1) lookup:
    /// ```swift
    /// if let balance = viewModel.balances[accountID]?.balance {
    ///     // Display balance
    /// }
    /// ```
    var balances: BalanceMap = [:]

    // MARK: - Dependencies

    /// Service used to fetch accounts and balances from the backend.
    ///
    /// Provides methods for retrieving both account structure and balance data.
    private let service = AccountService.shared

    // MARK: - Load

    /**
     Loads accounts and balances for the given ledger, builds the tree, and computes rolled-up balances.
     
     This method orchestrates the complete loading workflow:
     1. **Duplicate prevention**: Skips if ledger was already loaded
     2. **Concurrent fetch**: Loads accounts and balances simultaneously for performance
     3. **Tree building**: Constructs hierarchy from flat account list
     4. **Balance rollup**: Computes parent account balances from children
     5. **State update**: Updates `roots` and `balances` for display
     
     - Parameters:
       - ledgerID: The unique identifier of the ledger whose accounts to load.
       - token: A bearer authentication token for authorizing the requests.
     
     - Throws: Does not throw - errors are captured in `errorMessage` property.
     
     # Concurrent Loading
     
     Accounts and balances are fetched concurrently using async let:
     ```swift
     async let flatAccounts = AccountService.shared.fetchAccounts(...)
     async let balanceMap = AccountService.shared.fetchBalances(...)
     ```
     
     This reduces total load time compared to sequential fetching.
     
     # Balance Rollup
     
     After loading, the method automatically computes balances for parent accounts:
     - **Leaf accounts**: Use balances directly from API
     - **Parent accounts**: Sum all descendant account balances recursively
     
     Example hierarchy with rollup:
     ```
     Assets ($10,000)                     ← Rolled up from children
     ├─ Cash ($3,000)                    ← Rolled up from children
     │  ├─ Checking ($2,000)            ← From API
     │  └─ Savings ($1,000)             ← From API
     └─ Investments ($7,000)            ← From API
     ```
     
     # Duplicate Prevention
     
     The method tracks the last loaded ledger ID. If called again with the same ID,
     the load is skipped to avoid redundant network requests. This is safe when used
     with `.task(id: ledger.id)` which re-triggers only on ledger changes.
     
     # Usage Example
     
     ```swift
     .task(id: selectedLedger.id) {
         guard let token = auth.token else { return }
         await viewModel.loadAccounts(ledgerID: selectedLedger.id, token: token)
     }
     ```
     
     # Error Handling
     
     On failure:
     - `errorMessage` is set with error description
     - `isLoading` returns to `false`
     - Existing `roots` and `balances` remain unchanged
     
     - Important: Must be called from a `@MainActor` context for UI updates.
     - Note: Balance rollup is automatic - parent balances are computed from children.
     - SeeAlso: `rollUpBalances(_:)`, `AccountService.fetchAccounts(ledgerID:token:)`, `AccountService.fetchBalances(ledgerID:token:)`
     */
    @MainActor
    func loadAccounts(ledgerID: UUID, token: String) async {
        guard loadedLedgerID != ledgerID else { return }   // ← prevent duplicate loads
        isLoading = true
        errorMessage = nil
        do {
            // Load accounts and balances concurrently
            async let flatAccounts = AccountService.shared.fetchAccounts(
                ledgerID: ledgerID, token: token
            )
            async let balanceMap = AccountService.shared.fetchBalances(
                ledgerID: ledgerID, token: token
            )
            roots    = AccountTreeBuilder.build(from: try await flatAccounts)
            balances = try await balanceMap

            // Roll up balances to placeholder parents
            rollUpBalances(roots)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Balance Rollup

    /// Entry point: rolls up all balances from leaves to placeholder parents.
    /// Called once after both accounts and balances are loaded.
    private func rollUpBalances(_ nodes: [AccountNode]) {
        for node in nodes {
            guard !node.children.isEmpty else { continue }
            let rolled = computeSubtreeBalance(node)
            // Derive denom from the first descendant that has a balance
            let denom = firstDenom(in: node.children) ?? 100
            balances[node.id] = AccountBalanceResponse(
                accountId:    node.id,
                balanceNum:   rolled,
                balanceDenom: denom
            )
        }
    }

    /// Recursively computes the net balanceNum for a node's entire subtree.
    /// For leaf nodes: returns the value from the API balance map (or 0).
    /// For parent nodes: sums all children recursively, then stores result.
    @discardableResult
    private func computeSubtreeBalance(_ node: AccountNode) -> Int {
        if node.children.isEmpty {
            // Leaf: use the API-provided balance directly
            return balances[node.id]?.balanceNum ?? 0
        }

        // Parent: sum all children
        let childSum = node.children.reduce(0) { sum, child in
            sum + computeSubtreeBalance(child)
        }

        // Store rolled-up balance for this parent node
        let denom = firstDenom(in: node.children) ?? 100
        balances[node.id] = AccountBalanceResponse(
            accountId:    node.id,
            balanceNum:   childSum,
            balanceDenom: denom
        )

        return childSum
    }

    /// Finds the first available balanceDenom from a set of nodes (depth-first).
    private func firstDenom(in nodes: [AccountNode]) -> Int? {
        for node in nodes {
            if let b = balances[node.id] { return b.balanceDenom }
            if let d = firstDenom(in: node.children) { return d }
        }
        return nil
    }

    // MARK: - Filtered Roots

    /// Returns filtered roots when `searchText` has content; otherwise returns `roots`.
    var filteredRoots: [AccountNode] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return roots
        }
        return filterNodes(roots, query: searchText.lowercased())
    }

    // MARK: - Private Helpers

    /// Recursively filters the account tree, preserving full subtrees for matching nodes
    /// and including proxy nodes for parents of matching descendants.
    private func filterNodes(_ nodes: [AccountNode], query: String) -> [AccountNode] {
        var results: [AccountNode] = []
        for node in nodes {
            let matchesSelf = node.name.lowercased().contains(query)
                || (node.code?.lowercased().contains(query) ?? false)
                || (node.accountTypeCode?.lowercased().contains(query) ?? false)

            let filteredChildren = filterNodes(node.children, query: query)

            if matchesSelf {
                // Include node with all its children intact
                results.append(node)
            } else if !filteredChildren.isEmpty {
                // Include node as a container for matching children
                let proxy = AccountNode(account: node.account, children: filteredChildren)
                results.append(proxy)
            }
        }
        return results
    }
}

