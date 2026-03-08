// ============================================================
// LedgerController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for ledger endpoints.
//
//          All routes here require authentication (JWT).
//          This is enforced globally by SecurityConfig —
//          no per-method security annotations are needed.
//
//          The controller is intentionally thin:
//            - Receives and validates HTTP input
//            - Delegates to LedgerService for business logic
//            - Returns the response body
//          No SQL, no business rules, no ownerID resolution here.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreateLedgerRequest;
import com.leonguevara.mab.mab_api.dto.response.LedgerResponse;
import com.leonguevara.mab.mab_api.service.LedgerService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

// @RestController: marks this as a REST API controller.
//   All method return values are serialized as JSON automatically.
import org.springframework.web.bind.annotation.RestController;

// @RequestMapping: sets the base URL path for all routes in this controller.
import org.springframework.web.bind.annotation.RequestMapping;

// @GetMapping: maps HTTP GET requests to a handler method.
import org.springframework.web.bind.annotation.GetMapping;

// @PostMapping: maps HTTP POST requests to a handler method.
import org.springframework.web.bind.annotation.PostMapping;

// @RequestBody: deserializes the incoming JSON body into a Java object.
import org.springframework.web.bind.annotation.RequestBody;

// @Valid: triggers Bean Validation on the @RequestBody.
//   Returns HTTP 400 automatically if validation fails.
// import jakarta.validation.Valid;

// ResponseEntity: wraps a response body + HTTP status code together.
//   Used here to return HTTP 201 Created on successful ledger creation.
import org.springframework.http.ResponseEntity;

// HttpStatus: HTTP status code constants.
import org.springframework.http.HttpStatus;

import java.util.List;

@RestController
@RequestMapping("/ledgers")
@Tag(name = "Ledgers", description = "Ledger management — create and list ledgers")
@SecurityRequirement(name = "bearerAuth")
public class LedgerController {

    private final LedgerService ledgerService;

    public LedgerController(LedgerService ledgerService) {
        this.ledgerService = ledgerService;
    }

    @GetMapping
    @Operation(summary = "List ledgers",
            description = "Returns all active ledgers owned by the authenticated user.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "List of ledgers"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content)
    })
    public List<LedgerResponse> getLedgers() {
        return ledgerService.getAllLedgers();
    }

    @PostMapping
    @Operation(summary = "Create ledger",
            description = """
                       Creates a new ledger for the authenticated owner.
                       Optionally instantiates a Chart of Accounts from a template
                       by providing `coaTemplateCode` and `coaTemplateVersion`.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Ledger created",
                    content = @Content(schema = @Schema(implementation = LedgerResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request body", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content)
    })
    public ResponseEntity<LedgerResponse> createLedger(
            @RequestBody CreateLedgerRequest request) {
        LedgerResponse created = ledgerService.createLedger(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }
}
