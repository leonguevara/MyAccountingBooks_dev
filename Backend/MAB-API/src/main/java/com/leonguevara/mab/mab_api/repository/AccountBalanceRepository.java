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
// Last edited: 2026-03-30
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

/**
 * Computes signed account balances for all accounts in a ledger using rational arithmetic.
 *
 * <p>Balance formula per account:
 * <pre>
 *   balance_num   = SUM(CASE WHEN side=0 THEN value_num ELSE -value_num END)
 *   balance_denom = COALESCE(MAX(s.value_denom), 10^ledger.decimal_places)
 * </pre>
 *
 * <p>Invariants enforced by the query:
 * <ul>
 *   <li>Voided transactions ({@code is_voided = true}) are excluded.</li>
 *   <li>Soft-deleted transactions and splits ({@code deleted_at IS NOT NULL}) are excluded.</li>
 *   <li>Accounts with no qualifying splits appear with {@code balance_num = 0}.</li>
 *   <li>The denominator falls back to {@code 10^decimal_places} when an account has no splits,
 *       guaranteeing a consistent rational base across all rows in the result.</li>
 *   <li>Row-Level Security is activated via {@link TenantContext#withOwner}.</li>
 * </ul>
 *
 * @see TenantContext
 * @see AccountBalanceResponse
 */
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
     * Returns the signed rational balance for every account in the given ledger.
     *
     * <p>Accounts with no qualifying splits are included with {@code balanceNum = 0} and
     * {@code balanceDenom = 10^ledger.decimal_places}, so callers always receive a
     * well-formed rational number regardless of transaction history.
     *
     * <p>The denominator is derived as:
     * <pre>
     *   COALESCE(MAX(s.value_denom), CAST(POWER(10, decimal_places) AS integer))
     * </pre>
     * This ensures the fallback denominator matches the ledger's precision when an account
     * has no splits, avoiding a {@code NULL} denominator in the response.
     *
     * <p>Results are ordered by {@code account.code ASC}.
     *
     * @param ownerID  The authenticated owner UUID used to set {@code app.current_owner_id}
     *                 for Row-Level Security.
     * @param ledgerId The UUID of the ledger whose account balances are requested.
     * @return         Flat list of {@link AccountBalanceResponse}, one entry per non-deleted
     *                 account in the ledger.
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
                    LEFT JOIN (
                        SELECT s.*
                          FROM public.split s
                          JOIN public.transaction t
                            ON t.id         = s.transaction_id
                           AND t.deleted_at IS NULL
                           AND t.is_voided  = false
                         WHERE s.deleted_at IS NULL
                    ) s ON s.account_id = a.id
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
