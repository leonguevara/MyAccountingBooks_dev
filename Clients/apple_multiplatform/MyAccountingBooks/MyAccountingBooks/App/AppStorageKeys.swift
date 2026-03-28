//
//  App/AppStorageKeys.swift
//  AppStorageKeys.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

import Foundation

/// Namespaced constants for every `@AppStorage` / `UserDefaults` key used in the app.
///
/// Centralising keys here prevents typo-driven mismatches between the view that writes
/// a preference and any view that reads it.
///
/// ## Usage
/// ```swift
/// @AppStorage(AppStorageKeys.showAccountCode) var showAccountCode: Bool = true
/// ```
///
/// > Important: Never use raw string literals for UserDefaults keys. Always reference a
/// > constant from this enum so that renaming a key is a single-site change.
enum AppStorageKeys {
    /// The UserDefaults key that controls whether the account-code column is
    /// visible in the Chart of Accounts tree.
    ///
    /// - Type: `Bool`
    /// - Default: `true`
    /// - Written by: ``SettingsView``
    static let showAccountCode = "showAccountCode"
}
