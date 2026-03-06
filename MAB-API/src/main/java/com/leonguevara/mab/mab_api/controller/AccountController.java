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
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.service.AccountService;
import com.leonguevara.mab.mab_api.exception.ApiException;

// @RestController: REST controller — return values serialized as JSON.
import org.springframework.web.bind.annotation.RestController;

// @RequestMapping: base URL path for this controller.
import org.springframework.web.bind.annotation.RequestMapping;

// @GetMapping: maps HTTP GET to a handler method.
import org.springframework.web.bind.annotation.GetMapping;

// @PathVariable: extracts a value from the URL path (e.g. {ledgerId}).
import org.springframework.web.bind.annotation.PathVariable;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/ledgers")
public class AccountController {

    // Service layer handles all business logic and validation.
    private final AccountService accountService;

    /**
     * Constructor injection of AccountService.
     *
     * @param accountService The account business logic service bean.
     */
    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    /**
     * GET /ledgers/{ledgerId}/accounts
     * <p>
     * Returns the full Chart of Accounts for the specified ledger
     * as a flat list. The authenticated owner is resolved from the
     * JWT — the caller cannot request accounts for a ledger they
     * do not own.
     * <p>
     * Response is a flat JSON array — clients reconstruct the tree
     * using the parentId field on each account.
     *
     * @param  ledgerId The UUID of the ledger (from the URL path).
     * @return          HTTP 200 with a JSON array of AccountResponse objects.
     *                  Returns [] if the ledger exists but has no accounts.
     * @throws ApiException HTTP 404 if ledger not found or not owned by the caller.
     */
    @GetMapping("/{ledgerId}/accounts")
    public List<AccountResponse> getAccounts(
            @PathVariable UUID ledgerId) {

        // Delegate entirely to service — no business logic in the controller.
        return accountService.getAccountsForLedger(ledgerId);
    }
}
