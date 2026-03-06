// ============================================================
// TransactionController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for transaction endpoints.
//
//          Iteration 4: POST /transactions
//          Iteration 5: POST /transactions/{id}/reverse  (next)
//          Iteration 6: POST /transactions/{id}/void     (next)
//
//          All routes require authentication — enforced globally
//          by SecurityConfig.
//
//          The controller is intentionally thin:
//            - Receives + validates HTTP input
//            - Delegates to TransactionService
//            - Returns HTTP 201 with the response body
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.PostTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.ReverseTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.VoidTransactionRequest;
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.service.TransactionService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.UUID;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    // Service layer for all transaction business logic.
    private final TransactionService transactionService;

    /**
     * Constructor injection of TransactionService.
     *
     * @param transactionService The transaction business logic service bean.
     */
    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    /**
     * POST /transactions
     * <p>
     * Posts a balanced double-entry transaction to the specified ledger.
     * The ledger must belong to the authenticated owner (enforced by RLS).
     * <p>
     * Returns HTTP 201 Created on success.
     * Returns HTTP 400 if the transaction is unbalanced, uses wrong accounts,
     * or violates any DB-level posting invariant.
     *
     * @param  request The validated PostTransactionRequest body.
     * @return         HTTP 201 with the created TransactionResponse as JSON.
     */
    @PostMapping
    public ResponseEntity<TransactionResponse> postTransaction(
            @Valid @RequestBody PostTransactionRequest request) {

        TransactionResponse created = transactionService.postTransaction(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(created);
    }

    /**
     * POST /transactions/{id}/reverse
     * <p>
     * Creates a mirror reversal transaction with all split sides flipped.
     * The original transaction is marked with reversed_by_tx_id.
     * <p>
     * Returns HTTP 201 Created with the new reversal TransactionResponse.
     * Returns HTTP 404 if a transaction is not found or not owned by the caller.
     * Returns HTTP 400 if a transaction is voided or already reversed.
     *
     * @param  id      The UUID of the transaction to reverse (path variable).
     * @param  request Optional body — all fields nullable. Might be empty {}.
     * @return         HTTP 201 with the reversal TransactionResponse.
     */
    @PostMapping("/{id}/reverse")
    public ResponseEntity<TransactionResponse> reverseTransaction(
            @PathVariable UUID id,
            @RequestBody(required = false) ReverseTransactionRequest request) {

        // Allow a completely absent or empty body — default to all-null record.
        if (request == null) {
            request = new ReverseTransactionRequest(null, null, null);
        }

        TransactionResponse reversal = transactionService.reverseTransaction(id, request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(reversal);
    }

    /**
     * POST /transactions/{id}/void
     * <p>
     * Marks a transaction as voided in-place. Does NOT create a new transaction.
     * Sets is_voided=true, voided_at=now(), appends [VOID: reason] to the memo field.
     * <p>
     * Returns HTTP 200 OK with the updated TransactionResponse.
     * Returns HTTP 404 if a transaction is not found or not owned by the caller.
     * Returns HTTP 400 if a transaction is already voided.
     *
     * @param  id      The UUID of the transaction to void (path variable).
     * @param  request Optional body with a reason string. Might be empty {}.
     * @return         HTTP 200 with the updated TransactionResponse
     *                 (isVoided will be true).
     */
    @PostMapping("/{id}/void")
    public ResponseEntity<TransactionResponse> voidTransaction(
            @PathVariable UUID id,
            @RequestBody(required = false) VoidTransactionRequest request) {

        // Allow absent or empty body — default to null reason.
        if (request == null) {
            request = new VoidTransactionRequest(null);
        }

        TransactionResponse voided = transactionService.voidTransaction(id, request);

        return ResponseEntity
                .status(HttpStatus.OK)
                .body(voided);
    }
}
