//
//  Features/Transactions/EditTransactionViewModel.swift
//  EditTransactionViewModel.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-23.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Manages form state and PATCH submission for editing an existing transaction.
///
/// Call ``populate(from:accountPaths:allAccounts:)`` to seed form fields from an existing
/// ``TransactionResponse``, then ``submit(transaction:ledger:token:)`` to send only the
/// changed fields to `PATCH /transactions/{id}`. Change detection covers memo, num, postDate,
/// payeeId, and per-split account and memo; unchanged fields are omitted from the request.
///
/// - SeeAlso: ``PatchTransactionRequest``, ``EditSplitLine``, ``EditTransactionView``
@Observable
final class EditTransactionViewModel {

    // MARK: - Form State

    /// The transaction memo or description. Can be empty.
    var memo: String = ""
    
    /// The transaction number (e.g., check number, reference). Can be empty.
    var num: String = ""
    
    /// The posting date for this transaction. Defaults to current date/time.
    var postDate: Date = .now
    
    /// The editable split lines for this transaction; each exposes account and memo for modification.
    var splitLines: [EditSplitLine] = []

    /// The payee UUID to write; `nil` means no payee (or clear existing payee).
    var selectedPayeeId: UUID? = nil
    /// Whether the payee row is toggled on; set to `false` to clear `selectedPayeeId`.
    var usePayee: Bool = false

    // MARK: - UI State

    /// `true` while the save operation is in progress. Use for displaying loading indicators.
    var isSubmitting = false
    
    /// Contains a user-friendly error message if the save operation fails. `nil` if no error.
    var errorMessage: String?
    
    /// `true` if the transaction was successfully saved. Use to trigger navigation or dismissal.
    var didSave = false

    // MARK: - Initialization

    /// Seeds form state from an existing transaction, resolving split account IDs to ``AccountNode`` references.
    ///
    /// Flattens `allAccounts` into a UUID lookup, then maps each split to an ``EditSplitLine``
    /// with its resolved account. Optional fields are coerced to empty strings for form binding.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to edit; supplies initial field values.
    ///   - accountPaths: UUID-to-path map; available for display or future validation.
    ///   - allAccounts: Full account hierarchy used to resolve split account IDs.
    /// - Note: Call once in `.onAppear` before the user interacts with the form.
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

    /// Builds a ``PatchTransactionRequest`` from changed fields and sends it to `PATCH /transactions/{id}`.
    ///
    /// Compares each form field against the original transaction: memo and num are trimmed (empty → `nil`);
    /// postDate is compared with a 1-second tolerance to absorb date-picker precision noise; payeeId and
    /// per-split account/memo are compared directly. Only changed fields are included. Sets `didSave = true`
    /// on success or writes to `errorMessage` on failure.
    ///
    /// - Parameters:
    ///   - transaction: The original transaction; used as the baseline for change detection.
    ///   - ledger: The ledger context; reserved for future validation.
    ///   - token: Bearer token for the API request.
    /// - Note: Must be called from a `@MainActor` context as it mutates UI state.
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
        
        // Check payee changes
        if selectedPayeeId != transaction.payeeId {
            patch.payeeId = selectedPayeeId  // nil clears the payee, UUID sets it
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
