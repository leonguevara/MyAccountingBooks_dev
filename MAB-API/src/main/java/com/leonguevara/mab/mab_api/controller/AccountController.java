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
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.response.AccountResponse;
import com.leonguevara.mab.mab_api.service.AccountService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

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
@Tag(name = "Accounts", description = "Chart of Accounts — retrieve account tree for a ledger")
@SecurityRequirement(name = "bearerAuth")
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

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
}
