//
//  Core/Network/TransactionService.swift
//  TransactionService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-13.
//  Developed with AI assistance.
//

import Foundation

/// A service that encapsulates network operations related to transactions.
///
/// Uses `APIClient` to fetch transactions for a given ledger. Provides a shared
/// singleton for convenience.
///
/// Usage:
/// ```swift
/// let token = TokenStore.shared.load()!
/// let txs = try await TransactionService.shared.fetchTransactions(ledgerID: ledger.id, token: token)
/// ```
final class TransactionService {

    /// Shared singleton instance for convenient access.
    static let shared = TransactionService()

    /// Private initializer to enforce singleton usage.
    private init() {}

    /// Fetches transactions for the specified ledger.
    ///
    /// - Parameters:
    ///   - ledgerID: The identifier of the ledger whose transactions to fetch.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: An array of `TransactionResponse` models.
    /// - Throws: `APIError` for known API failures or other network-related errors.
    ///
    /// Example:
    /// ```swift
    /// let token = TokenStore.shared.load()!
    /// let txs = try await TransactionService.shared.fetchTransactions(ledgerID: ledger.id, token: token)
    /// ```
    func fetchTransactions(ledgerID: UUID, token: String) async throws -> [TransactionResponse] {
        try await APIClient.shared.request(
            .transactions(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
    }
}
