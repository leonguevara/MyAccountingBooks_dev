// ============================================================
// CoaTemplateController.java
// Package: com.leonguevara.mab.mab_api.controller
//
// Purpose: REST controller for the COA template catalog.
//          Route: GET /coa-templates
//          No tenant scoping — templates are global/shared.
// ============================================================
// Last edited: 2026-03-29
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * REST controller for the chart-of-accounts template catalog.
 *
 * <p>Exposes the global {@code coa_template} table, which contains pre-built
 * chart-of-accounts structures that users can instantiate when creating a new
 * ledger. Templates are <strong>not</strong> tenant-scoped — they are shared
 * across all owners and require no {@code TenantContext} wrapping.</p>
 *
 * <h2>Routes</h2>
 * <ul>
 *   <li>{@code GET /coa-templates} — list all active templates</li>
 * </ul>
 *
 * <h2>Security</h2>
 * <p>All endpoints require a valid JWT bearer token. No owner-level Row-Level
 * Security applies because the underlying table is not tenant-scoped.</p>
 *
 * <h2>Design notes</h2>
 * <ul>
 *   <li>Queries are executed directly via {@link NamedParameterJdbcTemplate};
 *       no service or repository layer is needed for this read-only catalog.</li>
 *   <li>Only rows where {@code is_active = true} and {@code deleted_at IS NULL}
 *       are returned, so soft-deleted or retired templates are never exposed.</li>
 * </ul>
 *
 * @see com.leonguevara.mab.mab_api.controller.LedgerController
 */
@RestController
@RequestMapping("/coa-templates")
@Tag(name = "COA Templates",
        description = "Chart of accounts templates — global catalog for ledger creation")
@SecurityRequirement(name = "bearerAuth")
public class CoaTemplateController {

    private final NamedParameterJdbcTemplate jdbc;

    /**
     * Constructs the controller with the shared JDBC template.
     *
     * @param jdbc the {@link NamedParameterJdbcTemplate} injected by Spring
     */
    public CoaTemplateController(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Returns all active chart-of-accounts templates.
     *
     * <p>Queries {@code public.coa_template} for rows where
     * {@code is_active = true} and {@code deleted_at IS NULL},
     * ordered by {@code name ASC, version ASC}.</p>
     *
     * <p>Each element in the returned list contains the fields:
     * {@code id}, {@code code}, {@code name}, {@code description},
     * {@code country}, {@code locale}, {@code industry}, {@code version}.
     * Use {@code code} and {@code version} when instantiating a template
     * during ledger creation.</p>
     *
     * @return {@code 200 OK} with the list of active template maps,
     *         or {@code 401 Unauthorized} if the bearer token is missing or invalid
     */
    @GetMapping
    @Operation(summary = "List COA templates",
            description = """
                       Returns all active chart-of-accounts templates.
                       Use `code` and `version` when creating a ledger with a template.
                       Templates are global — not scoped to any owner.
                       """)
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Template list"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid token",
                    content = @Content)
    })
    public ResponseEntity<List<Map<String, Object>>> getTemplates() {
        String sql = """
                SELECT id, code, name, description,
                       country, locale, industry, version
                  FROM public.coa_template
                 WHERE is_active  = true
                   AND deleted_at IS NULL
                 ORDER BY name ASC, version ASC
                """;
        List<Map<String, Object>> rows = jdbc.queryForList(sql, Map.of());
        return ResponseEntity.ok(rows);
    }
}