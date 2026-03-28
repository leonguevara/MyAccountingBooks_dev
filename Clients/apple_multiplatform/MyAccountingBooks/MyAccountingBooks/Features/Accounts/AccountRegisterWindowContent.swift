//
//  Features/Accounts/AccountRegisterWindowContent.swift
//  AccountRegisterWindowContent.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felie Guevara Chávez on 2026-03-28
//  Developed with AI assistance.
//

import SwiftUI

/// A thin bridge that connects an ``AccountRegisterWindowPayload`` to ``AccountRegisterView``.
///
/// `AccountRegisterWindowContent` is the view registered under the
/// `WindowGroup(for: AccountRegisterWindowPayload.self)` scene. Its sole responsibility is to:
///
/// 1. Reconstruct a minimal ``AccountNode`` from the ``AccountFormPayload`` stored in the window payload.
/// 2. Forward the ``AuthService`` instance from the SwiftUI environment into ``AccountRegisterView``.
/// 3. Wrap the register view in a `NavigationStack`.
///
/// The reconstructed node is intentionally minimal — `children` is always empty and
/// `accountRole` is always `0` (``AccountRole/unspecified``) because the register view
/// uses the node only for display and balance queries, not for operational role logic.
///
/// ## Window Registration
///
/// ```swift
/// WindowGroup(for: AccountRegisterWindowPayload.self) { $payload in
///     if let payload {
///         AccountRegisterWindowContent(payload: payload)
///     }
/// }
/// ```
///
/// - SeeAlso: ``AccountRegisterWindowPayload``, ``AccountRegisterView``, ``AccountNode``
struct AccountRegisterWindowContent: View {

    let payload: AccountRegisterWindowPayload
    @Environment(AuthService.self) private var auth

    /// Wraps ``AccountRegisterView`` in a `NavigationStack` and injects ``AuthService`` from the environment.
    var body: some View {
        NavigationStack {
            AccountRegisterView(
                ledger: payload.ledger,
                account: reconstructedNode
            )
            .environment(auth)
        }
    }

    /// Reconstructs a minimal ``AccountNode`` from the window payload for use in ``AccountRegisterView``.
    ///
    /// The node is built from the ``AccountFormPayload`` stored in ``AccountRegisterWindowPayload/account``.
    /// Two fields are deliberately simplified:
    ///
    /// - `parentId` is set to `nil` — the register view only needs the account itself, not its position in the hierarchy.
    /// - `accountRole` is set to `0` (``AccountRole/unspecified``) — the register view queries balances and
    ///   displays entries but never branches on operational role.
    ///
    /// - Returns: An ``AccountNode`` with an empty `children` array and the fields above hardcoded.
    private var reconstructedNode: AccountNode {
        let p = payload.account
        let response = AccountResponse(
            id:              p.id,
            name:            p.name,
            code:            p.code,
            parentId:        nil,
            isPlaceholder:   p.isPlaceholder,
            isHidden:        p.isHidden,
            kind:            p.kind,
            accountTypeCode: p.accountTypeCode,
            accountRole:     0
        )
        return AccountNode(account: response, children: [])
    }
}

