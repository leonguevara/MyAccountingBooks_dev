//
//  Features/Accounts/AccountRegisterView.swift
//  AccountRegisterView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import SwiftUI

/**
 A comprehensive account register view displaying transaction history and running balance.
 
 This view presents a detailed register for a specific account within a ledger, showing all
 transactions that affect the account with signed amounts and a continuously updated running balance.
 The register follows traditional accounting principles with debit/credit amount formatting.
 
 # Features
 - **Transaction List**: Displays all transactions for the account in chronological order
 - **Running Balance**: Shows cumulative balance after each transaction
 - **Signed Amounts**: Amounts are signed according to the account's normal balance
 - **Interactive Rows**: Tap any transaction to view full details
 - **Post Transactions**: Create new transactions via toolbar or empty state button
 - **Voided Indicator**: Visual badge for voided transactions with strikethrough text
 - **Refresh**: Manual refresh button to reload latest transactions
 - **Empty State**: Helpful placeholder when no transactions exist
 
 # User Interactions
 - **Tapping a row**: Opens transaction detail sheet with all splits and metadata
 - **+ Toolbar button**: Opens post transaction form
 - **Empty state button**: Opens post transaction form when no transactions exist
 - **Refresh button**: Reloads transactions from the backend
 
 # Data Loading
 The view loads two pieces of data concurrently on appear:
 1. **Transactions** for the current account (loaded first for quick display)
 2. **Account tree** for the entire chart of accounts (needed for transaction posting)
 
 # Display Format
 Each register row shows:
 - **Date**: Transaction posting date in short format
 - **Ref #**: Optional reference number (check number, invoice, etc.)
 - **Description**: Transaction memo with voided badge if applicable
 - **Amount**: Signed amount for this account (red if negative)
 - **Balance**: Running balance after this transaction (red if negative)
 
 # Usage Example
 ```swift
 AccountRegisterView(ledger: selectedLedger, account: accountNode)
     .environment(authService)
 ```
 
 - Important: Requires `AuthService` in the environment to obtain authentication token.
 - Note: The account tree is loaded asynchronously to populate the account picker in the post transaction form.
 - SeeAlso: `AccountRegisterViewModel`, `TransactionDetailView`, `PostTransactionView`
 */

struct AccountRegisterView: View {

    // MARK: - Properties
    
    /// The ledger that provides currency and decimal context for all monetary amounts.
    ///
    /// This ledger determines how amounts are formatted (currency code, decimal places)
    /// and provides the context for fetching transactions.
    let ledger: LedgerResponse
    
    /// The account whose transaction register is being displayed.
    ///
    /// All transactions shown in the register affect this account. The running balance
    /// represents the cumulative effect on this specific account.
    let account: AccountNode

    // MARK: - Environment and State
    
    /// Authentication service used to obtain bearer token for network operations.
    ///
    /// Required for loading transactions and accounts from the backend API.
    @Environment(AuthService.self) private var auth
    
    /// View model managing register data, loading state, and sheet presentation.
    ///
    /// Handles transaction loading, row computation, error state, and controls which
    /// sheets are currently presented (transaction detail or post transaction form).
    @State private var viewModel = AccountRegisterViewModel()
    
    /// Complete chart of accounts tree for the ledger.
    ///
    /// Loaded asynchronously alongside transactions to populate the account picker
    /// in the post transaction form. Initially empty until accounts are fetched.
    @State private var allAccountRoots: [AccountNode] = []

    // MARK: - Body
    
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
        // Load transactions and account tree concurrently on appear.
        // Transactions are awaited first so the register renders immediately,
        // while the account tree loads in the background for the post transaction form.
        .task {
            guard let token = auth.token else { return }
             
            // Load transactions and account tree concurrently
            async let txLoad: () = viewModel.load(
                ledger: ledger,
                account: account,
                token: token
            )
            async let accountLoad = AccountService.shared.fetchAccounts(
                ledgerID: ledger.id,
                token: token
            )
 
            // Await transactions first so the register renders quickly
            await txLoad
            if let flat = try? await accountLoad {
                allAccountRoots = AccountTreeBuilder.build(from: flat)
            }
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
        // Transaction detail sheet - shown when user taps a register row
        .sheet(isPresented: $viewModel.showTransactionDetail) {
            if let tx = viewModel.selectedTransaction {
                TransactionDetailSheet(transaction: tx, ledger: ledger)
            }
        }
        // Post transaction sheet - shown when user taps + button or empty state button
        .sheet(isPresented: $viewModel.showPostTransaction) {
            PostTransactionView(
                ledger: ledger,
                allAccounts: allAccountRoots,
                onSuccess: {
                    guard let token = auth.token else { return }
                    await viewModel.load(
                        ledger: ledger,
                        account: account,
                        token: token
                    )
                }
            )
            .environment(auth)
        }
    }

    // MARK: - Register Table
    
    /// The main register table composed of header, scrollable data rows, and footer.
    ///
    /// Displays all transactions in chronological order with:
    /// - Column headers showing Date, Ref #, Description, Amount, and Balance
    /// - Scrollable list of transaction rows with tap gesture support
    /// - Footer showing current account balance
    ///
    /// Each row is tappable to show transaction details and highlights when selected.
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

    // MARK: - Empty State
    
    /// Placeholder content shown when the account has no transactions.
    ///
    /// Displays a friendly message with an icon and provides a quick action button
    /// to post the first transaction for this account. The "Post Transaction" button
    /// opens the same form as the + toolbar button.
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

    // MARK: - Toolbar
    
    /// Toolbar actions for posting a new transaction and refreshing the register.
    ///
    /// **Primary Action:**
    /// - **+ Button**: Opens the post transaction form with the account tree pre-loaded
    ///
    /// **Secondary Action:**
    /// - **Refresh Button**: Reloads transactions from the backend to show latest data
    ///
    /// Both actions require authentication and use the token from `AuthService`.
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

// MARK: - Register Header Row

/**
 Column headers for the register table.
 
 Displays fixed-width column headers for the five register columns:
 - **Date**: Transaction posting date (90pt)
 - **Ref #**: Optional reference/check number (70pt)
 - **Description**: Transaction memo (flexible width)
 - **Amount**: Signed amount for this account (110pt, right-aligned)
 - **Balance**: Running balance after transaction (120pt, right-aligned)
 
 The header uses a distinct background color and secondary text to differentiate
 it from the data rows below.
 */
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

// MARK: - Register Data Row

/**
 A single register row showing transaction details and running balance.
 
 Displays a complete transaction entry in the register with:
 - **Date**: Short-formatted posting date
 - **Ref #**: Reference number prefixed with "#" (if present)
 - **Description**: Transaction memo with voided badge overlay (if voided)
 - **Amount**: Signed amount for this account (negative amounts in red)
 - **Balance**: Cumulative balance after this transaction (negative balances in red)
 
 # Visual Indicators
 - **Voided transactions**: Strikethrough text and red "VOIDED" badge
 - **Negative amounts**: Displayed in red color
 - **Negative balances**: Displayed in red color
 
 The row uses monospaced digits for amounts and dates to ensure proper alignment
 across all rows in the register.
 */
private struct RegisterDataRow: View {
    /// The register row data containing transaction and computed amounts.
    let row: RegisterRow
    /// The ledger context for currency formatting.
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

// MARK: - Register Footer Row

/**
 Footer row displaying the current account balance.
 
 Shows the final running balance after all transactions, formatted according to
 the ledger's currency code and decimal places. Negative balances are displayed
 in red to draw attention to potential issues.
 
 This footer provides a quick reference for the account's current state without
 needing to scroll to the last transaction in a long register.
 */
private struct RegisterFooterRow: View {
    /// The current balance to display (typically from the last register row).
    let balance: Decimal
    /// The ledger context for currency formatting.
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

// MARK: - Transaction Detail Sheet

/**
 A sheet presentation of the full transaction details.
 
 This view wraps `TransactionDetailView` in a navigation stack with a "Done" button
 to dismiss the sheet. It's presented when the user taps on any transaction row
 in the register.
 
 The sheet displays:
 - Complete transaction metadata (date, reference, memo, status)
 - All split lines with accounts and amounts
 - Debit/credit totals and balance verification
 
 # Usage
 This sheet is automatically presented by `AccountRegisterView` when a transaction
 row is tapped. The dismiss action is handled by the "Done" button in the toolbar.
 
 - Note: The sheet has a minimum size to ensure all transaction details are readable.
 */
struct TransactionDetailSheet: View {
    /// The transaction to display in detail.
    let transaction: TransactionResponse
    /// The ledger context for currency formatting.
    let ledger: LedgerResponse
    /// Environment dismiss action to close the sheet.
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
