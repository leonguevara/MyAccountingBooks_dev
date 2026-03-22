//
//  Features/Transactions/PostTransactionView.swift
//  PostTransactionView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-03-22.
//  Developed with AI assistance.
//

import SwiftUI

/**
 Form view for creating a new multi-split double-entry accounting transaction.

 `PostTransactionView` provides a complete data-entry interface for posting a transaction
 to a ledger. It enforces double-entry bookkeeping rules throughout: the form cannot be
 submitted until total debits equal total credits across all split lines.

 # Features

 - **Transaction header**: Date picker, free-text memo, and optional reference number.
 - **Dynamic split management**: Add or remove split lines freely; minimum of 2 enforced.
 - **Account picker**: Per-split expandable dropdown with real-time search, GnuCash-style
   full-path labels (e.g., `"Assets:Current Assets:Cash:Checking"`), and kind-color dots.
 - **Balance summary**: Live debit/credit totals with a green "Balanced" badge or a red
   imbalance amount.
 - **Auto-balance**: One-tap button fills the last split line with the amount needed to
   bring the transaction into balance.
 - **Submission guard**: The "Post" button is disabled until `viewModel.canSubmit` is `true`
   (balanced, all splits complete, not already submitting).
 - **Error display**: Inline red caption below the form when `viewModel.errorMessage` is set.

 # Account Labels (GnuCash-style paths)

 `accountPaths` is a `[UUID: String]` dictionary built by `AccountTreeBuilder.buildPathMap(from:)`.
 It is threaded through to each `SplitLineRow` → `accountPickerButton` and `AccountPickerRow`
 so that both the collapsed button label and every dropdown row show the full ancestor path
 rather than a bare account name or truncated code. The leaf name is always visible because
 long paths are truncated from the leading edge (`.truncationMode(.head)`).

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

 - Important: All splits must balance (total debits = total credits) before the "Post"
   button becomes active.
 - Note: Requires `AuthService` in the SwiftUI environment. The token is read from
   `auth.token` at the moment the "Post" button is tapped.
 - SeeAlso: `PostTransactionViewModel`, `SplitLineRow`, `AccountPickerRow`,
   `AccountTreeBuilder.buildPathMap(from:)`
 */
struct PostTransactionView: View {

    // MARK: - Properties

    /// The ledger to which the transaction will be posted.
    ///
    /// Determines the currency code and decimal precision used throughout the form for
    /// amount formatting and for constructing the `PostTransactionRequest` payload.
    let ledger: LedgerResponse

    /// The complete account tree (all root nodes) available for selection in split pickers.
    ///
    /// Passed through to `leafAccounts`, which filters out placeholder nodes so that only
    /// postable accounts are shown in each split line's account picker.
    let allAccounts: [AccountNode]

    /// GnuCash-style colon-separated full paths for every non-root account in the ledger.
    ///
    /// Keys are account UUIDs; values are path strings such as
    /// `"Assets:Current Assets:Cash:Checking"`. Threaded down to each `SplitLineRow`
    /// so that both the collapsed picker button label and every dropdown row show the full
    /// ancestor path. When a path is absent (empty map or unknown ID), the fallback is
    /// `account.name`.
    ///
    /// - SeeAlso: `AccountTreeBuilder.buildPathMap(from:)`
    let accountPaths: [UUID: String]

    /// Async callback invoked immediately after the transaction is successfully posted.
    ///
    /// Use this to reload the register, refresh balances, or update any other dependent state.
    /// The view dismisses itself after this callback returns.
    let onSuccess: () async -> Void

    // MARK: - Environment and State

    /// Authentication service providing the bearer token used to authorize the POST request.
    @Environment(AuthService.self) private var auth

    /// Environment dismiss action used to close the sheet on cancellation or after successful posting.
    @Environment(\.dismiss) private var dismiss

    /// View model managing form state, validation, balance computation, and submission.
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

    /// Transaction metadata inputs: posting date, memo, and optional reference number.
    ///
    /// - **Date**: `DatePicker` bound to `viewModel.postDate`; defaults to today.
    /// - **Description**: Free-text memo bound to `viewModel.memo`.
    /// - **Reference #**: Optional field bound to `viewModel.num` for check numbers,
    ///   invoice IDs, etc.
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

    /**
     The core double-entry split editor: column headers, per-split rows, and the add-line control.

     Renders `viewModel.splits` as a list of `SplitLineRow` views, each bound via `$line` for
     two-way editing. `accountPaths` is forwarded to every row so the account picker displays
     full GnuCash-style paths.

     # Column Layout

     | Column  | Width   | Notes                                    |
     |---------|---------|------------------------------------------|
     | Account | Flex    | Expandable picker with path-label search |
     | Memo    | 140 pt  | Optional per-split annotation            |
     | Debit   | 110 pt  | Right-aligned; clears Credit on edit     |
     | Credit  | 110 pt  | Right-aligned; clears Debit on edit      |
     | (delete)| 32 pt   | Spacer matching `SplitLineRow` button    |

     # Section Header Controls

     - **"Splits" label**: Static section title.
     - **"Auto-balance" button**: Calls `viewModel.autoBalance()` to fill the last split
       with the amount needed for balance. Disabled when already balanced.

     # Add Split Line

     A plain-styled button at the bottom of the section calls `viewModel.addSplitLine()`.
     The delete button on each row is disabled when exactly 2 lines remain (enforcing the
     double-entry minimum).
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
                Spacer().frame(width: 32)   // space for delete button
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            // Split rows — accountPaths threaded to each row for full-path picker labels
            ForEach($viewModel.splits) { $line in
                SplitLineRow(
                    line: $line,
                    allAccounts: leafAccounts,
                    accountPaths: accountPaths,
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

    /**
     Real-time balance summary showing total debits, balance status, and total credits.

     The three-column layout mirrors a traditional T-account view:
     - **Left**: Total Debits formatted with the ledger's currency and decimal precision.
     - **Center**: Either a green "Balanced ✓" label when `viewModel.isBalanced`, or a
       red imbalance amount (`abs(viewModel.imbalance)`) when not.
     - **Right**: Total Credits formatted identically to the debit column.

     The "Post" toolbar button reads `viewModel.canSubmit`, which requires `isBalanced`
     to be `true`, so this section provides the primary visual cue for submission readiness.

     All amounts are formatted via `AmountFormatter` using `ledger.currencyCode` and
     `ledger.decimalPlaces`.
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
     Toolbar items for the post-transaction form: Cancel and Post.

     - **Cancel** (`cancellationAction`): Dismisses the sheet immediately without posting.
     - **Post** (`confirmationAction`): Calls `viewModel.submit(ledger:token:)` asynchronously.
       While submitting, the label is replaced with a small `ProgressView`. The button is
       disabled whenever `viewModel.canSubmit` is `false` (unbalanced, incomplete splits,
       or a submission is already in flight).
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
     Recursively collects all postable (non-placeholder) leaf accounts from `allAccounts`.

     Placeholder accounts are structural containers in the chart of accounts and cannot
     receive transaction splits. This helper traverses the full tree depth-first, including
     non-placeholder nodes at every level (a non-placeholder parent may still have children).

     ```
     allAccounts (roots)
     └─ Assets (placeholder — skipped, recurse)
        └─ Cash (non-placeholder — included, recurse)
           └─ Checking (non-placeholder — included, recurse)
     ```

     The resulting flat array is passed to each `SplitLineRow` as `allAccounts`, driving
     both the expanded dropdown list and the `filteredAccounts` search.

     - Returns: A flat `[AccountNode]` array of every non-placeholder account in the tree.
     - SeeAlso: `SplitLineRow`, `AccountNode.isPlaceholder`
     */
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
 Editable row representing a single split line within the post-transaction form.

 `SplitLineRow` composes four editing surfaces side by side — account picker, memo field,
 debit field, and credit field — plus a delete button. It is instantiated once per entry in
 `PostTransactionViewModel.splits` and bound via `$line` for two-way state propagation.

 # Layout

 | Column         | Width   | Notes                                        |
 |----------------|---------|----------------------------------------------|
 | Account picker | Flex    | Expandable dropdown with path-label search   |
 | Memo           | 130 pt  | Optional free-text annotation for the split  |
 | Debit          | 100 pt  | Right-aligned; triggers `onDebitEdited`      |
 | Credit         | 100 pt  | Right-aligned; triggers `onCreditEdited`     |
 | Delete button  | 24 pt   | Disabled when `canDelete` is `false`         |

 # Debit / Credit Mutual Exclusivity

 Editing either amount field triggers its respective callback (`onDebitEdited` /
 `onCreditEdited`), which the parent view model uses to clear the opposing field —
 ensuring a split is never simultaneously a debit and a credit.

 # Account Picker

 The picker is a custom expandable button (`accountPickerButton`) that:
 - When **collapsed**: shows `accountPaths[account.id] ?? account.name` with
   `.truncationMode(.head)` so the leaf account name is always visible.
 - When **expanded**: shows a search field and a `LazyVStack` of `AccountPickerRow`
   views, each displaying its full `accountPaths` path and a kind-color dot.

 - Note: Debit and credit fields are mutually exclusive per split — entering a value in
   one clears the other via the parent view model callbacks.
 - SeeAlso: `PostTransactionView`, `PostTransactionViewModel`, `AccountPickerRow`
 */
private struct SplitLineRow: View {

    // MARK: - Properties

    /// Two-way binding to the split line data model.
    ///
    /// Mutations to `account`, `memo`, `debitAmount`, and `creditAmount` are immediately
    /// reflected in `PostTransactionViewModel.splits`.
    @Binding var line: SplitLine

    /// Flat list of postable (non-placeholder) accounts available in the picker dropdown.
    ///
    /// Pre-filtered by `PostTransactionView.leafAccounts` before being passed here.
    let allAccounts: [AccountNode]

    /// GnuCash-style colon-separated full paths keyed by account UUID.
    ///
    /// Forwarded to `accountPickerButton` (collapsed label) and each `AccountPickerRow`
    /// (dropdown row label). When a path is absent, the fallback is `account.name`.
    ///
    /// - SeeAlso: `AccountTreeBuilder.buildPathMap(from:)`
    let accountPaths: [UUID: String]

    /// Called when the user edits the debit field; triggers credit-field clearing in the view model.
    let onDebitEdited: () -> Void

    /// Called when the user edits the credit field; triggers debit-field clearing in the view model.
    let onCreditEdited: () -> Void

    /// Called when the user taps the delete button.
    ///
    /// The parent enforces a minimum of 2 split lines; deletion is silently ignored when
    /// only 2 remain.
    let onDelete: () -> Void

    /// Whether the delete button is currently enabled.
    ///
    /// `false` when `PostTransactionViewModel.splits.count <= 2`, preventing the user from
    /// dropping below the double-entry minimum.
    let canDelete: Bool

    // MARK: - State

    /// Current text in the account search field inside the expanded picker dropdown.
    @State private var searchText = ""

    /// Whether the account picker dropdown is currently expanded.
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

    /**
     Custom expandable account picker button with full-path labels and inline search.

     # Collapsed State

     Shows a rounded-border button containing:
     - The selected account's full path from `accountPaths`, or `account.name` as fallback.
       Long paths are truncated from the **leading edge** (`.truncationMode(.head)`) so the
       leaf account name at the right end remains visible.
     - A `"Select account…"` placeholder when no account is selected.
     - A `chevron.up.chevron.down` indicator on the trailing edge.

     # Expanded State

     A floating `VStack` (`.zIndex(100)`) drops below the button containing:
     - A search `TextField` that filters `filteredAccounts` in real time.
     - A `LazyVStack` of `AccountPickerRow` rows, each showing the full path and a
       kind-color dot. Tapping a row sets `line.account`, collapses the picker, and
       clears `searchText`.

     - Note: The dropdown uses `.zIndex(100)` to float above sibling rows in the form.
     - SeeAlso: `AccountPickerRow`, `filteredAccounts`
     */
    private var accountPickerButton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isPickerExpanded.toggle()
                if isPickerExpanded { searchText = "" }
            } label: {
                HStack {
                    if let account = line.account {
                        // Show full GnuCash-style path; truncate from the left so the
                        // leaf account name at the right end is always readable.
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

                    // Filtered account list — each row receives its full path for display
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

    /// Accounts from `allAccounts` that match `searchText`, or all accounts when the query is blank.
    ///
    /// The search is case-insensitive and matches against three fields:
    /// - `account.name`
    /// - `account.code`
    /// - `account.accountTypeCode`
    ///
    /// Whitespace-only queries are treated as empty, returning the full `allAccounts` list.
    ///
    /// - Returns: A filtered `[AccountNode]` array for display in the dropdown.
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
 A single row in the `SplitLineRow` account picker dropdown.

 Each row represents one selectable account and displays:
 - **Kind-color dot**: A 7 pt filled circle whose color encodes the account kind (see below).
 - **Primary text**: The full GnuCash-style path from `fullPath` (e.g.,
   `"Assets:Current Assets:Cash:Checking"`), or `account.name` when `fullPath` is `nil`.
   Long paths are truncated from the leading edge so the leaf name remains visible.
 - **Type code**: `account.accountTypeCode` shown below the path in tertiary style
   when present (e.g., `"ASSET"`, `"EXPENSE"`).

 # Kind Color Coding

 | Kind | Account type | Color  |
 |------|--------------|--------|
 | 1    | Asset        | Blue   |
 | 2    | Liability    | Red    |
 | 3    | Equity       | Purple |
 | 4    | Revenue      | Green  |
 | 5    | Expense      | Orange |
 | else | Other        | Gray   |

 - Note: `fullPath` defaults to `nil`. When absent, the row falls back to `account.name`.
 - SeeAlso: `SplitLineRow.accountPickerButton`, `AccountTreeBuilder.buildPathMap(from:)`
 */
private struct AccountPickerRow: View {

    /// The account node this row represents.
    let account: AccountNode

    /// The full GnuCash-style colon-separated path for this account, if available.
    ///
    /// When non-`nil`, this is shown as the primary label instead of `account.name`.
    /// Sourced from `accountPaths[account.id]` in the parent `SplitLineRow`.
    var fullPath: String? = nil

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kindColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                // Show full path when available; fall back to bare account name.
                // Truncate from the left so the leaf account name remains readable.
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

    // MARK: - Helpers

    /// Color associated with the account's kind, used for the kind-indicator dot.
    ///
    /// Provides at-a-glance visual differentiation between account categories without
    /// requiring the user to read the type code label.
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
