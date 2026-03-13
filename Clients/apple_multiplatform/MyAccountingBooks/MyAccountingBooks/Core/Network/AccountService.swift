//
//  Core/Network/AccountService.swift
//  AccountService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Developed with AI assistance.
//

import Foundation

/// A service that encapsulates network operations related to accounts.
///
/// Uses `APIClient` to fetch the flat list of accounts for a ledger. Consumers
/// can transform the flat list into a hierarchy using `AccountTreeBuilder`.
/// Provides a shared singleton for convenience.
///
/// Usage:
/// ```swift
/// let token = TokenStore.shared.load()!
/// let accounts = try await AccountService.shared.fetchAccounts(ledgerID: ledger.id, token: token)
/// let tree = AccountTreeBuilder.build(from: accounts)
/// // Present `tree` in an OutlineGroup or a List(children:)
/// ```
final class AccountService {

    /// Shared singleton instance for convenient access.
    static let shared = AccountService()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    // MARK: - Fetch Chart of Accounts

    /// Fetches the flat account list for a given ledger.
    ///
    /// - Parameters:
    ///   - ledgerID: The identifier of the ledger whose accounts to fetch.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: An array of `AccountResponse` models.
    /// - Throws: `APIError` for known API failures or other network-related errors.
    ///
    /// Example:
    /// ```swift
    /// let token = TokenStore.shared.load()!
    /// let accounts = try await AccountService.shared.fetchAccounts(ledgerID: ledger.id, token: token)
    /// ```
    func fetchAccounts(ledgerID: UUID, token: String) async throws -> [AccountResponse] {
        try await APIClient.shared.request(
            .accounts(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
    }
}

