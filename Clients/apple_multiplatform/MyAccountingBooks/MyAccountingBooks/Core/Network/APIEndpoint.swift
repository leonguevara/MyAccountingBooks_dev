//
//  Core/Network/APIEndpoint.swift
//  APIEndpoint.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-25.
//  Developed with AI assistance.
//

import Foundation

/**
 Describes backend API endpoints and constructs concrete URLs for requests.
 
 `APIEndpoint` centralizes the path logic for all backend routes, providing a single source
 of truth for building request URLs. All endpoints are built from a common `baseURL` which
 can be adjusted to point to different environments (development, staging, production).
 
 # Features
 - **Type-safe endpoints**: Each route is represented as an enum case
 - **Associated values**: Endpoints requiring IDs include them as parameters
 - **URL construction**: The `url` computed property builds the full URL
 - **Query parameters**: Endpoints like `commodities` support optional query strings
 - **Environment switching**: Change `baseURL` to point to different servers
 
 # Available Endpoints
 
 **Authentication:**
 - `login`: User authentication endpoint
 
 **Ledgers:**
 - `listLedgers`: List all accessible ledgers
 - `createLedger`: Create a new ledger
 
 **Accounts:**
 - `accounts(ledgerID:)`: Get chart of accounts for a ledger
 - `balances(ledgerID:)`: Get current balances for all accounts in a ledger
 - `createAccount`: Create a new account
 - `patchAccount(id:)`: Partially update an existing account
 - `accountTypes`: Get the catalog of account types
 
 **Transactions:**
 - `transactions(ledgerID:)`: List transactions for a ledger
 - `postTransaction`: Create a new transaction
 - `patchTransaction(id:)`: Partially update an existing transaction
 - `reverseTransaction(id:)`: Reverse a posted transaction
 - `voidTransaction(id:)`: Void a posted transaction
 
 **Commodities:**
 - `commodities(namespace:)`: List commodities, optionally filtered by namespace
 
 # Usage Examples
 
 **Building URLs:**
 ```swift
 // Authentication endpoint
 let loginURL = APIEndpoint.login.url
 // http://localhost:8080/auth/login
 
 // Ledger-specific endpoint
 let ledgerID = UUID()
 let accountsURL = APIEndpoint.accounts(ledgerID: ledgerID).url
 // http://localhost:8080/ledgers/{uuid}/accounts
 
 // Balance endpoint
 let balancesURL = APIEndpoint.balances(ledgerID: ledgerID).url
 // http://localhost:8080/ledgers/{uuid}/balances
 ```
 
 **Using with URLRequest:**
 ```swift
 var request = URLRequest(url: APIEndpoint.listLedgers.url)
 request.httpMethod = "GET"
 request.addValue("application/json", forHTTPHeaderField: "Accept")
 request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
 ```
 
 **Using with APIClient:**
 ```swift
 // APIClient automatically uses the endpoint's URL
 let ledgers: [LedgerResponse] = try await APIClient.shared.request(
     .listLedgers,
     method: "GET",
     token: authToken
 )
 ```
 
 **Response handling:**
 ```swift
 let endpoint = APIEndpoint.transactions(ledgerID: ledgerID)
 let (data, response) = try await URLSession.shared.data(
     for: URLRequest(url: endpoint.url)
 )
 
 if let http = response as? HTTPURLResponse {
     switch http.statusCode {
     case 200..<300:
         // Success - decode data
         let transactions = try JSONDecoder().decode([TransactionResponse].self, from: data)
     case 401:
         // Unauthorized - refresh credentials
         throw APIError.unauthorized
     case 404:
         // Not found - ledger or resource doesn't exist
         throw APIError.notFound
     default:
         // Other errors
         throw APIError.serverError(http.statusCode)
     }
 }
 ```
 
 # Environment Configuration
 
 Update `baseURL` for different environments:
 ```swift
 // Development
 static let baseURL = URL(string: "http://localhost:8080")!
 
 // Staging
 static let baseURL = URL(string: "https://staging-api.example.com")!
 
 // Production
 static let baseURL = URL(string: "https://api.example.com")!
 ```
 
 - Important: Always use HTTPS in production environments for secure communication.
 - Note: The `url` property is computed on each access; cache if using multiple times.
 - SeeAlso: `APIClient`, `APIError`
 */
enum APIEndpoint {
    /// The base URL for all API requests.
    ///
    /// Change this to point to your staging or production server as needed.
    /// Ensure HTTPS is used in production environments for secure communication.
    ///
    /// **Environments:**
    /// - Development: `http://localhost:8080`
    /// - Staging: `https://staging-api.example.com`
    /// - Production: `https://api.example.com`
    static let baseURL = URL(string: "http://localhost:8080")!

    // MARK: - Auth

    /// Authentication endpoint for user login.
    ///
    /// **Path:** `POST /auth/login`
    ///
    /// **Request body:** `{ "email": string, "password": string }`
    ///
    /// **Response:** `{ "token": string }`
    case login

    // MARK: - Ledgers

    /// Retrieves all ledgers accessible to the current user.
    ///
    /// **Path:** `GET /ledgers`
    ///
    /// **Response:** Array of ledger objects with metadata
    case listLedgers
    
    /// Creates a new ledger.
    ///
    /// **Path:** `POST /ledgers`
    ///
    /// **Request body:** Ledger creation data including name, currency, decimal places
    ///
    /// **Response:** The created ledger object
    case createLedger

    // MARK: - Accounts

    /// Retrieves the complete chart of accounts for a given ledger.
    ///
    /// **Path:** `GET /ledgers/{ledgerID}/accounts`
    ///
    /// Returns a flat list of all accounts which can be transformed into a hierarchy
    /// using `AccountTreeBuilder`.
    ///
    /// **Response:** Array of account objects with parent/child relationships
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    case accounts(ledgerID: UUID)
    
    /// Retrieves current balances for all accounts in a given ledger.
    ///
    /// **Path:** `GET /ledgers/{ledgerID}/balances`
    ///
    /// Returns balance information for each account as rational numbers (numerator/denominator)
    /// to maintain precision. Balances are signed according to the account's normal balance direction.
    ///
    /// **Response:** Array of balance objects with:
    /// - `accountId`: UUID linking to account
    /// - `balanceNum`: Rational number numerator (signed)
    /// - `balanceDenom`: Rational number denominator (scaling factor)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let balances: [AccountBalanceResponse] = try await APIClient.shared.request(
    ///     .balances(ledgerID: ledger.id),
    ///     token: authToken
    /// )
    /// ```
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    /// - SeeAlso: `AccountBalanceResponse`, `BalanceMap`, `AccountService.fetchBalances(ledgerID:token:)`
    case balances(ledgerID: UUID)
    
    /// Creates a new account in the chart of accounts.
    ///
    /// **Path:** `POST /accounts`
    ///
    /// Creates a new account with the specified properties. The backend validates that the
    /// parent account exists, the account type code is valid (if provided), and that the
    /// combination of properties adheres to the chart of accounts rules.
    ///
    /// **Request body:** Account creation data (e.g., `CreateAccountRequest`)
    /// - `ledgerId`: The ledger this account belongs to
    /// - `name`: Display name for the account
    /// - `code`: Optional account code/number
    /// - `parentId`: UUID of the parent account
    /// - `accountTypeCode`: Optional account type from the catalog
    /// - `accountRole`: Fundamental category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
    /// - `isPlaceholder`: Whether this is an organizational placeholder
    /// - `isHidden`: Whether this account is hidden from UI
    ///
    /// **Response:** The created account object
    ///
    /// **Usage Example:**
    /// ```swift
    /// let request = CreateAccountRequest(
    ///     ledgerId: ledger.id,
    ///     name: "Business Checking",
    ///     code: "1010",
    ///     parentId: assetsAccountId,
    ///     accountTypeCode: "BANK",
    ///     accountRole: 1,
    ///     isPlaceholder: false,
    ///     isHidden: false
    /// )
    /// let newAccount: AccountResponse = try await APIClient.shared.request(
    ///     .createAccount,
    ///     method: "POST",
    ///     body: request,
    ///     token: authToken
    /// )
    /// ```
    ///
    /// - SeeAlso: `CreateAccountRequest`, `PatchAccountRequest`, `accountTypes`
    case createAccount
    
    /// Partially updates an existing account.
    ///
    /// **Path:** `PATCH /accounts/{id}`
    ///
    /// Allows updating specific fields of an account without replacing the entire record.
    /// Only the fields included in the request body will be modified; all other fields
    /// remain unchanged. This is useful for renaming accounts, changing codes, moving
    /// accounts in the hierarchy, or updating account properties.
    ///
    /// **Request body:** Partial account data (e.g., `PatchAccountRequest`)
    /// - Only non-nil fields are updated
    /// - Supports updating name, code, parent, account type, role, placeholder status, and visibility
    ///
    /// **Response:** The updated account object with all fields
    ///
    /// **Usage Example:**
    /// ```swift
    /// let updates = PatchAccountRequest(
    ///     name: "Business Checking - Main",
    ///     code: "1010"
    /// )
    /// let updated: AccountResponse = try await APIClient.shared.request(
    ///     .patchAccount(id: accountId),
    ///     method: "PATCH",
    ///     body: updates,
    ///     token: authToken
    /// )
    /// ```
    ///
    /// - Parameter id: The unique identifier of the account to update.
    /// - Important: Changing `accountRole` or `parentId` may violate chart of accounts rules.
    ///   The backend validates these changes before applying them.
    /// - SeeAlso: `PatchAccountRequest`, `CreateAccountRequest`
    case patchAccount(id: UUID)
    
    /// Retrieves the catalog of available account types.
    ///
    /// **Path:** `GET /account-types`
    ///
    /// Returns the complete list of account type classifications available in the system.
    /// Each account type has a code (e.g., "BANK", "EQUITY"), a name, a fundamental category
    /// (kind), a normal balance direction, and a suggested sort order for display.
    ///
    /// **Response:** Array of account type objects with:
    /// - `id`: Unique identifier
    /// - `code`: Short alphanumeric code (e.g., "BANK")
    /// - `name`: Human-readable name (e.g., "Bank Account")
    /// - `kind`: Fundamental category (1=Asset, 2=Liability, 3=Equity, 4=Income, 5=Expense)
    /// - `normalBalance`: Direction of normal balance (1=Debit, 2=Credit)
    /// - `sortOrder`: Suggested ordering for display
    ///
    /// **Usage Example:**
    /// ```swift
    /// let types: [AccountTypeItem] = try await APIClient.shared.request(
    ///     .accountTypes,
    ///     method: "GET",
    ///     token: authToken
    /// )
    ///
    /// // Use in a picker
    /// Picker("Account Type", selection: $selectedTypeCode) {
    ///     ForEach(types.sorted(by: { $0.sortOrder < $1.sortOrder })) { type in
    ///         Text(type.displayName).tag(type.code)
    ///     }
    /// }
    /// ```
    ///
    /// - SeeAlso: `AccountTypeItem`, `CreateAccountRequest`, `PatchAccountRequest`
    case accountTypes

    // MARK: - Transactions

    /// Retrieves all transactions for a given ledger.
    ///
    /// **Path:** `GET /ledgers/{ledgerID}/transactions`
    ///
    /// Returns complete transaction records including all split lines, dates, and metadata.
    ///
    /// **Response:** Array of transaction objects with splits
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    case transactions(ledgerID: UUID)
    
    /// Creates a new transaction.
    ///
    /// **Path:** `POST /transactions`
    ///
    /// **Request body:** Transaction data including date, memo, and balanced split lines
    ///
    /// **Response:** The created transaction object
    case postTransaction
    
    /// Reverses a previously posted transaction.
    ///
    /// **Path:** `POST /transactions/{id}/reverse`
    ///
    /// Creates a new transaction with opposite amounts to undo the original transaction.
    ///
    /// **Response:** The reversing transaction object
    ///
    /// - Parameter id: The unique identifier of the transaction to reverse.
    case reverseTransaction(id: UUID)
    
    /// Voids a previously posted transaction.
    ///
    /// **Path:** `POST /transactions/{id}/void`
    ///
    /// Marks the transaction as voided without creating a reversing entry.
    ///
    /// **Response:** The voided transaction object
    ///
    /// - Parameter id: The unique identifier of the transaction to void.
    case voidTransaction(id: UUID)
    
    /// Partially updates an existing transaction.
    ///
    /// **Path:** `PATCH /transactions/{id}`
    ///
    /// Allows updating specific fields of a transaction without replacing the entire record.
    /// Only the fields included in the request body will be modified; all other fields remain unchanged.
    /// This is useful for editing transaction details like memo, number, date, or individual split lines.
    ///
    /// **Request body:** Partial transaction data (e.g., `PatchTransactionRequest`)
    /// - Only non-nil fields are updated
    /// - Supports updating transaction-level fields (memo, num, postDate)
    /// - Supports updating individual splits by splitId
    ///
    /// **Response:** The updated transaction object with all fields
    ///
    /// **Usage Example:**
    /// ```swift
    /// let updates = PatchTransactionRequest(
    ///     memo: "Updated description",
    ///     splits: [PatchSplitRequest(splitId: splitID, accountId: newAccountID)]
    /// )
    /// let updated: TransactionResponse = try await APIClient.shared.request(
    ///     .patchTransaction(id: transactionID),
    ///     method: "PATCH",
    ///     body: updates,
    ///     token: authToken
    /// )
    /// ```
    ///
    /// - Parameter id: The unique identifier of the transaction to update.
    /// - SeeAlso: `PatchTransactionRequest`, `PatchSplitRequest`
    case patchTransaction(id: UUID)

    // MARK: - Commodities

    /// Retrieves commodities, optionally filtering by a namespace.
    ///
    /// **Path:** `GET /commodities` or `GET /commodities?namespace={namespace}`
    ///
    /// Commodities represent currencies, stocks, or other assets tracked in the system.
    ///
    /// **Response:** Array of commodity objects with codes and namespaces
    ///
    /// - Parameter namespace: A string to filter commodities by namespace (e.g., "CURRENCY", "ISO4217").
    ///                        Pass `nil` to retrieve all commodities.
    case commodities(namespace: String?)

    // MARK: - URL Construction
    
    /// The fully-qualified URL for the endpoint, derived from `baseURL` and path components.
    ///
    /// This computed property constructs the complete URL for the endpoint by appending
    /// the appropriate path to `baseURL` and including any query parameters.
    ///
    /// **Examples:**
    /// - `.login` → `http://localhost:8080/auth/login`
    /// - `.accounts(ledgerID: id)` → `http://localhost:8080/ledgers/{id}/accounts`
    /// - `.balances(ledgerID: id)` → `http://localhost:8080/ledgers/{id}/balances`
    /// - `.commodities(namespace: "CURRENCY")` → `http://localhost:8080/commodities?namespace=CURRENCY`
    ///
    /// - Important: This property is computed on every access. Cache the value if using multiple times.
    var url: URL {
        switch self {
        case .login:
            return Self.baseURL.appendingPathComponent("auth/login")
        case .listLedgers, .createLedger:
            return Self.baseURL.appendingPathComponent("ledgers")
        case .accounts(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/accounts")
        case .balances(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/balances")
        case .transactions(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/transactions")
        case .postTransaction:
            return Self.baseURL.appendingPathComponent("transactions")
        case .reverseTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/reverse")
        case .voidTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/void")
        case .patchTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)")
        case .commodities(let ns):
            var components = URLComponents(url: Self.baseURL.appendingPathComponent("commodities"), resolvingAgainstBaseURL: false)!
            if let ns { components.queryItems = [URLQueryItem(name: "namespace", value: ns)] }
            return components.url!
        case .createAccount:
            return Self.baseURL.appendingPathComponent("accounts")
        case .patchAccount(let id):
            return Self.baseURL.appendingPathComponent("accounts/\(id)")
        case .accountTypes:
            return Self.baseURL.appendingPathComponent("account-types")
        }
    }
}
