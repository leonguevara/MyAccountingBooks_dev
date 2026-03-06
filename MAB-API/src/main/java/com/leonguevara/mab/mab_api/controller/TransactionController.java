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
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.service.TransactionService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;

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
}
