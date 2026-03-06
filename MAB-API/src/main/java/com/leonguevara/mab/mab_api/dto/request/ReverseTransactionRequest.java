// ============================================================
// ReverseTransactionRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /transactions/{id}/reverse.
//
//          Maps to mab_reverse_transaction(p_tx_id, p_post_date,
//                                          p_enter_date, p_memo).
//
//          All fields are optional:
//            - postDate  → defaults to now() inside the DB function
//            - enterDate → defaults to now() inside the DB function
//            - memo      → defaults to "Reversal of <tx_id>"
//
//          The transaction ID itself comes from the URL path,
//          not from this body — consistent with REST conventions.
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.time.OffsetDateTime;

/**
 * Optional body for a transaction reversal.
 * <p>
 * All fields nullable. Example minimal call uses an empty body {}.
 * Example full body:
 * {
 *   "postDate":  "2026-03-06T00:00:00-06:00",
 *   "enterDate": "2026-03-06T00:00:00-06:00",
 *   "memo":      "Correction — wrong account"
 * }
 *
 * @param postDate  Effective date of the reversal transaction.
 *                  Null → DB defaults to now().
 * @param enterDate Entry date of the reversal transaction.
 *                  Null → DB defaults to now().
 * @param memo      Narrative for the reversal transaction.
 *                  Null → DB defaults to "Reversal of <original-tx-id>".
 */
public record ReverseTransactionRequest(
        OffsetDateTime postDate,
        OffsetDateTime enterDate,
        String         memo
) {
    /**
     * Compact constructor: allows a fully null/empty body.
     * Called when the client sends {} or omits the body entirely.
     */
    public ReverseTransactionRequest {
        // No validation required — all fields are optional.
    }
}