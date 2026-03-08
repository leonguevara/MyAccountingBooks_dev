// ============================================================
// TransactionService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic layer for transaction operations.
//
//          Responsibilities:
//            1. Resolve ownerID from JWT (SecurityContext)
//            2. Delegate to TransactionRepository for DB call
//            3. Return TransactionResponse to controller
//
//          Intentionally thin — all accounting correctness
//          lives in mab_post_transaction() in the database.
//          The service layer does not re-implement balance
//          checks or split validation.
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

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
}
