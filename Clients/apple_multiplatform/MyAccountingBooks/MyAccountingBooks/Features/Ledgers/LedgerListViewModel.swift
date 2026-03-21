//
//  Features/Ledgers/LedgerListViewModel.swift
//  LedgerListViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import Foundation

/**
 View model managing state and business logic for the ledger list screen.
 
 `LedgerListViewModel` orchestrates ledger management operations including:
 - Fetching the list of available ledgers from the backend
 - Creating new ledgers with chart of accounts templates
 - Managing create form state and validation
 - Restoring the last selected ledger from session storage
 - Handling loading and error states
 
 # Features
 - **Ledger List Management**: Loads and maintains the list of user's ledgers
 - **Create Ledger Form**: Manages all fields for creating new ledgers
 - **Session Restoration**: Automatically restores the last selected ledger after loading
 - **Error Handling**: Captures and exposes error messages for UI display
 - **Loading States**: Provides loading indicators for async operations
 
 # Session Restoration
 When ledgers are loaded, the view model automatically checks `SessionStore` for the
 last selected ledger ID. If found and still present in the loaded list, it sets
 `restoredLedger` which the view can observe to automatically select it.
 
 # Usage Example
 
 ```swift
 @State private var viewModel = LedgerListViewModel()
 @State private var selectedLedger: LedgerResponse?
 @Environment(AuthService.self) private var auth
 
 var body: some View {
     List(viewModel.ledgers, selection: $selectedLedger) { ledger in
         LedgerRow(ledger: ledger)
     }
     .task {
         guard let token = auth.token else { return }
         await viewModel.loadLedgers(token: token)
         
         // Restore last selected ledger
         if let restored = viewModel.restoredLedger {
             selectedLedger = restored
         }
     }
     .sheet(isPresented: $viewModel.showCreateSheet) {
         CreateLedgerView(viewModel: viewModel)
     }
     .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
         Button("OK") { viewModel.errorMessage = nil }
     } message: {
         Text(viewModel.errorMessage ?? "")
     }
 }
 ```
 
 # Create Ledger Workflow
 
 ```swift
 // Present create sheet
 viewModel.showCreateSheet = true
 
 // User fills form (bound to viewModel.newLedger* properties)
 // ...
 
 // Submit form
 await viewModel.createLedger(token: authToken)
 
 // On success: new ledger is added to list, form is reset, sheet closes
 ```
 
 - Important: Always check for valid authentication token before calling async methods.
 - Note: This class uses the `@Observable` macro for SwiftUI state management.
 - SeeAlso: `LedgerService`, `SessionStore`, `CreateLedgerRequest`, `LedgerResponse`
 */
@Observable
final class LedgerListViewModel {

    // MARK: - State

    /// The current list of ledgers available to the user.
    ///
    /// This array is populated by `loadLedgers(token:)` and updated when new ledgers
    /// are created via `createLedger(token:)`. Each ledger contains metadata including
    /// name, currency, and chart of accounts information.
    var ledgers: [LedgerResponse] = []
    
    /// Indicates whether a network operation is currently in progress.
    ///
    /// Set to `true` during `loadLedgers` and `createLedger` operations.
    /// Used to display loading indicators in the UI.
    var isLoading = false
    
    /// An optional error message to display when operations fail.
    ///
    /// Set when network requests fail or validation errors occur.
    /// Should be displayed in an alert or error view, then cleared by setting to `nil`.
    var errorMessage: String?
    
    /// Controls presentation of the create ledger form sheet.
    ///
    /// Set to `true` to present the creation form, `false` to dismiss.
    /// Automatically set to `false` after successful ledger creation.
    var showCreateSheet = false
    
    /// The ledger restored from the last session, if available.
    ///
    /// After loading ledgers, this property is set to the ledger that was previously
    /// selected (stored in `SessionStore`), if it still exists in the loaded list.
    /// The view observes this property to automatically select the restored ledger.
    ///
    /// - Note: This is set once after `loadLedgers` completes successfully.
    /// - SeeAlso: `SessionStore.lastLedgerID`
    var restoredLedger: LedgerResponse? = nil

    // MARK: - Create Form State

    /// The name input for a new ledger.
    ///
    /// Required field - cannot be empty. Whitespace is trimmed before submission.
    var newLedgerName = ""
    
    /// The currency mnemonic code for the new ledger (e.g., "USD", "EUR", "MXN").
    ///
    /// Defaults to "MXN". Automatically converted to uppercase before submission.
    var newLedgerCurrency = "MXN"
    
    /// The number of decimal places for monetary amounts in the new ledger.
    ///
    /// Defaults to 2 (standard for most currencies). Determines precision for all amounts.
    var newLedgerDecimalPlaces = 2
    
    /// Optional chart-of-accounts template code to use when creating the ledger.
    ///
    /// If provided, the ledger will be initialized with accounts from the specified template.
    /// Leave empty to create a ledger without a pre-populated chart of accounts.
    var newLedgerTemplateCode = ""
    
    /// Optional version identifier for the chart-of-accounts template.
    ///
    /// Used in conjunction with `newLedgerTemplateCode` to specify a particular template version.
    /// Leave empty to use the default version of the template.
    var newLedgerTemplateVersion = ""

    // MARK: - Dependencies

    /// Service used to perform ledger-related network operations.
    ///
    /// Singleton instance providing methods to fetch and create ledgers.
    private let service = LedgerService.shared

    // MARK: - Load

    /**
     Loads the list of ledgers and attempts to restore the last selected ledger from session.
     
     This method fetches all ledgers available to the authenticated user and performs
     automatic session restoration by checking `SessionStore` for the previously selected
     ledger. If found in the loaded list, it sets `restoredLedger` for the view to observe.
     
     - Parameter token: A bearer authentication token for authorizing the request.
     
     - Throws: Does not throw - errors are captured in `errorMessage` property.
     
     # Workflow
     
     1. **Set loading state**: `isLoading = true`, clear previous errors
     2. **Fetch ledgers**: Request ledger list from backend via `LedgerService`
     3. **Update state**: Store ledgers in `ledgers` array
     4. **Restore session**: Check `SessionStore` for last selected ledger ID
        - If found and exists in loaded list: set `restoredLedger`
        - View observes this and automatically selects the ledger
     5. **Clear loading**: `isLoading = false`
     6. **Error handling**: If request fails, capture error in `errorMessage`
     
     # Session Restoration
     
     The restoration process matches the stored ledger ID against the loaded list:
     ```swift
     if let lastID = SessionStore.shared.lastLedgerID,
        let match = ledgers.first(where: { $0.id == lastID }) {
         restoredLedger = match
     }
     ```
     
     If the ledger no longer exists (deleted, access revoked, etc.), no restoration occurs
     and the user must manually select a ledger.
     
     # Usage
     
     ```swift
     @State private var viewModel = LedgerListViewModel()
     @State private var selectedLedger: LedgerResponse?
     
     .task {
         guard let token = auth.token else { return }
         await viewModel.loadLedgers(token: token)
         
         // Check for restored ledger
         if let restored = viewModel.restoredLedger {
             selectedLedger = restored
         }
     }
     ```
     
     - Important: Must be called from a `@MainActor` context for UI updates.
     - Note: Session restoration is automatic and requires no additional setup.
     - SeeAlso: `SessionStore.lastLedgerID`, `restoredLedger`
     */
    @MainActor
    func loadLedgers(token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            ledgers = try await service.fetchLedgers(token: token)
            
            // Restore last selected ledger from session storage
            // After loading, if a ledger was previously selected and still
            // exists in the list, set restoredLedger for the view to observe.
            if let lastID  = SessionStore.shared.lastLedgerID,
               let match   = ledgers.first(where: { $0.id == lastID }) {
                restoredLedger = match
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Create

    /**
     Creates a new ledger from the current form fields and updates the list on success.
     
     This method validates the form input, constructs a creation request, submits it to
     the backend, and updates the local ledger list upon success. The form is automatically
     reset and the creation sheet is dismissed after successful creation.
     
     - Parameter token: A bearer authentication token for authorizing the request.
     
     - Throws: Does not throw - errors are captured in `errorMessage` property.
     
     # Validation
     
     Before submitting, the method validates:
     - **Name**: Must not be empty or whitespace-only
     
     If validation fails, `errorMessage` is set and the method returns early.
     
     # Workflow
     
     1. **Validate input**: Check name is not empty after trimming whitespace
     2. **Set loading state**: `isLoading = true`, clear previous errors
     3. **Build request**: Create `CreateLedgerRequest` from form fields
        - Name is trimmed of whitespace
        - Currency is converted to uppercase
        - Template fields are converted to `nil` if empty
     4. **Submit request**: Create ledger via `LedgerService`
     5. **Update list**: Append new ledger to `ledgers` array
     6. **Reset form**: Clear all form fields to defaults
     7. **Dismiss sheet**: Set `showCreateSheet = false`
     8. **Clear loading**: `isLoading = false`
     9. **Error handling**: If request fails, capture error in `errorMessage`
     
     # Request Format
     
     The request includes:
     - `name`: Trimmed ledger name (required)
     - `currencyMnemonic`: Uppercase currency code (e.g., "MXN", "USD")
     - `decimalPlaces`: Number of decimal places for amounts
     - `coaTemplateCode`: Optional chart of accounts template
     - `coaTemplateVersion`: Optional template version
     
     # Usage
     
     ```swift
     // Bind form fields to view model
     TextField("Ledger Name", text: $viewModel.newLedgerName)
     TextField("Currency", text: $viewModel.newLedgerCurrency)
     Stepper("Decimal Places: \(viewModel.newLedgerDecimalPlaces)", 
             value: $viewModel.newLedgerDecimalPlaces, in: 0...4)
     
     // Submit button
     Button("Create") {
         Task {
             await viewModel.createLedger(token: authToken)
         }
     }
     .disabled(viewModel.newLedgerName.isEmpty)
     ```
     
     # Success Flow
     
     On successful creation:
     1. New ledger appears in the list immediately
     2. Form is reset to default values
     3. Creation sheet is dismissed
     4. User can select the new ledger
     
     # Error Flow
     
     On failure:
     1. `errorMessage` is set with error description
     2. Sheet remains open
     3. User can correct input and retry
     4. Form fields are preserved for correction
     
     - Important: Must be called from a `@MainActor` context for UI updates.
     - Note: Form is only reset on successful creation, not on errors.
     - SeeAlso: `CreateLedgerRequest`, `LedgerService.createLedger(_:token:)`
     */
    @MainActor
    func createLedger(token: String) async {
        guard !newLedgerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Ledger name cannot be empty."
            return
        }

        isLoading = true
        errorMessage = nil

        let request = CreateLedgerRequest(
            name: newLedgerName.trimmingCharacters(in: .whitespaces),
            currencyMnemonic: newLedgerCurrency.uppercased(),
            decimalPlaces: newLedgerDecimalPlaces,
            coaTemplateCode: newLedgerTemplateCode.isEmpty ? nil : newLedgerTemplateCode,
            coaTemplateVersion: newLedgerTemplateVersion.isEmpty ? nil : newLedgerTemplateVersion
        )

        do {
            let created = try await service.createLedger(request, token: token)
            ledgers.append(created)
            resetCreateForm()
            showCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    /**
     Resets all create ledger form fields to their default values.
     
     This private method is called automatically after successful ledger creation
     to prepare the form for creating another ledger. It resets all fields to:
     - `newLedgerName`: Empty string
     - `newLedgerCurrency`: "MXN"
     - `newLedgerDecimalPlaces`: 2
     - `newLedgerTemplateCode`: Empty string
     - `newLedgerTemplateVersion`: Empty string
     
     - Note: This is only called on successful creation, not on validation errors.
     */
    private func resetCreateForm() {
        newLedgerName = ""
        newLedgerCurrency = "MXN"
        newLedgerDecimalPlaces = 2
        newLedgerTemplateCode = ""
        newLedgerTemplateVersion = ""
    }
}

