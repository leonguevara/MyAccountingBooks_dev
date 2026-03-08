// ============================================================
// CommodityRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for commodity catalog queries.
//
//          Key design decisions:
//
//          1. No TenantContext: commodity is a global catalog,
//             not owner-scoped. No RLS policy on this table.
//             Direct NamedParameterJdbcTemplate queries suffice.
//
//          2. namespace filter: clients typically only want
//             CURRENCY commodities for ledger/transaction use.
//             The optional namespace parameter narrows results.
//             Passing null returns all namespaces.
//
//          3. isActive filter: inactive commodities (deactivated
//             ISO-4217 codes or retired securities) are excluded
//             by default. The active-only filter is always applied.
//
//          4. Ordered by mnemonic: predictable sort for UI dropdowns.
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.dto.response.CommodityResponse;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class CommodityRepository {

    // JDBC template for named-parameter SQL execution.
    private final NamedParameterJdbcTemplate jdbc;

    /**
     * Constructor injection of JDBC template.
     *
     * @param jdbc JDBC template bean (from DataSourceConfig).
     */
    public CommodityRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── RowMapper ────────────────────────────────────────────────────────────
    // Maps one result row to a CommodityResponse record.
    // It seems that parameter rowNums is never used, so I'm replacing it with the
    // underscore character.
    private static final RowMapper<CommodityResponse> COMMODITY_MAPPER = (rs, _) ->
            new CommodityResponse(
                    rs.getObject("id",        UUID.class),
                    rs.getString("mnemonic"),
                    rs.getString("namespace"),
                    rs.getString("full_name"),
                    rs.getLong("fraction"),
                    rs.getBoolean("is_active")
            );

    /**
     * Returns all active commodities, optionally filtered by namespace.
     * <p>
     * Query design:
     *   - WHERE is_active = true: excludes deactivated/retired entries.
     *   - WHERE deleted_at IS NULL: excludes soft-deleted entries.
     *   - AND namespace = :namespace (only when namespace is provided):
     *     narrows to a specific catalog (e.g. "CURRENCY").
     *   - ORDER BY mnemonic ASC: predictable order for UI dropdowns.
     *
     * @param  namespace Optional namespace filter (e.g. "CURRENCY").
     *                   Pass null to return all active namespaces.
     * @return           List of CommodityResponse objects.
     *                   Empty list if no active commodities exist.
     */
    @SuppressWarnings("null")
    public List<CommodityResponse> findAll(String namespace) {

        // Dynamic WHERE clause: namespace condition added only when provided.
        // Using String.format here would risk SQL injection — using named
        // parameters with a conditional clause instead.
        String sql = """
                SELECT id, mnemonic, namespace, full_name, fraction, is_active
                  FROM public.commodity
                 WHERE is_active  = true
                   AND deleted_at IS NULL
                """ +
                // Append namespace filter only when a value is supplied.
                (namespace != null ? "   AND namespace = :namespace\n" : "") +
                " ORDER BY mnemonic ASC";

        MapSqlParameterSource params = new MapSqlParameterSource();
        if (namespace != null) {
            params.addValue("namespace", namespace);
        }

        return jdbc.query(sql, params, COMMODITY_MAPPER);
    }

    /**
     * Returns a single commodity by its UUID primary key.
     * <p>
     * Used when the client needs to verify a specific commodity before
     * using its UUID in a transaction or ledger creation request.
     * <p>
     * Returns Optional.empty() if the commodity doesn't exist,
     * is inactive, or has been soft-deleted.
     *
     * @param  id The UUID of the commodity to fetch.
     * @return    Optional containing the CommodityResponse, or empty.
     */
    public Optional<CommodityResponse> findById(UUID id) {

        String sql = """
                SELECT id, mnemonic, namespace, full_name, fraction, is_active
                  FROM public.commodity
                 WHERE id         = :id
                   AND is_active  = true
                   AND deleted_at IS NULL
                """;

        MapSqlParameterSource params = new MapSqlParameterSource("id", id);

        // query() returns a List — safe alternative to queryForObject()
        // that avoids EmptyResultDataAccessException on not-found.
        @SuppressWarnings("null")
        List<CommodityResponse> results = jdbc.query(sql, params, COMMODITY_MAPPER);

        return results.isEmpty() ? Optional.empty() : Optional.of(results.getFirst());
    }
}
