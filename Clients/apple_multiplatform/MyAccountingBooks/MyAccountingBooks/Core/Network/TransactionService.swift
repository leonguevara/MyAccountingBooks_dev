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
/// `TransactionService` wraps ``APIClient`` for all transaction-related routes:
///
/// | Method | Route | Description |
/// |---|---|---|
/// | ``fetchTransactions(ledgerID:token:)`` | `GET /transactions` | List all transactions for a ledger |
/// | ``reverseTransaction(id:memo:token:)`` | `POST /transactions/{id}/reverse` | Create a mirror reversal transaction |
/// | ``voidTransaction(id:reason:token:)`` | `POST /transactions/{id}/void` | Mark a transaction as voided in-place |
///
/// - SeeAlso: ``APIClient``, ``TransactionResponse``
final class TransactionService {

    /// Shared singleton instance for convenient access.
    static let shared = TransactionService()

    /// Private initializer to enforce singleton usage.
    private init() {}

    /// Fetches all transactions for the specified ledger.
    ///
    /// - Parameters:
    ///   - ledgerID: The UUID of the ledger whose transactions to fetch.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: An array of ``TransactionResponse`` models.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
    ///
    /// ## Example
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
    
    /// Creates a mirror reversal of a posted transaction.
    ///
    /// Calls `POST /transactions/{id}/reverse`. The backend produces a new transaction
    /// with all split sides flipped (DEBIT↔CREDIT), effectively cancelling the original
    /// without modifying it.
    ///
    /// - Parameters:
    ///   - id: UUID of the transaction to reverse.
    ///   - memo: Optional memo for the reversal transaction. Pass `nil` to use the backend default.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: The newly created reversal ``TransactionResponse``.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
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

    /// Marks a posted transaction as voided in-place.
    ///
    /// Calls `POST /transactions/{id}/void`. The transaction is flagged `is_voided = true`
    /// in the database; no new transaction is created. If `reason` is provided, the backend
    /// appends `[VOID: reason]` to the transaction memo.
    ///
    /// - Parameters:
    ///   - id: UUID of the transaction to void.
    ///   - reason: Optional reason string appended to the memo. Pass `nil` to omit.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: The updated (voided) ``TransactionResponse``.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
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
