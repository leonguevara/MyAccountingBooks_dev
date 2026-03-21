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
}

