//
//  Features/Accounts/AccountTreeViewModel.swift
//  AccountTreeViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-12.
//  Developed with AI assistance.
//

import Foundation

/// Manages state and business logic for the Account Tree screen.
///
/// Holds the root account nodes, loading/error state, and search query. Interacts
/// with `AccountService` to load a flat list of accounts and builds a tree using
/// `AccountTreeBuilder`. Provides a filtered view of the tree when searching.
///
/// Usage (SwiftUI):
/// ```swift
/// @State private var vm = AccountTreeViewModel()
/// @Environment(AuthService.self) private var auth
///
/// .task(id: ledger.id) {
///     if let token = auth.token { await vm.loadAccounts(ledgerID: ledger.id, token: token) }
/// }
/// .searchable(text: $vm.searchText)
/// ```
@Observable
final class AccountTreeViewModel {

    // MARK: - State

    /// Root nodes of the account tree.
    var roots: [AccountNode] = []
    /// Indicates whether a network operation is in progress.
    var isLoading = false
    /// An optional error message to present when operations fail.
    var errorMessage: String?
    /// The current search query used to filter the account tree.
    var searchText = ""
    private var loadedLedgerID: UUID?

    // MARK: - Dependencies

    /// Service used to fetch accounts from the backend.
    private let service = AccountService.shared

    // MARK: - Load

    /// Loads accounts for the given ledger, builds the tree, and updates state.
    /// - Parameters:
    ///   - ledgerID: The identifier of the ledger whose accounts to load.
    ///   - token: A bearer token used to authorize the request.
    ///
    /// Example:
    /// ```swift
    /// if let token = auth.token { await vm.loadAccounts(ledgerID: ledger.id, token: token) }
    /// ```
    @MainActor
    func loadAccounts(ledgerID: UUID, token: String) async {
        guard loadedLedgerID != ledgerID else { return }   // ← prevent duplicate loads
        isLoading = true
        errorMessage = nil
        do {
            let flat = try await service.fetchAccounts(ledgerID: ledgerID, token: token)
            roots = AccountTreeBuilder.build(from: flat)
            loadedLedgerID = ledgerID      // ← mark as loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Filtered Roots

    /// Returns filtered roots when `searchText` has content; otherwise returns `roots`.
    var filteredRoots: [AccountNode] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return roots
        }
        return filterNodes(roots, query: searchText.lowercased())
    }

    // MARK: - Private Helpers

    /// Recursively filters the account tree, preserving full subtrees for matching nodes
    /// and including proxy nodes for parents of matching descendants.
    private func filterNodes(_ nodes: [AccountNode], query: String) -> [AccountNode] {
        var results: [AccountNode] = []
        for node in nodes {
            let matchesSelf = node.name.lowercased().contains(query)
                || (node.code?.lowercased().contains(query) ?? false)
                || (node.accountTypeCode?.lowercased().contains(query) ?? false)

            let filteredChildren = filterNodes(node.children, query: query)

            if matchesSelf {
                // Include node with all its children intact
                results.append(node)
            } else if !filteredChildren.isEmpty {
                // Include node as a container for matching children
                let proxy = AccountNode(account: node.account, children: filteredChildren)
                results.append(proxy)
            }
        }
        return results
    }
}

