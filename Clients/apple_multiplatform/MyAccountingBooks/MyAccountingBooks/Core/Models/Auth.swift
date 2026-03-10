//
//  Core/Models/Auth.swift
//  Auth.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// The payload used to authenticate a user with the backend API.
///
/// Example JSON payload:
///
/// ```json
/// {
///   "email": "user@example.com",
///   "password": "super-secret"
/// }
/// ```
///
/// Encoding example:
///
/// ```swift
/// let body = LoginRequest(email: "user@example.com", password: "super-secret")
/// let encoder = JSONEncoder()
/// encoder.keyEncodingStrategy = .convertToSnakeCase
/// encoder.dateEncodingStrategy = .iso8601
/// let payload = try encoder.encode(body)
/// ```
struct LoginRequest: Codable {
    /// The user's email address used for login.
    let email: String
    /// The user's password.
    let password: String
}

/// The token returned by the backend upon successful authentication.
///
/// Example JSON response:
///
/// ```json
/// {
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "ownerID": "4E0B6C9E-2B6B-4C2E-9B8B-3E7B1A2D8F10"
/// }
/// ```
///
/// Decoding example:
///
/// ```swift
/// let token: TokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
/// ```
struct TokenResponse: Codable {
    /// The bearer token used to authenticate subsequent API requests.
    let token: String
    /// The identifier of the authenticated user or owning entity.
    let ownerID: UUID
}
