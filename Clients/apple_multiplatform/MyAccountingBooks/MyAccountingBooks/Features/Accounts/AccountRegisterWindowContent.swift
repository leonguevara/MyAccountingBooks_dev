//
//  Features/Accounts/AccountRegisterWindowContent.swift
//  AccountRegisterWindowContent.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04
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
/// - SeeAlso: ``AccountRegisterWindowPayload``, ``AccountRegisterView``, ``AccountNode``
struct AccountRegisterWindowContent: View {

    let payload: AccountRegisterWindowPayload
    @Environment(AuthService.self) private var auth

    var body: some View {
        NavigationStack {
            AccountRegisterView(
                ledger:  payload.ledger,
                account: reconstructedNode
            )
            .environment(auth)
        }
    }

    /// Reconstructs a minimal ``AccountNode`` from the window payload.
    ///
    /// - `parentId` is `nil` — not needed by the register view.
    /// - `accountRole` is `0` — not used by the register view.
    /// - `commodityId` is `nil` — not needed for register display.
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
            accountRole:     0,
            commodityId:     nil        // ← not needed for register display
        )
        return AccountNode(account: response, children: [])
    }
}
