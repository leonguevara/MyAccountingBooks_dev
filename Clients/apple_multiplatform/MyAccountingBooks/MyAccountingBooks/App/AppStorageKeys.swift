//
//  App/AppStorageKeys.swift
//  AppStorageKeys.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

import Foundation

/// Namespaced constants for all `@AppStorage` / `UserDefaults` keys used in the app.
///
/// Always use these constants instead of raw string literals to avoid key mismatches.
enum AppStorageKeys {
    /// Whether the account code column is shown in the COA tree.
    static let showAccountCode = "showAccountCode"
}
