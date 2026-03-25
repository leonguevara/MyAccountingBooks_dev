//
//  Features/Accounts/AccountFormViewModel.swift
//  AccountFormViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-25.
//  Developed with AI assistance.
//

import Foundation

/// View model managing the account creation and editing form.
///
/// `AccountFormViewModel` handles the complete lifecycle of account form interactions,
/// including loading account types, validating user input, creating new accounts, updating
/// existing accounts, and posting opening balance transactions when needed.
///
/// ## Features
///
/// - **Dual mode operation**: Create new accounts or edit existing ones
/// - **Account type catalog**: Loads and presents available account types
/// - **Parent account selection**: Supports hierarchical account structure
/// - **Opening balance**: Posts initial balance transaction for new accounts
/// - **Placeholder support**: Allows creating organizational accounts
/// - **Validation**: Ensures required fields are populated before saving
/// - **Error handling**: Captures and displays API errors
///
/// ## Usage
///
/// **Creating a new account:**
/// ```swift
/// let viewModel = AccountFormViewModel()
/// let mode = AccountFormViewModel.Mode.create(
///     ledger: currentLedger,
///     suggestedParent: assetsRoot
/// )
///
/// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
///
/// // User fills in form fields
/// viewModel.name = "Business Checking"
/// viewModel.code = "1010"
/// viewModel.selectedAccountType = bankAccountType
/// viewModel.accountRole = 1  // Asset
///
/// await viewModel.save(mode: mode, token: authToken)
///
/// if viewModel.didSave {
///     // Success - dismiss form
/// }
/// ```
///
/// **Editing an existing account:**
/// ```swift
/// let payload = AccountFormPayload(node: selectedAccount)
/// let mode = AccountFormViewModel.Mode.edit(
///     ledger: currentLedger,
///     account: payload
/// )
///
/// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
///
/// // Form is pre-populated with existing values
/// // User makes changes
/// viewModel.name = "Updated Account Name"
///
/// await viewModel.save(mode: mode, token: authToken)
/// ```
///
/// **Opening balance flow:**
/// ```swift
/// // When creating a new account
/// viewModel.openingBalanceAmount = "1000.00"
/// viewModel.openingBalanceDate = startOfYear
/// viewModel.openingBalanceAccount = equityAccount  // Contra account
///
/// await viewModel.save(mode: .create(...), token: authToken)
/// // Automatically posts a transaction with opening balance
/// ```
///
/// - Note: Uses the `@Observable` macro for SwiftUI state management.
/// - SeeAlso: `AccountFormPayload`, `CreateAccountRequest`, `PatchAccountRequest`
@Observable
final class AccountFormViewModel {

    // MARK: - Mode

    /// Defines whether the form is in create or edit mode.
    ///
    /// The mode determines:
    /// - Which fields are pre-populated
    /// - Whether a POST or PATCH request is sent
    /// - Whether opening balance functionality is available (create only)
    ///
    /// ## Cases
    ///
    /// - **create**: Creating a new account
    ///   - `ledger`: The ledger context for the new account
    ///   - `suggestedParent`: Optional parent account to pre-select
    ///
    /// - **edit**: Editing an existing account
    ///   - `ledger`: The ledger context (for validation)
    ///   - `account`: Payload containing the current account data
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Create mode
    /// let createMode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: assetsRoot
    /// )
    ///
    /// // Edit mode
    /// let editMode = Mode.edit(
    ///     ledger: currentLedger,
    ///     account: AccountFormPayload(node: existingAccount)
    /// )
    /// ```
    enum Mode {
        /// Creating a new account with optional suggested parent.
        case create(ledger: LedgerResponse, suggestedParent: AccountNode?)
        
        /// Editing an existing account with current values.
        case edit(ledger: LedgerResponse, account: AccountFormPayload)
    }

    // MARK: - Form State

    /// The display name of the account being created or edited.
    ///
    /// This is the primary identifier users see in the chart of accounts.
    /// Must not be empty to save (validated by `canSave`).
    var name: String = ""
    
    /// Optional account code or number (e.g., "1010", "4000").
    ///
    /// Many accounting systems use numeric codes to organize accounts.
    /// If empty, no code is assigned to the account.
    var code: String = ""
    
    /// The parent account in the chart of accounts hierarchy.
    ///
    /// Required for all accounts. Use the root account or a category account
    /// as the parent. The account will appear as a child of this parent in
    /// the account tree.
    var selectedParent: AccountNode?
    
    /// The selected account type from the catalog (e.g., "Bank Account", "Equity").
    ///
    /// Required for non-placeholder accounts. Determines the account's classification
    /// and normal balance direction. Placeholder accounts don't require a type.
    var selectedAccountType: AccountTypeItem?
    
    /// The fundamental accounting category (role) for this account.
    ///
    /// Values:
    /// - 1: Asset
    /// - 2: Liability
    /// - 3: Equity
    /// - 4: Income
    /// - 5: Expense
    ///
    /// Must be compatible with the parent account's role.
    var accountRole: Int = 0
    
    /// Whether this is a placeholder (organizational) account.
    ///
    /// Placeholder accounts:
    /// - Cannot have transactions posted directly to them
    /// - Are used to organize the chart of accounts (e.g., "Current Assets")
    /// - Don't require an account type
    var isPlaceholder: Bool = false
    
    /// Whether this account should be hidden from most UI views.
    ///
    /// Hidden accounts are typically inactive or archived accounts that should
    /// not appear in account selection pickers or reports.
    var isHidden: Bool = false

    // MARK: - Opening Balance
    
    /// The opening balance amount as a string (for text field binding).
    ///
    /// Only used in create mode. If non-zero, an opening balance transaction
    /// will be automatically posted when the account is created.
    ///
    /// Example: "1000.00"
    var openingBalanceAmount: String = ""
    
    /// The date for the opening balance transaction.
    ///
    /// Typically set to the start of the accounting period or the date when
    /// the account was first opened. Defaults to current date/time.
    var openingBalanceDate: Date = .now
    
    /// The contra account for the opening balance transaction.
    ///
    /// Usually an equity account (e.g., "Opening Balances", "Retained Earnings").
    /// Required if an opening balance is provided.
    ///
    /// The transaction will be:
    /// - Debit: New account (opening balance amount)
    /// - Credit: This contra account (same amount)
    var openingBalanceAccount: AccountNode?

    // MARK: - UI State

    /// The complete catalog of account types loaded from the backend.
    ///
    /// Populated by `load()`. Used to populate the account type picker
    /// in the form UI.
    var accountTypes: [AccountTypeItem] = []
    
    /// `true` while loading account types and populating the form.
    ///
    /// Use this to show a loading indicator while initial data is fetched.
    var isLoading = false
    
    /// `true` while the save operation is in progress.
    ///
    /// Use this to disable the save button and show a progress indicator.
    var isSaving = false
    
    /// Contains a user-friendly error message if an operation fails.
    ///
    /// Set when loading or saving fails. Display this in an alert or error banner.
    var errorMessage: String?
    
    /// `true` if the account was successfully saved.
    ///
    /// Use this to trigger navigation away from the form or dismiss the window.
    var didSave = false

    // MARK: - Validation

    /// Returns `true` if the form is valid and ready to save.
    ///
    /// Checks:
    /// - Name is not empty (after trimming whitespace)
    /// - Parent account is selected
    /// - Either account is a placeholder OR an account type is selected
    /// - Not currently saving
    ///
    /// Use this to enable/disable the save button:
    /// ```swift
    /// Button("Save") { ... }
    ///     .disabled(!viewModel.canSave)
    /// ```
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && selectedParent != nil
        && (isPlaceholder || selectedAccountType != nil)
        && !isSaving
    }

    /// Returns `true` if a valid opening balance has been entered.
    ///
    /// Checks if `openingBalanceAmount` can be parsed as a `Decimal`
    /// and is non-zero. Used to determine whether to post an opening
    /// balance transaction during account creation.
    var hasOpeningBalance: Bool {
        guard let amount = Decimal(string: openingBalanceAmount) else { return false }
        return amount != .zero
    }

    // MARK: - Load

    /// Loads account types and pre-populates form fields based on the mode.
    ///
    /// This method must be called before presenting the form to the user. It fetches
    /// the account type catalog from the backend and, in edit mode, resolves existing
    /// account data to populate form fields.
    ///
    /// **Behavior by mode:**
    ///
    /// - **Create mode**: Sets `selectedParent` to the suggested parent (if provided)
    /// - **Edit mode**:
    ///   - Pre-fills name, code, placeholder status, hidden status, and role
    ///   - Resolves parent account UUID to `AccountNode` reference
    ///   - Resolves account type code to `AccountTypeItem` reference
    ///
    /// **Flow:**
    /// 1. Sets `isLoading = true`
    /// 2. Fetches account types from the backend
    /// 3. Populates form fields based on mode
    /// 4. Sets `isLoading = false`
    /// 5. On error, sets `errorMessage`
    ///
    /// **Usage:**
    /// ```swift
    /// let mode = Mode.create(ledger: ledger, suggestedParent: nil)
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
    ///
    /// // Form is now ready for user input
    /// if let error = viewModel.errorMessage {
    ///     // Handle error
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - mode: The form mode (create or edit) determining pre-population behavior
    ///   - allRoots: The complete account tree for resolving parent and contra account references
    ///   - token: Authentication token for the account types request
    ///
    /// - Note: This method runs on the main actor and updates UI state properties.
    @MainActor
    func load(mode: Mode, allRoots: [AccountNode], token: String) async {
        isLoading = true
        do {
            accountTypes = try await AccountService.shared.fetchAccountTypes(token: token)

            switch mode {
            case .create(_, let suggestedParent):
                selectedParent = suggestedParent

            case .edit(_, let existing):
                name          = existing.name
                code          = existing.code ?? ""
                isPlaceholder = existing.isPlaceholder
                isHidden      = existing.isHidden
                accountRole   = existing.accountRole

                // Resolve parent node
                selectedParent = findNode(id: existing.parentId, in: allRoots)

                // Resolve account type
                selectedAccountType = accountTypes.first {
                    $0.code == existing.accountTypeCode
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Save

    /// Saves the account by creating a new account or updating an existing one.
    ///
    /// This method validates the form via `canSave`, then dispatches to either
    /// `saveCreate()` or `savePatch()` based on the mode. In create mode with an
    /// opening balance, it also posts an opening balance transaction automatically.
    ///
    /// **Validation:**
    /// - Name must not be empty
    /// - Parent account must be selected
    /// - Non-placeholder accounts must have a type selected
    ///
    /// **Create mode flow:**
    /// 1. Builds `CreateAccountRequest` from form fields
    /// 2. Creates the account via `AccountService`
    /// 3. If opening balance provided, posts opening balance transaction
    /// 4. Sets `didSave = true` on success
    ///
    /// **Edit mode flow:**
    /// 1. Builds `PatchAccountRequest` from form fields
    /// 2. Updates the account via `AccountService`
    /// 3. Sets `didSave = true` on success
    ///
    /// **Usage:**
    /// ```swift
    /// await viewModel.save(mode: mode, token: authToken)
    ///
    /// if viewModel.didSave {
    ///     // Success - dismiss form
    ///     dismiss()
    /// } else if let error = viewModel.errorMessage {
    ///     // Show error alert
    ///     showAlert(error)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - mode: The form mode (create or edit) determining which save operation to perform
    ///   - token: Authentication token for API requests
    ///
    /// - Note: Sets `isSaving = true` during the operation and `false` when complete.
    ///         Updates `errorMessage` on failure and `didSave` on success.
    @MainActor
    func save(mode: Mode, token: String) async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil

        do {
            switch mode {
            case .create(let ledger, _):
                try await saveCreate(ledger: ledger, token: token)

            case .edit(let ledger, let existing):
                try await savePatch(
                    ledger: ledger,
                    accountId: existing.id,
                    token: token
                )
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Private

    /// Creates a new account and optionally posts an opening balance transaction.
    ///
    /// Builds a `CreateAccountRequest` from the current form state and sends it to
    /// the backend. If an opening balance is provided (non-zero amount with a contra
    /// account selected), automatically posts a balancing transaction.
    ///
    /// - Parameters:
    ///   - ledger: The ledger context for the new account
    ///   - token: Authentication token
    ///
    /// - Throws: `APIError` if account creation or transaction posting fails
    private func saveCreate(ledger: LedgerResponse, token: String) async throws {
        let request = CreateAccountRequest(
            ledgerId:        ledger.id,
            name:            name.trimmingCharacters(in: .whitespaces),
            code:            code.isEmpty ? nil : code.trimmingCharacters(in: .whitespaces),
            parentId:        selectedParent!.id,
            accountTypeCode: isPlaceholder ? nil : selectedAccountType?.code,
            accountRole:     accountRole,
            isPlaceholder:   isPlaceholder,
            isHidden:        isHidden
        )
        let created = try await AccountService.shared.createAccount(request, token: token)

        // Post opening balance if provided
        if hasOpeningBalance, let balanceAccount = openingBalanceAccount {
            try await postOpeningBalance(
                newAccountId: created.id,
                ledger: ledger,
                contraAccount: balanceAccount,
                token: token
            )
        }
    }

    /// Updates an existing account with the current form values.
    ///
    /// Builds a `PatchAccountRequest` with all form fields and sends it to the backend.
    /// All fields are included (even if unchanged) since this is a full form submission.
    ///
    /// - Parameters:
    ///   - ledger: The ledger context (for validation)
    ///   - accountId: The UUID of the account to update
    ///   - token: Authentication token
    ///
    /// - Throws: `APIError` if the update fails
    private func savePatch(ledger: LedgerResponse,
                           accountId: UUID,
                           token: String) async throws {
        let request = PatchAccountRequest(
            name:            name.trimmingCharacters(in: .whitespaces),
            code:            code.isEmpty ? nil : code.trimmingCharacters(in: .whitespaces),
            parentId:        selectedParent?.id,
            accountTypeCode: isPlaceholder ? nil : selectedAccountType?.code,
            accountRole:     accountRole,
            isPlaceholder:   isPlaceholder,
            isHidden:        isHidden
        )
        _ = try await AccountService.shared.patchAccount(
            id: accountId, request, token: token
        )
    }

    /// Posts an opening balance transaction for a newly created account.
    ///
    /// Creates a transaction with two splits:
    /// 1. Debit to the new account (the opening balance amount)
    /// 2. Credit to the contra account (typically equity)
    ///
    /// This establishes the account's initial balance without requiring manual
    /// transaction entry.
    ///
    /// **Transaction structure:**
    /// ```
    /// Date: openingBalanceDate
    /// Memo: "Opening balance"
    ///
    /// Splits:
    /// - DR  New Account        $1,000.00
    /// - CR  Opening Balances   $1,000.00
    /// ```
    ///
    /// - Parameters:
    ///   - newAccountId: The UUID of the newly created account
    ///   - ledger: The ledger context (for currency and decimal places)
    ///   - contraAccount: The equity/contra account to balance against
    ///   - token: Authentication token
    ///
    /// - Throws: `APIError` if the transaction posting fails
    private func postOpeningBalance(
        newAccountId: UUID,
        ledger: LedgerResponse,
        contraAccount: AccountNode,
        token: String
    ) async throws {
        guard let amount = Decimal(string: openingBalanceAmount),
              amount != .zero else { return }

        let denom = Int(pow(10.0, Double(ledger.decimalPlaces)))
        let valueNum = Int(truncating: (amount * Decimal(denom)) as NSDecimalNumber)
        guard let commodityId = ledger.currencyCommodityId else { return }

        let request = PostTransactionRequest(
            ledgerId:            ledger.id,
            currencyCommodityId: commodityId,
            postDate:            openingBalanceDate,
            enterDate:           nil,
            memo:                "Opening balance",
            num:                 nil,
            status:              0,
            payeeId:             nil,
            splits: [
                SplitRequest(
                    accountId:     newAccountId,
                    side:          0,           // debit new account
                    valueNum:      valueNum,
                    valueDenom:    denom,
                    quantityNum:   0,
                    quantityDenom: denom,
                    memo:          nil,
                    action:        nil
                ),
                SplitRequest(
                    accountId:     contraAccount.id,
                    side:          1,           // credit contra account
                    valueNum:      valueNum,
                    valueDenom:    denom,
                    quantityNum:   0,
                    quantityDenom: denom,
                    memo:          nil,
                    action:        nil
                )
            ]
        )
        _ = try await PostTransactionService.shared.post(request, token: token)
    }

    /// Recursively searches for an account node by UUID in the account tree.
    ///
    /// Performs a depth-first search through the account hierarchy to find
    /// a node matching the given UUID. Used to resolve account UUIDs to
    /// `AccountNode` references when loading the form in edit mode.
    ///
    /// - Parameters:
    ///   - id: The UUID to search for, or `nil` to return `nil` immediately
    ///   - nodes: The array of account nodes to search (root level or children)
    ///
    /// - Returns: The matching `AccountNode` if found, or `nil` if not found
    private func findNode(id: UUID?, in nodes: [AccountNode]) -> AccountNode? {
        guard let id else { return nil }
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(id: id, in: node.children) { return found }
        }
        return nil
    }
}
