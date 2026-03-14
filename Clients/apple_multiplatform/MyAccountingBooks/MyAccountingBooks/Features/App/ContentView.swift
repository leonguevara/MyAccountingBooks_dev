//
//  Features/App/ContentView.swift
//  ContentView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import SwiftUI

/// The main application shell displaying primary sections and a detail area.
///
/// Uses `NavigationSplitView` with a sidebar that lists ledgers and binds the
/// selection to `selectedLedger`. When a ledger is selected, the accounts tree
/// for that ledger is displayed in the detail pane. Provides a toolbar action
/// to sign out via `AuthService`.
struct ContentView: View {
    @Environment(AuthService.self) private var auth
    /// The currently selected ledger from the sidebar; drives the detail content.
    @State private var selectedLedger: LedgerResponse?
    @State private var selectedTransaction: TransactionResponse?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        /// Sidebar displaying ledgers and a detail area that shows the selected ledger's accounts tree.
        NavigationSplitView(columnVisibility: $columnVisibility) {
                // Column 1 — Ledger list
                LedgerListView(selectedLedger: $selectedLedger)
            } content: {
                
                // Column 2 — Transaction list (or account tree)
                if let ledger = selectedLedger {
                    TransactionListView(
                        ledger: ledger,
                        selectedTransaction: $selectedTransaction
                    )
                } else {
                    noLedgerSelected
                }
        } detail: {
            // Column 3 — Transaction detail
            if let tx = selectedTransaction,
               let ledger = selectedLedger {
                TransactionDetailView(transaction: tx, ledger: ledger)
            } else {
                noSelectionState
            }
        }
        /// Top-level toolbar providing a sign-out button.
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Sign Out") { auth.logout() }
            }
        }
    }
    
    // MARK: - Subviews
    
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

// MARK: - Ledger Detail Placeholder

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

