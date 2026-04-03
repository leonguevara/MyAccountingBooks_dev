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

/**
 * REST controller exposing payee management endpoints.
 *
 * <table border="1">
 *   <caption>Routes</caption>
 *   <tr><th>Method</th><th>Path</th><th>Description</th></tr>
 *   <tr><td>GET</td><td>{@code /ledgers/{ledgerID}/payees}</td><td>List payees for a ledger</td></tr>
 *   <tr><td>POST</td><td>{@code /payees}</td><td>Create a new payee</td></tr>
 * </table>
 *
 * <p>All routes require a valid Bearer token. Business logic is fully delegated to
 * {@link PayeeService}; this class handles only HTTP routing and response codes.</p>
 *
 * @see PayeeService
 * @see CreatePayeeRequest
 * @see PayeeResponse
 */
@RestController
@Tag(name = "Payees", description = "Payee management — list and create payees per ledger")
@SecurityRequirement(name = "bearerAuth")
public class PayeeController {

    private final PayeeService payeeService;

    /**
     * Constructs the controller with its required {@link PayeeService} dependency.
     *
     * @param payeeService service handling payee retrieval and creation
     */
    public PayeeController(PayeeService payeeService) {
        this.payeeService = payeeService;
    }

    /**
     * Returns all active payees for the given ledger, ordered by name.
     *
     * <p>Delegates to {@link PayeeService#getPayeesForLedger(UUID)}. RLS ensures only
     * payees belonging to the authenticated owner's ledger are returned.</p>
     *
     * @param ledgerID the UUID of the ledger whose payees are requested
     * @return list of {@link PayeeResponse} objects, possibly empty
     */
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

    /**
     * Creates a new payee in the ledger specified by the request body.
     *
     * <p>The {@code (ledger_id, name)} combination must be unique within the ledger.
     * {@code @Valid} triggers Bean Validation before the method is entered.</p>
     *
     * @param request validated request body containing {@code ledgerId} and {@code name}
     * @return HTTP 201 with the created {@link PayeeResponse}
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 400 on constraint violations,
     *         HTTP 409 when a payee with the same name already exists in the ledger
     * @see CreatePayeeRequest
     */
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