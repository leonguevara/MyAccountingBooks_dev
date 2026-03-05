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
import jakarta.validation.Valid;

// ResponseEntity: wraps a response body + HTTP status code together.
//   Used here to return HTTP 201 Created on successful ledger creation.
import org.springframework.http.ResponseEntity;

// HttpStatus: HTTP status code constants.
import org.springframework.http.HttpStatus;

import java.util.List;

@RestController
@RequestMapping("/ledgers")
public class LedgerController {

    // Service layer handles all business logic and DB delegation.
    private final LedgerService ledgerService;

    /**
     * Constructor injection of LedgerService.
     *
     * @param ledgerService The ledger business logic service bean.
     */
    public LedgerController(LedgerService ledgerService) {
        this.ledgerService = ledgerService;
    }

    /**
     * GET /ledgers
     * <p>
     * Returns all active ledgers belonging to the authenticated owner.
     * The owner is resolved from the JWT — no query parameter is needed.
     *
     * @return HTTP 200 with a JSON array of LedgerResponse objects.
     *         Returns an empty array [] if the owner has no ledgers yet.
     */
    @GetMapping
    public List<LedgerResponse> getAllLedgers() {
        return ledgerService.getAllLedgers();
    }

    /**
     * POST /ledgers
     * <p>
     * Creates a new ledger for the authenticated owner.
     * Optionally instantiates a COA template if code and version are provided.
     * <p>
     * Returns HTTP 201 Created (not 200) to follow REST conventions
     * for resource creation.
     *
     * @param  request The validated ledger creation parameters.
     * @return         HTTP 201 with the created LedgerResponse as the JSON body.
     */
    @PostMapping
    public ResponseEntity<LedgerResponse> createLedger(
            @Valid @RequestBody CreateLedgerRequest request) {

        LedgerResponse created = ledgerService.createLedger(request);

        // ResponseEntity.status(CREATED).body(...) returns HTTP 201.
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(created);
    }
}