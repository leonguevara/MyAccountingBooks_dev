// ============================================================
// CommodityController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for commodity catalog endpoints.
//
//          Routes:
//            GET /commodities              → all active commodities
//            GET /commodities?namespace=X  → filtered by namespace
//            GET /commodities/{id}         → single commodity by UUID
//
//          Authentication required (enforced globally by SecurityConfig).
//          No owner scoping — commodity is a shared global catalog.
//
//          Primary use case:
//            Client fetches GET /commodities?namespace=CURRENCY
//            to populate a currency picker before creating a ledger
//            or posting a transaction.
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import com.leonguevara.mab.mab_api.dto.response.CommodityResponse;
import com.leonguevara.mab.mab_api.service.CommodityService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/commodities")
@Tag(name = "Commodities", description = "Currency and commodity catalog — ISO-4217 and custom entries")
@SecurityRequirement(name = "bearerAuth")
public class CommodityController {

    private final CommodityService commodityService;

    public CommodityController(CommodityService commodityService) {
        this.commodityService = commodityService;
    }

    @GetMapping
    @Operation(summary = "List commodities",
            description = """
                       Returns all active commodities.
                       Use the optional `namespace` parameter to filter by category.
                       
                       **Primary use case:** fetch `GET /commodities?namespace=CURRENCY`
                       to populate a currency picker. The `id` from each result is used
                       as `currencyCommodityId` when creating a ledger or posting a transaction.
                       
                       The `fraction` field equals the correct `valueDenom` to use in splits
                       for that currency. Example: MXN `fraction=100` → use `valueDenom: 100`.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "List of active commodities"),
            @ApiResponse(responseCode = "400", description = "Invalid namespace value", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content)
    })
    public List<CommodityResponse> getCommodities(
            @Parameter(description = "Optional namespace filter. Valid values: CURRENCY, STOCK, FUND, INDEX, OTHER")
            @RequestParam(required = false) String namespace) {
        return commodityService.getCommodities(namespace);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get commodity by ID",
            description = "Returns a single active commodity by its UUID primary key.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Commodity found"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token", content = @Content),
            @ApiResponse(responseCode = "404", description = "Commodity not found or inactive", content = @Content)
    })
    public CommodityResponse getCommodityById(
            @Parameter(description = "UUID of the commodity")
            @PathVariable UUID id) {
        return commodityService.getCommodityById(id);
    }
}
