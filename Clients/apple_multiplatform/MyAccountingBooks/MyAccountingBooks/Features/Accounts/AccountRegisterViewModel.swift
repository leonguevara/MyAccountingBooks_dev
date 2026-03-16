//
//  Features/Accounts/AccountRegisterViewModel.swift
//  AccountRegisterViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
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

/// Manages state for the account register window.
///
/// Fetches all transactions for the ledger, filters to the selected account, computes
/// signed amounts based on the account's normal balance, and produces running balances
/// for display. Exposes selection state for showing transaction details and posting flows.
///
/// Usage (SwiftUI):
/// ```swift
/// @State private var vm = AccountRegisterViewModel()
/// .task { await vm.load(ledger: ledger, account: account, token: token) }
/// .sheet(isPresented: $vm.showTransactionDetail) { /* TransactionDetailSheet */ }
/// ```
@Observable
final class AccountRegisterViewModel {

    // MARK: - State

    /// The register rows to display (oldest-first for accumulation, typically rendered newest-first).
    var rows: [RegisterRow] = []
    /// Indicates whether a network operation is in progress.
    var isLoading = false
    /// An optional error message to present when operations fail.
    var errorMessage: String?
    /// The currently selected transaction for detail presentation.
    var selectedTransaction: TransactionResponse?
    /// Controls presentation of the transaction detail sheet.
    var showTransactionDetail = false
    /// Controls presentation of the post-transaction flow.
    var showPostTransaction = false

    // MARK: - Dependencies

    /// Service used to fetch transactions from the backend.
    private let service = TransactionService.shared

    // MARK: - Load

    /// Loads transactions for the ledger, filters rows to the specified account, and computes signed amounts and running balance.
    /// - Parameters:
    ///   - ledger: The ledger containing the transactions.
    ///   - account: The account whose register is being displayed.
    ///   - token: A bearer token used to authorize the request.
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
    /// Filters to transactions that include a split for the account, sorts them oldest-first
    /// to accumulate running balance, and computes signed amounts based on the account kind's
    /// normal balance (debit-positive for Assets/Expenses; credit-positive for Liabilities/Equity/Income).
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
            let raw = split.amount   // always positive rational value
            let signed: Decimal

            if debitPositive.contains(kind) {
                signed = split.side == 0 ? raw : -raw    // debit+, credit-
            } else {
                signed = split.side == 1 ? raw : -raw    // credit+, debit-
            }

            runningBalance += signed

            result.append(RegisterRow(
                id: tx.id,
                transaction: tx,
                split: split,
                accountAmount: signed,
                runningBalance: runningBalance
            ))
        }

        return result
    }
}

