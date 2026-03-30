//
//  Features/Ledgers/LedgerListView.swift
//  LedgerListView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11.
//  Last modified by León Felipe Guevara Chávez on 2026-03-21.
//  Developed with AI assistance.
//

import SwiftUI

/// A view displaying the list of available ledgers with session persistence and creation support.
///
/// `LedgerListView` presents the user's ledgers in a list format with full session management:
/// - Loads ledgers from the backend on appear
/// - Automatically restores the last selected ledger from session storage
/// - Saves ledger selection changes to persist across app launches
/// - Provides UI for creating new ledgers with optional COA templates
/// - Handles loading, empty, and error states gracefully
///
/// ## Features
/// - **Ledger List**: Displays all available ledgers with currency and precision info
/// - **Selection Management**: Binds to parent's `selectedLedger` for split view coordination
/// - **Session Persistence**: Automatically saves and restores ledger selection
/// - **Create Ledger**: Sheet-based form for creating new ledgers with optional COA templates
/// - **Empty State**: Helpful placeholder when no ledgers exist
/// - **Error Handling**: Displays errors in alerts
///
/// ## Session Management
///
/// **Saving selection:**
/// - When the user selects a ledger it is written to ``SessionStore``
/// - Persists across app launches and restarts
///
/// **Restoring selection:**
/// - On load, ``LedgerListViewModel`` checks ``SessionStore`` for the last selected ledger ID
/// - If found and still present in the list, it is automatically reselected
/// - Happens transparently via `viewModel.restoredLedger` observation
///
/// ## Usage Example
///
/// ```swift
/// struct ContentView: View {
///     @State private var selectedLedger: LedgerResponse?
///     @Environment(AuthService.self) private var auth
///
///     var body: some View {
///         NavigationSplitView {
///             LedgerListView(selectedLedger: $selectedLedger)
///         } detail: {
///             if let ledger = selectedLedger {
///                 LedgerDetailView(ledger: ledger)
///             } else {
///                 Text("Select a ledger")
///             }
///         }
///         .environment(auth)
///     }
/// }
/// ```
///
/// ## State Flow
///
/// 1. **On appear**: ``LedgerListViewModel/loadLedgers(token:)`` is called via `.task`
/// 2. **After load**: If the last selected ledger exists, `restoredLedger` is set
/// 3. **Restoration**: `onChange(of: restoredLedger)` applies the selection
/// 4. **Selection change**: `onChange(of: selectedLedger)` saves to ``SessionStore``
/// 5. **On next launch**: Process repeats, restoring the saved selection
///
/// - Important: Requires ``AuthService`` in the environment to obtain the authentication token.
/// - Note: Selection is only restored if the ledger still exists in the loaded list.
/// - SeeAlso: ``LedgerListViewModel``, ``SessionStore``
struct LedgerListView: View {

    // MARK: - Properties
    
    /// Authentication service used to obtain the bearer token for network operations.
    ///
    /// Required for loading ledgers and creating new ledgers. Accessed from the environment.
    @Environment(AuthService.self) private var auth
    
    /// The view model managing ledger data, loading state, and create form.
    ///
    /// Handles all business logic including fetching ledgers, session restoration,
    /// and ledger creation workflows.
    @State private var viewModel = LedgerListViewModel()
    
    /// The currently selected ledger, bound from the parent `NavigationSplitView`.
    ///
    /// When this value changes:
    /// - The selection drives the detail view in the split interface
    /// - The ledger ID is written to ``SessionStore`` for persistence across launches
    ///
    /// When ledgers are loaded:
    /// - If a previous selection is found in ``SessionStore`` and still exists in the list,
    ///   this binding is automatically updated to restore the selection
    @Binding var selectedLedger: LedgerResponse?

    // MARK: - Body
    
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
        // Save ledger selection to session storage for persistence across app launches
        .onChange(of: selectedLedger) { _, newLedger in
            if let ledger = newLedger {
                SessionStore.shared.saveLastLedger(id: ledger.id)
            }
        }
        // Apply restored ledger selection after load completes
        // Only applies if no ledger is currently selected (prevents overriding user choice)
        .onChange(of: viewModel.restoredLedger) { _, restored in
            if let ledger = restored, selectedLedger == nil {
                selectedLedger = ledger
            }
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
    ///
    /// Uses a standard SwiftUI `List` with the `selection` parameter bound to `selectedLedger`.
    /// Each row is tagged with the ledger object to enable selection tracking in the split view.
    private var ledgerList: some View {
        List(viewModel.ledgers, selection: $selectedLedger) { ledger in
            LedgerRowView(ledger: ledger)
                .tag(ledger)
        }
    }

    /// A placeholder view shown when no ledgers are available.
    ///
    /// Displays a friendly empty state with:
    /// - Book icon indicating ledger context
    /// - Helpful message explaining the empty state
    /// - Primary action button to create the first ledger
    ///
    /// This view is shown after loading completes with zero ledgers.
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
    ///
    /// Displays a + button in the toolbar's primary action area that opens
    /// the create ledger sheet when tapped.
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

    /// Sheet presenting the create ledger form bound to the view model.
    ///
    /// Form fields are bound to `viewModel.newLedger*` properties, delegating
    /// validation and submission to ``LedgerListViewModel/createLedger(token:)``.
    private var createSheet: some View {
        CreateLedgerSheet(viewModel: viewModel)
    }
}

// MARK: - Ledger Row

/// A single row view representing a ledger in the list.
///
/// Displays:
/// - **Ledger name**: Primary heading showing the ledger's display name
/// - **Currency code**: With banknote icon (e.g., `"MXN"`, `"USD"`)
/// - **Decimal places**: Precision setting for monetary amounts
///
/// Used within ``LedgerListView`` to provide a consistent, scannable summary of
/// each ledger's key attributes.
private struct LedgerRowView: View {
    /// The ledger to display in this row.
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

/// A sheet-based form for creating a new ledger with an optional chart of accounts template.
///
/// ## Form Fields
///
/// **Required:**
/// - **Name**: The ledger's display name (validated, cannot be empty)
/// - **Currency**: Currency code (e.g., `"MXN"`, `"USD"`) — converted to uppercase
/// - **Decimal places**: Precision for amounts (0–8, default: 2)
///
/// **Optional (COA Template):**
/// - A `Toggle` reveals a `Picker` populated from `viewModel.availableTemplates`
/// - When a template is selected its `code` and `version` are forwarded to the creation request
/// - When the toggle is off the ledger is created with an empty chart of accounts
///
/// ## Validation
///
/// - Name must not be empty after whitespace trimming
/// - Create button is disabled while `viewModel.isLoading` is `true`
/// - Errors are displayed inline in a dedicated `Form` section
///
/// ## Outcome
///
/// **On success**: new ledger is appended to the list, form is reset, sheet is dismissed.
///
/// **On failure**: `errorMessage` is shown in the form; sheet stays open for correction.
///
/// - Note: Form fields are bound directly to ``LedgerListViewModel`` for seamless state management.
/// - SeeAlso: ``LedgerListViewModel/createLedger(token:)``, ``CoaTemplateItem``
private struct CreateLedgerSheet: View {

    /// The view model containing form state and creation logic.
    @Bindable var viewModel: LedgerListViewModel
    
    /// Authentication service to obtain the bearer token for the create request.
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
                    Toggle("Use a chart of accounts template", isOn: $viewModel.useTemplate)
                        .onChange(of: viewModel.useTemplate) { _, on in
                            if !on { viewModel.selectedTemplate = nil }
                        }

                    if viewModel.useTemplate {
                        Picker("Template", selection: $viewModel.selectedTemplate) {
                            Text("Select a template…").tag(Optional<CoaTemplateItem>.none)
                            ForEach(viewModel.availableTemplates) { template in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.displayName)
                                    if let desc = template.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tag(Optional(template))
                            }
                        }
                    }
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

