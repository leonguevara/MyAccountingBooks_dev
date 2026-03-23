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
// Last edited: 2026-03-22
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Partial update request for a transaction header and its split memos/accounts.
 * <p>
 * Implements JSON Merge Patch semantics (RFC 7396): only non-null fields are updated.
 * All fields are optional — send only what you want to modify.
 * <p>
 * <b>Important constraints:</b>
 * <ul>
 *   <li>Cannot modify amounts (value_num/value_denom) — use reverse + repost workflow instead</li>
 *   <li>Cannot change structural fields (ledgerId, currencyCommodityId)</li>
 *   <li>Cannot void/unvoid via this endpoint — use dedicated void operation</li>
 *   <li>All split updates are applied within a single database transaction</li>
 * </ul>
 *
 * @param memo      New transaction-level description. Null = no change.
 * @param num       New reference/check number. Null = no change.
 * @param postDate  New effective transaction date (ISO 8601 with timezone). Null = no change.
 * @param splits    List of per-split updates. Null or empty = no split changes.
 *                  Each entry must reference an existing split within the transaction.
 * @see PatchSplitRequest
 */
public record PatchTransactionRequest(
        String         memo,
        String         num,
        OffsetDateTime postDate,
        List<PatchSplitRequest> splits
) {
    /**
     * Partial update for a single split line within a transaction.
     * <p>
     * Allows changing the split's memo and/or the account it posts to.
     * The split must already exist and belong to the transaction being patched.
     * <p>
     * <b>Account change constraints:</b>
     * <ul>
     *   <li>Target account must exist and belong to the same ledger</li>
     *   <li>Account must be active (not deleted)</li>
     *   <li>Account must be non-placeholder (leaf nodes only)</li>
     *   <li>Database RLS policies enforce ownership validation</li>
     * </ul>
     *
     * @param splitId   UUID of the existing split to update. <b>Required.</b>
     *                  Must belong to the transaction referenced in the PATCH path.
     * @param memo      New split-level memo/note. Null = no change.
     * @param accountId UUID of the new account to assign this split to. Null = no change.
     *                  When provided, must reference a valid, active, non-placeholder account
     *                  within the same ledger as the transaction.
     */
    public record PatchSplitRequest(
            UUID   splitId,
            String memo,
            UUID   accountId
    ) {}
}