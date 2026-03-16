//
//  Features/Accounts/AccountRegisterView.swift
//  AccountRegisterView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import SwiftUI

/// Displays an account register (running balance) for a ledger/account pair.
///
/// Loads transactions, filters to the given account, and renders a register with
/// signed amounts and a running balance. Presents a transaction detail sheet when a
/// row is tapped. Requires `AuthService` in the environment to obtain a token.
///
/// Usage:
/// ```swift
/// AccountRegisterView(ledger: ledger, account: accountNode)
///     .environment(AuthService())
/// ```
struct AccountRegisterView: View {

    /// The ledger that provides currency/decimal context for amounts.
    let ledger: LedgerResponse
    /// The account whose register is displayed.
    let account: AccountNode

    /// Authentication service used to obtain a token for network operations.
    @Environment(AuthService.self) private var auth
    /// View model that loads rows and manages selection/sheet state.
    @State private var viewModel = AccountRegisterViewModel()

    var body: some View {
        /// Switches between loading, empty, and populated register states.
        Group {
            if viewModel.isLoading {
                ProgressView("Loading register…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rows.isEmpty {
                emptyState
            } else {
                registerTable
            }
        }
        .navigationTitle(account.name)
        .navigationSubtitle(
            "\(ledger.name) · \(ledger.currencyCode) · \(account.accountTypeCode ?? "")"
        )
        .toolbar { toolbarContent }
        .task {
            guard let token = auth.token else { return }
            await viewModel.load(ledger: ledger, account: account, token: token)
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
        // Transaction detail sheet
        .sheet(isPresented: $viewModel.showTransactionDetail) {
            if let tx = viewModel.selectedTransaction {
                TransactionDetailSheet(transaction: tx, ledger: ledger)
            }
        }
    }

    /// The register table composed of a header, data rows, and a footer with current balance.
    private var registerTable: some View {
        VStack(spacing: 0) {
            // Column headers
            RegisterHeaderRow(ledger: ledger)

            Divider()

            // Data rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.rows) { row in
                        RegisterDataRow(
                            row: row,
                            ledger: ledger
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedTransaction = row.transaction
                            viewModel.showTransactionDetail = true
                        }
                        .background(
                            viewModel.selectedTransaction?.id == row.transaction.id
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                        )

                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }

            Divider()

            // Footer: current balance
            RegisterFooterRow(
                balance: viewModel.rows.last?.runningBalance ?? .zero,
                ledger: ledger
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    /// Placeholder content shown when the account has no transactions.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Transactions")
                .font(.headline)
            Text("This account has no recorded transactions yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Post Transaction") {
                viewModel.showPostTransaction = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Toolbar actions for posting a new transaction and refreshing the register.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showPostTransaction = true
            } label: {
                Label("Post Transaction", systemImage: "plus")
            }
            .help("Post a new transaction to this account")
        }
        ToolbarItem(placement: .secondaryAction) {
            Button {
                Task {
                    guard let token = auth.token else { return }
                    await viewModel.load(
                        ledger: ledger,
                        account: account,
                        token: token
                    )
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh transactions")
        }
    }
}

/// Column headers for the register table.
private struct RegisterHeaderRow: View {
    let ledger: LedgerResponse

    var body: some View {
        HStack(spacing: 0) {
            Text("Date")
                .frame(width: 90, alignment: .leading)
            Text("Ref #")
                .frame(width: 70, alignment: .leading)
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Amount")
                .frame(width: 110, alignment: .trailing)
            Text("Balance")
                .frame(width: 120, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// A single register row showing date, reference, memo/voided badge, amount, and running balance.
private struct RegisterDataRow: View {
    let row: RegisterRow
    let ledger: LedgerResponse

    var body: some View {
        HStack(spacing: 0) {

            // Date
            Text(AmountFormatter.shortDate(row.transaction.postDate))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            // Reference number
            Text(row.transaction.num.map { "#\($0)" } ?? "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)

            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(row.transaction.memo ?? "No description")
                    .font(.body)
                    .foregroundStyle(row.transaction.isVoided ? .secondary : .primary)
                    .strikethrough(row.transaction.isVoided)
                    .lineLimit(1)

                if row.transaction.isVoided {
                    Text("VOIDED")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Account amount (signed per normal balance)
            Text(formattedAmount)
                .font(.body.monospacedDigit())
                .foregroundStyle(amountColor)
                .frame(width: 110, alignment: .trailing)

            // Running balance
            Text(formattedBalance)
                .font(.body.monospacedDigit())
                .foregroundStyle(balanceColor)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Formats the signed amount for the current account row.
    private var formattedAmount: String {
        AmountFormatter.format(
            row.accountAmount,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    /// Formats the running balance at this row.
    private var formattedBalance: String {
        AmountFormatter.format(
            row.runningBalance,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    /// Color coding for the signed amount (negative amounts are red).
    private var amountColor: Color {
        row.accountAmount >= 0 ? Color.primary : Color.red
    }

    /// Color coding for the running balance (negative balances are red).
    private var balanceColor: Color {
        row.runningBalance >= 0 ? Color.primary : Color.red
    }
}

/// Footer showing the current balance formatted using the ledger's currency context.
private struct RegisterFooterRow: View {
    let balance: Decimal
    let ledger: LedgerResponse

    var body: some View {
        HStack {
            Text("Current Balance")
                .font(.subheadline.bold())
            Spacer()
            Text(AmountFormatter.format(
                balance,
                currencyCode: ledger.currencyCode,
                decimalPlaces: ledger.decimalPlaces
            ))
            .font(.subheadline.bold().monospacedDigit())
            .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Full split detail shown as a sheet inside the register window.
/// Presents the full transaction detail with a Done button to dismiss.
struct TransactionDetailSheet: View {
    let transaction: TransactionResponse
    let ledger: LedgerResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TransactionDetailView(transaction: transaction, ledger: ledger)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 600, minHeight: 480)
    }
}
