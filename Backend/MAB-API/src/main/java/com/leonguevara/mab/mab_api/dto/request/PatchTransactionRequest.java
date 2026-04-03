// ============================================================
// PatchTransactionRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for PATCH /transactions/{id}.
//
//          All fields are nullable. Only non-null fields are
//          applied. This follows JSON Merge Patch semantics
//          (RFC 7396) — send only what you want to change.
//
//          Editable fields:
//            - memo       : transaction-level description
//            - num        : reference number
//            - postDate   : effective date of the transaction
//            - splits     : per-split memo and account changes
//
//          NOT editable via this endpoint:
//            - amounts (value_num / value_denom) — use reverse+repost
//            - ledgerId, currencyCommodityId     — structural fields
//            - isVoided                          — use void endpoint
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Request body for {@code PATCH /transactions/{id}}.
 *
 * <p>Implements JSON Merge Patch semantics (RFC 7396): only non-{@code null} fields are
 * written; all others are left unchanged. The transaction must not be voided or deleted.</p>
 *
 * <p><strong>Not editable via this endpoint:</strong></p>
 * <ul>
 *   <li>Amounts ({@code value_num} / {@code value_denom}) — use the reverse + repost workflow.</li>
 *   <li>Structural fields ({@code ledgerId}, {@code currencyCommodityId}).</li>
 *   <li>{@code isVoided} — use the dedicated {@code POST .../void} endpoint.</li>
 * </ul>
 *
 * @param memo     new transaction-level description; {@code null} = no change
 * @param num      new reference/check number; {@code null} = no change
 * @param postDate new effective date (ISO 8601 with timezone); {@code null} = no change
 * @param payeeId  new payee UUID; {@code null} = no change
 * @param splits   per-split patches; {@code null} or empty = no split changes;
 *                 each entry must reference an existing split within the transaction
 * @see PatchSplitRequest
 * @see com.leonguevara.mab.mab_api.repository.TransactionRepository#update
 */
public record PatchTransactionRequest(
        String         memo,
        String         num,
        OffsetDateTime postDate,
        UUID           payeeId,
        List<PatchSplitRequest> splits
) {
    /**
     * Partial update for a single split line within a transaction.
     *
     * <p>Only {@code memo} and {@code accountId} are patchable; amounts are immutable.
     * The target account must be active, non-placeholder, and within the same ledger
     * as the transaction (enforced by FK + CHECK constraints and RLS).</p>
     *
     * @param splitId   UUID of the split to update; required — entries with a {@code null}
     *                  {@code splitId} are silently skipped by the repository
     * @param memo      new split-level memo; {@code null} = no change
     * @param accountId UUID of the replacement account; {@code null} = no change;
     *                  must be active, non-placeholder, and in the same ledger
     */
    public record PatchSplitRequest(
            UUID   splitId,
            String memo,
            UUID   accountId
    ) {}
}