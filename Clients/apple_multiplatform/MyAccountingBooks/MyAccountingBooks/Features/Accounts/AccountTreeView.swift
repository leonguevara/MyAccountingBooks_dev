//
//  Features/Accounts/AccountTreeView.swift
//  AccountTreeView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Developed with AI assistance
//

import SwiftUI

/// Displays a hierarchical chart of accounts for a given ledger.
///
/// Binds to an `AccountTreeViewModel` to load and filter accounts, and uses
/// `List(children:selection:)` to render a collapsible tree. Requires an
/// `AuthService` in the environment to obtain the token.
///
/// Usage:
/// ```swift
/// AccountTreeView(ledger: someLedger)
///     .environment(AuthService())
/// ```
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

    /// The hierarchical account list with selection and disclosure support.
    private var accountTree: some View {
        List(
            viewModel.filteredRoots,
            id: \.id,
            children: \.optionalChildren,
            selection: $selectedAccount
        ) { node in
            AccountRowView(node: node)
                .tag(node)
        }
        .listStyle(.sidebar)
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
}

// MARK: - Account Row

/// A single row representing an account node with visual indicators.
private struct AccountRowView: View {
    let node: AccountNode

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

            if node.isHidden {
                Image(systemName: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
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

