//
//  Features/Accounts/AccountRegisterWindowContent.swift
//  AccountRegisterWindowContent.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import SwiftUI

/// Bridges AccountRegisterWindowPayload → AccountRegisterView.
/// Reconstructs a minimal AccountNode from the Codable payload and forwards
/// `AuthService` from the environment to the register view.
///
/// This view is typically presented by the WindowGroup that handles
/// `AccountRegisterWindowPayload` values.
struct AccountRegisterWindowContent: View {

    let payload: AccountRegisterWindowPayload
    @Environment(AuthService.self) private var auth

    /// Presents AccountRegisterView inside a NavigationStack and injects `AuthService`.
    var body: some View {
        NavigationStack {
            AccountRegisterView(
                ledger: payload.ledger,
                account: reconstructedNode
            )
            .environment(auth)
        }
    }

    /// Reconstructs a minimal AccountNode from the payload for use in the register.
    /// Children are intentionally empty; the register does not require hierarchy.
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
            accountTypeCode: p.accountTypeCode
        )
        return AccountNode(account: response, children: [])
    }
}

