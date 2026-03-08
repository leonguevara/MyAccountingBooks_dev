// ============================================================
// LedgerService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic layer for ledger operations.
//
//          Sits between LedgerController (HTTP layer) and
//          LedgerRepository (data access layer). Responsible for:
//            - Extracting the ownerID from the Spring
//              SecurityContext (set by JwtAuthFilter)
//            - Applying any business rules before/after DB calls
//            - Delegating to LedgerRepository for actual queries
//
//          The ownerID is ALWAYS taken from the authenticated
//          SecurityContext — never from the request body or URL.
//          This prevents horizontal privilege escalation (a user
//          cannot request another owner's ledgers by forging an ID).
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.request.CreateLedgerRequest;
import com.leonguevara.mab.mab_api.dto.response.LedgerResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.LedgerRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

// SecurityContextHolder: Spring's thread-local store for the current
//   request's authentication object (set by JwtAuthFilter).
import org.springframework.security.core.context.SecurityContextHolder;

// HttpStatus: HTTP status code constants.
import org.springframework.http.HttpStatus;

// @Service: registers this class as a Spring-managed service bean.
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class LedgerService {

    // Data access layer for ledger queries and stored function calls.
    private final LedgerRepository ledgerRepository;

    /**
     * Constructor injection of LedgerRepository.
     *
     * @param ledgerRepository The repository bean for ledger data access.
     */
    public LedgerService(LedgerRepository ledgerRepository) {
        this.ledgerRepository = ledgerRepository;
    }

    /**
     * Returns all ledgers belonging to the currently authenticated owner.
     * <p>
     * The ownerID is extracted from the SecurityContext (JWT), never
     * from a request parameter — this is the correct security posture.
     *
     * @return List of LedgerResponse objects for the current owner.
     * @throws ApiException HTTP 401 if no authenticated principal is found.
     */
    public List<LedgerResponse> getAllLedgers() {
        UUID ownerID = resolveOwnerID();
        return ledgerRepository.findAllByOwner(ownerID);
    }

    /**
     * Creates a new ledger for the currently authenticated owner.
     * <p>
     * Delegates to the PostgreSQL function via LedgerRepository.
     * The DB function handles all validation — the service layer
     * only resolves the ownerID and passes the request fields through.
     *
     * @param  request The validated CreateLedgerRequest from the controller.
     * @return         The newly created LedgerResponse.
     * @throws ApiException HTTP 401 if no authenticated principal is found.
     */
    public LedgerResponse createLedger(CreateLedgerRequest request) {
        UUID ownerID = resolveOwnerID();

        return ledgerRepository.create(
                ownerID,
                request.name(),
                request.currencyMnemonic(),
                request.decimalPlaces(),
                request.coaTemplateCode(),     // nullable
                request.coaTemplateVersion()   // nullable
        );
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * Extracts the authenticated owner's UUID from the Spring SecurityContext.
     * <p>
     * JwtAuthFilter stores a UserPrincipal as the Authentication principal
     * after validating the JWT. This method retrieves it safely.
     *
     * @return The ownerID UUID of the authenticated ledger_owner.
     * @throws ApiException HTTP 401 if the SecurityContext has no principal.
     */
    private UUID resolveOwnerID() {
        // getAuthentication(): returns the Authentication object stored by
        //   JwtAuthFilter, or null if the request was not authenticated.
        var auth = SecurityContextHolder.getContext().getAuthentication();

        // UserPrincipal principal replaced with a record pattern.
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "Authentication required");
        }

        // Return the ownerID that was extracted from the JWT.
        // principal.ownerID() replaced with ownerID
        return ownerID;
    }
}
