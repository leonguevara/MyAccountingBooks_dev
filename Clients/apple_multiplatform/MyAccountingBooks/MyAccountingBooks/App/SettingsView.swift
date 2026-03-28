//
//  App/SettingsView.swift
//  SettingsView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

import SwiftUI

/// Application preferences window, accessible via ⌘ + , or the app menu.
///
/// Currently exposes the following preferences:
/// - **Show account code**: toggles the account code column in the COA tree.
///
/// Preferences are persisted via `@AppStorage` (UserDefaults) and read
/// throughout the app using the same keys.
struct SettingsView: View {

    /// Controls whether account codes are shown in the COA tree rows.
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
