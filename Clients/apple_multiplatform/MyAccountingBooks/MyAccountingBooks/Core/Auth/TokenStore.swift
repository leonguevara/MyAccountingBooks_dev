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

/**
 A secure Keychain-backed store for persisting and validating authentication tokens.
 
 `TokenStore` provides a simple interface for storing JWT authentication tokens securely
 in the system Keychain, along with client-side validation of token expiry. This ensures
 that expired tokens are detected before making network requests.
 
 # Features
 - **Secure Storage**: Uses iOS/macOS Keychain (`kSecClassGenericPassword`) for token persistence
 - **Save/Load/Delete**: Simple CRUD operations for token management
 - **JWT Expiry Validation**: Client-side expiry checking without network calls
 - **Singleton Pattern**: Shared instance for consistent access across the app
 
 # Token Validation
 The store can decode JWT tokens and validate their expiry by:
 1. Parsing the JWT structure (header.payload.signature)
 2. Base64url-decoding the payload
 3. Extracting the `exp` (expiration) claim
 4. Comparing against the current time
 
 This allows the app to proactively detect expired tokens and refresh them before
 making authenticated API requests, reducing failed request attempts.
 
 # Usage Example
 ```swift
 // Save a token after successful login
 TokenStore.shared.save(jwtToken)
 
 // Check if token exists and is valid
 if TokenStore.shared.isTokenValid {
     // Proceed with authenticated request
     let accounts = try await APIClient.shared.request(.accounts, token: token)
 } else {
     // Prompt user to sign in again
     showLoginScreen()
 }
 
 // Load the token for API requests
 if let token = TokenStore.shared.load() {
     let response = try await APIClient.shared.request(.endpoint, token: token)
 }
 
 // Delete token on sign out
 TokenStore.shared.delete()
 ```
 
 # Security Considerations
 - Tokens are stored in the system Keychain with service identifier namespacing
 - Keychain data is encrypted by the OS and tied to the app's identity
 - Token expiry is validated client-side to minimize exposure of expired credentials
 - The store does not perform token refresh; that must be handled by the auth service
 
 - Important: This store does not validate token signatures or claims other than expiry.
 - Note: JWT decoding is done client-side without cryptographic verification.
 - SeeAlso: `AuthService`, `APIClient`
 */
final class TokenStore {
    // MARK: - Properties
    
    /// Shared singleton instance providing consistent token storage across the app.
    ///
    /// Use this instance to access all token storage operations. The singleton pattern
    /// ensures that all parts of the app reference the same token state.
    static let shared = TokenStore()
    
    /// Keychain service identifier that namespaces token entries for this app.
    ///
    /// This service identifier prevents conflicts with other apps' Keychain items
    /// and groups all tokens under a common namespace.
    private let service = "com.leonguevara.MyAccountingBooks"
    
    /// Keychain account name used to identify the token entry.
    ///
    /// Combined with the service identifier, this uniquely identifies the stored token.
    private let account = "jwt_token"
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton usage.
    private init() {}
    
    // MARK: - Token Storage Operations
    
    /**
     Saves or updates the authentication token in the Keychain.
     
     This method stores the token securely using the system Keychain. If a token already
     exists for the configured service and account, it will be deleted first to ensure
     the new token replaces it.
     
     - Parameter token: The JWT token string to persist in the Keychain.
     
     # Implementation Details
     - Converts the token string to UTF-8 encoded `Data`
     - Uses `kSecClassGenericPassword` for the Keychain item type
     - Deletes any existing token before adding the new one to avoid duplicate item errors
     - Saves using the configured `service` and `account` identifiers
     
     # Usage
     ```swift
     // Save token after successful login
     TokenStore.shared.save(jwtToken)
     ```
     
     - Note: This method does not validate the token format or expiry before saving.
     - Important: Always use this method after successful authentication to persist credentials.
     */
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
    
    /**
     Loads the authentication token from the Keychain if it exists.
     
     Retrieves the stored token string from the Keychain using the configured service
     and account identifiers. If no token is found, returns `nil`.
     
     - Returns: The stored JWT token string, or `nil` if no token exists or if decoding fails.
     
     # Implementation Details
     - Queries Keychain with `kSecMatchLimitOne` to return only the first match
     - Retrieves the raw data using `kSecReturnData`
     - Decodes the data as a UTF-8 string
     - Returns `nil` if the query fails or if data cannot be decoded
     
     # Usage
     ```swift
     // Load token for API request
     if let token = TokenStore.shared.load() {
         let response = try await APIClient.shared.request(.endpoint, token: token)
     } else {
         // No token available, show login screen
         showLoginScreen()
     }
     ```
     
     - Note: This method does not validate token expiry; use `isTokenValid` for validation.
     - SeeAlso: `isTokenValid`
     */
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
    
    /**
     Deletes the stored authentication token from the Keychain.
     
     Removes the token entry from the Keychain if it exists. This method is safe to call
     even if no token is currently stored.
     
     # Implementation Details
     - Uses `SecItemDelete` to remove the Keychain entry
     - Matches the configured `service` and `account` identifiers
     - Silently succeeds if no token exists (no error thrown)
     
     # Usage
     ```swift
     // Delete token on sign out
     TokenStore.shared.delete()
     
     // Confirm deletion
     assert(TokenStore.shared.load() == nil, "Token should be deleted")
     ```
     
     - Important: Always call this method when the user signs out to prevent stale credentials.
     - Note: This operation cannot be undone; the token must be obtained again through authentication.
     */
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - JWT Expiry Validation
    
    /**
     Indicates whether a stored token exists and has not expired.
     
     This computed property performs client-side validation of the stored JWT token
     by checking both its existence and expiry status. The validation is performed
     without making any network requests.
     
     - Returns: `true` if a valid, non-expired token exists; `false` otherwise.
     
     # Validation Process
     1. Checks if a token exists in the Keychain
     2. Decodes the JWT payload (base64url-encoded)
     3. Extracts the `exp` (expiration) claim
     4. Compares expiration time against the current time
     
     # Usage
     ```swift
     // Check before making authenticated requests
     if TokenStore.shared.isTokenValid {
         // Token exists and is not expired
         let data = try await APIClient.shared.request(.endpoint, token: token)
     } else {
         // Token is missing or expired - require re-authentication
         showLoginScreen()
     }
     ```
     
     # Expiry Detection
     Returns `false` in these scenarios:
     - No token is stored
     - Token format is invalid (not a valid JWT)
     - Token payload cannot be decoded
     - Token has expired (current time >= expiration time)
     
     - Important: This only validates the `exp` claim; it does not verify signatures or other claims.
     - Note: Token expiry is checked in local time; ensure device time is accurate.
     - SeeAlso: `isExpired(_:)`
     */
    var isTokenValid: Bool {
        guard let token = load() else { return false }
        return !isExpired(token)
    }
    
    /**
     Determines if a JWT token has expired by examining its `exp` claim.
     
     This private method decodes the JWT payload and validates the expiration timestamp
     against the current time. It performs client-side validation without cryptographic
     verification of the token signature.
     
     - Parameter token: The JWT token string to validate.
     
     - Returns: `true` if the token has expired or is invalid; `false` if still valid.
     
     # JWT Decoding Process
     
     1. **Split token**: Separates the three JWT parts (header.payload.signature)
     2. **Extract payload**: Takes the second part containing claims
     3. **Base64url decode**: Converts from base64url to standard base64
        - Replaces `-` with `+`
        - Replaces `_` with `/`
        - Adds padding (`=`) to make length a multiple of 4
     4. **Parse JSON**: Deserializes the payload as a JSON object
     5. **Extract `exp`**: Gets the expiration timestamp (Unix epoch seconds)
     6. **Compare time**: Checks if expiration time <= current time
     
     # Return Values
     
     Returns `true` (expired/invalid) when:
     - Token doesn't have exactly 3 parts (invalid JWT structure)
     - Payload cannot be base64url-decoded
     - Payload is not valid JSON
     - `exp` claim is missing or not a number
     - Current time >= expiration time
     
     Returns `false` (valid) when:
     - Token is properly formatted AND
     - Payload is successfully decoded AND
     - `exp` claim exists AND
     - Current time < expiration time
     
     # Example
     ```swift
     let jwt = "eyJhbGc...header.eyJleH...payload.signature"
     
     if isExpired(jwt) {
         // Token has expired, refresh needed
         refreshToken()
     } else {
         // Token is still valid, proceed with request
         makeAuthenticatedRequest(jwt)
     }
     ```
     
     - Important: This method does not verify the token signature or issuer claims.
     - Note: Assumes the `exp` claim is in standard Unix timestamp format (seconds since epoch).
     - Warning: If the payload contains an invalid `exp` format, the token is considered expired.
     */
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
