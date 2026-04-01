//
//  Core/Auth/AuthService.swift
//  AuthService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-01.
//  Developed with AI assistance.
//

import Foundation

/// An observable authentication service managing login state, token storage, and validation.
///
/// `AuthService` coordinates the complete authentication lifecycle including login, logout,
/// registration, token persistence, and automatic expiry detection. It uses ``TokenStore``
/// for secure Keychain storage and ``APIClient`` for backend authentication requests.
///
/// ## Features
/// - **Login / Logout / Register**: Authenticates owners and manages session state
/// - **Token Management**: Securely stores JWT tokens in the Keychain via ``TokenStore``
/// - **Expiry Detection**: Validates tokens on app launch and on every `token` access
/// - **Observable State**: Publishes `isAuthenticated` for reactive SwiftUI updates
/// - **Session Cleanup**: Clears the last-selected ledger from ``SessionStore`` on logout
///
/// ## Token Validation
/// - **On app launch** (`init`): expired or missing tokens are deleted immediately and
///   `isAuthenticated` is set to `false` so the login screen appears without a failed API call.
/// - **On access** (`token`): returns `nil` for expired tokens — callers guard against `nil`
///   before issuing network requests.
/// - **On logout**: token and session data are cleared together.
///
/// ## Usage Example
///
/// ```swift
/// @State private var auth = AuthService()
///
/// var body: some View {
///     Group {
///         if auth.isAuthenticated {
///             ContentView().environment(auth)
///         } else {
///             LoginView().environment(auth)
///         }
///     }
/// }
/// ```
///
/// **Making authenticated requests:**
/// ```swift
/// @Environment(AuthService.self) private var auth
///
/// func loadData() async {
///     guard let token = auth.token else { return }
///     let accounts: [AccountResponse] = try await APIClient.shared.request(
///         .accounts(ledgerID: ledgerID), token: token
///     )
/// }
/// ```
///
/// - Important: Always read `auth.token` rather than loading directly from ``TokenStore``
///   to ensure expiry is checked on every access.
/// - Note: This class uses the `@Observable` macro for SwiftUI state management.
/// - SeeAlso: ``TokenStore``, ``SessionStore``, ``APIClient``, ``TokenResponse``
@Observable
final class AuthService {
    
    // MARK: - State
    
    /// Whether the user is currently authenticated with a valid token.
    ///
    /// Set to `true` by ``login(email:password:)`` and ``register(email:password:displayName:)``
    /// on success, and by `init()` when a non-expired token is found in the Keychain.
    /// Set to `false` by ``logout()`` and by `init()` when no valid token exists.
    ///
    /// SwiftUI views that read this property update automatically when it changes.
    var isAuthenticated = false
    
    /// The current bearer token for authenticated API requests, or `nil` if unavailable.
    ///
    /// Checks ``TokenStore`` on every access — returns the stored JWT only when
    /// `TokenStore.shared.isTokenValid` is `true`. Returns `nil` when:
    /// - No token is stored in the Keychain
    /// - The stored token has expired
    /// - The token format is unreadable
    ///
    /// Always guard against `nil` before issuing network requests:
    /// ```swift
    /// guard let token = auth.token else { return }
    /// let data = try await APIClient.shared.request(.someEndpoint, token: token)
    /// ```
    ///
    /// - Important: Validation runs on every access; assign to a local constant when
    ///   making several requests in the same scope.
    /// - Note: Expiry is checked client-side by decoding the JWT — no network call required.
    /// - SeeAlso: ``TokenStore``
    var token: String? {
        TokenStore.shared.isTokenValid ? TokenStore.shared.load() : nil
    }
    
    /// The UUID of the currently authenticated owner, populated after a successful
    /// ``login(email:password:)`` or ``register(email:password:displayName:)`` call.
    ///
    /// Set to `nil` by ``logout()``. Not persisted across app launches — derived
    /// from the ``TokenResponse`` returned by the backend on each authentication.
    var currentOwnerID: UUID? = nil
    
    // MARK: - Init

    /// Initializes the service and restores authentication state from the Keychain.
    ///
    /// Checks ``TokenStore`` on launch and takes one of two paths:
    ///
    /// - **Valid token found**: sets `isAuthenticated = true`; the user proceeds
    ///   directly to authenticated screens.
    /// - **Token missing or expired**: deletes the stale token from the Keychain,
    ///   clears the last-selected ledger from ``SessionStore``, and sets
    ///   `isAuthenticated = false` so the login screen appears immediately.
    ///
    /// ## Example
    /// ```swift
    /// @main
    /// struct MyAccountingBooksApp: App {
    ///     @State private var auth = AuthService()
    ///
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             if auth.isAuthenticated {
    ///                 ContentView()
    ///             } else {
    ///                 LoginView()
    ///             }
    ///         }
    ///         .environment(auth)
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Expiry is detected at launch, not on the first API call, preventing
    ///   any network requests with a stale token.
    /// - Note: The last-selected ledger is cleared when the token is found to be expired,
    ///   so the next session starts from the ledger list.
    init() {
        if TokenStore.shared.isTokenValid {
            isAuthenticated = true
        } else {
            // Token missing or expired — clean up and require fresh login
            TokenStore.shared.delete()
            SessionStore.shared.clearLastLedger()
            isAuthenticated = false
        }
    }
    
    // MARK: - Login / Logout

    /// Authenticates the owner with the backend and establishes a new session.
    ///
    /// Posts `POST /auth/login` via ``APIClient`` with a ``LoginRequest`` body.
    /// On success: saves the JWT to the Keychain via ``TokenStore``, sets
    /// `currentOwnerID`, and sets `isAuthenticated = true`.
    ///
    /// - Parameters:
    ///   - email: The owner's registered email address.
    ///   - password: The plain-text password to verify against the stored hash.
    /// - Throws: ``APIError`` for known failures:
    ///   - `.unauthorized` — invalid credentials (HTTP 401)
    ///   - `.serverError` — server-side error (HTTP 5xx)
    ///   - `.decodingError` — unexpected response format
    ///   - `.unknown` — network or other errors
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await auth.login(email: emailText, password: passwordText)
    /// } catch APIError.unauthorized {
    ///     showError("Invalid email or password")
    /// } catch {
    ///     showError(error.localizedDescription)
    /// }
    /// ```
    ///
    /// - Important: Always handle errors to display feedback on login failure.
    /// - SeeAlso: ``TokenStore``, ``TokenResponse``
    func login(email: String, password: String) async throws {
        let response: TokenResponse = try await APIClient.shared.request(
            .login,
            method: "POST",
            body: LoginRequest(email: email, password: password)
        )
        TokenStore.shared.save(response.token)
        self.currentOwnerID = response.ownerID
        isAuthenticated = true
    }

    /// Logs the owner out by deleting credentials and clearing all session state.
    ///
    /// Clears `currentOwnerID`, deletes the JWT from the Keychain via ``TokenStore``,
    /// clears the last-selected ledger from ``SessionStore``, and sets
    /// `isAuthenticated = false`. Observing views update automatically to show the
    /// login screen.
    ///
    /// - Note: Synchronous — completes immediately. The user must call
    ///   ``login(email:password:)`` or ``register(email:password:displayName:)``
    ///   to obtain a new token.
    /// - SeeAlso: ``TokenStore``, ``SessionStore``
    func logout() {
        self.currentOwnerID = nil
        TokenStore.shared.delete()
        SessionStore.shared.clearLastLedger()
        isAuthenticated = false
    }
    
    /// Creates a new owner account and establishes an authenticated session immediately.
    ///
    /// Posts `POST /auth/register` via ``APIClient``. On success: saves the JWT to
    /// the Keychain via ``TokenStore``, clears any stale session data via ``SessionStore``,
    /// sets `currentOwnerID`, and sets `isAuthenticated = true`.
    ///
    /// - Parameters:
    ///   - email: The desired email address (must be unique across all owners).
    ///   - password: Plain-text password; minimum 8 characters enforced by the backend.
    ///   - displayName: Optional display name shown in the UI; `nil` or blank values
    ///     are accepted — the backend substitutes `"No Name"` when blank.
    /// - Throws: ``APIError`` — `.conflict` (HTTP 409) if the email is already registered,
    ///   or other cases for validation errors, network failures, and server errors.
    func register(email: String,
                  password: String,
                  displayName: String?) async throws {
        struct RegisterBody: Encodable {
            let email: String
            let password: String
            let displayName: String?
        }
        let response: TokenResponse = try await APIClient.shared.request(
            .register,
            method: "POST",
            body: RegisterBody(
                email: email,
                password: password,
                displayName: displayName
            )
        )
        TokenStore.shared.save(response.token)
        self.currentOwnerID = response.ownerID
        SessionStore.shared.clearLastLedger()
        isAuthenticated = true
    }
}

