//
//  Features/Transactions/PostTransactionView.swift
//  PostTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-03-26.
//  Developed with AI assistance.
//

import SwiftUI

/**
 Form view for creating a new multi-split double-entry accounting transaction.

 `PostTransactionView` provides a complete data-entry interface for posting a transaction
 to a ledger. It enforces double-entry bookkeeping rules throughout: the form cannot be
 submitted until total debits equal total credits across all split lines.

 # Features

 - **Transaction header**: Date picker, free-text memo, and optional reference number
 - **Dynamic split management**: Add or remove split lines freely; minimum of 2 enforced
 - **Account picker**: Per-split expandable dropdown with real-time search, GnuCash-style
   full-path labels (e.g., `"Assets:Current Assets:Cash:Checking"`), and kind-color dots
 - **New Account on-the-fly**: The account picker offers a "New Account…" option that
   opens the account creation form in a new window. The picker refreshes automatically
   when the new account is saved via `NotificationCenter`
 - **Live account list**: Automatically refreshes when accounts are saved in other windows
 - **Balance summary**: Live debit/credit totals with a green "Balanced" badge or a red
   imbalance amount
 - **Auto-balance**: One-tap button fills the last split line with the amount needed to
   bring the transaction into balance
 - **Submission guard**: The "Post" button is disabled until `viewModel.canSubmit` is `true`
   (balanced, all splits complete, not already submitting)
 - **Error display**: Inline red caption below the form when `viewModel.errorMessage` is set

 # Account Labels (GnuCash-style paths)

 `accountPaths` is a `[UUID: String]` dictionary built by `AccountTreeBuilder.buildPathMap(from:)`.
 It is threaded through to each `SplitLineRow` → `accountPickerButton` and `AccountPickerRow`
 so that both the collapsed button label and every dropdown row show the full ancestor path
 rather than a bare account name or truncated code. The leaf name is always visible because
 long paths are truncated from the leading edge (`.truncationMode(.head)`).

 # Account List Refresh

 The view maintains live `currentAccounts` and `currentPaths` state that is automatically
 refreshed when `.accountSaved` notifications are received. This enables the workflow:

 1. User opens transaction posting form
 2. User clicks "New Account…" in a split line picker
 3. Account form opens in new window, user creates account
 4. `AccountFormViewModel` posts `.accountSaved` notification
 5. This view receives notification, fetches updated account tree
 6. Split line pickers immediately show the new account

 No reopening of the sheet is required — accounts appear immediately.

 # Layout

 ```
 NavigationStack
 └─ Form (grouped)
    ├─ Section "Transaction Details"  — date, memo, ref #
    ├─ Section "Splits"               — column headers + SplitLineRow × n + Add button
    ├─ Section (balance summary)      — total debits | status | total credits
    └─ Section (error)                — shown only when errorMessage ≠ nil
 ```

 # Usage Example

 ```swift
 PostTransactionView(
     ledger: selectedLedger,
     allAccounts: allAccountRoots,
     accountPaths: accountPaths,
     onSuccess: {
         guard let token = auth.token else { return }
         await viewModel.load(ledger: ledger, account: account, token: token)
     }
 )
 .environment(auth)
 ```

 # Double-Entry Validation

 The form enforces fundamental accounting rules:
 - Minimum 2 splits required (one debit, one credit at minimum)
 - Total debits must equal total credits (checked in real-time)
 - All splits must have an account assigned
 - At least one split must have a non-zero amount

 The "Post" button remains disabled until all validation passes.

 - Important: All splits must balance (total debits = total credits) before the "Post"
   button becomes active.
 - Note: Requires `AuthService` in the SwiftUI environment. The token is read from
   `auth.token` at the moment the "Post" button is tapped.
 - SeeAlso: `PostTransactionViewModel`, `SplitLineRow`, `AccountPickerRow`,
   `AccountTreeBuilder.buildPathMap(from:)`, `Notification.Name.accountSaved`
 */
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
    /// with `AccountFormWindowPayload` that optionally pre-fills the account name with
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
    /// Refreshed by fetching from `AccountService` and rebuilding the tree when
    /// `.accountSaved` notifications are received for this ledger.
    @State private var currentAccounts: [AccountNode]

    /// Live path map — seeded from `accountPaths` at init, rebuilt when `currentAccounts` refreshes.
    ///
    /// Maps account UUIDs to GnuCash-style full paths (e.g., "Assets:Cash:Checking").
    /// Automatically regenerated via `AccountTreeBuilder.buildPathMap()` whenever
    /// `currentAccounts` is updated, ensuring pickers always display current paths.
    @State private var currentPaths: [UUID: String]

    // MARK: - Init

    /**
     Creates the view, seeding live account state from the values provided by the parent.
     
     The account tree and path map are captured at initialization and stored in local
     state (`currentAccounts` and `currentPaths`). This allows the view to maintain
     its own copy that can be refreshed independently when `.accountSaved` notifications
     are received.
     
     - Parameters:
       - ledger: The ledger context for currency info and transaction posting
       - allAccounts: Initial account tree hierarchy (captured in state)
       - accountPaths: Initial UUID-to-path mapping (captured in state)
       - onSuccess: Async callback to invoke after successful posting
     
     - Note: The `@State` properties are initialised here so they hold a mutable copy
       that can be updated independently of the parent's bindings when new accounts
       are created. Updates to the parent's `allAccounts` and `accountPaths` after init
       have no effect — only `.accountSaved` notifications trigger refreshes.
     */
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
            Form {
                headerSection
                splitsSection
                balanceSummary
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Post Transaction")
            .toolbar { toolbarContent }
        }
        .frame(minWidth: 700, minHeight: 520)
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
            }
        }
    }

    // MARK: - Header Section

    /**
     Transaction metadata inputs: posting date, memo, and optional reference number.
     
     Displays editable controls for:
     - **Date**: DatePicker with date and time components (when the transaction occurred)
     - **Description**: TextField bound to `viewModel.memo` (transaction description)
     - **Reference #**: Optional text field for check numbers, invoice numbers, etc.
     
     All fields are editable and updates flow immediately to the view model.
     */
    private var headerSection: some View {
        Section("Transaction Details") {
            DatePicker(
                "Date",
                selection: $viewModel.postDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            TextField("Description (memo)", text: $viewModel.memo)
            TextField("Reference # (optional)", text: $viewModel.num)
        }
    }

    // MARK: - Splits Section

    /**
     Form section displaying the split lines with column headers and add button.
     
     Features:
     - **Column headers**: Show "Account", "Memo", "Debit", "Credit", and delete column
     - **Split rows**: Each `SplitLineRow` with account picker, memo field, amount fields
     - **Add button**: Creates new split lines (no upper limit)
     - **Auto-balance**: Section header button to automatically balance the transaction
     
     The account list is filtered to leaf accounts only (non-placeholders) via the
     `leafAccounts` computed property. When a user creates a new account via the
     "New Account..." option, this section automatically updates via the `.accountSaved`
     notification handler.
     
     The auto-balance button is disabled when the transaction is already balanced.
     */
    private var splitsSection: some View {
        Section {
            // Column header
            HStack(spacing: 0) {
                Text("Account")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Memo")
                    .frame(width: 140, alignment: .leading)
                Text("Debit")
                    .frame(width: 110, alignment: .trailing)
                Text("Credit")
                    .frame(width: 110, alignment: .trailing)
                Spacer().frame(width: 32)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            // Split rows
            ForEach($viewModel.splits) { $line in
                SplitLineRow(
                    line: $line,
                    allAccounts: leafAccounts,
                    accountPaths: currentPaths,
                    onDebitEdited:  { viewModel.didEditDebit(for: line.id) },
                    onCreditEdited: { viewModel.didEditCredit(for: line.id) },
                    onDelete:       { viewModel.removeSplitLine(id: line.id) },
                    canDelete:       viewModel.splits.count > 2,
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

            // Add line button
            Button {
                viewModel.addSplitLine()
            } label: {
                Label("Add Split Line", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 4)

        } header: {
            HStack {
                Text("Splits")
                Spacer()
                Button("Auto-balance") {
                    viewModel.autoBalance()
                }
                .font(.caption)
                .disabled(viewModel.isBalanced)
            }
        }
    }

    // MARK: - Balance Summary

    /**
     Summary section showing total debits, credits, and balance status.
     
     Layout:
     - **Left**: Total debits with label
     - **Center**: Balance status indicator
       - Green checkmark badge when balanced
       - Red imbalance amount when not balanced
     - **Right**: Total credits with label
     
     All amounts are formatted using the ledger's currency code and decimal places.
     This section updates in real-time as the user edits split amounts.
     */
    private var balanceSummary: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Debits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AmountFormatter.format(
                        viewModel.totalDebits,
                        currencyCode: ledger.currencyCode,
                        decimalPlaces: ledger.decimalPlaces
                    ))
                    .font(.body.monospacedDigit())
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    if viewModel.isBalanced {
                        Label("Balanced", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption.bold())
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
                            .font(.caption.bold().monospacedDigit())
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
                    .font(.body.monospacedDigit())
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toolbar

    /**
     Toolbar with cancel and post actions.
     
     - **Cancel**: Dismisses the sheet without saving
     - **Post**: Submits transaction via view model, shows spinner during submission
     
     The post button is disabled when `viewModel.canSubmit` is false, which occurs when:
     - Transaction is not balanced (debits ≠ credits)
     - Fewer than 2 splits exist
     - Any split is missing an account assignment
     - No split has a non-zero amount
     - Submission is already in progress
     */
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    guard let token = auth.token else { return }
                    await viewModel.submit(ledger: ledger, token: token)
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

    /**
     Recursively collects all postable (non-placeholder) accounts from `currentAccounts`.
     
     Placeholder accounts are organizational containers that cannot have transactions
     posted to them. This method recursively filters the account tree to return only
     accounts that can be assigned to split lines.
     
     - Returns: Flat array of leaf `AccountNode` values suitable for picker display
     
     - Note: Called each time split rows are rendered, but the operation is efficient
       since account trees are typically small (hundreds of nodes, not thousands).
     */
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

/**
 A view representing a single split line in the transaction posting form.
 
 `SplitLineRow` provides a horizontal layout with all controls needed to define
 one split line of a double-entry transaction:
 - Account picker (expandable dropdown with search)
 - Memo field (split-specific note)
 - Debit amount field
 - Credit amount field  
 - Delete button (disabled when < 3 splits exist)
 
 ## Features
 
 - **Account picker**: Searchable dropdown with GnuCash-style full paths
 - **New Account option**: "New Account…" button opens creation form
 - **Debit/Credit exclusivity**: View model clears opposite field when one is edited
 - **Delete protection**: Cannot delete split when only 2 remain (minimum for balance)
 - **Callback integration**: Notifies parent of edits for balance recalculation
 
 ## Layout
 
 ```
 ┌──────────────┬────────┬────────┬────────┬────┐
 │ Account      │  Memo  │  Debit │ Credit │ ❌ │
 │ (expandable) │  text  │  text  │  text  │    │
 └──────────────┴────────┴────────┴────────┴────┘
 ```
 
 - Note: This is a private component used exclusively by `PostTransactionView`.
 - SeeAlso: `SplitLine`, `AccountFormWindowPayload`
 */
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

    @State private var searchText = ""
    @State private var isPickerExpanded = false

    var body: some View {
        HStack(spacing: 8) {
            accountPickerButton
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Memo", text: $line.memo)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)

            TextField("0.00", text: $line.debitAmount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: line.debitAmount) { _, _ in onDebitEdited() }

            TextField("0.00", text: $line.creditAmount)
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
            .frame(width: 24)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Account Picker Button

    /**
     Expandable account picker button with search and new account options.
     
     When collapsed, shows the currently selected account's full path or a
     placeholder prompt. When expanded, displays a search field and scrollable
     list of filtered accounts, plus a "New Account…" option if the callback
     is provided.
     
     The picker automatically collapses after selecting an account or creating
     a new one, and clears the search field for the next use.
     */
    private var accountPickerButton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isPickerExpanded.toggle()
                if isPickerExpanded { searchText = "" }
            } label: {
                HStack {
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
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isPickerExpanded {
                VStack(spacing: 0) {
                    HStack {
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4, y: 2)
                .zIndex(100)
            }
        }
    }

    // MARK: - Filtered Accounts

    /**
     Filters accounts based on search query.
     
     Performs case-insensitive search against:
     - Account full path (e.g., "Assets:Cash:Checking")
     - Account code (if present)
     - Account type code (if present)
     
     Returns all accounts when search is empty.
     */
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

/**
 A single row in the account picker dropdown.
 
 Displays an account with:
 - Color-coded kind indicator dot
 - Full hierarchical path as primary text (or account name if path unavailable)
 - Account type code as secondary text
 
 The kind indicator uses the standard color scheme:
 - Blue: Asset
 - Red: Liability
 - Purple: Equity
 - Green: Income
 - Orange: Expense
 - Gray: Other/System
 
 - Note: This is a private component used by `SplitLineRow`.
 */
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
