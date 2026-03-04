// ============================================================
// PostTransactionRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of a POST /transactions request.
//
//          Maps to the parameters of the PostgreSQL function:
//            mab_post_transaction(
//              p_ledger_id, p_splits, p_currency_commodity_id, p_memo
//            )
//
//          The splits list must satisfy double-entry balance:
//            SUM of debit splits = SUM of credit splits
//          This invariant is enforced by the DB function,
//          not by the API layer.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;

/**
 * Incoming request body for posting a double-entry transaction.
 *
 * Expected JSON:
 * {
 *   "ledgerId":           "uuid",
 *   "currencyCommodityId": "uuid",
 *   "memo":               "Office supplies purchase",
 *   "splits": [
 *     { "accountId": "uuid", "side": 0, "valueNum": 50000, "valueDenom": 100 },
 *     { "accountId": "uuid", "side": 1, "valueNum": 50000, "valueDenom": 100 }
 *   ]
 * }
 *
 * @param ledgerId            The ledger this transaction belongs to.
 * @param currencyCommodityId The currency of this transaction.
 * @param memo                Optional narrative description.
 * @param splits              The debit/credit split lines. Minimum 2 required.
 */
public record PostTransactionRequest(

        @NotNull(message = "Ledger ID is required")
        UUID ledgerId,

        @NotNull(message = "Currency commodity ID is required")
        UUID currencyCommodityId,

        // Memo is optional — nullable in the DB schema.
        String memo,

        @NotNull
        @Size(min = 2, message = "A transaction requires at least 2 splits")
        List<SplitRequest> splits
) {

    /**
     * Nested record representing a single debit or credit line.
     *
     * Monetary values use rational arithmetic (valueNum / valueDenom)
     * to avoid floating-point rounding errors — matching the DB schema exactly.
     *
     * @param accountId  The account to post this split to.
     * @param side       0 = DEBIT, 1 = CREDIT (matches the DB smallint convention).
     * @param valueNum   Numerator of the rational amount (e.g. 50000 for $500.00).
     * @param valueDenom Denominator of the rational amount (e.g. 100 for cents).
     */
    public record SplitRequest(

            @NotNull(message = "Account ID is required")
            UUID accountId,

            // 0 = DEBIT, 1 = CREDIT — matches split.side in the DB schema.
            int side,

            // Rational arithmetic: amount = valueNum / valueDenom
            // Example: $500.00 = 50000 / 100
            long valueNum,
            int  valueDenom
    ) {}
}