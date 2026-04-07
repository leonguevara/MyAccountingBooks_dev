// ============================================================
// AccountBalanceRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Computes two signed rational balances per account:
//
//   BASE (value_num/value_denom)   — ledger's base currency (MXN)
//   NATIVE (quantity_num/quantity_denom) — account's own commodity (USD)
//
// GnuCash model: each leaf account shows its own-currency balance
// ("USD $ 600.00") alongside a converted base-currency figure
// ("MXN $ 10,734.00"). Parent placeholders always roll up in
// base currency (handled client-side in AccountTreeViewModel).
// ============================================================
// Last edited: 2026-04-06
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
 * Computes signed base-currency and native-currency balances for every
 * non-deleted account in a ledger.
 *
 * <p>For same-currency accounts {@code quantity_num == value_num}, so both
 * balances are identical. The client uses {@code AccountResponse.commodityId}
 * to decide which column to show — it does not compare the two values here.
 *
 * <p>Invariants:
 * <ul>
 *   <li>Voided transactions excluded.</li>
 *   <li>Soft-deleted rows excluded.</li>
 *   <li>Accounts with no splits: both numerators are 0.</li>
 *   <li>RLS activated via {@link TenantContext#withOwner}.</li>
 * </ul>
 *
 * @see TenantContext
 * @see AccountBalanceResponse
 */
@Repository
public class AccountBalanceRepository {

    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate        tx;

    public AccountBalanceRepository(NamedParameterJdbcTemplate jdbc,
                                    TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    private static final RowMapper<AccountBalanceResponse> BALANCE_MAPPER =
            (rs, _) -> new AccountBalanceResponse(
                    rs.getObject("account_id",          UUID.class),
                    rs.getLong("balance_num"),
                    rs.getInt("balance_denom"),
                    rs.getLong("native_balance_num"),
                    rs.getInt("native_balance_denom")
            );

    /**
     * Returns base-currency and native-currency balances for every account
     * in the ledger, ordered by account code.
     *
     * @param ownerID  authenticated owner UUID for RLS.
     * @param ledgerId the ledger whose balances are requested.
     * @return flat list of {@link AccountBalanceResponse}.
     */
    public List<AccountBalanceResponse> findByLedger(UUID ownerID, UUID ledgerId) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            String sql = """
                    SELECT
                        a.id                                             AS account_id,

                        -- Base currency: always in ledger's currency (MXN).
                        -- Used for tree roll-ups and parent balance display.
                        COALESCE(
                            SUM(CASE WHEN s.side = 0
                                     THEN  s.value_num
                                     ELSE -s.value_num END),
                            0
                        )                                                AS balance_num,
                        COALESCE(MAX(s.value_denom), l.denom_fallback)   AS balance_denom,

                        -- Native currency: in account's own commodity (USD for USD accts).
                        -- Used for tree native column and register view.
                        -- Equals base balance for same-currency accounts.
                        COALESCE(
                            SUM(CASE WHEN s.side = 0
                                     THEN  s.quantity_num
                                     ELSE -s.quantity_num END),
                            0
                        )                                                AS native_balance_num,
                        COALESCE(MAX(s.quantity_denom), l.denom_fallback) AS native_balance_denom

                    FROM public.account a

                    JOIN (
                        SELECT id,
                               CAST(POWER(10, decimal_places) AS integer) AS denom_fallback
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

                    GROUP BY a.id, l.denom_fallback
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
