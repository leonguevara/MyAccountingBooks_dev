//
//  Core/Network/PayeeService.swift
//  PayeeService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Network service for payee operations.
final class PayeeService {

    static let shared = PayeeService()
    private init() {}

    /// Fetches all active payees for the given ledger.
    func fetchPayees(ledgerID: UUID, token: String) async throws -> [PayeeResponse] {
        try await APIClient.shared.request(
            .payees(ledgerID: ledgerID),
            method: "GET",
            token: token
        )
    }

    /// Creates a new payee and returns the created record.
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
