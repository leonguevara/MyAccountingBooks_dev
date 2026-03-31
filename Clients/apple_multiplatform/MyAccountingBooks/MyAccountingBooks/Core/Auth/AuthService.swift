//
//  Core/Auth/AuthService.swift
//  AuthService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import Foundation

/**
 An observable authentication service managing user login state, token storage, and validation.
 
 `AuthService` coordinates the complete authentication lifecycle including login, logout, token
 persistence, and automatic expiry detection. It uses `TokenStore` for secure Keychain storage
 and `APIClient` for backend authentication requests.
 
 # Features
 - **Login/Logout**: Authenticates users and manages session state
 - **Token Management**: Securely stores JWT tokens in the Keychain
 - **Expiry Detection**: Automatically validates tokens on app launch and access
 - **Observable State**: Publishes authentication state for reactive UI updates
 - **Session Cleanup**: Removes expired tokens and clears session data on logout
 
 # Token Validation
 The service performs automatic token validation:
 - **On app launch**: Checks if stored token is valid and not expired
 - **On access**: Returns `nil` for expired tokens via the `token` computed property
 - **On logout**: Clears token and associated session data
 
 If a token is expired on app launch, it's automatically deleted and the user is
 presented with the login screen, preventing failed API requests with stale credentials.
 
 # Usage Example (SwiftUI)
 
 ```swift
 @State private var auth = AuthService()
 
 var body: some View {
     Group {
         if auth.isAuthenticated {
             ContentView()
                 .environment(auth)
         } else {
             LoginView()
                 .environment(auth)
         }
     }
 }
 ```
 
 **Login View:**
 ```swift
 @Environment(AuthService.self) private var auth
 @State private var email = ""
 @State private var password = ""
 @State private var errorMessage: String?
 
 var body: some View {
     Form {
         TextField("Email", text: $email)
             .textContentType(.username)
             .textInputAutocapitalization(.never)
             .autocorrectionDisabled()
         SecureField("Password", text: $password)
             .textContentType(.password)
         
         Button("Sign In") {
             Task {
                 do {
                     try await auth.login(email: email, password: password)
                 } catch {
                     errorMessage = error.localizedDescription
                 }
             }
         }
         
         if let error = errorMessage {
             Text(error).foregroundStyle(.red)
         }
     }
 }
 ```
 
 **Making authenticated requests:**
 ```swift
 @Environment(AuthService.self) private var auth
 
 func loadData() async {
     guard let token = auth.token else {
         // Token expired or missing - user will be logged out
         return
     }
     
     do {
         let accounts: [Account] = try await APIClient.shared.request(
             .accounts(ledgerID: ledgerID),
             token: token
         )
         // Process accounts...
     } catch {
         print("Failed to load accounts: \(error)")
     }
 }
 ```
 
 # State Management
 
 The service maintains authentication state that can be observed by SwiftUI views:
 - `isAuthenticated`: Boolean indicating whether a valid token exists
 - `token`: Optional token string, returns `nil` if expired or missing
 
 When authentication state changes, all observing views automatically update.
 
 - Important: Always check `auth.token` rather than loading directly from `TokenStore` to ensure token validity.
 - Note: This service uses the `@Observable` macro for SwiftUI state management.
 - SeeAlso: `TokenStore`, `APIClient`, `TokenResponse`, `LoginRequest`
 */
@Observable
final class AuthService {
    
    // MARK: - State
    
    /// Indicates whether the user is currently authenticated with a valid token.
    ///
    /// This property is set to `true` when:
    /// - User successfully logs in
    /// - App launches with a valid, non-expired token in the Keychain
    ///
    /// Set to `false` when:
    /// - User logs out
    /// - App launches with no token or an expired token
    ///
    /// SwiftUI views observing this property will automatically update when authentication state changes.
    var isAuthenticated = false
    
    /// The current bearer token for authenticated API requests, if valid.
    ///
    /// This computed property returns the stored JWT token only if it exists and has not expired.
    /// It performs real-time validation by checking `TokenStore.shared.isTokenValid`.
    ///
    /// - Returns: A valid JWT token string, or `nil` if:
    ///   - No token is stored in the Keychain
    ///   - The stored token has expired
    ///   - The token format is invalid
    ///
    /// # Usage
    /// Always access tokens through this property rather than directly from `TokenStore`:
    /// ```swift
    /// guard let token = auth.token else {
    ///     // Token is expired or missing - authentication required
    ///     return
    /// }
    ///
    /// // Use token for authenticated request
    /// let data = try await APIClient.shared.request(.endpoint, token: token)
    /// ```
    ///
    /// If this property returns `nil` but `isAuthenticated` is `true`, the token has expired
    /// and the user should be logged out automatically.
    ///
    /// - Important: This performs validation on every access. Cache the value if making multiple requests.
    /// - Note: Token expiry is validated client-side without network calls.
    /// - SeeAlso: `TokenStore.isTokenValid`
    var token: String? {
        TokenStore.shared.isTokenValid ? TokenStore.shared.load() : nil
    }
    
    var currentOwnerID: UUID? = nil
    
    // MARK: - Init

    /**
     Initializes the authentication service and restores session state from the Keychain.
     
     The initializer performs automatic token validation on app launch:
     1. Checks if a token exists in the Keychain
     2. Validates that the token has not expired
     3. Sets initial authentication state based on token validity
     4. Cleans up expired tokens and session data if necessary
     
     # Token Validation on Launch
     
     **If token is valid:**
     - Sets `isAuthenticated = true`
     - User proceeds directly to authenticated screens
     - Stored token is available via the `token` property
     
     **If token is missing or expired:**
     - Deletes the expired token from Keychain
     - Clears last selected ledger from session storage
     - Sets `isAuthenticated = false`
     - User is presented with login screen
     
     This automatic cleanup prevents failed API requests with stale credentials and provides
     a smooth user experience by immediately showing the appropriate screen.
     
     # Example
     ```swift
     @main
     struct MyAccountingBooksApp: App {
         @State private var auth = AuthService() // Validates token on init
         
         var body: some Scene {
             WindowGroup {
                 if auth.isAuthenticated {
                     ContentView()
                 } else {
                     LoginView()
                 }
             }
             .environment(auth)
         }
     }
     ```
     
     - Important: Token expiry is detected immediately on launch, not on first API call.
     - Note: Session data (last selected ledger) is cleared when token expires.
     */
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

    /**
     Authenticates the user with the backend and establishes a new session.
     
     This method performs the complete login workflow:
     1. Sends credentials to the backend authentication endpoint
     2. Receives a JWT token in the response
     3. Securely stores the token in the Keychain
     4. Updates `isAuthenticated` to `true`
     
     Upon successful completion, the user is authenticated and the token is available
     for subsequent API requests through the `token` property.
     
     - Parameters:
       - email: The user's email address for authentication.
       - password: The user's password for authentication.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized`: Invalid credentials (401)
         - `.serverError`: Server-side error (5xx)
         - `.decodingError`: Response format error
         - `.unknown`: Network or other errors
     
     # Usage
     ```swift
     @Environment(AuthService.self) private var auth
     
     func signIn() async {
         do {
             try await auth.login(email: emailText, password: passwordText)
             // User is now authenticated, navigate to main screen
         } catch APIError.unauthorized {
             showError("Invalid email or password")
         } catch {
             showError("Login failed: \(error.localizedDescription)")
         }
     }
     ```
     
     # Security
     - Password is sent securely to the backend (ensure HTTPS is used)
     - Token is stored encrypted in the system Keychain
     - Previous tokens are automatically replaced
     
     - Important: Always handle errors to provide user feedback on login failures.
     - Note: This method updates `isAuthenticated` immediately upon success.
     - SeeAlso: `TokenStore.save(_:)`, `LoginRequest`, `TokenResponse`
     */
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

    /**
     Logs the user out by deleting credentials and clearing session state.
     
     This method performs a complete logout by:
     1. Deleting the stored JWT token from the Keychain
     2. Setting `isAuthenticated` to `false`
     3. Triggering UI updates to show the login screen
     
     The token is permanently deleted and cannot be recovered. The user must
     authenticate again to obtain a new token.
     
     # Usage
     ```swift
     Button("Sign Out") {
         auth.logout()
         // User is now logged out, login screen will appear
     }
     ```
     
     # State Changes
     After calling this method:
     - `isAuthenticated` becomes `false`
     - `token` returns `nil`
     - Observing views automatically update to show login screen
     - Token is removed from Keychain storage
     
     # Session Data
     Note that this method only clears the authentication token. Other session data
     (like the last selected ledger) may remain and will be cleared automatically
     the next time the app launches if the token is missing or expired.
     
     - Important: This action cannot be undone - the user must log in again.
     - Note: This is a synchronous operation that completes immediately.
     - SeeAlso: `TokenStore.delete()`, `login(email:password:)`
     */
    func logout() {
        self.currentOwnerID = nil
        TokenStore.shared.delete()
        isAuthenticated = false
    }
    
    /// Registers a new account and returns a JWT on success.
    ///
    /// - Parameters:
    ///   - email: The desired email address.
    ///   - password: Plain-text password (minimum 8 characters).
    ///   - displayName: Optional display name shown in the UI.
    /// - Throws: `APIError.conflict` if the email is already taken,
    ///           or other `APIError` cases for network/server failures.
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

