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
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Response body returned by transaction endpoints ({@code POST /transactions},
 * {@code POST /transactions/{id}/reverse}, {@code POST /transactions/{id}/void},
 * {@code PATCH /transactions/{id}}).
 *
 * <p>Contains the transaction header and the full list of {@link SplitResponse} lines.
 * The {@code split.amount} DB column is intentionally excluded — it is a generated
 * presentation field. Clients must compute display amounts from
 * {@code valueNum / valueDenom} themselves.</p>
 *
 * <pre>{@code
 * {
 *   "id":                   "uuid",
 *   "ledgerId":             "uuid",
 *   "currencyCommodityId":  "uuid",
 *   "postDate":             "2026-03-05T12:00:00-06:00",
 *   "enterDate":            "2026-03-05T12:00:00-06:00",
 *   "memo":                 "Office supplies",
 *   "num":                  "TXN-001",
 *   "isVoided":             false,
 *   "payeeId":              null,
 *   "splits": [
 *     {"id": "uuid", "accountId": "uuid", "side": 0, "valueNum": 50000, "valueDenom": 100},
 *     {"id": "uuid", "accountId": "uuid", "side": 1, "valueNum": 50000, "valueDenom": 100}
 *   ]
 * }
 * }</pre>
 *
 * @param id                  UUID of the transaction record
 * @param ledgerId            UUID of the ledger this transaction was posted to
 * @param currencyCommodityId UUID of the transaction's currency commodity
 * @param postDate            effective (accounting) date of the transaction
 * @param enterDate           timestamp when the transaction was entered into the system
 * @param memo                transaction-level narrative; {@code null} when not provided
 * @param num                 reference number (invoice, cheque, etc.); {@code null} when not provided
 * @param isVoided            {@code false} on creation; {@code true} after {@code POST .../void}
 * @param splits              the split lines that make up the double-entry posting
 * @param payeeId             UUID of the associated payee; {@code null} when no payee is set
 * @see SplitResponse
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
        List<SplitResponse> splits,
        UUID           payeeId  // nullable, null means no payee
) {
    /**
     * A single split line within a {@link TransactionResponse}.
     *
     * <p>The monetary amount is stored as a rational number ({@code valueNum / valueDenom}).
     * All splits in the same transaction share the same {@code valueDenom}. The
     * {@code amount} generated column is excluded from this DTO; clients derive display
     * values from the rational fields directly.</p>
     *
     * @param id            UUID of the split record
     * @param transactionId UUID of the parent transaction
     * @param accountId     UUID of the account this split posts to
     * @param side          {@code 0} = DEBIT, {@code 1} = CREDIT
     * @param valueNum      rational numerator of the monetary amount (unsigned)
     * @param valueDenom    rational denominator; identical for all splits in the transaction
     * @param memo          per-split narrative; {@code null} when not provided
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

    /**
     * Returns a copy of this response with the {@code splits} list replaced.
     *
     * <p>Used by the service layer to attach fully-hydrated {@link SplitResponse} records
     * after the transaction header has already been mapped from a result set row.</p>
     *
     * @param splits the split lines to attach
     * @return a new {@code TransactionResponse} identical to this one except for {@code splits}
     */
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
                splits,
                this.payeeId()
        );
    }
}
