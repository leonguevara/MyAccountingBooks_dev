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
 * Represents a payee returned by the API.
 *
 * Example JSON:
 * {
 *   "id":       "550e8400-e29b-41d4-a716-446655440000",
 *   "ledgerId": "4e0b6c9e-2b6b-4c2e-9b8b-3e7b1a2d8f10",
 *   "name":     "Walmart"
 * }
 *
 * @param id       UUID of the payee.
 * @param ledgerId UUID of the ledger this payee belongs to.
 * @param name     Display name of the payee.
 */
public record PayeeResponse(UUID id, UUID ledgerId, String name) {}