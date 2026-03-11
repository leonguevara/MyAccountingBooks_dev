//
//  Features/Ledgers/LedgerListView.swift
//  LedgerListView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11.
//  Developed with AI assistance.
//

import SwiftUI

/// Displays a list of ledgers with loading, empty, and error states.
///
/// Binds to a `LedgerListViewModel` to load data and create new ledgers.
/// Requires an `AuthService` in the environment to obtain the auth token.
///
/// Usage:
/// ```swift
/// @State private var selected: LedgerResponse?
/// LedgerListView(selectedLedger: $selected)
///     .environment(AuthService())
/// ```
struct LedgerListView: View {

    /// Authentication service used to fetch the token for network operations.
    @Environment(AuthService.self) private var auth
    /// The view model managing ledger data and create form state.
    @State private var viewModel = LedgerListViewModel()
    
    /// The currently selected ledger — bound from the parent NavigationSplitView.
    /// When set, the selection drives the detail view in the split interface.
    @Binding var selectedLedger: LedgerResponse?

    var body: some View {
        /// Top-level content that switches between loading, empty, and list states.
        Group {
            if viewModel.isLoading && viewModel.ledgers.isEmpty {
                ProgressView("Loading ledgers…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.ledgers.isEmpty {
                emptyState
            } else {
                ledgerList
            }
        }
        .navigationTitle("Ledgers")
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.showCreateSheet) { createSheet }
        .task {
            guard let token = auth.token else { return }
            await viewModel.loadLedgers(token: token)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    /// The primary list of ledgers with selection support.
    private var ledgerList: some View {
        List(viewModel.ledgers, selection: $selectedLedger) { ledger in
            LedgerRowView(ledger: ledger)
                .tag(ledger)
        }
    }

    /// A placeholder view shown when no ledgers are available.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Ledgers Yet")
                .font(.headline)
            Text("Create your first ledger to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Create Ledger") { viewModel.showCreateSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Toolbar content providing an action to create a new ledger.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("New Ledger", systemImage: "plus")
            }
        }
    }

    /// Sheet presenting the create-ledger form bound to the view model.
    private var createSheet: some View {
        CreateLedgerSheet(viewModel: viewModel)
    }
}

// MARK: - Ledger Row

/// A single row representing a ledger in the list.
private struct LedgerRowView: View {
    let ledger: LedgerResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ledger.name)
                .font(.headline)
            HStack(spacing: 8) {
                Label(ledger.currencyCode, systemImage: "banknote")
                Text("·")
                Text("\(ledger.decimalPlaces) decimal places")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Ledger Sheet

/// A form used to create a new ledger, bound to the parent view model's fields.
private struct CreateLedgerSheet: View {

    @Bindable var viewModel: LedgerListViewModel
    @Environment(AuthService.self) private var auth

    var body: some View {
        NavigationStack {
            Form {
                Section("Ledger Details") {
                    TextField("Name", text: $viewModel.newLedgerName)
                    TextField("Currency (e.g. MXN, USD)", text: $viewModel.newLedgerCurrency)
                        .autocorrectionDisabled()
                    Stepper(
                        "Decimal places: \(viewModel.newLedgerDecimalPlaces)",
                        value: $viewModel.newLedgerDecimalPlaces,
                        in: 0...8
                    )
                }

                Section {
                    TextField("Template code (optional)", text: $viewModel.newLedgerTemplateCode)
                        .autocorrectionDisabled()
                    TextField("Template version (optional)", text: $viewModel.newLedgerTemplateVersion)
                        .autocorrectionDisabled()
                } header: {
                    Text("Chart of Accounts Template")
                } footer: {
                    Text("Leave blank to create an empty ledger with no accounts.")
                        .font(.caption)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Ledger")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            guard let token = auth.token else { return }
                            await viewModel.createLedger(token: token)
                        }
                    }
                    .disabled(viewModel.newLedgerName.trimmingCharacters(in: .whitespaces).isEmpty
                              || viewModel.isLoading)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 380)
    }
}

