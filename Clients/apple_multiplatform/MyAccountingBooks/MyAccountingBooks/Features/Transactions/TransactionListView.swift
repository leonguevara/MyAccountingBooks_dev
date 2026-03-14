//
//  Features/Transactions/TransactionListView.swift
//  TransactionListView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-13.
//  Developed with AI assistance.
//

import SwiftUI

/// Displays a list of transactions for a given ledger with loading, empty, and filtered states.
///
/// Binds to a `TransactionListViewModel` to load and filter transactions, supports
/// selection, search, and toggling visibility of voided transactions. Requires an
/// `AuthService` in the environment to obtain the token.
///
/// Usage:
/// ```swift
/// @State private var selectedTx: TransactionResponse?
/// TransactionListView(ledger: someLedger, selectedTransaction: $selectedTx)
///     .environment(AuthService())
/// ```
struct TransactionListView: View {

    /// The ledger whose transactions are displayed.
    let ledger: LedgerResponse
    /// Authentication service used to fetch the token for network operations.
    @Environment(AuthService.self) private var auth
    /// View model managing loading, filtering, and error state for transactions.
    @State private var viewModel = TransactionListViewModel()
    /// The currently selected transaction in the list, bound from a parent view.
    @Binding var selectedTransaction: TransactionResponse?

    var body: some View {
        /// Switches between loading, empty, and populated list states.
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ProgressView("Loading transactions…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTransactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .navigationTitle("Transactions")
        .searchable(text: $viewModel.searchText, prompt: "Search transactions…")
        .toolbar { toolbarContent }
        .task(id: ledger.id) {
            guard let token = auth.token else { return }
            await viewModel.loadTransactions(ledgerID: ledger.id, token: token)
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

    /// The sectioned list of transactions grouped by month with selection support.
    private var transactionList: some View {
        List(selection: $selectedTransaction) {
            ForEach(viewModel.groupedTransactions, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.transactions) { tx in
                        TransactionRowView(
                            transaction: tx,
                            ledger: ledger
                        )
                        .tag(tx)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    /// Placeholder content shown when there are no transactions or no search results.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            if viewModel.searchText.isEmpty {
                Text("No Transactions")
                    .font(.headline)
                Text("This ledger has no transactions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No Results")
                    .font(.headline)
                Text("No transactions match \"\(viewModel.searchText)\".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Toolbar with a toggle to show or hide voided transactions.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $viewModel.showVoided) {
                Label("Show Voided", systemImage: "eye.slash")
            }
            .toggleStyle(.button)
            .help("Show or hide voided transactions")
        }
    }
}

// MARK: - Transaction Row

/// A single row representing a transaction with date, memo, split summary, amount, and voided badge.
private struct TransactionRowView: View {
    let transaction: TransactionResponse
    let ledger: LedgerResponse

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            // Date column
            VStack(alignment: .center, spacing: 2) {
                Text(dayString)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(monthString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36)

            Divider()
                .frame(height: 36)

            // Memo + num
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let num = transaction.num, !num.isEmpty {
                        Text("#\(num)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text(transaction.memo ?? "No description")
                        .font(.body)
                        .foregroundStyle(transaction.isVoided ? .secondary : .primary)
                        .strikethrough(transaction.isVoided)
                        .lineLimit(1)
                }

                // Split summary: show first two account codes/names
                Text(splitSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount + voided badge
            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(transaction.isVoided ? .secondary : .primary)

                if transaction.isVoided {
                    Text("VOIDED")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Derived

    private var dayString: String {
        transaction.postDate.formatted(.dateTime.day())
    }

    private var monthString: String {
        transaction.postDate.formatted(.dateTime.month(.abbreviated))
    }

    private var formattedAmount: String {
        AmountFormatter.format(
            transaction.totalAmount,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    private var splitSummary: String {
        let codes = transaction.splits.prefix(2).map { $0.memo ?? $0.accountId.uuidString.prefix(8).description }
        return codes.joined(separator: " · ")
    }
}

// MARK: - Transaction Detail View

/// A detail view for a transaction showing header info and a splits table.
struct TransactionDetailView: View {
    let transaction: TransactionResponse
    let ledger: LedgerResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                splitsSection
            }
            .padding(24)
        }
        .navigationTitle(transaction.memo ?? "Transaction")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    AmountFormatter.shortDate(transaction.postDate),
                    systemImage: "calendar"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Text(AmountFormatter.format(
                    transaction.totalAmount,
                    currencyCode: ledger.currencyCode,
                    decimalPlaces: ledger.decimalPlaces
                ))
                .font(.title2.bold())
            }

            if let num = transaction.num, !num.isEmpty {
                Label("Reference #\(num)", systemImage: "number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if transaction.isVoided {
                Label("This transaction has been voided", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            Divider()

            Label(
                "Entered: \(AmountFormatter.shortDate(transaction.enterDate))",
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Splits Table

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Splits")
                .font(.headline)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Account")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Memo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Debit")
                        .frame(width: 100, alignment: .trailing)
                    Text("Credit")
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                ForEach(transaction.splits) { split in
                    SplitRowView(
                        split: split,
                        ledger: ledger
                    )
                    Divider()
                }

                // Totals row
                HStack {
                    Text("Total")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption.bold())
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(AmountFormatter.format(
                        transaction.totalAmount,
                        currencyCode: ledger.currencyCode,
                        decimalPlaces: ledger.decimalPlaces
                    ))
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption.bold())
                    Text(AmountFormatter.format(
                        transaction.totalAmount,
                        currencyCode: ledger.currencyCode,
                        decimalPlaces: ledger.decimalPlaces
                    ))
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
}

// MARK: - Split Row

private struct SplitRowView: View {
    let split: SplitResponse
    let ledger: LedgerResponse

    var body: some View {
        HStack {
            // Account ID (short) — replaced by account name in Iteration 4
            Text(split.accountId.uuidString.prefix(8).description + "…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(split.memo ?? "—")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Debit column (side = 0)
            Text(split.side == 0
                 ? AmountFormatter.format(split.amount, currencyCode: ledger.currencyCode, decimalPlaces: ledger.decimalPlaces)
                 : "")
                .frame(width: 100, alignment: .trailing)
                .font(.caption.monospacedDigit())

            // Credit column (side = 1)
            Text(split.side == 1
                 ? AmountFormatter.format(split.amount, currencyCode: ledger.currencyCode, decimalPlaces: ledger.decimalPlaces)
                 : "")
                .frame(width: 100, alignment: .trailing)
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

