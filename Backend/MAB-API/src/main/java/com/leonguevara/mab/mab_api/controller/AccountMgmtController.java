// ============================================================
// AccountMgmtController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for account management operations
//          that are NOT scoped under a specific ledger path:
//
//          POST  /accounts             — create a new account
//          PATCH /accounts/{accountId} — partially update an account
//
//          These routes cannot live in AccountController because
//          that controller is mapped to /ledgers, which would cause:
//          - POST /ledgers → collision with LedgerController
//
//          The account type catalog (GET /account-types) lives in
//          AccountTypeController to avoid prefix ambiguity between
//          /accounts and /account-types.
// ============================================================
// Last edited: 2026-03-26
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreateAccountRequest;
import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.dto.response.AccountTypeResponse;
import com.leonguevara.mab.mab_api.service.AccountService;
import com.leonguevara.mab.mab_api.dto.request.PatchAccountRequest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping
@Tag(name = "Account Management",
        description = "Create and partially update accounts in a ledger's chart of accounts")
@SecurityRequirement(name = "bearerAuth")
public class AccountMgmtController {

    private final AccountService accountService;

    /**
     * Constructor injection of AccountService.
     * <p>
     * Spring automatically wires the AccountService bean when instantiating
     * this controller.
     *
     * @param accountService The service layer for account operations.
     */
    public AccountMgmtController(AccountService accountService) {
        this.accountService = accountService;
    }

    // ── POST /accounts ────────────────────────────────────────────────────────

    /**
     * Creates a new account in a ledger's chart of accounts.
     * <p>
     * <strong>REST route:</strong> {@code POST /accounts}
     * <p>
     * <strong>Request body:</strong> The {@link CreateAccountRequest} contains all required
     * fields including {@code ledgerId}, {@code name}, {@code parentId}, and optionally
     * {@code code}, {@code accountTypeCode}, {@code accountRole}, {@code isPlaceholder},
     * and {@code isHidden}.
     * <p>
     * <strong>Security:</strong> Requires JWT authentication. The owner ID is resolved
     * from the JWT token. Row-Level Security (RLS) ensures the authenticated user can
     * only create accounts in ledgers they own. If the {@code ledgerId} in the request
     * belongs to another owner, the operation will fail with HTTP 404.
     * <p>
     * <strong>Parent account:</strong> The {@code parentId} is REQUIRED. All accounts
     * (except the root account, which is auto-created during ledger instantiation) must
     * have a parent. The new account inherits its {@code kind} (Asset/Liability/etc.),
     * {@code commodity_id}, and {@code commodity_scu} from the parent automatically.
     * <p>
     * <strong>Account type:</strong> For non-placeholder (posting) accounts,
     * {@code accountTypeCode} is REQUIRED and must match an active {@code account_type.code}
     * in the database (e.g., "BANK", "CASH", "RECEIVABLE"). Placeholder accounts
     * (grouping-only nodes) do not require an account type.
     * <p>
     * <strong>Opening balances:</strong> This endpoint does NOT support setting an opening
     * balance. To establish an opening balance, create the account first, then post a
     * transaction using {@code POST /transactions} with splits that credit/debit the
     * new account against an equity account (e.g., "Opening Balances Equity").
     * <p>
     * <strong>Response:</strong> Returns HTTP 201 Created with the newly created account
     * in the response body, including its auto-generated UUID.
     *
     * @param request The account creation request containing ledger ID, name, parent, type, etc.
     *                See {@link CreateAccountRequest} for field descriptions.
     * @return        HTTP 201 with the newly created {@link AccountResponse}.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 400 if validation fails
     *         (e.g., missing required fields, invalid account type code).
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if no valid JWT token.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 404 if the ledger or
     *         parent account does not exist or does not belong to the authenticated owner.
     * @throws org.springframework.dao.DataAccessException if database constraints are violated.
     */
    @PostMapping("/accounts")
    @Operation(summary = "Create account",
            description = """
                       Creates a new account in the ledger's chart of accounts.

                       The `ledgerId` in the request body determines which ledger
                       the account belongs to. The authenticated owner must own
                       that ledger (enforced via RLS).

                       The `parentId` is required. The new account inherits `kind`
                       and `commodityId` from the parent automatically.

                       For non-placeholder accounts, `accountTypeCode` is required
                       and must match an active entry in the `account_type` catalog.

                       If `openingBalance` is needed, post a transaction manually
                       after creation using `POST /transactions`.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Account created",
                    content = @Content(schema = @Schema(
                            implementation = AccountResponse.class))),
            @ApiResponse(responseCode = "400",
                    description = "Invalid request — missing required fields or " +
                            "account type not found",
                    content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404",
                    description = "Ledger or parent account not found",
                    content = @Content)
    })
    public ResponseEntity<AccountResponse> createAccount(
            @RequestBody CreateAccountRequest request) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(accountService.createAccount(request));
    }

    // ── PATCH /accounts/{accountId} ───────────────────────────────────────────

    /**
     * Partially updates an existing account.
     * <p>
     * <strong>REST route:</strong> {@code PATCH /accounts/{accountId}}
     * <p>
     * <strong>Partial update semantics:</strong> Only fields present (non-null) in the
     * {@link PatchAccountRequest} body are applied. Fields omitted from the request are
     * left unchanged. This follows standard HTTP PATCH semantics.
     * <p>
     * <strong>Updatable fields:</strong> Clients may patch {@code name}, {@code code},
     * {@code accountTypeCode}, {@code accountRole}, {@code isPlaceholder}, and
     * {@code isHidden}. Fields that define the account's structural position in the chart
     * of accounts (e.g., {@code parentId}, {@code ledgerId}, {@code kind}) cannot be
     * changed after creation.
     * <p>
     * <strong>Security:</strong> Requires JWT authentication. The owner ID is resolved
     * from the JWT token. Row-Level Security (RLS) ensures the authenticated user can
     * only update accounts that belong to ledgers they own. If {@code accountId} belongs
     * to another owner's ledger, the operation will fail with HTTP 404 (not 403, to
     * avoid leaking existence information).
     * <p>
     * <strong>No ledger ID in path:</strong> Unlike some routes, this endpoint does not
     * require the ledger ID in the URL. RLS enforces ownership at the DB level using
     * the JWT-derived owner ID, so the ledger is not needed for authorization.
     * <p>
     * <strong>Response:</strong> Returns HTTP 200 OK with the full updated account in
     * the response body, reflecting all current field values after the patch is applied.
     *
     * @param accountId The UUID of the account to update.
     * @param request   The patch request containing only the fields to be updated.
     *                  See {@link PatchAccountRequest} for field descriptions.
     * @return          HTTP 200 with the updated {@link AccountResponse}.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 400 if the patch
     *         data is invalid (e.g., unrecognized {@code accountTypeCode}).
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if no valid
     *         JWT token is present.
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 404 if the account
     *         does not exist or does not belong to the authenticated owner.
     */
    @PatchMapping("/accounts/{accountId}")
    @Operation(summary = "Update account",
            description = """
               Partially updates an account. Only non-null fields are applied.
               Ledger ownership is enforced via RLS — no ledgerId needed in the path.
               """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Account updated"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404", description = "Account not found",
                    content = @Content)
    })
    public ResponseEntity<AccountResponse> patchAccount(
            @PathVariable UUID accountId,
            @RequestBody PatchAccountRequest request) {
        return ResponseEntity.ok(accountService.patchAccount(accountId, request));
    }
}