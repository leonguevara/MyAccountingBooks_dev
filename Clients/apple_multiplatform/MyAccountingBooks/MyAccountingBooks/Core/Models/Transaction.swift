//
//  Core/Models/Transaction.swift
//  Transaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// Represents a transaction returned by the backend API.
///
/// Conforms to `Identifiable` for convenient use in SwiftUI lists, and `Codable`
/// for JSON encoding/decoding.
///
/// Example JSON response:
///
/// ```json
/// {
///   "id": "A1B2C3D4-E5F6-47A8-9ABC-0123456789AB",
///   "ledgerId": "4E0B6C9E-2B6B-4C2E-9B8B-3E7B1A2D8F10",
///   "currencyCommodityId": "9F8E7D6C-5B4A-3210-1234-56789ABCDEF0",
///   "postDate": "2026-03-10T12:34:56Z",
///   "enterDate": "2026-03-10T12:35:10Z",
///   "memo": "Grocery run",
///   "num": "000123",
///   "isVoided": false,
///   "splits": [
///     {
///       "id": "11111111-2222-3333-4444-555555555555",
///       "accountId": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
///       "side": 1,
///       "valueNum": 4599,
///       "valueDenom": 100,
///       "memo": "Whole Foods"
///     },
///     {
///       "id": "66666666-7777-8888-9999-000000000000",
///       "accountId": "FFFFFFFF-1111-2222-3333-444444444444",
///       "side": -1,
///       "valueNum": 4599,
///       "valueDenom": 100,
///       "memo": null
///     }
///   ]
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let tx: TransactionResponse = try JSONDecoder().decode(TransactionResponse.self, from: data)
/// ```
struct TransactionResponse: Codable, Identifiable, Hashable {
    /// The unique identifier of the transaction.
    let id: UUID
    /// The identifier of the ledger this transaction belongs to.
    let ledgerId: UUID
    /// The identifier of the currency commodity used for amounts.
    let currencyCommodityId: UUID
    /// The posting date of the transaction.
    let postDate: Date
    /// The date/time the transaction was entered into the system.
    let enterDate: Date
    /// Optional memo/description for the transaction.
    let memo: String?
    /// Optional transaction number or reference.
    let num: String?
    /// Indicates whether the transaction has been voided.
    let isVoided: Bool
    /// The collection of splits that make up this transaction.
    let splits: [SplitResponse]
    
    // MARK: - Derived

    /// Total debit side of the transaction (should equal total credit).
    var totalAmount: Decimal {
        splits
            .filter { $0.side == 0 }
            .reduce(.zero) { $0 + $1.amount }
    }

    /// Hashes the transaction by its unique `id` to support hashed collections and selection.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    /// Transactions are considered equal when their `id` values match.
    static func == (lhs: TransactionResponse, rhs: TransactionResponse) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a single split (posting) within a transaction.
///
/// Example JSON element:
///
/// ```json
/// {
///   "id": "11111111-2222-3333-4444-555555555555",
///   "accountId": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
///   "side": 1,
///   "valueNum": 4599,
///   "valueDenom": 100,
///   "memo": "Whole Foods"
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let split: SplitResponse = try JSONDecoder().decode(SplitResponse.self, from: data)
/// ```
struct SplitResponse: Codable, Identifiable, Hashable {
    /// The unique identifier of the split.
    let id: UUID
    /// The account to which this split is posted.
    let accountId: UUID
    /// The sign or side of the posting (backend-defined; e.g., 1 for debit, -1 for credit).
    let side: Int
    /// The numerator of the split amount (e.g., minor units).
    let valueNum: Int
    /// The denominator used with `valueNum` to represent fractional amounts.
    let valueDenom: Int
    /// Optional memo/description for this split.
    let memo: String?
    
    // MARK: - Rational Arithmetic

    /// Converts rational valueNum/valueDenom to a displayable Decimal.
    /// Uses Decimal to avoid floating-point rounding errors.
    var amount: Decimal {
        guard valueDenom != 0 else { return .zero }
        return Decimal(valueNum) / Decimal(valueDenom)
    }

    /// Signed amount: positive for debits, negative for credits.
    var signedAmount: Decimal {
        side == 0 ? amount : -amount
    }

    /// Hashes the split by its unique `id` to support hashed collections and selection.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    /// Splits are considered equal when their `id` values match.
    static func == (lhs: SplitResponse, rhs: SplitResponse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Formatting Helpers

enum AmountFormatter {

    /// Formats a Decimal amount as a currency string.
    /// - Parameters:
    ///   - amount: The decimal amount to format.
    ///   - currencyCode: ISO 4217 code, e.g. "MXN", "USD".
    ///   - decimalPlaces: Number of decimal places from the ledger.
    static func format(
        _ amount: Decimal,
        currencyCode: String,
        decimalPlaces: Int
    ) -> String {
        var formatter = Decimal.FormatStyle.Currency(code: currencyCode)
        formatter = formatter.precision(.fractionLength(decimalPlaces))
        return amount.formatted(formatter)
    }

    /// Short date string for list display.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

