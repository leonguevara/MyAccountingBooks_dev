//
//  Features/Transactions/PostTransactionViewModel.swift
//  PostTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Last modified by León Felie Guevara Chávez on 2026-03-29
//  Developed with AI assistance.
//

import Foundation

/// View model managing the Post Transaction form state, validation, request mapping, and submission.
///
/// `PostTransactionViewModel` is decorated with `@Observable` and orchestrates the complete
/// transaction posting workflow, handling:
/// - Form data management (date, memo, reference number, and split lines)
/// - Real-time balance calculation and validation
/// - User interaction handling (editing amounts, selecting accounts)
/// - Mapping from form state to ``PostTransactionRequest`` / ``SplitRequest`` objects
/// - Asynchronous submission via ``PostTransactionService``
/// - Posting `.transactionPosted` notifications so observers (e.g. ``AccountTreeView``)
///   can refresh balances immediately after a successful post
///
/// ## Double-Entry Bookkeeping Rules
///
/// The view model enforces standard accounting principles:
/// - Minimum of 2 split lines required
/// - Each split must have either a debit **or** credit amount (mutually exclusive)
/// - Total debits must equal total credits before submission
/// - All splits must have an assigned account and a non-zero amount
///
/// ## Usage Example
///
/// ```swift
/// @State private var viewModel = PostTransactionViewModel()
///
/// // In your submit action:
/// await viewModel.submit(ledger: selectedLedger, token: authToken)
///
/// // Check for success:
/// if viewModel.didPost {
///     // Transaction posted successfully
/// }
/// ```
///
/// - Note: Decorated with `@Observable` (macOS 14+) for SwiftUI integration.
/// - SeeAlso: ``PostTransactionView``, ``PostTransactionService``, ``SplitLine``
@Observable
final class PostTransactionViewModel {

    // MARK: - Form State

    /// The date on which the transaction is posted.
    ///
    /// This represents the effective date of the transaction in the ledger.
    /// Defaults to the current date when the form is initialized.
    var postDate: Date = .now

    /// An optional memo (description) for the entire transaction.
    ///
    /// This field provides context about the transaction as a whole,
    /// separate from individual split memos. If empty, it will be sent as `nil` to the backend.
    var memo: String = ""

    /// An optional transaction number or reference identifier.
    ///
    /// Commonly used for check numbers, invoice numbers, or other reference codes.
    /// If empty, it will be sent as `nil` to the backend.
    var num: String = ""

    /// Array of split lines representing the debit and credit entries of the transaction.
    ///
    /// Each split line contains an account, memo, and either a debit or credit amount.
    /// The transaction always starts with 2 empty split lines and requires a minimum of 2 lines.
    /// Users can add additional lines as needed for complex multi-split transactions.
    var splits: [SplitLine] = [SplitLine(), SplitLine()]

    // MARK: - UI State

    /// Indicates whether the transaction submission process is currently in progress.
    ///
    /// When `true`, the submit button should show a loading indicator and be disabled
    /// to prevent duplicate submissions.
    var isSubmitting = false

    /// Stores an error message to display to the user if submission fails.
    ///
    /// This will be `nil` when there's no error, or contain a localized error description
    /// when a submission failure occurs (network error, validation error, server error, etc.).
    var errorMessage: String?

    /// Flag indicating whether the transaction was successfully posted to the backend.
    ///
    /// When this becomes `true`, the view should trigger the `onSuccess` callback and dismiss.
    /// This property is observed by the view to coordinate post-submission actions.
    var didPost = false

    // MARK: - Account Search

    /// Maps split line IDs to their current account search text inputs.
    ///
    /// This dictionary maintains the search state for each split line's account picker,
    /// allowing independent search filtering for multiple account pickers.
    var accountSearchTexts: [UUID: String] = [:]

    /// The ID of the split line currently displaying its account picker dropdown.
    ///
    /// Only one account picker can be shown at a time. When set to a split line ID,
    /// that line's picker is expanded; when `nil`, all pickers are collapsed.
    var showAccountPicker: UUID? = nil

    // MARK: - Dependencies

    /// Service dependency responsible for performing the network POST request to create the transaction.
    ///
    /// This singleton service handles authentication, request formatting, and response parsing.
    private let service = PostTransactionService.shared

    // MARK: - Computed Properties

    /// The total debit amount summed across all split lines.
    ///
    /// Iterates through all splits, parsing valid decimal values from the `debitAmount` strings.
    /// Invalid or empty debit amounts are treated as zero and excluded from the sum.
    ///
    /// - Returns: The sum of all positive debit amounts as a `Decimal`.
    var totalDebits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard let d = Decimal(string: line.debitAmount), d > .zero else { return sum }
            return sum + d
        }
    }

    /// The total credit amount summed across all split lines.
    ///
    /// Iterates through all splits, parsing valid decimal values from the `creditAmount` strings.
    /// Invalid or empty credit amounts are treated as zero and excluded from the sum.
    ///
    /// - Returns: The sum of all positive credit amounts as a `Decimal`.
    var totalCredits: Decimal {
        splits.reduce(.zero) { sum, line in
            guard let c = Decimal(string: line.creditAmount), c > .zero else { return sum }
            return sum + c
        }
    }

    /// Indicates whether the transaction is balanced according to double-entry bookkeeping rules.
    ///
    /// A transaction is considered balanced when:
    /// - Total debits equal total credits exactly
    /// - Both totals are greater than zero
    ///
    /// This is a fundamental requirement for valid double-entry accounting transactions.
    ///
    /// - Returns: `true` if the transaction is properly balanced, `false` otherwise.
    var isBalanced: Bool {
        totalDebits > .zero && totalDebits == totalCredits
    }

    /// The difference between total debits and total credits.
    ///
    /// - A positive value indicates excess debits (need more credits to balance)
    /// - A negative value indicates excess credits (need more debits to balance)
    /// - Zero indicates a balanced transaction
    ///
    /// This value is used to display the imbalance amount in the UI and by the auto-balance feature.
    ///
    /// - Returns: The imbalance as a `Decimal` (debits minus credits).
    var imbalance: Decimal {
        totalDebits - totalCredits
    }

    /// Indicates whether the form is valid and ready to submit.
    ///
    /// Submission is enabled when ALL of the following conditions are met:
    /// - The transaction is balanced (`isBalanced` is `true`)
    /// - All split lines are complete (have an account and non-zero amount)
    /// - No submission is currently in progress (`isSubmitting` is `false`)
    ///
    /// This property is used to enable/disable the submit button in the UI.
    ///
    /// - Returns: `true` if the transaction can be submitted, `false` otherwise.
    var canSubmit: Bool {
        isBalanced && splits.allSatisfy { $0.isComplete } && !isSubmitting
    }

    // MARK: - Split Management

    /// Adds a new blank split line to the transaction.
    ///
    /// The new split line is initialized with empty values and appended to the end
    /// of the splits array. Users can then populate it with an account and amount.
    func addSplitLine() {
        splits.append(SplitLine())
    }

    /// Removes a split line from the transaction by its unique identifier.
    ///
    /// Enforces a minimum of 2 split lines. If only 2 splits remain, the removal
    /// request is silently ignored to prevent an invalid single-sided transaction.
    ///
    /// - Parameter id: The `UUID` of the ``SplitLine`` to remove.
    func removeSplitLine(id: UUID) {
        guard splits.count > 2 else { return }  // minimum 2 splits
        splits.removeAll { $0.id == id }
    }

    /// Enforces debit/credit mutual exclusivity when the debit field of a split is edited.
    ///
    /// Clears `creditAmount` on the matching ``SplitLine`` so that a split cannot carry
    /// both a debit and a credit value simultaneously. Called by ``PostTransactionView``
    /// via the `onDebitEdited` callback whenever the debit `TextField` changes.
    ///
    /// - Parameter id: The `UUID` of the ``SplitLine`` whose debit field was edited.
    func didEditDebit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].creditAmount = ""
        }
    }

    /// Enforces debit/credit mutual exclusivity when the credit field of a split is edited.
    ///
    /// Clears `debitAmount` on the matching ``SplitLine`` so that a split cannot carry
    /// both a debit and a credit value simultaneously. Called by ``PostTransactionView``
    /// via the `onCreditEdited` callback whenever the credit `TextField` changes.
    ///
    /// - Parameter id: The `UUID` of the ``SplitLine`` whose credit field was edited.
    func didEditCredit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].debitAmount = ""
        }
    }

    /// Assigns the selected account to a split line and collapses the account picker.
    ///
    /// Sets `account` on the matching ``SplitLine`` and clears ``showAccountPicker``
    /// so the dropdown closes. No-ops silently if `id` is not found in `splits`.
    ///
    /// - Parameters:
    ///   - account: The ``AccountNode`` selected by the user.
    ///   - id: The `UUID` of the ``SplitLine`` to update.
    func setAccount(_ account: AccountNode, for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].account = account
        }
        showAccountPicker = nil
    }

    // MARK: - Auto-balance

    /// Fills the last split line with the amount needed to bring the transaction into balance.
    ///
    /// Reads ``imbalance`` (debits − credits) and writes into the last ``SplitLine``:
    ///
    /// | `imbalance` sign | Action |
    /// |---|---|
    /// | Positive (more debits) | Sets last line's `creditAmount` to `imbalance`; clears `debitAmount` |
    /// | Negative (more credits) | Sets last line's `debitAmount` to `abs(imbalance)`; clears `creditAmount` |
    /// | Zero (already balanced) | No-op |
    ///
    /// ## Example
    ///
    /// Given splits: Debit $100, Credit $30, and one empty line —
    /// calling `autoBalance()` sets the last line's `creditAmount` to `"70"`,
    /// producing total debits = total credits = $100.
    ///
    /// - Note: Overwrites any existing amounts in the last split line without prompting.
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

    /// Validates, maps, and asynchronously submits the transaction to the backend API.
    ///
    /// The submission workflow follows five steps:
    ///
    /// 1. **Guard**: Returns immediately if ``canSubmit`` is `false`.
    /// 2. **Currency check**: Reads `ledger.currencyCommodityId`; sets ``errorMessage`` and
    ///    returns if the ID is absent.
    /// 3. **Data mapping**: Converts each complete ``SplitLine`` to a ``SplitRequest``
    ///    using rational-number encoding (see table below).
    /// 4. **Network request**: Calls ``PostTransactionService/post(_:token:)``.
    /// 5. **Notification**: On success, posts `Notification.Name.transactionPosted` with
    ///    `ledger.id` as the `object` so observers such as ``AccountTreeView`` can reload
    ///    balances immediately.
    ///
    /// ## Rational-Number Encoding
    ///
    /// | Source | Transformed to |
    /// |---|---|
    /// | Decimal string `"12.50"` | `valueNum = 1250`, `valueDenom = 100` |
    /// | `ledger.decimalPlaces` (e.g. 2) | `denom = 10^2 = 100` |
    /// | `SplitLine.side` | `0` = debit, `1` = credit |
    /// | `quantityNum` | Always `0` (single-currency ledgers) |
    ///
    /// - Parameters:
    ///   - ledger: The ``LedgerResponse`` providing `currencyCode`, `decimalPlaces`,
    ///     and `currencyCommodityId`.
    ///   - token: The bearer token for API authorisation.
    ///
    /// - Important: Must be called from a `@MainActor` context; all `@Observable`
    ///   property mutations happen on the main thread.
    /// - Note: Only ``SplitLine`` entries where `isComplete == true` are included in the request.
    @MainActor
    func submit(ledger: LedgerResponse, token: String) async {
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
            payeeId:              nil,
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

    /// Resets all form state, UI state, and dependencies to their initial values.
    ///
    /// This method is useful for clearing the form after a successful submission or
    /// when the user wants to start over with a fresh transaction. It resets:
    ///
    /// **Form Data:**
    /// - `postDate` → Current date
    /// - `memo` → Empty string
    /// - `num` → Empty string
    /// - `splits` → Two empty split lines
    ///
    /// **UI State:**
    /// - `errorMessage` → `nil`
    /// - `didPost` → `false`
    /// - `isSubmitting` → `false`
    ///
    /// **Account Search State:**
    /// - `accountSearchTexts` → Empty dictionary
    /// - `showAccountPicker` → `nil` (all pickers collapsed)
    ///
    /// ## Example
    /// ```swift
    /// // After successful submission
    /// if viewModel.didPost {
    ///     viewModel.reset()
    ///     // Form is now ready for a new transaction
    /// }
    /// ```
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
