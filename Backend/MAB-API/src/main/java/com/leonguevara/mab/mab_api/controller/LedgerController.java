// ============================================================
// LedgerController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for ledger endpoints.
//          Routes: GET /ledgers
//                  POST /ledgers
//                  GET /ledgers/{ledgerId}/transactions
//                  GET /ledgers/{ledgerId}/balances
// ============================================================
// Last edited: 2026-03-21
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreateLedgerRequest;
import com.leonguevara.mab.mab_api.dto.response.LedgerResponse;
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.service.LedgerService;
import com.leonguevara.mab.mab_api.service.TransactionService;
import com.leonguevara.mab.mab_api.dto.response.AccountBalanceResponse;
import com.leonguevara.mab.mab_api.service.AccountBalanceService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * REST controller for ledger operations.
 *
 * <p>Exposes endpoints to list ledgers, create a ledger, retrieve
 * transactions, and retrieve account balances for a specific ledger
 * owned by the authenticated user.</p>
 */
@RestController
@RequestMapping("/ledgers")
@Tag(name = "Ledgers", description = "Ledger management — create and list ledgers")
@SecurityRequirement(name = "bearerAuth")
public class LedgerController {

        /** Service that handles ledger read/write operations. */
    private final LedgerService ledgerService;

    /** Service that provides transaction queries for a ledger. */
    private final TransactionService transactionService;

    /** Service that computes account balances for a ledger. */
    private final AccountBalanceService accountBalanceService;

    /**
     * Creates a LedgerController with required services.
     *
     * @param ledgerService service for ledger operations
     * @param transactionService service for transaction retrieval
     * @param accountBalanceService service for account balance computation
     */
    public LedgerController(LedgerService ledgerService,
                            TransactionService transactionService,
                            AccountBalanceService accountBalanceService) {
        this.ledgerService = ledgerService;
        this.transactionService = transactionService;
        this.accountBalanceService  = accountBalanceService;
    }

    // ── GET /ledgers ─────────────────────────────────────────────────────────

    /**
     * Returns all active ledgers for the authenticated owner.
     *
     * @return list of ledger DTOs
     */
    @GetMapping
    @Operation(summary = "List ledgers",
            description = "Returns all active ledgers owned by the authenticated user.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "List of ledgers"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public List<LedgerResponse> getLedgers() {
        return ledgerService.getAllLedgers();
    }

    // ── POST /ledgers ─────────────────────────────────────────────────────────

    /**
     * Creates a new ledger for the authenticated owner.
     *
     * <p>If template fields are provided in the request, the service may also
     * instantiate a Chart of Accounts for the new ledger.</p>
     *
     * @param request payload containing ledger creation settings
     * @return created ledger wrapped in HTTP 201 response
     */
    @PostMapping
    @Operation(summary = "Create ledger",
            description = """
                    Creates a new ledger for the authenticated owner.
                    Optionally instantiates a Chart of Accounts from a template
                    by providing `coaTemplateCode` and `coaTemplateVersion`.
                    """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Ledger created",
                    content = @Content(schema = @Schema(implementation = LedgerResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request body",
                    content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public ResponseEntity<LedgerResponse> createLedger(
            @RequestBody CreateLedgerRequest request) {
        LedgerResponse created = ledgerService.createLedger(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    // ── GET /ledgers/{ledgerId}/transactions ──────────────────────────────────

    /**
     * Returns non-deleted transactions for a ledger, ordered by post date
     * descending.
     *
     * @param ledgerId target ledger identifier
     * @return transaction list wrapped in HTTP 200 response
     */
    @GetMapping("/{ledgerId}/transactions")
    @Operation(summary = "List transactions",
            description = "Returns all non-deleted transactions for the specified ledger, " +
                          "ordered by post date descending.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Transaction list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404", description = "Ledger not found or not owned by caller",
                    content = @Content)
    })
    public ResponseEntity<List<TransactionResponse>> getTransactions(
            @Parameter(description = "UUID of the ledger whose transactions to retrieve")
            @PathVariable UUID ledgerId) {
        return ResponseEntity.ok(
            transactionService.getTransactionsForLedger(ledgerId)
        );
    }

    // ── GET /ledgers/{ledgerId}/balances ──────────────────────────────────

    /**
     * Returns account balances for all accounts in the ledger.
     *
     * <p>Balances are computed using rational arithmetic (balanceNum / balanceDenom).
     * Voided transactions are excluded. Accounts with no transactions are included
     * with balanceNum = 0.</p>
     *
     * @param ledgerId target ledger identifier
     * @return balance list wrapped in HTTP 200 response
     */
    @GetMapping("/{ledgerId}/balances")
    @Operation(summary = "Get account balances",
            description = """
                Returns the signed balance for every account in the ledger
                using rational arithmetic (balanceNum / balanceDenom).
                Voided transactions are excluded.
                Accounts with no transactions are included with balanceNum = 0.
                """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Balance list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404", description = "Ledger not found",
                    content = @Content)
    })
    public ResponseEntity<List<AccountBalanceResponse>> getBalances(
            @Parameter(description = "UUID of the ledger")
            @PathVariable UUID ledgerId) {
        return ResponseEntity.ok(accountBalanceService.getBalances(ledgerId));
    }
}
