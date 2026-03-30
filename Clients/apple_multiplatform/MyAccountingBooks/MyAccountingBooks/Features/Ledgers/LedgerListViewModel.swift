//
//  Features/Ledgers/LedgerListViewModel.swift
//  LedgerListViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11
//  Last modified by León Felipe Guevara Chávez on 2026-03-29.
//  Developed with AI assistance.
//

import Foundation

/// View model managing state and business logic for the ledger list screen.
///
/// `LedgerListViewModel` orchestrates ledger management operations including:
/// - Fetching the list of available ledgers from the backend
/// - Creating new ledgers with optional chart of accounts templates
/// - Managing create form state and validation
/// - Restoring the last selected ledger from session storage
/// - Handling loading and error states
///
/// ## Features
/// - **Ledger List Management**: Loads and maintains the list of user's ledgers
/// - **Create Ledger Form**: Manages all fields for creating new ledgers
/// - **COA Template Picker**: Loads the global template catalog and applies a selected template at creation time
/// - **Session Restoration**: Automatically restores the last selected ledger after loading
/// - **Error Handling**: Captures and exposes error messages for UI display
/// - **Loading States**: Provides loading indicators for async operations
///
/// ## Session Restoration
/// When ledgers are loaded, the view model automatically checks ``SessionStore`` for the
/// last selected ledger ID. If found and still present in the loaded list, it sets
/// `restoredLedger` which the view can observe to automatically select it.
///
/// ## Usage Example
///
/// ```swift
/// @State private var viewModel = LedgerListViewModel()
/// @State private var selectedLedger: LedgerResponse?
/// @Environment(AuthService.self) private var auth
///
/// var body: some View {
///     List(viewModel.ledgers, selection: $selectedLedger) { ledger in
///         LedgerRow(ledger: ledger)
///     }
///     .task {
///         guard let token = auth.token else { return }
///         await viewModel.loadLedgers(token: token)
///
///         if let restored = viewModel.restoredLedger {
///             selectedLedger = restored
///         }
///     }
///     .sheet(isPresented: $viewModel.showCreateSheet) {
///         CreateLedgerView(viewModel: viewModel)
///     }
/// }
/// ```
///
/// ## Create Ledger Workflow
///
/// ```swift
/// viewModel.showCreateSheet = true
///
/// // User fills form (bound to viewModel.newLedger* properties)
///
/// await viewModel.createLedger(token: authToken)
/// // On success: new ledger is added to list, form is reset, sheet closes
/// ```
///
/// - Important: Always check for a valid authentication token before calling async methods.
/// - Note: This class uses the `@Observable` macro for SwiftUI state management.
/// - SeeAlso: ``LedgerService``, ``SessionStore``, ``CreateLedgerRequest``, ``LedgerResponse``
@Observable
final class LedgerListViewModel {

    // MARK: - State

    /// The current list of ledgers available to the user.
    ///
    /// Populated by ``loadLedgers(token:)`` and extended when new ledgers are created
    /// via ``createLedger(token:)``. Each ledger contains metadata including name,
    /// currency, and chart of accounts information.
    var ledgers: [LedgerResponse] = []
    
    /// Indicates whether a network operation is currently in progress.
    ///
    /// Set to `true` during ``loadLedgers(token:)`` and ``createLedger(token:)`` operations.
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
    /// selected (stored in ``SessionStore``), if it still exists in the loaded list.
    /// The view observes this property to automatically select the restored ledger.
    ///
    /// - Note: Set once after ``loadLedgers(token:)`` completes successfully.
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
    
    /// The global COA template catalog, loaded in parallel with ledgers.
    ///
    /// Populated by ``loadLedgers(token:)`` via ``LedgerService/fetchCoaTemplates(token:)``.
    /// Bound to the template picker in the create ledger form. An empty array means
    /// either the fetch failed (silently ignored) or no templates are defined.
    var availableTemplates: [CoaTemplateItem] = []

    /// Whether the user wants to seed the new ledger from a COA template.
    ///
    /// When `false`, `coaTemplateCode` and `coaTemplateVersion` are omitted from the
    /// creation request and the ledger is created with an empty chart of accounts.
    var useTemplate: Bool = false

    /// The COA template selected for the new ledger, if any.
    ///
    /// Only used when `useTemplate` is `true`. Its `code` and `version` fields are
    /// forwarded to ``CreateLedgerRequest`` so the backend can instantiate the template.
    /// - SeeAlso: ``CoaTemplateItem``
    var selectedTemplate: CoaTemplateItem? = nil

    // MARK: - Dependencies

    /// Service used to perform ledger-related network operations.
    ///
    /// Singleton instance providing methods to fetch and create ledgers.
    private let service = LedgerService.shared

    // MARK: - Load

    /// Loads the ledger list and the COA template catalog in parallel, then restores
    /// the previously selected ledger from session storage.
    ///
    /// Ledgers and templates are fetched concurrently with `async let`. Template fetch
    /// failures are silently swallowed (empty array), so a catalog outage does not block
    /// ledger access. If `SessionStore` holds a ledger ID that still exists in the loaded
    /// list, `restoredLedger` is set for the view to observe.
    ///
    /// ## Workflow
    ///
    /// 1. Set `isLoading = true`, clear previous errors
    /// 2. Fetch ledgers and COA templates concurrently via ``LedgerService``
    /// 3. Store results in `ledgers` and `availableTemplates`
    /// 4. Check ``SessionStore`` for the last selected ledger ID; set `restoredLedger` if found
    /// 5. Set `isLoading = false`; capture any thrown error in `errorMessage`
    ///
    /// ## Session Restoration
    ///
    /// ```swift
    /// if let lastID = SessionStore.shared.lastLedgerID,
    ///    let match  = ledgers.first(where: { $0.id == lastID }) {
    ///     restoredLedger = match
    /// }
    /// ```
    ///
    /// If the stored ledger no longer exists (deleted, access revoked, etc.), no restoration
    /// occurs and the user must select a ledger manually.
    ///
    /// - Parameter token: A bearer authentication token for authorizing the request.
    /// - Note: Errors are captured in `errorMessage`; this method does not throw.
    /// - Important: Must be called from a `@MainActor` context for UI updates.
    /// - SeeAlso: ``SessionStore``, `restoredLedger`
    @MainActor
    func loadLedgers(token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            async let ledgerFetch   = service.fetchLedgers(token: token)
            async let templateFetch = LedgerService.shared.fetchCoaTemplates(token: token)

            ledgers            = try await ledgerFetch
            availableTemplates = (try? await templateFetch) ?? []

            if let lastID = SessionStore.shared.lastLedgerID,
               let match  = ledgers.first(where: { $0.id == lastID }) {
                restoredLedger = match
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Create

    /// Creates a new ledger from the current form fields and appends it to the list on success.
    ///
    /// Validates that `newLedgerName` is non-empty, builds a ``CreateLedgerRequest``, submits
    /// it via ``LedgerService``, and on success appends the result to `ledgers`, resets the
    /// form, and dismisses the sheet. On failure, `errorMessage` is set and the sheet stays open
    /// so the user can correct and retry.
    ///
    /// ## Validation
    ///
    /// - **Name**: Must not be empty or whitespace-only; sets `errorMessage` and returns early if so.
    ///
    /// ## Workflow
    ///
    /// 1. Validate name (non-empty after trimming whitespace)
    /// 2. Set `isLoading = true`, clear previous errors
    /// 3. Build ``CreateLedgerRequest``:
    ///    - `name` — trimmed
    ///    - `currencyMnemonic` — uppercased
    ///    - `coaTemplateCode` / `coaTemplateVersion` — `nil` when `useTemplate` is `false`
    /// 4. Submit via ``LedgerService/createLedger(_:token:)``
    /// 5. Append new ledger to `ledgers`, reset form, set `showCreateSheet = false`
    /// 6. Set `isLoading = false`; capture any error in `errorMessage`
    ///
    /// - Parameter token: A bearer authentication token for authorizing the request.
    /// - Note: Errors are captured in `errorMessage`; this method does not throw. The form is
    ///   reset only on success, preserving fields for correction on failure.
    /// - Important: Must be called from a `@MainActor` context for UI updates.
    /// - SeeAlso: ``CreateLedgerRequest``, ``LedgerService/createLedger(_:token:)``
    @MainActor
    func createLedger(token: String) async {
        guard !newLedgerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Ledger name cannot be empty."
            return
        }

        isLoading = true
        errorMessage = nil

        let request = CreateLedgerRequest(
            name:               newLedgerName.trimmingCharacters(in: .whitespaces),
            currencyMnemonic:   newLedgerCurrency.uppercased(),
            decimalPlaces:      newLedgerDecimalPlaces,
            coaTemplateCode:    useTemplate ? selectedTemplate?.code    : nil,
            coaTemplateVersion: useTemplate ? selectedTemplate?.version : nil
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

    /// Resets all create-ledger form fields to their default values.
    ///
    /// Called automatically after a successful ledger creation to prepare the form for
    /// the next use. Resets:
    /// - `newLedgerName` → `""`
    /// - `newLedgerCurrency` → `"MXN"`
    /// - `newLedgerDecimalPlaces` → `2`
    /// - `useTemplate` → `false`
    /// - `selectedTemplate` → `nil`
    ///
    /// - Note: Only called on successful creation, not on validation errors or network failures.
    private func resetCreateForm() {
        newLedgerName          = ""
        newLedgerCurrency      = "MXN"
        newLedgerDecimalPlaces = 2
        useTemplate            = false
        selectedTemplate       = nil
    }
}

