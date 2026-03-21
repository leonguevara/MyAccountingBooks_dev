//
//  Core/Auth/SessionStore.swift
//  SessionStore.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

/**
 A lightweight session state manager that persists user preferences across app launches.
 
 `SessionStore` uses `UserDefaults` to store minimal session information that survives app restarts.
 Currently, it only stores the last selected ledger ID to provide a smoother user experience by
 remembering the user's working context.
 
 # Design Philosophy
 
 Following UX best practices, this store intentionally stores **only** the last selected ledger:
 - ✅ **Stored**: Last selected ledger ID (user's working context)
 - ❌ **Not stored**: Account register state, scroll positions, selected transactions
 
 This design ensures users consciously choose what to view each time, preventing confusion
 from automatically opening to potentially stale or unexpected views.
 
 # Session Lifecycle
 
 - **On ledger selection**: Store is updated with the new ledger ID
 - **On logout**: Last ledger is cleared to prevent cross-user data leakage
 - **On token expiry**: Last ledger is cleared to maintain security
 - **On app launch**: Last ledger ID is read to suggest the previous working context
 
 # Usage Example
 
 **Saving the last selected ledger:**
 ```swift
 // When user selects a ledger
 func selectLedger(_ ledger: LedgerResponse) {
     selectedLedger = ledger
     SessionStore.shared.saveLastLedger(id: ledger.id)
 }
 ```
 
 **Restoring the last selected ledger:**
 ```swift
 // On app launch or view appear
 func restoreSession() async {
     guard let lastLedgerID = SessionStore.shared.lastLedgerID else {
         // No previous ledger, show ledger picker
         return
     }
     
     // Try to select the last ledger
     if let ledger = ledgers.first(where: { $0.id == lastLedgerID }) {
         selectedLedger = ledger
     }
 }
 ```
 
 **Clearing session on logout:**
 ```swift
 func logout() {
     TokenStore.shared.delete()
     SessionStore.shared.clearLastLedger() // Clear session data
     isAuthenticated = false
 }
 ```
 
 # Data Persistence
 
 - **Storage**: `UserDefaults.standard`
 - **Format**: UUID stored as string
 - **Key**: `"mab.session.lastLedgerID"`
 - **Lifetime**: Persists until explicitly cleared or app is deleted
 
 # Security Considerations
 
 Session data is cleared when:
 - User explicitly logs out
 - Authentication token expires
 - This prevents session data from one user being shown to another
 
 - Important: Only stores the ledger ID, not sensitive financial data or authentication tokens.
 - Note: This is distinct from `TokenStore` which handles secure authentication credentials.
 - SeeAlso: `AuthService`, `TokenStore`
 */
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

    /**
     Saves the UUID of the most recently selected ledger to UserDefaults.
     
     This method persists the ledger ID so it can be restored on the next app launch,
     providing continuity in the user's workflow by remembering their working context.
     
     - Parameter id: The UUID of the ledger to remember.
     
     # Usage
     ```swift
     // When user selects a ledger from the picker
     func didSelectLedger(_ ledger: LedgerResponse) {
         selectedLedger = ledger
         SessionStore.shared.saveLastLedger(id: ledger.id)
         
         // Now load accounts for this ledger...
     }
     ```
     
     # Storage
     - The UUID is converted to a string and stored in `UserDefaults`
     - Key: `"mab.session.lastLedgerID"`
     - Persists across app launches until cleared
     
     - Note: This is a lightweight operation that completes synchronously.
     - SeeAlso: `lastLedgerID`, `clearLastLedger()`
     */
    func saveLastLedger(id: UUID) {
        defaults.set(id.uuidString, forKey: lastLedgerKey)
    }

    /**
     Returns the UUID of the last selected ledger, if available.
     
     This computed property retrieves the stored ledger ID from `UserDefaults` and returns
     it as a `UUID`. If no ledger has been stored, or if the stored value cannot be parsed
     as a valid UUID, it returns `nil`.
     
     - Returns: The UUID of the last selected ledger, or `nil` if:
       - No ledger has been saved yet
       - The stored value is not a valid UUID string
       - Session has been cleared via `clearLastLedger()`
     
     # Usage
     ```swift
     // On app launch or view appear
     func restoreLastSession() async {
         guard let lastLedgerID = SessionStore.shared.lastLedgerID else {
             // No previous session, show ledger picker
             showLedgerPicker = true
             return
         }
         
         // Try to find and select the last ledger
         if let ledger = availableLedgers.first(where: { $0.id == lastLedgerID }) {
             selectedLedger = ledger
         } else {
             // Ledger no longer exists, show picker
             showLedgerPicker = true
         }
     }
     ```
     
     # Validation
     Always validate that the ledger still exists and is accessible:
     - The ledger may have been deleted
     - User may no longer have access permissions
     - Ledger may belong to a different account (after re-login)
     
     - Important: Always validate the ledger exists before using it.
     - Note: Returns `nil` after logout or token expiry due to automatic cleanup.
     - SeeAlso: `saveLastLedger(id:)`, `clearLastLedger()`
     */
    var lastLedgerID: UUID? {
        guard let str = defaults.string(forKey: lastLedgerKey) else { return nil }
        return UUID(uuidString: str)
    }

    /**
     Clears the stored last selected ledger from UserDefaults.
     
     This method removes the persisted ledger ID, effectively resetting the session state.
     It's called automatically during logout and when an authentication token expires to
     prevent session data leakage between users or sessions.
     
     # When This Is Called
     
     - **On logout**: Prevents next user from seeing previous user's ledger
     - **On token expiry**: Maintains security by clearing stale session data
     - **Manual cleanup**: Can be called explicitly if needed
     
     # Usage
     ```swift
     // Called automatically by AuthService on logout
     func logout() {
         TokenStore.shared.delete()
         SessionStore.shared.clearLastLedger() // Clear session data
         isAuthenticated = false
     }
     ```
     
     ```swift
     // Called automatically by AuthService on token expiry
     init() {
         if TokenStore.shared.isTokenValid {
             isAuthenticated = true
         } else {
             TokenStore.shared.delete()
             SessionStore.shared.clearLastLedger() // Clear expired session
             isAuthenticated = false
         }
     }
     ```
     
     # Effects
     After calling this method:
     - `lastLedgerID` returns `nil`
     - On next app launch, no ledger will be pre-selected
     - User must choose a ledger from the picker
     
     - Important: This is a security measure to prevent cross-user data exposure.
     - Note: This operation is synchronous and completes immediately.
     - SeeAlso: `lastLedgerID`, `saveLastLedger(id:)`, `AuthService.logout()`
     */
    func clearLastLedger() {
        defaults.removeObject(forKey: lastLedgerKey)
    }
}
