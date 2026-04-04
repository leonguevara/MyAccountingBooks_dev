//
//  Core/Models/Commodity.swift
//  Commodity.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import Foundation

/// A commodity (currency or security) from the global catalog, returned by `GET /commodities`.
///
/// Referenced by `ledger.currencyCommodityId`, `transaction.currencyCommodityId`,
/// and `account.commodityId`. ``fraction`` equals the correct `valueDenom` for splits
/// (e.g. MXN `fraction=100` → `valueDenom: 100`).
struct CommodityResponse: Codable, Identifiable, Hashable, Equatable {
    /// Unique identifier.
    let id:        UUID
    /// Short ticker symbol (e.g. "MXN", "BTC").
    let mnemonic:  String
    /// Catalog namespace (e.g. "CURRENCY", "CRYPTO").
    let namespace: String
    /// Human-readable name (e.g. "Mexican Peso"). Nullable.
    let fullName:  String?
    /// Smallest unit denominator; use as `valueDenom` in split entries.
    let fraction:  Int
    /// Whether the commodity is available for use in new transactions.
    let isActive:  Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CommodityResponse, rhs: CommodityResponse) -> Bool {
        lhs.id == rhs.id
    }
}
