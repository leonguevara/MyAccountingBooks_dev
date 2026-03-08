// ============================================================
// PostTransactionRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of POST /transactions.
//
//          Maps directly to the parameters of:
//            mab_post_transaction(
//              p_ledger_id,             -- required
//              p_splits,                -- required: JSON array
//              p_post_date,             -- optional, defaults to now()
//              p_enter_date,            -- optional, defaults to now()
//              p_memo,                  -- optional
//              p_num,                   -- optional (transaction number)
//              p_status,                -- optional, defaults to 0
//              p_currency_commodity_id, -- required
//              p_payee_id               -- optional
//            )
//
//          Rational arithmetic:
//            Monetary values use value_num / value_denom to avoid
//            floating-point rounding errors. Example: MXN $500.00
//            is represented as value_num=50000, value_denom=100.
//            ALL splits in one transaction MUST share the same
//            value_denom — enforced by the DB function.
//
//          Balance invariant:
//            SUM(value_num WHERE side=0) = SUM(value_num WHERE side=1)
//            Enforced by mab_post_transaction() — not by the API layer.
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// OffsetDateTime: timestamp with timezone offset — correct type for
//   PostgreSQL timestamptz columns (post_date, enter_date).
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Incoming request body for posting a double-entry transaction.
 * <p>
 * Minimum valid JSON:
 * {
 *   "ledgerId":             "uuid",
 *   "currencyCommodityId":  "uuid",
 *   "splits": [
 *     {"accountId": "uuid", "side": 0, "valueNum": 50000, "valueDenom": 100},
 *     {"accountId": "uuid", "side": 1, "valueNum": 50000, "valueDenom": 100}
 *   ]
 * }
 * <p>
 * Full JSON with optional fields:
 * {
 *   "ledgerId":             "uuid",
 *   "currencyCommodityId":  "uuid",
 *   "postDate":             "2026-03-05T12:00:00-06:00",
 *   "enterDate":            "2026-03-05T12:00:00-06:00",
 *   "memo":                 "Office supplies",
 *   "num":                  "TXN-001",
 *   "status":               0,
 *   "payeeId":              "uuid-or-null",
 *   "splits": [...]
 * }
 *
 * @param ledgerId            The ledger to post to. Required.
 * @param currencyCommodityId The commodity UUID for the transaction currency. Required.
 * @param postDate            Date the transaction is effective. Defaults to now() if null.
 * @param enterDate           Date the transaction was entered. Defaults to now() if null.
 * @param memo                Optional narrative for the whole transaction.
 * @param num                 Optional transaction reference number (e.g., invoice number).
 * @param status              Transaction status smallint. Default 0 = uncleared.
 * @param payeeId             Optional payee UUID. Must exist in the payee table.
 * @param splits              The debit/credit lines. Minimum 2 required.
 */
public record PostTransactionRequest(

        @NotNull(message = "ledgerId is required")
        UUID ledgerId,

        @NotNull(message = "currencyCommodityId is required")
        UUID currencyCommodityId,

        // Nullable: DB function defaults to now() if not provided.
        OffsetDateTime postDate,

        // Nullable: DB function defaults to now() if not provided.
        OffsetDateTime enterDate,

        // Nullable: optional narrative description.
        String memo,

        // Nullable: optional reference number (invoice, check number, etc.)
        String num,

        // Default 0 = uncleared. Other values are defined by application convention.
        int status,

        // Nullable: must reference a valid payee in the same ledger.
        UUID payeeId,

        @NotNull
        @Size(min = 2, message = "A transaction requires at least 2 splits")
        @Valid
        List<SplitRequest> splits

) {
    /**
     * A single debit or credit line within the transaction.
     * <p>
     * Rational arithmetic fields:
     *   valueNum / valueDenom = monetary amount
     *   Example: $500.00 MXN = valueNum:50000 / valueDenom:100
     * <p>
     * CRITICAL RULE: all splits in one request MUST have the same
     * valueDenom. The DB function enforces this and will reject
     * the transaction if they differ.
     *
     * @param accountId    Target account UUID. Must be non-placeholder, active,
     *                     non-deleted, and belong to the transaction's ledger.
     * @param side         0 = DEBIT, 1 = CREDIT.
     * @param valueNum     Rational numerator. Must be >= 0.
     * @param valueDenom   Rational denominator. Must be > 0.
     * @param quantityNum  Optional commodity quantity numerator. Default 0.
     * @param quantityDenom Optional commodity quantity denominator. Default 100.
     * @param memo         Optional per-split narrative.
     * @param action       Optional action label for the split.
     */
    public record SplitRequest(

            @NotNull(message = "accountId is required on every split")
            UUID accountId,

            // 0 = DEBIT, 1 = CREDIT — matches split.side smallint in the DB.
            int side,

            // Rational numerator: positive integer representing the amount.
            long valueNum,

            // Rational denominator: defines precision. 100 = cents, 1 = whole units.
            int valueDenom,

            // Optional commodity quantity fields. Default to 0/100 if omitted.
            long quantityNum,
            int  quantityDenom,

            // Optional per-split narrative — different from the transaction memo.
            String memo,

            // Optional action label (e.g. "BUY", "SELL" for investment accounts).
            String action
    ) {
        /**
         * Compact constructor: applies sensible defaults for optional fields.
         * Called automatically by Java when deserializing from JSON.
         */
        public SplitRequest {
            // Default quantityDenom to 100 if not provided (zero would be invalid).
            if (quantityDenom == 0) quantityDenom = 100;
        }
    }
}
