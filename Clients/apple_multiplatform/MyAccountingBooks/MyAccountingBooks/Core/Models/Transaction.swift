//
//  Core/Models/Transaction.swift
//  Transaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
//  Developed with AI assistance.
//

import Foundation

/// Transaction record returned by the backend API.
struct TransactionResponse: Codable, Identifiable, Hashable {
    let id:                  UUID
    let ledgerId:            UUID
    let currencyCommodityId: UUID
    let postDate:            Date
    let enterDate:           Date
    let memo:                String?
    let num:                 String?
    let isVoided:            Bool
    let splits:              [SplitResponse]
    let payeeId:             UUID?

    /// Sum of all debit-side split amounts in base currency.
    var totalAmount: Decimal {
        splits.filter { $0.side == 0 }.reduce(.zero) { $0 + $1.amount }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: TransactionResponse, rhs: TransactionResponse) -> Bool {
        lhs.id == rhs.id
    }
}

/// A single split line within a ``TransactionResponse``.
///
/// ## Multi-currency fields
///
/// | Field pair | Meaning |
/// |---|---|
/// | `valueNum / valueDenom` | Amount in the **ledger's base currency** (e.g. MXN) |
/// | `quantityNum / quantityDenom` | Amount in the **account's native currency** (e.g. USD) |
///
/// For same-currency splits these pairs are equal.
///
/// The AccountTree uses `amount` (base currency).
/// The AccountRegisterView uses `quantityAmount` when the account is foreign-currency.
struct SplitResponse: Codable, Identifiable, Hashable {
    let id:             UUID
    let accountId:      UUID
    let side:           Int
    let valueNum:       Int
    let valueDenom:     Int
    /// Native-currency numerator. Equal to `valueNum` for same-currency splits.
    let quantityNum:    Int
    /// Native-currency denominator. Equal to `valueDenom` for same-currency splits.
    let quantityDenom:  Int
    let memo:           String?

    // MARK: - Computed amounts

    /// Absolute amount in the **ledger's base currency** (valueNum / valueDenom).
    var amount: Decimal {
        guard valueDenom != 0 else { return .zero }
        return Decimal(valueNum) / Decimal(valueDenom)
    }

    /// Absolute amount in the **account's native currency** (quantityNum / quantityDenom).
    /// Use this in the register view for foreign-currency accounts.
    var quantityAmount: Decimal {
        guard quantityDenom != 0 else { return .zero }
        return Decimal(quantityNum) / Decimal(quantityDenom)
    }

    /// Signed base-currency amount: positive for debits, negative for credits.
    var signedAmount: Decimal { side == 0 ? amount : -amount }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SplitResponse, rhs: SplitResponse) -> Bool { lhs.id == rhs.id }
}

// MARK: - Formatting Helpers

enum AmountFormatter {

    static func format(
        _ amount: Decimal,
        currencyCode: String,
        decimalPlaces: Int
    ) -> String {
        var formatter = Decimal.FormatStyle.Currency(code: currencyCode)
        formatter = formatter.precision(.fractionLength(decimalPlaces))
        return amount.formatted(formatter)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
