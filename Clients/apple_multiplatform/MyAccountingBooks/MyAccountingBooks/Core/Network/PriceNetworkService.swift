//
//  Core/Network/PriceNetworkService.swift
//  PriceNetworkService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04.
//  Developed with AI assistance.
//

import Foundation

/// Network service for price CRUD operations.
///
/// Wraps ``APIClient`` for the three price endpoints: fetch, create, and soft-delete.
/// Named `PriceNetworkService` to avoid collision with the ``PriceResponse`` type.
///
/// - SeeAlso: ``PriceResponse``, ``CreatePriceRequest``, ``APIEndpoint``
final class PriceNetworkService {

    /// Shared singleton instance.
    static let shared = PriceNetworkService()
    private init() {}

    /// Returns all active prices for the given ledger, ordered by date descending.
    func fetchPrices(ledgerID: UUID, token: String) async throws -> [PriceResponse] {
        try await APIClient.shared.request(
            .prices(ledgerID: ledgerID),
            method: "GET",
            token:  token
        )
    }

    /// Creates a new price entry in the given ledger and returns the server-assigned record.
    func createPrice(
        ledgerID:    UUID,
        commodityId: UUID,
        currencyId:  UUID,
        date:        Date?,
        valueNum:    Int,
        valueDenom:  Int,
        source:      String?,
        type:        String?,
        token:       String
    ) async throws -> PriceResponse {
        let body = CreatePriceRequest(
            commodityId: commodityId,
            currencyId:  currencyId,
            date:        date,
            valueNum:    valueNum,
            valueDenom:  valueDenom,
            source:      source,
            type:        type
        )
        return try await APIClient.shared.request(
            .createPrice(ledgerID: ledgerID),
            method: "POST",
            body:   body,
            token:  token
        )
    }

    /// Soft-deletes a price entry; expects HTTP 204 No Content.
    func deletePrice(priceID: UUID, token: String) async throws {
        try await APIClient.shared.requestNoContent(
            .deletePrice(id: priceID),
            method: "DELETE",
            token:  token
        )
    }
}
