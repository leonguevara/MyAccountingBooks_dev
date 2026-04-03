//
//  Features/Reports/NetWorthReportView.swift
//  NetWorthReportView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Displays three KPI cards (Assets, Liabilities, Net Worth), a proportional asset/liability bar,
/// and individual breakdown rows for each section. Shows an empty state when `summary` is `nil`.
///
/// - SeeAlso: ``NetWorthSummary``, ``ReportViewModel``
struct NetWorthReportView: View {

    /// Net worth data computed by ``ReportViewModel``; `nil` until loading completes.
    let summary: NetWorthSummary?
    /// The owning ledger; supplies `currencyCode` and `decimalPlaces` for amount formatting.
    let ledger:  LedgerResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if let s = summary {
                    // ── KPI Cards ─────────────────────────────────────────
                    HStack(spacing: 16) {
                        kpiCard(
                            title:  "Total Assets",
                            amount: s.totalAssets,
                            color:  .blue
                        )
                        kpiCard(
                            title:  "Total Liabilities",
                            amount: s.totalLiabilities,
                            color:  .orange
                        )
                        kpiCard(
                            title:  "Net Worth",
                            amount: s.netWorth,
                            color:  s.netWorth >= 0 ? .green : .red
                        )
                    }

                    // ── Proportional Bar ──────────────────────────────────
                    if s.totalAssets > 0 || s.totalLiabilities > 0 {
                        proportionalBar(summary: s)
                    }

                    // ── Breakdown List ────────────────────────────────────
                    breakdownSection(
                        title:  "Assets",
                        amount: s.totalAssets,
                        color:  .blue
                    )
                    breakdownSection(
                        title:  "Liabilities",
                        amount: s.totalLiabilities,
                        color:  .orange
                    )

                } else {
                    emptyState
                }
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    /// Rounded card displaying a labelled amount in the given color.
    private func kpiCard(
        title:  String,
        amount: Decimal,
        color:  Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatted(amount))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Horizontal two-segment bar showing the asset fraction (blue) and liability fraction (orange).
    private func proportionalBar(summary: NetWorthSummary) -> some View {
        let total  = summary.totalAssets + summary.totalLiabilities
        let aFrac  = total > 0 ? Double(truncating: (summary.totalAssets / total) as NSDecimalNumber) : 0.5

        return VStack(alignment: .leading, spacing: 6) {
            Text("Assets vs Liabilities")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(aFrac))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24)

            HStack {
                legendDot(.blue,   "Assets")
                Spacer()
                legendDot(.orange, "Liabilities")
            }
            .font(.caption)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Single-row card with a section title and its total amount right-aligned.
    private func breakdownSection(
        title:  String,
        amount: Decimal,
        color:  Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(formatted(amount))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(color)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Small colored dot with a text label; used in the proportional bar legend.
    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }

    /// Centered empty-state placeholder shown when `summary` is `nil`.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No balance data available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Formatting

    /// Formats `amount` using `ledger.currencyCode` and `ledger.decimalPlaces` via ``AmountFormatter``.
    private func formatted(_ amount: Decimal) -> String {
        AmountFormatter.format(
            amount,
            currencyCode:  ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }
}
