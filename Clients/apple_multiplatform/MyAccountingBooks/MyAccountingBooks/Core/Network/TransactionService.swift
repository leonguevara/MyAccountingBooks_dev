//
//  Core/Network/TransactionService.swift
//  TransactionService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-13.
//  Last modified by León Felipe Guevara Chávez on 2026-03-30.
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
    
    /// Reverses a posted transaction by calling POST /transactions/{id}/reverse.
    /// Creates a new mirror transaction with all split sides flipped (DEBIT↔CREDIT).
    /// - Parameters:
    ///   - id: UUID of the transaction to reverse.
    ///   - memo: Optional custom memo for the reversal transaction. Nil uses the default.
    ///   - token: Bearer token for authorization.
    /// - Returns: The newly created reversal TransactionResponse.
    func reverseTransaction(id: UUID, memo: String?, token: String) async throws -> TransactionResponse {
        // Backend accepts an optional body — send memo if provided, empty object otherwise
        struct ReverseBody: Encodable { let memo: String? }
        return try await APIClient.shared.request(
            .reverseTransaction(id: id),
            method: "POST",
            body: ReverseBody(memo: memo),
            token: token
        )
    }

    /// Voids a posted transaction by calling POST /transactions/{id}/void.
    /// Marks the transaction as voided in-place — does not create a new transaction.
    /// - Parameters:
    ///   - id: UUID of the transaction to void.
    ///   - reason: Optional reason appended to the transaction memo as [VOID: reason].
    ///   - token: Bearer token for authorization.
    /// - Returns: The updated (voided) TransactionResponse.
    func voidTransaction(id: UUID, reason: String?, token: String) async throws -> TransactionResponse {
        struct VoidBody: Encodable { let reason: String? }
        return try await APIClient.shared.request(
            .voidTransaction(id: id),
            method: "POST",
            body: VoidBody(reason: reason),
            token: token
        )
    }
}
