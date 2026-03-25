// ============================================================
// AccountController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for account (COA) endpoints.
//
//          Route: GET /ledgers/{ledgerId}/accounts
//
//          The ledger ID is in the path (not a query parameter)
//          following REST resource nesting conventions:
//            /ledgers/{ledgerId}/accounts
//          This expresses: "the accounts that belong to this ledger"
//
//          All routes require authentication — enforced globally
//          by SecurityConfig. No per-method annotations needed.
// ============================================================
// Last edited: 2026-03-25
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.service.AccountService;
import com.leonguevara.mab.mab_api.dto.request.PatchAccountRequest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;


// @RestController: REST controller — return values serialized as JSON.
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

// @RequestMapping: base URL path for this controller.
import org.springframework.web.bind.annotation.RequestMapping;

// @GetMapping: maps HTTP GET to a handler method.
import org.springframework.web.bind.annotation.GetMapping;

// @PathVariable: extracts a value from the URL path (e.g. {ledgerId}).
import org.springframework.web.bind.annotation.PathVariable;

import org.springframework.web.bind.annotation.RequestBody;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/ledgers")
@Tag(name = "Accounts", description = "Chart of Accounts — retrieve account tree for a ledger")
@SecurityRequirement(name = "bearerAuth")
public class AccountController {

    private final AccountService accountService;

    /**
     * Constructor injection of AccountService.
     * <p>
     * Spring automatically wires the AccountService bean when instantiating
     * this controller.
     *
     * @param accountService The service layer for account operations.
     */
    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    // ── GET /ledgers/{ledgerId}/accounts ─────────────────────────────────────

    /**
     * Retrieves all accounts for a ledger as a flat list.
     * <p>
     * <strong>REST route:</strong> {@code GET /ledgers/{ledgerId}/accounts}
     * <p>
     * <strong>Response format:</strong> Returns accounts as a flat list (not nested JSON).
     * Clients must use the {@code parentId} field on each account to reconstruct the
     * tree hierarchy locally. This approach is optimal for multi-platform clients and
     * allows flexible client-side rendering (tree view, flat view, filtered views, etc.).
     * <p>
     * <strong>Ordering:</strong> Accounts are sorted by {@code code ASC} (with {@code name}
     * as fallback for accounts without codes), providing a natural Chart of Accounts
     * display order.
     * <p>
     * <strong>Security:</strong> Requires JWT authentication. The owner ID is resolved
     * from the JWT token, and Row-Level Security (RLS) ensures only accounts in ledgers
     * owned by the authenticated user are returned. If the ledger doesn't exist or
     * belongs to another owner, HTTP 404 is returned.
     * <p>
     * <strong>Placeholder accounts:</strong> Grouping-only nodes (which cannot receive
     * transactions) are included in the response with {@code isPlaceholder: true}.
     *
     * @param ledgerId The UUID of the ledger whose accounts to retrieve (from URL path).
     * @return         A flat list of {@link AccountResponse} objects, ordered by code.
     *                 Returns an empty list if the ledger has no accounts (rare, as
     *                 ledgers created from COA templates have at least a root account).
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if no valid JWT token.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 404 if ledger not found
     *         or not owned by the authenticated user.
     */
    @GetMapping("/{ledgerId}/accounts")
    @Operation(summary = "Get Chart of Accounts",
            description = """
                       Returns all active accounts for the specified ledger as a **flat list**.
                       Use the `parentId` field on each account to reconstruct the tree hierarchy
                       on the client side.

                       Accounts are ordered by `code ASC`. Placeholder accounts (grouping nodes
                       that cannot receive transactions) are included and marked with
                       `isPlaceholder: true`.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Flat list of accounts"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content),
            @ApiResponse(responseCode = "404", description = "Ledger not found or not owned by caller", content = @Content)
    })
    public List<AccountResponse> getAccounts(
            @Parameter(description = "UUID of the ledger whose accounts to retrieve")
            @PathVariable UUID ledgerId) {
        return accountService.getAccountsForLedger(ledgerId);
    }

    // ── PATCH /ledgers/{ledgerId}/accounts/{accountId} ────────────────────────

    /**
     * Partially updates an existing account with sparse field updates.
     * <p>
     * <strong>REST route:</strong> {@code PATCH /ledgers/{ledgerId}/accounts/{accountId}}
     * <p>
     * <strong>Update semantics:</strong> Implements JSON Merge Patch (RFC 7396). Only
     * non-null fields in the request body are applied to the account. Fields set to
     * {@code null} retain their existing database values. This allows clients to update
     * specific fields (e.g., just the name) without needing to send the entire account object.
     * <p>
     * <strong>Security:</strong> Requires JWT authentication. The owner ID is resolved
     * from the JWT token, and Row-Level Security (RLS) ensures only accounts in ledgers
     * owned by the authenticated user can be modified.
     * <p>
     * <strong>Path parameters:</strong>
     * <ul>
     *   <li>{@code ledgerId} — Currently included for REST resource nesting but not used
     *       in validation. Future versions may enforce that the account belongs to this ledger.</li>
     *   <li>{@code accountId} — The UUID of the account to update.</li>
     * </ul>
     * <p>
     * <strong>Editable fields:</strong> name, code, parentId, accountTypeCode, accountRole,
     * isPlaceholder, isHidden. See {@link PatchAccountRequest} for field descriptions and constraints.
     * <p>
     * <strong>Important constraints:</strong>
     * <ul>
     *   <li>Changing {@code parentId} must not create circular references (not validated at API layer)</li>
     *   <li>Converting to placeholder ({@code isPlaceholder: true}) should only be done if
     *       the account has no posted transactions (not validated at API layer)</li>
     *   <li>Changing {@code accountTypeCode} on accounts with transactions may violate
     *       business rules (not validated at API layer)</li>
     * </ul>
     *
     * @param ledgerId  The UUID of the ledger (from URL path). Currently not used for validation.
     * @param accountId The UUID of the account to update (from URL path).
     * @param request   The patch request body with nullable fields. Only non-null fields are applied.
     * @return          HTTP 200 with the updated {@link AccountResponse} in the response body.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if no valid JWT token.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 404 if account not found
     *         or not owned by the authenticated user.
     * @throws org.springframework.dao.DataAccessException if database constraints are violated
     *         (e.g., invalid parent ID, invalid account type code).
     */
    @Operation(summary = "Update account",
            description = "Partially updates an account. Only non-null fields are applied.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Account updated"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404", description = "Account not found",
                    content = @Content)
    })
    public ResponseEntity<AccountResponse> patchAccount(
            @PathVariable UUID ledgerId,
            @PathVariable UUID accountId,
            @RequestBody PatchAccountRequest request) {
        return ResponseEntity.ok(accountService.patchAccount(accountId, request));
    }

}
