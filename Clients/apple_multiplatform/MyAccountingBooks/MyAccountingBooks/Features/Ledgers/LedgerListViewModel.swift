//
//  Features/Ledgers/LedgerListViewModel.swift
//  LedgerListViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import Foundation

/// View model managing state and business logic for the ledger list screen.
///
/// Orchestrates ``loadLedgers(token:)`` (concurrent ledger + COA template fetch with session
/// restoration) and ``createLedger(token:)`` (form validation, request building, list append).
/// All async results are written to `@Observable` properties for reactive SwiftUI updates.
///
/// - Important: Always guard for a valid ``AuthService/token`` before calling async methods.
/// - Note: Uses the `@Observable` macro for SwiftUI state management.
/// - SeeAlso: ``LedgerService``, ``SessionStore``, ``CreateLedgerRequest``, ``LedgerResponse``
@Observable
final class LedgerListViewModel {

    // MARK: - State

    /// Ledgers owned by the authenticated user; populated by ``loadLedgers(token:)``,
    /// extended by ``createLedger(token:)``.
    var ledgers: [LedgerResponse] = []

    /// `true` while ``loadLedgers(token:)`` or ``createLedger(token:)`` is in flight.
    var isLoading = false

    /// Inline error text set on network or validation failure; `nil` when no error is present.
    var errorMessage: String?

    /// Controls presentation of the create-ledger sheet; set to `false` after successful creation.
    var showCreateSheet = false

    /// The ledger matching the ``SessionStore`` last-selected ID, set by ``loadLedgers(token:)``.
    ///
    /// `nil` when no session ID is stored or the stored ledger no longer exists.
    /// The view observes this to automatically restore the previous selection.
    var restoredLedger: LedgerResponse? = nil

    // MARK: - Create Form State

    /// Required ledger name; trimmed before submission — must not be blank.
    var newLedgerName = ""

    /// Currency mnemonic (e.g., `"USD"`, `"MXN"`); uppercased before submission. Defaults to `"MXN"`.
    var newLedgerCurrency = "MXN"

    /// Decimal precision for monetary amounts. Defaults to `2`.
    var newLedgerDecimalPlaces = 2

    /// Global COA template catalog loaded in parallel with ledgers by ``loadLedgers(token:)``.
    ///
    /// Empty when the fetch fails (silently swallowed) or no templates are defined.
    var availableTemplates: [CoaTemplateItem] = []

    /// `true` when the user wants to seed the new ledger from a COA template.
    ///
    /// When `false`, `coaTemplateCode` and `coaTemplateVersion` are omitted from ``CreateLedgerRequest``.
    var useTemplate: Bool = false

    /// The template selected in the picker; used only when ``useTemplate`` is `true`.
    ///
    /// - SeeAlso: ``CoaTemplateItem``
    var selectedTemplate: CoaTemplateItem? = nil

    // MARK: - Dependencies

    /// Shared ``LedgerService`` instance used for all network operations.
    private let service = LedgerService.shared

    // MARK: - Load

    /// Fetches ledgers and the COA template catalog concurrently, then restores the last
    /// selected ledger from ``SessionStore``.
    ///
    /// Template fetch failures are silently swallowed (empty ``availableTemplates``) so a
    /// catalog outage never blocks ledger access. If the stored ledger ID no longer exists
    /// in the loaded list, ``restoredLedger`` remains `nil` and the user selects manually.
    ///
    /// - Parameter token: Bearer token for authorizing the request.
    /// - Note: Errors are written to ``errorMessage``; this method does not throw.
    /// - SeeAlso: ``SessionStore``, ``restoredLedger``
    @MainActor
    func loadLedgers(token: String) async {
        isLoading       = true
        errorMessage    = nil
        ledgers         = []
        restoredLedger  = nil
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

    /// Validates the create form, submits a ``CreateLedgerRequest``, and appends the result
    /// to ``ledgers`` on success.
    ///
    /// Returns early (sets ``errorMessage``) if ``newLedgerName`` is blank. On success the
    /// form is reset via ``resetCreateForm()`` and ``showCreateSheet`` is set to `false`.
    /// On failure ``errorMessage`` is set and the sheet stays open for correction.
    ///
    /// - Parameter token: Bearer token for authorizing the request.
    /// - Note: Errors are written to ``errorMessage``; this method does not throw.
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

    /// Resets all create-form fields to their defaults; called only on successful creation.
    ///
    /// - Note: Not called on validation errors or network failures, so fields are preserved for correction.
    private func resetCreateForm() {
        newLedgerName          = ""
        newLedgerCurrency      = "MXN"
        newLedgerDecimalPlaces = 2
        useTemplate            = false
        selectedTemplate       = nil
    }
}

