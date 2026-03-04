// ============================================================
// CreateLedgerRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of a POST /ledgers request.
//
//          Maps to the parameters of the PostgreSQL function:
//            create_ledger_with_optional_template(
//              p_owner_id, p_name, p_currency_commodity_id,
//              p_coa_template_id   -- nullable
//            )
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

// UUID: matches the UUID type of commodity.id and coa_template.id in the DB.
import java.util.UUID;

/**
 * Incoming request body for ledger creation.
 *
 * Expected JSON:
 * {
 *   "name":               "My Business Books",
 *   "currencyCommodityId": "uuid-of-MXN-commodity",
 *   "coaTemplateId":       "uuid-of-template"   // optional, nullable
 * }
 *
 * @param name               Display name for the new ledger.
 * @param currencyCommodityId UUID of the base currency commodity (e.g. MXN, USD).
 *                           References commodity.id in the database.
 * @param coaTemplateId      Optional UUID of a COA template to instantiate.
 *                           If null, the ledger is created with no accounts.
 */
public record CreateLedgerRequest(

        @NotBlank(message = "Ledger name is required")
        String name,

        @NotNull(message = "Currency commodity ID is required")
        UUID currencyCommodityId,

        // Nullable: a ledger can be created without a COA template.
        UUID coaTemplateId
) {}