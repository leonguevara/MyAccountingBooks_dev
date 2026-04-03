//
//  Features/Reports/ReportsView.swift
//  ReportsView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Sheet presenting three segmented report tabs for a ledger.
///
/// Shares a single ``ReportViewModel`` across ``NetWorthReportView``,
/// ``IncomeExpenseReportView``, and ``SpendingByCategoryReportView``.
/// Data is loaded once in `.task` and an error state with a Retry button
/// is shown if the fetch fails.
///
/// - SeeAlso: ``ReportViewModel``, ``AccountTreeView``
struct ReportsView: View {

    // MARK: - Input

    /// The ledger whose data is reported.
    let ledger:   LedgerResponse
    /// Account tree roots passed to ``ReportViewModel`` for net-worth rollup.
    let roots:    [AccountNode]
    /// Rolled-up balance map from ``AccountTreeViewModel``.
    let balances: BalanceMap

    // MARK: - Environment

    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss)        private var dismiss

    // MARK: - State

    /// Shared view model loaded once for all three report tabs.
    @State private var viewModel    = ReportViewModel()
    /// Index of the currently selected segmented tab (0 = Net Worth, 1 = Income & Expenses, 2 = Spending).
    @State private var selectedTab  = 0

    private let tabs = ["Net Worth", "Income & Expenses", "Spending"]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar ────────────────────────────────────────────────
            HStack {
                Text("Reports — \(ledger.name)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Tab picker ────────────────────────────────────────────────
            Picker("Report", selection: $selectedTab) {
                ForEach(tabs.indices, id: \.self) { idx in
                    Text(tabs[idx]).tag(idx)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // ── Content ───────────────────────────────────────────────────
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading report data…")
                Spacer()

            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            guard let token = auth.token else { return }
                            await viewModel.load(
                                ledger:   ledger,
                                roots:    roots,
                                balances: balances,
                                token:    token
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(40)
                Spacer()

            } else {
                Group {
                    switch selectedTab {
                    case 0:
                        NetWorthReportView(
                            summary:  viewModel.netWorth,
                            ledger:   ledger
                        )
                    case 1:
                        IncomeExpenseReportView(
                            bars:   viewModel.monthlyBars,
                            ledger: ledger
                        )
                    default:
                        SpendingByCategoryReportView(
                            spends: viewModel.categorySpends,
                            ledger: ledger
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .task {
            guard let token = auth.token else { return }
            await viewModel.load(
                ledger:   ledger,
                roots:    roots,
                balances: balances,
                token:    token
            )
        }
    }
}
