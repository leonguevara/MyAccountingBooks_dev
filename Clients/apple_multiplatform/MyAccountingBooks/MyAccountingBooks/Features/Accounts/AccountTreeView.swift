//
//  Features/Accounts/AccountTreeView.swift
//  AccountTreeView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance
//

import SwiftUI

/// Displays a collapsible, searchable chart-of-accounts tree for a ledger.
///
/// Binds to ``AccountTreeViewModel`` to load accounts and rolled-up balances. Each
/// ``AccountRowView`` shows a kind dot, optional code, name, type code, and balance
/// (suppressed for the root account). All parent nodes expand by default via ``expandedIDs``;
/// the user may collapse branches manually and they restore on the next load. Double-clicking
/// a non-placeholder leaf opens its register window via `openRegisterWindow(for:)`. Reloads
/// automatically on `.accountSaved` and `.transactionPosted` notifications for this ledger.
///
/// - Important: Requires ``AuthService`` in the SwiftUI environment.
/// - Note: `Task.yield()` before `loadAccounts` avoids races with concurrent view-appearance tasks.
/// - SeeAlso: ``AccountTreeViewModel``, ``AccountRowView``, ``AccountRegisterView``,
///   ``AccountFormWindowPayload``, ``AccountFormViewModel``
struct AccountTreeView: View {

    /// The ledger whose accounts are displayed.
    let ledger: LedgerResponse

    /// Authentication service used to fetch the token for network operations.
    @Environment(AuthService.self) private var auth

    /// View model managing account loading, balance rollup, search filtering, and error state.
    @State private var viewModel = AccountTreeViewModel()

    /// Currently selected row in the `List`; selection does not trigger navigation.
    @State private var selectedAccount: AccountNode?

    /// One-shot trigger for opening a register window; set on double-tap, cleared after `openWindow` is called.
    @State private var registerOpenFor: AccountNode?

    /// UUIDs of expanded `DisclosureGroup` nodes; populated by ``expandAll(_:)`` on every tree load.
    @State private var expandedIDs: Set<UUID> = []

    /// Controls presentation of the Reports sheet.
    @State private var showReports = false
    /// Controls presentation of the Exchange Rates (`PriceListView`) sheet.
    @State private var showPrices = false

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
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showReports = true
                } label: {
                    Label("Reports", systemImage: "chart.bar.xaxis")
                }
                .help("View financial reports")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showPrices = true
                } label: {
                    Label("Exchange Rates", systemImage: "arrow.left.arrow.right.circle")
                }
                .help("Manage exchange rates")
            }
        }
        .task(id: ledger.id) {
            guard let token = auth.token else { return }
            await Task.yield()
            await viewModel.loadAccounts(ledgerID: ledger.id, token: token)
        }
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
        .onReceive(NotificationCenter.default.publisher(
            for: .transactionPosted
        )) { notification in
            guard let postedLedgerID = notification.object as? UUID,
                  postedLedgerID == ledger.id,
                  let token = auth.token else { return }
            Task {
                await viewModel.forceReload(ledgerID: ledger.id, token: token)
            }
        }
        .sheet(isPresented: $showReports) {
            ReportsView(
                ledger:   ledger,
                roots:    viewModel.roots,
                balances: viewModel.balances
            )
            .environment(auth)
        }
        .sheet(isPresented: $showPrices) {
            PriceListView(ledger: ledger)
                .environment(auth)
        }
    }

    // MARK: - Subviews

    /// Sidebar `List` of recursive `DisclosureGroup` rows; `.onChange` consumes the `registerOpenFor` trigger.
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

    /// Renders `node` as a `DisclosureGroup` (when it has children) or a plain ``AccountRowView`` (leaf).
    ///
    /// Non-placeholder leaves carry a `simultaneousGesture(TapGesture(count:2))` that sets
    /// `registerOpenFor`; placeholder leaves absorb the double-tap silently. Both parent and
    /// leaf rows share the same context menu.
    ///
    /// - Parameter node: The ``AccountNode`` to render.
    /// - Returns: `AnyView` wrapping a `DisclosureGroup` or an ``AccountRowView``.
    private func accountRow(for node: AccountNode) -> AnyView {
        if node.children.isEmpty {
            return AnyView(
                AccountRowView(node: node, balance: viewModel.balances[node.id], ledger: ledger)
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
                    AccountRowView(node: node, balance: viewModel.balances[node.id], ledger: ledger)
                        .tag(node)
                        .contextMenu { contextMenuItems(for: node) }
                }
            )
        }
    }

    /// Context menu with New Sub-Account (pre-selects `node` as parent) and Edit Account actions.
    ///
    /// - Parameter node: The ``AccountNode`` the menu was invoked on.
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

    /// Opens (or brings to front) the register window for `node` via ``AccountRegisterWindowPayload``.
    ///
    /// - Parameter node: The leaf ``AccountNode`` whose register window to open.
    private func openRegisterWindow(for node: AccountNode) {
        openWindow(value: AccountRegisterWindowPayload(
            ledger: ledger,
            account: node
        ))
    }

    // MARK: - Expansion

    /// Recursively inserts every parent node's UUID into ``expandedIDs``; leaf nodes are skipped.
    ///
    /// - Parameter nodes: Top-level roots on the first call; recurses into children.
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

/// A single row in the account tree: kind dot, optional code, name, type code, balance, and hidden indicator.
///
/// The balance is suppressed for the root account (`parentId == nil`); negative values render in red.
/// The code column visibility is controlled by ``AppStorageKeys/showAccountCode``.
///
/// - SeeAlso: ``AccountNode``, ``AccountBalanceResponse``, ``AccountTreeViewModel``
private struct AccountRowView: View {

    /// Whether the account-code column is visible; mirrors ``AppStorageKeys/showAccountCode`` preference.
    @AppStorage(AppStorageKeys.showAccountCode)
    private var showAccountCode: Bool = true

    /// The account node to display.
    let node: AccountNode

    /// Pre-fetched balance from ``AccountTreeViewModel``; `nil` when no transactions exist yet.
    let balance: AccountBalanceResponse?

    /// The owning ledger; supplies `decimalPlaces` and `currencyCode` for balance formatting.
    let ledger: LedgerResponse

    var body: some View {
        HStack(spacing: 10) {
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
                Text(node.accountTypeCode ?? "SYSTEM")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let balance, node.account.parentId != nil {
                Text(formattedBalance(balance))
                    .font(.body.monospacedDigit())
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

    /// Formats `b.balance` as `"<CODE> <SYMBOL> <AMOUNT>"` using `ledger.decimalPlaces` for precision.
    ///
    /// Uses `NumberFormatter` (not `Decimal.FormatStyle.Currency`) to reliably enforce
    /// `minimumFractionDigits` for zero values.
    ///
    /// - Parameter b: The ``AccountBalanceResponse`` to format.
    /// - Returns: A grouped-decimal string prefixed with the currency code and symbol.
    private func formattedBalance(_ b: AccountBalanceResponse) -> String {
        let decimalPlaces = ledger.decimalPlaces
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.usesGroupingSeparator = true
        let amount = formatter.string(from: b.balance as NSDecimalNumber) ?? "\(b.balance)"
        let symbol = Self.currencySymbol(for: ledger.currencyCode)
        return "\(ledger.currencyCode) \(symbol) \(amount)"
    }

    /// Returns the locale-aware symbol for `code` via `NumberFormatter`; falls back to `code` itself.
    ///
    /// - Parameter code: An ISO 4217 currency code (e.g., `"USD"`, `"MXN"`).
    /// - Returns: The currency symbol, or `code` if unrecognised.
    private static func currencySymbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    // MARK: - Kind Color

    /// Color for the kind indicator dot; kinds 6+ (CostOfSales, Memo, Statistical) fall through to `.gray`.
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
