//
//  Core/Models/AccountBalance.swift
//  AccountBalance.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-21.
//  Last modified by León Felipe Guevara Chávez on 2026-04-06
//  Developed with AI assistance.
//

import Foundation

// MARK: - API Response

/// The current balance of an account, expressed in two currencies.
///
/// ## Two balance fields
///
/// | Fields | Currency | Source | Used by |
/// |---|---|---|---|
/// | `balanceNum / balanceDenom` | Ledger base (MXN) | `split.value_num` | AccountTree roll-ups |
/// | `nativeBalanceNum / nativeBalanceDenom` | Account native (USD) | `split.quantity_num` | AccountTree native column, RegisterView |
///
/// For same-currency accounts both pairs are equal.
/// The client determines whether an account is foreign-currency by comparing
/// `AccountResponse.commodityId` with `LedgerResponse.currencyCommodityId`.
struct AccountBalanceResponse: Codable {

    let accountId:          UUID

    // ── Base currency (value fields) ──────────────────────────────────────────
    /// Signed numerator in the ledger's base currency.
    let balanceNum:         Int
    /// Denominator for the base-currency balance (e.g. 100 for 2 decimal places).
    let balanceDenom:       Int

    // ── Native currency (quantity fields) ─────────────────────────────────────
    /// Signed numerator in the account's own commodity (e.g. USD).
    let nativeBalanceNum:   Int
    /// Denominator for the native-currency balance.
    let nativeBalanceDenom: Int

    // MARK: - Computed

    /// Base-currency balance as `Decimal` (ledger currency, e.g. MXN).
    var balance: Decimal {
        guard balanceDenom != 0 else { return .zero }
        return Decimal(balanceNum) / Decimal(balanceDenom)
    }

    /// Native-currency balance as `Decimal` (account's own currency, e.g. USD).
    /// Equal to `balance` for same-currency accounts.
    var nativeBalance: Decimal {
        guard nativeBalanceDenom != 0 else { return .zero }
        return Decimal(nativeBalanceNum) / Decimal(nativeBalanceDenom)
    }
}

// MARK: - Balance Map

/// Dictionary mapping account UUIDs to their `AccountBalanceResponse` for O(1) lookup.
typealias BalanceMap = [UUID: AccountBalanceResponse]
