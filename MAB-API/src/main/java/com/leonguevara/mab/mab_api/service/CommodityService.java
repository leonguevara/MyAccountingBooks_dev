// ============================================================
// CommodityService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic layer for commodity catalog operations.
//
//          Intentionally thin — commodity queries have no
//          business logic beyond routing to the repository.
//          ownerID is not needed (no RLS scoping).
//
//          The namespace parameter is validated here to prevent
//          passing arbitrary strings directly to SQL, even though
//          it is used as a named parameter (not interpolated).
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.CommodityResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.CommodityRepository;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class CommodityService {

    // Known valid namespace values. Extend if new namespaces are added.
    private static final List<String> VALID_NAMESPACES =
            List.of("CURRENCY", "STOCK", "FUND", "INDEX", "OTHER");

    // Data access layer for commodity queries.
    private final CommodityRepository commodityRepository;

    /**
     * Constructor injection of CommodityRepository.
     *
     * @param commodityRepository The repository bean for commodity data access.
     */
    public CommodityService(CommodityRepository commodityRepository) {
        this.commodityRepository = commodityRepository;
    }

    /**
     * Returns all active commodities, optionally filtered by namespace.
     *
     * @param  namespace Optional filter. Must be one of the known valid
     *                   namespaces if provided. Null returns all namespaces.
     * @return           List of CommodityResponse objects.
     * @throws ApiException HTTP 400 if an invalid namespace value is supplied.
     */
    public List<CommodityResponse> getCommodities(String namespace) {

        // Validate namespace value if provided — prevents junk query params.
        if (namespace != null && !VALID_NAMESPACES.contains(namespace.toUpperCase())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Invalid namespace '" + namespace + "'. Valid values: "
                            + String.join(", ", VALID_NAMESPACES));
        }

        // Normalize to uppercase — the DB stores namespaces in uppercase.
        String normalizedNamespace = namespace != null
                ? namespace.toUpperCase()
                : null;

        return commodityRepository.findAll(normalizedNamespace);
    }

    /**
     * Returns a single commodity by UUID.
     *
     * @param  id The UUID of the commodity to retrieve.
     * @return    The CommodityResponse.
     * @throws ApiException HTTP 404 if not found or inactive.
     */
    public CommodityResponse getCommodityById(UUID id) {
        return commodityRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "Commodity not found: " + id));
    }
}
