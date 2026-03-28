//
//  App/AppStorageKeys.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

import Foundation

/// Namespaced constants for all `@AppStorage` / `UserDefaults` keys used in the app.
///
/// Always reference these constants instead of raw string literals to prevent
/// key mismatches between write sites (e.g., `SettingsView`) and read sites
/// (e.g., feature views that consume the stored preference).
enum AppStorageKeys {

    /// Key for the preference that controls whether the account code column is
    /// visible in the Chart of Accounts tree.
    ///
    /// Consumed by: `SettingsView`, `AccountTreeView`.
    static let showAccountCode = "showAccountCode"
}
