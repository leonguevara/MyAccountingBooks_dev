//
//  Core/Models/Account.swift
//  Account.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// Represents an account returned by the backend API.
///
/// Conforms to `Identifiable` for convenient use in SwiftUI lists, and `Codable`
/// for JSON encoding/decoding.
///
/// Example JSON response:
///
/// ```json
/// {
///   "id": "5C3A7E36-2D3B-4F10-98C4-9C9F0C2B5C61",
///   "name": "Cash",
///   "code": "1000",
///   "parentId": null,
///   "isPlaceholder": false,
///   "isHidden": false,
///   "kind": 1,
///   "accountTypeCode": "ASSET"
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let account: AccountResponse = try JSONDecoder().decode(AccountResponse.self, from: data)
/// ```
struct AccountResponse: Codable, Identifiable {
    /// The unique identifier of the account.
    let id: UUID
    /// The human-readable name of the account.
    let name: String
    /// Optional account code used for classification (e.g., "1000").
    let code: String?
    /// Optional identifier of the parent account, if this account is nested.
    let parentId: UUID?
    /// Whether the account is a non-posting placeholder.
    let isPlaceholder: Bool
    /// Whether the account should be hidden from standard views.
    let isHidden: Bool
    /// A numeric kind/category for the account (backend-defined enum).
    let kind: Int
    /// A code describing the account type (e.g., "ASSET", "LIABILITY").
    let accountTypeCode: String
}
