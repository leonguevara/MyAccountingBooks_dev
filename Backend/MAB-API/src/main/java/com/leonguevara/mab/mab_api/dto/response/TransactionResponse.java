// ============================================================
// TransactionResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON response for a posted transaction and its splits.
//
//          SplitResponse now includes quantity fields so the
//          Swift client can display amounts in the account's
//          native currency (e.g. USD) rather than the ledger's
//          base currency (e.g. MXN) in the register view.
//
//          quantity_num / quantity_denom = amount in the
//          account's native commodity (foreign currency).
//          value_num    / value_denom    = amount in the
//          ledger's base currency.
//
//          For same-currency splits these pairs are equal.
// ============================================================
// Last edited: 2026-04-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Response body for a transaction with its nested split lines.
 *
 * @param id                   UUID of the transaction.
 * @param ledgerId             UUID of the ledger this transaction belongs to.
 * @param currencyCommodityId  UUID of the base currency commodity.
 * @param postDate             Effective accounting date.
 * @param enterDate            System entry timestamp.
 * @param memo                 Transaction-level narrative; null when not provided.
 * @param num                  Reference or check number; null when not provided.
 * @param isVoided             True after POST .../void.
 * @param splits               The split lines making up the double-entry posting.
 * @param payeeId              UUID of the associated payee; null when no payee is set.
 */
public record TransactionResponse(
        UUID                id,
        UUID                ledgerId,
        UUID                currencyCommodityId,
        OffsetDateTime      postDate,
        OffsetDateTime      enterDate,
        String              memo,
        String              num,
        boolean             isVoided,
        List<SplitResponse> splits,
        UUID                payeeId
) {

    /**
     * A single split line within a {@link TransactionResponse}.
     *
     * <p>For foreign-currency accounts:
     * <ul>
     *   <li>{@code valueNum / valueDenom} — amount in the ledger's base currency (e.g. MXN).
     *       Used by the account tree balance view.</li>
     *   <li>{@code quantityNum / quantityDenom} — amount in the account's native currency
     *       (e.g. USD). Used by the account register view.</li>
     * </ul>
     * For same-currency splits, these pairs are equal.
     *
     * @param id             UUID of the split record.
     * @param transactionId  UUID of the parent transaction.
     * @param accountId      UUID of the account this split posts to.
     * @param side           0 = DEBIT, 1 = CREDIT.
     * @param valueNum       Base-currency numerator (unsigned).
     * @param valueDenom     Base-currency denominator.
     * @param quantityNum    Native-currency numerator (unsigned).
     * @param quantityDenom  Native-currency denominator.
     * @param memo           Per-split narrative; null when not provided.
     */
    public record SplitResponse(
            UUID   id,
            UUID   transactionId,
            UUID   accountId,
            int    side,
            long   valueNum,
            int    valueDenom,
            long   quantityNum,
            int    quantityDenom,
            String memo
    ) {}

    /** Returns a copy with the splits list replaced. Used by the repository layer. */
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
