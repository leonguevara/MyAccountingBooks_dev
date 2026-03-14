//
//  Features/Transactions/TransactionListViewModel.swift
//  TransactionListViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-13.
//  Developed with AI assistance
//

import Foundation

/// Manages state and business logic for the Transaction list screen.
///
/// Holds the flat list of transactions, loading/error state, search query, and a
/// toggle for showing voided transactions. Interacts with `TransactionService`
/// to load transactions for a ledger and provides filtered/grouped views for UI.
///
/// Usage (SwiftUI):
/// ```swift
/// @State private var vm = TransactionListViewModel()
/// @Environment(AuthService.self) private var auth
///
/// .task(id: ledger.id) {
///     if let token = auth.token { await vm.loadTransactions(ledgerID: ledger.id, token: token) }
/// }
/// .searchable(text: $vm.searchText)
/// ```
@Observable
final class TransactionListViewModel {

    // MARK: - State

    /// The flat list of transactions for the current ledger.
    var transactions: [TransactionResponse] = []
    /// Indicates whether a network operation is in progress.
    var isLoading = false
    /// An optional error message to present when operations fail.
    var errorMessage: String?
    /// The current search query used to filter transactions by memo, number, or split memo.
    var searchText = ""
    /// Whether to include voided transactions in results.
    var showVoided = false

    // MARK: - Dependencies

    /// Service used to fetch transactions from the backend.
    private let service = TransactionService.shared

    // MARK: - Load

    /// Loads transactions for the given ledger and updates state.
    /// - Parameters:
    ///   - ledgerID: The identifier of the ledger whose transactions to load.
    ///   - token: A bearer token used to authorize the request.
    ///
    /// Example:
    /// ```swift
    /// if let token = auth.token { await vm.loadTransactions(ledgerID: ledger.id, token: token) }
    /// ```
    @MainActor
    func loadTransactions(ledgerID: UUID, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            transactions = try await service.fetchTransactions(
                ledgerID: ledgerID,
                token: token
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Filtered Transactions

    /// Applies voided and search filters, then sorts by most recent `postDate` first.
    var filteredTransactions: [TransactionResponse] {
        var result = transactions

        // Filter voided unless explicitly shown
        if !showVoided {
            result = result.filter { !$0.isVoided }
        }

        // Search filter
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter { tx in
                (tx.memo?.lowercased().contains(query) ?? false)
                || (tx.num?.lowercased().contains(query) ?? false)
                || tx.splits.contains {
                    $0.memo?.lowercased().contains(query) ?? false
                }
            }
        }

        // Most recent first
        return result.sorted { $0.postDate > $1.postDate }
    }

    // MARK: - Grouping

    /// Groups filtered transactions by month label for sectioned display, sorted by most recent group first.
    var groupedTransactions: [(key: String, transactions: [TransactionResponse])] {
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            tx.postDate.formatted(.dateTime.month(.wide).year())
        }
        return grouped
            .map { (key: $0.key, transactions: $0.value) }
            .sorted { lhs, rhs in
                // Sort groups by the most recent transaction in each group
                let lDate = lhs.transactions.map(\.postDate).max() ?? .distantPast
                let rDate = rhs.transactions.map(\.postDate).max() ?? .distantPast
                return lDate > rDate
            }
    }
}

