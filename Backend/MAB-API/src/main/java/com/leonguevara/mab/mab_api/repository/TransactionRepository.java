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
// Last edited: 2026-04-02
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

/**
 * Data-access layer for all transaction operations.
 *
 * <p>Write operations ({@link #post}, {@link #reverse}, {@link #void_}) delegate to
 * PostgreSQL stored functions ({@code mab_post_transaction}, {@code mab_reverse_transaction},
 * {@code mab_void_transaction}) which enforce double-entry invariants. After each function
 * returns a transaction UUID, a second query reads the full header + splits back — keeping
 * DB functions focused on writing and this class focused on reading.</p>
 *
 * <p>The partial-update operation ({@link #update}) applies changes directly via dynamic
 * {@code UPDATE} statements using JSON Merge Patch semantics — no stored function is involved.</p>
 *
 * <p>Every method wraps its SQL in {@link TenantContext#withOwner} so that
 * {@code SET LOCAL app.current_owner_id} is issued before any query, activating
 * PostgreSQL Row-Level Security and scoping all results to the authenticated owner.</p>
 *
 * <p>Split lines are serialized to JSONB using Jackson {@link ObjectMapper} —
 * no string concatenation. See {@link #buildSplitsJson} for the expected field names.</p>
 *
 * @see TenantContext
 * @see TransactionResponse
 * @see PostTransactionRequest
 */
@Repository
public class TransactionRepository {

    /** {@link NamedParameterJdbcTemplate} used for all parameterised SQL execution. */
    private final NamedParameterJdbcTemplate jdbc;

    /** {@link TransactionTemplate} passed to {@link TenantContext#withOwner} to scope each operation. */
    private final TransactionTemplate tx;

    /**
     * Jackson mapper for building the splits JSONB array in {@link #buildSplitsJson}.
     * Declared as a field to avoid re-instantiation on every call.
     */
    private final ObjectMapper objectMapper;

    /**
     * Constructs the repository with its required dependencies.
     *
     * @param jdbc         named-parameter JDBC template bean
     * @param tx           transaction template bean for {@link TenantContext#withOwner} wrapping
     * @param objectMapper Jackson serializer (autoconfigured by Spring Boot)
     */
    public TransactionRepository(NamedParameterJdbcTemplate jdbc,
                                 TransactionTemplate tx,
                                 ObjectMapper objectMapper) {
        this.jdbc         = jdbc;
        this.tx           = tx;
        this.objectMapper = objectMapper;
    }

    /**
     * Maps one {@code split} result-set row to a {@link TransactionResponse.SplitResponse}.
     *
     * <p>Reads {@code id}, {@code transaction_id}, {@code account_id}, {@code side},
     * {@code value_num}, {@code value_denom}, and {@code memo} columns.</p>
     */
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
     * Posts a double-entry transaction by calling {@code mab_post_transaction()}.
     *
     * <ol>
     *   <li>Serialize the splits list to a JSONB string via {@link #buildSplitsJson}.</li>
     *   <li>Call {@code mab_post_transaction()} — returns the new transaction UUID.</li>
     *   <li>Fetch the full header + splits via {@link #fetchTransaction}.</li>
     * </ol>
     *
     * <p>All steps run inside a single {@link TenantContext#withOwner} block so
     * {@code SET LOCAL app.current_owner_id} is active for every query.</p>
     *
     * @param ownerID the authenticated owner's UUID (from JWT)
     * @param request the validated {@link PostTransactionRequest} from the controller
     * @return the fully assembled {@link TransactionResponse}
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
        });
    }

    /**
     * Reverses a transaction by calling {@code mab_reverse_transaction()}.
     *
     * <ol>
     *   <li>Verify ownership via {@link #verifyTransactionOwnership}.</li>
     *   <li>Call {@code mab_reverse_transaction()} — returns the new reversal UUID.</li>
     *   <li>Fetch and return the reversal transaction via {@link #fetchTransaction}.</li>
     * </ol>
     *
     * <p>DB guards enforced inside the function:</p>
     * <ul>
     *   <li>Transaction must exist and not be deleted.</li>
     *   <li>Transaction must not be voided.</li>
     *   <li>Transaction must not have been reversed yet ({@code reversed_by_tx_id IS NULL}).</li>
     * </ul>
     *
     * @param ownerID the authenticated owner's UUID (from JWT)
     * @param txId    UUID of the transaction to reverse (from URL path)
     * @param request optional post date, enter date, and memo for the reversal entry
     * @return {@link TransactionResponse} for the newly created reversal transaction
     * @throws ApiException HTTP 404 if the transaction does not exist or is not owned by this owner
     * @throws ApiException HTTP 400 if DB guards reject the reversal
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
     * Voids a transaction by calling {@code mab_void_transaction()}.
     *
     * <p>Voiding does <em>not</em> create a new transaction — it marks the existing one
     * in-place ({@code is_voided = true}, {@code voided_at = now()}). If a reason is
     * provided the memo is prefixed with {@code [VOID: reason]}.</p>
     *
     * <ol>
     *   <li>Verify ownership via {@link #verifyTransactionOwnership}.</li>
     *   <li>Call {@code mab_void_transaction()} — returns {@code void}.</li>
     *   <li>Fetch and return the updated transaction via {@link #fetchTransaction}.</li>
     * </ol>
     *
     * <p>DB guards enforced inside the function:</p>
     * <ul>
     *   <li>Transaction must exist and not be deleted.</li>
     *   <li>Transaction must not already be voided.</li>
     * </ul>
     *
     * @param ownerID the authenticated owner's UUID (from JWT)
     * @param txId    UUID of the transaction to void (from URL path)
     * @param request optional reason string appended to the memo
     * @return {@link TransactionResponse} reflecting the voided state ({@code isVoided = true})
     * @throws ApiException HTTP 404 if the transaction is not found or not owned by this owner
     * @throws ApiException HTTP 400 if the transaction is already voided
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
     * Fetches all non-deleted transactions for a ledger together with their splits.
     *
     * <p>Uses a two-query strategy: one query loads all transaction headers, a second
     * fetches all splits for those transactions in one round-trip ({@code ANY(:txIds)}),
     * then splits are grouped and attached in memory. Returns an empty list when the
     * ledger has no transactions.</p>
     *
     * @param ownerID  the authenticated owner's UUID (from JWT)
     * @param ledgerId UUID of the ledger whose transactions are requested
     * @return list of {@link TransactionResponse} with nested splits,
     *         ordered by {@code post_date DESC, enter_date DESC}
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
                        t.is_voided,
                        t.payee_id
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
                                List.of(),   // splits attached in step 3
                                rs.getObject("payee_id", UUID.class)
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
     * Verifies that a transaction exists and belongs to the authenticated owner.
     *
     * <p>Joins {@code transaction} to {@code ledger}; RLS hides ledger rows belonging
     * to other owners, so the {@code COUNT} returns 0 for foreign transaction IDs,
     * producing HTTP 404.</p>
     *
     * @param template the JDBC template already scoped inside {@link TenantContext#withOwner}
     * @param txId     UUID of the transaction to check
     * @throws ApiException HTTP 404 if the transaction is not found or not owned by the current owner
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
     * Fetches the complete {@link TransactionResponse} for a single transaction UUID.
     *
     * <p>Shared by {@link #post}, {@link #reverse}, {@link #void_}, and {@link #update}
     * to avoid duplicating the two-query header + splits pattern.</p>
     *
     * @param template the JDBC template already scoped inside {@link TenantContext#withOwner}
     * @param txId     UUID of the transaction to fetch
     * @return the fully assembled {@link TransactionResponse} with all split lines attached
     */
    @SuppressWarnings("null")
    private TransactionResponse fetchTransaction(
            NamedParameterJdbcTemplate template, UUID txId) {

        String txSql = """
                SELECT id, ledger_id, currency_commodity_id,
                       post_date, enter_date, memo, num, is_voided, payee_id
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
                        List.of(),
                        rs.getObject("payee_id", UUID.class)
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
                splits,
                header.payeeId()
        );
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Serializes a list of {@link PostTransactionRequest.SplitRequest} objects into a
     * JSONB-compatible JSON string for passing to {@code mab_post_transaction()}.
     *
     * <p>Field names are {@code snake_case} to match the {@code jsonb_to_recordset()}
     * declaration inside the PostgreSQL function:</p>
     *
     * <pre>{@code
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
     *   }
     * ]
     * }</pre>
     *
     * @param splits the split lines from the HTTP request
     * @return a compact JSON array string suitable for casting to {@code ::jsonb}
     * @throws ApiException HTTP 500 if Jackson serialization fails (should not occur in practice)
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
     * Applies a partial update to a transaction header and/or its split lines
     * using JSON Merge Patch semantics (RFC 7396) — only non-{@code null} fields
     * in the request are written; all others are left unchanged.
     *
     * <ol>
     *   <li>Verify ownership via {@link #verifyTransactionOwnership}.</li>
     *   <li>Dynamically build and execute a header {@code UPDATE} for any of
     *       {@code memo}, {@code num}, {@code postDate}, {@code payeeId} that are non-{@code null}.</li>
     *   <li>For each entry in {@code request.splits()}, build and execute a split
     *       {@code UPDATE} for {@code memo} and/or {@code accountId} if non-{@code null}.</li>
     *   <li>Fetch and return the complete updated transaction via {@link #fetchTransaction}.</li>
     * </ol>
     *
     * <p>All steps execute within a single {@link TenantContext#withOwner} block —
     * either all changes succeed or none are applied.</p>
     *
     * <p><strong>Constraints:</strong></p>
     * <ul>
     *   <li>Transaction must not be voided ({@code is_voided = false}) or deleted.</li>
     *   <li>Split {@code accountId} changes must reference valid, active, non-placeholder
     *       accounts within the same ledger (enforced by FK + CHECK constraints).</li>
     *   <li>Amounts cannot be modified — use the reverse + repost workflow instead.</li>
     *   <li>Each modified row has its {@code revision} incremented and {@code updated_at} refreshed.</li>
     * </ul>
     *
     * @param ownerID the authenticated owner's UUID (from JWT)
     * @param txId    UUID of the transaction to update (from URL path)
     * @param request partial update payload — {@code null} fields are skipped
     * @return the fully updated {@link TransactionResponse} reflecting all changes
     * @throws ApiException HTTP 404 if the transaction is not found or not owned by this owner
     * @throws ApiException HTTP 400 if DB constraints reject the update
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
            if (request.payeeId() != null) {
                setClauses.add("payee_id = :payeeId");
                headerParams.addValue("payeeId", request.payeeId());
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
