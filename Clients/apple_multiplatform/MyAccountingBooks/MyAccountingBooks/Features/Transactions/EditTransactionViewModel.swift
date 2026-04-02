//
//  Features/Transactions/EditTransactionViewModel.swift
//  EditTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Developed with AI assistance.
//

import Foundation

/// View model for editing an existing transaction in the accounting system.
///
/// `EditTransactionViewModel` manages the form state and submission logic for modifying
/// posted transactions. It intelligently tracks changes and submits only modified fields
/// to the server using the PATCH endpoint, minimizing network payload and preserving
/// unchanged data.
///
/// ## Features
///
/// - **Efficient updates**: Only sends changed fields to the server
/// - **Pre-population**: Loads existing transaction data into editable form state
/// - **Account resolution**: Converts account IDs to full `AccountNode` references
/// - **Split line editing**: Supports modifying individual transaction splits
/// - **Change detection**: Compares current values against originals to identify modifications
/// - **Error handling**: Provides user-friendly error messages for failed submissions
///
/// ## Usage
///
/// ```swift
/// @State private var viewModel = EditTransactionViewModel()
///
/// // Populate with existing transaction data
/// viewModel.populate(
///     from: transaction,
///     accountPaths: accountPathMap,
///     allAccounts: chartOfAccounts
/// )
///
/// // User modifies form fields...
/// viewModel.memo = "Updated description"
/// viewModel.splitLines[0].account = newAccount
///
/// // Submit changes
/// await viewModel.submit(
///     transaction: transaction,
///     ledger: currentLedger,
///     token: authToken
/// )
///
/// if viewModel.didSave {
///     // Transaction updated successfully
/// }
/// ```
///
/// - Note: This view model uses the `@Observable` macro for SwiftUI integration.
/// - SeeAlso: `PatchTransactionRequest`, `EditSplitLine`, `TransactionResponse`
@Observable
final class EditTransactionViewModel {

    // MARK: - Form State

    /// The transaction memo or description. Can be empty.
    var memo: String = ""
    
    /// The transaction number (e.g., check number, reference). Can be empty.
    var num: String = ""
    
    /// The posting date for this transaction. Defaults to current date/time.
    var postDate: Date = .now
    
    /// The editable split lines that make up this transaction.
    ///
    /// Each split represents a debit or credit to an account. Users can modify
    /// the memo and account assignment for each split line.
    var splitLines: [EditSplitLine] = []
    
    // Add properties
    var selectedPayeeId: UUID? = nil
    var usePayee: Bool = false

    // MARK: - UI State

    /// `true` while the save operation is in progress. Use for displaying loading indicators.
    var isSubmitting = false
    
    /// Contains a user-friendly error message if the save operation fails. `nil` if no error.
    var errorMessage: String?
    
    /// `true` if the transaction was successfully saved. Use to trigger navigation or dismissal.
    var didSave = false

    // MARK: - Initialization

    /// Populates the view model with data from an existing transaction.
    ///
    /// This method loads the transaction's current values into the editable form state,
    /// resolving account IDs to full `AccountNode` objects for easier UI binding. It
    /// stores the original values internally to enable change detection during submission.
    ///
    /// **Implementation Details:**
    /// - Converts optional fields to empty strings for form binding
    /// - Builds a flattened account lookup map for efficient ID resolution
    /// - Maps each split to an `EditSplitLine` with resolved account references
    /// - Preserves original account IDs for change detection
    ///
    /// **Usage:**
    /// ```swift
    /// viewModel.populate(
    ///     from: existingTransaction,
    ///     accountPaths: pathDictionary,
    ///     allAccounts: accountHierarchy
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - transaction: The existing transaction to edit.
    ///   - accountPaths: A dictionary mapping account IDs to their full paths (e.g., "Assets:Bank:Checking").
    ///                   Currently used for reference; may be utilized for validation or display.
    ///   - allAccounts: The complete chart of accounts as a hierarchical tree. Used to resolve
    ///                  account IDs to `AccountNode` objects.
    ///
    /// - Note: Call this method before presenting the edit form to the user.
    func populate(
        from transaction: TransactionResponse,
        accountPaths: [UUID: String],
        allAccounts: [AccountNode]
    ) {
        memo     = transaction.memo ?? ""
        num      = transaction.num  ?? ""
        postDate = transaction.postDate
        selectedPayeeId = transaction.payeeId
        usePayee        = transaction.payeeId != nil   // ← toggle on if payee exists

        // Build a flat account lookup for quick ID → node resolution
        func flatten(_ nodes: [AccountNode]) -> [UUID: AccountNode] {
            var map: [UUID: AccountNode] = [:]
            for node in nodes {
                map[node.id] = node
                map.merge(flatten(node.children)) { $1 }
            }
            return map
        }
        let accountMap = flatten(allAccounts)

        splitLines = transaction.splits.map { split in
            EditSplitLine(
                id:                split.id,
                memo:              split.memo ?? "",
                account:           accountMap[split.accountId],
                originalAccountId: split.accountId
            )
        }
    }

    // MARK: - Submit

    /// Submits the modified transaction data to the server.
    ///
    /// This method performs intelligent change detection, comparing current form values
    /// against the original transaction. Only fields that have been modified are included
    /// in the PATCH request, minimizing network payload and reducing the chance of
    /// conflicting updates.
    ///
    /// **Change Detection Strategy:**
    /// - **Memo & Num**: Trimmed and compared to original; empty strings become `nil`
    /// - **Post Date**: Compared with 1-second tolerance to avoid spurious updates from date picker precision
    /// - **Split Lines**: Each split is compared individually; only changed splits are sent
    /// - **Split Memo**: Trimmed and compared to original
    /// - **Split Account**: Compared to original account ID
    ///
    /// **Submission Process:**
    /// 1. Sets `isSubmitting = true` and clears previous errors
    /// 2. Builds a `PatchTransactionRequest` with only changed fields
    /// 3. Sends PATCH request to `/transactions/{id}`
    /// 4. On success: Sets `didSave = true`
    /// 5. On failure: Sets `errorMessage` with description
    /// 6. Sets `isSubmitting = false` when complete
    ///
    /// **Usage:**
    /// ```swift
    /// await viewModel.submit(
    ///     transaction: originalTransaction,
    ///     ledger: currentLedger,
    ///     token: userToken
    /// )
    ///
    /// if viewModel.didSave {
    ///     dismiss()
    /// } else if let error = viewModel.errorMessage {
    ///     // Show error alert
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - transaction: The original transaction being edited. Used for change detection.
    ///   - ledger: The ledger this transaction belongs to. Currently unused but available
    ///             for future validation or audit logging.
    ///   - token: The authentication token for API requests.
    ///
    /// - Note: This method must be called from the main actor context as it updates UI state.
    @MainActor
    func submit(
        transaction: TransactionResponse,
        ledger: LedgerResponse,
        token: String
    ) async {
        isSubmitting = true
        errorMessage = nil

        // Build patch — only include fields that changed
        var patch = PatchTransactionRequest()

        // Check memo changes
        let newMemo = memo.trimmingCharacters(in: .whitespaces)
        if newMemo != (transaction.memo ?? "") {
            patch.memo = newMemo.isEmpty ? nil : newMemo
        }

        // Check num changes
        let newNum = num.trimmingCharacters(in: .whitespaces)
        if newNum != (transaction.num ?? "") {
            patch.num = newNum.isEmpty ? nil : newNum
        }

        // Compare dates at second precision to avoid spurious updates
        let originalDate = transaction.postDate
        if abs(postDate.timeIntervalSince(originalDate)) > 1 {
            patch.postDate = postDate
        }

        // Build split patches for changed splits only
        var splitPatches: [PatchSplitRequest] = []
        for line in splitLines {
            var sp = PatchSplitRequest(splitId: line.id)
            let originalSplit = transaction.splits.first { $0.id == line.id }

            // Check split memo changes
            let trimmedMemo = line.memo.trimmingCharacters(in: .whitespaces)
            if trimmedMemo != (originalSplit?.memo ?? "") {
                sp.memo = trimmedMemo.isEmpty ? nil : trimmedMemo
            }
            
            // Check account changes
            if let account = line.account, account.id != line.originalAccountId {
                sp.accountId = account.id
            }
            
            // Only include this split if something changed
            if sp.memo != nil || sp.accountId != nil {
                splitPatches.append(sp)
            }
        }
        if !splitPatches.isEmpty {
            patch.splits = splitPatches
        }

        do {
            let _: TransactionResponse = try await APIClient.shared.request(
                .patchTransaction(id: transaction.id),
                method: "PATCH",
                body: patch,
                token: token
            )
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
