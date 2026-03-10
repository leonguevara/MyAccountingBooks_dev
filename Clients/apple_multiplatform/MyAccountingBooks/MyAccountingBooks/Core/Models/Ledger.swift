//
//  Core/Models/Ledger.swift
//  Ledger.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

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
///   "decimalPlaces": 2
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let ledger: LedgerResponse = try JSONDecoder().decode(LedgerResponse.self, from: data)
/// ```
struct LedgerResponse: Codable, Identifiable {
    /// The unique identifier of the ledger.
    let id: UUID
    /// The human-readable name of the ledger.
    let name: String
    /// The ISO 4217 currency code used by this ledger (e.g., "USD").
    let currencyCode: String
    /// The number of decimal places used for monetary amounts.
    let decimalPlaces: Int
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
