//
//  Features/Transactions/EditTransactionView.swift
//  EditTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
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
/// ## View Structure
///
/// The form is organized into sections:
/// - **Transaction Details**: Date picker, memo field, reference number field
/// - **Split Lines**: List of editable splits with account picker and memo
/// - **Error Display**: Shows validation or network errors if they occur
///
/// ## Implementation Notes
///
/// - Uses `EditTransactionViewModel` for state management and change detection
/// - Filters accounts to show only leaf (non-placeholder) accounts in pickers
/// - Supports keyboard-friendly search in account selection
/// - Automatically populates form on appear with existing transaction data
/// - Dismisses sheet automatically after successful save
///
/// - Note: Designed for macOS with a minimum window size of 620×480 points.
/// - SeeAlso: `EditTransactionViewModel`, `EditSplitLine`, `TransactionDetailSheet`
struct EditTransactionView: View {

    // MARK: - Properties
    
    /// The transaction being edited. Used for populating the form and change detection.
    let transaction: TransactionResponse
    
    /// The ledger this transaction belongs to. Used for context and validation.
    let ledger: LedgerResponse
    
    /// The complete chart of accounts hierarchy. Used to populate account pickers.
    let allAccounts: [AccountNode]
    
    /// A dictionary mapping account IDs to their full hierarchical paths (e.g., "Assets:Bank:Checking").
    let accountPaths: [UUID: String]
    
    /// Async closure called after successful save. Use this to refresh the transaction list or detail view.
    let onSuccess: () async -> Void

    // MARK: - Environment
    
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    /// The view model managing form state and submission logic.
    @State private var viewModel = EditTransactionViewModel()

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
        .onAppear {
            viewModel.populate(
                from: transaction,
                accountPaths: accountPaths,
                allAccounts: allAccounts
            )
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
                Task {
                    await onSuccess()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section
    
    /// The transaction details section containing date, memo, and reference number fields.
    ///
    /// Provides form fields for editing the transaction-level properties:
    /// - Date picker with date and time components
    /// - Memo text field for the transaction description
    /// - Reference number field for check numbers or other identifiers
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
    
    /// The split lines section displaying editable rows for each transaction split.
    ///
    /// Each row shows:
    /// - An account picker for changing the split's account assignment
    /// - A memo field for split-specific descriptions
    ///
    /// The splits cannot be added or removed in this edit view, only their
    /// properties can be modified.
    private var splitsSection: some View {
        Section("Split Lines") {
            ForEach($viewModel.splitLines) { $line in
                EditSplitLineRow(
                    line: $line,
                    allAccounts: leafAccounts,
                    accountPaths: accountPaths
                )
            }
        }
    }

    // MARK: - Toolbar
    
    /// Toolbar content providing Cancel and Save actions.
    ///
    /// - **Cancel**: Dismisses the sheet without saving changes
    /// - **Save**: Submits changes to the server via PATCH request
    ///   - Disabled while submission is in progress
    ///   - Shows a progress indicator during save operation
    ///   - Requires authentication token from AuthService
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
    
    /// Returns only the leaf (non-placeholder) accounts from the chart of accounts.
    ///
    /// Placeholder accounts are used for organizational purposes and cannot have
    /// transactions posted to them. This computed property filters the account tree
    /// to return only accounts that can be assigned to split lines.
    ///
    /// The filtering preserves both:
    /// - Direct leaf accounts (accounts with no children)
    /// - Parent accounts that are not placeholders (can have transactions)
    ///
    /// - Returns: A flat array of selectable accounts for split assignment.
    private var leafAccounts: [AccountNode] {
        func collectLeaves(_ nodes: [AccountNode]) -> [AccountNode] {
            nodes.flatMap { node in
                node.isPlaceholder
                    ? collectLeaves(node.children)
                    : [node] + collectLeaves(node.children)
            }
        }
        return collectLeaves(allAccounts)
    }
}

// MARK: - Edit Split Line Row

/// A view representing a single editable split line within the transaction edit form.
///
/// `EditSplitLineRow` provides UI controls for modifying a split's account assignment
/// and memo. It features a custom account picker with search functionality that helps
/// users quickly find accounts in large charts of accounts.
///
/// ## Features
///
/// - **Account picker**: Custom dropdown with search capability
/// - **Full path display**: Shows complete account hierarchy (e.g., "Assets:Bank:Checking")
/// - **Split memo field**: Allows per-split descriptions
/// - **Keyboard-friendly**: Search filter for quick account selection
/// - **Visual feedback**: Color-coded account type indicators
///
/// ## Account Picker Behavior
///
/// - Clicking the account button expands the picker dropdown
/// - Search field filters accounts by name, path, or account code
/// - Selecting an account collapses the picker and updates the split
/// - Search text is cleared when picker closes
///
/// - Note: This is a private component used exclusively by `EditTransactionView`.
private struct EditSplitLineRow: View {

    // MARK: - Properties
    
    /// Binding to the split line being edited.
    @Binding var line: EditSplitLine
    
    /// All selectable (leaf) accounts from the chart of accounts.
    let allAccounts: [AccountNode]
    
    /// Dictionary mapping account IDs to their full hierarchical paths.
    let accountPaths: [UUID: String]

    // MARK: - State
    
    /// The current search query for filtering accounts in the picker.
    @State private var searchText = ""
    
    /// Whether the account picker dropdown is currently expanded.
    @State private var isPickerExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Account picker
            accountPickerButton

            // Split memo
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
    
    /// A custom account picker button with expandable dropdown and search.
    ///
    /// When collapsed, displays the currently selected account's full path or a placeholder.
    /// When expanded, shows a search field and scrollable list of filtered accounts.
    ///
    /// The picker includes:
    /// - Button showing current selection
    /// - Search field for filtering accounts
    /// - Scrollable list of matching accounts
    /// - Visual styling matching macOS native controls
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
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4, y: 2)
                .zIndex(100)
            }
        }
    }

    /// Returns accounts filtered by the current search query.
    ///
    /// Filters accounts based on case-insensitive matching against:
    /// - Account name
    /// - Full account path
    /// - Account code (if present)
    ///
    /// If search text is empty, returns all accounts.
    ///
    /// - Returns: Filtered array of accounts matching the search criteria.
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

/// A row view displaying an account option in the picker dropdown.
///
/// Shows the account's full path, type code, and a color-coded indicator based
/// on the account kind (asset, liability, equity, income, expense).
///
/// ## Visual Elements
///
/// - **Color dot**: Indicates account kind with standard accounting colors
///   - Blue: Assets (kind 1)
///   - Red: Liabilities (kind 2)
///   - Purple: Equity (kind 3)
///   - Green: Income (kind 4)
///   - Orange: Expenses (kind 5)
/// - **Account path**: Full hierarchical path truncated from the head if too long
/// - **Type code**: Small secondary text showing the account type code
///
/// - Note: This is a private component used exclusively by `EditSplitLineRow`.
private struct EditAccountPickerRow: View {
    
    /// The account to display in this row.
    let account: AccountNode
    
    /// The full hierarchical path for this account. If nil, falls back to account name.
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

    /// Returns a color representing the account's kind/type.
    ///
    /// Uses standard accounting color conventions:
    /// - Assets: Blue
    /// - Liabilities: Red
    /// - Equity: Purple
    /// - Income: Green
    /// - Expenses: Orange
    /// - Unknown: Gray
    ///
    /// - Returns: A SwiftUI `Color` corresponding to the account kind.
    private var kindColor: Color {
        switch account.account.kind {
        case 1: return .blue
        case 2: return .red
        case 3: return .purple
        case 4: return .green
        case 5: return .orange
        default: return .gray
        }
    }
}
