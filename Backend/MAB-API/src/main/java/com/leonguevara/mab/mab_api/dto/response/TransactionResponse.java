// ============================================================
// TransactionResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a posted transaction,
//          returned after a successful POST /transactions call.
//
//          Includes the transaction header fields and the
//          full list of splits that were created.
//          The split.amount field is NOT included in the response
//          because it is a generated presentation column in the
//          DB — clients should compute display amounts from
//          valueNum / valueDenom themselves.
// ============================================================
// Last edited: 2026-03-14
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Response body for a successfully posted transaction.
 * <p>
 * Returned JSON example:
 * {
 *   "id":                   "uuid",
 *   "ledgerId":             "uuid",
 *   "currencyCommodityId":  "uuid",
 *   "postDate":             "2026-03-05T12:00:00-06:00",
 *   "enterDate":            "2026-03-05T12:00:00-06:00",
 *   "memo":                 "Office supplies",
 *   "num":                  "TXN-001",
 *   "isVoided":             false,
 *   "splits": [
 *     {"id": "uuid", "accountId": "uuid", "side": 0, "valueNum": 50000, "valueDenom": 100},
 *     {"id": "uuid", "accountId": "uuid", "side": 1, "valueNum": 50000, "valueDenom": 100}
 *   ]
 * }
 *
 * @param id                  UUID of the created transaction.
 * @param ledgerId            UUID of the ledger it was posted to.
 * @param currencyCommodityId UUID of the transaction currency commodity.
 * @param postDate            Effective date of the transaction.
 * @param enterDate           Date the transaction was entered into the system.
 * @param memo                Transaction-level narrative. Might be null.
 * @param num                 Reference number (invoice, check, etc.). Might be null.
 * @param isVoided            Always false on creation. Becomes true after void.
 * @param splits              The split lines that were created.
 */
public record TransactionResponse(
        UUID           id,
        UUID           ledgerId,
        UUID           currencyCommodityId,
        OffsetDateTime postDate,
        OffsetDateTime enterDate,
        String         memo,
        String         num,
        boolean        isVoided,
        List<SplitResponse> splits
) {
    /**
     * A single split line in the transaction response.
     *
     * @param id           UUID of the split row.
     * @param accountId    UUID of the account this split posts to.
     * @param side         0 = DEBIT, 1 = CREDIT.
     * @param valueNum     Rational numerator of the monetary amount.
     * @param valueDenom   Rational denominator. Same for all splits in transaction.
     * @param memo         Per-split narrative. Might be null.
     */
    public record SplitResponse(
            UUID   id,
            UUID   transactionId,
            UUID   accountId,
            int    side,
            long   valueNum,
            int    valueDenom,
            String memo
    ) {}

    public TransactionResponse withSplits(List<SplitResponse> splits) {
        return new TransactionResponse(
                this.id(),
                this.ledgerId(),
                this.currencyCommodityId(),
                this.postDate(),
                this.enterDate(),
                this.memo(),
                this.num(),
                this.isVoided(),
                splits
    );
}
}
