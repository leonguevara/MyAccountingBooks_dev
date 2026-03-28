//
//  App/SettingsView.swift
//  SettingsView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

import SwiftUI

/// Application-level preferences window.
///
/// Presented as a standard macOS Settings scene (⌘ + , or **MyAccountingBooks › Settings…**).
/// Each preference is persisted via `@AppStorage` using the keys defined in ``AppStorageKeys``,
/// so any view that binds to the same key receives updates automatically.
///
/// ## Sections
/// ### Chart of Accounts
/// | Preference | Default | Effect |
/// |---|---|---|
/// | Show account code | `true` | Displays the account-code column in the COA tree. |
struct SettingsView: View {

    /// Whether the account-code column is visible in the COA tree.
    ///
    /// Persisted under ``AppStorageKeys/showAccountCode``.
    @AppStorage(AppStorageKeys.showAccountCode)
    private var showAccountCode: Bool = true

    var body: some View {
        Form {
            Section("Chart of Accounts") {
                Toggle("Show account code", isOn: $showAccountCode)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 120)
        .padding()
    }
}
