//
//  Core/Models/AccountRole.swift
//  AccountRole.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-28.
//  Developed with AI assistance.
//

// Generated update: finer-grained financial roles (RIF / SAT 700s).
//
// Notes:
// - Keep raw values stable once shipped. New cases are appended in a dedicated range.
// - Roles are "system intent" (analytics, UX, automations), not fiscal mapping.
// - SAT mapping should remain in ledger_account_sat_map (per-ledger), not here.

import Foundation

/// Defines the functional (operational) intent of an account within the system.
///
/// `AccountRole` is one of three orthogonal dimensions used to classify accounts —
/// the others being `AccountKind` (accounting nature: Asset, Liability, etc.) and
/// `accountTypeCode` (functional type: BANK, CASH, AP…). Do not conflate them.
///
/// Roles express *system intent* for analytics, UX automation, and reporting.
/// They are **not** a fiscal or SAT classification — SAT mapping belongs in
/// `ledger_account_sat_map` (per-ledger), not here.
///
/// ## Raw Value Contract
/// Raw values are persisted as `Int16` in PostgreSQL and across all platforms
/// (Swift / Java / Kotlin). **Never change an existing raw value once shipped.**
/// New cases must be appended in a dedicated, previously unused range.
///
/// ## Range Layout
/// | Range     | Classification          |
/// |-----------|-------------------------|
/// | 0         | Unspecified / generic   |
/// | 100–199   | Assets                  |
/// | 200–299   | Liabilities             |
/// | 300–399   | Equity                  |
/// | 400–499   | Income                  |
/// | 500–599   | Cost of Sales           |
/// | 600–699   | Expenses                |
/// | 700, 800  | Memorandum / Off-balance |
/// | 900–999   | Statistical             |
/// | 4300–4399 | Financial result (RIF)  |
///
/// The 4300+ range was introduced for RIF / SAT 700-series financial result roles.
/// These cases refine income or expense accounts without changing `AccountKind`.
public enum AccountRole: Int16, Codable, CaseIterable, Sendable {

    // MARK: - Generic
    case unspecified = 0

    // MARK: - Assets (100s range)
    case cashAndCashEquivalents = 100
    case bank = 101
    case accountsReceivable = 110
    case inventory = 120
    case fixedAssets = 130
    case accumulatedDepreciation = 131
    case otherAssets = 199

    // MARK: - Liabilities (200s range)
    case accountsPayable = 200
    case taxesPayable = 210
    case loansPayable = 220
    case otherLiabilities = 299

    // MARK: - Equity (300s range)
    case capital = 300
    case retainedEarnings = 310
    case currentYearResult = 320

    // MARK: - Income (400s range)
    case salesRevenue = 400
    case serviceRevenue = 410
    case workRevenue = 420
    case rentalRevenue = 430
    case otherIncome = 499

    // MARK: - Cost of Sales (500s range)
    case costOfGoodsSold = 500
    case costOfServices = 510

    // MARK: - Expenses (600s range)
    case operatingExpense = 600
    case administrativeExpense = 610
    case sellingExpense = 620
    case otherExpense = 699

    // MARK: - Memorandum / Off-balance (700/800 classic bookkeeping)
    // In SAT 2025, 800s are memorandum accounts. SAT 700s are financial result (RIF), handled below.
    case memorandumDebit = 700
    case memorandumCredit = 800

    // MARK: - Financial result roles (RIF / SAT 700s) (4300+ dedicated range)
    // These roles refine financial income/expense without changing AccountKind (income vs expense).
    case financialIncome = 4300
    case financialExpense = 4301

    case interestIncome = 4310
    case interestExpense = 4311

    case fxGain = 4320
    case fxLoss = 4321

    case inflationGain = 4330
    case inflationLoss = 4331

    case bankFeesIncome = 4340
    case bankFeesExpense = 4341

    case otherFinancialIncome = 4390
    case otherFinancialExpense = 4391

    // MARK: - Statistical (optional) (900s range)
    case kpi = 900
    
    /// A human-readable label for this role, including its raw value in parentheses.
    ///
    /// Intended for UI display (pickers, form labels, debug output). The format is
    /// `"<Classification> — <Description> (<rawValue>)"` (e.g. `"Asset — Bank (101)"`).
    ///
    /// - Note: Do not use this value for persistence or equality checks — use the
    ///   raw `Int16` value directly.
    var displayName: String {
        switch self {
        case .unspecified:              return "Generic (0)"
        // Assets
        case .cashAndCashEquivalents:   return "Asset — Cash & Equivalents (100)"
        case .bank:                     return "Asset — Bank (101)"
        case .accountsReceivable:       return "Asset — Accounts Receivable (110)"
        case .inventory:                return "Asset — Inventory (120)"
        case .fixedAssets:              return "Asset — Fixed Assets (130)"
        case .accumulatedDepreciation:  return "Asset — Accumulated Depreciation (131)"
        case .otherAssets:              return "Asset — Other (199)"
        // Liabilities
        case .accountsPayable:          return "Liability — Accounts Payable (200)"
        case .taxesPayable:             return "Liability — Taxes Payable (210)"
        case .loansPayable:             return "Liability — Loans Payable (220)"
        case .otherLiabilities:         return "Liability — Other (299)"
        // Equity
        case .capital:                  return "Equity — Capital (300)"
        case .retainedEarnings:         return "Equity — Retained Earnings (310)"
        case .currentYearResult:        return "Equity — Current Year Result (320)"
        // Income
        case .salesRevenue:             return "Income — Sales Revenue (400)"
        case .serviceRevenue:           return "Income — Service Revenue (410)"
        case .workRevenue:              return "Income — Work Revenue (420)"
        case .rentalRevenue:            return "Income — Rental Revenue (430)"
        case .otherIncome:              return "Income — Other (499)"
        // Cost of Sales
        case .costOfGoodsSold:          return "Cost of Sales — COGS (500)"
        case .costOfServices:           return "Cost of Sales — Services (510)"
        // Expenses
        case .operatingExpense:         return "Expense — Operating (600)"
        case .administrativeExpense:    return "Expense — Administrative (610)"
        case .sellingExpense:           return "Expense — Selling (620)"
        case .otherExpense:             return "Expense — Other (699)"
        // Memorandum
        case .memorandumDebit:          return "Memo — Debit (700)"
        case .memorandumCredit:         return "Memo — Credit (800)"
        // Financial result roles
        case .financialIncome:          return "Financial — Income (4300)"
        case .financialExpense:         return "Financial — Expense (4301)"
        case .interestIncome:           return "Financial — Interest Income (4310)"
        case .interestExpense:          return "Financial — Interest Expense (4311)"
        case .fxGain:                   return "Financial — FX Gain (4320)"
        case .fxLoss:                   return "Financial — FX Loss (4321)"
        case .inflationGain:            return "Financial — Inflation Gain (4330)"
        case .inflationLoss:            return "Financial — Inflation Loss (4331)"
        case .bankFeesIncome:           return "Financial — Bank Fees Income (4340)"
        case .bankFeesExpense:          return "Financial — Bank Fees Expense (4341)"
        case .otherFinancialIncome:     return "Financial — Other Income (4390)"
        case .otherFinancialExpense:    return "Financial — Other Expense (4391)"
        // Statistical
        case .kpi:                      return "Statistical — KPI (900)"
        }
    }
}
