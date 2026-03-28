//
//  Core/Models/Account.swift
//  Account.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felie Guevara Chávez on 2026-03-28
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
/// ## API Response Format
///
/// This structure matches the JSON response from the backend:
/// ```json
/// {
///     "id": "5C3A7E36-2D3B-4F10-98C4-9C9F0C2B5C61",
///     "name": "Cash",
///     "code": "1000",
///     "parentId": null,
///     "isPlaceholder": false,
///     "isHidden": false,
///     "kind": 1,
///     "accountTypeCode": "CASH",
///     "accountRole": 101
/// }
/// ```
///
/// ## Decoding Example
///
/// ```swift
/// let decoder = JSONDecoder()
/// decoder.keyDecodingStrategy = .convertFromSnakeCase
/// let account = try decoder.decode(AccountResponse.self, from: data)
/// ```
///
/// ## Usage in SwiftUI Selection
///
/// ```swift
/// @State private var selected: AccountResponse?
/// let accounts: [AccountResponse] = // decoded from API
///
/// List(accounts, selection: $selected) { account in
///     Text(account.name)
///         .tag(account) // requires Hashable/Equatable; identity by id
/// }
/// ```
///
/// - Important: Equality and hashing are based solely on `id`. Two accounts with the
///   same `id` but different fields are considered equal.
/// - Note: The flat list returned by the API must be assembled into a tree client-side
///   using ``AccountTreeBuilder/build(from:)``.
/// - SeeAlso: ``AccountNode``, ``AccountTreeBuilder``, ``AccountBalanceResponse``
struct AccountResponse: Codable, Identifiable, Hashable, Equatable {
    /// The unique identifier of the account.
    let id: UUID

    /// The human-readable name of the account (e.g., "Cash", "Accounts Payable").
    let name: String

    /// Optional account code used for classification and sorting (e.g., "1000").
    ///
    /// When present, the code takes precedence over `name` for ordering within
    /// the `AccountTreeBuilder` sort pass.
    let code: String?

    /// Optional identifier of the parent account, if this account is nested.
    ///
    /// A `nil` value indicates a root-level account. A value that does not match
    /// any account in the flat list is treated as a root by `AccountTreeBuilder`.
    let parentId: UUID?

    /// Whether the account is a non-posting placeholder.
    ///
    /// Placeholder accounts act as structural containers in the chart of accounts
    /// and cannot have transactions posted directly to them. Their balances are
    /// rolled up from descendant accounts by `AccountTreeViewModel`.
    let isPlaceholder: Bool

    /// Whether the account should be hidden from standard views.
    let isHidden: Bool

    /// A numeric kind/category for the account (backend-defined enum).
    ///
    /// Known values:
    /// - 1: Asset
    /// - 2: Liability
    /// - 3: Equity
    /// - 4: Income
    /// - 5: Expense
    ///
    /// Use `AccountNode.kindLabel` for a human-readable string representation.
    let kind: Int

    /// A code describing the account type (e.g., `"ASSET"`, `"LIABILITY"`).
    ///
    /// Corresponds to the `accountTypeCode` field in the backend catalog.
    let accountTypeCode: String?
    
    /// The operational role of this account within the system.
    ///
    /// Corresponds to the `accountRole` field in the backend response. The raw `Int`
    /// value maps to cases defined in ``AccountRole`` (e.g., `101` = `.bank`,
    /// `200` = `.accountsPayable`). Clients use this to apply special display or
    /// validation rules without a separate catalog lookup.
    ///
    /// - SeeAlso: ``AccountRole``
    let accountRole: Int

    /// Hashes the account by its unique `id` to support hashed collections and SwiftUI selection.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Accounts are considered equal when their `id` values match.
    static func == (lhs: AccountResponse, rhs: AccountResponse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tree Node

/// A recursive tree node built client-side from a flat `[AccountResponse]` API response.
///
/// `AccountNode` wraps an ``AccountResponse`` and adds a `children` array to represent
/// the parent-child hierarchy of the chart of accounts. Nodes are assembled by
/// ``AccountTreeBuilder/build(from:)`` and are the primary model type consumed by
/// `AccountTreeView` and `AccountTreeViewModel`.
///
/// ## Conformances
///
/// - `Identifiable`: Exposes the underlying account `id` directly for SwiftUI list identity.
/// - `Hashable` and `Equatable`: Identity based on `id`, enabling use in `List`/`OutlineGroup` selections.
///
/// ## Usage in OutlineGroup / Hierarchical List
///
/// ```swift
/// List(roots, children: \.optionalChildren) { node in
///     Label(node.name, systemImage: "folder")
/// }
/// ```
///
/// ## Accessing the Balance
///
/// Balances are not stored on the node itself. Use a balance map keyed by `node.id`
/// to look up the corresponding ``AccountBalanceResponse``:
///
/// ```swift
/// let balance = balanceMap[node.id]?.balance ?? .zero
/// ```
///
/// - Important: Equality and hashing are based solely on `id`. Mutating `children`
///   does not affect equality.
/// - Note: `optionalChildren` returns `nil` for leaf nodes so that SwiftUI's
///   `List(children:)` does not render a disclosure arrow for accounts with no children.
/// - SeeAlso: ``AccountResponse``, ``AccountTreeBuilder``, ``AccountBalanceResponse``
struct AccountNode: Identifiable, Hashable, Equatable {
    /// The underlying account data decoded from the API.
    let account: AccountResponse

    /// The child nodes of this account in the hierarchy.
    ///
    /// Empty for leaf accounts. Populated recursively by `AccountTreeBuilder`.
    var children: [AccountNode]

    /// The unique identifier of the account, forwarded from `account.id`.
    var id: UUID { account.id }

    /// The human-readable name of the account, forwarded from `account.name`.
    var name: String { account.name }

    /// The optional account code, forwarded from `account.code`.
    var code: String? { account.code }

    /// Whether the account is a non-posting placeholder, forwarded from `account.isPlaceholder`.
    var isPlaceholder: Bool { account.isPlaceholder }

    /// Whether the account should be hidden, forwarded from `account.isHidden`.
    var isHidden: Bool { account.isHidden }

    /// The account type code (e.g., `"ASSET"`), forwarded from `account.accountTypeCode`.
    var accountTypeCode: String? { account.accountTypeCode }

    /// Derived: whether this node has any children.
    ///
    /// `true` for accounts with no children (posting accounts);
    /// `false` for placeholder/parent accounts.
    var isLeaf: Bool { children.isEmpty }

    /// Derived: a human-readable label for the account kind.
    ///
    /// Maps `account.kind` to its string representation:
    ///
    /// | Kind | Label     |
    /// |------|-----------|
    /// | 1    | Asset     |
    /// | 2    | Liability |
    /// | 3    | Equity    |
    /// | 4    | Income    |
    /// | 5    | Expense   |
    /// | else | Other     |
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

    /// Creates an `AccountNode` from an `AccountResponse` with an optional set of children.
    ///
    /// - Parameters:
    ///   - account: The decoded API account this node wraps.
    ///   - children: Child nodes in the hierarchy. Defaults to an empty array (leaf node).
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

    /// Returns `children` if non-empty, otherwise `nil`.
    ///
    /// Used by `List(children:)` and `OutlineGroup` — returning `nil` signals a leaf
    /// node and suppresses the disclosure triangle in the sidebar.
    ///
    /// # Usage
    ///
    /// ```swift
    /// List(roots, children: \.optionalChildren) { node in
    ///     Text(node.name)
    /// }
    /// ```
    var optionalChildren: [AccountNode]? {
        children.isEmpty ? nil : children
    }
}

// MARK: - Tree Builder

/// Converts a flat `[AccountResponse]` array from the API into a `[AccountNode]` hierarchy.
///
/// `AccountTreeBuilder` is a namespace (caseless `enum`) that provides two related
/// operations:
/// 1. **``build(from:)``** — assembles the full account tree from a flat API response.
/// 2. **``buildPathMap(from:)``** — derives a GnuCash-style colon-separated path string
///    for every account in the tree (e.g., `"Assets:Current Assets:Cash:Checking"`).
///
/// ## How Tree Building Works
///
/// The flat list uses `parentId` references to encode hierarchy. ``build(from:)``:
/// 1. Creates a lookup dictionary (`nodeMap`) keyed by account `id`.
/// 2. Identifies root accounts — those with no `parentId`, or whose `parentId` does not
///    appear in the map.
/// 3. Recursively assembles each root's subtree via `buildSubtree(for:from:)`.
/// 4. Sorts siblings at every level by `code` (falling back to `name`).
///
/// ## Usage Example
///
/// ```swift
/// // Fetch flat account list from the API
/// let flat: [AccountResponse] = try await AccountService.shared.fetchAccounts(
///     ledgerID: ledger.id,
///     token: token
/// )
///
/// // Build the tree
/// let roots: [AccountNode] = AccountTreeBuilder.build(from: flat)
///
/// // Render in SwiftUI
/// List(roots, children: \.optionalChildren) { node in
///     Text(node.name)
/// }
/// ```
///
/// ## Path Map Example
///
/// ```swift
/// let roots = AccountTreeBuilder.build(from: flat)
/// let pathMap = AccountTreeBuilder.buildPathMap(from: roots)
///
/// // "Assets:Current Assets:Cash:Checking"
/// let path = pathMap[checkingAccountID]
/// ```
///
/// - Important: `buildSubtree(for:from:)` calls `fatalError` if an expected account ID
///   is not found in the flat list. This should never happen with a valid API response.
/// - Note: The root account (no parent) is excluded from all paths produced by
///   ``buildPathMap(from:)`` — it is a structural container whose name should not appear
///   in picker labels or breadcrumbs.
/// - SeeAlso: ``AccountNode``, ``AccountResponse``, ``AccountTreeViewModel``
enum AccountTreeBuilder {

    // MARK: - Build Tree

    /// Builds a hierarchical account tree from a flat array of API responses.
    ///
    /// Accounts are sorted at every level by `code` (ascending), falling back to `name`
    /// when `code` is `nil`.
    ///
    /// - Parameter flat: The flat array of ``AccountResponse`` values returned by the API.
    /// - Returns: An array of root ``AccountNode`` values, each with its full subtree populated.
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

    // MARK: - Full Path Map

    /// Builds a flat dictionary mapping each account UUID to its full colon-separated path string.
    ///
    /// Path strings follow the GnuCash convention — account names are joined with `":"`,
    /// building a breadcrumb-style label for use in pickers, search results, and
    /// accessibility descriptions.
    ///
    /// The root account is excluded from all paths: its name is structural and should not
    /// appear in user-facing labels.
    ///
    /// ## Example
    ///
    /// Given the hierarchy:
    /// ```
    /// Root
    /// └── Assets
    ///     └── Current Assets
    ///         └── Cash
    ///             └── Checking
    /// ```
    ///
    /// The path for *Checking* is `"Assets:Current Assets:Cash:Checking"`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let roots = AccountTreeBuilder.build(from: flat)
    /// let pathMap = AccountTreeBuilder.buildPathMap(from: roots)
    ///
    /// // Display in a picker
    /// ForEach(accounts) { account in
    ///     Text(pathMap[account.id] ?? account.name)
    ///         .tag(account)
    /// }
    /// ```
    ///
    /// - Parameter roots: The top-level nodes produced by ``build(from:)``.
    /// - Returns: A `[UUID: String]` dictionary mapping every non-root account ID to its full path.
    /// - Note: Root nodes (top-level entries in `roots`) are skipped; their immediate children
    ///   begin the path at depth 1.
    /// - SeeAlso: ``build(from:)``, ``AccountNode``
    static func buildPathMap(from roots: [AccountNode]) -> [UUID: String] {
        var map: [UUID: String] = [:]
        for root in roots {
            // Skip the root node itself — its name ("Raíz") should not
            // appear in any account's path since it is structural only.
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
        let currentPath = parentPath.isEmpty
            ? node.name
            : "\(parentPath):\(node.name)"

        map[node.id] = currentPath

        for child in node.children {
            buildPaths(node: child, parentPath: currentPath, map: &map)
        }
    }

    // MARK: - Private

    /// Recursively builds the subtree rooted at the given account ID.
    ///
    /// Finds all direct children of `id` in `flat`, builds their subtrees recursively,
    /// and returns a fully populated ``AccountNode``. Siblings are sorted by `code`,
    /// falling back to `name`.
    ///
    /// - Parameters:
    ///   - id: The UUID of the account to build a subtree for.
    ///   - flat: The complete flat list of ``AccountResponse`` values from the API.
    /// - Returns: An ``AccountNode`` with all descendant nodes populated.
    /// - Precondition: `id` must exist in `flat`; a `fatalError` is raised otherwise.
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
