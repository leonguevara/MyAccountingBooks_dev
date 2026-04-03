//
//  Features/Reports/ReportViewModel.swift
//  ReportViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import Foundation

// MARK: - Supporting Types

/// A single bar in the Income vs Expenses chart.
struct MonthlyBar: Identifiable {
    let id = UUID()
    /// Display label, e.g. `"Jan 26"`.
    let label: String
    /// Total income for the month (always positive).
    let income: Decimal
    /// Total expenses for the month (always positive).
    let expenses: Decimal
    /// `income − expenses`; positive = surplus, negative = deficit.
    var net: Decimal { income - expenses }
}

/// A single row in the Spending by Category chart.
struct CategorySpend: Identifiable {
    let id = UUID()
    /// Second-level expense account name used as the category label.
    let name: String
    /// Total amount spent in this category (always positive).
    let amount: Decimal
}

/// Net worth snapshot broken into assets, liabilities, and net worth.
struct NetWorthSummary {
    /// Sum of all asset account balances.
    let totalAssets:      Decimal
    /// Sum of all liability account balances.
    let totalLiabilities: Decimal
    /// `totalAssets − totalLiabilities`.
    var netWorth: Decimal { totalAssets - totalLiabilities }
}

// MARK: - ViewModel

/// Shared view model for all report views.
///
/// Fetches transactions and accounts in parallel via ``load(ledger:roots:balances:token:)``,
/// then populates ``netWorth``, ``monthlyBars``, and ``categorySpends`` using pure Swift
/// computation — no additional backend endpoints beyond those already in use.
///
/// - SeeAlso: ``ReportsView``, ``NetWorthSummary``, ``MonthlyBar``, ``CategorySpend``
@Observable
final class ReportViewModel {

    // MARK: - State

    /// `true` while the parallel transaction/account fetch is in progress.
    var isLoading   = false
    /// Localized error message set on fetch failure; `nil` when no error is present.
    var errorMessage: String?

    /// Net worth snapshot; `nil` until ``load(ledger:roots:balances:token:)`` completes.
    var netWorth:       NetWorthSummary?
    /// Monthly income/expense bars for the last 12 months with data, oldest first.
    var monthlyBars:    [MonthlyBar]    = []
    /// Spending totals grouped by second-level expense category, sorted descending.
    var categorySpends: [CategorySpend] = []

    // MARK: - Private storage

    /// Full transaction list fetched in ``load(ledger:roots:balances:token:)``.
    private var transactions: [TransactionResponse]   = []
    /// Flat UUID-to-`AccountResponse` map built from the fetched account list.
    private var accountMap:   [UUID: AccountResponse] = [:]

    // MARK: - Load

    /// Fetches transactions and accounts in parallel, then populates all three report properties.
    ///
    /// Accounts are fetched independently (not from `roots`) in case the tree is still loading
    /// when the report sheet opens.
    ///
    /// - Parameters:
    ///   - ledger:   Ledger context supplying `id` and `decimalPlaces`.
    ///   - roots:    Account tree roots from ``AccountTreeViewModel``; used for net-worth rollup.
    ///   - balances: Rolled-up balance map from ``AccountTreeViewModel``.
    ///   - token:    Bearer token for the API requests.
    @MainActor
    func load(
        ledger:   LedgerResponse,
        roots:    [AccountNode],
        balances: BalanceMap,
        token:    String
    ) async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        do {
            // Fetch transactions and accounts in parallel — both are needed.
            // Accounts are fetched independently rather than relying on the
            // passed-in `roots`, which may be empty if the tree has not yet
            // loaded when the report sheet opens.
            async let txFetch: [TransactionResponse] = APIClient.shared.request(
                .transactions(ledgerID: ledger.id),
                method: "GET",
                token:  token
            )
            async let acctFetch: [AccountResponse] = APIClient.shared.request(
                .accounts(ledgerID: ledger.id),
                method: "GET",
                token:  token
            )

            transactions = try await txFetch
            let flatAccounts = try await acctFetch

            // Build a flat UUID → AccountResponse map for kind resolution.
            accountMap = Dictionary(
                uniqueKeysWithValues: flatAccounts.map { ($0.id, $0) }
            )

            // Compute each report from the loaded data.
            netWorth       = computeNetWorth(balances: balances, roots: roots)
            monthlyBars    = computeMonthlyBars(ledger: ledger)
            categorySpends = computeCategorySpends(ledger: ledger)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Net Worth

    /// Recursively sums kind-1 (Asset) and kind-2 (Liability) balances from the rolled-up map.
    private func computeNetWorth(
        balances: BalanceMap,
        roots:    [AccountNode]
    ) -> NetWorthSummary {

        var assets:      Decimal = .zero
        var liabilities: Decimal = .zero

        func walk(_ nodes: [AccountNode]) {
            for node in nodes {
                let bal = balance(for: node.id, in: balances)
                switch node.account.kind {
                case 1: assets      += abs(bal)
                case 2: liabilities += abs(bal)
                default: break
                }
                walk(node.children)
            }
        }
        walk(roots)

        return NetWorthSummary(
            totalAssets:      assets,
            totalLiabilities: liabilities
        )
    }

    // MARK: - Income vs Expenses

    /// Groups non-voided splits by calendar month; sums Income (kind 4) credits and Expense/COS (kind 5/6) debits.
    ///
    /// - Returns: Up to 12 months with data, sorted oldest-first.
    private func computeMonthlyBars(ledger: LedgerResponse) -> [MonthlyBar] {
        let denom = pow(10.0, Double(ledger.decimalPlaces))

        // Accumulate per month-key (yyyyMM)
        var incomeByMonth:  [String: Decimal] = [:]
        var expenseByMonth: [String: Decimal] = [:]
        var labelByMonth:   [String: String]  = [:]

        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yy"   // e.g. "Jan 26"

        for tx in transactions where !tx.isVoided {
            let date     = tx.postDate
            let year     = cal.component(.year,  from: date)
            let month    = cal.component(.month, from: date)
            let key      = String(format: "%04d%02d", year, month)
            labelByMonth[key] = fmt.string(from: date)

            for split in tx.splits {
                guard let acct = accountMap[split.accountId] else { continue }
                let amount = Decimal(split.valueNum) / Decimal(denom)

                switch acct.kind {
                case 4 where split.side == 1:       // Income credit
                    incomeByMonth[key,  default: .zero] += amount
                case 5 where split.side == 0,       // Expense debit
                     6 where split.side == 0:       // CostOfSales debit
                    expenseByMonth[key, default: .zero] += amount
                default: break
                }
            }
        }

        // Merge all keys and sort chronologically
        let allKeys = Set(incomeByMonth.keys).union(expenseByMonth.keys).sorted()

        // Limit to last 12 months
        let displayKeys = Array(allKeys.suffix(12))

        return displayKeys.map { key in
            MonthlyBar(
                label:    labelByMonth[key] ?? key,
                income:   incomeByMonth[key]  ?? .zero,
                expenses: expenseByMonth[key] ?? .zero
            )
        }
    }

    // MARK: - Spending by Category

    /// Groups Expense/COS (kind 5/6) debits by second-level category name; sorted descending by amount.
    private func computeCategorySpends(ledger: LedgerResponse) -> [CategorySpend] {
        let denom = pow(10.0, Double(ledger.decimalPlaces))

        var spendByCategory: [String: Decimal] = [:]

        for tx in transactions where !tx.isVoided {
            for split in tx.splits where split.side == 0 {
                guard let acct = accountMap[split.accountId],
                      acct.kind == 5 || acct.kind == 6 else { continue }

                let rootName = topLevelName(for: acct)
                let amount   = Decimal(split.valueNum) / Decimal(denom)
                spendByCategory[rootName, default: .zero] += amount
            }
        }

        return spendByCategory
            .map { CategorySpend(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Private helpers

    /// Converts a ``BalanceMap`` entry to `Decimal`; returns `.zero` for missing or zero-denom entries.
    private func balance(for id: UUID, in balances: BalanceMap) -> Decimal {
        guard let entry = balances[id], entry.balanceDenom != 0 else { return .zero }
        return Decimal(entry.balanceNum) / Decimal(entry.balanceDenom)
    }

    /// Returns the second-level expense category name for `account`.
    ///
    /// Climbs the parent chain while the grandparent is still an expense account,
    /// stopping one level before the root (e.g., returns `"Alimentos"` rather than `"Egresos"`).
    private func topLevelName(for account: AccountResponse) -> String {
        var current = account

        while let parentId = current.parentId,
              let parent = accountMap[parentId],
              (parent.kind == 5 || parent.kind == 6) {

            // Stop climbing if the parent's own parent is NOT an expense
            // account — that means `parent` is the root ("Egresos") and
            // `current` is already the useful category level.
            if let grandParentId = parent.parentId,
               let grandParent = accountMap[grandParentId],
               (grandParent.kind == 5 || grandParent.kind == 6) {
                // Grandparent is still expense — safe to keep climbing.
                current = parent
            } else {
                // Parent is the root expense account — stop here.
                break
            }
        }

        return current.name
    }
}
