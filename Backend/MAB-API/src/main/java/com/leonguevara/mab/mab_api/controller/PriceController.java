// ============================================================
// PriceController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for exchange-rate price entries.
//
//          Routes:
//            GET    /ledgers/{ledgerID}/prices   — list prices for ledger
//            POST   /ledgers/{ledgerID}/prices   — create a new price entry
//            DELETE /prices/{id}                 — soft-delete a price entry
//
//          All routes require JWT authentication.
//          RLS (via TenantContext) ensures owners only access
//          prices in their own ledgers.
// ============================================================
// Last edited: 2026-04-03
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.request.CreatePriceRequest;
import com.leonguevara.mab.mab_api.dto.response.PriceResponse;
import com.leonguevara.mab.mab_api.service.PriceService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@Tag(name = "Prices", description = "Exchange rate price history — list, create, and delete price entries per ledger")
@SecurityRequirement(name = "bearerAuth")
public class PriceController {

    private final PriceService priceService;

    public PriceController(PriceService priceService) {
        this.priceService = priceService;
    }

    // ── GET /ledgers/{ledgerID}/prices ────────────────────────────────────────

    @GetMapping("/ledgers/{ledgerID}/prices")
    @Operation(
            summary = "List prices",
            description = """
                    Returns all active price entries for the given ledger,
                    ordered by date descending (most recent first).
                    Each entry represents an exchange rate between two commodities
                    (e.g. USD priced in MXN) at a specific point in time.
                    """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Price list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public List<PriceResponse> getPrices(
            @PathVariable UUID ledgerID) {
        return priceService.getPricesForLedger(ledgerID);
    }

    // ── POST /ledgers/{ledgerID}/prices ───────────────────────────────────────

    @PostMapping("/ledgers/{ledgerID}/prices")
    @Operation(
            summary = "Create price",
            description = """
                    Records a new exchange rate entry for the given ledger.
                    
                    The rate is expressed as a rational number: rate = valueNum / valueDenom.
                    Example: USD/MXN = 19.50 → valueNum=1950, valueDenom=100
                    
                    Returns HTTP 409 if a price already exists for the same
                    commodity, currency, and date in this ledger.
                    Returns HTTP 400 if commodityId equals currencyId.
                    """)
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Price created",
                    content = @Content(schema = @Schema(implementation = PriceResponse.class))),
            @ApiResponse(responseCode = "400", description = "Validation error or commodityId = currencyId",
                    content = @Content),
            @ApiResponse(responseCode = "409", description = "Duplicate price for this commodity/currency/date",
                    content = @Content)
    })
    public ResponseEntity<PriceResponse> createPrice(
            @PathVariable UUID ledgerID,
            @Valid @RequestBody CreatePriceRequest request) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(priceService.createPrice(ledgerID, request));
    }

    // ── DELETE /prices/{id} ───────────────────────────────────────────────────

    @DeleteMapping("/prices/{id}")
    @Operation(
            summary = "Delete price",
            description = """
                    Soft-deletes a price entry by setting deleted_at = now().
                    The entry is excluded from all subsequent queries.
                    Returns HTTP 404 if the price does not exist or
                    does not belong to the authenticated owner's ledgers.
                    """)
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "Price deleted"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content),
            @ApiResponse(responseCode = "404", description = "Price not found or not owned",
                    content = @Content)
    })
    public ResponseEntity<Void> deletePrice(
            @PathVariable UUID id) {
        priceService.deletePrice(id);
        return ResponseEntity.noContent().build();
    }
}
