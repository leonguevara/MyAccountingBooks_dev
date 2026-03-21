// ============================================================
// AccountBalanceRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Computes account balances for all accounts in a ledger.
//
//          Balance formula (rational arithmetic):
//            SUM(CASE WHEN side=0 THEN value_num ELSE -value_num END)
//          per account, using value_num/value_denom from split.
//
//          Voided transactions are excluded.
//          Deleted splits are excluded.
//          Only accounts in the given ledger are included.
//          RLS is enforced via TenantContext.
// ============================================================
// Last edited: 2026-03-21
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.response.AccountBalanceResponse;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.List;
import java.util.UUID;

@Repository
public class AccountBalanceRepository {

    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public AccountBalanceRepository(NamedParameterJdbcTemplate jdbc,
                                    TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    // ── RowMapper ────────────────────────────────────────────────────────────

    private static final RowMapper<AccountBalanceResponse> BALANCE_MAPPER =
            (rs, _) -> new AccountBalanceResponse(
                    rs.getObject("account_id",  UUID.class),
                    rs.getLong("balance_num"),
                    rs.getInt("balance_denom")
            );

    // ── Query ─────────────────────────────────────────────────────────────────

    /**
     * Returns the signed balance for every account in the ledger.
     * Accounts with no splits are included with balanceNum = 0.
     *
     * @param ownerID  The authenticated owner UUID (for RLS).
     * @param ledgerId The ledger to compute balances for.
     * @return         Flat list of AccountBalanceResponse, one per account.
     */
    public List<AccountBalanceResponse> findByLedger(UUID ownerID, UUID ledgerId) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // Computes signed balance per account using rational arithmetic.
            // LEFT JOIN ensures accounts with no transactions appear with 0.
            // Voided transactions are excluded via t.is_voided = false.
            // value_denom: use the ledger's decimal_places to derive a
            // consistent denominator across all accounts.
            String sql = """
                    SELECT
                        a.id                                             AS account_id,
                        COALESCE(
                            SUM(
                                CASE WHEN s.side = 0
                                     THEN  s.value_num
                                     ELSE -s.value_num
                                END
                            ), 0
                        )                                                AS balance_num,
                        COALESCE(MAX(s.value_denom), l.decimal_places_denom) AS balance_denom
                    FROM public.account a
                    JOIN (
                        SELECT id,
                               CAST(POWER(10, decimal_places) AS integer) AS decimal_places_denom
                          FROM public.ledger
                         WHERE id = :ledgerId
                    ) l ON a.ledger_id = l.id
                    LEFT JOIN public.split s
                           ON s.account_id     = a.id
                          AND s.deleted_at     IS NULL
                    LEFT JOIN public.transaction t
                           ON t.id             = s.transaction_id
                          AND t.deleted_at     IS NULL
                          AND t.is_voided      = false
                    WHERE a.ledger_id  = :ledgerId
                      AND a.deleted_at IS NULL
                    GROUP BY a.id, l.decimal_places_denom
                    ORDER BY a.code ASC
                    """;

            return template.query(
                    sql,
                    new MapSqlParameterSource("ledgerId", ledgerId),
                    BALANCE_MAPPER
            );
        });
    }
}
