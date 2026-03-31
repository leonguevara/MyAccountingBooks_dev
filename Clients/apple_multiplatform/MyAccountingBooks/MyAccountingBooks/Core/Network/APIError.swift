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

/// A type that represents errors that can occur when interacting with the app's networking layer.
///
/// `APIError` provides a concise set of cases that map common failure scenarios
/// such as invalid URLs, authentication problems, not found responses, server-side
/// failures, and decoding issues.
///
/// You can surface user-friendly messages via `LocalizedError` conformance using
/// `errorDescription`.
///
/// Usage:
///
/// ```swift
/// // Mapping a URL string to a URL or returning an error
/// guard let url = URL(string: urlString) else { throw APIError.invalidURL }
///
/// // Handling decoding failures
/// do {
///     let model = try JSONDecoder().decode(MyModel.self, from: data)
/// } catch {
///     throw APIError.decodingError(error)
/// }
///
/// // Surfacing a user-friendly message
/// func presentError(_ error: Error) {
///     let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
///     // showAlert(message)
/// }
/// ```
///
/// Mapping HTTP responses to `APIError`:
///
/// ```swift
/// if let http = response as? HTTPURLResponse {
///     switch http.statusCode {
///     case 200..<300:
///         break // success
///     case 401:
///         throw APIError.unauthorized
///     case 404:
///         throw APIError.notFound
///     case 400..<600:
///         throw APIError.serverError(http.statusCode)
///     default:
///         break
///     }
/// }
/// ```
enum APIError: Error, LocalizedError {
    /// The constructed URL is invalid or cannot be formed.
    case invalidURL
    
    /// The request requires authentication or the provided credentials are invalid.
    case unauthorized
    
    /// The requested resource could not be found (typically HTTP 404).
    case notFound
    
    /// The server responded with an error status code.
    /// - Parameter code: The HTTP status code returned by the server.
    case serverError(Int)
    
    /// Decoding of the response payload failed.
    /// - Parameter error: The underlying decoding error.
    case decodingError(Error)
    
    /// An unexpected error occurred that does not match other cases.
    /// - Parameter error: The underlying error.
    case unknown(Error)
    
    case conflict

    /// A human-readable description of the error suitable for displaying to users.
    ///
    /// Provided by `LocalizedError`.
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
    
    /// Maps an HTTP status code and optional underlying error to an `APIError` when appropriate.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code from `HTTPURLResponse`.
    ///   - underlying: An optional lower-level error from URLSession or decoding.
    /// - Returns: An `APIError` representing the condition, or `nil` for success codes (2xx).
    ///
    /// Example:
    /// ```swift
    /// let http = try #require(response as? HTTPURLResponse)
    /// if let apiError = APIError.map(statusCode: http.statusCode, underlying: error) {
    ///     throw apiError
    /// }
    /// ```
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

