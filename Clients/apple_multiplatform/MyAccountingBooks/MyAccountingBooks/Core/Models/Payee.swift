//
//  Core/Models/Payee.swift
//  Payee.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Payee record returned by `GET /ledgers/{id}/payees` and `POST /payees`.
///
/// Conforms to `Identifiable` (via `id`) for use in SwiftUI lists and
/// `Hashable` for use in `Set` or as a `Picker` selection value.
struct PayeeResponse: Codable, Identifiable, Hashable {
    /// Unique identifier of the payee record.
    let id: UUID
    /// UUID of the ledger this payee belongs to.
    let ledgerId: UUID
    /// Display name of the payee; unique within its ledger.
    let name: String
}

/// Request body for `POST /payees`.
///
/// The `(ledgerId, name)` combination must be unique within the ledger;
/// a duplicate triggers HTTP 409.
struct CreatePayeeRequest: Encodable {
    /// UUID of the ledger to create the payee in.
    let ledgerId: UUID
    /// Display name of the new payee; must be non-blank and unique per ledger.
    let name: String
}
