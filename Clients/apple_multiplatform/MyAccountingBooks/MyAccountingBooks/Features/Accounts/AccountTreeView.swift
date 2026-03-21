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

/// Displays a hierarchical chart of accounts for a given ledger.
///
/// Binds to an `AccountTreeViewModel` to load and filter accounts, and uses
/// `List(children:selection:)` to render a collapsible tree. Requires an
/// `AuthService` in the environment to obtain the token.
///
/// Each row shows the account name, optional code, type label, and — for
/// non-root accounts — the current balance fetched alongside the account tree.
/// Balances for placeholder (parent) accounts are automatically rolled up from
/// their descendants by the view model.
///
/// Usage:
/// ```swift
/// AccountTreeView(ledger: someLedger)
///     .environment(AuthService())
/// ```
///
/// Notes:
/// - Double-clicking a **non-placeholder leaf** account opens its register in a new window.
///   Placeholder accounts and parent nodes are intentionally excluded from this action.
struct AccountTreeView: View {

    /// The ledger whose accounts are displayed.
    let ledger: LedgerResponse
    /// Authentication service used to fetch the token for network operations.
    @Environment(AuthService.self) private var auth
    /// View model managing loading, filtering, and error state for the tree.
    @State private var viewModel = AccountTreeViewModel()
    /// The currently selected account node in the tree.
    @State private var selectedAccount: AccountNode?

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
        .task(id: ledger.id) {
            guard let token = auth.token else { return }
            // Small yield to avoid racing with other concurrent tasks
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
    }

    // MARK: - Subviews
    
    /// Tracks the account node that should open its register window (set on double-click).
    @State private var registerOpenFor: AccountNode?

    /// The hierarchical account list with selection and disclosure support.
    private var accountTree: some View {
        List(
            viewModel.filteredRoots,
            id: \.id,
            children: \.optionalChildren,
            selection: $selectedAccount
        ) { node in
            AccountRowView(node: node, balance: viewModel.balances[node.id])
                .tag(node)
                /// Double-click handler: open the account register for leaf (non-placeholder) nodes.
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        // Only open the register for real leaf accounts; placeholder
                        // and parent nodes do not have a transaction register.
                        guard !node.isPlaceholder && node.isLeaf else { return }
                        registerOpenFor = node
                    }
                )
        }
        .listStyle(.sidebar)
        // Open a new window for each account register
        .onChange(of: registerOpenFor) { _, newNode in
            guard let node = newNode else { return }
            openRegisterWindow(for: node)
            registerOpenFor = nil
        }
    }

    /// Placeholder content shown when there are no accounts or no search results.
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
    
    // MARK: - Window opener
    /// Environment action used to open a dedicated register window.
    @Environment(\.openWindow) private var openWindow

    /// Opens a new register window for the provided account node using a window value payload.
    private func openRegisterWindow(for node: AccountNode) {
        openWindow(value: AccountRegisterWindowPayload(
            ledger: ledger,
            account: node
        ))
    }
}

// MARK: - Account Row

/// A single row representing an account node with visual indicators.
///
/// Displays a color-coded kind dot, the optional account code, account name,
/// type label, and — when available — the account's current balance. The
/// balance is only shown for non-root accounts (those with a parent).
/// Negative balances are rendered in red; zero and positive balances use the
/// primary label color.
private struct AccountRowView: View {
    let node: AccountNode
    /// The pre-fetched balance for this account, or `nil` if unavailable.
    ///
    /// Supplied by `AccountTreeViewModel.balances` which includes both
    /// API-provided leaf balances and rolled-up parent balances.
    let balance: AccountBalanceResponse?

    var body: some View {
        HStack(spacing: 10) {
            // Kind indicator dot
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

            // Show balance for non-root accounts only; root accounts aggregate
            // the entire ledger and are omitted to reduce visual noise.
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

    /// Formats a balance response as a locale-aware numeric string without a
    /// currency symbol, using the precision implied by `balanceDenom`.
    ///
    /// - Parameter b: The balance response to format.
    /// - Returns: A decimal string (e.g. `"1,250.00"`) with the appropriate
    ///   number of fraction digits derived from the denominator.
    private func formattedBalance(_ b: AccountBalanceResponse) -> String {
        let denom = b.balanceDenom
        let decimalPlaces = denom == 1 ? 0
                          : denom == 10 ? 1
                          : denom == 100 ? 2
                          : denom == 1000 ? 3 : 2
        return Decimal.FormatStyle.Currency(code: "")
            .precision(.fractionLength(decimalPlaces))
            .format(b.balance)
    }

    /// Color coding by account kind (asset, liability, equity, income, expense).
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

