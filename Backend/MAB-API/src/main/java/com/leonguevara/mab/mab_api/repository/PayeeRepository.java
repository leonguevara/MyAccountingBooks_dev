// ============================================================
// PayeeRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access for the payee table.
//          All queries run inside TenantContext so RLS is active.
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.response.PayeeResponse;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.List;
import java.util.UUID;

/**
 * Data-access layer for the {@code public.payee} table.
 *
 * <p>Every method wraps its SQL in {@link TenantContext#withOwner} so that
 * {@code SET LOCAL app.current_owner_id} is issued before any query, activating
 * PostgreSQL Row-Level Security and scoping results to the authenticated owner.</p>
 *
 * <p>All SQL is executed via {@link NamedParameterJdbcTemplate}; results are mapped
 * by the shared {@link #PAYEE_MAPPER} row mapper.</p>
 *
 * @see TenantContext
 * @see PayeeResponse
 */
@Repository
public class PayeeRepository {

    /** {@link NamedParameterJdbcTemplate} used for all parameterised queries. */
    private final NamedParameterJdbcTemplate jdbc;

    /** {@link TransactionTemplate} passed to {@link TenantContext#withOwner} to wrap each operation. */
    private final TransactionTemplate tx;

    /**
     * Constructs the repository with its required JDBC dependencies.
     *
     * @param jdbc Spring named-parameter JDBC template
     * @param tx   transaction template for {@link TenantContext#withOwner} wrapping
     */
    public PayeeRepository(NamedParameterJdbcTemplate jdbc, TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    /**
     * Maps a {@code payee} result-set row to a {@link PayeeResponse}.
     *
     * <p>Reads {@code id}, {@code ledger_id}, and {@code name} columns.</p>
     */
    private static final RowMapper<PayeeResponse> PAYEE_MAPPER = (rs, _) ->
            new PayeeResponse(
                    rs.getObject("id",        UUID.class),
                    rs.getObject("ledger_id", UUID.class),
                    rs.getString("name")
            );

    /**
     * Returns all active, non-deleted payees for the given ledger, ordered by name.
     *
     * <p>Filters on {@code is_active = true} and {@code deleted_at IS NULL}.
     * RLS additionally restricts rows to the authenticated owner, so only payees
     * belonging to {@code ownerID}'s ledgers are ever visible.</p>
     *
     * @param ownerID  UUID of the authenticated owner (passed to {@link TenantContext#withOwner})
     * @param ledgerID UUID of the ledger whose payees are requested
     * @return list of {@link PayeeResponse} objects ordered by {@code name ASC}; empty if none found
     */
    public List<PayeeResponse> findByLedger(UUID ownerID, UUID ledgerID) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {
            String sql = """
                    SELECT id, ledger_id, name
                      FROM public.payee
                     WHERE ledger_id  = :ledgerID
                       AND is_active  = true
                       AND deleted_at IS NULL
                     ORDER BY name ASC
                    """;
            return template.query(sql,
                    new MapSqlParameterSource("ledgerID", ledgerID),
                    PAYEE_MAPPER);
        });
    }

    /**
     * Inserts a new payee into the given ledger and returns the created record.
     *
     * <p>{@code name} is trimmed before insertion. The database unique constraint
     * {@code (ledger_id, name)} prevents duplicates; a violation surfaces as a
     * {@link org.springframework.dao.DataIntegrityViolationException} which the
     * service layer maps to HTTP 409.</p>
     *
     * @param ownerID  UUID of the authenticated owner (passed to {@link TenantContext#withOwner})
     * @param ledgerID UUID of the ledger the payee belongs to
     * @param name     display name of the payee; trimmed, must be non-blank and unique per ledger
     * @return the newly created {@link PayeeResponse} as returned by {@code RETURNING}
     * @throws org.springframework.dao.DataIntegrityViolationException if {@code (ledgerID, name)}
     *         already exists
     */
    public PayeeResponse create(UUID ownerID, UUID ledgerID, String name) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {
            String sql = """
                    INSERT INTO public.payee (ledger_id, name, is_active)
                    VALUES (:ledgerID, :name, true)
                    RETURNING id, ledger_id, name
                    """;
            return template.queryForObject(sql,
                    new MapSqlParameterSource()
                            .addValue("ledgerID", ledgerID)
                            .addValue("name",     name.trim()),
                    PAYEE_MAPPER);
        });
    }
}