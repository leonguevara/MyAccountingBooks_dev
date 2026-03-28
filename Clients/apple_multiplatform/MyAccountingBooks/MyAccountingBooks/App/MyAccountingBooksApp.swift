//
//  App/MyAccountingBooksApp.swift
//  MyAccountingBooks.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance
//

/// The main application entry point for MyAccountingBooks.
///
/// Manages the authentication flow and sets up window scenes:
/// - **Primary window**: Presents `ContentView` or `LoginView` based on authentication state.
/// - **Account Register windows**: Dedicated windows opened via `AccountRegisterWindowPayload`.
/// - **Account Form windows**: Modal windows for creating and editing accounts, opened via `AccountFormWindowPayload`.
import SwiftUI

@main
struct MyAccountingBooksApp: App {
    /// Authentication service shared across the app via the environment.
    @State private var auth = AuthService()

    /// Configures the app's primary window scene and presents the appropriate root view.
    var body: some Scene {
        /// Primary window group that conditionally presents content based on authentication state.
        WindowGroup {
            if auth.isAuthenticated {
                ContentView()
                    .environment(auth)
            } else {
                LoginView()
                    .environment(auth)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 720)
        
        // ── Account register windows ──────────────────────────────────────
        /// Secondary window group for account registers, opened with a value payload.
        ///
        /// Each account register window displays the transaction history for a specific
        /// account. Multiple register windows can be open simultaneously, one per account.
        /// SwiftUI automatically deduplicates windows by payload value.
        WindowGroup("Account Register", for: AccountRegisterWindowPayload.self) { $payload in
            if let payload {
                AccountRegisterWindowContent(payload: payload)
                    .environment(auth)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 600)
        
        // ── Account form windows ──────────────────────────────────────────
        /// Window group for creating and editing accounts, opened with a value payload.
        ///
        /// Account form windows are used for:
        /// - **Creating new accounts**: `existingAccount` is `nil`, `suggestedParentId` may
        ///   pre-select a parent account.
        /// - **Editing existing accounts**: `existingAccount` contains the account data to modify.
        ///
        /// Opened from:
        /// - Toolbar "New Account" button in `AccountTreeView`
        /// - Context menu "New Sub-Account" action (with `suggestedParentId` set)
        /// - Context menu "Edit Account" action (with `existingAccount` populated)
        WindowGroup("Account", for: AccountFormWindowPayload.self) { $payload in
            if let payload {
                AccountFormWindowContent(payload: payload)
                    .environment(auth)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 540, height: 580)
        
        Settings {
            SettingsView()
        }
    }
}
