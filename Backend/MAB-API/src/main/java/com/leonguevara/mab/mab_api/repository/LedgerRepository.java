// ============================================================
// LedgerRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for ledger operations.
//
//          All methods receive an ownerID and a pre-configured
//          TenantContext to guarantee RLS is active before any
//          query runs. Direct SQL queries use the v_ledger view
//          (not the raw ledger table) so that currency_code is
//          available without an extra join in this layer.
//
//          Ledger creation delegates entirely to the PostgreSQL
//          function create_ledger_with_optional_template() —
//          no INSERT is written here. The DB function handles
//          all validation, currency resolution, and optional
//          COA template instantiation atomically.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.response.LedgerResponse;

// NamedParameterJdbcTemplate: executes named-parameter SQL queries.
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

// MapSqlParameterSource: builds a named parameter map for queries.
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

// RowMapper: maps a single ResultSet row to a Java object.
//   Declared as a constant to avoid re-creating it on every call.
import org.springframework.jdbc.core.RowMapper;

// TransactionTemplate: used by TenantContext to wrap queries in
//   BEGIN/SET LOCAL/COMMIT blocks.
import org.springframework.transaction.support.TransactionTemplate;

// @Repository: marks this as a Spring data-access bean.
//   Also enables Spring's exception translation (converts SQL
//   exceptions into Spring's DataAccessException hierarchy).
import org.springframework.stereotype.Repository;

import java.util.List;
// import java.util.Map;
import java.util.UUID;

@Repository
public class LedgerRepository {

    // JDBC template for executing SQL with named parameters.
    private final NamedParameterJdbcTemplate jdbc;

    // Transaction template used by TenantContext to scope queries.
    private final TransactionTemplate tx;

    /**
     * Constructor injection of JDBC and transaction dependencies.
     *
     * @param jdbc JDBC template bean (configured in DataSourceConfig).
     * @param tx   Transaction template bean (configured in DataSourceConfig).
     */
    public LedgerRepository(NamedParameterJdbcTemplate jdbc,
                            TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    // ── RowMapper ────────────────────────────────────────────────────────────
    // Maps a single row from v_ledger to a LedgerResponse record.
    // Declared as a constant: created once, reused on every query call.
    // This mapper used to have an int rowNumbs parameter that is not used, so I'm
    // replacing it with the underscore character.
    private static final RowMapper<LedgerResponse> LEDGER_MAPPER = (rs, _) ->
            new LedgerResponse(
                    // rs.getObject with UUID.class: correct way to read PostgreSQL UUIDs.
                    rs.getObject("id",           UUID.class),
                    rs.getString("name"),
                    // currency_code: derived from commodity.mnemonic via v_ledger view.
                    rs.getString("currency_code"),
                    rs.getInt("decimal_places")
            );

    /**
     * Returns all active, non-deleted ledgers belonging to the given owner.
     * <p>
     * Queries the v_ledger view (not the raw ledger table) so that
     * currency_code is available directly without an extra join.
     * <p>
     * RLS enforcement: TenantContext sets SET LOCAL app.current_owner_id
     * before this query runs. PostgreSQL automatically filters rows to
     * only those where ledger.owner_id matches the session variable.
     *
     * @param  ownerID The authenticated owner's UUID (from JWT).
     * @return         List of LedgerResponse objects. Empty list if none exists.
     */
    @SuppressWarnings("null")
public List<LedgerResponse> findAllByOwner(UUID ownerID) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            String sql = """
                    SELECT id, name, currency_code, decimal_places
                      FROM public.v_ledger
                     WHERE deleted_at IS NULL
                       AND is_active  = true
                     ORDER BY name ASC
                    """;

            // query(): executes the SQL and maps each row using LEDGER_MAPPER.
            // No parameters needed: RLS already filters by owner via SET LOCAL.
            return template.query(sql, LEDGER_MAPPER);
        });
    }

    /**
     * Creates a new ledger by calling the PostgreSQL stored function
     * create_ledger_with_optional_template().
     * <p>
     * The function handles:
     *   - Owner validation
     *   - Currency commodity resolution by mnemonic (e.g. "MXN", "USD")
     *   - COA template resolution by code and version (optional)
     *   - Atomic ledger INSERT plus account tree instantiation
     * <p>
     * Returns the created ledger by querying v_ledger with the
     * returned ledger_id, so currency_code is included in the response.
     *
     * @param  ownerID          The authenticated owner's UUID.
     * @param  name             Display-name for the new ledger.
     * @param  currencyMnemonic ISO 4217 currency code (e.g. "MXN", "USD").
     * @param  decimalPlaces    Number of decimal places (e.g., 2 for cents).
     * @param  templateCode     COA template code (nullable — e.g. "SAT_2025").
     * @param  templateVersion  COA template version (nullable — e.g. "2025").
     * @return                  The newly created LedgerResponse.
     */
    @SuppressWarnings("null")
public LedgerResponse create(UUID ownerID,
                                 String name,
                                 String currencyMnemonic,
                                 short  decimalPlaces,
                                 String templateCode,
                                 String templateVersion) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // Call the PostgreSQL function that creates the ledger atomically.
            // The function returns a single row with ledger_id and related UUIDs.
            String callSql = """
                    SELECT ledger_id
                      FROM public.create_ledger_with_optional_template(
                               :ownerId,
                               :ledgerName,
                               :currencyMnemonic,
                               :decimalPlaces,
                               'API',
                               :templateCode,
                               :templateVersion
                           )
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("ownerId",          ownerID)
                    .addValue("ledgerName",        name)
                    .addValue("currencyMnemonic",  currencyMnemonic)
                    .addValue("decimalPlaces",     decimalPlaces)
                    // templateCode and templateVersion may be null.
                    // PostgreSQL function handles NULL gracefully (no template).
                    .addValue("templateCode",      templateCode)
                    .addValue("templateVersion",   templateVersion);

            // queryForObject: expects exactly one row back from the function.
            UUID newLedgerID = template.queryForObject(
                    callSql, params, UUID.class);

            // Fetch the full ledger from v_ledger using the returned ID.
            // This gives us currency_code without writing an extra join here.
            String fetchSql = """
                    SELECT id, name, currency_code, decimal_places
                      FROM public.v_ledger
                     WHERE id = :ledgerId
                    """;

            return template.queryForObject(
                    fetchSql,
                    new MapSqlParameterSource("ledgerId", newLedgerID),
                    LEDGER_MAPPER);
        });
    }
}