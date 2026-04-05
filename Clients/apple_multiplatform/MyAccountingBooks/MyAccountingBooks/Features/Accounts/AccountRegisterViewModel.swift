//
//  Features/Accounts/AccountRegisterViewModel.swift
//  AccountRegisterViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
//  Developed with AI assistance.
//

import Foundation

// MARK: - Register Row

/// A single row in the account register.
struct RegisterRow: Identifiable {
    let id:             UUID
    let transaction:    TransactionResponse
    let split:          SplitResponse
    /// Signed amount in the **account's display currency**:
    /// - Native currency (quantity) for foreign-currency accounts
    /// - Base currency (value) for same-currency accounts
    let accountAmount:  Decimal
    /// Cumulative balance in the account's display currency.
    let runningBalance: Decimal
}

// MARK: - ViewModel

/// Manages state for the account register screen.
///
/// ## Multi-currency behaviour
///
/// When the account's `commodityId` differs from the ledger's `currencyCommodityId`,
/// the register displays amounts in the account's **native currency** using
/// `split.quantityAmount` instead of `split.amount`. The running balance is
/// accumulated in the same native currency.
///
/// The `isForeignCurrency` flag on this view model is read by ``AccountRegisterView``
/// to select the correct currency code and decimal places for formatting.
///
/// - SeeAlso: ``RegisterRow``, ``AccountRegisterView``, ``TransactionService``
@Observable
final class AccountRegisterViewModel {

    // MARK: - State

    var rows:         [RegisterRow] = []
    var isLoading     = false
    var errorMessage: String?

    var selectedTransaction:  TransactionResponse?
    var showTransactionDetail = false
    var showPostTransaction   = false

    /// True when the current account's commodity differs from the ledger's base currency.
    /// Read by the view to choose the correct currency code for amount formatting.
    var isForeignCurrency = false

    // MARK: - Dependencies

    private let service = TransactionService.shared

    // MARK: - Load

    /// Fetches all transactions for the ledger and builds register rows for the account.
    ///
    /// Sets ``isForeignCurrency`` based on whether `account.account.commodityId` differs
    /// from `ledger.currencyCommodityId`. When true, `buildRows` uses `quantityAmount`
    /// (native currency) instead of `amount` (base currency) for each split.
    @MainActor
    func load(ledger: LedgerResponse, account: AccountNode, token: String) async {
        isLoading = true
        errorMessage = nil

        // Determine currency mode once, before building rows.
        let accountCommodity = account.account.commodityId
        let ledgerCommodity  = ledger.currencyCommodityId
        isForeignCurrency = accountCommodity != nil
                         && ledgerCommodity  != nil
                         && accountCommodity != ledgerCommodity

        do {
            let allTransactions = try await service.fetchTransactions(
                ledgerID: ledger.id,
                token: token
            )
            rows = Self.buildRows(
                transactions:     allTransactions,
                accountID:        account.id,
                kind:             account.account.kind,
                isForeignCurrency: isForeignCurrency
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Row Builder

    /// Builds register rows for an account from a flat transaction list.
    ///
    /// When `isForeignCurrency` is true, uses `split.quantityAmount` (native currency)
    /// for both the signed amount and the running balance. Otherwise uses `split.amount`
    /// (base currency).
    ///
    /// Normal-balance sign rules:
    /// - Assets / Expenses (kind 1, 5, 6): debit = positive, credit = negative
    /// - Liabilities / Equity / Income (kind 2, 3, 4): credit = positive, debit = negative
    private static func buildRows(
        transactions:      [TransactionResponse],
        accountID:         UUID,
        kind:              Int,
        isForeignCurrency: Bool
    ) -> [RegisterRow] {

        let relevant = transactions
            .compactMap { tx -> (TransactionResponse, SplitResponse)? in
                guard let split = tx.splits.first(where: { $0.accountId == accountID })
                else { return nil }
                return (tx, split)
            }
            .sorted { $0.0.postDate < $1.0.postDate }

        let debitPositive: Set<Int> = [1, 5, 6]

        var runningBalance: Decimal = .zero
        var result: [RegisterRow] = []

        for (tx, split) in relevant {
            let signed: Decimal

            if tx.isVoided {
                signed = .zero
            } else {
                // Use native currency (quantity) for foreign accounts,
                // base currency (value) for same-currency accounts.
                let raw = isForeignCurrency ? split.quantityAmount : split.amount

                if debitPositive.contains(kind) {
                    signed = split.side == 0 ? raw : -raw
                } else {
                    signed = split.side == 1 ? raw : -raw
                }
                runningBalance += signed
            }

            result.append(RegisterRow(
                id:             tx.id,
                transaction:    tx,
                split:          split,
                accountAmount:  signed,
                runningBalance: runningBalance
            ))
        }

        return result
    }
}
