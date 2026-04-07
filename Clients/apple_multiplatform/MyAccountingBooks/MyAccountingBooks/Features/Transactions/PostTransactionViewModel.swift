//
//  Features/Transactions/PostTransactionViewModel.swift
//  PostTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
//  Developed with AI assistance.
//

import Foundation

/// Manages form state, balance validation, and submission for the Post Transaction sheet.
///
/// ## Multi-currency support
///
/// When a split's selected account has a `commodityId` that differs from the ledger's
/// base currency commodity, the view model:
///
/// 1. Sets `SplitLine.isForeignCurrency = true` on that split.
/// 2. Looks up the most recent price from `prices` for that commodity pair.
/// 3. Pre-fills `SplitLine.exchangeRate` if a price is found.
/// 4. If no price is found, leaves the rate empty — the split shows a warning
///    and `canSubmit` remains `false` until the user enters a rate manually.
///
/// Balance computation uses `SplitLine.baseAmount` (base-currency equivalent)
/// for all splits regardless of mode.
///
/// - SeeAlso: ``PostTransactionView``, ``SplitLine``, ``PriceResponse``
@Observable
final class PostTransactionViewModel {

    // MARK: - Form State

    var postDate: Date    = .now
    var memo:     String  = ""
    var num:      String  = ""
    var splits:   [SplitLine] = [SplitLine(), SplitLine()]

    // MARK: - Multi-currency support

    /// Prices loaded from the price table for the current ledger.
    /// Used to pre-fill exchange rates when a foreign-currency account is selected.
    var prices: [PriceResponse] = []

    /// The ledger's base currency commodity UUID.
    /// Set by the view when the form opens.
    var ledgerCommodityId: UUID? = nil

    // MARK: - UI State

    var isSubmitting  = false
    var errorMessage: String?
    var didPost       = false

    var accountSearchTexts: [UUID: String] = [:]
    var showAccountPicker:  UUID?           = nil

    // MARK: - Dependencies

    private let service = PostTransactionService.shared

    // MARK: - Computed Properties

    /// Sum of base-currency debit amounts across all splits.
    var totalDebits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard line.side == 0 else { return sum }
            return sum + line.baseAmount
        }
    }

    /// Sum of base-currency credit amounts across all splits.
    var totalCredits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard line.side == 1 else { return sum }
            return sum + line.baseAmount
        }
    }

    var isBalanced: Bool {
        totalDebits > .zero && totalDebits == totalCredits
    }

    var imbalance: Decimal {
        totalDebits - totalCredits
    }

    /// True only when balanced, all splits complete, no missing rates, not submitting.
    var canSubmit: Bool {
        isBalanced
        && splits.allSatisfy { $0.isComplete }
        && !splits.contains { $0.isMissingRate }
        && !isSubmitting
    }

    /// True when any split has a foreign-currency account with a missing rate.
    /// Used to show a form-level warning banner.
    var hasMissingRates: Bool {
        splits.contains { $0.isMissingRate }
    }

    // MARK: - Split Management

    func addSplitLine() { splits.append(SplitLine()) }

    func removeSplitLine(id: UUID) {
        guard splits.count > 2 else { return }
        splits.removeAll { $0.id == id }
    }

    func didEditDebit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].creditAmount = ""
        }
    }

    func didEditCredit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].debitAmount = ""
        }
    }

    /// Sets the account for a split and configures multi-currency mode if needed.
    ///
    /// - If the account's `commodityId` differs from `ledgerCommodityId`, marks the
    ///   split as foreign-currency and attempts to pre-fill the exchange rate from `prices`.
    /// - If no price is found, the rate is left empty and `isMissingRate` becomes true.
    func setAccount(_ account: AccountNode, for id: UUID) {
        guard let idx = splits.firstIndex(where: { $0.id == id }) else { return }

        splits[idx].account = account
        showAccountPicker   = nil

        // Determine if this is a foreign-currency account
        let accountCommodity = account.account.commodityId
        let isForeign = accountCommodity != nil
                     && ledgerCommodityId != nil
                     && accountCommodity != ledgerCommodityId

        splits[idx].isForeignCurrency = isForeign

        if isForeign, let foreignId = accountCommodity, let baseId = ledgerCommodityId {
            // Clear previous amounts
            splits[idx].debitAmount  = ""
            splits[idx].creditAmount = ""
            splits[idx].foreignAmount = ""

            // Look up most recent price: foreignId priced in baseId
            let rate = bestRate(commodityId: foreignId, currencyId: baseId)
            splits[idx].exchangeRate = rate.map { formatRate($0) } ?? ""
        } else {
            splits[idx].isForeignCurrency = false
            splits[idx].foreignAmount     = ""
            splits[idx].exchangeRate      = ""
        }
    }

    // MARK: - Auto-balance

    /// Fills the last split to balance the transaction.
    /// For same-currency splits only — foreign splits must be entered manually.
    func autoBalance() {
        guard let lastIdx = splits.indices.last else { return }
        guard !splits[lastIdx].isForeignCurrency else { return }
        let diff = totalDebits - totalCredits
        if diff > .zero {
            splits[lastIdx].creditAmount = "\(diff)"
            splits[lastIdx].debitAmount  = ""
        } else if diff < .zero {
            splits[lastIdx].debitAmount  = "\(-diff)"
            splits[lastIdx].creditAmount = ""
        }
    }

    // MARK: - Submit

    @MainActor
    func submit(ledger: LedgerResponse, payeeId: UUID? = nil, token: String) async {
        guard canSubmit else { return }
        guard let commodityId = ledger.currencyCommodityId else {
            errorMessage = "Ledger is missing currency commodity ID. Please sign out and sign back in."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let baseDenom = Int(pow(10.0, Double(ledger.decimalPlaces)))

        let splitRequests: [SplitRequest] = splits
            .filter { $0.isComplete }
            .map { line in
                if line.isForeignCurrency,
                   let acctCommodity = line.account?.account.commodityId {
                    // Foreign split:
                    // value    = foreignAmount × rate  (base currency)
                    // quantity = foreignAmount          (foreign currency)
                    let quantityDenom = 100 // standard; could use commodity.fraction
                    return SplitRequest(
                        accountId:     line.account!.id,
                        side:          line.side,
                        valueNum:      line.toValueNum(denom: baseDenom),
                        valueDenom:    baseDenom,
                        quantityNum:   line.toQuantityNum(quantityDenom: quantityDenom),
                        quantityDenom: quantityDenom,
                        memo:          line.memo.isEmpty ? nil : line.memo,
                        action:        nil
                    )
                } else {
                    // Same-currency split: value == quantity
                    return SplitRequest(
                        accountId:     line.account!.id,
                        side:          line.side,
                        valueNum:      line.toValueNum(denom: baseDenom),
                        valueDenom:    baseDenom,
                        quantityNum:   line.toValueNum(denom: baseDenom),
                        quantityDenom: baseDenom,
                        memo:          line.memo.isEmpty ? nil : line.memo,
                        action:        nil
                    )
                }
            }

        let request = PostTransactionRequest(
            ledgerId:            ledger.id,
            currencyCommodityId: commodityId,
            postDate:            postDate,
            enterDate:           nil,
            memo:                memo.isEmpty ? nil : memo,
            num:                 num.isEmpty  ? nil : num,
            status:              0,
            payeeId:             payeeId,
            splits:              splitRequests
        )

        do {
            _ = try await service.post(request, token: token)
            didPost = true
            NotificationCenter.default.post(name: .transactionPosted, object: ledger.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Reset

    func reset() {
        postDate           = .now
        memo               = ""
        num                = ""
        splits             = [SplitLine(), SplitLine()]
        errorMessage       = nil
        didPost            = false
        isSubmitting       = false
        accountSearchTexts = [:]
        showAccountPicker  = nil
    }

    // MARK: - Private helpers

    /// Returns the most recent price for `commodityId` priced in `currencyId`, or nil.
    private func bestRate(commodityId: UUID, currencyId: UUID) -> Decimal? {
        let match = prices
            .filter { $0.commodityId == commodityId && $0.currencyId == currencyId }
            .sorted { $0.date > $1.date }
            .first
        guard let p = match, p.valueDenom != 0 else { return nil }
        return Decimal(p.valueNum) / Decimal(p.valueDenom)
    }

    /// Formats a Decimal rate for display in the exchange rate field (4 decimal places).
    private func formatRate(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle            = .decimal
        formatter.minimumFractionDigits  = 2
        formatter.maximumFractionDigits  = 6
        return formatter.string(from: rate as NSDecimalNumber) ?? "\(rate)"
    }
}
