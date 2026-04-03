//
//  Core/Models/Transaction.swift
//  Transaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Transaction record returned by the backend API.
///
/// Conforms to `Identifiable` (keyed on `id`) for SwiftUI lists and `Hashable`
/// for use as a selection value. `Codable` handles ISO 8601 date decoding via
/// ``APIClient``'s shared decoder.
///
/// - SeeAlso: ``SplitResponse``, ``APIEndpoint/transactions(ledgerID:)``
struct TransactionResponse: Codable, Identifiable, Hashable {
    /// Unique identifier of the transaction.
    let id: UUID
    /// UUID of the ledger this transaction was posted to.
    let ledgerId: UUID
    /// UUID of the currency commodity used for all split amounts.
    let currencyCommodityId: UUID
    /// Effective (accounting) date of the transaction.
    let postDate: Date
    /// Timestamp when the transaction was entered into the system.
    let enterDate: Date
    /// Transaction-level narrative; `nil` when not provided.
    let memo: String?
    /// Reference or check number; `nil` when not provided.
    let num: String?
    /// `true` after the transaction has been voided via `POST .../void`.
    let isVoided: Bool
    /// Split lines that make up the double-entry posting.
    let splits: [SplitResponse]
    /// Associated payee UUID; `nil` when no payee is set.
    let payeeId: UUID?

    // MARK: - Derived

    /// Sum of all debit-side (`side == 0`) split amounts; equals total credits in a balanced transaction.
    var totalAmount: Decimal {
        splits
            .filter { $0.side == 0 }
            .reduce(.zero) { $0 + $1.amount }
    }

    /// Hashes by `id` only.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    /// Equality is determined solely by `id`.
    static func == (lhs: TransactionResponse, rhs: TransactionResponse) -> Bool {
        lhs.id == rhs.id
    }
}

/// A single split line within a ``TransactionResponse``.
///
/// The monetary amount is stored as a rational number (`valueNum / valueDenom`).
/// Use ``amount`` for an absolute `Decimal` value and ``signedAmount`` for a
/// signed value where debits are positive and credits are negative.
///
/// - SeeAlso: ``TransactionResponse``
struct SplitResponse: Codable, Identifiable, Hashable {
    /// Unique identifier of the split record.
    let id: UUID
    /// UUID of the account this split posts to.
    let accountId: UUID
    /// Side of the posting: `0` = DEBIT, `1` = CREDIT.
    let side: Int
    /// Rational numerator of the monetary amount (unsigned).
    let valueNum: Int
    /// Rational denominator; all splits in the same transaction share the same value.
    let valueDenom: Int
    /// Per-split narrative; `nil` when not provided.
    let memo: String?

    // MARK: - Rational Arithmetic

    /// Absolute `Decimal` amount computed as `valueNum / valueDenom`.
    ///
    /// Returns `.zero` when `valueDenom` is `0` to avoid division by zero.
    var amount: Decimal {
        guard valueDenom != 0 else { return .zero }
        return Decimal(valueNum) / Decimal(valueDenom)
    }

    /// Signed amount: positive for debits (`side == 0`), negative for credits.
    var signedAmount: Decimal {
        side == 0 ? amount : -amount
    }

    /// Hashes by `id` only.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    /// Equality is determined solely by `id`.
    static func == (lhs: SplitResponse, rhs: SplitResponse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Formatting Helpers

/// Stateless formatting helpers for amounts and dates used in transaction list views.
enum AmountFormatter {

    /// Formats a `Decimal` amount as a localised currency string.
    ///
    /// - Parameters:
    ///   - amount: The decimal amount to format.
    ///   - currencyCode: ISO 4217 currency code (e.g., `"MXN"`, `"USD"`).
    ///   - decimalPlaces: Fractional digit count from the ledger's `decimalPlaces` setting.
    /// - Returns: A localised currency string (e.g., `"MX$45.99"`).
    static func format(
        _ amount: Decimal,
        currencyCode: String,
        decimalPlaces: Int
    ) -> String {
        var formatter = Decimal.FormatStyle.Currency(code: currencyCode)
        formatter = formatter.precision(.fractionLength(decimalPlaces))
        return amount.formatted(formatter)
    }

    /// Formats a `Date` as a short display string (e.g., `"Mar 10, 2026"`).
    ///
    /// - Parameter date: The date to format.
    /// - Returns: An abbreviated day-month-year string.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

