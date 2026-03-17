//
//  Core/Models/Ledger.swift
//  Ledger.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// A ledger model used throughout the app and decoded from API responses.
///
/// Conformances:
/// - `Codable`: Enables JSON encoding/decoding.
/// - `Identifiable`: Supports SwiftUI list identity via `id`.
/// - `Hashable`: Required for selection and tagging in SwiftUI lists and sets; identity is based on `id`.
/// - `Equatable`: Equality is defined by `id`, matching the hashing behavior.

/// Represents a ledger returned by the backend API.
///
/// Conforms to `Identifiable` for convenient use in SwiftUI lists, and `Codable`
/// for JSON encoding/decoding.
///
/// Example JSON response:
///
/// ```json
/// {
///   "id": "4E0B6C9E-2B6B-4C2E-9B8B-3E7B1A2D8F10",
///   "name": "Household",
///   "currencyCode": "USD",
///   "decimalPlaces": 2,
///   "currencyCommodityId": "F0BD9093-F03C-4FD6-87A9-4F8920EF372B",
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let ledger: LedgerResponse = try JSONDecoder().decode(LedgerResponse.self, from: data)
/// ```
struct LedgerResponse: Codable, Identifiable, Hashable, Equatable {
    /// The unique identifier of the ledger.
    let id: UUID
    /// The human-readable name of the ledger.
    let name: String
    /// The ISO 4217 currency code used by this ledger (e.g., "USD").
    let currencyCode: String
    /// The number of decimal places used for monetary amounts.
    let decimalPlaces: Int
    /// The unique identifier of the currency
    let currencyCommodityId: UUID?
    
    /// Hashes the essential components of this value by feeding them into the given hasher.
    ///
    /// Identity is defined by the ledger's unique `id`, which allows this type to be used in
    /// hashed collections and supports selection in `List` with `selection:`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Returns a Boolean value indicating whether two ledgers are considered equal.
    ///
    /// Equality is based solely on the unique `id`, matching the hashing behavior.
    static func == (lhs: LedgerResponse, rhs: LedgerResponse) -> Bool {
        lhs.id == rhs.id
    }
}

/// The payload for creating a new ledger via the API.
///
/// Encoded as JSON when sent in a POST request.
///
/// Example JSON payload:
///
/// ```json
/// {
///   "name": "Household",
///   "currencyMnemonic": "USD",
///   "decimalPlaces": 2,
///   "coaTemplateCode": "basic",
///   "coaTemplateVersion": "2024.1"
/// }
/// ```
///
/// Encoding example:
///
/// ```swift
/// let body = CreateLedgerRequest(
///     name: "Household",
///     currencyMnemonic: "USD",
///     decimalPlaces: 2,
///     coaTemplateCode: "basic",
///     coaTemplateVersion: "2024.1"
/// )
/// let encoder = JSONEncoder()
/// encoder.keyEncodingStrategy = .convertToSnakeCase
/// encoder.dateEncodingStrategy = .iso8601
/// let payload = try encoder.encode(body)
/// ```
struct CreateLedgerRequest: Codable {
    /// The desired name for the new ledger.
    let name: String
    /// A short currency mnemonic (e.g., "USD") to initialize the ledger.
    let currencyMnemonic: String
    /// The number of decimal places to use for amounts in this ledger.
    let decimalPlaces: Int
    /// Optional: A chart-of-accounts template code to pre-populate accounts.
    var coaTemplateCode: String?
    /// Optional: The version of the chart-of-accounts template.
    var coaTemplateVersion: String?
}

