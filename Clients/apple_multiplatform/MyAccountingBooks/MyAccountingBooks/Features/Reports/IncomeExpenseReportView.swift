//
//  Features/Reports/IncomeExpenseReportView.swift
//  IncomeExpenseReportView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Displays up to 12 months of income/expense data as side-by-side vertical bars
/// (green = income, red = expenses), a three-KPI summary row, and a detail table.
/// Shows an empty state when `bars` is empty.
///
/// - SeeAlso: ``MonthlyBar``, ``ReportViewModel``
struct IncomeExpenseReportView: View {

    /// Monthly income/expense bars computed by ``ReportViewModel``; up to 12 entries, oldest first.
    let bars:   [MonthlyBar]
    /// The owning ledger; supplies `currencyCode` and `decimalPlaces` for amount formatting.
    let ledger: LedgerResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if bars.isEmpty {
                    emptyState
                } else {
                    summaryRow
                    chartSection
                    tableSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Summary KPI row

    /// Three KPI cards showing total income, total expenses, and net across all bars.
    private var summaryRow: some View {
        let totalIncome   = bars.reduce(Decimal.zero) { $0 + $1.income }
        let totalExpenses = bars.reduce(Decimal.zero) { $0 + $1.expenses }
        let net           = totalIncome - totalExpenses

        return HStack(spacing: 16) {
            kpiCard("Total Income",   totalIncome,   .green)
            kpiCard("Total Expenses", totalExpenses, .red)
            kpiCard("Net",            net,           net >= 0 ? .green : .red)
        }
    }

    // MARK: - Bar chart

    /// Grouped bar chart scaled to the maximum monthly value, with a color legend below.
    private var chartSection: some View {
        let maxVal = bars.flatMap { [$0.income, $0.expenses] }.max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Breakdown")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(bars) { bar in
                    monthColumn(bar: bar, maxVal: maxVal)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Legend
            HStack(spacing: 16) {
                legendDot(.green, "Income")
                legendDot(.red,   "Expenses")
            }
            .font(.caption)
        }
    }

    /// Two side-by-side bars (income/expense) for a single month, scaled relative to `maxVal`.
    private func monthColumn(bar: MonthlyBar, maxVal: Decimal) -> some View {
        let maxDouble  = Double(truncating: maxVal as NSDecimalNumber)
        let incDouble  = Double(truncating: bar.income   as NSDecimalNumber)
        let expDouble  = Double(truncating: bar.expenses as NSDecimalNumber)
        let incFrac    = maxDouble > 0 ? incDouble / maxDouble : 0
        let expFrac    = maxDouble > 0 ? expDouble / maxDouble : 0
        let barHeight  = 120.0

        return VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 10, height: barHeight * CGFloat(incFrac))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 10, height: barHeight * CGFloat(expFrac))
            }
            .frame(height: barHeight, alignment: .bottom)

            Text(bar.label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data table

    /// Tabular detail listing each month's income, expenses, and net, newest first.
    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Month")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Income")
                    .frame(width: 110, alignment: .trailing)
                Text("Expenses")
                    .frame(width: 110, alignment: .trailing)
                Text("Net")
                    .frame(width: 110, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ForEach(bars.reversed()) { bar in
                HStack {
                    Text(bar.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(fmt(bar.income))
                        .frame(width: 110, alignment: .trailing)
                        .foregroundStyle(.green)
                    Text(fmt(bar.expenses))
                        .frame(width: 110, alignment: .trailing)
                        .foregroundStyle(.red)
                    Text(fmt(bar.net))
                        .frame(width: 110, alignment: .trailing)
                        .foregroundStyle(bar.net >= 0 ? .green : .red)
                }
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)

                Divider().padding(.leading, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    /// Rounded card displaying a labelled amount in the given color.
    private func kpiCard(
        _ title: String,
        _ amount: Decimal,
        _ color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(fmt(amount))
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

    /// Small colored dot with a text label; used in the bar chart legend.
    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }

    /// Centered empty-state placeholder shown when `bars` is empty.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No income or expense transactions found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    /// Formats `amount` using `ledger.currencyCode` and `ledger.decimalPlaces` via ``AmountFormatter``.
    private func fmt(_ amount: Decimal) -> String {
        AmountFormatter.format(
            amount,
            currencyCode:  ledger.currencyCode,
            decimalPlaces: ledger.decimalPlaces
        )
    }
}
