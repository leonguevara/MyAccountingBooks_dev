//
//  Features/Accounts/AccountRegisterWindowPayload.swift
//  AccountRegisterWindowPayload.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import Foundation

/// Value passed to the WindowGroup that opens an account register.
/// Must be Hashable and Codable for SwiftUI window management.
///
/// Usage:
/// ```swift
/// @Environment(\.openWindow) private var openWindow
/// openWindow(value: AccountRegisterWindowPayload(ledger: ledger, account: node))
/// ```
///
/// In your app scene:
/// ```swift
/// WindowGroup(for: AccountRegisterWindowPayload.self) { payload in
///     // Reconstruct or look up the full AccountNode by `payload.account.id` if needed
///     AccountRegisterView(
///         ledger: payload.ledger,
///         account: AccountNode(account: AccountResponse(
///             id: payload.account.id,
///             name: payload.account.name,
///             code: payload.account.code,
///             parentId: nil,
///             isPlaceholder: payload.account.isPlaceholder,
///             isHidden: payload.account.isHidden,
///             kind: payload.account.kind,
///             accountTypeCode: payload.account.accountTypeCode
///         ))
///     )
/// }
/// ```
struct AccountRegisterWindowPayload: Hashable, Codable {
    let ledger: LedgerResponse
    let account: LedgerAccountPayload

    /// Encodes a minimal, codable account projection to satisfy window scene value constraints.
    init(ledger: LedgerResponse, account: AccountNode) {
        self.ledger = ledger
        self.account = LedgerAccountPayload(node: account)
    }
}

/// Codable representation of AccountNode for window passing.
///
/// `AccountNode` may contain non-codable references or recursive children; this
/// payload projects only the necessary fields to identify and render the account
/// in a new window scene. Use `id` to look up the full node if needed.
struct LedgerAccountPayload: Hashable, Codable {
    let id: UUID
    let name: String
    let code: String?
    let accountTypeCode: String?
    let kind: Int
    let isPlaceholder: Bool
    let isHidden: Bool

    /// Copies only the identifying and display fields from the node.
    init(node: AccountNode) {
        self.id              = node.id
        self.name            = node.name
        self.code            = node.code
        self.accountTypeCode = node.accountTypeCode
        self.kind            = node.account.kind
        self.isPlaceholder   = node.isPlaceholder
        self.isHidden        = node.isHidden
    }
}

