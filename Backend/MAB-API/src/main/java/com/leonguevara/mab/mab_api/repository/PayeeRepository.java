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

@Repository
public class PayeeRepository {

    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public PayeeRepository(NamedParameterJdbcTemplate jdbc, TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    private static final RowMapper<PayeeResponse> PAYEE_MAPPER = (rs, _) ->
            new PayeeResponse(
                    rs.getObject("id",        UUID.class),
                    rs.getObject("ledger_id", UUID.class),
                    rs.getString("name")
            );

    /**
     * Returns all active payees for the given ledger.
     * RLS filters to the authenticated owner automatically.
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
     * Creates a new payee and returns it.
     * The unique constraint (ledger_id, name) prevents duplicates.
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