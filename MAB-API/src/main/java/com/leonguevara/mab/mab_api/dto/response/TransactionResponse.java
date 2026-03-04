// ============================================================
// TransactionResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a posted transaction,
//          including its split lines.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Response body representing a posted double-entry transaction.
 *
 * @param id           UUID of the transaction.
 * @param ledgerId     UUID of the ledger it belongs to.
 * @param memo         Optional narrative description.
 * @param postDate     The date/time the transaction was posted.
 * @param isVoided     True if this transaction has been voided.
 * @param splits       The individual debit/credit lines.
 */
public record TransactionResponse(
        UUID           id,
        UUID           ledgerId,
        String         memo,
        OffsetDateTime postDate,
        boolean        isVoided,
        List<SplitResponse> splits
) {

    /**
     * Nested record representing a single split line in the response.
     *
     * @param id         UUID of the split.
     * @param accountId  UUID of the account this split posts to.
     * @param side       0 = DEBIT, 1 = CREDIT.
     * @param valueNum   Numerator of the rational amount.
     * @param valueDenom Denominator of the rational amount.
     */
    public record SplitResponse(
            UUID id,
            UUID accountId,
            int  side,
            long valueNum,
            int  valueDenom
    ) {}
}