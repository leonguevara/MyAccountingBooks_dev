// ============================================================
// VoidTransactionRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /transactions/{id}/void.
//
//          Maps to mab_void_transaction(p_tx_id, p_reason).
//
//          reason is optional:
//            - If provided, appended to memo as "[VOID: reason]"
//            - If null, memo is unchanged
//
//          The transaction ID comes from the URL path.
// ============================================================
// Last edited: 2026-03-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

/**
 * Optional body for a transaction void.
 * <p>
 * Example body:
 * {
 *   "reason": "Duplicate entry"
 * }
 * <p>
 * Or empty body {} if no reason needed.
 *
 * @param reason Human-readable reason for voiding. Nullable.
 *               Appended to the transaction memo as "[VOID: reason]".
 */
public record VoidTransactionRequest(
        String reason
) {}