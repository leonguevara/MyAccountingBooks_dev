//
//  Features/Accounts/AccountRegisterView.swift
//  AccountRegisterView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felie Guevara Chávez on 2026-04-02
//  Developed with AI assistance.
//

import SwiftUI

/// Account register displaying transaction history and a continuously updated running balance.
///
/// `AccountRegisterView` presents the full transaction register for a single account within a
/// ledger. It follows traditional double-entry accounting conventions: signed amounts reflect the
/// account's normal balance direction, and a running balance is recomputed after each transaction.
///
/// ## Features
///
/// - **Transaction list**: All transactions for the account in chronological order.
/// - **Running balance**: Cumulative balance column updated after every row.
/// - **Signed amounts**: Each amount is signed according to the account's normal balance.
/// - **Interactive rows**: Tap any row to open the full transaction detail sheet.
/// - **Edit transactions**: Edit button in the detail sheet allows modifying memo, number, date, and splits.
/// - **Post transactions**: Create new transactions via the `+` toolbar button or the empty-state button.
/// - **Void / Reverse**: Void or reverse a transaction directly from the detail sheet.
/// - **Voided indicator**: Strikethrough text and a red "VOIDED" badge on voided rows.
/// - **Refresh**: Manual reload via the secondary toolbar button.
/// - **Empty state**: Contextual placeholder with a quick-post button when no transactions exist.
///
/// ## Data Loading
///
/// On `.task`, transactions and the chart of accounts are fetched concurrently:
///
/// ```swift
/// async let txLoad      = viewModel.load(ledger:account:token:)
/// async let accountLoad = AccountService.fetchAccounts(ledgerID:token:)
/// ```
///
/// Transactions are awaited first so the register renders immediately; the account tree
/// (needed only for the post-transaction form and the detail sheet) loads in the background.
/// After the account tree resolves, `accountPaths` is built via
/// ``AccountTreeBuilder/buildPathMap(from:)`` and forwarded to both sheet destinations.
///
/// ## Sheet Destinations
///
/// | Trigger | Sheet | Receives `accountPaths`? |
/// |---|---|---|
/// | Tap a register row | ``TransactionDetailSheet`` | Yes — resolves split UUIDs to names |
/// | Tap `+` / empty CTA | ``PostTransactionView`` | Yes — drives account picker labels |
/// | Tap Edit in detail | `EditTransactionView` | Yes — drives account picker labels |
///
/// ## Display Format
///
/// Each register row shows five fixed-width columns:
///
/// | Column | Width | Alignment |
/// |---|---|---|
/// | Date | 90 pt | Leading |
/// | Ref # | 70 pt | Leading |
/// | Description | Flex | Leading |
/// | Amount | 110 pt | Trailing |
/// | Balance | 120 pt | Trailing |
///
/// ## Usage Example
///
/// ```swift
/// AccountRegisterView(ledger: selectedLedger, account: accountNode)
///     .environment(authService)
/// ```
///
/// - Important: Requires ``AuthService`` in the SwiftUI environment to obtain a valid bearer token.
/// - Note: The account tree and path map are loaded asynchronously. The post-transaction
///   form and detail sheet remain functional as soon as that background load completes;
///   before it does, `allAccountRoots` and `accountPaths` are empty.
/// - SeeAlso: ``AccountRegisterViewModel``, ``TransactionDetailSheet``, ``PostTransactionView``,
///   ``AccountTreeBuilder``
struct AccountRegisterView: View {

    // MARK: - Properties

    /// The ledger that provides currency and decimal context for all monetary amounts.
    ///
    /// Determines how amounts are formatted (currency code, decimal places) and supplies
    /// the `ledgerID` used to fetch both transactions and the account tree.
    let ledger: LedgerResponse

    /// The account whose transaction register is being displayed.
    ///
    /// All transactions shown affect this account. The running balance represents the
    /// cumulative effect on this specific account over time.
    let account: AccountNode

    // MARK: - Environment and State

    /// Authentication service used to obtain the bearer token for all network operations.
    @Environment(AuthService.self) private var auth

    /// View model managing register rows, loading state, error state, and sheet triggers.
    ///
    /// Controls which sheet is currently presented (`showTransactionDetail` or
    /// `showPostTransaction`) and holds the `selectedTransaction` for the detail sheet.
    @State private var viewModel = AccountRegisterViewModel()

    /// Complete chart of accounts tree for the ledger, loaded concurrently with transactions.
    ///
    /// Initially empty. Populated after ``AccountService/fetchAccounts(ledgerID:token:)`` resolves
    /// in the background `.task`. Passed to ``PostTransactionView`` as the account picker source.
    @State private var allAccountRoots: [AccountNode] = []

    /// GnuCash-style colon-separated full paths for every non-root account in the ledger.
    ///
    /// Keys are account UUIDs; values are path strings such as
    /// `"Assets:Current Assets:Cash:Checking"`. Built from `allAccountRoots` via
    /// ``AccountTreeBuilder/buildPathMap(from:)`` immediately after the account tree loads.
    ///
    /// Forwarded to two destinations:
    /// - ``PostTransactionView`` — drives account picker row labels.
    /// - ``TransactionDetailSheet`` → `TransactionDetailView` — resolves raw `accountId`
    ///   UUIDs on split lines to human-readable account names.
    ///
    /// - Note: Empty until the background account-tree load completes. Both sheet
    ///   destinations handle an empty map gracefully (falling back to short UUIDs or
    ///   bare account names).
    /// - SeeAlso: ``AccountTreeBuilder``
    @State private var accountPaths: [UUID: String] = [:]

    // MARK: - Body

    var body: some View {
        // Switches between loading indicator, empty state, and the populated register table.
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

            // Both fetches start simultaneously
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
                accountPaths    = AccountTreeBuilder.buildPathMap(from: allAccountRoots)
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
        // Transaction detail sheet — shown when the user taps a register row.
        // accountPaths is forwarded so TransactionDetailView can resolve split
        // accountId UUIDs to human-readable account names.
        // allAccounts is forwarded to enable the edit transaction form.
        // onTransactionUpdated reloads the register when edits are saved.
        .sheet(isPresented: $viewModel.showTransactionDetail) {
            if let tx = viewModel.selectedTransaction {
                TransactionDetailSheet(
                    transaction: tx,
                    ledger: ledger,
                    accountPaths: accountPaths,
                    allAccounts: allAccountRoots,
                    onTransactionUpdated: {
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
        // Post transaction sheet — shown when the user taps + or the empty-state button.
        // accountPaths drives the account picker label display.
        .sheet(isPresented: $viewModel.showPostTransaction) {
            PostTransactionView(
                ledger: ledger,
                allAccounts: allAccountRoots,
                accountPaths: accountPaths,
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

    /// The main register composed of a sticky header, a scrollable data area, and a footer.
    ///
    /// Renders `viewModel.rows` in a `LazyVStack` for performance on long registers. Each
    /// row is tappable: a tap sets `viewModel.selectedTransaction` and raises the detail sheet.
    /// The selected row is highlighted with a translucent accent background.
    ///
    /// Layout:
    /// - `RegisterHeaderRow` — fixed column labels.
    /// - `ScrollView` / `LazyVStack` — one `RegisterDataRow` per ``RegisterRow``, with dividers.
    /// - `RegisterFooterRow` — current balance from `viewModel.rows.last?.runningBalance`.
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

    /// Placeholder shown when the account has no recorded transactions.
    ///
    /// Presents an icon, a headline, a supporting message, and a "Post Transaction"
    /// button that triggers the same sheet as the `+` toolbar item.
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
    /// - **Primary action (`+`)**: Sets `viewModel.showPostTransaction = true`, which
    ///   presents ``PostTransactionView`` with the pre-loaded account tree and path map.
    /// - **Secondary action (↺ Refresh)**: Re-invokes `viewModel.load` to pull the latest
    ///   transactions from the backend without reloading the account tree.
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

/// Fixed column headers for the register table.
///
/// Renders five labels with the same fixed widths used by `RegisterDataRow` to ensure
/// visual alignment across the entire register:
///
/// | Column | Width | Alignment |
/// |---|---|---|
/// | Date | 90 pt | Leading |
/// | Ref # | 70 pt | Leading |
/// | Description | Flex | Leading |
/// | Amount | 110 pt | Trailing |
/// | Balance | 120 pt | Trailing |
///
/// The header uses `windowBackgroundColor` to visually separate it from the data rows below.
///
/// - Note: `ledger` is accepted as a parameter for future extensibility (e.g., showing
///   the currency symbol in the Amount/Balance headers), but is not currently used.
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

/// A single register row displaying one transaction and its running balance.
///
/// Renders five fixed-width columns aligned with `RegisterHeaderRow`:
/// - **Date**: Short-formatted posting date in monospaced digits.
/// - **Ref #**: Reference number prefixed with `"#"` when present; empty otherwise.
/// - **Description**: Transaction memo, with strikethrough and a red `"VOIDED"` capsule
///   badge for voided transactions.
/// - **Amount**: Signed amount for this account via `row.accountAmount`; negative values
///   are rendered in red.
/// - **Balance**: Running cumulative balance via `row.runningBalance`; negative values
///   are rendered in red.
///
/// Monospaced digits are used for all numeric and date columns to ensure vertical alignment
/// across rows regardless of digit width.
///
/// ## Visual Indicators
///
/// | Condition | Visual treatment |
/// |---|---|
/// | Voided transaction | Strikethrough memo + red `"VOIDED"` badge |
/// | Negative amount | Red foreground on the Amount column |
/// | Negative balance | Red foreground on the Balance column |
///
/// - SeeAlso: ``RegisterRow``, `AmountFormatter`
private struct RegisterDataRow: View {
    /// The register row data containing the transaction and its computed amounts.
    let row: RegisterRow
    /// The ledger context for currency code and decimal-place formatting.
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

    /// Formats `row.accountAmount` using the ledger's currency code and decimal places.
    private var formattedAmount: String {
        AmountFormatter.format(
            row.accountAmount,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    /// Formats `row.runningBalance` using the ledger's currency code and decimal places.
    private var formattedBalance: String {
        AmountFormatter.format(
            row.runningBalance,
            currencyCode: ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }

    /// Red for negative amounts; primary label color otherwise.
    private var amountColor: Color {
        row.accountAmount >= 0 ? Color.primary : Color.red
    }

    /// Red for negative balances; primary label color otherwise.
    private var balanceColor: Color {
        row.runningBalance >= 0 ? Color.primary : Color.red
    }
}

// MARK: - Register Footer Row

/// Footer row displaying the current account balance.
///
/// Shows the final running balance after all transactions, formatted with the ledger's
/// currency code and decimal places. Negative balances are displayed in red to draw
/// attention to potentially unexpected account states.
///
/// The footer provides an at-a-glance balance summary without requiring the user to
/// scroll to the last row of a long register.
///
/// - Note: The balance value is sourced from `viewModel.rows.last?.runningBalance`,
///   falling back to `.zero` when the register is empty.
/// - SeeAlso: ``RegisterRow``, `AmountFormatter`
private struct RegisterFooterRow: View {
    /// The balance to display — typically the `runningBalance` of the last register row.
    let balance: Decimal
    /// The ledger context for currency code and decimal-place formatting.
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

/// Sheet wrapper presenting the full details of a tapped register transaction.
///
/// Embeds `TransactionDetailView` inside a custom navigation bar with **Reverse**,
/// **Void**, **Edit**, and **Done** buttons. Presented by ``AccountRegisterView``
/// when the user taps any register row.
///
/// `accountPaths` is forwarded to `TransactionDetailView` so raw `accountId` UUIDs
/// on split lines are resolved to human-readable names (e.g.,
/// `"Assets:Current Assets:Cash:Checking"`). `loadedPayees` is fetched on `.task`
/// via ``PayeeService`` and forwarded for payee name display.
///
/// ## Edit Flow
///
/// Tap "Edit" → `EditTransactionView` sheet → PATCH `/transactions/{id}` →
/// `onTransactionUpdated()` reloads the register → both sheets dismiss.
///
/// ## Void / Reverse Flow
///
/// A confirmation alert with an optional text field (reason / memo) is shown.
/// On confirmation, the appropriate ``TransactionService`` method is called,
/// `onTransactionUpdated()` reloads the register, the sheet dismisses, and a
/// `.transactionPosted` notification is posted so ``AccountTreeView`` updates balances.
///
/// - Note: Minimum frame 600 × 480 pt. All action buttons are hidden when
///   `transaction.isVoided` is `true` — voided transactions are immutable.
/// - SeeAlso: `TransactionDetailView`, `EditTransactionView`, ``AccountRegisterView``,
///   ``TransactionService``
struct TransactionDetailSheet: View {
    /// The transaction whose full detail is being displayed.
    let transaction: TransactionResponse

    /// The ledger context for currency code and decimal-place formatting.
    let ledger: LedgerResponse

    /// GnuCash-style full paths keyed by account UUID.
    ///
    /// Forwarded to `TransactionDetailView` to resolve split `accountId` values to
    /// human-readable names. Defaults to an empty dictionary; the detail view falls
    /// back to truncated UUID strings when a path is not found.
    var accountPaths: [UUID: String] = [:]

    /// Complete chart of accounts hierarchy for the ledger.
    ///
    /// Forwarded to `EditTransactionView` to populate account pickers when editing
    /// split assignments.
    var allAccounts: [AccountNode] = []
    
    /// Pre-loaded payee list; currently unused (payees are loaded in `.task` via ``PayeeService``).
    var payees: [PayeeResponse] = []

    /// Payees fetched on `.task` and forwarded to `TransactionDetailView` for name display.
    ///
    /// Populated by ``PayeeService/fetchPayees(ledgerID:token:)``; empty until the fetch completes.
    @State private var loadedPayees: [PayeeResponse] = []

    /// Async closure invoked after a successful edit, void, or reverse action.
    ///
    /// ``AccountRegisterView`` uses this callback to reload the transaction register
    /// and reflect the updated data without requiring a full view reconstruction.
    var onTransactionUpdated: () async -> Void = {}

    /// Authentication service for obtaining the bearer token for all write operations.
    @Environment(AuthService.self) private var auth

    /// Environment dismiss action used by the "Done" button and after successful actions.
    @Environment(\.dismiss) private var dismiss

    /// Controls presentation of the `EditTransactionView` sheet.
    ///
    /// Set to `true` when the user taps "Edit" in the custom navigation bar.
    @State private var showEdit = false

    /// Controls presentation of the void-transaction confirmation alert.
    @State private var showVoidAlert    = false

    /// Controls presentation of the reverse-transaction confirmation alert.
    @State private var showReverseAlert = false

    /// Shared text-field input for void reason or reversal memo, bound to the active alert.
    ///
    /// Cleared on cancel and on successful action completion.
    @State private var actionReason = ""

    /// `true` while a void or reverse network call is in flight; drives the inline `ProgressView`.
    @State private var isActioning  = false

    /// Inline error message shown in the navigation bar area when a void or reverse call fails.
    ///
    /// Set to `nil` at the start of each action and on success; set to the localized error
    /// description on failure.
    @State private var actionError: String?

    var body: some View {
        VStack(spacing: 0) {

            // ── Navigation bar substitute ─────────────────────────────────
            // Custom navigation bar with Edit and Done buttons.
            // Edit button is hidden for voided transactions (they are immutable).
            // Tapping Edit presents EditTransactionView with the chart of accounts.
            HStack {
                Text(transaction.memo ?? "Transaction")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let error = actionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if isActioning {
                    ProgressView().controlSize(.small)
                }
                if !transaction.isVoided {
                    Button("Reverse") { showReverseAlert = true }
                        .buttonStyle(.bordered)
                    Button("Void") { showVoidAlert = true }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    Button("Edit") { showEdit = true }
                        .buttonStyle(.bordered)
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Transaction detail body ───────────────────────────────────
            ScrollView {
                TransactionDetailView(
                    transaction: transaction,
                    ledger: ledger,
                    accountPaths: accountPaths,
                    payees: loadedPayees          // ← fix
                )
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        // Edit transaction sheet — presented when user taps "Edit".
        // On successful save, calls onTransactionUpdated to refresh the register
        // and dismisses both the edit sheet and this detail sheet.
        .sheet(isPresented: $showEdit) {
            EditTransactionView(
                transaction: transaction,
                ledger: ledger,
                allAccounts: allAccounts,
                accountPaths: accountPaths,
                onSuccess: {
                    await onTransactionUpdated()
                    dismiss()
                }
            )
            .environment(auth)
        }
        // Void confirmation alert
        .alert("Void Transaction", isPresented: $showVoidAlert) {
            TextField("Reason (optional)", text: $actionReason)
            Button("Void", role: .destructive) {
                Task { await performVoid() }
            }
            Button("Cancel", role: .cancel) { actionReason = "" }
        } message: {
            Text("This will mark the transaction as voided. This action cannot be undone.")
        }

        // Reverse confirmation alert
        .alert("Reverse Transaction", isPresented: $showReverseAlert) {
            TextField("Memo (optional)", text: $actionReason)
            Button("Reverse") {
                Task { await performReverse() }
            }
            Button("Cancel", role: .cancel) { actionReason = "" }
        } message: {
            Text("This will create a new transaction with all amounts reversed.")
        }
        .task {
            guard let token = auth.token else { return }
            if let fetched = try? await PayeeService.shared.fetchPayees(
                ledgerID: ledger.id, token: token) {
                loadedPayees = fetched
            }
        }
    }
    
    /// Calls ``TransactionService/voidTransaction(id:reason:token:)``, reloads the register,
    /// dismisses this sheet, and posts a `.transactionPosted` notification so that
    /// ``AccountTreeView`` refreshes balances.
    ///
    /// A 0.3 s delay before the notification gives the sheet-dismissal animation time to
    /// complete before the tree view processes the balance update.
    private func performVoid() async {
        guard let token = auth.token else { return }
        isActioning = true
        actionError = nil
        do {
            _ = try await TransactionService.shared.voidTransaction(
                id: transaction.id,
                reason: actionReason.isEmpty ? nil : actionReason,
                token: token
            )
            actionReason = ""
            await onTransactionUpdated()
            dismiss()
            // Small yield to let the sheet dismissal animation complete
            // before the main window's AccountTreeView processes the notification
            try? await Task.sleep(nanoseconds: 300_000_000)   // 0.3 seconds
            NotificationCenter.default.post(
                name: .transactionPosted,
                object: ledger.id        // ← use ledger.id directly
            )
        } catch {
            actionError = error.localizedDescription
        }
        isActioning = false
    }

    /// Calls ``TransactionService/reverseTransaction(id:memo:token:)``, reloads the register,
    /// dismisses this sheet, and posts a `.transactionPosted` notification so that
    /// ``AccountTreeView`` refreshes balances.
    ///
    /// A 0.3 s delay before the notification gives the sheet-dismissal animation time to
    /// complete before the tree view processes the balance update.
    private func performReverse() async {
        guard let token = auth.token else { return }
        isActioning = true
        actionError = nil
        do {
            _ = try await TransactionService.shared.reverseTransaction(
                id: transaction.id,
                memo: actionReason.isEmpty ? nil : actionReason,
                token: token
            )
            actionReason = ""
            await onTransactionUpdated()
            dismiss()
            // Small yield to let the sheet dismissal animation complete
            // before the main window's AccountTreeView processes the notification
            try? await Task.sleep(nanoseconds: 300_000_000)   // 0.3 seconds
            NotificationCenter.default.post(
                name: .transactionPosted,
                object: ledger.id        // ← use ledger.id directly
            )
        } catch {
            actionError = error.localizedDescription
        }
        isActioning = false
    }
}
