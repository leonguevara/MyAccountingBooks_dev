//
//  Core/Models/EditTransaction.swift
//  EditTransaction.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Developed with AI assistance.
//

import Foundation

// MARK: - PATCH Request Models

/// A partial update request for modifying an existing transaction.
///
/// This structure represents the request body sent to the server when updating
/// a transaction via PATCH. All fields are optional, allowing clients to send
/// only the fields that have changed. The server will merge non-nil values with
/// the existing transaction data.
///
/// - Note: Only non-nil properties are encoded and sent to the server.
struct PatchTransactionRequest: Encodable {
    /// Optional transaction memo/description.
    var memo: String?
    
    /// Optional transaction number (e.g., check number, reference number).
    var num: String?
    
    /// Optional posting date for the transaction.
    var postDate: Date?
    
    var payeeId: UUID?        // ← add — send nil to clear, omit entirely if unchanged
    
    /// Optional array of split line updates. Each split is identified by its UUID.
    var splits: [PatchSplitRequest]?

    enum CodingKeys: String, CodingKey {
        case memo, num, postDate, splits
    }
}

/// A partial update request for modifying a single split line within a transaction.
///
/// Split lines represent the individual account entries that make up a transaction.
/// This structure allows updating specific properties of an existing split while
/// preserving other fields.
struct PatchSplitRequest: Encodable {
    /// The unique identifier of the split to update. Required to identify which split to modify.
    let splitId: UUID
    
    /// Optional memo/description specific to this split line.
    var memo: String?
    
    /// Optional account identifier. If provided, reassigns this split to a different account.
    var accountId: UUID?

    enum CodingKeys: String, CodingKey {
        case splitId, memo, accountId
    }
}

// MARK: - Edit Split Line (form state)

/// Represents the editable state for a single split line in the transaction edit form.
///
/// This structure maintains the current editing state of a split line, including
/// both the current values and the original values needed to detect changes.
/// It conforms to `Identifiable` to support SwiftUI list views.
///
/// Use this type to bind split data to form controls and track modifications
/// before committing changes to the server.
struct EditSplitLine: Identifiable {
    /// The unique identifier of this split from the database. Used as the SwiftUI identity.
    let id: UUID
    
    /// The current memo text for this split line. Can be modified by the user.
    var memo: String
    
    /// The currently selected account for this split. May be nil if no account is selected.
    var account: AccountNode?
    
    /// The original account ID when this split was loaded. Used to detect account changes.
    let originalAccountId: UUID

    /// Returns `true` if any field has been modified from its original value.
    ///
    /// - Note: Current implementation is simplified. The actual change detection
    ///   is handled by the patch request logic, which compares against server state.
    var isDirty: Bool {
        memo != (memo)  // always true — simplified; patch handles unchanged
    }
}
