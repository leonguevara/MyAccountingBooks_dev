//
//  Features/Transactions/PostTransactionView.swift
//  PostTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-01.
//  Developed with AI assistance.
//

import SwiftUI

/// Form view for creating a new multi-split double-entry accounting transaction.
///
/// `PostTransactionView` provides a complete data-entry interface for posting a transaction
/// to a ledger. It enforces double-entry bookkeeping rules throughout: the form cannot be
/// submitted until total debits equal total credits across all split lines.
///
/// ## Features
///
/// - **Transaction header**: Date picker, free-text memo, and optional reference number
/// - **Dynamic split management**: Add or remove split lines freely; minimum of 2 enforced
/// - **Account picker**: Per-split expandable dropdown with real-time search, GnuCash-style
///   full-path labels (e.g., `"Assets:Current Assets:Cash:Checking"`), and kind-color dots
/// - **New Account on-the-fly**: The account picker offers a "New Account…" option that
///   opens the account creation form in a new window. The picker refreshes automatically
///   when the new account is saved via `NotificationCenter`
/// - **Live account list**: Automatically refreshes when accounts are saved in other windows
/// - **Balance summary**: Live debit/credit totals with a green "Balanced" badge or a red
///   imbalance amount
/// - **Auto-balance**: One-tap button fills the last split line with the amount needed to
///   bring the transaction into balance
/// - **Submission guard**: The "Post" button is disabled until `viewModel.canSubmit` is `true`
///   (balanced, all splits complete, not already submitting)
/// - **Error display**: Inline red caption below the form when `viewModel.errorMessage` is set
///
/// ## Account Labels (GnuCash-style paths)
///
/// `accountPaths` is a `[UUID: String]` dictionary built by ``AccountTreeBuilder/buildPathMap(from:)``.
/// It is threaded through to each ``SplitLineRow`` → `accountPickerButton` and ``AccountPickerRow``
/// so that both the collapsed button label and every dropdown row show the full ancestor path
/// rather than a bare account name or truncated code. The leaf name is always visible because
/// long paths are truncated from the leading edge (`.truncationMode(.head)`).
///
/// ## Account List Refresh
///
/// The view maintains live `currentAccounts` and `currentPaths` state that is automatically
/// refreshed when `.accountSaved` notifications are received. This enables the workflow:
///
/// 1. User opens transaction posting form
/// 2. User clicks "New Account…" in a split line picker
/// 3. Account form opens in new window, user creates account
/// 4. ``AccountFormViewModel`` posts `.accountSaved` notification
/// 5. This view receives notification, fetches updated account tree
/// 6. Split line pickers immediately show the new account
///
/// No reopening of the sheet is required — accounts appear immediately.
///
/// ## Layout
///
/// ```
/// NavigationStack
/// └─ Form (grouped)
///    ├─ Section "Transaction Details"  — date, memo, ref #
///    ├─ Section "Splits"               — column headers + SplitLineRow × n + Add button
///    ├─ Section (balance summary)      — total debits | status | total credits
///    └─ Section (error)                — shown only when errorMessage ≠ nil
/// ```
///
/// ## Usage Example
///
/// ```swift
/// PostTransactionView(
///     ledger: selectedLedger,
///     allAccounts: allAccountRoots,
///     accountPaths: accountPaths,
///     onSuccess: {
///         guard let token = auth.token else { return }
///         await viewModel.load(ledger: ledger, account: account, token: token)
///     }
/// )
/// .environment(auth)
/// ```
///
/// ## Double-Entry Validation
///
/// The form enforces fundamental accounting rules:
/// - Minimum 2 splits required (one debit, one credit at minimum)
/// - Total debits must equal total credits (checked in real-time)
/// - All splits must have an account assigned
/// - At least one split must have a non-zero amount
///
/// The "Post" button remains disabled until all validation passes.
///
/// - Important: All splits must balance (total debits = total credits) before the "Post"
///   button becomes active.
/// - Note: Requires ``AuthService`` in the SwiftUI environment. The token is read from
///   `auth.token` at the moment the "Post" button is tapped.
/// - SeeAlso: ``PostTransactionViewModel``, ``SplitLineRow``, ``AccountPickerRow``,
///   ``AccountTreeBuilder/buildPathMap(from:)``, ``Notification/Name/accountSaved``
struct PostTransactionView: View {

    // MARK: - Properties

    /// The ledger to which the transaction will be posted.
    ///
    /// Used to:
    /// - Provide currency code and decimal places for amount formatting
    /// - Identify which ledger to post the transaction to
    /// - Filter `.accountSaved` notifications (only reload for this ledger)
    let ledger: LedgerResponse

    /// Async callback invoked immediately after the transaction is successfully posted.
    ///
    /// Typically used by the parent view to refresh its transaction list. Called before
    /// the sheet is dismissed, allowing the parent to reload data while the loading
    /// indicator is still visible.
    ///
    /// Example:
    /// ```swift
    /// PostTransactionView(
    ///     ledger: ledger,
    ///     allAccounts: accounts,
    ///     accountPaths: paths,
    ///     onSuccess: {
    ///         await registerViewModel.loadTransactions()
    ///     }
    /// )
    /// ```
    let onSuccess: () async -> Void

    // MARK: - Environment and State

    /// Authentication service providing the bearer token used to authorize the POST request.
    @Environment(AuthService.self) private var auth

    /// Environment dismiss action used to close the sheet on cancellation or after successful posting.
    @Environment(\.dismiss) private var dismiss

    /// Environment action used to open the account creation form in a new window.
    ///
    /// Called when the user taps "New Account…" in a split line picker. Opens a window
    /// with ``AccountFormWindowPayload`` that optionally pre-fills the account name with
    /// the user's search text.
    @Environment(\.openWindow) private var openWindow

    /// View model managing form state, validation, balance computation, and submission.
    ///
    /// Handles:
    /// - Split line management (add, remove, populate)
    /// - Balance calculations (total debits, credits, imbalance)
    /// - Auto-balance logic
    /// - Validation rules (minimum splits, balance check, account assignment)
    /// - Transaction submission via API
    @State private var viewModel = PostTransactionViewModel()

    /// Live account tree — seeded from `allAccounts` at init, refreshed on `.accountSaved`.
    ///
    /// Stored as `@State` so the picker updates immediately when a new account is
    /// created via the "New Account…" option without reopening the sheet.
    ///
    /// Refreshed by fetching from ``AccountService`` and rebuilding the tree when
    /// `.accountSaved` notifications are received for this ledger.
    @State private var currentAccounts: [AccountNode]

    /// Live path map — seeded from `accountPaths` at init, rebuilt when `currentAccounts` refreshes.
    ///
    /// Maps account UUIDs to GnuCash-style full paths (e.g., "Assets:Cash:Checking").
    /// Automatically regenerated via ``AccountTreeBuilder/buildPathMap(from:)`` whenever
    /// `currentAccounts` is updated, ensuring pickers always display current paths.
    @State private var currentPaths: [UUID: String]
    
    // FIx: Add alongside currentAccounts and currentPaths
    @State private var currentPayees: [PayeeResponse] = []
    @State private var selectedPayee: PayeeResponse? = nil
    @State private var usePayee: Bool = false

    // MARK: - Init

    /// Creates the view, seeding live account state from the values provided by the parent.
    ///
    /// The account tree and path map are captured at initialization and stored in local
    /// state (`currentAccounts` and `currentPaths`). This allows the view to maintain
    /// its own copy that can be refreshed independently when `.accountSaved` notifications
    /// are received.
    ///
    /// - Parameters:
    ///   - ledger: The ledger context for currency info and transaction posting.
    ///   - allAccounts: Initial account tree hierarchy (captured in state).
    ///   - accountPaths: Initial UUID-to-path mapping (captured in state).
    ///   - onSuccess: Async callback to invoke after successful posting.
    ///
    /// - Note: The `@State` properties are initialised here so they hold a mutable copy
    ///   that can be updated independently of the parent's bindings when new accounts
    ///   are created. Updates to the parent's `allAccounts` and `accountPaths` after init
    ///   have no effect — only `.accountSaved` notifications trigger refreshes.
    init(ledger: LedgerResponse,
         allAccounts: [AccountNode],
         accountPaths: [UUID: String],
         onSuccess: @escaping () async -> Void) {
        self.ledger    = ledger
        self.onSuccess = onSuccess
        _currentAccounts = State(initialValue: allAccounts)
        _currentPaths    = State(initialValue: accountPaths)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    splitsCard
                    balanceSummaryCard

                    if let error = viewModel.errorMessage {
                        errorCard(error)
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Post Transaction")
            .toolbar { toolbarContent }
        }
        .frame(minWidth: 980, minHeight: 560)
        // Dismiss sheet and trigger parent refresh on successful post
        .onChange(of: viewModel.didPost) { _, posted in
            if posted {
                Task {
                    await onSuccess()
                    dismiss()
                }
            }
        }
        // Reload account list when a new account is saved in another window.
        // Only reloads when the notification is for this ledger.
        //
        // This enables the workflow:
        // 1. User clicks "New Account…" in split line picker
        // 2. Account form opens in new window
        // 3. User creates and saves new account
        // 4. AccountFormViewModel posts .accountSaved notification
        // 5. This view fetches updated account tree
        // 6. Picker immediately shows new account
        .onReceive(NotificationCenter.default.publisher(for: .accountSaved)) { notification in
            guard let savedLedgerID = notification.object as? UUID,
                  savedLedgerID == ledger.id,
                  let token = auth.token else { return }
            Task {
                if let flat = try? await AccountService.shared.fetchAccounts(
                    ledgerID: ledger.id, token: token
                ) {
                    currentAccounts = AccountTreeBuilder.build(from: flat)
                    currentPaths    = AccountTreeBuilder.buildPathMap(from: currentAccounts)
                }
                if let payees = try? await PayeeService.shared.fetchPayees(
                    ledgerID: ledger.id, token: token) {
                    currentPayees = payees
                }
            }
        }
        .task(id: ledger.id) {
            guard let token = auth.token else { return }
            if let payees = try? await PayeeService.shared.fetchPayees(
                ledgerID: ledger.id, token: token) {
                currentPayees = payees
            }
        }
    }

    // MARK: - Header Card

    /// Transaction metadata inputs: posting date, memo, and optional reference number.
    ///
    /// Displays editable controls for:
    /// - **Date**: `DatePicker` with date and time components (when the transaction occurred).
    /// - **Description**: `TextField` bound to `viewModel.memo` (transaction description).
    /// - **Reference #**: Optional text field for check numbers, invoice numbers, etc.
    ///
    /// All fields are editable and updates flow immediately to the view model.
    private var headerCard: some View {
        card(title: "Transaction Details") {
            VStack(alignment: .leading, spacing: 12) {
                compactLabeledRow("Date") {
                    DatePicker(
                        "",
                        selection: $viewModel.postDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .frame(maxWidth: 280, alignment: .leading)
                }

                compactLabeledRow("Description") {
                    TextField("Description (memo)", text: $viewModel.memo)
                        .textFieldStyle(.roundedBorder)
                }

                compactLabeledRow("Reference #") {
                    TextField("Reference # (optional)", text: $viewModel.num)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Payee toggle + picker
                compactLabeledRow("Payee") {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $usePayee)
                            .labelsHidden()
                            .onChange(of: usePayee) { _, on in
                                if !on { selectedPayee = nil }
                            }
                        if usePayee {
                            PayeePickerButton(
                                selectedPayee: $selectedPayee,
                                payees: currentPayees,
                                onCreate: { name in
                                    Task {
                                        guard let token = auth.token else { return }
                                        if let created = try? await PayeeService.shared.createPayee(
                                            ledgerID: ledger.id,
                                            name: name,
                                            token: token
                                        ) {
                                            currentPayees.append(created)
                                            currentPayees.sort { $0.name < $1.name }
                                            selectedPayee = created
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Splits Card

    /// Form section displaying the split lines with column headers and add button.
    ///
    /// - **Column headers**: Show "Memo", "Account", "Debit", "Credit", and delete column
    ///   (rendered by `splitColumnHeader`).
    /// - **Split rows**: One ``SplitLineRow`` per entry in `viewModel.splits`, each with
    ///   account picker, memo field, and debit/credit amount fields.
    /// - **Add button**: Appends a new empty split line; no upper limit.
    /// - **Auto-balance**: Header button that calls `viewModel.autoBalance()` to fill the
    ///   imbalance into the last split line. Disabled when `viewModel.isBalanced` is `true`.
    ///
    /// The account list passed to each row is filtered to non-placeholder leaves via
    /// ``leafAccounts``. When a user creates a new account via "New Account…", the section
    /// automatically updates via the `.accountSaved` notification handler in `body`.
    private var splitsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    Text("Splits")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Button("Auto-balance") {
                        viewModel.autoBalance()
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isBalanced)
                }

                // Column Header
                splitColumnHeader

                // Split rows
                VStack(spacing: 8) {
                    ForEach($viewModel.splits) { $line in
                        SplitLineRow(
                            line: $line,
                            allAccounts: leafAccounts,
                            accountPaths: currentPaths,
                            onDebitEdited: { viewModel.didEditDebit(for: line.id) },
                            onCreditEdited: { viewModel.didEditCredit(for: line.id) },
                            onDelete: { viewModel.removeSplitLine(id: line.id) },
                            canDelete: viewModel.splits.count > 2,
                            onCreateAccount: { suggestedName in
                                openWindow(value: AccountFormWindowPayload(
                                    ledger: ledger,
                                    existingAccount: nil,
                                    suggestedParentId: nil,
                                    suggestedName: suggestedName.isEmpty ? nil : suggestedName
                                ))
                            }
                        )
                    }
                }

                // Add line button
                Button {
                    viewModel.addSplitLine()
                } label: {
                    Label("Add Split Line", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            }
        }
    }

    /// Static column header row rendered above the split lines.
    ///
    /// Labels — "Memo", "Account", "Debit", "Credit" — are aligned to match the
    /// fixed and flexible column widths used by each ``SplitLineRow``. A `Color.clear`
    /// spacer at the trailing edge aligns with the delete button column.
    private var splitColumnHeader: some View {
        HStack(spacing: 8) {
            Text("Memo")
                .frame(minWidth: 160, idealWidth: 220, maxWidth: 260, alignment: .leading)

            Text("Account")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Debit")
                .frame(width: 110, alignment: .trailing)

            Text("Credit")
                .frame(width: 110, alignment: .trailing)

            Color.clear
                .frame(width: 24)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Balance Summary

    /// Summary section showing total debits, credits, and balance status.
    ///
    /// Layout (left → center → right):
    /// - **Left**: Total debits formatted via `AmountFormatter`.
    /// - **Center**: Balance status indicator —
    ///   green checkmark badge (`viewModel.isBalanced == true`) or
    ///   red imbalance amount (`abs(viewModel.imbalance)`).
    /// - **Right**: Total credits formatted via `AmountFormatter`.
    ///
    /// All amounts use `ledger.currencyCode` and `ledger.decimalPlaces`.
    /// This section updates in real-time as the user edits split amounts.
    private var balanceSummaryCard: some View {
        card {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Debits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AmountFormatter.format(
                        viewModel.totalDebits,
                        currencyCode: ledger.currencyCode,
                        decimalPlaces: ledger.decimalPlaces
                    ))
                    .font(.title3.monospacedDigit())
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    if viewModel.isBalanced {
                        Label("Balanced", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    } else {
                        VStack(spacing: 2) {
                            Text("Imbalance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(AmountFormatter.format(
                                abs(viewModel.imbalance),
                                currencyCode: ledger.currencyCode,
                                decimalPlaces: ledger.decimalPlaces
                            ))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Credits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AmountFormatter.format(
                        viewModel.totalCredits,
                        currencyCode: ledger.currencyCode,
                        decimalPlaces: ledger.decimalPlaces
                    ))
                    .font(.title3.monospacedDigit())
                }
            }
        }
    }

    // MARK: - Error Card

    /// Renders a card containing a red error caption.
    ///
    /// Shown below the balance summary when `viewModel.errorMessage` is non-nil.
    /// The card is omitted entirely when there is no error — it is not pre-allocated.
    ///
    /// - Parameter error: The error string to display.
    /// - Returns: A card view with the error message styled in red caption text.
    private func errorCard(_ error: String) -> some View {
        card {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    // MARK: - Toolbar

    /// Toolbar providing **Cancel** and **Post** actions.
    ///
    /// - **Cancel** (`cancellationAction`): Dismisses the sheet without saving.
    /// - **Post** (`confirmationAction`): Calls `viewModel.submit(ledger:token:)` and
    ///   shows a `ProgressView` spinner while `viewModel.isSubmitting` is `true`.
    ///
    /// The Post button is disabled when `viewModel.canSubmit` is `false`, which occurs when:
    /// - The transaction is not balanced (debits ≠ credits)
    /// - Fewer than 2 split lines exist
    /// - Any split is missing an account assignment
    /// - No split has a non-zero amount
    /// - Submission is already in progress
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    guard let token = auth.token else { return }
                    await viewModel.submit(ledger: ledger, payeeId: selectedPayee?.id,token: token)
                }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Post")
                }
            }
            .disabled(!viewModel.canSubmit)
        }
    }

    // MARK: - Helpers


    /// Renders a horizontal label-plus-content row used in the transaction header card.
    ///
    /// The label is fixed at 110 pt wide and left-aligned; the content fills the
    /// remaining width. Used for Date, Description, and Reference # fields.
    ///
    /// - Parameters:
    ///   - title: The label text displayed to the left of the control.
    ///   - content: The input control (e.g., `DatePicker`, `TextField`).
    /// - Returns: An `HStack` pairing the label with the provided content.
    private func compactLabeledRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.body)
                .frame(width: 110, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Wraps content in a rounded-rectangle card with an optional title heading.
    ///
    /// All section cards in `body` (`headerCard`, `splitsCard`, `balanceSummaryCard`,
    /// `errorCard`) are built with this helper to ensure consistent padding, background
    /// color, corner radius, and separator border.
    ///
    /// - Parameters:
    ///   - title: Optional section heading rendered as `.title3.weight(.semibold)` above the content.
    ///   - content: The card body view.
    /// - Returns: A styled card view.
    private func card<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.title3.weight(.semibold))
            }

            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    /// Recursively collects all postable (non-placeholder) accounts from `currentAccounts`.
    ///
    /// Placeholder accounts are organisational containers that cannot receive transaction
    /// postings. This computed property recursively walks `currentAccounts` and returns
    /// only concrete leaf accounts eligible for assignment to split lines.
    ///
    /// Non-placeholder nodes that also have children are included — a non-placeholder
    /// parent can itself receive postings while still grouping child accounts.
    ///
    /// - Returns: A flat `[AccountNode]` array suitable for display in split-line pickers.
    ///
    /// - Note: Re-evaluated each time split rows are rendered, but the operation is
    ///   efficient since account trees are typically small (hundreds of nodes, not thousands).
    private var leafAccounts: [AccountNode] {
        func collectLeaves(_ nodes: [AccountNode]) -> [AccountNode] {
            nodes.flatMap { node in
                node.isPlaceholder ? collectLeaves(node.children)
                                   : [node] + collectLeaves(node.children)
            }
        }
        return collectLeaves(currentAccounts)
    }
}

// MARK: - Split Line Row

/// A view representing a single split line in the transaction posting form.
///
/// `SplitLineRow` provides a horizontal layout with all controls needed to define
/// one split line of a double-entry transaction:
/// - Memo field (split-specific note)
/// - Account picker (expandable dropdown with search)
/// - Debit amount field
/// - Credit amount field
/// - Delete button (disabled when fewer than 3 splits exist)
///
/// ## Features
///
/// - **Account picker**: Searchable dropdown with GnuCash-style full paths.
/// - **New Account option**: "New Account…" button at the bottom of the picker opens
///   the account creation form; receives the current search text as the suggested name.
/// - **Debit/Credit exclusivity**: The parent view model clears the opposite field
///   when one is edited (`onDebitEdited` / `onCreditEdited` callbacks).
/// - **Delete protection**: The delete button is disabled when `canDelete` is `false`
///   (i.e., only 2 split lines remain, which is the minimum required for balance).
/// - **Callback integration**: Notifies ``PostTransactionView`` of edits via closures
///   so balance totals update in real time.
///
/// ## Layout
///
/// ```
/// ┌──────────────┬─────────────┬────────┬────────┬────┐
/// │    Memo      │   Account   │  Debit │ Credit │ ❌ │
/// │  text field  │ (expandable)│  text  │  text  │    │
/// └──────────────┴─────────────┴────────┴────────┴────┘
/// ```
///
/// - Note: This is a private component used exclusively by ``PostTransactionView``.
/// - SeeAlso: ``SplitLine``, ``AccountFormWindowPayload``
private struct SplitLineRow: View {

    /// Binding to the split line being edited.
    @Binding var line: SplitLine
    
    /// All leaf (non-placeholder) accounts available for selection.
    let allAccounts: [AccountNode]
    
    /// Mapping of account UUIDs to full hierarchical paths for display.
    let accountPaths: [UUID: String]
    
    /// Callback invoked when the debit amount field is edited.
    let onDebitEdited: () -> Void
    
    /// Callback invoked when the credit amount field is edited.
    let onCreditEdited: () -> Void
    
    /// Callback invoked when the delete button is tapped.
    let onDelete: () -> Void
    
    /// Whether this split can be deleted (false when only 2 splits remain).
    let canDelete: Bool

    /// Optional callback invoked when the user taps "New Account…" in the picker.
    /// Receives the current search text as the suggested account name.
    var onCreateAccount: ((String) -> Void)? = nil

    /// Current text in the account picker search field.
    ///
    /// Cleared automatically when the picker opens or after an account is selected.
    /// Also passed to `onCreateAccount` as the suggested name when "New Account…" is tapped.
    @State private var searchText = ""

    /// Whether the account picker dropdown is currently expanded.
    ///
    /// Toggled by the picker button. Collapses automatically after account selection
    /// or when "New Account…" is tapped.
    @State private var isPickerExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("", text: $line.memo)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)

            accountPickerButton
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: $line.debitAmount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: line.debitAmount) { _, _ in onDebitEdited() }

            TextField("", text: $line.creditAmount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: line.creditAmount) { _, _ in onCreditEdited() }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(canDelete ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .frame(width: 24, alignment: .center)
            .padding(.top, 6)
        }
    }

    // MARK: - Account Picker Button

    /// Expandable account picker button with search and optional "New Account…" entry.
    ///
    /// - **Collapsed**: Shows the selected account's full GnuCash-style path
    ///   (from `accountPaths`) or a "Select account…" placeholder.
    /// - **Expanded**: Shows a search field, a scrollable `LazyVStack` of
    ///   ``filteredAccounts`` rendered as ``AccountPickerRow`` entries, and — when
    ///   `onCreateAccount` is non-nil — a "New Account…" row at the bottom.
    ///
    /// The picker collapses and clears `searchText` after an account is selected or
    /// after "New Account…" is tapped. The dropdown uses `zIndex(100)` to float
    /// above sibling rows in the splits list.
    private var accountPickerButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isPickerExpanded.toggle()
                if isPickerExpanded { searchText = "" }
            } label: {
                HStack(spacing: 8) {
                    if let account = line.account {
                        Text(accountPaths[account.id] ?? account.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    } else {
                        Text("Select account…")
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isPickerExpanded {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search accounts…", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredAccounts) { account in
                                AccountPickerRow(
                                    account: account,
                                    fullPath: accountPaths[account.id]
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    line.account = account
                                    isPickerExpanded = false
                                    searchText = ""
                                }
                                Divider().padding(.leading, 12)
                            }

                            // ── "New Account…" option ─────────────────────
                            // Displays at bottom of picker list if callback is provided.
                            // Shows search text in button if user has typed something,
                            // e.g., "New Account \"Savings\""... or just "New Account..."
                            // if search is empty.
                            if let onCreateAccount {
                                Divider()
                                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text(trimmed.isEmpty
                                         ? "New Account..."
                                         : "New Account \"\(trimmed)\"...")
                                        .foregroundStyle(Color.accentColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let name = searchText.trimmingCharacters(in: .whitespaces)
                                    isPickerExpanded = false
                                    searchText = ""
                                    onCreateAccount(name)
                                }
                            }
                            // ─────────────────────────────────────────────
                        }
                    }
                    .frame(maxHeight: 220)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .shadow(radius: 4, y: 2)
                .zIndex(100)
            }
        }
    }

    // MARK: - Filtered Accounts

    /// Filters `allAccounts` against the current `searchText`.
    ///
    /// Performs a case-insensitive substring search across three fields per account:
    /// - Full GnuCash-style path from `accountPaths` (falls back to `account.name`)
    /// - `account.code` (if present)
    /// - `account.accountTypeCode` (if present)
    ///
    /// Returns `allAccounts` unfiltered when `searchText` is empty or whitespace-only.
    ///
    /// - Returns: The subset of `allAccounts` whose path, code, or type code matches the query.
    private var filteredAccounts: [AccountNode] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allAccounts }
        return allAccounts.filter { account in
            let path = accountPaths[account.id] ?? account.name
            return path.lowercased().contains(query)
                || (account.code?.lowercased().contains(query) ?? false)
                || (account.accountTypeCode?.lowercased().contains(query) ?? false)
        }
    }
}

// MARK: - Account Picker Row

/// A single row in the account picker dropdown inside ``SplitLineRow``.
///
/// Composes three elements:
/// 1. A color-coded **kind dot** (same scheme as ``AccountRowView``).
/// 2. The **full hierarchical path** as body text, truncated from the leading edge
///    (`.truncationMode(.head)`) so the leaf name always remains visible.
///    Falls back to `account.name` when `fullPath` is `nil`.
/// 3. The **account type code** as tertiary caption below the path.
///
/// ## Kind Color Legend
///
/// | Kind | Color  | Classification |
/// |------|--------|----------------|
/// | 1    | Blue   | Asset          |
/// | 2    | Red    | Liability      |
/// | 3    | Purple | Equity         |
/// | 4    | Green  | Income         |
/// | 5    | Orange | Expense        |
/// | other| Gray   | Other / System |
///
/// - Note: This is a private component used exclusively by ``SplitLineRow``.
/// - SeeAlso: ``AccountNode``, ``SplitLineRow``
private struct AccountPickerRow: View {

    /// The account to display.
    let account: AccountNode
    
    /// Optional full hierarchical path (e.g., "Assets:Current Assets:Checking").
    /// Falls back to account name if unavailable.
    var fullPath: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kindColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                if let path = fullPath {
                    Text(path)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.head)
                } else {
                    Text(account.name)
                        .font(.body)
                        .lineLimit(1)
                }
                if let typeCode = account.accountTypeCode {
                    Text(typeCode)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    /// Returns the color for the account's kind indicator dot.
    private var kindColor: Color {
        switch account.account.kind {
        case 1:  return .blue    // Asset
        case 2:  return .red     // Liability
        case 3:  return .purple  // Equity
        case 4:  return .green   // Income
        case 5:  return .orange  // Expense
        default: return .gray    // Other/System
        }
    }
}

