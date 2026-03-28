//
//  Features/Accounts/AccountFormViewModel.swift
//  AccountFormViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-25.
//  Last modified by León Felie Guevara Chávez on 2026-03-28
//  Developed with AI assistance.
//

import Foundation

/// Notification posted when an account is successfully saved (created or updated).
///
/// This notification is posted by `AccountFormViewModel.save(mode:token:)` after
/// successfully creating or updating an account. The notification's `object` is the
/// ledger ID (`UUID`) of the affected ledger.
///
/// ## Usage
///
/// **Observing account saves:**
/// ```swift
/// NotificationCenter.default.addObserver(
///     forName: .accountSaved,
///     object: nil,
///     queue: .main
/// ) { notification in
///     if let ledgerId = notification.object as? UUID {
///         // Refresh account tree for this ledger
///         await reloadAccounts(for: ledgerId)
///     }
/// }
/// ```
///
/// **In SwiftUI:**
/// ```swift
/// .onReceive(NotificationCenter.default.publisher(for: .accountSaved)) { notification in
///     if let ledgerId = notification.object as? UUID,
///        ledgerId == currentLedger.id {
///         Task {
///             await viewModel.loadAccounts(ledgerID: ledgerId, token: token)
///         }
///     }
/// }
/// ```
///
/// - Note: Posted on successful save only (not on validation failures or API errors).
/// - SeeAlso: ``AccountFormViewModel/save(mode:token:)``, ``AccountTreeView``
extension Notification.Name {
    /// Posted when an account is saved, with the ledger UUID as the object.
    static let accountSaved = Notification.Name("com.leonfelipe.mab.accountSaved")
}

/// View model managing the account creation and editing form.
///
/// `AccountFormViewModel` handles the complete lifecycle of account form interactions,
/// including loading account types, validating user input, creating new accounts, updating
/// existing accounts, and posting opening balance transactions when needed.
///
/// ## Features
///
/// - **Dual mode operation**: Create new accounts or edit existing ones via ``Mode``.
/// - **Account type catalog**: Loads and presents available ``AccountTypeItem`` values from the backend.
/// - **Parent account selection**: Supports hierarchical account structure with optional suggested parent.
/// - **Opening balance**: Posts initial balance transaction for new accounts.
/// - **Placeholder support**: Allows creating organizational accounts without a type.
/// - **Validation**: Ensures required fields are populated before saving (see ``canSave``).
/// - **Error handling**: Captures and displays API errors with user-friendly messages.
/// - **Change notifications**: Posts ``Notification/Name/accountSaved`` when an account is saved.
///
/// ## Usage
///
/// **Creating a new account with a suggested parent:**
/// ```swift
/// let viewModel = AccountFormViewModel()
///
/// let mode = AccountFormViewModel.Mode.create(
///     ledger: currentLedger,
///     suggestedParent: assetsRootAccount,
///     suggestedName: nil
/// )
///
/// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
///
/// viewModel.name = "Business Checking"
/// viewModel.code = "1010"
/// viewModel.selectedAccountType = bankAccountType
/// viewModel.accountRole = AccountRole.bank.rawValue  // 101
///
/// await viewModel.save(mode: mode, token: authToken)
///
/// if viewModel.didSave { /* dismiss form */ }
/// ```
///
/// **Editing an existing account:**
/// ```swift
/// let payload = AccountFormPayload(node: selectedAccount)
/// let mode = AccountFormViewModel.Mode.edit(ledger: currentLedger, account: payload)
///
/// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
/// viewModel.name = "Updated Account Name"
/// await viewModel.save(mode: mode, token: authToken)
/// ```
///
/// ## State Management
///
/// Uses the `@Observable` macro (macOS 14+) for automatic SwiftUI view updates.
/// All mutable properties trigger view refreshes when changed.
///
/// ## Change Notification
///
/// On a successful save, posts ``Notification/Name/accountSaved`` with the ledger UUID
/// as the object, allowing views like ``AccountTreeView`` to refresh without polling.
///
/// - SeeAlso: ``AccountFormPayload``, ``CreateAccountRequest``, ``PatchAccountRequest``,
///   ``AccountFormView``, ``AccountFormWindowContent``
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
    ///   - `suggestedParent`: Optional parent account to pre-select in the form
    ///   - `suggestedName`: Optional account name to pre-fill in the form
    ///
    /// - **edit**: Editing an existing account
    ///   - `ledger`: The ledger context (for validation)
    ///   - `account`: Payload containing the current account data
    ///
    /// ## Suggested Parent Usage
    ///
    /// The `suggestedParent` parameter in create mode enables "Add Sub-Account" workflows
    /// where the parent is already known (e.g., from a context menu action):
    ///
    /// ```swift
    /// // User right-clicks "Assets" and chooses "Add Sub-Account"
    /// let mode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: assetsAccount,  // Pre-selects "Assets" as parent
    ///     suggestedName: nil
    /// )
    /// ```
    ///
    /// ## Suggested Name Usage
    ///
    /// The `suggestedName` parameter enables pre-filling the account name from a search
    /// query or user input (e.g., from transaction form account pickers):
    ///
    /// ```swift
    /// // User types "Savings" in account picker and clicks "New Account..."
    /// let mode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: nil,
    ///     suggestedName: "Savings"  // Pre-fills name field
    /// )
    /// ```
    ///
    /// When `load(mode:allRoots:token:)` is called with this mode, the view model
    /// automatically sets `selectedParent` and `name` if provided, streamlining
    /// the account creation workflow.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Create mode with suggested parent only (from account tree)
    /// let createMode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: assetsRoot,
    ///     suggestedName: nil
    /// )
    ///
    /// // Create mode with suggested name only (from transaction form)
    /// let createMode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: nil,
    ///     suggestedName: "Savings"
    /// )
    ///
    /// // Create mode with no suggestions
    /// let createMode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: nil,
    ///     suggestedName: nil
    /// )
    ///
    /// // Edit mode
    /// let editMode = Mode.edit(
    ///     ledger: currentLedger,
    ///     account: AccountFormPayload(node: existingAccount)
    /// )
    /// ```
    ///
    /// - SeeAlso: ``load(mode:allRoots:token:)``, ``AccountFormWindowPayload``
    enum Mode {
        /// Creating a new account with optional suggested parent and name.
        case create(ledger: LedgerResponse, suggestedParent: AccountNode?, suggestedName: String?)
        
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
    
    /// The operational role for this account, stored as the raw `Int` value of ``AccountRole``.
    ///
    /// Defaults to `0` (``AccountRole/unspecified``). Use ``AccountRole`` raw values when
    /// setting this field (e.g., `AccountRole.bank.rawValue` = 101).
    ///
    /// - SeeAlso: ``AccountRole``
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
    /// Populated by ``load(mode:allRoots:token:)``. Used to populate the
    /// account type picker in the form UI.
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
    /// the account type catalog from the backend and, depending on the mode, pre-populates
    /// form fields with either suggested defaults (create) or existing values (edit).
    ///
    /// ## Behavior by Mode
    ///
    /// **Create mode:**
    /// - Fetches account types from backend
    /// - Sets `selectedParent` to the `suggestedParent` if provided
    /// - Sets `name` to the `suggestedName` if provided and non-empty
    /// - Leaves other fields at their default values for user input
    ///
    /// **Edit mode:**
    /// - Fetches account types from backend
    /// - Pre-fills: name, code, placeholder status, hidden status, and role
    /// - Resolves parent account UUID to `AccountNode` reference using `allRoots`
    /// - Resolves account type code to `AccountTypeItem` reference
    ///
    /// ## Suggested Parent Flow
    ///
    /// The suggested parent feature enables "Add Sub-Account" workflows:
    ///
    /// ```swift
    /// // User right-clicks "Cash" account and selects "Add Sub-Account"
    /// let mode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: cashAccount,  // Pre-select Cash as parent
    ///     suggestedName: nil
    /// )
    ///
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: token)
    ///
    /// // Now viewModel.selectedParent == cashAccount
    /// // User sees "Cash" pre-selected in parent picker
    /// ```
    ///
    /// ## Suggested Name Flow
    ///
    /// The suggested name feature enables pre-filling from search queries:
    ///
    /// ```swift
    /// // User types "Savings" in transaction form picker and clicks "New Account..."
    /// let mode = Mode.create(
    ///     ledger: currentLedger,
    ///     suggestedParent: nil,
    ///     suggestedName: "Savings"  // Pre-fill name
    /// )
    ///
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: token)
    ///
    /// // Now viewModel.name == "Savings"
    /// // User can modify or accept the pre-filled name
    /// ```
    ///
    /// ## Loading Flow
    ///
    /// 1. Sets `isLoading = true`
    /// 2. Fetches account types from backend via `AccountService`
    /// 3. Populates form fields based on mode (create or edit)
    /// 4. Sets `isLoading = false`
    /// 5. On error, sets `errorMessage` with user-friendly message
    ///
    /// ## Usage Examples
    ///
    /// **Create with suggested parent:**
    /// ```swift
    /// let mode = Mode.create(ledger: ledger, suggestedParent: assetsAccount, suggestedName: nil)
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
    /// // selectedParent is now assetsAccount
    /// ```
    ///
    /// **Create with suggested name:**
    /// ```swift
    /// let mode = Mode.create(ledger: ledger, suggestedParent: nil, suggestedName: "Savings")
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
    /// // name is now "Savings"
    /// ```
    ///
    /// **Edit existing:**
    /// ```swift
    /// let payload = AccountFormPayload(node: existingAccount)
    /// let mode = Mode.edit(ledger: ledger, account: payload)
    /// await viewModel.load(mode: mode, allRoots: accountTree, token: authToken)
    /// // All fields pre-populated from existing account
    /// ```
    ///
    /// ## Parameters
    ///
    /// - Parameters:
    ///   - mode: The form mode (create or edit) determining pre-population behavior
    ///   - allRoots: The complete account tree for resolving parent references and
    ///               populating the parent/contra account pickers
    ///   - token: Authentication token for the account types API request
    ///
    /// ## Error Handling
    ///
    /// On network or parsing errors, sets `errorMessage` with the localized description.
    /// The UI should display this in an alert or error banner.
    ///
    /// - Note: This method runs on the main actor and updates UI state properties.
    /// - SeeAlso: ``Mode``, ``AccountService``
    @MainActor
    func load(mode: Mode, allRoots: [AccountNode], token: String) async {
        isLoading = true
        do {
            accountTypes = try await AccountService.shared.fetchAccountTypes(token: token)

            switch mode {
            case .create(_, let suggestedParent, let suggestedName):
                selectedParent = suggestedParent
                if let suggestedName, !suggestedName.isEmpty {
                    name = suggestedName
                }          // don't overwrite if already set

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
    /// ## Validation
    ///
    /// Checks that:
    /// - Name is not empty (after trimming whitespace)
    /// - Parent account is selected
    /// - Non-placeholder accounts have a type selected
    ///
    /// If validation fails, returns early without attempting to save.
    ///
    /// ## Create Mode Flow
    ///
    /// 1. Builds `CreateAccountRequest` from form fields
    /// 2. Posts request to backend via `AccountService.createAccount()`
    /// 3. If opening balance provided (`hasOpeningBalance == true`):
    ///    - Posts opening balance transaction with two splits (DR new account, CR contra)
    /// 4. Sets `didSave = true` on success
    /// 5. Posts `.accountSaved` notification with ledger ID for UI refresh
    ///
    /// ## Edit Mode Flow
    ///
    /// 1. Builds `PatchAccountRequest` from form fields
    /// 2. Sends PATCH request to backend via `AccountService.patchAccount()`
    /// 3. Sets `didSave = true` on success
    /// 4. Posts `.accountSaved` notification with ledger ID for UI refresh
    ///
    /// ## Opening Balance Transaction
    ///
    /// If creating an account with a non-zero opening balance:
    /// ```
    /// Date: openingBalanceDate
    /// Memo: "Opening balance"
    ///
    /// Splits:
    /// - DR  New Account            $1,000.00
    /// - CR  Opening Balance Equity $1,000.00
    /// ```
    ///
    /// ## Change Notification
    ///
    /// On successful save, posts `Notification.Name.accountSaved` with the ledger's
    /// UUID as the object. Views observing this notification can refresh their
    /// account data:
    ///
    /// ```swift
    /// .onReceive(NotificationCenter.default.publisher(for: .accountSaved)) { notification in
    ///     if let ledgerId = notification.object as? UUID,
    ///        ledgerId == currentLedger.id {
    ///         Task { await reloadAccounts() }
    ///     }
    /// }
    /// ```
    ///
    /// ## Usage
    ///
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
    /// ## Parameters
    ///
    /// - Parameters:
    ///   - mode: The form mode (create or edit) determining which save operation to perform
    ///   - token: Authentication token for API requests
    ///
    /// ## State Changes
    ///
    /// - Sets `isSaving = true` at start, `false` when complete
    /// - Sets `errorMessage` on failure (with localized description)
    /// - Sets `didSave = true` on success
    /// - Posts `.accountSaved` notification on success
    ///
    /// - Note: This method runs on the main actor and updates UI state properties.
    /// - SeeAlso: ``canSave``, ``Notification/Name/accountSaved``
    @MainActor
    func save(mode: Mode, token: String) async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil

        do {
            switch mode {
            case .create(let ledger, _, _):
                try await saveCreate(ledger: ledger, token: token)

            case .edit(let ledger, let existing):
                try await savePatch(
                    ledger: ledger,
                    accountId: existing.id,
                    originalRole: existing.accountRole,
                    token: token
                )
            }
            didSave = true
            
            // Extract ledger ID and post notification to refresh UI
            let notificationLedger: LedgerResponse
            switch mode {
            case .create(let l, _, _): notificationLedger = l
            case .edit(let l, _):   notificationLedger = l
            }
            NotificationCenter.default.post(
                name: .accountSaved,
                object: notificationLedger.id
            )
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
    /// Builds a ``PatchAccountRequest`` with all form fields and sends it to the backend.
    /// `accountRole` is only included in the patch when it differs from `originalRole`,
    /// avoiding spurious role updates when the user hasn't changed the role field.
    ///
    /// - Parameters:
    ///   - ledger: The ledger context (unused at present; reserved for future validation).
    ///   - accountId: The UUID of the account to update.
    ///   - originalRole: The account's role value at load time. The patch omits `accountRole`
    ///     when the current ``accountRole`` equals this value.
    ///   - token: Authentication token.
    ///
    /// - Throws: `APIError` if the update fails.
    private func savePatch(ledger: LedgerResponse,
                           accountId: UUID,
                           originalRole: Int,
                           token: String) async throws {
        let request = PatchAccountRequest(
            name:            name.trimmingCharacters(in: .whitespaces),
            code:            code.isEmpty ? nil : code.trimmingCharacters(in: .whitespaces),
            parentId:        selectedParent?.id,
            accountTypeCode: isPlaceholder ? nil : selectedAccountType?.code,
            accountRole:     accountRole != originalRole ? accountRole : nil,
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
    /// ``AccountNode`` references when loading the form in edit mode.
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
