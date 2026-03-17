//
//  Features/Transactions/PostTransactionViewModel.swift
//  PostTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import Foundation

/**
 ViewModel managing the Post Transaction form state, validation, mapping to request objects, and submission.

 This observable class orchestrates the complete transaction posting workflow, handling:
 - Form data management (date, memo, number, and split lines)
 - Real-time balance calculation and validation
 - User interaction handling (editing amounts, selecting accounts)
 - Mapping from form state to API request objects
 - Asynchronous submission to the backend service
 
 # Double-Entry Bookkeeping Rules
 The view model enforces standard accounting principles:
 - Minimum of 2 split lines required
 - Each split must have either a debit OR credit amount (mutually exclusive)
 - Total debits must equal total credits before submission
 - All splits must have an assigned account and non-zero amount
 
 # Usage Example
 ```swift
 @State private var viewModel = PostTransactionViewModel()
 
 // In your submit action:
 await viewModel.submit(ledger: selectedLedger, token: authToken)
 
 // Check for success:
 if viewModel.didPost {
     // Transaction posted successfully
 }
 ```
 
 - Note: This class uses the `@Observable` macro for SwiftUI integration.
 - SeeAlso: `PostTransactionView`, `PostTransactionService`, `SplitLine`
 */
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

    /**
     Removes a split line from the transaction by its unique identifier.

     This method enforces a minimum of 2 split lines to maintain valid double-entry
     transactions. If only 2 splits remain, the removal request is ignored.

     - Parameter id: The UUID of the split line to remove.
     
     # Example
     ```swift
     viewModel.removeSplitLine(id: splitLine.id)
     ```
     */
    func removeSplitLine(id: UUID) {
        guard splits.count > 2 else { return }  // minimum 2 splits
        splits.removeAll { $0.id == id }
    }

    /**
     Handles user editing of a debit amount for a specific split line.

     This method enforces the mutual exclusivity rule: when a user enters a debit amount,
     the credit amount for the same split must be cleared to zero, as a split cannot
     simultaneously be both a debit and a credit.

     - Parameter id: The UUID of the split line whose debit field was edited.
     
     # Example
     ```swift
     TextField("0.00", text: $line.debitAmount)
     .onChange(of: line.debitAmount) { _, _ in
         viewModel.didEditDebit(for: line.id)
     }
     ```
     */
    func didEditDebit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].creditAmount = ""
        }
    }

    /**
     Handles user editing of a credit amount for a specific split line.

     This method enforces the mutual exclusivity rule: when a user enters a credit amount,
     the debit amount for the same split must be cleared to zero, as a split cannot
     simultaneously be both a debit and a credit.

     - Parameter id: The UUID of the split line whose credit field was edited.
     
     # Example
     ```swift
     TextField("0.00", text: $line.creditAmount)
     .onChange(of: line.creditAmount) { _, _ in
         viewModel.didEditCredit(for: line.id)
     }
     ```
     */
    func didEditCredit(for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].debitAmount = ""
        }
    }

    /**
     Assigns the selected account to a specific split line and dismisses the account picker.

     - Parameters:
       - account: The `AccountNode` selected by the user from the account picker.
       - id: The UUID of the split line to update with the selected account.
     
     # Example
     ```swift
     accountRow.onTapGesture {
         viewModel.setAccount(selectedAccount, for: splitLine.id)
     }
     ```
     */
    func setAccount(_ account: AccountNode, for id: UUID) {
        if let idx = splits.firstIndex(where: { $0.id == id }) {
            splits[idx].account = account
        }
        showAccountPicker = nil
    }

    // MARK: - Auto-balance

    /**
     Automatically balances the transaction by calculating and filling the last split line.

     This convenience method examines the current imbalance and fills the last split line
     with the amount needed to bring the transaction into balance:
     
     - If total debits exceed total credits, fills the last line's **credit** field
     - If total credits exceed total debits, fills the last line's **debit** field
     - If already balanced, does nothing
     
     The opposing field (debit or credit) in the last line is cleared to ensure
     mutual exclusivity.
     
     # Algorithm
     1. Calculate the difference between total debits and total credits
     2. If difference is positive (more debits): set last split's credit to the difference
     3. If difference is negative (more credits): set last split's debit to the absolute value
     4. Clear the opposing field to maintain the debit/credit exclusivity rule
     
     # Example
     Given a transaction with:
     - Split 1: Debit $100
     - Split 2: Credit $30
     - Split 3: Empty
     
     Calling `autoBalance()` will set Split 3's credit to $70, resulting in:
     - Total Debits: $100
     - Total Credits: $100 (balanced ✓)
     
     - Note: This method modifies the last split line regardless of whether it has existing data.
     */
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

    /**
     Attempts to submit the transaction asynchronously to the backend API.

     This method orchestrates the complete submission workflow:
     1. **Validation**: Checks that the transaction can be submitted
     2. **Currency Check**: Ensures the ledger has a valid currency commodity ID
     3. **Data Mapping**: Converts form state (split lines with decimal strings) to API request format (rational numbers)
     4. **Network Request**: Posts the transaction via the service layer
     5. **State Updates**: Updates UI state based on success or failure

     - Parameters:
       - ledger: The `LedgerResponse` context containing currency information and decimal precision.
       - token: The authentication token for authorizing the network request.

     # Data Transformation
     The method performs several key transformations:
     - Decimal strings (`"12.50"`) → Rational numbers (`numerator: 1250, denominator: 100`)
     - Decimal places (2) → Denominator (100)
     - Split lines → `SplitRequest` objects with proper side (0=debit, 1=credit)
     - Form state → `PostTransactionRequest` API model
     
     # Split Request Mapping
     Each complete split line is converted to a `SplitRequest`:
     - `accountId`: The selected account's UUID
     - `side`: 0 for debit, 1 for credit (derived from which field has a value)
     - `valueNum`: Amount × denominator (e.g., $12.50 × 100 = 1250)
     - `valueDenom`: Based on ledger decimal places (e.g., 100 for 2 decimal places)
     - `quantityNum`: Currently set to 0 (for multi-currency, would be different from value)
     - `quantityDenom`: Same as valueDenom
     - `memo`: The split's memo, or `nil` if empty
     - `action`: Currently `nil` (reserved for future use like editing/deleting)
     
     # Error Handling
     Potential errors include:
     - Missing currency commodity ID in ledger
     - Network connectivity issues
     - Server validation errors (unbalanced transaction, invalid accounts, etc.)
     - Authentication failures
     
     All errors are captured and displayed in the `errorMessage` property.
     
     # Example
     ```swift
     await viewModel.submit(ledger: currentLedger, token: userAuthToken)
     
     if viewModel.didPost {
         print("Transaction posted successfully!")
     } else if let error = viewModel.errorMessage {
         print("Error: \(error)")
     }
     ```
     
     - Important: This method must be called from a `@MainActor` context to ensure UI updates occur on the main thread.
     - Note: Only complete split lines (with account and non-zero amount) are included in the request.
     */
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
    /// # Example
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
