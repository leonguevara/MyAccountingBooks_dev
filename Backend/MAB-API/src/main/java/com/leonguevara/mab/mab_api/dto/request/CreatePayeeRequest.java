// ============================================================
// CreatePayeeRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /payees.
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;

/**
 * Request body for POST /payees.
 *
 * Example JSON:
 * {
 *   "ledgerId": "4e0b6c9e-2b6b-4c2e-9b8b-3e7b1a2d8f10",
 *   "name":     "Walmart"
 * }
 *
 * @param ledgerId UUID of the ledger to which this payee belongs.
 * @param name     Display name of the payee. Must be unique per ledger.
 */
public record CreatePayeeRequest(

        @NotNull(message = "ledgerId is required")
        UUID ledgerId,

        @NotBlank(message = "name is required")
        String name
) {}