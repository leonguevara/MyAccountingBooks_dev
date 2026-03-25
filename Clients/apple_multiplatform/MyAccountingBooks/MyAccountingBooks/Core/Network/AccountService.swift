//
//  Core/Network/AccountService.swift
//  AccountService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

/**
 A service encapsulating network operations for account and balance management.
 
 `AccountService` provides methods to fetch account data and balances from the backend API.
 It serves as the networking layer for the chart of accounts functionality, retrieving both
 account metadata (structure, types, codes) and current balance information.
 
 # Features
 - **Fetch Accounts**: Retrieves the flat list of accounts for a ledger
 - **Fetch Balances**: Retrieves current balances for all accounts in a ledger
 - **Fetch Account Types**: Retrieves the catalog of available account types
 - **Create Accounts**: Creates new accounts in the chart of accounts
 - **Update Accounts**: Partially updates existing account properties
 - **Singleton Pattern**: Shared instance for consistent access across the app
 - **Balance Map**: Returns balances as a dictionary for O(1) lookup efficiency
 
 # Account Hierarchy
 
 The service returns accounts as a flat list from the API. To build a tree structure:
 1. Fetch accounts using `fetchAccounts(ledgerID:token:)`
 2. Use `AccountTreeBuilder.build(from:)` to construct the hierarchy
 3. Display in SwiftUI using `OutlineGroup` or `List(children:)`
 
 # Balance Integration
 
 For displaying accounts with balances:
 1. Fetch accounts and balances concurrently
 2. Use the `BalanceMap` dictionary for efficient lookups
 3. Attach balances when building `AccountNode` structures
 
 # Usage Example
 
 **Fetching accounts and building tree:**
 ```swift
 let accounts = try await AccountService.shared.fetchAccounts(
     ledgerID: ledger.id,
     token: authToken
 )
 let tree = AccountTreeBuilder.build(from: accounts)
 
 // Display in SwiftUI
 OutlineGroup(tree, children: \.children) { node in
     Text(node.name)
 }
 ```
 
 **Fetching accounts with balances:**
 ```swift
 // Fetch concurrently
 async let accountsTask = AccountService.shared.fetchAccounts(
     ledgerID: ledger.id,
     token: authToken
 )
 async let balancesTask = AccountService.shared.fetchBalances(
     ledgerID: ledger.id,
     token: authToken
 )
 
 let (accounts, balanceMap) = try await (accountsTask, balancesTask)
 
 // Build tree with balances
 let nodes = accounts.map { account in
     let balance = balanceMap[account.id]?.balance ?? .zero
     return AccountNode(account: account, balance: balance, children: [])
 }
 let tree = AccountTreeBuilder.build(from: accounts, balances: balanceMap)
 ```
 
 - Important: Always use a valid authentication token from `AuthService` or `TokenStore`.
 - Note: This service uses the singleton pattern accessed via `AccountService.shared`.
 - SeeAlso: `AccountTreeBuilder`, `AccountResponse`, `AccountBalanceResponse`, `BalanceMap`
 */
final class AccountService {

    // MARK: - Properties
    
    /// Shared singleton instance for convenient access across the app.
    ///
    /// Use this instance for all account and balance fetching operations to ensure
    /// consistent behavior and avoid creating multiple service instances.
    static let shared = AccountService()
    
    /// Private initializer to enforce singleton usage pattern.
    private init() {}

    // MARK: - Fetch Chart of Accounts

    /**
     Fetches the complete flat list of accounts for a specific ledger.
     
     This method retrieves all accounts in the ledger's chart of accounts from the backend.
     The accounts are returned as a flat array without hierarchy information, which can then
     be transformed into a tree structure using `AccountTreeBuilder`.
     
     - Parameters:
       - ledgerID: The unique identifier of the ledger whose accounts to fetch.
       - token: A bearer authentication token for authorizing the request.
     
     - Returns: An array of `AccountResponse` models containing account metadata including
                name, code, type, parent relationships, and placeholder status.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid or missing authentication (401)
         - `.notFound`: Ledger does not exist (404)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Usage Example
     
     **Basic fetch:**
     ```swift
     guard let token = auth.token else { return }
     
     do {
         let accounts = try await AccountService.shared.fetchAccounts(
             ledgerID: selectedLedger.id,
             token: token
         )
         print("Loaded \(accounts.count) accounts")
     } catch {
         print("Failed to load accounts: \(error)")
     }
     ```
     
     **Building account tree:**
     ```swift
     let accounts = try await AccountService.shared.fetchAccounts(
         ledgerID: ledger.id,
         token: token
     )
     
     // Transform flat list to hierarchy
     let accountTree = AccountTreeBuilder.build(from: accounts)
     
     // Display in SwiftUI
     List(accountTree, children: \.children) { node in
         HStack {
             Text(node.name)
             Spacer()
             if let code = node.code {
                 Text(code).foregroundStyle(.secondary)
             }
         }
     }
     ```
     
     # Account Structure
     
     Each account includes:
     - Unique ID and name
     - Optional account code
     - Account type and kind
     - Parent account ID for hierarchy
     - Placeholder flag (true = no transactions allowed)
     - Currency commodity ID
     
     # Performance
     
     - Returns all accounts in a single request
     - O(n) response size where n is the number of accounts
     - Tree building is performed locally after fetch
     
     - Important: Tree structure must be built client-side using `AccountTreeBuilder`.
     - Note: Placeholder accounts cannot have transactions posted directly to them.
     - SeeAlso: `AccountTreeBuilder.build(from:)`, `AccountResponse`, `AccountNode`
     */
    func fetchAccounts(ledgerID: UUID, token: String) async throws -> [AccountResponse] {
        try await APIClient.shared.request(
            .accounts(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
    }
    
    // MARK: - Fetch Account Balances

    /**
     Fetches current balances for all accounts in a ledger, returned as an efficient lookup map.
     
     This method retrieves the current balance for every account in the specified ledger
     and returns them as a `BalanceMap` dictionary for O(1) lookup performance. Balances
     are returned as rational numbers (numerator/denominator) for precision and are signed
     according to the account's normal balance direction.
     
     - Parameters:
       - ledgerID: The unique identifier of the ledger whose balances to fetch.
       - token: A bearer authentication token for authorizing the request.
     
     - Returns: A `BalanceMap` dictionary mapping account UUIDs to their `AccountBalanceResponse`,
                enabling constant-time balance lookups by account ID.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid or missing authentication (401)
         - `.notFound`: Ledger does not exist (404)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Return Value
     
     The `BalanceMap` is a dictionary where:
     - **Key**: Account UUID
     - **Value**: `AccountBalanceResponse` containing:
       - `accountId`: The account's unique identifier
       - `balanceNum`: Rational number numerator (signed integer)
       - `balanceDenom`: Rational number denominator (scaling factor)
       - `balance`: Computed `Decimal` property for display
     
     # Balance Format
     
     Balances use rational numbers for precision:
     - **$12.50** with 2 decimal places: `balanceNum = 1250`, `balanceDenom = 100`
     - **$-5.00** (negative): `balanceNum = -500`, `balanceDenom = 100`
     - **$0.00**: `balanceNum = 0`, `balanceDenom = 100`
     
     # Usage Examples
     
     **Basic balance fetch:**
     ```swift
     guard let token = auth.token else { return }
     
     let balanceMap = try await AccountService.shared.fetchBalances(
         ledgerID: ledger.id,
         token: token
     )
     
     // Look up specific account balance
     if let balanceResponse = balanceMap[accountID] {
         let balance = balanceResponse.balance
         print("Account balance: \(balance)")
     }
     ```
     
     **Concurrent fetch with accounts:**
     ```swift
     // Fetch both concurrently for better performance
     async let accountsTask = AccountService.shared.fetchAccounts(
         ledgerID: ledger.id,
         token: token
     )
     async let balancesTask = AccountService.shared.fetchBalances(
         ledgerID: ledger.id,
         token: token
     )
     
     let (accounts, balanceMap) = try await (accountsTask, balancesTask)
     
     // Build account nodes with balances
     let nodesWithBalances = accounts.map { account in
         let balance = balanceMap[account.id]?.balance ?? .zero
         return AccountNode(account: account, balance: balance)
     }
     ```
     
     **Displaying balances in UI:**
     ```swift
     let balanceMap = try await AccountService.shared.fetchBalances(
         ledgerID: ledger.id,
         token: token
     )
     
     ForEach(accounts) { account in
         HStack {
             Text(account.name)
             Spacer()
             if let balanceResponse = balanceMap[account.id] {
                 Text(AmountFormatter.format(
                     balanceResponse.balance,
                     currencyCode: ledger.currencyCode,
                     decimalPlaces: ledger.decimalPlaces
                 ))
                 .monospacedDigit()
                 .foregroundStyle(balanceResponse.balance >= 0 ? .primary : .red)
             }
         }
     }
     ```
     
     # Performance
     
     - **API Request**: O(n) where n is the number of accounts
     - **Map Construction**: O(n) to build the dictionary
     - **Balance Lookup**: O(1) average case for each lookup
     - **Memory**: O(n) to store all balances
     
     This is much more efficient than fetching balances individually (O(n) requests)
     or searching an array for each account (O(n²) overall complexity).
     
     # Missing Balances
     
     If an account has no balance entry in the map:
     - The account has a zero balance
     - Treat as `Decimal.zero` in calculations
     - Use nil coalescing: `balanceMap[id]?.balance ?? .zero`
     
     - Important: Use the `balance` computed property for display to get `Decimal` values.
     - Note: Balances are signed - negative values indicate opposite of normal balance direction.
     - SeeAlso: `BalanceMap`, `AccountBalanceResponse`, `AmountFormatter`
     */
    func fetchBalances(ledgerID: UUID, token: String) async throws -> BalanceMap {
        let list: [AccountBalanceResponse] = try await APIClient.shared.request(
            .balances(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
        return Dictionary(uniqueKeysWithValues: list.map { ($0.accountId, $0) })
    }
    
    // MARK: - Account Types
    
    /**
     Fetches the catalog of available account types from the backend.
     
     This method retrieves the complete list of account type classifications that can be
     assigned to accounts. Each account type has a unique code (e.g., "BANK", "EQUITY"),
     a human-readable name, a fundamental category (kind), and a normal balance direction.
     Account types are typically used in account creation and editing forms to classify
     accounts according to standard accounting conventions.
     
     - Parameters:
       - token: A bearer authentication token for authorizing the request.
     
     - Returns: An array of `AccountTypeItem` models, each containing:
       - `id`: Unique identifier for the account type
       - `code`: Short alphanumeric code (e.g., "BANK", "EQUITY", "INCOME")
       - `name`: Human-readable display name (e.g., "Bank Account", "Opening Balances")
       - `kind`: Fundamental category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
       - `normalBalance`: Direction of normal balance (1=Debit, 2=Credit)
       - `sortOrder`: Suggested ordering for display in UI
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid or missing authentication (401)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Usage Examples
     
     **Basic fetch:**
     ```swift
     guard let token = auth.token else { return }
     
     let types = try await AccountService.shared.fetchAccountTypes(token: token)
     print("Loaded \(types.count) account types")
     ```
     
     **Display in picker (sorted):**
     ```swift
     let types = try await AccountService.shared.fetchAccountTypes(token: token)
     
     Picker("Account Type", selection: $selectedTypeCode) {
         Text("None").tag(nil as String?)
         ForEach(types.sorted(by: { $0.sortOrder < $1.sortOrder })) { type in
             Text(type.displayName).tag(type.code as String?)
         }
     }
     ```
     
     **Filter by kind:**
     ```swift
     let types = try await AccountService.shared.fetchAccountTypes(token: token)
     
     // Get only asset account types (kind = 1)
     let assetTypes = types.filter { $0.kind == 1 }
     ```
     
     # Account Type Categories
     
     The `kind` field indicates the fundamental accounting category:
     - **1 (Asset)**: Resources owned (Cash, Accounts Receivable, Equipment)
     - **2 (Liability)**: Obligations owed (Loans, Accounts Payable)
     - **3 (Equity)**: Owner's residual interest (Capital, Retained Earnings)
     - **4 (Income)**: Revenue earned (Sales, Interest Income)
     - **5 (Expense)**: Costs incurred (Rent, Salaries, Utilities)
     
     # Normal Balance
     
     The `normalBalance` field indicates the typical balance direction:
     - **1 (Debit)**: Increases with debits (Assets, Expenses)
     - **2 (Credit)**: Increases with credits (Liabilities, Equity, Income)
     
     # Display Formatting
     
     Use the `displayName` computed property for formatted display:
     ```swift
     type.displayName  // "Bank Account (BANK)"
     ```
     
     - Important: Account types are defined by the backend and cannot be created or modified
       by the client application.
     - Note: The `sortOrder` field provides a suggested display order for UI consistency.
     - SeeAlso: `AccountTypeItem`, `CreateAccountRequest`, `PatchAccountRequest`
     */
    func fetchAccountTypes(token: String) async throws -> [AccountTypeItem] {
        try await APIClient.shared.request(
            .accountTypes,
            method: "GET",
            token: token
        )
    }

    // MARK: - Create Account
    
    /**
     Creates a new account in the chart of accounts for a ledger.
     
     This method sends a creation request to the backend to add a new account to the specified
     ledger's chart of accounts. The backend validates that the parent account exists, the account
     type code is valid (if provided), and that the combination of properties adheres to the
     chart of accounts rules before creating the account.
     
     - Parameters:
       - request: A `CreateAccountRequest` containing all required and optional account properties:
         - `ledgerId`: The ledger this account belongs to
         - `name`: Display name for the account
         - `code`: Optional account code/number
         - `parentId`: UUID of the parent account
         - `accountTypeCode`: Optional account type from the catalog
         - `accountRole`: Fundamental category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
         - `isPlaceholder`: Whether this is an organizational placeholder
         - `isHidden`: Whether this account is hidden from UI
       - token: A bearer authentication token for authorizing the request.
     
     - Returns: An `AccountResponse` representing the newly created account with all properties
                populated by the backend, including the generated UUID.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid or missing authentication (401)
         - `.badRequest`: Invalid account data or validation failure (400)
         - `.notFound`: Parent account or ledger does not exist (404)
         - `.conflict`: Account with the same name/code already exists (409)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Usage Examples
     
     **Create a basic account:**
     ```swift
     guard let token = auth.token else { return }
     
     let request = CreateAccountRequest(
         ledgerId: currentLedger.id,
         name: "Business Checking",
         code: "1010",
         parentId: assetsRootId,
         accountTypeCode: "BANK",
         accountRole: 1,  // Asset
         isPlaceholder: false,
         isHidden: false
     )
     
     do {
         let newAccount = try await AccountService.shared.createAccount(
             request,
             token: token
         )
         print("Created account: \(newAccount.name) with ID: \(newAccount.id)")
     } catch {
         print("Failed to create account: \(error)")
     }
     ```
     
     **Create a placeholder account (organizational only):**
     ```swift
     let request = CreateAccountRequest(
         ledgerId: ledger.id,
         name: "Current Assets",
         code: nil,
         parentId: assetsRootId,
         accountTypeCode: nil,
         accountRole: 1,  // Asset
         isPlaceholder: true,  // No transactions allowed
         isHidden: false
     )
     
     let placeholder = try await AccountService.shared.createAccount(
         request,
         token: token
     )
     ```
     
     **Create with error handling:**
     ```swift
     do {
         let account = try await AccountService.shared.createAccount(
             request,
             token: token
         )
         // Success - refresh account list
         await refreshAccounts()
     } catch APIError.badRequest(let message) {
         errorMessage = "Invalid account data: \(message)"
     } catch APIError.conflict(let message) {
         errorMessage = "Account already exists: \(message)"
     } catch {
         errorMessage = "Failed to create account: \(error.localizedDescription)"
     }
     ```
     
     # Validation Rules
     
     The backend enforces several validation rules:
     - **Name**: Must not be empty
     - **Parent**: Must exist and belong to the same ledger
     - **Account Role**: Must be compatible with parent's role
     - **Account Type**: If provided, must exist in the catalog
     - **Code**: If provided, should be unique within the ledger (warning, not error)
     
     # Placeholder Accounts
     
     Accounts with `isPlaceholder = true`:
     - Cannot have transactions posted directly to them
     - Are used for organizational structure in the chart of accounts
     - Can have child accounts (which may accept transactions)
     - Often represent category headers (e.g., "Current Assets", "Operating Expenses")
     
     # Response
     
     The returned `AccountResponse` includes:
     - The generated UUID for the new account
     - All properties from the request
     - Server-assigned timestamps (if applicable)
     - Computed properties based on the account's position in the hierarchy
     
     - Important: The `accountRole` must be compatible with the account's position in the
       hierarchy. For example, an Income account cannot be a child of an Asset account.
     - Note: Accounts are created immediately and appear in subsequent `fetchAccounts` calls.
     - SeeAlso: `CreateAccountRequest`, `patchAccount`, `fetchAccountTypes`, `AccountResponse`
     */
    func createAccount(_ request: CreateAccountRequest,
                       token: String) async throws -> AccountResponse {
        try await APIClient.shared.request(
            .createAccount,
            method: "POST",
            body: request,
            token: token
        )
    }

    // MARK: - Update Account
    
    /**
     Partially updates an existing account's properties.
     
     This method sends a PATCH request to modify specific fields of an existing account without
     replacing the entire record. Only the fields included in the request (non-nil values) will
     be modified; all other fields remain unchanged. The backend validates changes to ensure
     they maintain chart of accounts consistency.
     
     - Parameters:
       - id: The unique identifier of the account to update.
       - request: A `PatchAccountRequest` containing the fields to modify. All fields are optional:
         - `name`: Updated account name
         - `code`: Updated account code/number
         - `parentId`: Move to a different parent account
         - `accountTypeCode`: Change account type classification
         - `accountRole`: Change fundamental category (use with caution)
         - `isPlaceholder`: Toggle placeholder status
         - `isHidden`: Toggle visibility
       - token: A bearer authentication token for authorizing the request.
     
     - Returns: An `AccountResponse` representing the updated account with all current properties.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid or missing authentication (401)
         - `.badRequest`: Invalid update data or validation failure (400)
         - `.notFound`: Account does not exist (404)
         - `.conflict`: Update would violate uniqueness constraints (409)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Usage Examples
     
     **Rename an account:**
     ```swift
     guard let token = auth.token else { return }
     
     var patch = PatchAccountRequest()
     patch.name = "Business Checking - Main"
     
     do {
         let updated = try await AccountService.shared.patchAccount(
             id: accountId,
             patch,
             token: token
         )
         print("Renamed to: \(updated.name)")
     } catch {
         print("Failed to rename: \(error)")
     }
     ```
     
     **Update multiple fields:**
     ```swift
     var patch = PatchAccountRequest()
     patch.name = "Petty Cash"
     patch.code = "1020"
     patch.accountTypeCode = "CASH"
     
     let updated = try await AccountService.shared.patchAccount(
         id: accountId,
         patch,
         token: token
     )
     ```
     
     **Move an account to a new parent:**
     ```swift
     var patch = PatchAccountRequest()
     patch.parentId = newParentAccountId
     
     let moved = try await AccountService.shared.patchAccount(
         id: accountId,
         patch,
         token: token
     )
     // All child accounts move with it
     ```
     
     **Change placeholder status:**
     ```swift
     var patch = PatchAccountRequest()
     patch.isPlaceholder = false  // Allow transactions
     
     let updated = try await AccountService.shared.patchAccount(
         id: accountId,
         patch,
         token: token
     )
     ```
     
     **Efficient change detection:**
     ```swift
     var patch = PatchAccountRequest()
     
     // Only include fields that actually changed
     if newName != originalAccount.name {
         patch.name = newName
     }
     
     if newCode != originalAccount.code {
         patch.code = newCode
     }
     
     // Don't send request if nothing changed
     guard patch.name != nil || patch.code != nil else {
         return originalAccount
     }
     
     return try await AccountService.shared.patchAccount(
         id: accountId,
         patch,
         token: token
     )
     ```
     
     # Validation Rules
     
     The backend validates PATCH requests to ensure:
     - **Name**: If provided, must not be empty
     - **Parent**: If changed, new parent must exist and be compatible
     - **Account Role**: If changed, must maintain hierarchy consistency
     - **Placeholder**: Cannot be changed to false if account has children
     - **Code**: If provided, should be unique (warning, not error)
     
     # Moving Accounts
     
     When updating `parentId`:
     - The account moves to the new parent in the hierarchy
     - All child accounts move with it (subtree is preserved)
     - The new parent must be compatible with the account's role
     - Cannot create circular references (account cannot be its own ancestor)
     
     # Performance
     
     - Only changed fields are included in the request payload
     - Backend only validates and updates modified fields
     - Use change detection to avoid unnecessary requests
     
     # Response
     
     The returned `AccountResponse` includes:
     - All current properties after the update
     - The same UUID (account identity is preserved)
     - Updated server timestamps (if applicable)
     
     - Important: Changing `accountRole` or `parentId` may violate chart of accounts rules.
       The backend validates these changes before applying them.
     - Warning: Moving placeholder accounts with many children can be slow. Consider this
       when designing the account hierarchy.
     - Note: Changes take effect immediately and appear in subsequent `fetchAccounts` calls.
     - SeeAlso: `PatchAccountRequest`, `createAccount`, `AccountResponse`
     */
    func patchAccount(id: UUID,
                      _ request: PatchAccountRequest,
                      token: String) async throws -> AccountResponse {
        try await APIClient.shared.request(
            .patchAccount(id: id),
            method: "PATCH",
            body: request,
            token: token
        )
    }
}

