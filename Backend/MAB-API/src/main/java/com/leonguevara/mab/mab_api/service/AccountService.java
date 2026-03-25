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
// Last edited: 2026-03-25
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.AccountRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;
import com.leonguevara.mab.mab_api.dto.request.CreateAccountRequest;
import com.leonguevara.mab.mab_api.dto.request.PatchAccountRequest;
import com.leonguevara.mab.mab_api.dto.response.AccountTypeResponse;

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

    /**
     * Creates a new account in the specified ledger.
     * <p>
     * This method acts as a thin orchestration layer: it resolves the authenticated
     * owner's UUID from the JWT in SecurityContext and delegates to the repository
     * layer for the actual account creation.
     * <p>
     * <strong>Security:</strong> The {@code ownerID} is NEVER passed from the controller
     * or request body. It is always resolved from the JWT token, ensuring users can
     * only create accounts in ledgers they own.
     * <p>
     * <strong>Validation:</strong> Business-level validation (e.g., parent account exists,
     * ledger ownership, account type validity) is enforced by:
     * <ul>
     *   <li>Row-Level Security (RLS) at the database layer</li>
     *   <li>Foreign key constraints on {@code ledger_id}, {@code parent_id}, {@code account_type_id}</li>
     * </ul>
     * If validation fails, the repository layer will throw a Spring DAO exception,
     * which is automatically converted to an appropriate HTTP error by the global
     * exception handler.
     *
     * @param request The account creation request containing ledger ID, name, parent, type, etc.
     * @return        The newly created account as an {@link AccountResponse}.
     * @throws ApiException HTTP 401 if not authenticated (no valid JWT).
     * @throws org.springframework.dao.DataAccessException if database constraints are violated
     *         (e.g., invalid parent ID, invalid ledger ID, invalid account type code).
     */
    public AccountResponse createAccount(CreateAccountRequest request) {
        UUID ownerID = resolveOwnerID();
        return accountRepository.create(ownerID, request);
    }

    /**
     * Partially updates an existing account with sparse field updates.
     * <p>
     * This method implements JSON Merge Patch semantics (RFC 7396): only non-null
     * fields in the {@link PatchAccountRequest} are applied to the database. Fields
     * set to {@code null} retain their existing values.
     * <p>
     * <strong>Security:</strong> The {@code ownerID} is resolved from the JWT token,
     * ensuring users can only modify accounts in ledgers they own. Row-Level Security
     * (RLS) at the database layer provides an additional enforcement layer.
     * <p>
     * <strong>Validation:</strong> Field-level validation (e.g., parent account exists,
     * account type code is valid) is enforced by:
     * <ul>
     *   <li>Row-Level Security (RLS) at the database layer</li>
     *   <li>Foreign key constraints on {@code parent_id}, {@code account_type_id}</li>
     * </ul>
     * <p>
     * <strong>Important constraints:</strong>
     * <ul>
     *   <li>Changing {@code parentId} can move an account to a different subtree, but
     *       must not create circular references (not validated at this layer)</li>
     *   <li>Converting a non-placeholder account to a placeholder (setting
     *       {@code isPlaceholder} to {@code true}) should only be done if the account
     *       has no posted transactions (not validated at this layer)</li>
     *   <li>Changing {@code accountTypeCode} on accounts with existing transactions
     *       may violate business rules (not validated at this layer)</li>
     * </ul>
     *
     * @param accountId The UUID of the account to update (from URL path parameter).
     * @param request   The patch request with nullable fields (only non-null fields are applied).
     * @return          The updated account as an {@link AccountResponse}.
     * @throws ApiException HTTP 401 if not authenticated (no valid JWT).
     * @throws org.springframework.dao.EmptyResultDataAccessException if the account does not
     *         exist or does not belong to the authenticated owner.
     * @throws org.springframework.dao.DataAccessException if database constraints are violated
     *         (e.g., invalid parent ID, invalid account type code).
     */
    public AccountResponse patchAccount(UUID accountId, PatchAccountRequest request) {
        UUID ownerID = resolveOwnerID();
        return accountRepository.patch(ownerID, accountId, request);
    }

    /**
     * Retrieves the complete catalog of account types.
     * <p>
     * Account types define the functional classification of accounts (BANK, CASH,
     * RECEIVABLE, PAYABLE, EQUITY, STOCK, etc.) and are system-wide—not tenant-scoped.
     * They are seeded during schema bootstrap via {@code 002_Populating_account_type.pgsql}.
     * <p>
     * <strong>No authentication required:</strong> This method does NOT call
     * {@link #resolveOwnerID()} because account types are shared across all owners.
     * The endpoint can be accessed without JWT authentication (depending on
     * SecurityConfig settings) as it returns public reference data.
     * <p>
     * Results are ordered by {@code sort_order ASC}, providing a natural display
     * order for UI dropdowns when creating or editing accounts.
     * <p>
     * This is typically called by:
     * <ul>
     *   <li>Account creation forms (to populate the account type dropdown)</li>
     *   <li>Account editing forms (to show available account types)</li>
     *   <li>COA template management interfaces</li>
     * </ul>
     *
     * @return A list of all active {@link AccountTypeResponse} objects, ordered by
     *         {@code sort_order}. Never returns null; returns an empty list if no
     *         account types exist (which should never happen in a properly seeded database).
     */
    public List<AccountTypeResponse> getAccountTypes() {
        return accountRepository.findAllAccountTypes();
    }
}