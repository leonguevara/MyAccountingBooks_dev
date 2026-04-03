//
//  Features/Transactions/PostTransactionView.swift
//  PostTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import SwiftUI

/// Form for creating a new multi-split double-entry transaction.
///
/// Presents header fields (date, memo, reference number, payee) and a dynamic list of
/// ``SplitLineRow`` entries with per-split account pickers and debit/credit fields.
/// Delegates state, balance computation, and submission to ``PostTransactionViewModel``.
/// Maintains live `currentAccounts`/`currentPaths` refreshed via `.accountSaved`
/// notifications so newly created accounts appear in pickers without reopening the sheet.
/// The Post button stays disabled until ``PostTransactionViewModel/canSubmit`` is `true`
/// (balanced, ≥ 2 splits, all accounts assigned, at least one non-zero amount).
///
/// - Important: All splits must balance (total debits = total credits) before posting.
/// - Note: Requires ``AuthService`` in the SwiftUI environment.
/// - SeeAlso: ``PostTransactionViewModel``, ``SplitLineRow``, ``AccountPickerRow``
struct PostTransactionView: View {

    // MARK: - Properties

    /// The ledger to post to; supplies `id`, `currencyCode`, and `decimalPlaces`.
    let ledger: LedgerResponse

    /// Async callback invoked after a successful post, before the sheet is dismissed.
    ///
    /// Typically reloads the parent's transaction list while the loading indicator is still visible.
    let onSuccess: () async -> Void

    // MARK: - Environment and State

    /// Authentication service providing the bearer token used to authorize the POST request.
    @Environment(AuthService.self) private var auth

    /// Environment dismiss action used to close the sheet on cancellation or after successful posting.
    @Environment(\.dismiss) private var dismiss

    /// Opens the account creation form in a new window when "New Account…" is tapped in a split picker.
    @Environment(\.openWindow) private var openWindow

    /// View model managing split lines, balance computations, validation, and submission.
    @State private var viewModel = PostTransactionViewModel()

    /// Live account tree seeded from `allAccounts` at init; refreshed on `.accountSaved` notifications.
    @State private var currentAccounts: [AccountNode]

    /// Live UUID-to-path map seeded from `accountPaths` at init; rebuilt whenever `currentAccounts` changes.
    @State private var currentPaths: [UUID: String]

    /// Payees available for selection; fetched from ``PayeeService`` in `.task` and empty until complete.
    @State private var currentPayees: [PayeeResponse] = []
    /// The payee selected via ``PayeePickerButton``; `nil` when no payee is assigned.
    @State private var selectedPayee: PayeeResponse? = nil
    /// Whether the payee row is toggled on; toggling off clears `selectedPayee`.
    @State private var usePayee: Bool = false

    // MARK: - Init

    /// Creates the view, seeding `currentAccounts` and `currentPaths` from the provided snapshots.
    ///
    /// - Parameters:
    ///   - ledger: The ledger to post to.
    ///   - allAccounts: Initial account tree hierarchy; captured in local state.
    ///   - accountPaths: Initial UUID-to-path map; captured in local state.
    ///   - onSuccess: Async callback invoked after a successful post.
    /// - Note: Post-init changes to `allAccounts` and `accountPaths` have no effect;
    ///   only `.accountSaved` notifications trigger refreshes.
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

    /// Header card with date, memo, reference number, and optional payee fields.
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

    /// Splits card with column headers, one ``SplitLineRow`` per entry, Add Split Line button, and Auto-balance.
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

    /// Card showing total debits (left), balance status or imbalance amount (center), and total credits (right).
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

    /// Cancel and Post toolbar items; Post is disabled while `viewModel.canSubmit` is `false`.
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


    /// Horizontal row with a 110 pt label and a full-width content view; used in `headerCard`.
    ///
    /// - Parameters:
    ///   - title: The label text.
    ///   - content: The input control.
    /// - Returns: An `HStack` pairing the label with the content.
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

    /// Wraps content in a styled rounded-rectangle card with an optional title heading.
    ///
    /// - Parameters:
    ///   - title: Optional heading rendered as `.title3.weight(.semibold)`.
    ///   - content: The card body.
    /// - Returns: A padded card with consistent background, corner radius, and border.
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

    /// Recursively collects non-placeholder ``AccountNode`` values from `currentAccounts`.
    ///
    /// Non-placeholder parents that also have children are included — they can receive postings
    /// while still grouping child accounts.
    ///
    /// - Returns: Flat array of postable accounts suitable for split-line picker display.
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

/// A single split line row: memo, searchable account picker, debit/credit fields, and a delete button.
///
/// Notifies ``PostTransactionView`` of amount edits via `onDebitEdited`/`onCreditEdited` callbacks
/// so balance totals update in real time. Delete is disabled when `canDelete` is `false`
/// (minimum two splits required). Tapping "New Account…" calls `onCreateAccount` with the
/// current search text so the parent can open an account creation window.
///
/// - Note: Private component used exclusively by ``PostTransactionView``.
/// - SeeAlso: ``SplitLine``
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

    /// Current search query in the account picker; cleared when the picker opens or an account is selected.
    @State private var searchText = ""
    /// Whether the account picker dropdown is currently expanded.
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

    /// Expandable account picker: shows selected path when collapsed; search field, filtered list,
    /// and optional "New Account…" row when expanded. Uses `zIndex(100)` to float above sibling rows.
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

    /// Case-insensitive filter over full path, account code, and type code; returns all accounts when query is empty.
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

/// A single row in the account picker: color-coded kind dot, full hierarchical path
/// (`.truncationMode(.head)`), and account type code as tertiary caption.
///
/// - Note: Private component used exclusively by ``SplitLineRow``.
/// - SeeAlso: ``AccountNode``
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

