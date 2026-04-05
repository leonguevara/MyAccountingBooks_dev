//
//  Core/Models/PostTransaction.swift
//  PostTransaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
//  Developed with AI assistance.
//

import Foundation

// MARK: - Request Models

/// Encodable payload for posting a full transaction with multiple splits.
struct PostTransactionRequest: Encodable {
    let ledgerId:            UUID
    let currencyCommodityId: UUID
    let postDate:            Date?
    let enterDate:           Date?
    let memo:                String?
    let num:                 String?
    let status:              Int
    let payeeId:             UUID?
    let splits:              [SplitRequest]

    enum CodingKeys: String, CodingKey {
        case ledgerId, currencyCommodityId
        case postDate, enterDate
        case memo, num, status, payeeId, splits
    }
}

/// Encodable model for one split line sent to the backend.
///
/// # Multi-currency semantics
/// - `valueNum / valueDenom` — amount in the **transaction's base currency** (ledger currency).
/// - `quantityNum / quantityDenom` — amount in the **account's native currency**.
///   For same-currency splits these equal the value fields.
///   For foreign-currency splits these carry the foreign amount.
struct SplitRequest: Encodable {
    let accountId:     UUID
    let side:          Int
    let valueNum:      Int
    let valueDenom:    Int
    let quantityNum:   Int
    let quantityDenom: Int
    let memo:          String?
    let action:        String?

    enum CodingKeys: String, CodingKey {
        case accountId, side
        case valueNum, valueDenom
        case quantityNum, quantityDenom
        case memo, action
    }
}

// MARK: - Split Line (form state)

/// Editable form-state model for one split line in the Post Transaction form.
///
/// ## Multi-currency support
///
/// When the selected account has a different `commodityId` than the ledger's base
/// currency, the split enters **foreign-currency mode**:
///
/// - `foreignAmount` holds the amount in the foreign currency (e.g. "100" USD).
/// - `exchangeRate` holds the rate to convert to base currency (e.g. "17.89" MXN per USD).
/// - `debitAmount` / `creditAmount` are computed from `foreignAmount × exchangeRate`
///   and are read-only in this mode.
///
/// In same-currency mode (the default), `foreignAmount` and `exchangeRate` are empty
/// and `debitAmount` / `creditAmount` are the user's direct inputs.
///
/// ## Balance contribution
///
/// In both modes, `baseAmount` is the amount that counts toward `totalDebits` /
/// `totalCredits`. In foreign mode this is `foreignAmount × exchangeRate`; in
/// same-currency mode it is `effectiveAmount`.
struct SplitLine: Identifiable {
    let id = UUID()

    // MARK: - Account

    /// The selected account for this split. nil until the user picks one.
    var account: AccountNode?

    // MARK: - Same-currency amounts (direct user input)

    /// Debit amount string entered by the user (same-currency mode).
    var debitAmount:  String = ""
    /// Credit amount string entered by the user (same-currency mode).
    var creditAmount: String = ""

    // MARK: - Foreign-currency amounts

    /// Amount in the account's native foreign currency.
    /// Empty in same-currency mode; populated by the user in foreign-currency mode.
    var foreignAmount: String = ""

    /// Exchange rate: units of base currency per 1 unit of foreign currency.
    /// Pre-filled from the price table when available; editable by the user.
    /// Empty triggers a warning and blocks submission.
    var exchangeRate: String = ""

    // MARK: - Memo

    var memo: String = ""

    // MARK: - Foreign-currency mode detection

    /// True when the account has a foreign commodity AND the ledger's commodity is known.
    /// Set by the view model after an account is selected.
    var isForeignCurrency: Bool = false

    // MARK: - Derived

    /// True if this split can be included in the transaction.
    /// Foreign-currency mode requires a valid foreignAmount AND a non-empty exchangeRate.
    var isComplete: Bool {
        guard account != nil else { return false }
        if isForeignCurrency {
            let fa = Decimal(string: foreignAmount.trimmingCharacters(in: .whitespaces)) ?? .zero
            let er = Decimal(string: exchangeRate.trimmingCharacters(in: .whitespaces)) ?? .zero
            return fa > .zero && er > .zero
        }
        let d = Decimal(string: debitAmount) ?? .zero
        let c = Decimal(string: creditAmount) ?? .zero
        return d > .zero || c > .zero
    }

    /// True when in foreign-currency mode but the exchange rate field is empty.
    /// Used to show a warning in the UI and block submission.
    var isMissingRate: Bool {
        guard isForeignCurrency else { return false }
        let fa = Decimal(string: foreignAmount.trimmingCharacters(in: .whitespaces)) ?? .zero
        let er = Decimal(string: exchangeRate.trimmingCharacters(in: .whitespaces)) ?? .zero
        return fa > .zero && er == .zero
    }

    /// The effective amount in the **base currency** that contributes to balance totals.
    ///
    /// Foreign mode: `foreignAmount × exchangeRate`
    /// Same-currency mode: the non-zero debit or credit amount.
    var baseAmount: Decimal {
        if isForeignCurrency {
            let fa = Decimal(string: foreignAmount.trimmingCharacters(in: .whitespaces)) ?? .zero
            let er = Decimal(string: exchangeRate.trimmingCharacters(in: .whitespaces)) ?? .zero
            return fa * er
        }
        return effectiveAmount
    }

    /// The raw effective amount (same-currency mode only).
    var effectiveAmount: Decimal {
        if let d = Decimal(string: debitAmount), d > .zero { return d }
        if let c = Decimal(string: creditAmount), c > .zero { return c }
        return .zero
    }

    /// 0 = DEBIT, 1 = CREDIT.
    var side: Int {
        if isForeignCurrency {
            // In foreign mode side is determined by debitAmount / creditAmount
            // which are set by the UI toggle.
            if let d = Decimal(string: debitAmount), d > .zero { return 0 }
            return 1
        }
        if let d = Decimal(string: debitAmount), d > .zero { return 0 }
        return 1
    }

    // MARK: - Rational conversion helpers

    /// `valueNum` for the **base currency** value (same-currency or converted foreign).
    func toValueNum(denom: Int) -> Int {
        let amount: Decimal
        if isForeignCurrency {
            amount = baseAmount
        } else {
            amount = effectiveAmount
        }
        let num = amount * Decimal(denom)
        return Int(truncating: num as NSDecimalNumber)
    }

    /// `quantityNum` for the **account's native currency**.
    /// Same as `toValueNum` for same-currency splits.
    func toQuantityNum(quantityDenom: Int) -> Int {
        if isForeignCurrency {
            let fa = Decimal(string: foreignAmount.trimmingCharacters(in: .whitespaces)) ?? .zero
            let num = fa * Decimal(quantityDenom)
            return Int(truncating: num as NSDecimalNumber)
        }
        return toValueNum(denom: quantityDenom)
    }
}
