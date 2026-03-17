//
//  Core/Models/PostTransaction.swift
//  PostTransaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import Foundation

/// Models used for posting a full transaction with multiple splits to the backend.
///
/// Rational amounts are represented as numerator/denominator pairs to maintain precision.
/// The ledger transaction consists of a main transaction record plus one or more splits.
/// 
/// # Overview
/// - `PostTransactionRequest`: Encodable model representing the full transaction payload.
/// - `SplitRequest`: Encodable model for each split line of the transaction.
/// - `SplitLine`: Form state model for user input with decimal strings, convertible to `SplitRequest`.
///
/// # Usage example
/// ```swift
/// let split = SplitRequest(accountId: UUID(uuidString: "SOME_UUID")!,
///                          side: 0,
///                          valueNum: 100,
///                          valueDenom: 1,
///                          quantityNum: 100,
///                          quantityDenom: 1,
///                          memo: "Sample split",
///                          action: nil)
/// let request = PostTransactionRequest(ledgerId: UUID(uuidString: "LEDGER_UUID")!,
///                                      currencyCommodityId: UUID(uuidString: "CURRENCY_UUID")!,
///                                      postDate: Date(),
///                                      enterDate: nil,
///                                      memo: "Transaction memo",
///                                      num: "123",
///                                      status: 0,
///                                      payeeId: nil,
///                                      splits: [split])
/// ```
 
// MARK: - Request Models

/// Encodable payload for posting a full transaction with multiple splits.
/// 
/// The transaction is tied to a specific ledger and currency commodity.
/// Dates are optional; if provided, they must be valid and typically `postDate` is the effective date.
/// The `status` field denotes the transaction status (e.g., cleared, reconciled).
/// The `splits` array must contain at least one split and the total debits and credits must balance.
/// 
/// # Example
/// ```swift
/// let split = SplitRequest(accountId: UUID(uuidString: "ACCOUNT_UUID")!,
///                          side: 0,
///                          valueNum: 500,
///                          valueDenom: 100,
///                          quantityNum: 500,
///                          quantityDenom: 100,
///                          memo: "Split memo",
///                          action: nil)
/// let request = PostTransactionRequest(ledgerId: UUID(uuidString: "LEDGER_UUID")!,
///                                      currencyCommodityId: UUID(uuidString: "CURRENCY_UUID")!,
///                                      postDate: Date(),
///                                      enterDate: Date(),
///                                      memo: "Transaction memo",
///                                      num: "TX123",
///                                      status: 1,
///                                      payeeId: UUID(uuidString: "PAYEE_UUID"),
///                                      splits: [split])
/// ```
struct PostTransactionRequest: Encodable {
    /// Ledger identifier where the transaction belongs.
    let ledgerId: UUID
    
    /// Currency commodity identifier for the transaction amounts.
    let currencyCommodityId: UUID
    
    /// Posting date of the transaction (optional).
    let postDate: Date?
    
    /// Enter date of the transaction (optional).
    let enterDate: Date?
    
    /// Optional memo for the transaction.
    let memo: String?
    
    /// Optional user-assigned transaction number or reference.
    let num: String?
    
    /// Status code representing transaction state (e.g., 0 = pending, 1 = cleared).
    let status: Int
    
    /// Optional payee identifier for the transaction.
    let payeeId: UUID?
    
    /// Array of split lines belonging to this transaction; must balance.
    let splits: [SplitRequest]
    
    /// Explicit keys — ensures exact camelCase names regardless of encoder strategy.
    enum CodingKeys: String, CodingKey {
        case ledgerId
        case currencyCommodityId
        case postDate
        case enterDate
        case memo
        case num
        case status
        case payeeId
        case splits
    }
}

/// Represents one split line in a transaction; encodable for posting.
///
/// `side` indicates debit (0) or credit (1).
/// Amounts and quantities are represented as rational numbers: numerator/denominator pairs.
///
/// # Example
/// ```swift
/// let split = SplitRequest(accountId: UUID(uuidString: "ACCOUNT_UUID")!,
///                          side: 1,
///                          valueNum: 250,
///                          valueDenom: 100,
///                          quantityNum: 250,
///                          quantityDenom: 100,
///                          memo: "Payment split",
///                          action: nil)
/// ```
struct SplitRequest: Encodable {
    /// Account identifier for this split.
    let accountId: UUID
    
    /// Split side: 0 = debit, 1 = credit.
    let side: Int
    
    /// Numerator for the split's value amount.
    let valueNum: Int
    
    /// Denominator for the split's value amount.
    let valueDenom: Int
    
    /// Numerator for the split's quantity amount.
    let quantityNum: Int
    
    /// Denominator for the split's quantity amount.
    let quantityDenom: Int
    
    /// Optional memo for this split.
    let memo: String?
    
    /// Optional action string (e.g., "delete", "update").
    let action: String?
    
    /// Explicit keys — ensures exact camelCase names regardless of encoder strategy.
    enum CodingKeys: String, CodingKey {
        case accountId
        case side
        case valueNum
        case valueDenom
        case quantityNum
        case quantityDenom
        case memo
        case action
    }
}

// MARK: - Split Line (form state)

/// Editable form-state model representing one split line in the Post Transaction form.
///
/// This model uses user-facing decimal strings for amounts (`debitAmount`, `creditAmount`).
/// On submission, these decimal values can be converted to rational numbers for `SplitRequest`.
/// The `side` property is derived automatically:
/// - `0` if there is a positive debit amount,
/// - `1` otherwise (credit).
///
/// # Usage example
/// ```swift
/// let denom = 100
/// let splitRequest = SplitRequest(
///     accountId: splitLine.account!.id,
///     side: splitLine.side,
///     valueNum: splitLine.toValueNum(denom: denom),
///     valueDenom: denom,
///     quantityNum: splitLine.toValueNum(denom: denom),
///     quantityDenom: denom,
///     memo: splitLine.memo,
///     action: nil
/// )
/// ```
struct SplitLine: Identifiable {
    /// Unique identifier for this split line.
    let id = UUID()
    
    /// Optional selected account node for this split.
    var account: AccountNode?
    
    /// User-edited debit amount as a decimal string.
    var debitAmount: String  = ""
    
    /// User-edited credit amount as a decimal string.
    var creditAmount: String = ""
    
    /// Optional memo text for this split.
    var memo: String         = ""

    // MARK: - Derived

    /// Returns true if this line has a selected account and a non-zero amount (debit or credit).
    /// Returns false if account is nil or amounts are zero or invalid.
    var isComplete: Bool {
        guard account != nil else { return false }
        let d = Decimal(string: debitAmount) ?? .zero
        let c = Decimal(string: creditAmount) ?? .zero
        return d > .zero || c > .zero
    }

    /// Returns the effective amount as a positive decimal regardless of side.
    /// If debit amount is positive, returns debit; else returns positive credit amount.
    /// Returns zero if neither amount is positive or invalid.
    var effectiveAmount: Decimal {
        if let d = Decimal(string: debitAmount), d > .zero { return d }
        if let c = Decimal(string: creditAmount), c > .zero { return c }
        return .zero
    }

    /// Returns the side of the split line:
    /// - `0` (debit) if debitAmount is a positive decimal,
    /// - `1` (credit) otherwise (including zero or invalid debitAmount).
    var side: Int {
        if let d = Decimal(string: debitAmount), d > .zero { return 0 }
        return 1
    }

    /// Converts the effective decimal amount to an integer numerator using the given denominator.
    /// - Parameter denom: The denominator to scale the decimal amount.
    /// - Returns: The integer numerator value (amount * denom), truncated toward zero.
    func toValueNum(denom: Int) -> Int {
        let amount = effectiveAmount
        let num = amount * Decimal(denom)
        return Int(truncating: num as NSDecimalNumber)
    }
}
