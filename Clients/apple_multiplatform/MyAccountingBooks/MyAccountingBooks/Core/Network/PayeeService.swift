//
//  Core/Network/PayeeService.swift
//  PayeeService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Networking layer for payee endpoints.
///
/// Wraps ``APIClient/request(_:method:body:token:)`` for the two payee routes.
/// All calls require a valid bearer token.
///
/// - SeeAlso: ``PayeeResponse``, ``CreatePayeeRequest``, ``APIEndpoint/payees(ledgerID:)``
final class PayeeService {

    /// Shared singleton instance.
    static let shared = PayeeService()
    private init() {}

    /// Fetches all active payees for the given ledger (`GET /ledgers/{ledgerID}/payees`).
    ///
    /// - Parameters:
    ///   - ledgerID: UUID of the ledger whose payees are requested.
    ///   - token: Bearer token for authentication.
    /// - Returns: Array of ``PayeeResponse`` objects ordered by name; empty if none exist.
    /// - Throws: ``APIError`` on network or HTTP failure.
    func fetchPayees(ledgerID: UUID, token: String) async throws -> [PayeeResponse] {
        try await APIClient.shared.request(
            .payees(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
    }

    /// Creates a new payee in the given ledger (`POST /payees`).
    ///
    /// - Parameters:
    ///   - ledgerID: UUID of the ledger the payee belongs to.
    ///   - name: Display name of the payee; must be non-blank and unique within the ledger.
    ///   - token: Bearer token for authentication.
    /// - Returns: The created ``PayeeResponse``.
    /// - Throws: ``APIError/conflict`` (HTTP 409) if the name already exists in the ledger;
    ///   ``APIError`` for other network or HTTP failures.
    func createPayee(ledgerID: UUID, name: String, token: String) async throws -> PayeeResponse {
        let body = CreatePayeeRequest(ledgerId: ledgerID, name: name)
        return try await APIClient.shared.request(
            .createPayee,
            method: "POST",
            body: body,
            token: token
        )
    }
}
