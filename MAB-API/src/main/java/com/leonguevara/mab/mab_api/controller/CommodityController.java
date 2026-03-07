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
import com.leonguevara.mab.mab_api.exception.ApiException;

import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/commodities")
public class CommodityController {

    // Service layer for commodity catalog logic.
    private final CommodityService commodityService;

    /**
     * Constructor injection of CommodityService.
     *
     * @param commodityService The commodity catalog service bean.
     */
    public CommodityController(CommodityService commodityService) {
        this.commodityService = commodityService;
    }

    /**
     * GET /commodities
     * GET /commodities?namespace=CURRENCY
     * <p>
     * Returns all active commodities. The optional namespace query parameter
     * narrows results to a single catalog (e.g., CURRENCY, STOCK, FUND).
     * <p>
     * Primary use: the client fetches the currency list before creating a ledger
     * or posting a transaction. The id field from each result is used
     * as currencyCommodityId in those requests.
     *
     * @param  namespace Optional query parameter. Case-insensitive.
     *                   Valid values: CURRENCY, STOCK, FUND, INDEX, OTHER.
     *                   Omit this parameter to return all active commodities.
     * @return           HTTP 200 with a JSON array of CommodityResponse objects.
     * @throws ApiException HTTP 400 if an invalid namespace value is supplied.
     */
    @GetMapping
    public List<CommodityResponse> getCommodities(
            @RequestParam(required = false) String namespace) {

        return commodityService.getCommodities(namespace);
    }

    /**
     * GET /commodities/{id}
     * <p>
     * Returns a single active commodity by its UUID.
     * <p>
     * Useful for clients that have stored a commodity UUID and need
     * to resolve its mnemonic, full name, and fraction for display.
     *
     * @param  id The UUID of the commodity (from the URL path).
     * @return    HTTP 200 with a single CommodityResponse.
     * @throws ApiException HTTP 404 if the commodity doesn't exist or is inactive.
     */
    @GetMapping("/{id}")
    public CommodityResponse getCommodityById(@PathVariable UUID id) {

        return commodityService.getCommodityById(id);
    }
}
