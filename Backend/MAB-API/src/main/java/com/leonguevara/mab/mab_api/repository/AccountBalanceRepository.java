// ============================================================
// AccountBalanceRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Computes signed rational balances for every account
//          in a ledger, always expressed in the ledger's base
//          currency (value_num / value_denom).
//
//          The AccountTree always shows balances in the ledger's
//          base currency — foreign-currency accounts display their
//          MXN equivalent, not their native USD/EUR amount.
//          The AccountRegisterView handles per-account native
//          currency display separately using quantity fields.
// ============================================================
// Last edited: 2026-04-04
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
 * Data access layer for account balance computation.
 *
 * <p>Returns signed rational balances for every non-deleted account in a ledger.
 * All balances are expressed in the <b>ledger's base currency</b> using
 * {@code value_num / value_denom}. This is correct for the AccountTree, which
 * always shows amounts in the ledger's currency regardless of each account's
 * native commodity.</p>
 *
 * <p>The AccountRegisterView uses {@code quantity_num / quantity_denom} from
 * split responses to display amounts in the account's native currency.
 * That logic lives in the Swift client, not here.</p>
 *
 * <p>Balance formula:
 * <pre>
 *   balance_num   = SUM(CASE WHEN side=0 THEN value_num ELSE -value_num END)
 *   balance_denom = COALESCE(MAX(value_denom), 10^decimal_places)
 * </pre>
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
                    rs.getObject("account_id",  UUID.class),
                    rs.getLong("balance_num"),
                    rs.getInt("balance_denom")
            );

    /**
     * Returns the signed base-currency balance for every account in the ledger.
     *
     * @param ownerID  authenticated owner UUID for RLS.
     * @param ledgerId the ledger whose balances are requested.
     * @return flat list of {@link AccountBalanceResponse}, ordered by account code.
     */
    public List<AccountBalanceResponse> findByLedger(UUID ownerID, UUID ledgerId) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

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
