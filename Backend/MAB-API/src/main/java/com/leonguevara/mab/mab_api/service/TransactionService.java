// ============================================================
// TransactionService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic layer for transaction operations.
//
//          Responsibilities:
//            1. Resolve ownerID from JWT (SecurityContext)
//            2. Delegate to TransactionRepository for DB operations
//            3. Return TransactionResponse to controller
//
//          Intentionally thin — accounting correctness lives in:
//            - Database stored functions (mab_post_transaction,
//              mab_reverse_transaction, mab_void_transaction)
//            - Database constraints and RLS policies
//
//          The service layer does not re-implement balance checks,
//          split validation, or ownership verification. It only
//          extracts the authenticated user and delegates to the
//          repository layer.
// ============================================================
// Last edited: 2026-03-22
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.request.PatchTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.PostTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.VoidTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.ReverseTransactionRequest;
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.TransactionRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class TransactionService {

    // Data access layer for transaction operations.
    private final TransactionRepository transactionRepository;

    /**
     * Constructor injection of TransactionRepository.
     *
     * @param transactionRepository The repository bean for transaction data access.
     */
    public TransactionService(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    /**
     * Posts a double-entry transaction for the authenticated owner.
     * <p>
     * The DB function mab_post_transaction() enforces:
     *   - All splits reference accounts in the same ledger
     *   - No placeholder or deleted accounts
     *   - All splits share the same value_denom
     *   - The debit sum equals the credit sum (double-entry balance)
     *   - Concurrency lock on the ledger
     * <p>
     * If any of these are violated, the DB raises an exception
     * which propagates as an HTTP 400 via GlobalExceptionHandler.
     *
     * @param  request The validated PostTransactionRequest from the controller.
     * @return         The fully assembled TransactionResponse.
     * @throws ApiException HTTP 401 if not authenticated.
     */
    public TransactionResponse postTransaction(PostTransactionRequest request) {
        UUID ownerID = resolveOwnerID();
        return transactionRepository.post(ownerID, request);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * Extracts the authenticated owner's UUID from the Spring SecurityContext.
     *
     * @return The ownerID UUID from the JWT.
     * @throws ApiException HTTP 401 if no valid authentication is present.
     */
    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return ownerID;
    }

    /**
     * Reverses a transaction for the authenticated owner.
     *
     * @param  txId    The UUID of the transaction to reverse (from URL path).
     * @param  request Optional dates and memo for the reversal.
     * @return         TransactionResponse for the new reversal transaction.
     */
    public TransactionResponse reverseTransaction(UUID txId,
                                                  ReverseTransactionRequest request) {
        UUID ownerID = resolveOwnerID();
        return transactionRepository.reverse(ownerID, txId, request);
    }

    /**
     * Voids a transaction for the authenticated owner.
     *
     * @param  txId    The UUID of the transaction to void (from URL path).
     * @param  request Optional reason string.
     * @return         TransactionResponse with isVoided = true.
     */
    public TransactionResponse voidTransaction(UUID txId,
                                               VoidTransactionRequest request) {
        UUID ownerID = resolveOwnerID();
        return transactionRepository.void_(ownerID, txId, request);
    }

    /**
     * Returns all transactions for the given ledger owned by the authenticated user.
     *
     * @param  ledgerId The UUID of the ledger to fetch transactions for.
     * @return          List of TransactionResponse, ordered by post date descending.
     */
    public List<TransactionResponse> getTransactionsForLedger(UUID ledgerId) {
        UUID ownerID = resolveOwnerID();
        return transactionRepository.findByLedgerId(ownerID, ledgerId);
    }

    /**
     * Applies a partial update to a transaction header and/or splits.
     * <p>
     * Implements JSON Merge Patch semantics (RFC 7396) — only non-null fields
     * in the request are modified. All fields are optional.
     * <p>
     * The repository layer enforces:
     *   - Transaction ownership via RLS (current owner only)
     *   - Transaction must not be voided
     *   - Transaction must not be deleted
     *   - Split account changes must reference valid, active, non-placeholder
     *     accounts within the same ledger
     *   - Atomic updates (all changes succeed or none are applied)
     * <p>
     * <b>Cannot modify via this endpoint:</b>
     * <ul>
     *   <li>Split amounts (value_num/value_denom) — use reverse + repost instead</li>
     *   <li>Structural fields (ledgerId, currencyCommodityId)</li>
     *   <li>Void status — use voidTransaction() instead</li>
     * </ul>
     *
     * @param  txId    UUID of the transaction to update (from URL path).
     * @param  request Partial update request — null fields are ignored.
     *                 See {@link PatchTransactionRequest} for available fields.
     * @return         The fully updated TransactionResponse reflecting all changes.
     * @throws ApiException HTTP 401 if not authenticated.
     * @throws ApiException HTTP 404 if transaction not found or not owned by current user.
     * @throws ApiException HTTP 400 if database constraints reject the update
     *                      (e.g., invalid accountId, voided transaction).
     * @see PatchTransactionRequest
     */
    public TransactionResponse updateTransaction(UUID txId,
                                                 PatchTransactionRequest request) {
        UUID ownerID = resolveOwnerID();
        return transactionRepository.update(ownerID, txId, request);
    }
}
