//
//  Core/Network/APIClient.swift
//  APIClient.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import Foundation

/// A lightweight HTTP client for interacting with the backend API.
///
/// `APIClient` centralizes request setup — headers, authentication, JSON encoding/decoding —
/// behind a single generic ``request(_:method:body:token:)`` entry point.
///
/// ## Features
/// - Singleton via ``shared`` for consistent configuration across the app
/// - Generic `async/await` interface returning any `Decodable` response type
/// - Bearer token authentication via the `Authorization` header
/// - camelCase JSON with ISO 8601 dates; no snake_case conversion
/// - Typed error mapping via ``APIError`` (401, 404, 409, 5xx, decode failures)
///
/// ## Usage
///
/// ```swift
/// // GET — no body, no token
/// let ledgers: [LedgerResponse] = try await APIClient.shared.request(.listLedgers)
///
/// // POST — body + auth token
/// let created: LedgerResponse = try await APIClient.shared.request(
///     .createLedger,
///     method: "POST",
///     body: CreateLedgerBody(name: "Household"),
///     token: auth.token
/// )
/// ```
///
/// - Important: The backend must accept and return camelCase JSON keys.
/// - Note: All models should use explicit `CodingKeys` when field names deviate from camelCase.
/// - SeeAlso: ``APIEndpoint``, ``APIError``
final class APIClient {
    
    // MARK: - Properties
    
    /// Shared singleton instance providing consistent API client configuration throughout the app.
    static let shared = APIClient()
    
    /// The underlying `URLSession` used for all network requests.
    private let session = URLSession.shared

    /// JSON decoder shared across all responses; configured for ISO 8601 dates in ``init()``.
    private let decoder = JSONDecoder()

    // MARK: - Initialization
    
    /// Configures the decoder with ISO 8601 date decoding.
    ///
    /// - Note: Private to enforce singleton usage via ``shared``.
    private init() {
        // Keys are expected in camelCase format
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Request Method
    
    /// Performs an HTTP request to the specified endpoint and decodes the response into `T`.
    ///
    /// Builds a `URLRequest`, optionally encodes `body` as JSON, attaches the bearer token,
    /// executes the request, maps the HTTP status to an ``APIError``, then decodes the
    /// response body into `T`.
    ///
    /// ## Status Code Mapping
    ///
    /// | Status | Throws |
    /// |---|---|
    /// | 2xx | — (decodes into `T`) |
    /// | 401 | ``APIError/unauthorized`` |
    /// | 404 | ``APIError/notFound`` |
    /// | 409 | ``APIError/conflict`` |
    /// | other | ``APIError/serverError(_:)`` with the status code |
    ///
    /// Decode failures on 2xx responses throw ``APIError/decodingError(_:)`` to surface
    /// API contract mismatches immediately.
    ///
    /// - Parameters:
    ///   - endpoint: The ``APIEndpoint`` describing the route URL.
    ///   - method: HTTP method string (`"GET"`, `"POST"`, `"PUT"`, `"DELETE"`). Defaults to `"GET"`.
    ///   - body: Optional `Encodable` to JSON-encode as the request body (camelCase, ISO 8601 dates).
    ///   - token: Optional bearer token added to the `Authorization` header.
    /// - Returns: A decoded instance of `T` from the successful response body.
    /// - Throws: ``APIError`` for all failure cases; network errors wrap as ``APIError/unknown(_:)``.
    /// - Note: Must be called from an `async` context.
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
            // Keys are encoded in camelCase format (no conversion to snake_case)
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
        case 409: throw APIError.conflict
        default:  throw APIError.serverError(http.statusCode)
        }
    }
}

