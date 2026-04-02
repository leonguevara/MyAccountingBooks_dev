//
//  Core/Models/Payee.swift
//  Payee.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// A payee returned by GET /ledgers/{id}/payees.
struct PayeeResponse: Codable, Identifiable, Hashable {
    let id: UUID
    let ledgerId: UUID
    let name: String
}

/// Request body for POST /payees.
struct CreatePayeeRequest: Encodable {
    let ledgerId: UUID
    let name: String
}
