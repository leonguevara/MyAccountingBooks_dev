// ============================================================
// AccountMgmtController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for account management operations
//          that are NOT scoped under a specific ledger path:
//
//          POST /accounts             — create a new account
//          GET  /account-types        — fetch account type catalog
//
//          These routes cannot live in AccountController because
//          that controller is mapped to /ledgers, which would cause:
//          - POST /ledgers      → collision with LedgerController
//          - GET /ledgers/account-types → "account-types" matched
//            as {ledgerId} path variable (routing conflict)
//
//          Separating them here keeps routing unambiguous.
// ============================================================
// Last edited: 2026-03-25
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreateAccountRequest;
import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.dto.response.AccountTypeResponse;
import com.leonguevara.mab.mab_api.service.AccountService;

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

import java.util.List;

@RestController
@RequestMapping
@Tag(name = "Account Management",
        description = "Create accounts and retrieve the account type catalog")
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

    // ── GET /account-types ────────────────────────────────────────────────────

    /**
     * Retrieves the complete catalog of account types.
     * <p>
     * <strong>REST route:</strong> {@code GET /account-types}
     * <p>
     * <strong>Purpose:</strong> Account types define the functional classification of
     * accounts (BANK, CASH, RECEIVABLE, PAYABLE, EQUITY, STOCK, etc.) and are used when
     * creating or updating accounts. This endpoint provides the reference data needed to
     * populate account type dropdowns in client applications.
     * <p>
     * <strong>System-wide catalog:</strong> Account types are NOT tenant-scoped—they are
     * shared across all owners and are seeded during schema bootstrap via
     * {@code 002_Populating_account_type.pgsql}. The same catalog is available to all users.
     * <p>
     * <strong>Authentication:</strong> Requires JWT authentication (enforced by
     * {@code @SecurityRequirement}). Although account types are system-wide, the endpoint
     * is protected to maintain consistent auth requirements across the API.
     * <p>
     * <strong>Response format:</strong> Returns a list of {@link AccountTypeResponse}
     * objects, each containing:
     * <ul>
     *   <li>{@code id} — UUID primary key</li>
     *   <li>{@code code} — Stable functional code (use this value for {@code accountTypeCode}
     *       when creating/updating accounts)</li>
     *   <li>{@code name} — Human-readable display name</li>
     *   <li>{@code kind} — Accounting nature (1=Asset, 2=Liability, 3=Equity, 4=Revenue,
     *       5=Gain/Loss, 6=Expense)</li>
     *   <li>{@code normalBalance} — 0=Debit, 1=Credit</li>
     *   <li>{@code sortOrder} — Display order hint for UI</li>
     * </ul>
     * <p>
     * <strong>Ordering:</strong> Results are ordered by {@code sortOrder ASC}, providing
     * a natural display order for UI dropdowns.
     * <p>
     * <strong>Filtering:</strong> Only active, non-deleted account types are returned.
     * <p>
     * <strong>Typical usage:</strong>
     * <ul>
     *   <li>Populating the account type dropdown in account creation forms</li>
     *   <li>Validating {@code accountTypeCode} values before submission</li>
     *   <li>Displaying account type names in account lists and reports</li>
     * </ul>
     *
     * @return HTTP 200 with a list of all active {@link AccountTypeResponse} objects,
     *         ordered by {@code sortOrder}. Never returns null; returns an empty list if
     *         no account types exist (which should never happen in a properly seeded database).
     * @throws com.leonguevara.mab.mab_api.exception.ApiException HTTP 401 if no valid JWT token.
     */
    @GetMapping("/account-types")
    @Operation(summary = "List account types",
            description = """
                       Returns the full account type catalog ordered by `sortOrder`.

                       Use the `code` field as the value for `accountTypeCode` when
                       creating or updating accounts.

                       Results are filtered to active, non-deleted types only.
                       The `kind` field matches the account `kind` integer:
                       1=Asset, 2=Liability, 3=Equity, 4=Revenue,
                       5=Gain/Loss, 6=Expense.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Account type list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public ResponseEntity<List<AccountTypeResponse>> getAccountTypes() {
        return ResponseEntity.ok(accountService.getAccountTypes());
    }
}