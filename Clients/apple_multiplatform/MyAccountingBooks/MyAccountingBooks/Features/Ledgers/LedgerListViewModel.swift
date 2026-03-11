//
//  Features/Ledgers/LedgerListViewModel.swift
//  LedgerListViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11
//  Developed with AI assistance.
//

import Foundation

/// Manages state and business logic for the Ledger list screen.
///
/// Holds the list of ledgers, loading/error state, and create-ledger form fields.
/// Interacts with `LedgerService` to fetch and create ledgers.
///
/// Usage (SwiftUI):
///
/// ```swift
/// @State private var vm = LedgerListViewModel()
/// @Environment(AuthService.self) private var auth
///
/// var body: some View {
///     List(vm.ledgers) { ledger in
///         Text(ledger.name)
///     }
///     .task {
///         if let token = auth.token {
///             await vm.loadLedgers(token: token)
///         }
///     }
///     .sheet(isPresented: $vm.showCreateSheet) {
///         // present create form bound to vm.newLedger* fields
///     }
/// }
/// ```
@Observable
final class LedgerListViewModel {

    // MARK: - State

    /// The current list of ledgers to display.
    var ledgers: [LedgerResponse] = []
    /// Indicates whether a network operation is in progress.
    var isLoading = false
    /// An optional error message to present when operations fail.
    var errorMessage: String?
    /// Controls presentation of the create-ledger sheet.
    var showCreateSheet = false

    // MARK: - Create Form State

    /// The name input for a new ledger.
    var newLedgerName = ""
    /// The currency mnemonic input for a new ledger (e.g., "USD").
    var newLedgerCurrency = "MXN"
    /// The decimal places input for amounts in the new ledger.
    var newLedgerDecimalPlaces = 2
    /// Optional: A chart-of-accounts template code.
    var newLedgerTemplateCode = ""
    /// Optional: The version of the chart-of-accounts template.
    var newLedgerTemplateVersion = ""

    // MARK: - Dependencies

    /// Service used to perform ledger-related network operations.
    private let service = LedgerService.shared

    // MARK: - Load

    /// Loads ledgers using the provided token, updating loading and error state as needed.
    /// - Parameter token: A bearer token used to authorize the request.
    ///
    /// Example:
    /// ```swift
    /// if let token = auth.token { await vm.loadLedgers(token: token) }
    /// ```
    @MainActor
    func loadLedgers(token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            ledgers = try await service.fetchLedgers(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Create

    /// Creates a ledger from the current form fields and updates the list on success.
    /// - Parameter token: A bearer token used to authorize the request.
    ///
    /// Example:
    /// ```swift
    /// await vm.createLedger(token: token)
    /// ```
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

    /// Resets the create-ledger form fields to their default values.
    private func resetCreateForm() {
        newLedgerName = ""
        newLedgerCurrency = "MXN"
        newLedgerDecimalPlaces = 2
        newLedgerTemplateCode = ""
        newLedgerTemplateVersion = ""
    }
}

