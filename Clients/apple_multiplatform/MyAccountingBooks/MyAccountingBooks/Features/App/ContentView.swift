//
//  ContentView.swift
//  ContentView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//

import SwiftUI

/// The main application shell displaying primary sections and content area.
///
/// Uses `NavigationSplitView` to present a sidebar with sections and a detail area.
/// Provides a toolbar action to sign out via `AuthService`.
struct ContentView: View {
    /// Authentication service used to perform sign-out from the toolbar.
    @Environment(AuthService.self) private var auth

    var body: some View {
        /// Sidebar and detail layout for the app's primary navigation.
        NavigationSplitView {
            List {
                Label("Ledgers", systemImage: "book.closed")
                Label("Accounts", systemImage: "list.bullet.indent")
                Label("Transactions", systemImage: "arrow.left.arrow.right")
            }
            .navigationTitle("MyAccountingBooks")
        } detail: {
            Text("Select a section")
                .foregroundStyle(.secondary)
        }
        /// Top-level toolbar providing a sign-out button.
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Sign Out") { auth.logout() }
            }
        }
    }
}

