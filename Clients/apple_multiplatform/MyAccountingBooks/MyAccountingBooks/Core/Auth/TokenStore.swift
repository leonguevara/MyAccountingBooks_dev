//
//  Core/Auth/TokenStore.swift
//  TokenStore.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance
//

import Foundation
import Security

/// A secure Keychain-backed store for persisting and validating JWT authentication tokens.
///
/// `TokenStore` wraps `Security.framework` Keychain APIs behind three simple operations —
/// ``save(_:)``, ``load()``, ``delete()`` — and adds client-side JWT expiry detection via
/// ``isTokenValid`` so expired tokens are caught before a network request is issued.
///
/// ## API Surface
///
/// | Member | Description |
/// |---|---|
/// | ``save(_:)`` | Write a new JWT to the Keychain (replaces any existing entry) |
/// | ``load()`` | Read the stored JWT; `nil` if absent or unreadable |
/// | ``delete()`` | Remove the stored JWT; safe to call when nothing is stored |
/// | ``isTokenValid`` | `true` when a token exists and its `exp` claim is in the future |
///
/// ## Token Validation
/// `isTokenValid` decodes the JWT payload (base64url → JSON), extracts the `exp` Unix
/// timestamp, and compares it against `Date()` — no network call required. Any decode
/// failure (malformed JWT, missing `exp`) is treated as expired.
///
/// - Important: Only the `exp` claim is checked; the token signature is **not** verified client-side.
/// - Note: JWT decoding is performed without cryptographic verification of the signature.
/// - SeeAlso: ``AuthService``, ``APIClient``
final class TokenStore {
    // MARK: - Properties
    
    /// Shared singleton instance.
    static let shared = TokenStore()

    /// Keychain `kSecAttrService` value that scopes the entry to this app.
    private let service = "com.leonguevara.MyAccountingBooks"

    /// Keychain `kSecAttrAccount` value that identifies the JWT entry within the service.
    private let account = "jwt_token"
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton usage.
    private init() {}
    
    // MARK: - Token Storage Operations
    
    /// Writes the JWT to the Keychain, replacing any previously stored token.
    ///
    /// The existing entry (if any) is deleted with `SecItemDelete` before the new
    /// value is added with `SecItemAdd`, avoiding duplicate-item errors.
    ///
    /// - Parameter token: The JWT string to persist (UTF-8 encoded before storage).
    /// - Note: Does not validate token format or expiry before saving.
    func save(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Reads the stored JWT from the Keychain.
    ///
    /// - Returns: The JWT string, or `nil` if no entry is found or the raw data cannot
    ///   be decoded as a UTF-8 string.
    /// - Note: Does not check expiry; use ``isTokenValid`` to confirm the token is still valid.
    /// - SeeAlso: ``isTokenValid``
    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Removes the stored JWT from the Keychain.
    ///
    /// Safe to call when no token is stored — `SecItemDelete` returns silently
    /// if no matching entry exists.
    ///
    /// - Important: Call this on logout to ensure stale credentials are not reused.
    ///   A new token must be obtained via ``AuthService/login(email:password:)`` or
    ///   ``AuthService/register(email:password:displayName:)``.
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - JWT Expiry Validation
    
    /// `true` when a token exists in the Keychain and its `exp` claim is in the future.
    ///
    /// Returns `false` when no token is stored, the JWT structure is malformed, the
    /// payload cannot be base64url-decoded, the `exp` claim is absent, or the token
    /// has already expired.
    ///
    /// - Important: Validates only the `exp` claim — does not verify the token signature.
    /// - Note: Expiry is compared against `Date()`; accurate device time is required.
    /// - SeeAlso: ``load()``
    var isTokenValid: Bool {
        guard let token = load() else { return false }
        return !isExpired(token)
    }
    
    /// Returns `true` when the JWT has expired or cannot be decoded; `false` when still valid.
    ///
    /// Decoding steps: split on `"."`, base64url-decode the payload segment
    /// (replace `-`/`_`, add `=` padding), deserialize as JSON, read the `exp`
    /// Unix timestamp, and compare against `Date()`.
    ///
    /// Any failure in the decode chain — wrong number of segments, bad base64,
    /// non-JSON payload, missing or non-numeric `exp` — is treated as expired.
    ///
    /// - Parameter token: The JWT string to inspect.
    /// - Returns: `true` if expired or invalid; `false` if the `exp` claim is in the future.
    /// - Important: Does not verify the token signature or any other claim.
    /// - Warning: A malformed `exp` field causes this method to return `true` (expired).
    private func isExpired(_ token: String) -> Bool {
        // JWT structure: header.payload.signature (base64url-encoded parts)
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        
        // Decode the payload (second part) from base64url
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Pad to a multiple of 4 — required by base64 spec
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp  = json["exp"] as? TimeInterval
        else { return true }
        
        // exp is Unix timestamp in seconds
        return Date(timeIntervalSince1970: exp) <= Date()
    }
}
