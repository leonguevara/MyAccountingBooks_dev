// ============================================================
// PayeeResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: Response body for payee endpoints.
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body returned by payee endpoints.
 *
 * <p>Produced by {@code GET /ledgers/{ledgerID}/payees} (list) and
 * {@code POST /payees} (create, HTTP 201).</p>
 *
 * <pre>{@code
 * {
 *   "id":       "550e8400-e29b-41d4-a716-446655440000",
 *   "ledgerId": "4e0b6c9e-2b6b-4c2e-9b8b-3e7b1a2d8f10",
 *   "name":     "Walmart"
 * }
 * }</pre>
 *
 * @param id       unique identifier of the payee record
 * @param ledgerId UUID of the ledger this payee belongs to
 * @param name     display name of the payee; unique within its ledger
 * @see com.leonguevara.mab.mab_api.controller.PayeeController
 * @see com.leonguevara.mab.mab_api.dto.request.CreatePayeeRequest
 */
public record PayeeResponse(UUID id, UUID ledgerId, String name) {}