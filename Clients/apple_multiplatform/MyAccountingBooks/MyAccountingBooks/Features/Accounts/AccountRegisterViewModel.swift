//
//  Features/Accounts/AccountRegisterViewModel.swift
//  AccountRegisterViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felie Guevara Chávez on 2026-03-30
//  Developed with AI assistance.
//

import Foundation

// MARK: - Register Row

/// A single row in the account register.
///
/// Combines a transaction header with the specific split for this account and the
/// running balance up to and including this transaction. Useful for driving a table UI
/// where each row is tappable to reveal full transaction details.
struct RegisterRow: Identifiable {
    /// Transaction identifier (mirrors `transaction.id`).
    let id: UUID                        // transaction id
    /// The full transaction associated with this row.
    let transaction: TransactionResponse
    /// The split within the transaction that belongs to the current account.
    let split: SplitResponse            // the split belonging to this account
    /// The signed amount for this account (sign derived from account kind/normal balance).
    let accountAmount: Decimal          // signed per normal balance
    /// The cumulative balance for the account up to and including this row.
    let runningBalance: Decimal         // cumulative balance to this row
}

// MARK: - ViewModel

/// Manages state for the account register screen.
///
/// Fetches all transactions for the ledger via ``TransactionService``, filters to the
/// selected account's splits, computes signed amounts based on the account's normal
/// balance, and accumulates a running balance for every row. Exposes selection state
/// for the transaction detail sheet and the post-transaction flow.
///
/// ## Usage
/// ```swift
/// @State private var vm = AccountRegisterViewModel()
/// .task { await vm.load(ledger: ledger, account: account, token: token) }
/// .sheet(isPresented: $vm.showTransactionDetail) { /* TransactionDetailSheet */ }
/// ```
///
/// - SeeAlso: ``RegisterRow``, ``AccountRegisterView``, ``TransactionService``
@Observable
final class AccountRegisterViewModel {

    // MARK: - State

    /// The register rows to display, sorted oldest-first for running-balance accumulation.
    ///
    /// Each ``RegisterRow`` carries the transaction, the account's split, the signed amount,
    /// and the cumulative balance up to that row. The UI may reverse the order for display.
    var rows: [RegisterRow] = []

    /// Indicates whether a network operation is in progress.
    ///
    /// Set to `true` at the start of ``load(ledger:account:token:)`` and cleared when
    /// it completes, regardless of success or failure.
    var isLoading = false

    /// An optional error message to present when operations fail.
    ///
    /// Set when the transaction fetch throws. Should be displayed in an alert and
    /// cleared by setting to `nil`.
    var errorMessage: String?

    /// The transaction selected by tapping a register row.
    ///
    /// Set before `showTransactionDetail` is toggled to `true` so the detail sheet
    /// has a value to display as soon as it appears.
    var selectedTransaction: TransactionResponse?

    /// Controls presentation of the transaction detail sheet.
    ///
    /// Set to `true` when the user taps a row; the sheet reads `selectedTransaction`.
    var showTransactionDetail = false

    /// Controls presentation of the post-transaction sheet.
    ///
    /// Set to `true` by the `+` toolbar button and the empty-state CTA button.
    var showPostTransaction = false

    // MARK: - Dependencies

    /// Service used to fetch transactions from the backend.
    private let service = TransactionService.shared

    // MARK: - Load

    /// Fetches all transactions for the ledger and rebuilds the register rows for the given account.
    ///
    /// Delegates to ``TransactionService/fetchTransactions(ledgerID:token:)``, then passes the
    /// result to `buildRows(transactions:accountID:kind:)` which filters, sorts, signs, and
    /// accumulates a running balance. On failure the error is written to `errorMessage` and
    /// `rows` is left unchanged.
    ///
    /// - Parameters:
    ///   - ledger: The ledger whose transactions are fetched (supplies `ledgerID`).
    ///   - account: The account whose register is being displayed (supplies `id` and `kind`).
    ///   - token: A bearer token used to authorize the request.
    /// - Note: Errors are captured in `errorMessage`; this method does not throw.
    /// - Important: Must be called from a `@MainActor` context for UI state updates.
    @MainActor
    func load(ledger: LedgerResponse, account: AccountNode, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let allTransactions = try await service.fetchTransactions(
                ledgerID: ledger.id,
                token: token
            )
            rows = Self.buildRows(
                transactions: allTransactions,
                accountID: account.id,
                kind: account.account.kind
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Row Builder

    /// Builds register rows for an account from a flat list of transactions.
    ///
    /// 1. Filters to transactions that contain a split for `accountID`.
    /// 2. Sorts oldest-first (`postDate` ascending) for running-balance accumulation.
    /// 3. Signs each amount by the account's normal balance:
    ///
    /// | `kind` values | Normal balance | Debit effect | Credit effect |
    /// |---|---|---|---|
    /// | 1 (Asset), 5 (Expense), 6 (CostOfSales) | Debit | `+` | `−` |
    /// | 2 (Liability), 3 (Equity), 4 (Income) | Credit | `−` | `+` |
    ///
    /// 4. Voided transactions contribute `signed = 0` and do **not** advance the running balance.
    ///
    /// - Parameters:
    ///   - transactions: The full ledger transaction list from ``TransactionService``.
    ///   - accountID: UUID of the account to filter splits for.
    ///   - kind: The account's `kind` integer, used to determine the normal-balance sign rule.
    /// - Returns: An array of ``RegisterRow`` values sorted oldest-first, ready for display.
    private static func buildRows(
        transactions: [TransactionResponse],
        accountID: UUID,
        kind: Int
    ) -> [RegisterRow] {

        // Filter to transactions that have a split for this account
        let relevant = transactions
            .compactMap { tx -> (TransactionResponse, SplitResponse)? in
                guard let split = tx.splits.first(where: { $0.accountId == accountID })
                else { return nil }
                return (tx, split)
            }
            // Oldest first for running balance accumulation
            .sorted { $0.0.postDate < $1.0.postDate }

        // Compute signed amount per normal balance:
        // Assets/Expenses (kind 1, 5, 6): debit = positive, credit = negative
        // Liabilities/Equity/Income (kind 2, 3, 4): credit = positive, debit = negative
        let debitPositive: Set<Int> = [1, 5, 6]  // Asset, Expense, CostOfSales

        var runningBalance: Decimal = .zero
        var result: [RegisterRow] = []

        for (tx, split) in relevant {
            let signed: Decimal

            if tx.isVoided {
                signed = .zero
            } else {
                let raw = split.amount   // always positive rational value
                if debitPositive.contains(kind) {
                    signed = split.side == 0 ? raw : -raw    // debit+, credit-
                } else {
                    signed = split.side == 1 ? raw : -raw    // credit+, debit-
                }
                runningBalance += signed    // ← only accumulate non-voided
            }

            result.append(RegisterRow(
                id: tx.id,
                transaction: tx,
                split: split,
                accountAmount: signed,      // zero for voided rows
                runningBalance: runningBalance
            ))
        }

        return result
    }
}
