//
//  Core/Models/AccountForm.swift
//  AccountForm.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-25.
//  Developed with AI assistance.
//

import Foundation

// MARK: - Account Type Catalog

/// Represents a single account type from the backend's account type catalog.
///
/// Account types define the classification and behavior of accounts in the chart of accounts.
/// Each type has a unique code (e.g., "BANK", "EQUITY", "INCOME") and belongs to one of five
/// fundamental accounting categories (kind): Assets, Liabilities, Equity, Income, or Expenses.
///
/// ## Properties
///
/// - **id**: Unique identifier for this account type in the database
/// - **code**: Short alphanumeric code (e.g., "BANK", "EQUITY") — typically uppercase
/// - **name**: Human-readable display name (e.g., "Bank Account", "Opening Balances")
/// - **kind**: Fundamental accounting category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
/// - **normalBalance**: Direction of normal balance (1=Debit, 2=Credit)
/// - **sortOrder**: Suggested ordering for display in dropdowns or lists
///
/// ## Usage
///
/// Account types are fetched from the backend and presented in account creation/edit forms:
///
/// ```swift
/// let types: [AccountTypeItem] = try await APIClient.shared.request(
///     .accountTypes,
///     method: "GET",
///     token: authToken
/// )
///
/// // Display in a picker
/// Picker("Account Type", selection: $selectedTypeCode) {
///     ForEach(types.sorted(by: { $0.sortOrder < $1.sortOrder })) { type in
///         Text(type.displayName).tag(type.code)
///     }
/// }
/// ```
///
/// - SeeAlso: ``CreateAccountRequest``, ``PatchAccountRequest``, ``AccountNode``
struct AccountTypeItem: Codable, Identifiable, Hashable {
    /// Unique identifier for this account type.
    let id: UUID
    
    /// Short alphanumeric code identifying this account type (e.g., "BANK", "EQUITY").
    let code: String
    
    /// Human-readable name of this account type (e.g., "Bank Account", "Opening Balances").
    let name: String
    
    /// Fundamental accounting category:
    /// - 1: Asset
    /// - 2: Liability
    /// - 3: Equity
    /// - 4: Income
    /// - 5: Expense
    let kind: Int
    
    /// Direction of normal balance:
    /// - 1: Debit (typical for Assets and Expenses)
    /// - 2: Credit (typical for Liabilities, Equity, and Income)
    let normalBalance: Int
    
    /// Suggested display order when presenting account types in lists or pickers.
    /// Lower values appear first.
    let sortOrder: Int

    /// Formatted display string combining name and code.
    ///
    /// Example: `"Bank Account (BANK)"`
    ///
    /// Use this in picker labels or account type displays for clarity.
    var displayName: String { "\(name) (\(code))" }
}

// MARK: - Create Request

/// Request body for creating a new account in a ledger.
///
/// `CreateAccountRequest` encapsulates all required and optional fields needed to create
/// a new account via `POST /accounts`. The backend validates that the parent account exists,
/// the account type code is valid (if provided), and that the combination of properties
/// adheres to the chart of accounts rules.
///
/// ## Required Fields
///
/// - **ledgerId**: The ledger this account belongs to
/// - **name**: Display name for the account (e.g., "Checking Account")
/// - **parentId**: UUID of the parent account (use root account ID for top-level accounts)
/// - **accountRole**: Fundamental category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
///
/// ## Optional Fields
///
/// - **code**: Short identifier for the account (e.g., "1000")
/// - **accountTypeCode**: Classification code from the account type catalog (e.g., "BANK")
/// - **isPlaceholder**: If `true`, the account is organizational only (no direct postings allowed)
/// - **isHidden**: If `true`, the account is hidden from most UI views
///
/// ## Usage Example
///
/// ```swift
/// let request = CreateAccountRequest(
///     ledgerId: currentLedger.id,
///     name: "Business Checking",
///     code: "1010",
///     parentId: assetsAccountId,
///     accountTypeCode: "BANK",
///     accountRole: 1,  // Asset
///     isPlaceholder: false,
///     isHidden: false
/// )
///
/// let newAccount: AccountResponse = try await APIClient.shared.request(
///     .createAccount,
///     method: "POST",
///     body: request,
///     token: authToken
/// )
/// ```
///
/// - Important: The `accountRole` must be compatible with the account's position in the
///   hierarchy. For example, an Income account cannot be a child of an Asset account.
/// - SeeAlso: ``PatchAccountRequest``, ``AccountNode``, ``AccountRole``
struct CreateAccountRequest: Encodable {
    /// The unique identifier of the ledger this account belongs to.
    let ledgerId: UUID
    
    /// Display name of the account (e.g., "Checking Account", "Sales Revenue").
    let name: String
    
    /// Optional short code for the account (e.g., "1000", "4010"). Often used for numbering schemes.
    let code: String?
    
    /// UUID of the parent account. Use the root account ID for top-level accounts.
    let parentId: UUID
    
    /// Optional account type code from the catalog (e.g., "BANK", "EQUITY", "INCOME").
    let accountTypeCode: String?
    
    /// The operational role of the account, encoded as the raw `Int16` value of ``AccountRole``.
    ///
    /// Use ``AccountRole`` to obtain the correct raw value (e.g., `AccountRole.bank.rawValue` = 101).
    /// Do **not** pass `kind` values (1–5) here — those belong to the `kind` field inherited
    /// from the parent account on the backend side.
    ///
    /// - SeeAlso: ``AccountRole``
    let accountRole: Int

    /// If `true`, this is a placeholder account used for organization only.
    /// Placeholder accounts cannot have transactions posted directly to them.
    let isPlaceholder: Bool

    /// If `true`, this account is hidden from most UI views (e.g., inactive accounts).
    let isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case ledgerId, name, code, parentId
        case accountTypeCode, accountRole
        case isPlaceholder, isHidden
    }
}

// MARK: - Patch Request

/// Request body for partially updating an existing account.
///
/// `PatchAccountRequest` allows modifying specific fields of an account via `PATCH /accounts/{id}`.
/// All fields are optional — only include the fields you want to change. The backend merges
/// non-nil values with the existing account data.
///
/// ## Patchable Fields
///
/// - **name**: Account display name
/// - **code**: Account code/number
/// - **parentId**: Move to a different parent account
/// - **accountTypeCode**: Change account type classification
/// - **accountRole**: Change fundamental category (use with caution)
/// - **isPlaceholder**: Toggle placeholder status
/// - **isHidden**: Toggle visibility
///
/// ## Usage Example
///
/// ```swift
/// // Rename an account and change its code
/// let patch = PatchAccountRequest(
///     name: "Business Checking - Main",
///     code: "1010"
/// )
///
/// let updated: AccountResponse = try await APIClient.shared.request(
///     .patchAccount(id: accountId),
///     method: "PATCH",
///     body: patch,
///     token: authToken
/// )
/// ```
///
/// ## Change Detection
///
/// Only populate fields that have actually changed. For example:
///
/// ```swift
/// var patch = PatchAccountRequest()
///
/// if newName != originalName {
///     patch.name = newName
/// }
///
/// if newParentId != originalParentId {
///     patch.parentId = newParentId
/// }
/// ```
///
/// - Important: Changing `accountRole` or `parentId` may violate chart of accounts rules.
///   The backend validates these changes before applying them.
/// - Note: Moving an account (changing `parentId`) preserves all child accounts — they move with it.
/// - SeeAlso: ``CreateAccountRequest``, ``AccountRole``
struct PatchAccountRequest: Encodable {
    /// Updated account name. If nil, the existing name is preserved.
    var name: String?
    
    /// Updated account code. If nil, the existing code is preserved.
    var code: String?
    
    /// Updated parent account UUID. If nil, the existing parent is preserved.
    /// Use to move the account to a different location in the hierarchy.
    var parentId: UUID?
    
    /// Updated account type code. If nil, the existing type code is preserved.
    var accountTypeCode: String?
    
    /// Updated operational role. If `nil`, the existing role is preserved.
    ///
    /// Pass the raw `Int` value of the desired ``AccountRole`` case
    /// (e.g., `AccountRole.bank.rawValue` = 101).
    ///
    /// - Warning: Changing this after transactions have been posted may break
    ///   chart-of-accounts consistency. The backend does not validate role changes
    ///   against existing transaction history.
    var accountRole: Int?
    
    /// Updated placeholder status. If nil, the existing status is preserved.
    var isPlaceholder: Bool?
    
    /// Updated visibility status. If nil, the existing status is preserved.
    var isHidden: Bool?

    enum CodingKeys: String, CodingKey {
        case name, code, parentId
        case accountTypeCode, accountRole
        case isPlaceholder, isHidden
    }
}

// MARK: - Window Payload

/// Value passed to the WindowGroup that opens an account creation or editing form.
///
/// `AccountFormWindowPayload` is used with SwiftUI's `.openWindow()` modifier to pass
/// context to a new account form window. It includes the ledger context and an optional
/// existing account for edit mode.
///
/// ## Usage
///
/// **Creating a new account:**
/// ```swift
/// Button("New Account") {
///     let payload = AccountFormWindowPayload(
///         ledger: currentLedger,
///         existingAccount: nil,  // Create mode
///         suggestedParentId: nil
///     )
///     openWindow(value: payload)
/// }
/// ```
///
/// **Creating a new account with a suggested parent:**
/// ```swift
/// Button("Add Subaccount") {
///     let payload = AccountFormWindowPayload(
///         ledger: currentLedger,
///         existingAccount: nil,
///         suggestedParentId: selectedAccount.id  // Pre-select parent
///     )
///     openWindow(value: payload)
/// }
/// ```
///
/// **Editing an existing account:**
/// ```swift
/// Button("Edit Account") {
///     let payload = AccountFormWindowPayload(
///         ledger: currentLedger,
///         existingAccount: AccountFormPayload(node: selectedAccount),
///         suggestedParentId: nil
///     )
///     openWindow(value: payload)
/// }
/// ```
///
/// ## Window Registration
///
/// Register the window in your app's `WindowGroup`:
/// ```swift
/// WindowGroup(for: AccountFormWindowPayload.self) { $payload in
///     if let payload = payload {
///         AccountFormWindowContent(payload: payload)
///     }
/// }
/// ```
///
/// - Note: Conforms to `Hashable` and `Codable` for SwiftUI window management.
/// - SeeAlso: ``AccountFormPayload``, ``AccountFormWindowContent``, ``AccountFormView``
struct AccountFormWindowPayload: Hashable, Codable {
    /// The ledger context for this account form.
    ///
    /// Provides currency information, decimal places, and the ledger ID needed
    /// for creating or updating accounts.
    let ledger: LedgerResponse
    
    /// The existing account to edit, or `nil` for create mode.
    ///
    /// - `nil`: Create a new account (form starts empty or with defaults)
    /// - Non-`nil`: Edit mode (form pre-populates with existing account data)
    let existingAccount: AccountFormPayload?
    
    /// Optional UUID of the parent account to pre-select in create mode.
    ///
    /// When creating a new account, this value pre-selects the parent account in the form's
    /// parent picker. Useful for "Add Subaccount" actions where the parent is already known.
    ///
    /// - `nil`: No parent pre-selected (user must choose or defaults to root)
    /// - Non-`nil`: Form pre-selects this account as the parent
    ///
    /// - Note: This field is only used in create mode. When editing (`existingAccount` is not `nil`),
    ///   the parent is determined by the existing account's `parentId`.
    let suggestedParentId: UUID?
    
    /// Optional name to pre-fill in the account name field when creating a new account.
    ///
    /// Enables "create on the spot" workflows from account pickers: the user types a name
    /// that doesn't exist yet, taps "New Account…", and the form opens with the name already
    /// filled in. Ignored in edit mode.
    var suggestedName: String?
}

/// Codable snapshot of an AccountNode for window passing.
///
/// `AccountFormPayload` is a serializable representation of an `AccountNode` that can be
/// passed between windows or stored in SwiftUI's window state. It contains all the data
/// needed to populate an account editing form.
///
/// ## Purpose
///
/// `AccountNode` is not `Codable` because it contains a tree structure with children.
/// This payload extracts only the essential fields for form editing, making it suitable
/// for window parameters and state persistence.
///
/// ## Usage
///
/// **Create from AccountNode:**
/// ```swift
/// let payload = AccountFormPayload(node: selectedAccount)
/// ```
///
/// **Use in form:**
/// ```swift
/// struct AccountFormView: View {
///     let payload: AccountFormWindowPayload
///     
///     var body: some View {
///         if let existing = payload.existingAccount {
///             // Pre-populate form with existing.name, existing.code, etc.
///         }
///     }
/// }
/// ```
///
/// - Note: `accountRole` and `kind` are distinct fields — `accountRole` encodes operational
///   intent via ``AccountRole``; `kind` encodes accounting nature (Asset, Liability, etc.).
/// - SeeAlso: ``AccountFormWindowPayload``, ``AccountNode``, ``AccountRole``
struct AccountFormPayload: Hashable, Codable {
    /// The unique identifier of the account being edited.
    let id: UUID
    
    /// The current name of the account.
    let name: String
    
    /// The current code of the account, if any.
    let code: String?
    
    /// The UUID of the parent account, or `nil` if this is a root account.
    let parentId: UUID?
    
    /// The account type code from the catalog (e.g., "BANK", "EQUITY").
    let accountTypeCode: String?
    
    /// The operational role of the account, as the raw `Int` value of ``AccountRole``.
    ///
    /// Populated from `AccountResponse.accountRole`. Use ``AccountRole/init(rawValue:)``
    /// to convert back to a typed enum value for display or validation logic.
    ///
    /// - SeeAlso: ``AccountRole``
    let accountRole: Int

    /// Whether this account is a placeholder (organizational only, no direct postings).
    let isPlaceholder: Bool

    /// Whether this account is hidden from most UI views.
    let isHidden: Bool

    /// The accounting nature of the account (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense).
    ///
    /// This is the `kind` dimension — distinct from `accountRole`, which encodes operational
    /// intent via ``AccountRole``. `kind` is inherited from the parent account on the backend
    /// and is included here for read-only display purposes.
    let kind: Int

    /// Initializes a payload from an existing ``AccountNode``.
    ///
    /// Extracts all relevant fields from the node's underlying ``AccountResponse``,
    /// including `accountRole` (operational role) and `kind` (accounting nature).
    ///
    /// - Parameter node: The account node to create a payload from.
    init(node: AccountNode) {
        self.id              = node.id
        self.name            = node.name
        self.code            = node.code
        self.parentId        = node.account.parentId
        self.accountTypeCode = node.accountTypeCode
        self.accountRole     = node.account.accountRole
        self.isPlaceholder   = node.isPlaceholder
        self.isHidden        = node.isHidden
        self.kind            = node.account.kind
    }
}
