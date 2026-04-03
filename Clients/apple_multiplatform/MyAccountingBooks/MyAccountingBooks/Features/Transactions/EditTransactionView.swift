//
//  Features/Transactions/EditTransactionView.swift
//  EditTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import SwiftUI

/// Modal sheet for editing an existing transaction.
///
/// Presents editable controls for the transaction header (memo, number, post date, payee)
/// and each split line (account, memo). Delegates form state and PATCH construction to
/// ``EditTransactionViewModel``, which sends only changed fields to the server. Maintains
/// live `currentAccounts`/`currentPaths` state refreshed via `.accountSaved` notifications,
/// so newly created accounts appear in split pickers without dismissing this sheet.
///
/// - Note: Designed for macOS with a minimum window size of 620×480 points.
/// - Important: Requires ``AuthService`` in the SwiftUI environment for API authentication.
/// - SeeAlso: ``EditTransactionViewModel``, ``EditSplitLine``, ``TransactionDetailSheet``
struct EditTransactionView: View {

    // MARK: - Properties

    /// The transaction being edited; supplies original field values for PATCH comparison.
    let transaction: TransactionResponse

    /// The ledger context; provides `id` for account/payee fetches and `.accountSaved` filtering.
    let ledger: LedgerResponse

    /// Async callback invoked after a successful save, before the sheet is dismissed.
    ///
    /// Typically reloads the parent's transaction list. Called while the loading indicator
    /// is still visible, so the parent can reload data before the sheet disappears.
    let onSuccess: () async -> Void

    // MARK: - Environment

    /// Authentication service providing the bearer token for API requests.
    @Environment(AuthService.self) private var auth
    
    /// SwiftUI dismiss action used to close the sheet after saving or canceling.
    @Environment(\.dismiss) private var dismiss

    /// Opens the account creation form in a new window when "New Account…" is tapped in a split picker.
    @Environment(\.openWindow) private var openWindow

    // MARK: - State

    /// View model managing form state and PATCH construction; populated in `.onAppear`.
    @State private var viewModel = EditTransactionViewModel()

    /// Live account tree seeded from `allAccounts` at init; refreshed on `.accountSaved` notifications.
    @State private var currentAccounts: [AccountNode]

    /// Live UUID-to-path map seeded from `accountPaths` at init; rebuilt whenever `currentAccounts` changes.
    @State private var currentPaths: [UUID: String]

    /// Payees available for selection; fetched from ``PayeeService`` in `.task` and empty until complete.
    @State private var currentPayees: [PayeeResponse] = []

    // MARK: - Init

    /// Creates the view, seeding `currentAccounts` and `currentPaths` from the provided snapshots.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to edit; supplies original field values for PATCH comparison.
    ///   - ledger: The ledger context for account and payee fetches.
    ///   - allAccounts: Initial account tree hierarchy; captured in local state.
    ///   - accountPaths: Initial UUID-to-path map; captured in local state.
    ///   - onSuccess: Async callback invoked after a successful save.
    /// - Note: `allAccounts` and `accountPaths` seed state only; post-init changes to these
    ///   parameters have no effect — only `.accountSaved` notifications trigger refreshes.
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
        .task {
            guard let token = auth.token else { return }
            if let payees = try? await PayeeService.shared.fetchPayees(
                ledgerID: ledger.id, token: token) {
                currentPayees = payees
            }
        }
    }

    // MARK: - Header Section

    /// Form section for date, memo, reference number, and payee; all fields tracked by the view model.
    private var headerSection: some View {
        Section("Transaction Details") {
            DatePicker(
                "Date",
                selection: $viewModel.postDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            TextField("Description (memo)", text: $viewModel.memo)
            TextField("Reference # (optional)", text: $viewModel.num)

            // In headerCard — add payee row (same pattern as PostTransactionView)
            LabeledContent("Payee") {
                HStack(spacing: 10) {
                    Toggle("", isOn: $viewModel.usePayee)
                        .labelsHidden()
                        .onChange(of: viewModel.usePayee) { _, on in
                            if !on { viewModel.selectedPayeeId = nil }
                        }
                    if viewModel.usePayee {
                        PayeePickerButton(
                            selectedPayee: Binding(
                                get: {
                                    currentPayees.first { $0.id == viewModel.selectedPayeeId }
                                },
                                set: { viewModel.selectedPayeeId = $0?.id }
                            ),
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
                                        viewModel.selectedPayeeId = created.id
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Splits Section

    /// Form section listing editable split lines; each row exposes an account picker and a memo field.
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

    /// Cancel and Save toolbar items; Save is disabled while `viewModel.isSubmitting` is `true`.
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

    /// Recursively collects non-placeholder ``AccountNode`` values from `currentAccounts`.
    ///
    /// - Returns: Flat array of leaf accounts suitable for split-line picker display.
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

/// A single editable split line row: searchable account picker and a split-memo field.
///
/// Tapping "New Account…" at the bottom of the picker calls `onCreateAccount` with the
/// current search text as the suggested name, allowing the parent to open an account
/// creation window without dismissing the edit sheet.
///
/// - Note: Private component used exclusively by ``EditTransactionView``.
/// - SeeAlso: ``EditSplitLine``
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

    /// Current search query typed into the account picker's search field.
    @State private var searchText = ""
    /// Whether the account picker dropdown is currently expanded.
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

    /// Expandable account picker showing the selected path when collapsed; a search field,
    /// filtered account list, and optional "New Account…" row when expanded.
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

    /// Case-insensitive filter over full path, name, and account code; returns all accounts when query is empty.
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

/// A single row in the account picker: color-coded kind dot, full hierarchical path, and type code.
///
/// - Note: Private component used by ``EditSplitLineRow``.
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
