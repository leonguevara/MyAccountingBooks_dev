//
//  Features/Transactions/EditTransactionView.swift
//  EditTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Last modified by León Felipe Guevara Chávez on 2026-03-26.
//  Developed with AI assistance.
//

import SwiftUI

/// A SwiftUI view for editing an existing transaction in the accounting system.
///
/// `EditTransactionView` provides a modal sheet interface that allows users to modify
/// transaction details including the memo, number, posting date, and individual split
/// line properties. The view implements efficient PATCH semantics, sending only changed
/// fields to the server to minimize network payload and preserve unchanged data.
///
/// ## Features
///
/// - **Transaction header editing**: Modify memo, number, and posting date
/// - **Split line editing**: Change account assignments and split-specific memos
/// - **Smart account picker**: Searchable dropdown with full account paths
/// - **New Account on-the-fly**: "New Account…" option opens account creation in a new
///   window. The picker refreshes immediately via `NotificationCenter` when saved.
/// - **Live account list**: Automatically refreshes when accounts are saved in other windows
/// - **Efficient updates**: Only sends modified fields via PATCH request
/// - **Error handling**: Displays user-friendly error messages
/// - **Loading states**: Shows progress indicator during submission
/// - **Automatic dismissal**: Closes and triggers refresh on successful save
///
/// ## Usage
///
/// Present this view as a sheet when the user taps "Edit" on a transaction:
///
/// ```swift
/// .sheet(isPresented: $showEditTransaction) {
///     EditTransactionView(
///         transaction: selectedTransaction,
///         ledger: currentLedger,
///         allAccounts: chartOfAccounts,
///         accountPaths: accountPathDictionary,
///         onSuccess: {
///             await refreshTransactions()
///         }
///     )
/// }
/// ```
///
/// ## Account List Refresh
///
/// The view maintains live `currentAccounts` and `currentPaths` state that is automatically
/// refreshed when `.accountSaved` notifications are received. This ensures that:
///
/// - Users can create accounts while editing a transaction
/// - New accounts appear immediately in the split line pickers
/// - The account hierarchy stays synchronized across windows
///
/// The refresh flow:
/// 1. User opens transaction edit view
/// 2. User clicks "New Account…" in split line picker
/// 3. Account form opens in new window, user creates account
/// 4. `AccountFormViewModel` posts `.accountSaved` notification
/// 5. This view receives notification, fetches updated account tree
/// 6. Split line pickers immediately show the new account
///
/// ## PATCH Semantics
///
/// Only fields that have changed are included in the PATCH request:
/// - Transaction header: memo, num, postDate
/// - Split lines: account assignment, split memo
///
/// Unchanged fields are omitted, preserving server state for concurrent edits.
///
/// - Note: Designed for macOS with a minimum window size of 620×480 points.
/// - Important: Requires `AuthService` in the SwiftUI environment for API authentication.
/// - SeeAlso: `EditTransactionViewModel`, `EditSplitLine`, `TransactionDetailSheet`,
///   `AccountFormWindowPayload`, `Notification.Name.accountSaved`
struct EditTransactionView: View {

    // MARK: - Properties

    /// The transaction being edited, containing original values for comparison.
    ///
    /// Used by the view model to determine which fields have changed and need to
    /// be included in the PATCH request.
    let transaction: TransactionResponse
    
    /// The ledger context, providing currency and decimal place information.
    ///
    /// Used when creating new accounts and for identifying which ledger's accounts
    /// should be refreshed when receiving `.accountSaved` notifications.
    let ledger: LedgerResponse
    
    /// Callback invoked after successfully saving the transaction.
    ///
    /// Typically used by the parent view to refresh its transaction list. Called
    /// before the sheet is dismissed, allowing the parent to reload data while
    /// the loading indicator is still visible.
    ///
    /// Example:
    /// ```swift
    /// EditTransactionView(
    ///     transaction: txn,
    ///     ledger: ledger,
    ///     allAccounts: accounts,
    ///     accountPaths: paths,
    ///     onSuccess: {
    ///         await viewModel.loadTransactions()
    ///     }
    /// )
    /// ```
    let onSuccess: () async -> Void

    // MARK: - Environment

    /// Authentication service providing the bearer token for API requests.
    @Environment(AuthService.self) private var auth
    
    /// SwiftUI dismiss action used to close the sheet after saving or canceling.
    @Environment(\.dismiss) private var dismiss

    /// Environment action used to open the account creation form in a new window.
    ///
    /// Called when the user taps "New Account…" in a split line picker. Opens a
    /// window with `AccountFormWindowPayload` that optionally pre-fills the account
    /// name with the user's search text.
    @Environment(\.openWindow) private var openWindow

    // MARK: - State

    /// View model managing form state, validation, and submission logic.
    ///
    /// Populated in `.onAppear` with the original transaction values and updated
    /// as the user modifies fields. Handles PATCH request construction and submission.
    @State private var viewModel = EditTransactionViewModel()

    /// Live account tree — seeded from `allAccounts` at init, refreshed on `.accountSaved`.
    ///
    /// Maintained as local state to support immediate updates when new accounts are
    /// created in other windows. Refreshed by fetching from `AccountService` and
    /// rebuilding the tree when `.accountSaved` notifications are received for this ledger.
    @State private var currentAccounts: [AccountNode]

    /// Live path map — seeded from `accountPaths` at init, rebuilt when `currentAccounts` refreshes.
    ///
    /// Maps account UUIDs to GnuCash-style full paths (e.g., "Assets:Cash:Checking").
    /// Automatically regenerated via `AccountTreeBuilder.buildPathMap()` whenever
    /// `currentAccounts` is updated, ensuring pickers always display current paths.
    @State private var currentPaths: [UUID: String]

    // MARK: - Init

    /**
     Creates a new edit transaction view with initial account data.
     
     The account tree and path map are captured at initialization and stored in local
     state (`currentAccounts` and `currentPaths`). This allows the view to maintain
     its own copy that can be refreshed independently when `.accountSaved` notifications
     are received.
     
     - Parameters:
       - transaction: The transaction to edit, containing original field values
       - ledger: The ledger context for currency info and account filtering
       - allAccounts: Initial account tree hierarchy (captured in state)
       - accountPaths: Initial UUID-to-path mapping (captured in state)
       - onSuccess: Async callback to invoke after successful save
     
     - Note: The `allAccounts` and `accountPaths` parameters seed local state but are
       not retained directly. Updates to these parameters after init have no effect —
       only `.accountSaved` notifications trigger refreshes.
     */
    init(transaction: TransactionResponse,
         ledger: LedgerResponse,
         allAccounts: [AccountNode],
         accountPaths: [UUID: String],
         onSuccess: @escaping () async -> Void) {
        self.transaction = transaction
        self.ledger      = ledger
        self.onSuccess   = onSuccess
        _currentAccounts = State(initialValue: allAccounts)
        _currentPaths    = State(initialValue: accountPaths)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                splitsSection
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Transaction")
            .toolbar { toolbarContent }
        }
        .frame(minWidth: 620, minHeight: 480)
        // Populate view model with original transaction values
        .onAppear {
            viewModel.populate(
                from: transaction,
                accountPaths: currentPaths,
                allAccounts: currentAccounts
            )
        }
        // Dismiss sheet and trigger parent refresh on successful save
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
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
     Form section for editing transaction-level fields.
     
     Displays editable controls for:
     - **Date**: DatePicker with date and time components
     - **Description**: TextField bound to `viewModel.memo`
     - **Reference #**: Optional text field for check numbers, invoice numbers, etc.
     
     All changes are tracked by the view model and included in the PATCH request
     only if they differ from the original transaction values.
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
     Form section displaying editable split lines.
     
     Each split line shows:
     - Account picker with search and "New Account..." option
     - Split-specific memo field
     
     The account list is filtered to leaf accounts only (non-placeholders) via
     the `leafAccounts` computed property. When a user creates a new account via
     the "New Account..." option, this section automatically updates via the
     `.accountSaved` notification handler.
     */
    private var splitsSection: some View {
        Section("Split Lines") {
            ForEach($viewModel.splitLines) { $line in
                EditSplitLineRow(
                    line: $line,
                    allAccounts: leafAccounts,
                    accountPaths: currentPaths,
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
    }

    // MARK: - Toolbar

    /**
     Toolbar with cancel and save actions.
     
     - **Cancel**: Dismisses the sheet without saving
     - **Save**: Submits changes via view model, shows spinner during submission
     
     The save button is disabled while `viewModel.isSubmitting` is true to prevent
     duplicate requests.
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
                    await viewModel.submit(
                        transaction: transaction,
                        ledger: ledger,
                        token: token
                    )
                }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .disabled(viewModel.isSubmitting)
        }
    }

    // MARK: - Helpers

    /**
     Returns only the leaf (non-placeholder) accounts from `currentAccounts`.
     
     Placeholder accounts are organizational containers that cannot have transactions
     posted to them. This method recursively filters the account tree to return only
     accounts that can be assigned to split lines.
     
     - Returns: Flat array of leaf `AccountNode` values suitable for picker display
     
     - Note: Called each time `splitsSection` is rendered, but the operation is
       efficient since account trees are typically small (hundreds of nodes, not thousands).
     */
    private var leafAccounts: [AccountNode] {
        func collectLeaves(_ nodes: [AccountNode]) -> [AccountNode] {
            nodes.flatMap { node in
                node.isPlaceholder
                    ? collectLeaves(node.children)
                    : [node] + collectLeaves(node.children)
            }
        }
        return collectLeaves(currentAccounts)
    }
}

// MARK: - Edit Split Line Row

/**
 A view representing a single editable split line within the transaction edit form.
 
 `EditSplitLineRow` provides UI controls for modifying a split's account assignment
 and memo. Features a custom account picker with search functionality and an option
 to create new accounts on the fly.
 
 ## Features
 
 - **Account picker**: Dropdown with search and full account path display
 - **New Account option**: "New Account…" button opens account creation form
 - **Search pre-fill**: Passes search text as suggested account name
 - **Split memo**: Optional text field for split-specific notes
 
 ## Account Picker Behavior
 
 The picker displays leaf accounts with:
 - Color-coded kind indicators (blue=Asset, red=Liability, etc.)
 - Full hierarchical paths (e.g., "Assets:Current Assets:Checking")
 - Account type codes as secondary text
 - Real-time search filtering on path, name, and code
 
 ## New Account Workflow
 
 When the user types in the search field and clicks "New Account…":
 1. Picker collapses and clears search text
 2. `onCreateAccount` callback fires with search text as suggested name
 3. Parent view opens account form in new window with pre-filled name
 4. User creates account and saves
 5. `.accountSaved` notification triggers account list refresh
 6. New account appears in picker immediately
 
 - Note: This is a private component used exclusively by `EditTransactionView`.
 - SeeAlso: `EditSplitLine`, `AccountFormWindowPayload`
 */
private struct EditSplitLineRow: View {

    /// Binding to the split line being edited.
    @Binding var line: EditSplitLine
    
    /// All leaf (non-placeholder) accounts available for selection.
    let allAccounts: [AccountNode]
    
    /// Mapping of account UUIDs to full hierarchical paths for display.
    let accountPaths: [UUID: String]

    /// Optional callback invoked when the user taps "New Account…" in the picker.
    /// Receives the current search text as the suggested account name.
    var onCreateAccount: ((String) -> Void)? = nil

    @State private var searchText = ""
    @State private var isPickerExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountPickerButton

            HStack {
                Text("Memo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                TextField("Split memo (optional)", text: $line.memo)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Account Picker

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
                                EditAccountPickerRow(
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
                            // e.g., "New Account \"Cash\""... or just "New Account..."
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

    /**
     Filters accounts based on search query.
     
     Performs case-insensitive search against:
     - Account full path (e.g., "Assets:Cash:Checking")
     - Account name
     - Account code (if present)
     
     Returns all accounts when search is empty.
     */
    private var filteredAccounts: [AccountNode] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allAccounts }
        return allAccounts.filter { account in
            let path = accountPaths[account.id] ?? account.name
            return path.lowercased().contains(query)
                || (account.code?.lowercased().contains(query) ?? false)
        }
    }
}

// MARK: - Account Picker Row (edit context)

/**
 A single row in the account picker dropdown.
 
 Displays an account with:
 - Color-coded kind indicator dot
 - Full hierarchical path as primary text
 - Account type code as secondary text
 
 The kind indicator uses the same color scheme as other account views:
 - Blue: Asset
 - Red: Liability
 - Purple: Equity
 - Green: Income
 - Orange: Expense
 - Gray: Other/System
 
 - Note: This is a private component used by `EditSplitLineRow`.
 */
private struct EditAccountPickerRow: View {

    /// The account to display.
    let account: AccountNode
    
    /// Optional full hierarchical path (e.g., "Assets:Current Assets:Checking").
    /// Falls back to account name if path is unavailable.
    let fullPath: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kindColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(fullPath ?? account.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.head)
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
        case 1: return .blue    // Asset
        case 2: return .red     // Liability
        case 3: return .purple  // Equity
        case 4: return .green   // Income
        case 5: return .orange  // Expense
        default: return .gray   // Other/System
        }
    }
}
