//
//  Features/Transactions/TransactionListView.swift
//  TransactionListView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-13.
//  Last modified by León Felipe Guevara Chávez on 2026-03-22.
//  Developed with AI assistance.
//

import SwiftUI

/**
 Displays a month-grouped, searchable list of transactions for a given ledger.

 `TransactionListView` binds to a `TransactionListViewModel` for all data operations
 and presents three mutually exclusive states driven by loading and filter conditions:
 a `ProgressView` while the initial fetch is in flight, an empty state when no
 transactions match the current filters, and the sectioned transaction list otherwise.

 # Features

 - **Month grouping**: Transactions are grouped by `postDate` month via
   `viewModel.groupedTransactions` and rendered as `List` sections.
 - **Search**: A `.searchable` modifier filters by memo, reference number, and split
   memos in real time through `viewModel.filteredTransactions`.
 - **Voided toggle**: A toolbar `Toggle` controls `viewModel.showVoided`; voided
   transactions are hidden by default and shown with strikethrough + badge when revealed.
 - **Selection**: Row selection is bound via `$selectedTransaction` for use by a parent
   split view or navigation destination.
 - **Error handling**: Network failures surface as a dismissible alert.

 # Usage Example

 ```swift
 @State private var selectedTx: TransactionResponse?

 TransactionListView(ledger: someLedger, selectedTransaction: $selectedTx)
     .environment(authService)
 ```

 - Important: Requires `AuthService` in the SwiftUI environment to obtain the bearer
   token before loading.
 - Note: Uses `.task(id: ledger.id)` so the list reloads automatically whenever the
   selected ledger changes.
 - SeeAlso: `TransactionListViewModel`, `TransactionRowView`
 */
struct TransactionListView: View {

    /// The ledger whose transactions are displayed.
    ///
    /// Provides the `ledgerID` for the network fetch and the currency/decimal context
    /// forwarded to each `TransactionRowView`.
    let ledger: LedgerResponse

    /// Authentication service providing the bearer token for network operations.
    @Environment(AuthService.self) private var auth

    /// View model managing transaction loading, filtering, grouping, and error state.
    @State private var viewModel = TransactionListViewModel()

    /// The currently selected transaction, bound from a parent view.
    ///
    /// Updated by `List(selection:)` when the user taps a row. A parent split view
    /// or navigation destination can observe this binding to drive a detail panel.
    @Binding var selectedTransaction: TransactionResponse?

    // MARK: - Body

    var body: some View {
        /// Switches between loading indicator, empty state, and the grouped transaction list.
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

    /// Month-sectioned transaction list with row selection support.
    ///
    /// Iterates `viewModel.groupedTransactions` — a sorted array of `(key: String,
    /// transactions: [TransactionResponse])` tuples — and renders each group as a
    /// `Section` whose header is the month label (e.g., `"March 2026"`). Each row is
    /// a `TransactionRowView` tagged with its `TransactionResponse` for selection binding.
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

    /// Placeholder shown when no transactions match the current filters.
    ///
    /// Displays context-sensitive messaging:
    /// - When `searchText` is empty: indicates the ledger has no transactions yet.
    /// - When `searchText` is non-empty: indicates no transactions match the query.
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

    /// Toolbar toggle controlling visibility of voided transactions.
    ///
    /// Bound to `viewModel.showVoided`. When `off` (default), voided transactions are
    /// excluded from `filteredTransactions`. When `on`, they appear with strikethrough
    /// text and a red "VOIDED" badge in each `TransactionRowView`.
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

/**
 A single list row representing one transaction with date badge, memo, split summary,
 total amount, and an optional voided indicator.

 # Layout

 ```
 [Day / Month badge] | [Ref# · Memo]          [Amount]
                       [Split summary]         [VOIDED badge?]
 ```

 - **Date badge**: Day number in `title2.bold` and abbreviated month below in `caption2`,
   both monospaced, in a fixed 36 pt column.
 - **Memo line**: Optional reference number prefix (`#num`) followed by the transaction
   memo. Voided transactions render the memo with strikethrough in secondary color.
 - **Split summary**: Up to two split memos joined by `" · "`. Falls back to a truncated
   `accountId` UUID when a split has no memo.
 - **Amount**: `totalAmount` formatted with the ledger's currency code and decimal places.
   Shown in secondary color for voided transactions.
 - **Voided badge**: A red capsule with "VOIDED" in `caption2.bold` shown only when
   `transaction.isVoided` is `true`.

 - SeeAlso: `TransactionListView`, `AmountFormatter`
 */
private struct TransactionRowView: View {
    /// The transaction this row represents.
    let transaction: TransactionResponse
    /// Ledger context for currency code and decimal-place formatting.
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

                // Split summary: first two split memos (or short UUID fallback)
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

    /// Day-of-month string extracted from `transaction.postDate` (e.g., `"22"`).
    private var dayString: String {
        transaction.postDate.formatted(.dateTime.day())
    }

    /// Abbreviated month string extracted from `transaction.postDate` (e.g., `"Mar"`).
    private var monthString: String {
        transaction.postDate.formatted(.dateTime.month(.abbreviated))
    }

    /// `totalAmount` formatted with the ledger's currency code and decimal precision.
    private var formattedAmount: String {
        AmountFormatter.format(
            transaction.totalAmount,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    /// Summary string built from the first two split memos, joined by `" · "`.
    ///
    /// Falls back to `split.accountId.uuidString.prefix(8) + "…"` for splits that have
    /// no memo. This is a display-only heuristic; account names are not available in
    /// `TransactionRowView` (no `accountPaths` map at this level).
    private var splitSummary: String {
        let codes = transaction.splits.prefix(2).map {
            $0.memo ?? $0.accountId.uuidString.prefix(8).description
        }
        return codes.joined(separator: " · ")
    }
}

// MARK: - Transaction Detail View

/**
 Detail view for a single transaction showing metadata, a splits table, and column totals.

 `TransactionDetailView` is displayed inside `TransactionDetailSheet` (from
 `AccountRegisterView`) when the user taps a register row. It renders two sections:

 - **Header card**: Posting date, total amount, optional reference number, voided warning,
   and entered date.
 - **Splits table**: One `SplitRowView` per split with Account, Memo, Debit, and Credit
   columns, followed by a totals row.

 # Account Name Resolution

 Split lines from the API carry only a raw `accountId` UUID. The optional `accountPaths`
 dictionary (built by `AccountTreeBuilder.buildPathMap(from:)` in `AccountRegisterView`)
 maps those UUIDs to human-readable leaf names. When present, `SplitRowView` displays the
 resolved leaf name; when absent (empty map), it falls back to a truncated UUID string.

 # Usage

 ```swift
 // With path resolution (from AccountRegisterView → TransactionDetailSheet)
 TransactionDetailView(
     transaction: tx,
     ledger: ledger,
     accountPaths: accountPaths
 )

 // Without path resolution (legacy / standalone callers)
 TransactionDetailView(transaction: tx, ledger: ledger)
 ```

 - Note: `accountPaths` defaults to an empty dictionary so that all existing call sites
   that omit the argument continue to compile and render without modification.
 - SeeAlso: `TransactionDetailSheet`, `SplitRowView`, `AccountTreeBuilder.buildPathMap(from:)`
 */
struct TransactionDetailView: View {
    /// The transaction to display.
    let transaction: TransactionResponse

    /// Ledger context for currency code and decimal-place formatting.
    let ledger: LedgerResponse

    /// GnuCash-style colon-separated full paths keyed by account UUID.
    ///
    /// When non-empty, `SplitRowView` uses this map to resolve each split's `accountId`
    /// to a leaf account name (the last colon-delimited component of the path).
    /// Defaults to `[:]` so existing callers without a path map compile unmodified.
    ///
    /// - SeeAlso: `AccountTreeBuilder.buildPathMap(from:)`, `SplitRowView.resolvedAccountName`
    var accountPaths: [UUID: String] = [:]

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

    /// Transaction metadata card: date, total amount, reference number, voided warning,
    /// and entered date.
    ///
    /// Renders inside a rounded-rectangle card with `controlBackgroundColor` fill.
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

    /**
     Splits table: column header row, one `SplitRowView` per split, and a totals row.

     `accountPaths` is forwarded to each `SplitRowView` so split account IDs are
     resolved to leaf account names wherever the map is available.

     # Column Layout

     | Column  | Width | Alignment |
     |---------|-------|-----------|
     | Account | Flex  | Leading   |
     | Memo    | Flex  | Leading   |
     | Debit   | 100pt | Trailing  |
     | Credit  | 100pt | Trailing  |

     The totals row repeats `transaction.totalAmount` in both Debit and Credit columns,
     reflecting that a balanced transaction has equal total debits and credits.
     */
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

                // Data rows — accountPaths forwarded for account name resolution
                ForEach(transaction.splits) { split in
                    SplitRowView(
                        split: split,
                        ledger: ledger,
                        accountPaths: accountPaths
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

/**
 A single row in the `TransactionDetailView` splits table.

 Renders four columns — Account, Memo, Debit, Credit — for one `SplitResponse`.
 The Account column displays a resolved human-readable name when `accountPaths` is
 available, falling back gracefully to a truncated UUID string.

 # Account Name Resolution

 The `resolvedAccountName` computed property implements a two-level fallback:

 1. **Path available**: Extracts the **leaf component** (text after the last `":"`)
    from the full GnuCash-style path (e.g., `"Checking"` from
    `"Assets:Current Assets:Cash:Checking"`). Showing only the leaf keeps the narrow
    Account column readable without truncating meaningful context.
 2. **Path unavailable**: Falls back to `split.accountId.uuidString.prefix(8) + "…"`.
    This preserves backward compatibility with call sites that do not supply a path map.

 Long account names are truncated from the **leading edge** (`.truncationMode(.head)`)
 so the most specific part of the name remains visible.

 # Debit / Credit Columns

 `split.side` determines which column is populated:
 - `side == 0`: Debit column shows the formatted amount; Credit is empty.
 - `side == 1`: Credit column shows the formatted amount; Debit is empty.

 - Note: `accountPaths` defaults to `[:]` so existing callers that omit it
   continue to compile and render the short-UUID fallback unmodified.
 - SeeAlso: `TransactionDetailView`, `AccountTreeBuilder.buildPathMap(from:)`
 */
private struct SplitRowView: View {
    /// The split line from the API response.
    let split: SplitResponse

    /// Ledger context for currency code and decimal-place formatting.
    let ledger: LedgerResponse

    /// GnuCash-style colon-separated full paths keyed by account UUID.
    ///
    /// When non-empty, `resolvedAccountName` uses this map to display a human-readable
    /// leaf account name instead of a truncated UUID. Defaults to `[:]` for backward
    /// compatibility with callers that do not supply a path map.
    ///
    /// - SeeAlso: `resolvedAccountName`, `AccountTreeBuilder.buildPathMap(from:)`
    var accountPaths: [UUID: String] = [:]

    var body: some View {
        HStack {
            Text(resolvedAccountName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)

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

    // MARK: - Helpers

    /**
     Resolves the display name for this split's account using a two-level fallback strategy.

     1. **Path available** (`accountPaths[split.accountId]` is non-`nil`): Returns the
        **leaf component** — the substring after the final `":"` in the full path.
        For example, `"Assets:Current Assets:Cash:Checking"` → `"Checking"`.
        If the path contains no colon (a top-level account), the full path string is
        returned as-is.

     2. **Path unavailable**: Returns the first 8 characters of the `accountId` UUID
        followed by `"…"` as a diagnostic fallback (e.g., `"550e8400…"`).

     - Returns: A short, human-readable string suitable for display in the narrow Account
       column of the splits table.
     - SeeAlso: `accountPaths`, `AccountTreeBuilder.buildPathMap(from:)`
     */
    private var resolvedAccountName: String {
        if let path = accountPaths[split.accountId] {
            // Show only the leaf name (last component after the final colon)
            // to keep the splits table readable within the fixed column width.
            return path.split(separator: ":").last.map(String.init) ?? path
        }
        // Fallback: short UUID prefix when no path map is available.
        return split.accountId.uuidString.prefix(8).description + "…"
    }
}
