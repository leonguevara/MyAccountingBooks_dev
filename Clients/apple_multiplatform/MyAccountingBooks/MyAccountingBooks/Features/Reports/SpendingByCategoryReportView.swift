//
//  Features/Reports/SpendingByCategoryReportView.swift
//  SpendingByCategoryReportView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Ranked horizontal bar chart of spending by second-level Expense category.
///
/// Shows a two-KPI summary card (total spending + category count) above a list of
/// ``CategorySpend`` rows, each with a name, amount, gradient bar, and percentage of total.
/// Shows an empty state when `spends` is empty.
///
/// - SeeAlso: ``CategorySpend``, ``ReportViewModel``
struct SpendingByCategoryReportView: View {

    /// Category spending totals from ``ReportViewModel``; sorted descending by amount.
    let spends: [CategorySpend]
    /// The owning ledger; supplies `currencyCode` and `decimalPlaces` for amount formatting.
    let ledger: LedgerResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if spends.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    chartSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Summary card

    /// Two KPI cards showing total spending and the number of distinct categories.
    private var summaryCard: some View {
        let total = spends.reduce(Decimal.zero) { $0 + $1.amount }

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total Spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(fmt(total))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("Categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(spends.count)")
                    .font(.title2.bold())
            }
            .frame(width: 120, alignment: .leading)
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Horizontal bar chart

    /// Ranked list of ``CategorySpend`` rows with a gradient horizontal bar scaled to the largest category.
    private var chartSection: some View {
        let total  = spends.reduce(Decimal.zero) { $0 + $1.amount }
        let maxAmt = spends.first?.amount ?? 1    // already sorted descending

        return VStack(alignment: .leading, spacing: 0) {
            Text("By Category")
                .font(.headline)
                .padding(.bottom, 12)

            ForEach(spends) { item in
                categoryRow(item: item, total: total, maxAmt: maxAmt)
                Divider().padding(.leading, 0)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Single category row with name, amount, gradient bar scaled relative to `maxAmt`, and percentage of `total`.
    private func categoryRow(
        item:   CategorySpend,
        total:  Decimal,
        maxAmt: Decimal
    ) -> some View {
        let fraction = maxAmt > 0
            ? Double(truncating: (item.amount / maxAmt) as NSDecimalNumber)
            : 0
        let pct = total > 0
            ? Double(truncating: (item.amount / total * 100) as NSDecimalNumber)
            : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(fmt(item.amount))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.red)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.7), .orange.opacity(0.6)],
                                startPoint: .leading,
                                endPoint:   .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(fraction),
                            height: 10
                        )
                }
            }
            .frame(height: 10)

            Text(String(format: "%.1f%% of total spending", pct))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    /// Centered empty-state placeholder shown when `spends` is empty.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No expense transactions found.")
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
