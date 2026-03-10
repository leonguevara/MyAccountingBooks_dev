//
//  Core/Network/APIEndpoint.swift
//  APIEndpoint.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// Describes backend API endpoints and constructs concrete URLs for requests.
///
/// `APIEndpoint` centralizes the path logic for each route and provides a
/// single source of truth for building request URLs based on a common `baseURL`.
/// Adjust `baseURL` to point to your staging/production server as needed.
///
/// Usage:
///
/// ```swift
/// // Build a URL for logging in
/// let loginURL = APIEndpoint.login.url
///
/// // Build a URL for accounts under a ledger
/// let ledgerID = UUID()
/// let accountsURL = APIEndpoint.accounts(ledgerID: ledgerID).url
///
/// // Create a URLRequest using the endpoint
/// var request = URLRequest(url: APIEndpoint.listLedgers.url)
/// request.httpMethod = "GET"
/// request.addValue("application/json", forHTTPHeaderField: "Accept")
/// ```
///
/// Mapping HTTP(S) responses in context of an endpoint:
///
/// ```swift
/// let endpoint = APIEndpoint.transactions(ledgerID: ledgerID)
/// let (data, response) = try await URLSession.shared.data(for: URLRequest(url: endpoint.url))
/// if let http = response as? HTTPURLResponse {
///     switch http.statusCode {
///     case 200..<300:
///         // decode data for this endpoint
///         break
///     case 401:
///         // e.g., refresh credentials or surface unauthorized state
///         break
///     case 404:
///         // endpoint-specific handling (e.g., ledger no longer exists)
///         break
///     default:
///         // general error handling
///         break
///     }
/// }
/// ```
enum APIEndpoint {
    /// The base URL for all API requests. Change to your staging/production host.
    static let baseURL = URL(string: "http://localhost:8080")!

    // Auth
    /// Authentication endpoint for user login.
    case login

    // Ledgers
    /// Retrieves all ledgers accessible to the current user.
    case listLedgers
    /// Creates a new ledger.
    case createLedger

    // Accounts
    /// Retrieves accounts for a given ledger.
    /// - Parameter ledgerID: The identifier of the ledger.
    case accounts(ledgerID: UUID)

    // Transactions
    /// Retrieves transactions for a given ledger.
    /// - Parameter ledgerID: The identifier of the ledger.
    case transactions(ledgerID: UUID)
    /// Creates a new transaction.
    case postTransaction
    /// Reverses a previously posted transaction.
    /// - Parameter id: The unique identifier of the transaction to reverse.
    case reverseTransaction(id: UUID)
    /// Voids a previously posted transaction.
    /// - Parameter id: The unique identifier of the transaction to void.
    case voidTransaction(id: UUID)

    // Commodities
    /// Retrieves commodities, optionally filtering by a namespace.
    /// - Parameter namespace: A string to filter commodities by namespace. Pass `nil` for all.
    case commodities(namespace: String?)

    /// The fully-qualified URL for the endpoint, derived from `baseURL` and path components.
    var url: URL {
        switch self {
        case .login:
            return Self.baseURL.appendingPathComponent("auth/login")
        case .listLedgers, .createLedger:
            return Self.baseURL.appendingPathComponent("ledgers")
        case .accounts(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/accounts")
        case .transactions(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/transactions")
        case .postTransaction:
            return Self.baseURL.appendingPathComponent("transactions")
        case .reverseTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/reverse")
        case .voidTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/void")
        case .commodities(let ns):
            var components = URLComponents(url: Self.baseURL.appendingPathComponent("commodities"), resolvingAgainstBaseURL: false)!
            if let ns { components.queryItems = [URLQueryItem(name: "namespace", value: ns)] }
            return components.url!
        }
    }
}
