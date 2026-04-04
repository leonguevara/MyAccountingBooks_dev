//
//  Core/Models/Price.swift
//  Price.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import Foundation

// MARK: - Response

/// An exchange rate entry returned by the price endpoints.
///
/// The rate is encoded as a rational: `rate = Decimal(valueNum) / Decimal(valueDenom)`
/// (e.g. USD/MXN = 19.50 → `valueNum=1950, valueDenom=100`).
struct PriceResponse: Codable, Identifiable, Hashable {
    /// Unique identifier.
    let id:          UUID
    /// UUID of the owning ledger.
    let ledgerId:    UUID
    /// UUID of the commodity being priced (e.g. USD).
    let commodityId: UUID
    /// UUID of the reference currency (e.g. MXN).
    let currencyId:  UUID
    /// Timestamp at which this rate is effective.
    let date:        Date
    /// Rational numerator of the exchange rate.
    let valueNum:    Int
    /// Rational denominator of the exchange rate.
    let valueDenom:  Int
    /// Optional source label (e.g. "manual", "Banxico").
    let source:      String?
    /// Optional price type (e.g. "last", "bid", "ask").
    let type:        String?

    /// Exchange rate as a `Decimal`; `0` if `valueDenom` is zero.
    var rate: Decimal {
        guard valueDenom != 0 else { return .zero }
        return Decimal(valueNum) / Decimal(valueDenom)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PriceResponse, rhs: PriceResponse) -> Bool { lhs.id == rhs.id }
}

// MARK: - Request

/// Request body for `POST /ledgers/{id}/prices`.
struct CreatePriceRequest: Encodable {
    /// UUID of the commodity being priced (e.g. USD).
    let commodityId: UUID
    /// UUID of the reference currency (e.g. MXN).
    let currencyId:  UUID
    /// Effective timestamp; omit to default to `now()` on the server.
    let date:        Date?
    /// Rational numerator of the exchange rate.
    let valueNum:    Int
    /// Rational denominator of the exchange rate.
    let valueDenom:  Int
    /// Optional source label (e.g. "manual", "Banxico").
    let source:      String?
    /// Optional price type (e.g. "last", "bid", "ask").
    let type:        String?
}
