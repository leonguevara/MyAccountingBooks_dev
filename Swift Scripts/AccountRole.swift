// AccountRole_v3.swift
// Generated update: finer-grained financial roles (RIF / SAT 700s).
//
// Notes:
// - Keep raw values stable once shipped. New cases are appended in a dedicated range.
// - Roles are "system intent" (analytics, UX, automations), not fiscal mapping.
// - SAT mapping should remain in ledger_account_sat_map (per-ledger), not here.

import Foundation

/// AccountRole defines the functional intent of an account inside the system.
/// Persist as Int16 across platforms (Swift/Java/Kotlin).
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
}
