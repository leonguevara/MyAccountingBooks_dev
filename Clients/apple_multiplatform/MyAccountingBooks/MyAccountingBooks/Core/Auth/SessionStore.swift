//
//  Core/Auth/SessionStore.swift
//  SessionStore.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

/// A lightweight session state manager that persists the user's working context across app launches.
///
/// `SessionStore` wraps `UserDefaults.standard` and intentionally stores **only** the last
/// selected ledger ID — nothing more. Account register state, scroll positions, and selected
/// transactions are deliberately not persisted so users always make a conscious choice about
/// what to view, avoiding confusion from stale or unexpected state.
///
/// ## Session Lifecycle
///
/// | Event | Action |
/// |---|---|
/// | Ledger selected | ``saveLastLedger(id:)`` writes the UUID |
/// | App launched | ``lastLedgerID`` is read to restore working context |
/// | Logout | ``clearLastLedger()`` removes the UUID |
/// | Token expired | ``clearLastLedger()`` removes the UUID |
///
/// ## Data Persistence
///
/// - **Storage**: `UserDefaults.standard`
/// - **Format**: UUID stored as a string
/// - **Key**: `"mab.session.lastLedgerID"`
/// - **Lifetime**: Persists until explicitly cleared or the app is deleted
///
/// - Important: Stores only a ledger UUID — no sensitive financial data or auth tokens.
/// - Note: Distinct from ``TokenStore``, which handles secure Keychain credentials.
/// - SeeAlso: ``AuthService``, ``TokenStore``
final class SessionStore {

    // MARK: - Properties
    
    /// Shared singleton instance providing consistent session storage across the app.
    static let shared = SessionStore()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    /// UserDefaults instance for persistent storage.
    private let defaults = UserDefaults.standard
    
    /// Storage key for the last selected ledger ID.
    private let lastLedgerKey = "mab.session.lastLedgerID"

    // MARK: - Last Selected Ledger

    /// Persists the UUID of the most recently selected ledger to `UserDefaults`.
    ///
    /// The UUID is converted to a string and written under the key
    /// `"mab.session.lastLedgerID"`. Persists across app launches until
    /// ``clearLastLedger()`` is called.
    ///
    /// - Parameter id: The UUID of the ledger to remember.
    /// - Note: Synchronous; completes immediately.
    /// - SeeAlso: ``lastLedgerID``, ``clearLastLedger()``
    func saveLastLedger(id: UUID) {
        defaults.set(id.uuidString, forKey: lastLedgerKey)
    }

    /// The UUID of the last selected ledger, read from `UserDefaults`.
    ///
    /// Returns `nil` when no ledger has been saved, the stored string is not a valid UUID,
    /// or ``clearLastLedger()`` has been called (e.g. after logout or token expiry).
    ///
    /// - Important: Always verify the returned ledger still exists before selecting it —
    ///   the ledger may have been deleted or become inaccessible since the last session.
    /// - Note: Returns `nil` automatically after logout or token expiry.
    /// - SeeAlso: ``saveLastLedger(id:)``, ``clearLastLedger()``
    var lastLedgerID: UUID? {
        guard let str = defaults.string(forKey: lastLedgerKey) else { return nil }
        return UUID(uuidString: str)
    }

    /// Removes the persisted last-selected ledger from `UserDefaults`.
    ///
    /// Called automatically by ``AuthService`` on logout and on token expiry to prevent
    /// session data from one user being shown to another. After this call,
    /// ``lastLedgerID`` returns `nil` and the next launch will start at the ledger list.
    ///
    /// - Note: Synchronous; completes immediately.
    /// - SeeAlso: ``lastLedgerID``, ``saveLastLedger(id:)``, ``AuthService``
    func clearLastLedger() {
        defaults.removeObject(forKey: lastLedgerKey)
    }
}
