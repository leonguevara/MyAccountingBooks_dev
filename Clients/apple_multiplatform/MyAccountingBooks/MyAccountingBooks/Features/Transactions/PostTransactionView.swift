//
//  Features/Transactions/PostTransactionView.swift
//  PostTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import SwiftUI

/**
 A SwiftUI view that presents a comprehensive form for creating multi-split accounting transactions.
 
 This view provides a complete interface for entering transaction details including date, memo,
 reference number, and multiple split lines. Each split line contains an account selection,
 optional memo, and either a debit or credit amount. The view enforces double-entry bookkeeping
 rules by requiring that total debits equal total credits before submission.
 
 # Features
 - Transaction header with date, description (memo), and reference number
 - Dynamic split line management (add/remove lines)
 - Account picker with search functionality for each split
 - Real-time balance calculation and validation
 - Auto-balance functionality to automatically balance the last incomplete split
 - Visual balance indicators (balanced checkmark or imbalance warning)
 - Error handling and display
 
 # Usage Example
 ```swift
 PostTransactionView(
     ledger: selectedLedger,
     allAccounts: accountTree,
     onSuccess: {
         await viewModel.refreshTransactions()
     }
 )
 ```
 
 - Note: This view requires authentication and will use the current user's token for posting.
 - Important: All splits must balance (total debits = total credits) before submission is allowed.
 */
struct PostTransactionView: View {

    // MARK: - Properties
    
    /// The ledger to which the transaction will be posted.
    ///
    /// This ledger determines the currency and decimal precision for all amounts in the transaction.
    let ledger: LedgerResponse
    
    /// A flat list of all account nodes available for selection in split line pickers.
    ///
    /// This list is filtered to only show leaf (non-placeholder) accounts when presented to the user.
    let allAccounts: [AccountNode]
    
    /// An async callback invoked after the transaction is successfully posted to the backend.
    ///
    /// Use this callback to refresh data, update UI state, or perform other post-submission actions.
    /// The view will automatically dismiss after this callback completes.
    let onSuccess: () async -> Void

    // MARK: - Environment and State
    
    /// Authentication service environment dependency to access the user's authentication token.
    @Environment(AuthService.self) private var auth
    
    /// Environment dismiss action used to close the sheet after successful posting or cancellation.
    @Environment(\.dismiss) private var dismiss
    
    /// The stateful view model managing form data, validation, and submission logic.
    @State private var viewModel = PostTransactionViewModel()

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
        .onChange(of: viewModel.didPost) { _, posted in
            if posted {
                Task {
                    await onSuccess()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section

    /// Displays the transaction header section with input fields for essential transaction details.
    ///
    /// This section includes:
    /// - **Date picker**: Allows selection of the transaction posting date
    /// - **Description field**: A text field for the transaction memo/description
    /// - **Reference number field**: An optional text field for check numbers, invoice numbers, etc.
    private var headerSection: some View {
        Section("Transaction Details") {
            DatePicker(
                "Date",
                selection: $viewModel.postDate,
                displayedComponents: .date
            )
            TextField("Description (memo)", text: $viewModel.memo)
            TextField("Reference # (optional)", text: $viewModel.num)
        }
    }

    // MARK: - Splits Section

    /// Displays the split lines section with account picker, amounts, and management controls.
    ///
    /// This section is the core of the double-entry transaction interface. It includes:
    /// - Column headers for Account, Memo, Debit, and Credit
    /// - Individual split line rows with editable fields
    /// - Add split line button to insert new lines
    /// - Auto-balance button in the header to automatically balance the transaction
    ///
    /// Each split line allows the user to:
    /// - Select an account from the filtered leaf accounts
    /// - Enter an optional memo for the split
    /// - Enter either a debit or credit amount (not both)
    /// - Delete the line (if more than 2 lines exist)
    ///
    /// The auto-balance feature fills the last incomplete split line to balance the transaction.
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
                Spacer().frame(width: 32)   // space for delete button
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            // Split rows
            ForEach($viewModel.splits) { $line in
                SplitLineRow(
                    line: $line,
                    allAccounts: leafAccounts,
                    onDebitEdited: { viewModel.didEditDebit(for: line.id) },
                    onCreditEdited: { viewModel.didEditCredit(for: line.id) },
                    onDelete: { viewModel.removeSplitLine(id: line.id) },
                    canDelete: viewModel.splits.count > 2
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

    /// Displays a real-time balance summary showing total debits, total credits, and balance status.
    ///
    /// This section provides immediate visual feedback about the transaction's balance state:
    /// - **Total Debits**: Sum of all debit amounts across all split lines
    /// - **Total Credits**: Sum of all credit amounts across all split lines
    /// - **Balance Status**: Either a green checkmark (balanced) or red imbalance amount
    ///
    /// The transaction can only be posted when the balance status shows "Balanced"
    /// (i.e., total debits equal total credits).
    ///
    /// All amounts are formatted according to the ledger's currency code and decimal precision.
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

    /// Provides toolbar items for transaction form actions: Cancel and Post.
    ///
    /// - **Cancel button**: Dismisses the view without posting the transaction
    /// - **Post button**: Submits the transaction to the backend (disabled if validation fails)
    ///
    /// The Post button shows a progress indicator during submission and is disabled when:
    /// - The transaction is not balanced
    /// - Required fields are missing
    /// - A submission is already in progress
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

    /// Returns only leaf (non-placeholder) accounts that can receive transaction splits.
    ///
    /// This computed property filters the account tree to exclude placeholder accounts,
    /// which are used only for organizational hierarchy and cannot have transactions posted to them.
    /// The filtering is recursive, traversing the entire account tree structure.
    ///
    /// - Returns: An array of `AccountNode` objects representing valid accounts for split assignment.
    private var leafAccounts: [AccountNode] {
        func collectLeaves(_ nodes: [AccountNode]) -> [AccountNode] {
            nodes.flatMap { node in
                node.isPlaceholder ? collectLeaves(node.children)
                                   : [node] + collectLeaves(node.children)
            }
        }
        return collectLeaves(allAccounts)
    }
}

// MARK: - Split Line Row

/**
 A specialized row view for editing a single split line within the transaction.
 
 This view provides a complete interface for one split line in the double-entry transaction,
 including account selection, memo entry, amount input (debit or credit), and deletion.
 
 # Features
 - **Account picker**: Dropdown with search functionality to select from available accounts
 - **Memo field**: Optional text field for split-specific notes
 - **Debit/Credit fields**: Numeric input fields (only one should have a value per split)
 - **Delete button**: Removes the split line (disabled if minimum lines would be violated)
 
 # Layout
 The row uses a horizontal layout with the following columns:
 - Account picker (expandable, full width)
 - Memo field (130pt fixed width)
 - Debit field (100pt fixed width, right-aligned)
 - Credit field (100pt fixed width, right-aligned)
 - Delete button (24pt fixed width)
 
 - Note: When a debit amount is entered, the credit field should remain empty and vice versa.
 */
private struct SplitLineRow: View {

    // MARK: - Properties
    
    /// Binding to the split line data model being edited.
    ///
    /// Changes to account selection, memo, or amounts are immediately reflected in the parent view.
    @Binding var line: SplitLine
    
    /// The list of all available accounts for selection in the account picker dropdown.
    ///
    /// This should typically contain only leaf (non-placeholder) accounts.
    let allAccounts: [AccountNode]
    
    /// Callback invoked when the user edits the debit amount field.
    ///
    /// This triggers balance recalculation and may clear the credit field in the view model.
    let onDebitEdited: () -> Void
    
    /// Callback invoked when the user edits the credit amount field.
    ///
    /// This triggers balance recalculation and may clear the debit field in the view model.
    let onCreditEdited: () -> Void
    
    /// Callback invoked when the user taps the delete button.
    ///
    /// The parent view determines whether deletion is allowed based on minimum line requirements.
    let onDelete: () -> Void
    
    /// Indicates whether the delete button should be enabled.
    ///
    /// Typically `false` when only the minimum number of split lines (usually 2) remain.
    let canDelete: Bool

    // MARK: - State
    
    /// The current search text for filtering accounts in the picker dropdown.
    @State private var searchText = ""
    
    /// Controls the visibility of the account picker dropdown menu.
    @State private var isPickerExpanded = false

    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {

            // Account picker
            accountPickerButton
                .frame(maxWidth: .infinity, alignment: .leading)

            // Split memo
            TextField("Memo", text: $line.memo)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)

            // Debit field
            TextField("0.00", text: $line.debitAmount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: line.debitAmount) { _, _ in
                    onDebitEdited()
                }

            // Credit field
            TextField("0.00", text: $line.creditAmount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: line.creditAmount) { _, _ in
                    onCreditEdited()
                }

            // Delete button
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

    /// Presents a custom account picker button with expandable dropdown and search functionality.
    ///
    /// When collapsed, displays either the selected account (with code and name) or a placeholder.
    /// When expanded, shows a search field and scrollable list of filtered accounts.
    ///
    /// The picker includes:
    /// - A button showing the current account selection or "Select account…" placeholder
    /// - An expandable dropdown with search field
    /// - Filtered list of accounts based on search text
    /// - Visual styling with rounded corners and borders
    ///
    /// Search filters accounts by name, code, or account type code (case-insensitive).
    private var accountPickerButton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isPickerExpanded.toggle()
                if isPickerExpanded { searchText = "" }
            } label: {
                HStack {
                    if let account = line.account {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                if let code = account.code {
                                    Text(code)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(account.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
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

            // Dropdown list
            if isPickerExpanded {
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search accounts…", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // Filtered account list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredAccounts) { account in
                                AccountPickerRow(account: account)
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

    // MARK: - Filtered Accounts

    /// Returns the list of accounts filtered by the current search text.
    ///
    /// Searches across multiple account properties:
    /// - Account name
    /// - Account code
    /// - Account type code
    ///
    /// The search is case-insensitive. If the search text is empty, returns all accounts.
    ///
    /// - Returns: An array of `AccountNode` objects matching the search criteria.
    private var filteredAccounts: [AccountNode] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allAccounts }
        return allAccounts.filter { account in
            account.name.lowercased().contains(query)
            || (account.code?.lowercased().contains(query) ?? false)
            || (account.accountTypeCode?.lowercased().contains(query) ?? false)
        }
    }
}

// MARK: - Account Picker Row

/**
 A single row in the account picker dropdown list.
 
 This view displays one account option in the picker with visual indicators and information:
 - **Color indicator**: A small circle colored by account kind (asset, liability, etc.)
 - **Account code**: Optional account code displayed in monospaced font
 - **Account name**: The primary account name
 - **Type code**: Optional account type code shown as tertiary text
 
 # Color Coding by Account Kind
 - Kind 1 (Asset): Blue
 - Kind 2 (Liability): Red
 - Kind 3 (Equity): Purple
 - Kind 4 (Revenue): Green
 - Kind 5 (Expense): Orange
 - Other: Gray
 */
private struct AccountPickerRow: View {
    /// The account node to display in this row.
    let account: AccountNode

    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kindColor)
                .frame(width: 7, height: 7)

            if let code = account.code {
                Text(code)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 90, alignment: .leading)
            }

            Text(account.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            if let typeCode = account.accountTypeCode {
                Text(typeCode)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    
    /// Returns the color associated with the account's kind (type).
    ///
    /// This provides visual differentiation between different account categories:
    /// - **Blue**: Assets (kind 1)
    /// - **Red**: Liabilities (kind 2)
    /// - **Purple**: Equity (kind 3)
    /// - **Green**: Revenue (kind 4)
    /// - **Orange**: Expenses (kind 5)
    /// - **Gray**: Other or undefined kinds
    ///
    /// - Returns: A `Color` representing the account kind.
    private var kindColor: Color {
        switch account.account.kind {
        case 1:  return .blue
        case 2:  return .red
        case 3:  return .purple
        case 4:  return .green
        case 5:  return .orange
        default: return .gray
        }
    }
}

