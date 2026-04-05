//
//  Core/Models/Account.swift
//  Account.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
//  Developed with AI assistance.
//

import Foundation

// MARK: - API Response

/// Represents an account returned by the backend API.
///
/// `AccountResponse` is a value type that maps directly to the JSON payload from
/// `GET /ledgers/{id}/accounts`. It is the atomic unit of the chart of accounts and is
/// used as the source of truth when building the client-side account tree.
///
/// ## Conformances
///
/// - `Codable`: Enables JSON encoding/decoding via the standard `JSONDecoder`.
/// - `Identifiable`: Supports SwiftUI list identity via `id`.
/// - `Hashable`: Required for selection and tagging in SwiftUI `List`/`OutlineGroup`; identity is based on `id`.
/// - `Equatable`: Equality is defined by `id`, matching the hashing behavior.
///
/// - Important: Equality and hashing are based solely on `id`.
/// - Note: The flat list returned by the API must be assembled into a tree client-side
///   using ``AccountTreeBuilder/build(from:)``.
/// - SeeAlso: ``AccountNode``, ``AccountTreeBuilder``, ``AccountBalanceResponse``
struct AccountResponse: Codable, Identifiable, Hashable, Equatable {
    let id:              UUID
    let name:            String
    let code:            String?
    let parentId:        UUID?
    let isPlaceholder:   Bool
    let isHidden:        Bool
    let kind:            Int
    let accountTypeCode: String?
    let accountRole:     Int
    /// The commodity (currency) assigned to this account.
    /// Nil if the backend has not yet been updated to return this field,
    /// or if no explicit commodity is assigned.
    let commodityId:     UUID?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AccountResponse, rhs: AccountResponse) -> Bool { lhs.id == rhs.id }
}

// MARK: - Tree Node

/// A recursive tree node built client-side from a flat `[AccountResponse]` API response.
///
/// - SeeAlso: ``AccountResponse``, ``AccountTreeBuilder``, ``AccountBalanceResponse``
struct AccountNode: Identifiable, Hashable, Equatable {
    let account:  AccountResponse
    var children: [AccountNode]

    var id:              UUID    { account.id }
    var name:            String  { account.name }
    var code:            String? { account.code }
    var isPlaceholder:   Bool    { account.isPlaceholder }
    var isHidden:        Bool    { account.isHidden }
    var accountTypeCode: String? { account.accountTypeCode }
    var isLeaf:          Bool    { children.isEmpty }

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
        self.account  = account
        self.children = children
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AccountNode, rhs: AccountNode) -> Bool { lhs.id == rhs.id }

    var optionalChildren: [AccountNode]? { children.isEmpty ? nil : children }
}

// MARK: - Tree Builder

/// Converts a flat `[AccountResponse]` array from the API into a `[AccountNode]` hierarchy.
///
/// - SeeAlso: ``AccountNode``, ``AccountResponse``, ``AccountTreeViewModel``
enum AccountTreeBuilder {

    static func build(from flat: [AccountResponse]) -> [AccountNode] {
        var nodeMap: [UUID: AccountNode] = [:]
        for account in flat {
            nodeMap[account.id] = AccountNode(account: account, children: [])
        }
        let rootIDs = flat
            .filter { account in
                guard let parentId = account.parentId else { return true }
                return nodeMap[parentId] == nil
            }
            .map { $0.id }
        return rootIDs
            .compactMap { nodeMap[$0] }
            .map { buildSubtree(for: $0.id, from: flat) }
            .sorted { ($0.code ?? $0.name) < ($1.code ?? $1.name) }
    }

    static func buildPathMap(from roots: [AccountNode]) -> [UUID: String] {
        var map: [UUID: String] = [:]
        for root in roots {
            for child in root.children {
                buildPaths(node: child, parentPath: "", map: &map)
            }
        }
        return map
    }

    private static func buildPaths(
        node: AccountNode,
        parentPath: String,
        map: inout [UUID: String]
    ) {
        let currentPath = parentPath.isEmpty ? node.name : "\(parentPath):\(node.name)"
        map[node.id] = currentPath
        for child in node.children {
            buildPaths(node: child, parentPath: currentPath, map: &map)
        }
    }

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
