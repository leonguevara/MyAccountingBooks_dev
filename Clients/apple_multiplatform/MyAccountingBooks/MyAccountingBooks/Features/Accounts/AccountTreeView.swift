//
//  Features/Accounts/AccountTreeView.swift
//  AccountTreeView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-03-29.
//  Developed with AI assistance
//

import SwiftUI

/// Displays a hierarchical chart of accounts for a given ledger.
///
/// `AccountTreeView` binds to an ``AccountTreeViewModel`` to load, filter, and render
/// the full chart of accounts as a sidebar tree. Each row shows the account
/// code (optional), name, type label, kind color dot, and — for non-root accounts — the
/// current balance fetched and rolled up by the view model.
///
/// ## Features
/// - **Hierarchical display**: Renders a fully collapsible account tree using recursive
///   `DisclosureGroup` views. All parent nodes are **expanded by default** when the tree
///   first loads or when the ledger changes. The user can collapse individual branches;
///   the expansion state is tracked in ``expandedIDs``.
/// - **Balance column**: Each non-root row shows its current balance. Placeholder
///   (parent) balances are automatically rolled up from descendants by
///   ``AccountTreeViewModel``. The root account balance is intentionally suppressed
///   as it aggregates the entire ledger and adds no useful information.
/// - **Search/filter**: A `.searchable` modifier filters the tree in real time,
///   preserving parent nodes as containers for matching descendants.
/// - **Account register**: Double-clicking a non-placeholder leaf account opens its
///   register in a dedicated window via `openWindow(value:)`. Placeholder and
///   parent nodes are excluded from this action.
/// - **Account management**: Create, edit, and organize accounts via toolbar and
///   context menu actions that open dedicated form windows.
/// - **Automatic refresh**: Observes `.accountSaved` notifications to refresh the
///   tree immediately when accounts are created or modified.
/// - **Error handling**: Network failures surface as a dismissible alert.
/// - **Concurrent loading**: Accounts and balances are fetched concurrently via
///   ``AccountTreeViewModel/loadAccounts(ledgerID:token:)``.
///
/// ## Usage Example
///
/// ```swift
/// AccountTreeView(ledger: someLedger)
///     .environment(AuthService())
/// ```
///
/// ## Balance Display Rules
///
/// | Account type        | Balance shown? | Reason                                        |
/// |---------------------|----------------|-----------------------------------------------|
/// | Root (no parent)    | No             | Aggregates whole ledger — omitted for clarity |
/// | Placeholder parent  | Yes            | Shows rolled-up subtotal from descendants     |
/// | Real leaf account   | Yes            | Shows API-provided balance directly           |
///
/// Negative balances are rendered in red; zero and positive values use the primary
/// label color.
///
/// ## Tree Expansion Behaviour
///
/// When the tree loads (or reloads), all parent nodes are automatically expanded by
/// inserting their UUIDs into ``expandedIDs``. Each `DisclosureGroup` is bound to a
/// `Binding<Bool>` that reads and writes this set, so expansion state persists while
/// the view is alive but resets to fully-expanded on the next load.
///
/// The user may collapse any branch manually. Re-selecting a ledger triggers a fresh
/// load, which calls ``expandAll(_:)`` again and restores the fully-expanded state.
///
/// ## Register Window Interaction
///
/// Double-clicking any **non-placeholder leaf** opens its register window. The interaction
/// is implemented using a `simultaneousGesture(TapGesture(count:2))` so that single-tap
/// selection and double-tap window opening do not conflict. The `registerOpenFor` state
/// variable acts as a one-shot trigger: it is set on double-tap and immediately cleared
/// after `openWindow(value:)` is called.
///
/// ## Account Management
///
/// The toolbar provides a "New Account" button that opens an account creation form with
/// no pre-selected parent. Context menus on each account row provide:
/// - **New Sub-Account**: Opens the account form with the right-clicked account pre-selected
///   as the parent via `suggestedParentId`.
/// - **Edit Account**: Opens the account form pre-populated with the existing account's data.
///
/// ### Automatic Refresh
///
/// The view observes `Notification.Name.accountSaved` posted by ``AccountFormViewModel``
/// when accounts are successfully created or updated. When a notification is received
/// for the current ledger, the view automatically calls `viewModel.forceReload()` to
/// fetch the updated account tree from the backend.
///
/// This ensures that:
/// - Newly created accounts appear immediately in the tree
/// - Account edits (name, code, parent changes) are reflected without manual refresh
/// - The account hierarchy stays synchronized with the backend state
///
/// No user action is required — the tree updates automatically as soon as the account
/// form is saved.
///
/// - Important: Requires ``AuthService`` in the SwiftUI environment to obtain a valid
///   bearer token before loading.
/// - Note: The `Task.yield()` before `loadAccounts` prevents race conditions when this
///   view renders simultaneously with other views that also trigger network requests.
/// - SeeAlso: ``AccountTreeViewModel``, ``AccountRowView``, ``AccountRegisterView``,
///   ``AccountRegisterWindowPayload``, ``AccountFormWindowPayload``, ``AccountFormViewModel``
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

    /// Set of node UUIDs whose `DisclosureGroup` is currently expanded.
    ///
    /// Populated by ``expandAll(_:)`` after every tree load, which inserts every
    /// parent node's UUID so all branches start open. The user may collapse
    /// individual branches at any time; tapping the disclosure triangle removes
    /// the UUID from this set. On next load, ``expandAll(_:)`` restores all IDs.
    @State private var expandedIDs: Set<UUID> = []

    /// Environment action used to open dedicated windows (register and form windows).
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
        // Expand all parent nodes whenever the tree loads or reloads.
        // expandAll() inserts every parent UUID into expandedIDs so that
        // all DisclosureGroups open by default. The user may collapse branches.
        .onChange(of: viewModel.roots) { _, newRoots in
            expandAll(newRoots)
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
            guard let savedLedgerID = notification.object as? UUID,
                  savedLedgerID == ledger.id,
                  let token = auth.token else { return }
            Task {
                await viewModel.forceReload(ledgerID: ledger.id, token: token)
            }
        }
    }

    // MARK: - Subviews

    /// The hierarchical account list rendered as a `List` containing recursive
    /// `DisclosureGroup` views.
    ///
    /// All parent nodes are expanded by default via ``expandedIDs``. Each
    /// `DisclosureGroup` is bound to a `Binding<Bool>` that reads/writes the set:
    /// - **Opening** a group inserts its UUID into ``expandedIDs``.
    /// - **Closing** a group removes its UUID from ``expandedIDs``.
    ///
    /// Leaf nodes (accounts with no children) are rendered as plain ``AccountRowView``
    /// rows without a disclosure indicator. Both leaf and parent rows carry a
    /// context menu and — for non-placeholder leaves — a double-tap gesture to open
    /// the account register.
    ///
    /// The `.onChange(of: registerOpenFor)` modifier on the `List` consumes the
    /// one-shot register-open trigger and calls ``openRegisterWindow(for:)``.
    private var accountTree: some View {
        List(selection: $selectedAccount) {
            ForEach(viewModel.filteredRoots) { node in
                accountRow(for: node)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: registerOpenFor) { _, newNode in
            guard let node = newNode else { return }
            openRegisterWindow(for: node)
            registerOpenFor = nil
        }
    }

    /// Recursively renders a single account node as either a collapsible
    /// `DisclosureGroup` (parent with children) or a plain row (leaf).
    ///
    /// **Parent nodes** (nodes with at least one child) render a `DisclosureGroup`
    /// whose expansion state is driven by ``expandedIDs``. The disclosure label is an
    /// ``AccountRowView`` that carries a context menu. Children are rendered by calling
    /// this method recursively for each child node.
    ///
    /// **Leaf nodes** (nodes with no children) render a plain ``AccountRowView`` with:
    /// - A `simultaneousGesture(TapGesture(count: 2))` attached to every leaf.
    ///   The gesture handler applies an additional guard — only **non-placeholder** leaves
    ///   set `registerOpenFor`; placeholder leaves absorb the double-tap silently.
    /// - A context menu for sub-account creation and account editing.
    ///
    /// Both parent and leaf rows carry the same context menu so that "New Sub-Account"
    /// and "Edit Account" are accessible regardless of whether the node has children.
    ///
    /// - Parameter node: The ``AccountNode`` to render.
    /// - Returns: An `AnyView` wrapping either a `DisclosureGroup` (parent) or an ``AccountRowView`` (leaf).
    private func accountRow(for node: AccountNode) -> AnyView {
        if node.children.isEmpty {
            return AnyView(
                AccountRowView(node: node, balance: viewModel.balances[node.id])
                    .tag(node)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            guard !node.isPlaceholder && node.isLeaf else { return }
                            registerOpenFor = node
                        }
                    )
                    .contextMenu { contextMenuItems(for: node) }
            )
        } else {
            return AnyView(
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedIDs.contains(node.id) },
                        set: { isOpen in
                            if isOpen { expandedIDs.insert(node.id) }
                            else      { expandedIDs.remove(node.id) }
                        }
                    )
                ) {
                    ForEach(node.children) { child in
                        accountRow(for: child)
                    }
                } label: {
                    AccountRowView(node: node, balance: viewModel.balances[node.id])
                        .tag(node)
                        .contextMenu { contextMenuItems(for: node) }
                }
            )
        }
    }

    /// Builds the context menu items shared by both leaf and parent account rows.
    ///
    /// Provides two actions:
    /// - **New Sub-Account**: Opens the account form with `suggestedParentId` set to
    ///   this node's UUID so the parent picker is pre-selected.
    /// - **Edit Account**: Opens the account form in edit mode, pre-populated with
    ///   the current node's data via ``AccountFormPayload``.
    ///
    /// - Parameter node: The ``AccountNode`` the menu was invoked on.
    /// - Returns: A `View` containing the two `Button` items.
    @ViewBuilder
    private func contextMenuItems(for node: AccountNode) -> some View {
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

    /// Placeholder content shown when the account list is empty or no search results match.
    ///
    /// Displays context-sensitive messaging:
    /// - When `searchText` is empty: indicates the ledger has no accounts.
    /// - When `searchText` is non-empty: indicates no accounts match the query.
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

    /// Opens a new account register window for the given account node.
    ///
    /// Constructs an ``AccountRegisterWindowPayload`` from the current ledger and
    /// the provided node, then calls `openWindow(value:)` to present a new window
    /// via the `WindowGroup` registered in ``MyAccountingBooksApp``.
    ///
    /// Multiple register windows can be open simultaneously — one per account.
    /// SwiftUI deduplicates windows by payload value, so double-clicking the same
    /// account brings its existing window to the front rather than opening a duplicate.
    ///
    /// - Parameter node: The leaf ``AccountNode`` whose register should be opened.
    private func openRegisterWindow(for node: AccountNode) {
        openWindow(value: AccountRegisterWindowPayload(
            ledger: ledger,
            account: node
        ))
    }

    // MARK: - Expansion

    /// Recursively inserts every parent node's UUID into ``expandedIDs``.
    ///
    /// Called via `.onChange(of: viewModel.roots)` immediately after the account
    /// tree loads. Only nodes with at least one child are inserted — leaf nodes
    /// have no `DisclosureGroup` and do not need an entry in the set.
    ///
    /// This method is safe to call repeatedly: `Set.insert` is idempotent, so
    /// re-inserting an already-present UUID has no effect.
    ///
    /// - Parameter nodes: The array of ``AccountNode`` objects to process
    ///   (top-level roots on the first call; recursed for children).
    private func expandAll(_ nodes: [AccountNode]) {
        for node in nodes {
            if !node.children.isEmpty {
                expandedIDs.insert(node.id)
                expandAll(node.children)
            }
        }
    }
}

// MARK: - Account Row

/// A single row in the account tree representing one account node.
///
/// `AccountRowView` composes six visual elements from left to right:
/// 1. A color-coded **kind dot** indicating the account's accounting classification.
/// 2. The optional **account code** in monospaced secondary type — visibility controlled
///    by ``AppStorageKeys/showAccountCode`` (toggled in ``SettingsView``).
/// 3. The **account name** — italic and secondary for placeholders, primary for real accounts.
/// 4. The **account type code** as a tertiary caption below the name.
/// 5. The **current balance** right-aligned, shown for all non-root accounts.
/// 6. An **eye-slash icon** for hidden accounts.
///
/// ## Balance Display
///
/// The balance column follows these rules:
/// - Suppressed for the root account (`parentId == nil`) since it reflects the entire
///   ledger and provides no actionable information.
/// - Negative values are rendered in red.
/// - Zero and positive values use the primary label color.
/// - The number of decimal places is derived from `balanceDenom` (e.g., 100 → 2 places).
///
/// ## Kind Color Legend
///
/// | Kind value | Color  | Classification |
/// |------------|--------|----------------|
/// | 1          | Blue   | Asset          |
/// | 2          | Red    | Liability      |
/// | 3          | Purple | Equity         |
/// | 4          | Green  | Income         |
/// | 5          | Orange | Expense        |
/// | other      | Gray   | Other / System |
///
/// - SeeAlso: ``AccountNode``, ``AccountBalanceResponse``, ``AccountTreeViewModel``
private struct AccountRowView: View {

    /// Whether the account-code column is visible in each row.
    ///
    /// Mirrors the preference stored under ``AppStorageKeys/showAccountCode``.
    /// Toggled by the user in ``SettingsView``. Changes take effect immediately
    /// across all open COA tree windows without requiring a reload.
    @AppStorage(AppStorageKeys.showAccountCode)
    private var showAccountCode: Bool = true

    /// The account node to display.
    let node: AccountNode

    /// The pre-fetched balance for this account, or `nil` if unavailable.
    ///
    /// Supplied by `AccountTreeViewModel.balances`, which contains both
    /// API-provided leaf balances and balances rolled up to placeholder parents
    /// by `AccountTreeViewModel.rollUpBalances(_:)`.
    ///
    /// A `nil` value means the balance map did not include an entry for this account,
    /// which can occur if the ledger has no transactions yet.
    let balance: AccountBalanceResponse?

    var body: some View {
        HStack(spacing: 10) {
            // Kind indicator dot — color-coded per account classification.
            Circle()
                .fill(kindColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if showAccountCode, let code = node.code {
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

    /// Formats a balance response as a locale-aware numeric string without a currency symbol.
    ///
    /// The number of fraction digits is derived from `balanceDenom`:
    ///
    /// | Denominator | Decimal places | Example output |
    /// |-------------|----------------|----------------|
    /// | 1           | 0              | `"1,250"`      |
    /// | 10          | 1              | `"1,250.0"`    |
    /// | 100         | 2              | `"1,250.00"`   |
    /// | 1000        | 3              | `"1,250.000"`  |
    /// | other       | 2 (default)    | `"1,250.00"`   |
    ///
    /// The currency symbol is intentionally omitted (`code: ""`). The ledger's currency
    /// is already visible in the navigation subtitle of the parent ``AccountTreeView``.
    ///
    /// - Parameter b: The ``AccountBalanceResponse`` to format.
    /// - Returns: A locale-formatted decimal string with the appropriate fraction digits.
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

    /// Returns the color associated with the account's accounting kind.
    ///
    /// Used by the kind indicator dot to provide an instant visual classification
    /// without requiring the user to read the account type label.
    ///
    /// - Note: Values 6 (Cost of Sales), 7 (Memorandum), and 8 (Statistical) fall
    ///   through to `.gray` since they are uncommon in personal accounting contexts.
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
