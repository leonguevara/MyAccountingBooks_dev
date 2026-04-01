//
//  Core/Network/APIError.swift
//  APIError.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-09.
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import Foundation

/// Typed errors produced by ``APIClient`` for all network and decoding failures.
///
/// Each case maps to a distinct failure mode. ``errorDescription`` provides a
/// human-readable string (via `LocalizedError`) suitable for alert messages.
/// ``map(statusCode:underlying:)`` converts an HTTP status code to the matching
/// case, returning `nil` for 2xx success responses.
///
/// - SeeAlso: ``APIClient``, ``APIEndpoint``
enum APIError: Error, LocalizedError {
    /// The URL could not be constructed from the given ``APIEndpoint``.
    case invalidURL

    /// HTTP 401 — credentials missing or invalid; the user must log in again.
    case unauthorized

    /// HTTP 404 — the requested resource does not exist.
    case notFound

    /// HTTP 409 — the request conflicts with existing data (e.g. duplicate email on registration).
    case conflict

    /// Any other non-2xx response.
    /// - Parameter code: The HTTP status code returned by the server.
    case serverError(Int)

    /// The response body could not be decoded into the expected model.
    /// - Parameter error: The underlying `DecodingError`.
    case decodingError(Error)

    /// A network-layer or other unexpected error not covered by the cases above.
    /// - Parameter error: The underlying error from `URLSession` or another source.
    case unknown(Error)

    /// Human-readable description for use in alert messages (`LocalizedError`).
    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL."
        case .unauthorized:          return "Authentication required."
        case .notFound:              return "Resource not found."
        case .serverError(let code): return "Server error: \(code)."
        case .decodingError(let e):  return "Decoding error: \(e.localizedDescription)"
        case .unknown(let e):        return e.localizedDescription
        case .conflict:              return "Conflicted credentilas"
        }
    }
    
    /// Converts an HTTP status code to the matching ``APIError`` case, or `nil` for 2xx responses.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code from `HTTPURLResponse`.
    ///   - underlying: Optional lower-level error; wrapped as ``unknown(_:)`` for unrecognised codes.
    /// - Returns: The corresponding ``APIError``, or `nil` when `statusCode` is in `200..<300`.
    static func map(statusCode: Int, underlying: Error? = nil) -> APIError? {
        switch statusCode {
        case 200..<300:
            return nil
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 400..<600:
            return .serverError(statusCode)
        default:
            return underlying.map { .unknown($0) } ?? .serverError(statusCode)
        }
    }
}

