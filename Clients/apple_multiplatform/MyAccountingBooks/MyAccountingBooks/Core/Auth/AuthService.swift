//
//  Core/Auth/AuthService.swift
//  AuthService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/// An observable authentication service that manages login state and token storage.
///
/// Uses `APIClient` to authenticate with the backend and `TokenStore` to persist
/// the received token securely in the Keychain. Publishes `isAuthenticated` for
/// UI updates.
///
/// Usage (SwiftUI):
///
/// ```swift
/// @State private var email = ""
/// @State private var password = ""
/// @State private var auth = AuthService()
///
/// var body: some View {
///     VStack {
///         if auth.isAuthenticated {
///             Text("Welcome!")
///             Button("Logout") { auth.logout() }
///         } else {
///             TextField("Email", text: $email)
///                 .textContentType(.username)
///                 .textInputAutocapitalization(.never)
///                 .autocorrectionDisabled()
///             SecureField("Password", text: $password)
///             Button("Login") {
///                 Task { try? await auth.login(email: email, password: password) }
///             }
///         }
///     }
/// }
/// ```
@Observable
final class AuthService {
    /// Indicates whether the user is currently authenticated.
    var isAuthenticated = false
    /// The current bearer token, if available, loaded from the Keychain.
    var token: String? { TokenStore.shared.load() }

    /// Initializes the service and derives the initial authentication state from the stored token.
    init() {
        isAuthenticated = token != nil
    }

    /// Authenticates the user with the backend and persists the returned token.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Throws: `APIError` for known API failures or other errors from the network layer.
    func login(email: String, password: String) async throws {
        let response: TokenResponse = try await APIClient.shared.request(
            .login,
            method: "POST",
            body: LoginRequest(email: email, password: password)
        )
        TokenStore.shared.save(response.token)
        isAuthenticated = true
    }

    /// Logs the user out by deleting the stored token and updating authentication state.
    func logout() {
        TokenStore.shared.delete()
        isAuthenticated = false
    }
}

