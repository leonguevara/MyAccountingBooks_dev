//
//  Core/Network/APIClient.swift
//  APIClient.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// A lightweight HTTP client for interacting with the backend API.
///
/// `APIClient` centralizes common request setup (base decoding strategies,
/// headers, auth token handling) and returns decoded models from the server.
///
/// Usage:
///
/// ```swift
/// struct Ledger: Decodable { let id: UUID; let name: String }
///
/// // Fetch all ledgers
/// let ledgers: [Ledger] = try await APIClient.shared.request(.listLedgers)
///
/// // Create a ledger with a POST body and an auth token
/// struct CreateLedgerBody: Encodable { let name: String }
/// let created: Ledger = try await APIClient.shared.request(
///     .createLedger,
///     method: "POST",
///     body: CreateLedgerBody(name: "Household"),
///     token: myAuthToken
/// )
/// ```
///
/// Mapping HTTP(S) responses and errors:
///
/// ```swift
/// do {
///     let accounts: [Account] = try await APIClient.shared.request(.accounts(ledgerID: id))
///     // success
/// } catch let apiError as APIError {
///     // Present a friendly message
///     print(apiError.errorDescription ?? "Unknown error")
/// } catch {
///     // Non-APIError fallback
///     print(error.localizedDescription)
/// }
/// ```
final class APIClient {
    /// Shared singleton instance for convenience.
    static let shared = APIClient()
    /// Backing URLSession used to perform requests.
    private let session = URLSession.shared
    /// JSON decoder configured for common API conventions.
    private let decoder = JSONDecoder()

    /// Initializes the client with default decoding strategies.
    private init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Performs an HTTP request to the given endpoint and decodes the response into `T`.
    ///
    /// - Parameters:
    ///   - endpoint: The `APIEndpoint` describing the route and URL.
    ///   - method: The HTTP method (e.g., `"GET"`, `"POST"`). Defaults to `"GET"`.
    ///   - body: An optional `Encodable` body. If provided, it is JSON-encoded with snake_case keys and ISO8601 dates.
    ///   - token: An optional bearer token added to the `Authorization` header.
    /// - Returns: A decoded instance of `T`.
    /// - Throws: `APIError` for known API failures (unauthorized, not found, server errors, decoding errors),
    ///           or other errors thrown by `URLSession`.
    ///
    /// Usage:
    /// ```swift
    /// struct Transaction: Decodable { /* ... */ }
    /// let txs: [Transaction] = try await APIClient.shared.request(.transactions(ledgerID: id))
    /// ```
    ///
    /// Guidance on mapping HTTP responses:
    ///
    /// This method interprets 2xx as success and decodes `T`. It maps common status codes to
    /// `APIError` (401 → `.unauthorized`, 404 → `.notFound`, other 4xx/5xx → `.serverError(code)`).
    /// If decoding fails on a 2xx response, it throws `.decodingError` with the underlying error.
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        method: String = "GET",
        body: Encodable? = nil,
        token: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:  throw APIError.serverError(http.statusCode)
        }
    }
}

