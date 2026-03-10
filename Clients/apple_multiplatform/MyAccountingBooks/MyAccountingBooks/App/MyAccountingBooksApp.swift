//
//  App/MyAccountingBooksApp.swift
//  MyAccountingBooks.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance
//

/// The main application entry point for MyAccountingBooks.
///
/// Manages the authentication flow and sets up the initial window scene.
import SwiftUI

@main
struct MyAccountingBooksApp: App {
    /// Authentication service shared across the app via the environment.
    @State private var auth = AuthService()

    /// Configures the app's primary window scene and presents the appropriate root view.
    var body: some Scene {
        /// The main window group that conditionally presents content based on authentication state.
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
    }
}
