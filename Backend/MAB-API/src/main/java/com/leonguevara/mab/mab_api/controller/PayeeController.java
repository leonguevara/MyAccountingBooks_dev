// ============================================================
// PayeeController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST endpoints for payee management.
//          GET  /ledgers/{id}/payees  — list payees for a ledger
//          POST /payees               — create a new payee
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreatePayeeRequest;
import com.leonguevara.mab.mab_api.dto.response.PayeeResponse;
import com.leonguevara.mab.mab_api.service.PayeeService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@Tag(name = "Payees", description = "Payee management — list and create payees per ledger")
@SecurityRequirement(name = "bearerAuth")
public class PayeeController {

    private final PayeeService payeeService;

    public PayeeController(PayeeService payeeService) {
        this.payeeService = payeeService;
    }

    @GetMapping("/ledgers/{ledgerID}/payees")
    @Operation(summary = "List payees",
            description = "Returns all active payees for the given ledger, ordered by name.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Payee list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public List<PayeeResponse> getPayees(
            @PathVariable UUID ledgerID) {
        return payeeService.getPayeesForLedger(ledgerID);
    }

    @PostMapping("/payees")
    @Operation(summary = "Create payee",
            description = """
                    Creates a new payee in the specified ledger.
                    The (ledger_id, name) combination must be unique.
                    Returns HTTP 409 if a payee with the same name already exists.
                    """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Payee created",
                    content = @Content(schema = @Schema(implementation = PayeeResponse.class))),
            @ApiResponse(responseCode = "400", description = "Validation error",
                    content = @Content),
            @ApiResponse(responseCode = "409", description = "Payee name already exists in this ledger",
                    content = @Content)
    })
    public ResponseEntity<PayeeResponse> createPayee(
            @Valid @RequestBody CreatePayeeRequest request) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(payeeService.createPayee(request));
    }
}