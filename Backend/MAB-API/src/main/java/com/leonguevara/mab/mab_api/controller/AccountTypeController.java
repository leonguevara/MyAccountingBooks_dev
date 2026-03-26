// ============================================================
// AccountTypeController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for the account type catalog.
//
//          Route: GET /account-types
//
//          Separated from AccountMgmtController to avoid
//          routing conflicts — /accounts and /account-types
//          must be independent base paths.
// ============================================================
// Last edited: 2026-03-26
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.response.AccountTypeResponse;
import com.leonguevara.mab.mab_api.service.AccountService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/account-types")
@Tag(name = "Account Types", description = "Account type catalog — classification reference data")
@SecurityRequirement(name = "bearerAuth")
public class AccountTypeController {

    private final AccountService accountService;

    public AccountTypeController(AccountService accountService) {
        this.accountService = accountService;
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
    @GetMapping
    @Operation(summary = "List account types",
            description = """
                       Returns the full account type catalog ordered by `sortOrder`.

                       Use the `code` field as the value for `accountTypeCode` when
                       creating or updating accounts.

                       The `kind` field matches the account kind integer:
                       1=Asset, 2=Liability, 3=Equity, 4=Income,
                       5=CostOfSales, 6=Expense, 7=Memorandum, 8=Statistical.
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