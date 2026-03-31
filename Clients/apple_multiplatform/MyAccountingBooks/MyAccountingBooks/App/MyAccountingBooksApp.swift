//
//  App/MyAccountingBooksApp.swift
//  MyAccountingBooks.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance
//

import SwiftUI

/// Application entry point for MyAccountingBooks.
///
/// Owns the global ``AuthService`` instance and composes all SwiftUI `Scene`s.
/// `AuthService` is injected into every scene via the environment so that any
/// descendant view can read or mutate authentication state without direct coupling.
///
/// ## Scenes
/// | Scene | Title | Default size |
/// |---|---|---|
/// | Primary `WindowGroup` | *(app name)* | 1100 × 720 |
/// | Account Register `WindowGroup` | "Account Register" | 900 × 600 |
/// | Account Form `WindowGroup` | "Account" | 540 × 580 |
/// | `Settings` | "Settings" | per ``SettingsView`` |
@main
struct MyAccountingBooksApp: App {
    /// Authentication service shared across all scenes via the SwiftUI environment.
    ///
    /// Declared with `@State` so SwiftUI owns the object's lifetime for the duration
    /// of the app process. Passed down with `.environment(auth)` rather than
    /// `@EnvironmentObject` to leverage the Observation framework.
    @State private var auth = AuthService()

    /// Declares the app's window scenes.
    ///
    /// - The primary `WindowGroup` guards its root view behind `auth.isAuthenticated`:
    ///   authenticated users see ``ContentView``; everyone else sees ``LoginView``.
    /// - Secondary window groups are value-typed and keyed by their payload structs,
    ///   allowing multiple independent windows of the same kind to coexist.
    /// - The `Settings` scene wires in ``SettingsView`` and is reachable via ⌘ + ,.
    var body: some Scene {
        // Primary window — shows ContentView or LoginView based on auth state.
        WindowGroup {
            if auth.isAuthenticated {
                ContentView()
                    .environment(auth)
                    .id(auth.currentOwnerID)   // ← force full recreation on user change
            } else {
                LoginView()
                    .environment(auth)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 720)
        
        // ── Account register windows ──────────────────────────────────────
        // Each window shows the transaction history for one account.
        // SwiftUI deduplicates windows by payload value, so opening the same
        // account twice brings the existing window to the front.
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
        // Used for both account creation and editing:
        //   • Creation — existingAccount is nil; suggestedParentId may pre-select a parent.
        //   • Editing  — existingAccount carries the account data to modify.
        //
        // Opened from:
        //   • Toolbar "New Account" button in AccountTreeView
        //   • Context menu "New Sub-Account" (suggestedParentId set)
        //   • Context menu "Edit Account"    (existingAccount populated)
        WindowGroup("Account", for: AccountFormWindowPayload.self) { $payload in
            if let payload {
                AccountFormWindowContent(payload: payload)
                    .environment(auth)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 540, height: 580)

        // ── Settings ──────────────────────────────────────────────────────
        // Standard macOS preferences window. Reachable via ⌘ + , or the app menu.
        Settings {
            SettingsView()
        }
    }
}
