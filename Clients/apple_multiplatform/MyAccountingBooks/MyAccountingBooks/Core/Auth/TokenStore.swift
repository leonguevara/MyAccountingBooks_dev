//
//  Core/Auth/TokenStore.swift
//  TokenStore.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance
//

import Foundation
import Security

/// A simple Keychain-backed store for persisting an authentication token.
///
/// Uses the iOS Keychain (`kSecClassGenericPassword`) to securely save, load,
/// and delete a token (e.g., a JWT) for authenticated API requests.
final class TokenStore {
    /// Shared singleton instance for convenience.
    static let shared = TokenStore()
    /// Keychain service identifier (namespaces items for this app).
    private let service = "com.leonfelipe.MyAccountingBooks"
    /// Keychain account name used to store the token entry.
    private let account = "jwt_token"

    /// Saves or updates the token in the Keychain.
    /// - Parameter token: The token string to persist.
    ///
    /// Notes:
    /// - Existing entries for the same service/account are deleted before adding.
    /// - Uses `kSecClassGenericPassword` with the configured service/account.
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

    /// Loads the token from the Keychain if it exists.
    /// - Returns: The stored token string, or `nil` if not found.
    ///
    /// Notes:
    /// - Returns only the first match (`kSecMatchLimitOne`).
    /// - Decodes the returned data as UTF-8.
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

    /// Deletes the stored token from the Keychain, if present.
    ///
    /// Notes:
    /// - This is safe to call even if no token exists.
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

