//
//  Features/Transactions/PostTransactionViewModel.swift
//  PostTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felie Guevara Chávez on 2026-04-02
//  Developed with AI assistance.
//

import Foundation

/// Manages form state, balance validation, and submission for the Post Transaction sheet.
///
/// Maintains the split line array, computes ``totalDebits``, ``totalCredits``, ``imbalance``,
/// and ``isBalanced`` in real time. ``canSubmit`` gates the Post button (balanced, all splits
/// complete, not already submitting). ``submit(ledger:payeeId:token:)`` maps form state to a
/// ``PostTransactionRequest`` using rational-number encoding and posts `.transactionPosted`
/// on success so observers such as ``AccountTreeView`` can reload balances immediately.
///
/// - SeeAlso: ``PostTransactionView``, ``PostTransactionService``, ``SplitLine``
@Observable
final class PostTransactionViewModel {

    // MARK: - Form State

    /// Effective (accounting) date of the transaction; defaults to now.
    var postDate: Date = .now

    /// Transaction-level memo; empty string is sent as `nil` to the backend.
    var memo: String = ""

    /// Reference or check number; empty string is sent as `nil` to the backend.
    var num: String = ""

    /// Split lines for the transaction; initialized with two empty lines (minimum required).
    var splits: [SplitLine] = [SplitLine(), SplitLine()]

    // MARK: - UI State

    /// `true` while a submission is in progress; used to show a spinner and block duplicate taps.
    var isSubmitting = false

    /// Localized error message set on submission failure; `nil` when no error is present.
    var errorMessage: String?

    /// Set to `true` on successful post; observed by the view to invoke `onSuccess` and dismiss.
    var didPost = false

    // MARK: - Account Search

    /// Per-split search text for account pickers; keyed by ``SplitLine`` `id`.
    var accountSearchTexts: [UUID: String] = [:]

    /// ID of the split whose account picker is currently expanded; `nil` collapses all pickers.
    var showAccountPicker: UUID? = nil

    // MARK: - Dependencies

    /// Service used to POST the transaction to the backend.
    private let service = PostTransactionService.shared

    // MARK: - Computed Properties

    /// Sum of all positive debit amounts across `splits`; invalid or empty strings contribute zero.
    var totalDebits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard let d = Decimal(string: line.debitAmount), d > .zero else { return sum }
            return sum + d
        }
    }

    /// Sum of all positive credit amounts across `splits`; invalid or empty strings contribute zero.
    var totalCredits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard let c = Decimal(string: line.creditAmount), c > .zero else { return sum }
            return sum + c
        }
    }

    /// `true` when `totalDebits == totalCredits > 0`; required before the Post button is enabled.
    var isBalanced: Bool {
        totalDebits > .zero && totalDebits == totalCredits
    }

    /// `totalDebits − totalCredits`; positive = excess debits, negative = excess credits, zero = balanced.
    var imbalance: Decimal {
        totalDebits - totalCredits
    }

    /// `true` when `isBalanced`, all splits satisfy `isComplete`, and `isSubmitting` is `false`.
    var canSubmit: Bool {
        isBalanced && splits.allSatisfy { $0.isComplete } && !isSubmitting
    }

    // MARK: - Split Management

    /// Appends a new blank ``SplitLine`` to `splits`.
    func addSplitLine() {
        splits.append(SplitLine())
    }

    /// Removes the ``SplitLine`` with the given `id`; no-op when only 2 splits remain.
    ///
    /// - Parameter id: UUID of the split to remove.
    func removeSplitLine(id: UUID) {
        guard splits.count > 2 else { return }  // minimum 2 splits
        splits.removeAll { $0.id == id }
    }

    /// Clears `creditAmount` on the matching split to enforce debit/credit mutual exclusivity.
    ///
    /// - Parameter id: UUID of the split whose debit field changed.
    func didEditDebit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].creditAmount = ""
        }
    }

    /// Clears `debitAmount` on the matching split to enforce debit/credit mutual exclusivity.
    ///
    /// - Parameter id: UUID of the split whose credit field changed.
    func didEditCredit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].debitAmount = ""
        }
    }

    /// Sets `account` on the matching split and clears ``showAccountPicker`` to collapse the dropdown.
    ///
    /// - Parameters:
    ///   - account: The selected ``AccountNode``.
    ///   - id: UUID of the split to update.
    func setAccount(_ account: AccountNode, for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].account = account
        }
        showAccountPicker = nil
    }

    // MARK: - Auto-balance

    /// Fills the last split line with the amount needed to balance the transaction.
    ///
    /// Writes the absolute value of ``imbalance`` into the last ``SplitLine`` as a credit
    /// (when debits exceed credits) or a debit (when credits exceed debits). No-op when already balanced.
    ///
    /// - Note: Overwrites any existing amounts on the last split line without prompting.
    func autoBalance() {
        guard let lastIdx = splits.indices.last else { return }
        let diff = totalDebits - totalCredits
        if diff > .zero {
            // More debits — fill last line as credit
            splits[lastIdx].creditAmount = "\(diff)"
            splits[lastIdx].debitAmount  = ""
        } else if diff < .zero {
            // More credits — fill last line as debit
            splits[lastIdx].debitAmount  = "\(-diff)"
            splits[lastIdx].creditAmount = ""
        }
    }

    // MARK: - Submit

    /// Maps form state to a ``PostTransactionRequest`` and POSTs it to the backend.
    ///
    /// Guards on ``canSubmit`` and `ledger.currencyCommodityId`. Encodes each complete
    /// ``SplitLine`` using rational numbers: `valueNum = amount × 10^decimalPlaces`,
    /// `valueDenom = 10^decimalPlaces`. Posts `.transactionPosted` on success.
    ///
    /// - Parameters:
    ///   - ledger: Provides `id`, `decimalPlaces`, and `currencyCommodityId`.
    ///   - payeeId: Optional payee to attach; `nil` means no payee.
    ///   - token: Bearer token for the API request.
    /// - Important: Must be called from a `@MainActor` context.
    @MainActor
    func submit(ledger: LedgerResponse, payeeId: UUID? = nil, token: String) async {
        guard canSubmit else { return }

        // Guard: currencyCommodityId must be present to identify currency for amounts
        guard let commodityId = ledger.currencyCommodityId else {
            errorMessage = "Ledger is missing currency commodity ID. Please sign out and sign back in."
            return
        }

        isSubmitting = true
        errorMessage = nil

        // Derive valueDenom from ledger decimal places
        // e.g. 2 decimal places → denom = 100
        let denom = Int(pow(10.0, Double(ledger.decimalPlaces)))

        // Filter only complete split lines and convert them to SplitRequest objects
        let splitRequests = splits
            .filter { $0.isComplete }   // ← only include complete lines
            .map { line in
                SplitRequest(
                    accountId:     line.account!.id,
                    side:          line.side,
                    valueNum:      line.toValueNum(denom: denom),
                    valueDenom:    denom,
                    quantityNum:   0,
                    quantityDenom: denom,
                    memo:          line.memo.isEmpty ? nil : line.memo,
                    action:        nil
                )
            }

        // Build the main PostTransactionRequest with all required fields
        let request = PostTransactionRequest(
            ledgerId:             ledger.id,
            currencyCommodityId:  commodityId,
            postDate:             postDate,
            enterDate:            nil,
            memo:                 memo.isEmpty ? nil : memo,
            num:                  num.isEmpty  ? nil : num,
            status:               0,
            payeeId:              payeeId,
            splits:               splitRequests
        )

        do {
            // Perform the network call to post the transaction
            _ = try await service.post(request, token: token)
            didPost = true
            NotificationCenter.default.post(
                name: .transactionPosted,
                object: ledger.id         // carry the ledger ID so observers can filter
            )
        } catch {
            // Capture and display any error encountered
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Reset

    /// Resets all form and UI state to initial values, ready for a new transaction entry.
    func reset() {
        postDate = .now
        memo = ""
        num = ""
        splits = [SplitLine(), SplitLine()]
        errorMessage = nil
        didPost = false
        isSubmitting = false
        accountSearchTexts = [:]
        showAccountPicker = nil
    }
}
