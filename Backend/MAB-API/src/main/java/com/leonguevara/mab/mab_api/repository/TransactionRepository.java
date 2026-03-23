// ============================================================
// TransactionRepository.java
// Package: com.leonguevara.mab.mab_api.repository
//
// Purpose: Data access layer for transaction operations.
//
//          Core design:
//
//          1. mab_post_transaction(), mab_reverse_transaction(),
//             and mab_void_transaction() do the heavy lifting.
//             For posting new transactions:
//               a) Build the splits JSONB string
//               b) Call the function with named parameters
//               c) Fetch the created transaction + splits back
//
//          2. Splits are serialized to JSONB using Jackson
//             ObjectMapper — clean, testable, no string concat.
//
//          3. After stored functions return a transaction UUID,
//             we do a second query to fetch the full transaction
//             + splits for the response. This keeps DB functions
//             focused on writing, and the repository focused on
//             reading back what was written.
//
//          4. PATCH operations (update method) apply changes
//             directly via UPDATE statements — no stored function.
//             Only non-null fields are modified (JSON Merge Patch).
//
//          5. TenantContext scopes all queries via RLS.
// ============================================================
// Last edited: 2026-03-22
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
import com.leonguevara.mab.mab_api.dto.request.ReverseTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.VoidTransactionRequest;
import com.leonguevara.mab.mab_api.dto.request.PatchTransactionRequest;

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
import java.util.Map;
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
                    rs.getObject("transaction_id", UUID.class),
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

            return fetchTransaction(template, txId);

            // ── Step 3: Fetch the transaction header ─────────────────────────
            /*String txSql = """
                    SELECT id, ledger_id, currency_commodity_id,
                           post_date, enter_date, memo, num, is_voided
                      FROM public.transaction
                     WHERE id = :txId
                    """;

            MapSqlParameterSource txParams =
                    new MapSqlParameterSource("txId", txId);*/

            // queryForObject: safe here — we just created this exact row.
            // It seems that patameer rn is never used, so I'm replacing it with the
            // underscore character.
            /*TransactionResponse header = template.queryForObject(txSql, txParams,
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
                    ));*/

            // ── Step 4: Fetch the split lines ────────────────────────────────
            /*String splitSql = """
                    SELECT id, account_id, side, value_num, value_denom, memo
                      FROM public.split
                     WHERE transaction_id = :txId
                       AND deleted_at     IS NULL
                     ORDER BY side ASC, id ASC
                    """;

            List<TransactionResponse.SplitResponse> splits =
                    template.query(splitSql, txParams, SPLIT_MAPPER);*/

            // ── Step 5: Assemble final response ──────────────────────────────
            // Records are immutable — create a new instance with the splits.
            /*assert header != null;  // To avoid the NullPointerException.
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
            );*/
        });
    }

    /**
     * Reverses a transaction by calling mab_reverse_transaction().
     * <p>
     * Flow:
     *   1. Verify the target transaction belongs to this owner (via RLS check).
     *   2. Call mab_reverse_transaction() — returns the new reversal tx UUID.
     *   3. Fetch the new reversal transaction header plus splits.
     *   4. Return a full TransactionResponse for the reversal transaction.
     * <p>
     * DB guards (enforced inside the function):
     *   - Transaction must exist and not be deleted.
     *   - Transaction must not be voided.
     *   - Transaction must not have been reversed yet.
     *     (reversed_by_tx_id IS NULL).
     *
     * @param  ownerID  The authenticated owner's UUID (from JWT).
     * @param  txId     The UUID of the transaction to reverse (from URL path).
     * @param  request  Optional dates and memo for the reversal.
     * @return          TransactionResponse for the new reversal transaction.
     * @throws ApiException HTTP 404 if the transaction doesn't exist or
     *                      doesn't belong to this owner.
     * @throws ApiException HTTP 400 if DB guards reject the reversal.
     */
    public TransactionResponse reverse(UUID ownerID,
                                       UUID txId,
                                       ReverseTransactionRequest request) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // ── Step 1: Ownership check ───────────────────────────────────
            // RLS scopes the query to the current owner's ledgers.
            // If the tx belongs to another owner, COUNT returns 0 → 404.
            verifyTransactionOwnership(template, txId);

            // ── Step 2: Call mab_reverse_transaction() ────────────────────
            String callSql = """
                    SELECT public.mab_reverse_transaction(
                        :txId,
                        :postDate,
                        :enterDate,
                        :memo
                    )
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("txId",      txId)
                    .addValue("postDate",  request.postDate()  != null
                            ? Timestamp.from(request.postDate().toInstant())  : null)
                    .addValue("enterDate", request.enterDate() != null
                            ? Timestamp.from(request.enterDate().toInstant()) : null)
                    .addValue("memo",      request.memo());

            UUID reversalTxId = template.queryForObject(callSql, params, UUID.class);

            if (reversalTxId == null) {
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                        "Reverse function returned no ID");
            }

            // ── Step 3 & 4: Fetch and return the reversal transaction ─────
            return fetchTransaction(template, reversalTxId);
        });
    }

    /**
     * Voids a transaction by calling mab_void_transaction().
     * <p>
     * Voiding does NOT create a new transaction — it marks the existing
     * transaction as voided in-place (is_voided=true, voided_at=now()).
     * The memo is updated with "[VOID: reason]" if a reason is provided.
     * <p>
     * Flow:
     *   1. Verify ownership via RLS-scoped count check.
     *   2. Call mab_void_transaction() — returns void.
     *   3. Fetch the updated transaction plus splits and return them.
     * <p>
     * DB guards:
     *   - Transaction must exist.
     *   - Transaction must not already be voided.
     *
     * @param  ownerID  The authenticated owner's UUID (from JWT).
     * @param  txId     The UUID of the transaction to void (from URL path).
     * @param  request  Optional reason string.
     * @return          TransactionResponse reflecting the voided state
     *                  (isVoided will be true).
     * @throws ApiException HTTP 404 if transaction not found or not owned.
     * @throws ApiException HTTP 400 if the transaction is already voided.
     */
    public TransactionResponse void_(UUID ownerID,
                                     UUID txId,
                                     VoidTransactionRequest request) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // ── Step 1: Ownership check ───────────────────────────────────
            verifyTransactionOwnership(template, txId);

            // ── Step 2: Call mab_void_transaction() ──────────────────────
            // This function returns void — no UUID is returned.
            String callSql = """
                    SELECT public.mab_void_transaction(
                        :txId,
                        :reason
                    )
                    """;

            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("txId",   txId)
                    .addValue("reason", request.reason());

            // queryForObject with Void.class: executes the function,
            // discards the (void) return value cleanly.
            // This line fails so I'm commenting it out.
            // template.queryForObject(callSql, params, Void.class);
            template.query(callSql, params, rs -> null);

            // ── Step 3: Fetch and return the updated transaction ──────────
            // The transaction now has is_voided=true and updated memo.
            return fetchTransaction(template, txId);
        });
    }

        // ── Fetch transactions by ledger ─────────────────────────────────────────

        /**
         * Fetches all non-deleted transactions for a ledger with their splits.
         * Wrapped in TenantContext so RLS is active for all queries.
         *
         * @param ownerID  The authenticated owner UUID (from JWT via service).
         * @param ledgerId The ledger to fetch transactions for.
         * @return         List of TransactionResponse with nested splits,
         *                 ordered by post_date DESC.
         */
        public List<TransactionResponse> findByLedgerId(UUID ownerID, UUID ledgerId) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

                // ── Step 1: Fetch transaction headers ────────────────────────────
                final String txSql = """
                        SELECT
                        t.id,
                        t.ledger_id,
                        t.currency_commodity_id,
                        t.post_date,
                        t.enter_date,
                        t.memo,
                        t.num,
                        t.is_voided
                        FROM public.transaction t
                        WHERE t.ledger_id  = :ledgerId
                        AND t.deleted_at IS NULL
                        ORDER BY t.post_date DESC, t.enter_date DESC
                        """;

                List<TransactionResponse> transactions = template.query(
                        txSql,
                        new MapSqlParameterSource("ledgerId", ledgerId),
                        (rs, _) -> new TransactionResponse(
                                rs.getObject("id",                    UUID.class),
                                rs.getObject("ledger_id",             UUID.class),
                                rs.getObject("currency_commodity_id", UUID.class),
                                rs.getTimestamp("post_date")
                                        .toInstant()
                                        .atOffset(java.time.ZoneOffset.UTC),
                                rs.getTimestamp("enter_date")
                                        .toInstant()
                                        .atOffset(java.time.ZoneOffset.UTC),
                                rs.getString("memo"),
                                rs.getString("num"),
                                rs.getBoolean("is_voided"),
                                List.of()   // splits attached in step 3
                        )
                );

                if (transactions.isEmpty()) return transactions;

                // ── Step 2: Fetch all splits in one query ────────────────────────
                List<UUID> txIds = transactions.stream()
                        .map(TransactionResponse::id)
                        .toList();

                final String splitSql = """
                        SELECT
                        s.id,
                        s.transaction_id,
                        s.account_id,
                        s.side,
                        s.value_num,
                        s.value_denom,
                        s.memo
                        FROM public.split s
                        WHERE s.transaction_id = ANY(:txIds)
                        AND s.deleted_at     IS NULL
                        ORDER BY s.transaction_id, s.side
                        """;

                Map<UUID, List<TransactionResponse.SplitResponse>> splitsByTx =
                        template.query(
                                splitSql,
                                new MapSqlParameterSource("txIds", txIds.toArray(new UUID[0])),
                                SPLIT_MAPPER
                        )
                        .stream()
                        .collect(java.util.stream.Collectors.groupingBy(
                                TransactionResponse.SplitResponse::transactionId
                        ));

                // ── Step 3: Attach splits to their transactions ──────────────────
                return transactions.stream()
                        .map(t -> t.withSplits(
                                splitsByTx.getOrDefault(t.id(), List.of())
                        ))
                        .toList();
        });
        }

    // ── Shared private helpers ────────────────────────────────────────────────

    /**
     * Verifies a transaction exists and belongs to the current RLS owner.
     * <p>
     * Joins transaction → ledger, which is RLS-protected.
     * If the transaction belongs to a different owner, the JOIN
     * returns zero rows → ApiException 404.
     *
     * @param  template The JDBC template (already inside TenantContext).
     * @param  txId     The transaction UUID to check.
     * @throws ApiException HTTP 404 if not found or not owned.
     */
    private void verifyTransactionOwnership(
            NamedParameterJdbcTemplate template, UUID txId) {

        String sql = """
                SELECT COUNT(*)
                  FROM public.transaction t
                  JOIN public.ledger      l ON l.id = t.ledger_id
                 WHERE t.id         = :txId
                   AND t.deleted_at IS NULL
                """;
        // The JOIN on the ledger is RLS-filtered — rows for other owners
        // are invisible, so the count returns 0 for foreign tx IDs.
        Integer count = template.queryForObject(
                sql,
                new MapSqlParameterSource("txId", txId),
                Integer.class);

        if (count == null || count == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND,
                    "Transaction not found: " + txId);
        }
    }

    /**
     * Fetches a complete TransactionResponse for a given transaction UUID.
     * <p>
     * Reused by post(), reverse(), and void_() to avoid duplicating
     * the header plus splits fetch logic.
     *
     * @param  template The JDBC template (already inside TenantContext).
     * @param  txId     The transaction UUID to fetch.
     * @return          The fully assembled TransactionResponse.
     */
    @SuppressWarnings("null")
    private TransactionResponse fetchTransaction(
            NamedParameterJdbcTemplate template, UUID txId) {

        String txSql = """
                SELECT id, ledger_id, currency_commodity_id,
                       post_date, enter_date, memo, num, is_voided
                  FROM public.transaction
                 WHERE id = :txId
                """;

        MapSqlParameterSource txParams =
                new MapSqlParameterSource("txId", txId);

        // It seems that parameter rn is never used, so I'm replacing it with the
        // underscore character.
        TransactionResponse header = template.queryForObject(txSql, txParams,
                (rs, _) -> new TransactionResponse(
                        rs.getObject("id",                    UUID.class),
                        rs.getObject("ledger_id",             UUID.class),
                        rs.getObject("currency_commodity_id", UUID.class),
                        rs.getTimestamp("post_date")
                                .toInstant()
                                .atOffset(java.time.ZoneOffset.UTC),
                        rs.getTimestamp("enter_date")
                                .toInstant()
                                .atOffset(java.time.ZoneOffset.UTC),
                        rs.getString("memo"),
                        rs.getString("num"),
                        rs.getBoolean("is_voided"),
                        List.of()
                ));

        String splitSql = """
                SELECT id, transaction_id, account_id, side, value_num, value_denom, memo
                  FROM public.split
                 WHERE transaction_id = :txId
                   AND deleted_at     IS NULL
                 ORDER BY side ASC, id ASC
                """;

        List<TransactionResponse.SplitResponse> splits =
                template.query(splitSql, txParams, SPLIT_MAPPER);

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

    // ── PATCH transaction ────────────────────────────────────────────────────────

    /**
     * Applies a partial update to a transaction header and/or its split lines.
     * <p>
     * Implements JSON Merge Patch semantics (RFC 7396) — only non-null fields
     * are updated. All fields in the request are optional.
     * <p>
     * Flow:
     *   1. Verify ownership via RLS-scoped check.
     *   2. Update transaction header fields (memo, num, postDate) if provided.
     *   3. Update individual split fields (memo, accountId) per splitId.
     *   4. Fetch and return the complete updated transaction with all splits.
     * <p>
     * All updates execute within a single TenantContext transaction,
     * so either all changes succeed or none are applied.
     * <p>
     * <b>Important constraints:</b>
     * <ul>
     *   <li>Transaction must not be voided (is_voided=false)</li>
     *   <li>Transaction must not be deleted</li>
     *   <li>Split accountId changes must reference valid, active, non-placeholder
     *       accounts within the same ledger (enforced by foreign key + CHECK constraints)</li>
     *   <li>Cannot modify amounts — use reverse + repost workflow instead</li>
     *   <li>Increments revision and updates updated_at for each modified row</li>
     * </ul>
     *
     * @param  ownerID  The authenticated owner's UUID (from JWT).
     * @param  txId     UUID of the transaction to update (from URL path).
     * @param  request  Partial update request — null fields are skipped.
     *                  See {@link PatchTransactionRequest} for field details.
     * @return          The fully updated TransactionResponse reflecting all changes.
     * @throws ApiException HTTP 404 if transaction not found or not owned by this owner.
     * @throws ApiException HTTP 400 if DB constraints reject the update
     *                      (e.g., invalid accountId, voided transaction, etc.)
     * @see PatchTransactionRequest
     */
    public TransactionResponse update(UUID ownerID,
                                      UUID txId,
                                      PatchTransactionRequest request) {

        return TenantContext.withOwner(ownerID, jdbc, tx, template -> {

            // ── Step 1: Verify ownership ─────────────────────────────────
            verifyTransactionOwnership(template, txId);

            // ── Step 2: Patch transaction header ─────────────────────────
            // Build SET clause dynamically — only update provided fields.
            // Always increment revision and update updated_at.
            var headerParams = new MapSqlParameterSource("txId", txId);
            var setClauses   = new java.util.ArrayList<String>();

            if (request.memo() != null) {
                setClauses.add("memo = :memo");
                headerParams.addValue("memo", request.memo());
            }
            if (request.num() != null) {
                setClauses.add("num = :num");
                headerParams.addValue("num", request.num());
            }
            if (request.postDate() != null) {
                setClauses.add("post_date = :postDate");
                headerParams.addValue("postDate",
                        Timestamp.from(request.postDate().toInstant()));
            }

            if (!setClauses.isEmpty()) {
                setClauses.add("updated_at = now()");
                setClauses.add("revision = revision + 1");
                String headerSql = "UPDATE public.transaction SET "
                        + String.join(", ", setClauses)
                        + " WHERE id = :txId AND deleted_at IS NULL AND is_voided = false";
                template.update(headerSql, headerParams);
            }

            // ── Step 3: Patch split lines ─────────────────────────────────
            if (request.splits() != null) {
                for (var splitPatch : request.splits()) {
                    if (splitPatch.splitId() == null) continue;

                    var splitParams = new MapSqlParameterSource("splitId", splitPatch.splitId());
                    var splitSet    = new java.util.ArrayList<String>();

                    if (splitPatch.memo() != null) {
                        splitSet.add("memo = :memo");
                        splitParams.addValue("memo", splitPatch.memo());
                    }
                    if (splitPatch.accountId() != null) {
                        splitSet.add("account_id = :accountId");
                        splitParams.addValue("accountId", splitPatch.accountId());
                    }

                    if (!splitSet.isEmpty()) {
                        splitSet.add("updated_at = now()");
                        splitSet.add("revision = revision + 1");
                        String splitSql = "UPDATE public.split SET "
                                + String.join(", ", splitSet)
                                + " WHERE id = :splitId AND deleted_at IS NULL";
                        template.update(splitSql, splitParams);
                    }
                }
            }

            // ── Step 4: Fetch and return updated transaction ──────────────
            return fetchTransaction(template, txId);
        });
    }
}
