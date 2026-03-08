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
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.PostTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.ReverseTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.VoidTransactionRequest;
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.service.TransactionService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.UUID;

@RestController
@RequestMapping("/transactions")
@Tag(name = "Transactions", description = "Double-entry posting engine — post, reverse, and void transactions")
@SecurityRequirement(name = "bearerAuth")
public class TransactionController {

    private final TransactionService transactionService;

    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    @PostMapping
    @Operation(summary = "Post transaction",
            description = """
                       Posts a balanced double-entry transaction.
                       
                       **Rational arithmetic:** all monetary values use `valueNum / valueDenom`.
                       Example: MXN $500.00 → `valueNum: 50000, valueDenom: 100`.
                       All splits in one request **must share the same `valueDenom`**.
                       
                       **Balance rule:** `SUM(valueNum WHERE side=0)` must equal
                       `SUM(valueNum WHERE side=1)`. Enforced by the database.
                       
                       **Side values:** `0` = DEBIT, `1` = CREDIT.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Transaction posted",
                    content = @Content(schema = @Schema(implementation = TransactionResponse.class))),
            @ApiResponse(responseCode = "400", description = "Unbalanced splits, wrong accounts, or DB validation failure", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content)
    })
    public ResponseEntity<TransactionResponse> postTransaction(
            @Valid @RequestBody PostTransactionRequest request) {
        TransactionResponse created = transactionService.postTransaction(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @PostMapping("/{id}/reverse")
    @Operation(summary = "Reverse transaction",
            description = """
                       Creates a mirror reversal transaction with all split sides flipped (DEBIT↔CREDIT).
                       Marks the original transaction with `reversedByTxId`.
                       
                       **Guards (enforced by database):**
                       - Cannot reverse a voided transaction.
                       - Cannot reverse a deleted transaction.
                       - Cannot reverse a transaction that has already been reversed.
                       
                       All body fields are optional — send `{}` for a default reversal.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Reversal transaction created",
                    content = @Content(schema = @Schema(implementation = TransactionResponse.class))),
            @ApiResponse(responseCode = "400", description = "Transaction already reversed, voided, or deleted", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content),
            @ApiResponse(responseCode = "404", description = "Transaction not found or not owned by caller", content = @Content)
    })
    public ResponseEntity<TransactionResponse> reverseTransaction(
            @Parameter(description = "UUID of the transaction to reverse")
            @PathVariable UUID id,
            @RequestBody(required = false) ReverseTransactionRequest request) {
        if (request == null) request = new ReverseTransactionRequest(null, null, null);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transactionService.reverseTransaction(id, request));
    }

    @PostMapping("/{id}/void")
    @Operation(summary = "Void transaction",
            description = """
                       Marks a transaction as voided in-place. Does **not** create a new transaction.
                       Sets `isVoided = true`, `voidedAt = now()`, and appends `[VOID: reason]`
                       to the transaction memo if a reason is provided.
                       
                       **Guards (enforced by database):**
                       - Cannot void an already-voided transaction.
                       
                       Send `{}` if no reason is needed.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Transaction voided — isVoided will be true",
                    content = @Content(schema = @Schema(implementation = TransactionResponse.class))),
            @ApiResponse(responseCode = "400", description = "Transaction is already voided", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content),
            @ApiResponse(responseCode = "404", description = "Transaction not found or not owned by caller", content = @Content)
    })
    public ResponseEntity<TransactionResponse> voidTransaction(
            @Parameter(description = "UUID of the transaction to void")
            @PathVariable UUID id,
            @RequestBody(required = false) VoidTransactionRequest request) {
        if (request == null) request = new VoidTransactionRequest(null);
        return ResponseEntity.status(HttpStatus.OK)
                .body(transactionService.voidTransaction(id, request));
    }
}
