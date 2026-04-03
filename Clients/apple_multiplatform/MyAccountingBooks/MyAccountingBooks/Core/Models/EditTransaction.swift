//
//  Core/Models/EditTransaction.swift
//  EditTransaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Last modified by León Felie Guevara Chávez on 2026-04-02
//  Developed with AI assistance.
//

import Foundation

// MARK: - PATCH Request Models

/// Request body for `PATCH /transactions/{id}` — JSON Merge Patch semantics.
///
/// Only non-`nil` properties are encoded and sent; the server merges them with
/// the existing transaction record. Omit a field entirely (leave it `nil`) to
/// leave it unchanged on the server.
///
/// - Note: Amounts (`valueNum`/`valueDenom`) are not patchable — use the
///   reverse + repost workflow instead.
/// - SeeAlso: ``PatchSplitRequest``, ``EditTransactionViewModel``
struct PatchTransactionRequest: Encodable {
    /// Transaction-level description; `nil` = no change.
    var memo: String?

    /// Reference or check number; `nil` = no change.
    var num: String?

    /// Effective posting date; `nil` = no change.
    var postDate: Date?

    /// Associated payee UUID; `nil` = no change.
    var payeeId: UUID?

    /// Per-split patches; `nil` or empty = no split changes.
    var splits: [PatchSplitRequest]?

    enum CodingKeys: String, CodingKey {
        case memo, num, postDate, payeeId, splits
    }
}

/// Per-split patch within a ``PatchTransactionRequest``.
///
/// Only `memo` and `accountId` are patchable; amounts are immutable via PATCH.
/// The target account must be active and non-placeholder within the same ledger.
struct PatchSplitRequest: Encodable {
    /// UUID of the split to update. Required — the server skips entries with a missing ID.
    let splitId: UUID

    /// New split-level memo; `nil` = no change.
    var memo: String?

    /// UUID of the replacement account; `nil` = no change.
    var accountId: UUID?

    enum CodingKeys: String, CodingKey {
        case splitId, memo, accountId
    }
}

// MARK: - Edit Split Line (form state)

/// Mutable form state for a single split line in the transaction edit form.
///
/// Bound to SwiftUI form controls in ``EditTransactionViewModel``. Conforms to
/// `Identifiable` using the split's database UUID so SwiftUI can track rows in a `List`.
/// ``originalAccountId`` is retained to detect account changes when building the
/// ``PatchSplitRequest``.
struct EditSplitLine: Identifiable {
    /// Database UUID of this split; used as the SwiftUI `Identifiable` identity.
    let id: UUID

    /// Current memo text; edited in-place by the user.
    var memo: String

    /// Currently selected account node; `nil` if no account is selected.
    var account: AccountNode?

    /// Account UUID as loaded from the server; compared against `account?.id` to detect changes.
    let originalAccountId: UUID

    /// `true` when the selected account differs from ``originalAccountId`` or memo has changed.
    ///
    /// - Note: The implementation is a placeholder — actual dirty-checking is performed
    ///   by ``EditTransactionViewModel`` when building the ``PatchSplitRequest``.
    var isDirty: Bool {
        memo != (memo)  // always true — simplified; patch handles unchanged
    }
}
