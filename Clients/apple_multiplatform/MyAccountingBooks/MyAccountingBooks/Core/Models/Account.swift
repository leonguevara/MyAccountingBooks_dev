//
//  Core/Models/Account.swift
//  Account.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// Represents an account returned by the backend API.
///
/// Conformances:
/// - `Codable`: Enables JSON encoding/decoding.
/// - `Identifiable`: Supports SwiftUI list identity via `id`.
/// - `Hashable`: Required for selection and tagging in SwiftUI lists/trees; identity is based on `id`.
/// - `Equatable`: Equality is defined by `id`, matching the hashing behavior.
///
/// Example JSON response:
///
/// ```json
/// {
///   "id": "5C3A7E36-2D3B-4F10-98C4-9C9F0C2B5C61",
///   "name": "Cash",
///   "code": "1000",
///   "parentId": null,
///   "isPlaceholder": false,
///   "isHidden": false,
///   "kind": 1,
///   "accountTypeCode": "ASSET"
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let account: AccountResponse = try JSONDecoder().decode(AccountResponse.self, from: data)
/// ```
///
/// Usage (selection in a List):
///
/// ```swift
/// @State private var selected: AccountResponse?
/// let accounts: [AccountResponse] = /* decoded from API */
///
/// List(accounts, selection: $selected) { account in
///     Text(account.name)
///         .tag(account) // requires Hashable/Equatable; identity by id
/// }
/// ```
struct AccountResponse: Codable, Identifiable, Hashable, Equatable {
    /// The unique identifier of the account.
    let id: UUID
    /// The human-readable name of the account.
    let name: String
    /// Optional account code used for classification (e.g., "1000").
    let code: String?
    /// Optional identifier of the parent account, if this account is nested.
    let parentId: UUID?
    /// Whether the account is a non-posting placeholder.
    let isPlaceholder: Bool
    /// Whether the account should be hidden from standard views.
    let isHidden: Bool
    /// A numeric kind/category for the account (backend-defined enum).
    let kind: Int
    /// A code describing the account type (e.g., "ASSET", "LIABILITY").
    let accountTypeCode: String?
    
    /// Hashes the account by its unique `id` to support hashed collections and selection.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Accounts are considered equal when their `id` values match.
    static func == (lhs: AccountResponse, rhs: AccountResponse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tree Node

/// A recursive tree node built client-side from the flat API response.
///
/// Conformances:
/// - `Identifiable`: Exposes the underlying account `id`.
/// - `Hashable` and `Equatable`: Identity based on `id`, enabling use in `List`/`OutlineGroup` selections.
struct AccountNode: Identifiable, Hashable, Equatable {
    let account: AccountResponse
    var children: [AccountNode]

    var id: UUID { account.id }
    var name: String { account.name }
    var code: String? { account.code }
    var isPlaceholder: Bool { account.isPlaceholder }
    var isHidden: Bool { account.isHidden }
    var accountTypeCode: String? { account.accountTypeCode }

    /// Derived: whether this node has any children.
    var isLeaf: Bool { children.isEmpty }

    /// Derived: account kind as a readable label.
    var kindLabel: String {
        switch account.kind {
        case 1:  return "Asset"
        case 2:  return "Liability"
        case 3:  return "Equity"
        case 4:  return "Income"
        case 5:  return "Expense"
        default: return "Other"
        }
    }

    init(account: AccountResponse, children: [AccountNode] = []) {
        self.account = account
        self.children = children
    }
    
    /// Hashes the node by its `id` to align with equality and list selection semantics.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Nodes are considered equal when their `id` values match.
    static func == (lhs: AccountNode, rhs: AccountNode) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Optional Children (List helper)
    
    /// Returns children if non-empty, else `nil`.
    ///
    /// Used by `List(children:)`/`OutlineGroup` — returning `nil` indicates a leaf node (no disclosure arrow).
    var optionalChildren: [AccountNode]? {
        children.isEmpty ? nil : children
    }
}

// MARK: - Tree Builder

/// Converts a flat [AccountResponse] from the API into a [AccountNode] tree.
enum AccountTreeBuilder {

    static func build(from flat: [AccountResponse]) -> [AccountNode] {
        // Build a dictionary of id → AccountNode (no children yet)
        var nodeMap: [UUID: AccountNode] = [:]
        for account in flat {
            nodeMap[account.id] = AccountNode(account: account, children: [])
        }

        // Determine root ids (accounts with no parent, or parent not in map)
        let rootIDs = flat
            .filter { account in
                guard let parentId = account.parentId else { return true }
                return nodeMap[parentId] == nil
            }
            .map { $0.id }

        // Recursively build each root subtree
        return rootIDs
            .compactMap { nodeMap[$0] }
            .map { buildSubtree(for: $0.id, from: flat) }
            .sorted { ($0.code ?? $0.name) < ($1.code ?? $1.name) }
    }

    // MARK: - Private

    private static func buildSubtree(for id: UUID, from flat: [AccountResponse]) -> AccountNode {
        guard let account = flat.first(where: { $0.id == id }) else {
            fatalError("AccountTreeBuilder: account \(id) not found in flat list")
        }

        let children = flat
            .filter { $0.parentId == id }
            .map { buildSubtree(for: $0.id, from: flat) }
            .sorted { ($0.code ?? $0.name) < ($1.code ?? $1.name) }

        return AccountNode(account: account, children: children)
    }
}

