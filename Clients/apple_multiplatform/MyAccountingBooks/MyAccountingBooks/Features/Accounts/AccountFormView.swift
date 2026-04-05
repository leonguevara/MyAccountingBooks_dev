//
//  Features/Accounts/AccountFormView.swift
//  AccountFormView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-25.
//  Last modified by León Felie Guevara Chávez on 2026-03-28
//  Developed with AI assistance.
//

import SwiftUI

// MARK: - Account Form Window Content

/// Window content wrapper that bridges `AccountFormWindowPayload` to `AccountFormView`.
///
/// `AccountFormWindowContent` receives the payload from SwiftUI's `WindowGroup` and
/// translates it into the appropriate mode for `AccountFormView`. This separation allows
/// the window system to pass codable payloads while the view works with rich domain models.
///
/// ## Usage
///
/// Register in your app's `WindowGroup`:
/// ```swift
/// WindowGroup(for: AccountFormWindowPayload.self) { $payload in
///     if let payload = payload {
///         AccountFormWindowContent(payload: payload)
///     }
/// }
/// ```
///
/// Open the window for creating a new account:
/// ```swift
/// // Create account with no parent pre-selected
/// let payload = AccountFormWindowPayload(
///     ledger: currentLedger,
///     existingAccount: nil,
///     suggestedParentId: nil
/// )
/// openWindow(value: payload)
///
/// // Create account with suggested parent (e.g., "Add Sub-Account")
/// let payload = AccountFormWindowPayload(
///     ledger: currentLedger,
///     existingAccount: nil,
///     suggestedParentId: parentAccount.id  // Pre-select parent
/// )
/// openWindow(value: payload)
/// ```
///
/// Open the window for editing an existing account:
/// ```swift
/// let payload = AccountFormWindowPayload(
///     ledger: currentLedger,
///     existingAccount: AccountFormPayload(node: selectedAccount),
///     suggestedParentId: nil  // Not used in edit mode
/// )
/// openWindow(value: payload)
/// ```
///
/// ## Parent Selection
///
/// The `suggestedParentId` field in the payload is intended for pre-selecting a parent
/// account when creating new accounts (e.g., when clicking "Add Sub-Account" in the
/// account tree context menu).
///
/// **Partial implementation note:** `suggestedName` is fully wired — it is passed through
/// to `AccountFormViewModel.Mode.create` and pre-fills the account name field. However,
/// `suggestedParentId` is not yet wired: `formMode` always passes `suggestedParent: nil`.
/// To complete that feature, the UUID would need to be resolved to an `AccountNode` after
/// the account tree loads in `AccountFormView`'s `.task` modifier.
///
/// - Note: The account tree is loaded inside ``AccountFormView`` via its `.task` modifier,
///   which allows for deferred parent resolution after the tree data is available.
/// - SeeAlso: ``AccountFormWindowPayload``, ``AccountFormView``, ``AccountFormViewModel``
struct AccountFormWindowContent: View {

    /// The payload passed from the window system containing ledger and optional account data.
    let payload: AccountFormWindowPayload
    
    @Environment(AuthService.self) private var auth

    var body: some View {
        AccountFormView(
            mode: formMode  //,
            //allRoots: []    // roots loaded inside AccountFormView
        )
        .environment(auth)
    }

    /// Converts the window payload into the appropriate form mode.
    ///
    /// - If `existingAccount` is present: Returns `.edit` mode
    /// - If `existingAccount` is `nil`: Returns `.create` mode
    ///
    /// ## Parent Pre-Selection
    ///
    /// `suggestedName` is forwarded directly to `Mode.create` and pre-fills the account
    /// name field. `suggestedParentId`, however, cannot be resolved here because the account
    /// tree hasn't loaded yet — `formMode` always passes `suggestedParent: nil`.
    ///
    /// To wire up `suggestedParentId` in the future:
    /// 1. Pass the complete payload to `AccountFormView` (not just the mode)
    /// 2. After `AccountFormView` loads the account tree in its `.task` modifier,
    ///    resolve `payload.suggestedParentId` to an `AccountNode` using the loaded tree
    /// 3. Update `viewModel.selectedParent` with the resolved node
    ///
    /// This deferred resolution pattern avoids blocking the window from opening while
    /// waiting for network requests to complete.
    ///
    /// - Returns: The appropriate ``AccountFormViewModel/Mode`` for the form.
    private var formMode: AccountFormViewModel.Mode {
        if let existing = payload.existingAccount {
            return .edit(ledger: payload.ledger, account: existing)
        }
        return .create(ledger: payload.ledger, suggestedParent: nil, suggestedName: payload.suggestedName)
    }
}

// MARK: - Account Form View

/// A comprehensive form for creating new accounts or editing existing ones in the chart of accounts.
///
/// `AccountFormView` provides a full-featured account management interface with sections for
/// identification (name, code, parent), classification (type, role), options (placeholder, hidden),
/// and optional opening balance entry for new accounts.
///
/// ## Features
///
/// - **Dual mode operation**: Create or edit based on `AccountFormViewModel.Mode`
/// - **Parent selection**: Hierarchical account picker with search
/// - **Suggested parent**: Supports pre-selecting a parent for "Add Sub-Account" workflows
/// - **Account type catalog**: Type picker with placeholder support
/// - **Role selection**: Dropdown with common accounting roles
/// - **Opening balance**: Optional initial balance with contra account (create only)
/// - **Validation**: Real-time form validation with save button state
/// - **Error display**: User-friendly error messages from API failures
///
/// ## Form Sections
///
/// 1. **Identification**: Name, code, parent account
/// 2. **Classification**: Account type and role
/// 3. **Options**: Placeholder and hidden flags
/// 4. **Opening Balance** (create mode only): Amount, date, contra account
///
/// ## Usage
///
/// **Create mode:**
/// ```swift
/// let mode = AccountFormViewModel.Mode.create(
///     ledger: currentLedger,
///     suggestedParent: nil,
///     suggestedName: nil
/// )
///
/// AccountFormView(mode: mode)
/// ```
///
/// **Edit mode:**
/// ```swift
/// let payload = AccountFormPayload(node: existingAccount)
/// let mode = AccountFormViewModel.Mode.edit(
///     ledger: currentLedger,
///     account: payload
/// )
///
/// AccountFormView(mode: mode)
/// ```
///
/// ## Opening Balance
///
/// When creating a new account, users can optionally enter an opening balance:
/// - Amount is entered as a decimal string
/// - Date defaults to current date
/// - Contra account (typically equity) must be selected
/// - Transaction is automatically posted after account creation
///
/// ## Validation
///
/// The save button is enabled only when:
/// - Name is not empty
/// - Parent account is selected
/// - Account type is selected (unless placeholder)
/// - Form is not currently saving
///
/// - Note: Designed for macOS with a minimum window size of 520×560 points.
/// - SeeAlso: ``AccountFormViewModel``, ``AccountFormPayload``, ``AccountFormWindowContent``
struct AccountFormView: View {

    /// The form mode determining create or edit behavior.
    let mode: AccountFormViewModel.Mode
    
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    /// View model managing form state and save operations.
    @State private var viewModel = AccountFormViewModel()
    
    /// Dictionary mapping account UUIDs to full hierarchical paths for display.
    @State private var accountPaths: [UUID: String] = [:]
    
    /// The full account tree for the current ledger, built after the `.task` modifier
    /// fetches the flat account list and passes it through ``AccountTreeBuilder/build(from:)``.
    /// Used by ``AccountNodePicker`` instances in the form.
    @State private var loadedRoots: [AccountNode] = []

    /// The ledger context extracted from the mode.
    private var ledger: LedgerResponse {
        switch mode {
        case .create(let l, _, _): return l
        case .edit(let l, _):   return l
        }
    }

    /// Returns `true` if the form is in edit mode, `false` for create mode.
    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────
            HStack {
                Text(isEditMode ? "Edit Account" : "New Account")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button(viewModel.isSaving ? "Saving…" : "Save") {
                    Task {
                        guard let token = auth.token else { return }
                        await viewModel.save(mode: mode, token: token)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if viewModel.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        identificationSection
                        classificationSection
                        flagsSection
                        if !isEditMode {
                            openingBalanceSection
                        }
                        Text("* Required field")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
        // Account loading: Loads account types first, then fetches the account tree
        // and resolves parent references. In create mode with a suggested parent,
        // the suggestedParentId would be resolved here after loadedRoots is populated.
        .task {
            guard let token = auth.token else { return }
            // Step 1: load account types immediately (fast — no tree needed yet)
            await viewModel.load(mode: mode, allRoots: [], token: token)
            // Step 2: fetch the account tree
            if let flat = try? await AccountService.shared.fetchAccounts(
                ledgerID: ledger.id, token: token
            ) {
                loadedRoots  = AccountTreeBuilder.build(from: flat)
                accountPaths = AccountTreeBuilder.buildPathMap(from: loadedRoots)
                // Step 3: re-run load now that the tree is available so the
                // parent picker can resolve the existing account's parent node
                await viewModel.load(mode: mode, allRoots: loadedRoots, token: token)
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    // MARK: - Identification Section

    /// Form section for account identification: name, code, and parent selection.
    ///
    /// - **Name**: Required text field for the account display name
    /// - **Code**: Optional text field for account code/number
    /// - **Parent**: Required picker for selecting the parent account in the hierarchy
    ///
    /// Uses ``AccountNodePicker`` for parent selection with search functionality.
    private var identificationSection: some View {
        FormSection(title: "Identification") {
            FormRow(label: "Name *") {
                TextField("Account name", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
            }
            FormRow(label: "Code") {
                TextField("e.g. 100-01.001.01", text: $viewModel.code)
                    .textFieldStyle(.roundedBorder)
            }
            FormRow(label: "Parent *") {
                AccountNodePicker(
                    selection: $viewModel.selectedParent,
                    allRoots: loadedRoots,
                    accountPaths: accountPaths,
                    placeholder: "Select parent account…",
                    leafOnly: false
                )
            }
            FormRow(label: "Currency") {
                Picker("", selection: $viewModel.selectedCommodity) {
                    Text("Inherit from parent")
                        .tag(CommodityResponse?.none)
                    ForEach(viewModel.availableCommodities) { c in
                        Text("\(c.mnemonic) — \(c.fullName ?? c.mnemonic)")
                            .tag(CommodityResponse?.some(c))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Classification Section

    /// Form section for account classification: type and role.
    ///
    /// - **Account Type**: Required for non-placeholder accounts; shows informational text for placeholders
    /// - **Role**: Fundamental accounting category (Asset, Liability, Equity, Income, Expense)
    ///
    /// Account type is automatically cleared when placeholder mode is toggled on.
    private var classificationSection: some View {
        FormSection(title: "Classification") {
            FormRow(label: viewModel.isPlaceholder ? "Account Type" : "Account Type *") {
                if viewModel.isPlaceholder {
                    Text("Not required for placeholder accounts")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    AccountTypePicker(
                        selection: $viewModel.selectedAccountType,
                        types: viewModel.accountTypes
                    )
                }
            }
            FormRow(label: "Role") {
                AccountRolePicker(selection: $viewModel.accountRole)
            }
        }
    }

    // MARK: - Flags Section

    /// Form section for account options: placeholder and hidden flags.
    ///
    /// - **Placeholder**: When toggled on, the account becomes organizational only (no direct transactions)
    ///   and the account type is automatically cleared.
    /// - **Hidden**: When toggled on, the account is excluded from default views and pickers.
    ///
    /// The placeholder toggle includes an `.onChange` modifier that clears the account type
    /// when enabled, since placeholder accounts don't require types.
    private var flagsSection: some View {
        FormSection(title: "Options") {
            Toggle("Placeholder (grouping account only)", isOn: $viewModel.isPlaceholder)
                .onChange(of: viewModel.isPlaceholder) { _, isPlaceholder in
                    if isPlaceholder { viewModel.selectedAccountType = nil }
                }
            Toggle("Hidden (exclude from default views)", isOn: $viewModel.isHidden)
        }
    }

    // MARK: - Opening Balance Section

    /// Form section for optional opening balance entry (create mode only).
    ///
    /// Allows setting an initial balance for a new account by specifying:
    /// - **Amount**: Decimal value as a string
    /// - **Date**: Transaction posting date
    /// - **Contra Account**: Equity account to balance against (typically "Opening Balances")
    ///
    /// The opening balance transaction is automatically posted after account creation with:
    /// - Debit: New account (amount)
    /// - Credit: Contra account (amount)
    /// - Memo: "Opening balance"
    ///
    /// Includes explanatory text describing the transaction structure.
    ///
    /// - Note: Only displayed in create mode; not shown when editing existing accounts.
    private var openingBalanceSection: some View {
        FormSection(title: "Opening Balance (Optional)") {
            FormRow(label: "Amount") {
                TextField("0.00", text: $viewModel.openingBalanceAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }
            FormRow(label: "Date") {
                DatePicker("",
                    selection: $viewModel.openingBalanceDate,
                           displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
            FormRow(label: "Contra Account") {
                AccountNodePicker(
                    selection: $viewModel.openingBalanceAccount,
                    allRoots: loadedRoots,
                    accountPaths: accountPaths,
                    placeholder: "Select equity/contra account…",
                    leafOnly: false
                )
            }
            Text("The opening balance will be posted as a transaction debiting this account and crediting the selected contra account.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Reusable Form Components

/// A section container with a title and rounded background for grouping related form fields.
///
/// Provides consistent styling across all form sections with:
/// - Headline title
/// - Rounded background with system control color
/// - 8px corner radius
/// - 12pt padding
///
/// ## Usage
///
/// ```swift
/// FormSection(title: "Identification") {
///     FormRow(label: "Name") { TextField(...) }
///     FormRow(label: "Code") { TextField(...) }
/// }
/// ```
private struct FormSection<Content: View>: View {
    /// The section title displayed above the content.
    let title: String
    
    /// The form fields contained in this section.
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// A horizontal form row with a fixed-width label and flexible content area.
///
/// Provides consistent two-column layout for form fields:
/// - Left column: 110pt wide label, right-aligned, secondary color
/// - Right column: Flexible width content area, left-aligned
/// - 12pt spacing between columns
///
/// ## Usage
///
/// ```swift
/// FormRow(label: "Name") {
///     TextField("Account name", text: $name)
/// }
/// ```
private struct FormRow<Content: View>: View {
    /// The label text displayed on the left side.
    let label: String
    
    /// The form control(s) displayed on the right side.
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Account Node Picker

/// A custom picker for selecting accounts from the chart of accounts with search functionality.
///
/// `AccountNodePicker` provides a dropdown-style picker with these features:
/// - **Search filtering**: Real-time search by account name, path, or code
/// - **Full path display**: Shows complete hierarchical path (e.g., "Assets:Current Assets:Cash")
/// - **Leaf filtering**: Optional filtering to show only non-placeholder accounts
/// - **Lazy loading**: Uses `LazyVStack` for efficient rendering of large account lists
/// - **Expandable dropdown**: Compact button that expands to show search and results
///
/// ## Usage
///
/// **Basic parent account selection (leaf accounts only):**
/// ```swift
/// AccountNodePicker(
///     selection: $selectedParent,
///     allRoots: accountTree,
///     accountPaths: pathDictionary,
///     placeholder: "Select parent account…"
/// )
/// ```
///
/// **Contra account selection (including placeholders):**
/// ```swift
/// AccountNodePicker(
///     selection: $contraAccount,
///     allRoots: accountTree,
///     accountPaths: pathDictionary,
///     placeholder: "Select equity account…",
///     leafOnly: false
/// )
/// ```
///
/// ## Search Behavior
///
/// - Searches account names, full paths, and codes (case-insensitive)
/// - Empty search shows all candidates
/// - Results update in real-time as user types
///
/// - Note: This is a private component used within ``AccountFormView``.
private struct AccountNodePicker: View {
    /// Binding to the selected account node.
    @Binding var selection: AccountNode?
    
    /// The complete chart of accounts hierarchy to choose from.
    let allRoots: [AccountNode]
    
    /// Dictionary mapping account UUIDs to full hierarchical paths for display.
    let accountPaths: [UUID: String]
    
    /// Placeholder text shown when no account is selected.
    let placeholder: String
    
    /// If `true`, filters out placeholder accounts. If `false`, shows all accounts.
    var leafOnly: Bool = true

    @State private var searchText = ""
    @State private var isExpanded = false

    /// Returns filtered accounts based on leaf-only setting and search query.
    ///
    /// - Flattens the account tree
    /// - Filters out placeholders if `leafOnly` is true
    /// - Applies search filter to name, path, and code
    private var candidates: [AccountNode] {
        func flatten(_ nodes: [AccountNode]) -> [AccountNode] {
            nodes.flatMap { node in
                let self_ = (!leafOnly || (!node.isPlaceholder)) ? [node] : []
                return self_ + flatten(node.children)
            }
        }
        let all = flatten(allRoots)
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { node in
            let path = accountPaths[node.id] ?? node.name
            return path.lowercased().contains(query)
                || (node.code?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
                if isExpanded { searchText = "" }
            } label: {
                HStack {
                    Text(selection.map { accountPaths[$0.id] ?? $0.name } ?? placeholder)
                        .foregroundStyle(selection == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search…", text: $searchText).textFieldStyle(.plain)
                    }
                    .padding(8)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(candidates) { node in
                                HStack {
                                    Text(accountPaths[node.id] ?? node.name)
                                        .font(.body).lineLimit(1).truncationMode(.head)
                                    Spacer()
                                    if let code = node.code {
                                        Text(code).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = node
                                    isExpanded = false
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
}

// MARK: - Account Type Picker

/// A picker for selecting an account type from the catalog.
///
/// Displays account types using their `displayName` property which includes both
/// the human-readable name and the code (e.g., "Bank Account (BANK)").
///
/// Includes a "Select type…" option for clearing the selection.
///
/// ## Usage
///
/// ```swift
/// AccountTypePicker(
///     selection: $viewModel.selectedAccountType,
///     types: viewModel.accountTypes
/// )
/// ```
///
/// - Note: This is a private component used within `AccountFormView`.
private struct AccountTypePicker: View {
    /// Binding to the selected account type (optional).
    @Binding var selection: AccountTypeItem?
    
    /// The complete list of available account types from the catalog.
    let types: [AccountTypeItem]

    var body: some View {
        Picker("", selection: $selection) {
            Text("Select type…").tag(Optional<AccountTypeItem>.none)
            ForEach(types) { type_ in
                Text(type_.displayName).tag(Optional(type_))
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Account Role Picker

/// A picker for selecting the account role (fundamental accounting category).
///
/// Displays common accounting roles organized by category with descriptive labels.
/// The role determines the account's fundamental behavior and normal balance direction.
///
/// ## Role Categories
///
/// Populated from ``AccountRole/allCases``; see ``AccountRole`` for the full range layout.
///
/// | Range     | Examples                                        |
/// |-----------|-------------------------------------------------|
/// | 0         | Unspecified                                     |
/// | 100–199   | Cash & Equivalents, Bank, Receivable, Inventory |
/// | 200–299   | Accounts Payable, Taxes Payable, Loans Payable  |
/// | 300–399   | Capital, Retained Earnings, Current Year Result |
/// | 400–499   | Sales Revenue, Service Revenue, Other Income    |
/// | 500–599   | Cost of Goods Sold, Cost of Services            |
/// | 600–699   | Operating, Administrative, Selling Expenses     |
/// | 700, 800  | Memorandum Debit / Credit (off-balance)         |
/// | 900       | KPI / Statistical                               |
/// | 4300–4399 | Financial result roles (RIF / interest, FX…)    |
///
/// ## Usage
///
/// ```swift
/// AccountRolePicker(selection: $viewModel.accountRole)
/// ```
///
/// - Note: This is a private component used within ``AccountFormView``.
/// - SeeAlso: ``AccountRole``
private struct AccountRolePicker: View {
    /// Binding to the selected role code.
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(AccountRole.allCases, id: \.rawValue) { role in
                Text(role.displayName).tag(Int(role.rawValue))
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}
