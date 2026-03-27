//
//  Features/Accounts/AccountTreeView.swift
//  AccountTreeView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance
//

import SwiftUI

/**
 Displays a hierarchical chart of accounts for a given ledger.

 `AccountTreeView` binds to an `AccountTreeViewModel` to load, filter, and render
 the full chart of accounts as a collapsible sidebar tree. Each row shows the account
 code, name, type label, kind color dot, and — for non-root accounts — the current
 balance fetched and rolled up by the view model.

 # Features
 - **Hierarchical display**: Uses `List(children:selection:)` to render a fully
   collapsible account tree with disclosure indicators at every level.
 - **Balance column**: Each non-root row shows its current balance. Placeholder
   (parent) balances are automatically rolled up from descendants by
   `AccountTreeViewModel`. The root account balance is intentionally suppressed
   as it aggregates the entire ledger and adds no useful information.
 - **Search/filter**: A `.searchable` modifier filters the tree in real time,
   preserving parent nodes as containers for matching descendants.
 - **Account register**: Double-clicking a non-placeholder leaf account opens its
   register in a dedicated window via `openWindow(value:)`. Placeholder and
   parent nodes are excluded from this action.
 - **Account management**: Create, edit, and organize accounts via toolbar and
   context menu actions that open dedicated form windows.
 - **Automatic refresh**: Observes `.accountSaved` notifications to refresh the
   tree immediately when accounts are created or modified.
 - **Error handling**: Network failures surface as a dismissible alert.
 - **Concurrent loading**: Accounts and balances are fetched concurrently via
   `AccountTreeViewModel.loadAccounts(ledgerID:token:)`.

 # Usage Example

 ```swift
 AccountTreeView(ledger: someLedger)
     .environment(AuthService())
 ```

 # Balance Display Rules

 | Account type        | Balance shown? | Reason                                       |
 |---------------------|----------------|----------------------------------------------|
 | Root (no parent)    | No             | Aggregates whole ledger — omitted for clarity |
 | Placeholder parent  | Yes            | Shows rolled-up subtotal from descendants    |
 | Real leaf account   | Yes            | Shows API-provided balance directly          |

 Negative balances are rendered in red; zero and positive values use the primary
 label color.

 # Register Window Interaction

 Double-clicking any **non-placeholder leaf** opens its register window. The interaction
 is implemented using a `simultaneousGesture(TapGesture(count:2))` so that single-tap
 selection and double-tap window opening do not conflict. The `registerOpenFor` state
 variable acts as a one-shot trigger: it is set on double-tap and immediately cleared
 after `openWindow(value:)` is called.

 # Account Management

 The toolbar provides a "New Account" button that opens an account creation form with
 no pre-selected parent. Context menus on each account row provide:
 - **New Sub-Account**: Opens the account form with the right-clicked account pre-selected
   as the parent via `suggestedParentId`.
 - **Edit Account**: Opens the account form pre-populated with the existing account's data.

 ## Automatic Refresh

 The view observes `Notification.Name.accountSaved` posted by `AccountFormViewModel`
 when accounts are successfully created or updated. When a notification is received
 for the current ledger, the view automatically calls `viewModel.forceReload()` to
 fetch the updated account tree from the backend.

 This ensures that:
 - Newly created accounts appear immediately in the tree
 - Account edits (name, code, parent changes) are reflected without manual refresh
 - The account hierarchy stays synchronized with the backend state

 No user action is required — the tree updates automatically as soon as the account
 form is saved.

 - Important: Requires `AuthService` in the SwiftUI environment to obtain a valid
   bearer token before loading.
 - Note: The `Task.yield()` before `loadAccounts` prevents race conditions when this
   view renders simultaneously with other views that also trigger network requests.
 - SeeAlso: `AccountTreeViewModel`, `AccountRowView`, `AccountRegisterView`,
   `AccountRegisterWindowPayload`, `AccountFormWindowPayload`, `AccountFormViewModel`
 */
struct AccountTreeView: View {

    /// The ledger whose accounts are displayed.
    let ledger: LedgerResponse

    /// Authentication service used to fetch the token for network operations.
    @Environment(AuthService.self) private var auth

    /// View model managing account loading, balance rollup, search filtering,
    /// and error state for the tree.
    @State private var viewModel = AccountTreeViewModel()

    /// The currently selected account node in the tree.
    ///
    /// Used by `List(selection:)` to highlight the selected row. Selection does
    /// not trigger any navigation — only double-clicking a leaf opens its register.
    @State private var selectedAccount: AccountNode?

    /// Tracks the account node that should open its register window.
    ///
    /// Acts as a one-shot trigger: set to a node on double-click, consumed by
    /// `.onChange(of: registerOpenFor)`, then immediately reset to `nil`.
    @State private var registerOpenFor: AccountNode?

    /// Environment action used to open a dedicated account register window.
    ///
    /// Provided by the SwiftUI window management system. Called with an
    /// `AccountRegisterWindowPayload` value that carries the ledger and account.
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        /// Switches between loading, empty, and populated tree states.
        Group {
            if viewModel.isLoading && viewModel.roots.isEmpty {
                ProgressView("Loading accounts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredRoots.isEmpty {
                emptyState
            } else {
                accountTree
            }
        }
        .navigationTitle(ledger.name)
        .searchable(text: $viewModel.searchText, prompt: "Search accounts…")
        // ── Toolbar: New Account button ───────────────────────────────────────
        // Opens account creation form with no pre-selected parent (nil) and no
        // suggested name. User must choose parent from the full account tree picker
        // and provide a name for the new account.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(value: AccountFormWindowPayload(
                        ledger: ledger,
                        existingAccount: nil,
                        suggestedParentId: nil,
                        suggestedName: nil
                    ))
                } label: {
                    Label("New Account", systemImage: "plus")
                }
                .help("Add a new account to this ledger")
            }
        }
        // ─────────────────────────────────────────────────────────────────────
        .task(id: ledger.id) {
            guard let token = auth.token else { return }
            // Small yield to avoid racing with other concurrent tasks
            // that may also trigger on the same view appearance cycle.
            await Task.yield()
            await viewModel.loadAccounts(ledgerID: ledger.id, token: token)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // ── Automatic refresh on account changes ──────────────────────────────
        // Observes notifications posted by AccountFormViewModel when accounts are
        // saved (created or updated). When a notification is received for this
        // ledger, forces a reload to fetch the updated account tree.
        //
        // This ensures that newly created accounts appear immediately, and that
        // edits (name changes, parent moves, etc.) are reflected without requiring
        // manual refresh or app restart.
        .onReceive(NotificationCenter.default.publisher(
            for: .accountSaved
        )) { notification in
            // Only reload if the notification is for this ledger
            guard let savedLedgerID = notification.object as? UUID,
                  savedLedgerID == ledger.id,
                  let token = auth.token else { return }
            Task {
                await viewModel.forceReload(ledgerID: ledger.id, token: token)
            }
        }
    }

    // MARK: - Subviews

    /**
     The hierarchical account list with selection, disclosure, and double-click support.

     Renders `viewModel.filteredRoots` using `List(children:selection:)`, which
     automatically provides disclosure triangles for parent nodes. Each row is an
     `AccountRowView` tagged with its `AccountNode` for selection binding.

     Double-click detection uses `simultaneousGesture(TapGesture(count:2))` so
     single-tap selection and double-tap register opening do not conflict. The
     `.onChange(of: registerOpenFor)` modifier consumes the trigger and calls
     `openRegisterWindow(for:)`, then resets the trigger to `nil`.

     - Note: `\.optionalChildren` returns `nil` for leaf nodes so that no
       disclosure arrow is rendered for accounts with no children.
     */
    private var accountTree: some View {
        List(
            viewModel.filteredRoots,
            id: \.id,
            children: \.optionalChildren,
            selection: $selectedAccount
        ) { node in
            AccountRowView(node: node, balance: viewModel.balances[node.id])
                .tag(node)
                // ── Double-click: open register ───────────────────────────
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        // Only open the register for real leaf accounts.
                        // Placeholder and parent nodes do not have a transaction register.
                        guard !node.isPlaceholder && node.isLeaf else { return }
                        registerOpenFor = node
                    }
                )
                // ── Right-click context menu ──────────────────────────────
                // Provides quick actions for managing account hierarchy:
                // - "New Sub-Account": Pre-selects this node as parent via suggestedParentId,
                //   with no suggested name (user provides name in form)
                // - "Edit Account": Opens form with existing account data for modification,
                //   with no parent pre-selection (parent is determined by existing data)
                .contextMenu {
                    Button {
                        openWindow(value: AccountFormWindowPayload(
                            ledger: ledger,
                            existingAccount: nil,
                            suggestedParentId: node.id,
                            suggestedName: nil
                        ))
                    } label: {
                        Label("New Sub-Account", systemImage: "plus.circle")
                    }

                    Button {
                        openWindow(value: AccountFormWindowPayload(
                            ledger: ledger,
                            existingAccount: AccountFormPayload(node: node),
                            suggestedParentId: nil,
                            suggestedName: nil
                        ))
                    } label: {
                        Label("Edit Account", systemImage: "pencil")
                    }
                }
                // ─────────────────────────────────────────────────────────
        }
        .listStyle(.sidebar)
        .onChange(of: registerOpenFor) { _, newNode in
            guard let node = newNode else { return }
            openRegisterWindow(for: node)
            registerOpenFor = nil
        }
    }

    /**
     Placeholder content shown when the account list is empty or no search results match.

     Displays context-sensitive messaging:
     - When `searchText` is empty: indicates the ledger has no accounts.
     - When `searchText` is non-empty: indicates no accounts match the query.
     */
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            if viewModel.searchText.isEmpty {
                Text("No Accounts")
                    .font(.headline)
                Text("This ledger has no accounts yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No Results")
                    .font(.headline)
                Text("No accounts match \"\(viewModel.searchText)\".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Window Management

    /**
     Opens a new account register window for the given account node.

     Constructs an `AccountRegisterWindowPayload` from the current ledger and
     the provided node, then calls `openWindow(value:)` to present a new window
     via the `WindowGroup` registered in `MyAccountingBooksApp`.

     Multiple register windows can be open simultaneously — one per account.
     SwiftUI deduplicates windows by payload value, so double-clicking the same
     account brings its existing window to the front rather than opening a duplicate.

     - Parameter node: The leaf `AccountNode` whose register should be opened.
     */
    private func openRegisterWindow(for node: AccountNode) {
        openWindow(value: AccountRegisterWindowPayload(
            ledger: ledger,
            account: node
        ))
    }
}

// MARK: - Account Row

/**
 A single row in the account tree representing one account node.

 `AccountRowView` composes four visual elements from left to right:
 1. A color-coded **kind dot** indicating the account's accounting classification.
 2. The optional **account code** in monospaced secondary type.
 3. The **account name** — italic and secondary for placeholders, primary for real accounts.
 4. The **account type code** as a tertiary caption below the name.
 5. The **current balance** right-aligned, shown for all non-root accounts.
 6. An **eye-slash icon** for hidden accounts.

 # Balance Display

 The balance column follows these rules:
 - Suppressed for the root account (`parentId == nil`) since it reflects the entire
   ledger and provides no actionable information.
 - Negative values are rendered in red.
 - Zero and positive values use the primary label color.
 - The number of decimal places is derived from `balanceDenom` (e.g., 100 → 2 places).

 # Kind Color Legend

 | Kind value | Color  | Classification |
 |------------|--------|----------------|
 | 1          | Blue   | Asset          |
 | 2          | Red    | Liability      |
 | 3          | Purple | Equity         |
 | 4          | Green  | Income         |
 | 5          | Orange | Expense        |
 | other      | Gray   | Other / System |

 - SeeAlso: `AccountNode`, `AccountBalanceResponse`, `AccountTreeViewModel.balances`
 */
private struct AccountRowView: View {

    /// The account node to display.
    let node: AccountNode

    /**
     The pre-fetched balance for this account, or `nil` if unavailable.

     Supplied by `AccountTreeViewModel.balances`, which contains both
     API-provided leaf balances and balances rolled up to placeholder parents
     by `AccountTreeViewModel.rollUpBalances(_:)`.

     A `nil` value means the balance map did not include an entry for this account,
     which can occur if the ledger has no transactions yet.
     */
    let balance: AccountBalanceResponse?

    var body: some View {
        HStack(spacing: 10) {
            // Kind indicator dot — color-coded per account classification.
            Circle()
                .fill(kindColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let code = node.code {
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text(node.name)
                        .font(.body)
                        .foregroundStyle(node.isPlaceholder ? .secondary : .primary)
                        .italic(node.isPlaceholder)
                }
                Text(node.accountTypeCode ?? "-")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Balance: suppressed for the root account (parentId == nil) since it
            // aggregates the entire ledger and adds no useful information to the tree.
            if let balance, node.account.parentId != nil {
                Text(formattedBalance(balance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(
                        balance.balanceNum >= 0 ? Color.primary : Color.red
                    )
            }

            if node.isHidden {
                Image(systemName: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Formatting

    /**
     Formats a balance response as a locale-aware numeric string without a currency symbol.

     The number of fraction digits is derived from `balanceDenom`:

     | Denominator | Decimal places | Example output |
     |-------------|----------------|----------------|
     | 1           | 0              | `"1,250"`      |
     | 10          | 1              | `"1,250.0"`    |
     | 100         | 2              | `"1,250.00"`   |
     | 1000        | 3              | `"1,250.000"`  |
     | other       | 2 (default)    | `"1,250.00"`   |

     The currency symbol is intentionally omitted (`code: ""`). The ledger's currency
     is already visible in the navigation subtitle of the parent `AccountTreeView`.

     - Parameter b: The `AccountBalanceResponse` to format.
     - Returns: A locale-formatted decimal string with the appropriate fraction digits.
     */
    private func formattedBalance(_ b: AccountBalanceResponse) -> String {
        let denom = b.balanceDenom
        let decimalPlaces = denom == 1    ? 0
                          : denom == 10   ? 1
                          : denom == 100  ? 2
                          : denom == 1000 ? 3 : 2
        return Decimal.FormatStyle.Currency(code: "")
            .precision(.fractionLength(decimalPlaces))
            .format(b.balance)
    }

    // MARK: - Kind Color

    /**
     Returns the color associated with the account's accounting kind.

     Used by the kind indicator dot to provide an instant visual classification
     without requiring the user to read the account type label.

     - Note: Values 6 (Cost of Sales), 7 (Memorandum), and 8 (Statistical) fall
       through to `.gray` since they are uncommon in personal accounting contexts.
     */
    private var kindColor: Color {
        switch node.account.kind {
        case 1:  return .blue        // Asset
        case 2:  return .red         // Liability
        case 3:  return .purple      // Equity
        case 4:  return .green       // Income
        case 5:  return .orange      // Expense
        default: return .gray
        }
    }
}
