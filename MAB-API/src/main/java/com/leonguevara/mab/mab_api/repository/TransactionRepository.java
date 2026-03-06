// ============================================================
// TransactionRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for transaction operations.
//
//          Core design:
//
//          1. mab_post_transaction() does ALL the work.
//             This repository's job is purely:
//               a) Build the splits JSONB string
//               b) Call the function with named parameters
//               c) Fetch the created transaction + splits back
//
//          2. Splits are serialized to JSONB using Jackson
//             ObjectMapper — clean, testable, no string concat.
//
//          3. After the function returns a transaction UUID,
//             we do a second query to fetch the full transaction
//             + splits for the response. This keeps the DB
//             function focused on writing, and the repository
//             focused on reading back what was written.
//
//          4. TenantContext scopes all queries via RLS.
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.repository;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.leonguevara.mab.mab_api.config.TenantContext;
import com.leonguevara.mab.mab_api.dto.request.PostTransactionRequest;
import com.leonguevara.mab.mab_api.dto.response.TransactionResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.support.TransactionTemplate;

// Timestamp: used to convert OffsetDateTime to java.sql.Timestamp
//   for passing to PostgreSQL timestamptz parameters.
import java.sql.Timestamp;
import java.util.List;
import java.util.UUID;

@Repository
public class TransactionRepository {

    // JDBC template for named-parameter SQL execution.
    private final NamedParameterJdbcTemplate jdbc;

    // Transaction template for TenantContext scoping.
    private final TransactionTemplate tx;

    // Jackson ObjectMapper for building the splits JSONB array.
    // Declared as a field to avoid re-instantiation on every call.
    private final ObjectMapper objectMapper;

    /**
     * Constructor injection of all dependencies.
     *
     * @param jdbc         JDBC template bean (from DataSourceConfig).
     * @param tx           Transaction template bean (from DataSourceConfig).
     * @param objectMapper Jackson JSON serializer (autoconfigured by Spring Boot).
     */
    public TransactionRepository(NamedParameterJdbcTemplate jdbc,
                                 TransactionTemplate tx,
                                 ObjectMapper objectMapper) {
        this.jdbc         = jdbc;
        this.tx           = tx;
        this.objectMapper = objectMapper;
    }

    // ── RowMapper for split lines ─────────────────────────────────────────────
    // Maps one row from the split table to a SplitResponse record.
    // It seems that parameter rowNum is never used, so I'm replacing it with the
    // underscore character.
    private static final RowMapper<TransactionResponse.SplitResponse> SPLIT_MAPPER =
            (rs, _) -> new TransactionResponse.SplitResponse(
                    rs.getObject("id",         UUID.class),
                    rs.getObject("account_id", UUID.class),
                    rs.getInt("side"),
                    rs.getLong("value_num"),
                    rs.getInt("value_denom"),
                    rs.getString("memo")
            );

    /**
     * Posts a double-entry transaction by calling mab_post_transaction().
     * <p>
     * Flow:
     *   1. Serialize the splits list to a JSONB string using Jackson.
     *   2. Call mab_post_transaction() — returns the new transaction UUID.
     *   3. Fetch the transaction header row using the returned UUID.
     *   4. Fetch all split rows for the transaction.
     *   5. Assemble and return a TransactionResponse.
     * <p>
     * All steps run inside a single TenantContext transaction block,
     * so SET LOCAL app.current_owner_id is active for all queries.
     *
     * @param  ownerID  The authenticated owner's UUID (from JWT).
     * @param  request  The validated PostTransactionRequest from the controller.
     * @return          The fully assembled TransactionResponse.
     * @throws ApiException HTTP 400 if the DB function rejects the transaction
     *                      (unbalanced splits, wrong ledger, placeholder account, etc.)
     */
    @SuppressWarnings("null")
public TransactionResponse post(UUID ownerID,
                                    PostTransactionRequest request) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // ── Step 1: Build the splits JSONB array ─────────────────────────
            // Jackson builds a proper JSON array from the splits list.
            // Each element matches the jsonb_to_recordset() field names
            // expected by mab_post_transaction().
            String splitsJson = buildSplitsJson(request.splits());

            // ── Step 2: Call mab_post_transaction() ──────────────────────────
            // The function returns a single UUID — the created transaction id.
            // We cast ":splitsJson" to jsonb inline in the SQL.
            String callSql = """
                    SELECT public.mab_post_transaction(
                        :ledgerId,
                        :splitsJson::jsonb,
                        :postDate,
                        :enterDate,
                        :memo,
                        :num,
                        :status,
                        :currencyCommodityId,
                        :payeeId
                    )
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("ledgerId",            request.ledgerId())
                    .addValue("splitsJson",           splitsJson)
                    // Convert OffsetDateTime to Timestamp for PostgreSQL timestamptz.
                    // null is acceptable — the DB function defaults to now().
                    .addValue("postDate",   request.postDate()  != null
                            ? Timestamp.from(request.postDate().toInstant())  : null)
                    .addValue("enterDate",  request.enterDate() != null
                            ? Timestamp.from(request.enterDate().toInstant()) : null)
                    .addValue("memo",                request.memo())
                    .addValue("num",                 request.num())
                    .addValue("status",              (short) request.status())
                    .addValue("currencyCommodityId", request.currencyCommodityId())
                    // payeeId is nullable — null is valid and means "no payee".
                    .addValue("payeeId",             request.payeeId());

            // Execute the stored function — returns the new transaction UUID.
            UUID txId = template.queryForObject(callSql, params, UUID.class);

            if (txId == null) {
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                        "Transaction function returned no ID");
            }

            // ── Step 3: Fetch the transaction header ─────────────────────────
            String txSql = """
                    SELECT id, ledger_id, currency_commodity_id,
                           post_date, enter_date, memo, num, is_voided
                      FROM public.transaction
                     WHERE id = :txId
                    """;

            MapSqlParameterSource txParams =
                    new MapSqlParameterSource("txId", txId);

            // queryForObject: safe here — we just created this exact row.
            // It seems that patameer rn is never used, so I'm replacing it with the
            // underscore character.
            TransactionResponse header = template.queryForObject(txSql, txParams,
                    (rs, _) -> new TransactionResponse(
                            rs.getObject("id",                   UUID.class),
                            rs.getObject("ledger_id",            UUID.class),
                            rs.getObject("currency_commodity_id",UUID.class),
                            // getTimestamp().toInstant() converts to OffsetDateTime.
                            rs.getTimestamp("post_date")
                                    .toInstant()
                                    .atOffset(java.time.ZoneOffset.UTC),
                            rs.getTimestamp("enter_date")
                                    .toInstant()
                                    .atOffset(java.time.ZoneOffset.UTC),
                            rs.getString("memo"),
                            rs.getString("num"),
                            rs.getBoolean("is_voided"),
                            List.of() // splits populated in step 4
                    ));

            // ── Step 4: Fetch the split lines ────────────────────────────────
            String splitSql = """
                    SELECT id, account_id, side, value_num, value_denom, memo
                      FROM public.split
                     WHERE transaction_id = :txId
                       AND deleted_at     IS NULL
                     ORDER BY side ASC, id ASC
                    """;

            List<TransactionResponse.SplitResponse> splits =
                    template.query(splitSql, txParams, SPLIT_MAPPER);

            // ── Step 5: Assemble final response ──────────────────────────────
            // Records are immutable — create a new instance with the splits.
            assert header != null;  // To avoid the NullPointerException.
            return new TransactionResponse(
                    header.id(),
                    header.ledgerId(),
                    header.currencyCommodityId(),
                    header.postDate(),
                    header.enterDate(),
                    header.memo(),
                    header.num(),
                    header.isVoided(),
                    splits
            );
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Serializes a list of SplitRequest objects into a JSONB-compatible
     * JSON string for passing to mab_post_transaction().
     * <p>
     * Output format matches the jsonb_to_recordset() field names
     * exactly as expected by the PostgreSQL function:
     * [
     *   {
     *     "account_id":     "uuid-string",
     *     "side":           0,
     *     "value_num":      50000,
     *     "value_denom":    100,
     *     "quantity_num":   0,
     *     "quantity_denom": 100,
     *     "memo":           "optional",
     *     "action":         null
     *   },
     *   ...
     * ]
     * <p>
     * Note: field names are snake_case to match the PostgreSQL
     * jsonb_to_recordset() field declaration in the function.
     *
     * @param  splits The list of SplitRequest records from the HTTP request.
     * @return        A JSON array string suitable for casting to ::jsonb.
     * @throws ApiException HTTP 500 if JSON serialization fails (should never happen).
     */
    private String buildSplitsJson(
            List<PostTransactionRequest.SplitRequest> splits) {

        try {
            // ArrayNode: Jackson's mutable JSON array builder.
            ArrayNode array = objectMapper.createArrayNode();

            for (PostTransactionRequest.SplitRequest split : splits) {
                // ObjectNode: one JSON object per split line.
                ObjectNode node = objectMapper.createObjectNode();

                // account_id: UUID as string — PostgreSQL casts text to uuid.
                node.put("account_id",     split.accountId().toString());
                // side: 0=DEBIT, 1=CREDIT.
                node.put("side",           split.side());
                // value_num / value_denom: rational monetary amount.
                node.put("value_num",      split.valueNum());
                node.put("value_denom",    split.valueDenom());
                // quantity fields: default to 0/100 if not provided.
                node.put("quantity_num",   split.quantityNum());
                node.put("quantity_denom", split.quantityDenom());
                // memo / action: optional, may be null.
                if (split.memo() != null) {
                    node.put("memo",   split.memo());
                } else {
                    node.putNull("memo");
                }
                if (split.action() != null) {
                    node.put("action", split.action());
                } else {
                    node.putNull("action");
                }

                array.add(node);
            }

            // Serialize the ArrayNode to a compact JSON string.
            return objectMapper.writeValueAsString(array);

        } catch (Exception e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Failed to serialize splits to JSON: " + e.getMessage());
        }
    }
}
