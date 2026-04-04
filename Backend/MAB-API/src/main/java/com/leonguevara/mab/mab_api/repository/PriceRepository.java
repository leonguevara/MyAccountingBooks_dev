// ============================================================
// PriceRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for the price table.
//
//          All queries run inside TenantContext.withOwner() so
//          RLS is active — each owner only sees prices that
//          belong to their own ledgers.
//
//          Three operations:
//            findByLedger() — list prices for a ledger
//            create()       — insert a new price entry
//            softDelete()   — set deleted_at = now()
// ============================================================
// Last edited: 2026-04-03
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.request.CreatePriceRequest;
import com.leonguevara.mab.mab_api.dto.response.PriceResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.support.TransactionTemplate;

import java.sql.Timestamp;
import java.util.List;
import java.util.UUID;

@Repository
public class PriceRepository {

    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate        tx;

    public PriceRepository(NamedParameterJdbcTemplate jdbc,
                           TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx   = tx;
    }

    // ── RowMapper ────────────────────────────────────────────────────────────

    private static final RowMapper<PriceResponse> PRICE_MAPPER = (rs, _) ->
            new PriceResponse(
                    rs.getObject("id",           UUID.class),
                    rs.getObject("ledger_id",    UUID.class),
                    rs.getObject("commodity_id", UUID.class),
                    rs.getObject("currency_id",  UUID.class),
                    rs.getTimestamp("date")
                            .toInstant()
                            .atOffset(java.time.ZoneOffset.UTC),
                    rs.getLong("value_num"),
                    rs.getInt("value_denom"),
                    rs.getString("source"),
                    rs.getString("type")
            );

    // ── Find by ledger ────────────────────────────────────────────────────────

    /**
     * Returns all active price entries for the given ledger,
     * ordered by date descending (most recent first).
     * <p>
     * RLS filters to prices belonging to the authenticated owner's ledgers.
     *
     * @param ownerID  The authenticated owner UUID.
     * @param ledgerID The ledger to fetch prices for.
     * @return         List of PriceResponse, most recent first.
     */
    public List<PriceResponse> findByLedger(UUID ownerID, UUID ledgerID) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {
            String sql = """
                    SELECT id, ledger_id, commodity_id, currency_id,
                           date, value_num, value_denom, source, type
                      FROM public.price
                     WHERE ledger_id  = :ledgerID
                       AND deleted_at IS NULL
                     ORDER BY date DESC
                    """;
            return template.query(sql,
                    new MapSqlParameterSource("ledgerID", ledgerID),
                    PRICE_MAPPER);
        });
    }

    // ── Create ────────────────────────────────────────────────────────────────

    /**
     * Inserts a new price entry for the given ledger.
     * <p>
     * The unique constraint (ledger_id, commodity_id, currency_id, date)
     * prevents duplicate entries for the same moment in time.
     *
     * @param ownerID  The authenticated owner UUID.
     * @param ledgerID The ledger this price belongs to.
     * @param request  The validated CreatePriceRequest from the controller.
     * @return         The newly created PriceResponse.
     */
    @SuppressWarnings("null")
    public PriceResponse create(UUID ownerID,
                                UUID ledgerID,
                                CreatePriceRequest request) {
        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {
            String sql = """
                    INSERT INTO public.price
                           (ledger_id, commodity_id, currency_id,
                            date, value_num, value_denom, source, type)
                    VALUES (:ledgerID, :commodityId, :currencyId,
                            :date, :valueNum, :valueDenom, :source, :type)
                    RETURNING id, ledger_id, commodity_id, currency_id,
                              date, value_num, value_denom, source, type
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("ledgerID",    ledgerID)
                    .addValue("commodityId", request.commodityId())
                    .addValue("currencyId",  request.currencyId())
                    .addValue("date",
                            request.date() != null
                                    ? Timestamp.from(request.date().toInstant())
                                    : new Timestamp(System.currentTimeMillis()))
                    .addValue("valueNum",    request.valueNum())
                    .addValue("valueDenom",  request.valueDenom())
                    .addValue("source",      request.source())
                    .addValue("type",        request.type());

            PriceResponse result = template.queryForObject(sql, params, PRICE_MAPPER);
            if (result == null) {
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                        "Price creation failed: no row returned.");
            }
            return result;
        });
    }

    // ── Soft delete ───────────────────────────────────────────────────────────

    /**
     * Soft-deletes a price entry by setting deleted_at = now().
     * <p>
     * RLS ensures the price must belong to the authenticated owner's
     * ledger — a foreign price UUID silently affects 0 rows, which
     * is treated as a 404.
     *
     * @param ownerID The authenticated owner UUID.
     * @param priceID The UUID of the price entry to delete.
     * @throws ApiException HTTP 404 if not found or not owned.
     */
    public void softDelete(UUID ownerID, UUID priceID) {
        TenantContext.withOwner(ownerID, jdbc, tx, template -> {
            String sql = """
                    UPDATE public.price
                       SET deleted_at = now(),
                           updated_at = now(),
                           revision   = revision + 1
                     WHERE id         = :priceID
                       AND deleted_at IS NULL
                    """;
            int rows = template.update(sql,
                    new MapSqlParameterSource("priceID", priceID));
            if (rows == 0) {
                throw new ApiException(HttpStatus.NOT_FOUND,
                        "Price not found: " + priceID);
            }
            return null;
        });
    }
}
