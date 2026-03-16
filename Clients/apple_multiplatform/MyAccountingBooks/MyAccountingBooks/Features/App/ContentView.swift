//
//  Features/App/ContentView.swift
//  ContentView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import SwiftUI

/// The main application shell displaying a split layout (ledgers → account tree).
///
/// Uses `NavigationSplitView` with:
/// - Sidebar (Column 1): A list of ledgers with selection bound to `selectedLedger`.
/// - Detail (Column 2): An account tree (`AccountTreeView`) for the selected ledger.
///
/// Notes:
/// - Account register windows are opened independently from `AccountTreeView` (double-click on a leaf node).
/// - The previous transactions/transaction-detail flow is no longer presented here.
struct ContentView: View {
    @Environment(AuthService.self) private var auth
    /// The currently selected ledger from the sidebar; drives the transaction list.
    @State private var selectedLedger: LedgerResponse?
    /// UNUSED in current layout: transaction selection is not presented in this view.
    @State private var selectedTransaction: TransactionResponse?
    /// Controls the visibility of the split view columns.
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        /// Two-column split: Ledgers (sidebar) and Account Tree (detail).
        NavigationSplitView(columnVisibility: $columnVisibility) {

            // ── Column 1 — Ledger list ────────────────────────────────────
            LedgerListView(selectedLedger: $selectedLedger)

        } detail: {

            // ── Column 2 — Account tree for selected ledger ───────────────
            if let ledger = selectedLedger {
                AccountTreeView(ledger: ledger)
            } else {
                noSelectionState
            }
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Sign Out") { auth.logout() }
            }
        }
        .onChange(of: selectedLedger) {
            // Nothing to reset — register windows are independent
        }
    }
    
    // MARK: - Subviews
    
    // UNUSED: This helper is not referenced in the current layout.
    private var noLedgerSelected: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a Ledger")
                .font(.headline)
            Text("Choose a ledger from the sidebar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Placeholder content shown when no ledger is selected.
    private var noSelectionState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Select a Transaction")
                .font(.headline)
            Text("Choose a transaction to view its splits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// UNUSED: This placeholder is not used in the current layout (account tree is shown instead).
/// Temporary placeholder that displays basic info for the selected ledger.
private struct LedgerDetailPlaceholder: View {
    let ledger: LedgerResponse

    var body: some View {
        VStack(spacing: 8) {
            Text(ledger.name)
                .font(.largeTitle).bold()
            Text(ledger.currencyCode)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Account tree coming in next iteration.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(ledger.name)
    }
}

