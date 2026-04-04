//
//  Core/Network/APIClient.swift
//  APIClient.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-04.
//  Developed with AI assistance.
//

import Foundation

/// Lightweight HTTP client for the backend API.
///
/// Centralizes request setup — headers, bearer auth, camelCase JSON encoding/decoding with ISO 8601
/// dates — behind two entry points: ``request(_:method:body:token:)`` for responses with a body, and
/// ``requestNoContent(_:method:token:)`` for HTTP 204 endpoints. Errors are mapped to ``APIError``.
///
/// - Important: The backend must accept and return camelCase JSON keys.
/// - Note: Models should use explicit `CodingKeys` when field names deviate from camelCase.
/// - SeeAlso: ``APIEndpoint``, ``APIError``
final class APIClient {
    
    // MARK: - Properties
    
    /// Shared singleton instance.
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
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Request Method
    
    /// Performs an HTTP request and decodes the 2xx response body into `T`.
    ///
    /// Encodes `body` as camelCase JSON with ISO 8601 dates when provided. Maps non-2xx status codes
    /// to ``APIError`` (401 → `unauthorized`, 404 → `notFound`, 409 → `conflict`, other → `serverError`).
    /// Decode failures on 2xx responses throw ``APIError/decodingError(_:)``.
    ///
    /// - Parameters:
    ///   - endpoint: The ``APIEndpoint`` describing the route URL.
    ///   - method: HTTP method string (`"GET"`, `"POST"`, `"PATCH"`, `"DELETE"`). Defaults to `"GET"`.
    ///   - body: Optional `Encodable` JSON-encoded as the request body.
    ///   - token: Optional bearer token added to the `Authorization` header.
    /// - Returns: A decoded instance of `T`.
    /// - Throws: ``APIError`` for HTTP errors; ``APIError/unknown(_:)`` for network-level failures.
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
    
    /// Performs an HTTP request that expects HTTP 204 No Content; use for DELETE endpoints with no response body.
    ///
    /// Applies the same status-code mapping as ``request(_:method:body:token:)`` but returns `Void` on success.
    ///
    /// - Parameters:
    ///   - endpoint: The ``APIEndpoint`` describing the route URL.
    ///   - method: HTTP method string. Defaults to `"DELETE"`.
    ///   - token: Optional bearer token added to the `Authorization` header.
    /// - Throws: ``APIError`` for HTTP errors; ``APIError/unknown(_:)`` for network-level failures.
    func requestNoContent(
        _ endpoint: APIEndpoint,
        method: String = "DELETE",
        token: String? = nil
    ) async throws {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw APIError.unauthorized
        case 404:       throw APIError.notFound
        case 409:       throw APIError.conflict
        default:        throw APIError.serverError(http.statusCode)
        }
    }
}

