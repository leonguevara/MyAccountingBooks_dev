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
 * Request body for {@code POST /payees}.
 *
 * <p>Validated by {@code @Valid} in {@link com.leonguevara.mab.mab_api.controller.PayeeController}.
 * The {@code (ledgerId, name)} combination must be unique within the ledger; a duplicate
 * triggers HTTP 409.</p>
 *
 * <pre>{@code
 * {
 *   "ledgerId": "4e0b6c9e-2b6b-4c2e-9b8b-3e7b1a2d8f10",
 *   "name":     "Walmart"
 * }
 * }</pre>
 *
 * @param ledgerId UUID of the ledger this payee belongs to. Required ({@code @NotNull}).
 * @param name     Display name of the payee; must be non-blank ({@code @NotBlank}) and
 *                 unique within the ledger.
 * @see com.leonguevara.mab.mab_api.controller.PayeeController#createPayee
 * @see com.leonguevara.mab.mab_api.dto.response.PayeeResponse
 */
public record CreatePayeeRequest(

        @NotNull(message = "ledgerId is required")
        UUID ledgerId,

        @NotBlank(message = "name is required")
        String name
) {}