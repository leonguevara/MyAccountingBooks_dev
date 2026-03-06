// ============================================================
// AccountService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic layer for account (COA) operations.
//
//          Responsibilities:
//            1. Resolve ownerID from the SecurityContext (JWT)
//            2. Validate the requested ledger belongs to this owner
//            3. Delegate to AccountRepository for the DB query
//            4. Return the structured AccountResponse list to controller
//
//          Security posture:
//            - ownerID always from JWT, never from request params
//            - Ledger ownership verified before any account query
//            - RLS provides a second layer of enforcement at DB level
// ============================================================
// Last edited: 2026-03-05
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.AccountRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

// SecurityContextHolder: retrieves the current request's authentication.
import org.springframework.security.core.context.SecurityContextHolder;

// HttpStatus: HTTP status code constants.
import org.springframework.http.HttpStatus;

// @Service: registers this as a Spring-managed service bean.
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class AccountService {

    // Data access layer for account queries.
    private final AccountRepository accountRepository;

    /**
     * Constructor injection of AccountRepository.
     *
     * @param accountRepository The repository bean for account data access.
     */
    public AccountService(AccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    /**
     * Returns all accounts for a given ledger as a flat list.
     * <p>
     * The ownerID is always resolved from the JWT stored in the
     * SecurityContext — never passed as a parameter from the controller.
     * <p>
     * Flow:
     *   1. Resolve ownerID from JWT
     *   2. Verify the ledger exists and belongs to this owner (→ 404 if not)
     *   3. Query all accounts for the ledger (flat list, ordered by code)
     *   4. Return the list — client reconstructs the tree using parentId
     *
     * @param  ledgerID The UUID of the ledger whose COA to retrieve.
     *                  Comes from the URL path variable in the controller.
     * @return          Flat list of AccountResponse objects.
     * @throws ApiException HTTP 401 if not authenticated.
     * @throws ApiException HTTP 404 if ledger not found or not owned by the caller.
     */
    public List<AccountResponse> getAccountsForLedger(UUID ledgerID) {

        // Step 1: resolve the owner from JWT.
        UUID ownerID = resolveOwnerID();

        // Step 2: verify ledger ownership before querying accounts.
        // This gives a clean 404 rather than a silent empty list
        // when the ledger ID is invalid or belongs to another owner.
        if (!accountRepository.ledgerExists(ownerID, ledgerID)) {
            throw new ApiException(HttpStatus.NOT_FOUND,
                    "Ledger not found: " + ledgerID);
        }

        // Step 3: fetch all accounts for this ledger.
        return accountRepository.findAllByLedger(ownerID, ledgerID);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * Extracts the authenticated owner's UUID from the Spring SecurityContext.
     * <p>
     * JwtAuthFilter populates this context on every authenticated request.
     *
     * @return The ownerID UUID of the authenticated ledger_owner.
     * @throws ApiException HTTP 401 if no valid authentication is present.
     */
    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();

        // It had the instance of UserPrincipal principal, but I'm replacing it with
        // a record pattern.
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "Authentication required");
        }

        // replaced principal.ownerID() with ownerID
        return ownerID;
    }
}