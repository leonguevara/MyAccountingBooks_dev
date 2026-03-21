//
//  Core/Models/AccountBalance.swift
//  AccountBalance.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

// MARK: - API Response

/**
 Represents the current balance of an account as returned by the backend API.
 
 Account balances are stored and transmitted as rational numbers (numerator/denominator pairs)
 to maintain precision and avoid floating-point rounding errors. This structure provides
 convenient conversion to `Decimal` for display and calculation purposes.
 
 # Rational Number Format
 
 The backend stores monetary amounts as fractions:
 - **Numerator** (`balanceNum`): The scaled integer value
 - **Denominator** (`balanceDenom`): The scaling factor (e.g., 100 for 2 decimal places)
 
 For example, $12.50 with 2 decimal places is stored as:
 - `balanceNum`: 1250
 - `balanceDenom`: 100
 - Actual value: 1250 / 100 = 12.50
 
 # Sign Convention
 
 The sign of `balanceNum` indicates the account's natural balance:
 - **Positive**: Balance in the account's normal direction (e.g., debit accounts with debit balances)
 - **Negative**: Balance opposite to the account's normal direction (e.g., asset account with credit balance)
 - **Zero**: Account has no balance
 
 # Usage Example
 
 ```swift
 // Received from API
 let response = AccountBalanceResponse(
     accountId: cashAccountID,
     balanceNum: 125000,
     balanceDenom: 100
 )
 
 // Convert to Decimal for display
 let displayBalance = response.balance // 1250.00
 
 // Format for UI
 let formatted = AmountFormatter.format(
     response.balance,
     currencyCode: "USD",
     decimalPlaces: 2
 )
 // Result: "$1,250.00"
 ```
 
 # API Response Format
 
 This structure matches the JSON response from the backend:
 ```json
 {
     "accountId": "550e8400-e29b-41d4-a716-446655440000",
     "balanceNum": 125000,
     "balanceDenom": 100
 }
 ```
 
 - Important: Always use the `balance` computed property for display to avoid precision issues.
 - Note: The denominator should never be zero, but the computed property guards against division by zero.
 - SeeAlso: `BalanceMap`, `AmountFormatter`, `AccountResponse`
 */
struct AccountBalanceResponse: Codable {
    /// The unique identifier of the account this balance belongs to.
    ///
    /// Used to match balances with accounts when building the account tree or
    /// displaying balances in the UI.
    let accountId: UUID
    
    /// The numerator of the rational number representing the balance.
    ///
    /// This is the scaled integer value. For example, $12.50 with 2 decimal places
    /// would have a numerator of 1250.
    ///
    /// The sign indicates whether the balance is in the normal direction (positive)
    /// or opposite direction (negative) for the account type.
    let balanceNum: Int
    
    /// The denominator of the rational number representing the balance.
    ///
    /// This is the scaling factor based on decimal places. Common values:
    /// - 1: 0 decimal places (whole numbers)
    /// - 10: 1 decimal place
    /// - 100: 2 decimal places (standard for most currencies)
    /// - 1000: 3 decimal places
    ///
    /// Should match the ledger's `decimalPlaces` setting.
    let balanceDenom: Int

    /// The account balance as a `Decimal` value for display and calculations.
    ///
    /// Converts the rational number (numerator/denominator) to a `Decimal` for use in:
    /// - UI display with proper formatting
    /// - Financial calculations requiring precision
    /// - Comparisons and balance checks
    ///
    /// - Returns: The balance as a `Decimal`, or `.zero` if denominator is zero (safeguard).
    ///
    /// # Example
    /// ```swift
    /// let response = AccountBalanceResponse(
    ///     accountId: id,
    ///     balanceNum: 1250,
    ///     balanceDenom: 100
    /// )
    /// print(response.balance) // 12.50
    /// ```
    ///
    /// - Important: This computed property is evaluated on every access. Cache the value if using multiple times.
    /// - Note: Division by zero returns `.zero` as a safety measure, though the API should never send zero denominators.
    var balance: Decimal {
        guard balanceDenom != 0 else { return .zero }
        return Decimal(balanceNum) / Decimal(balanceDenom)
    }
}

// MARK: - Balance Map

/**
 A type alias for efficient lookup of account balances by account ID.
 
 `BalanceMap` is a dictionary that maps account UUIDs to their corresponding balance responses,
 enabling O(1) lookup when displaying balances in account trees or lists.
 
 # Purpose
 
 When building account hierarchies or displaying account lists, you often need to:
 1. Fetch all accounts
 2. Fetch all balances
 3. Match each account with its balance
 
 This dictionary structure makes step 3 efficient, avoiding nested loops and providing
 constant-time lookups.
 
 # Usage Example
 
 ```swift
 // Fetch balances from API
 let balanceResponses: [AccountBalanceResponse] = try await fetchBalances(token: token)
 
 // Convert to map for efficient lookup
 let balanceMap: BalanceMap = Dictionary(
     uniqueKeysWithValues: balanceResponses.map { ($0.accountId, $0) }
 )
 
 // Build account tree with balances
 let accountNodes = accounts.map { account in
     let balance = balanceMap[account.id]?.balance ?? .zero
     return AccountNode(account: account, balance: balance)
 }
 ```
 
 # Building the Map
 
 From an array of balance responses:
 ```swift
 let responses: [AccountBalanceResponse] = [...]
 let map: BalanceMap = Dictionary(uniqueKeysWithValues: responses.map { 
     ($0.accountId, $0) 
 })
 ```
 
 Or using reduce:
 ```swift
 let map: BalanceMap = responses.reduce(into: [:]) { dict, response in
     dict[response.accountId] = response
 }
 ```
 
 # Performance
 
 - **Lookup**: O(1) average case
 - **Insertion**: O(1) average case
 - **Memory**: O(n) where n is the number of accounts
 
 This is significantly faster than filtering an array for each account (O(n²) overall).
 
 - Important: Assumes account IDs are unique. If duplicates exist, the last one wins.
 - Note: Accounts without balance entries will not be present in the map; treat as zero balance.
 - SeeAlso: `AccountBalanceResponse`, `AccountNode`, `AccountTreeBuilder`
 */
typealias BalanceMap = [UUID: AccountBalanceResponse]
