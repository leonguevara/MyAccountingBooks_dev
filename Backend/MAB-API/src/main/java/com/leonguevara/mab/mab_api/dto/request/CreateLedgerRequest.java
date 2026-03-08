// ============================================================
// CreateLedgerRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of a POST /ledgers request.
//
//          Maps to the parameters of the PostgreSQL function:
//            create_ledger_with_optional_template(
//              p_owner_id,             -- from JWT (not in body)
//              p_ledger_name,          -- from request
//              p_currency_mnemonic,    -- from request (e.g., "MXN")
//              p_decimal_places,       -- from request (e.g., 2)
//              p_template_label,       -- hardcoded to "API"
//              p_coa_template_code,    -- from request (nullable)
//              p_coa_template_version  -- from request (nullable)
//            )
//
//          Note: p_owner_id is NEVER in the request body.
//          It is always resolved from the JWT in LedgerService.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.NotBlank;
// import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;

// UUID: matches the UUID type of commodity.id and coa_template.id in the DB.
// import java.util.UUID;

/**
 * Incoming request body for ledger creation.
 * <p>
 * Expected JSON:
 * {
 *   "name":               "My Business Books",
 *   "currencyMnemonic":   "MXN",
 *   "decimalPlaces":      2,
 *   "coaTemplateCode":    "SAT_2025",   // optional, nullable
 *   "coaTemplateVersion": "2025"        // optional, nullable
 * }
 *
 * @param name               Display name for the new ledger.
 * @param currencyMnemonic   ISO 4217 currency code (e.g. "MXN", "USD", "EUR").
 *                           Must match commodity.mnemonic in the database.
 * @param decimalPlaces      Number of decimal display places (1–8).
 *                           Default 2 is appropriate for most fiat currencies.
 * @param coaTemplateCode    Optional COA template code. Both code and version
 *                           must be provided together, or both must be null.
 * @param coaTemplateVersion Optional COA template version (e.g. "2025").
 */
public record CreateLedgerRequest(

        @NotBlank(message = "Ledger name is required")
        String name,

        @NotBlank(message = "Currency mnemonic is required (e.g. MXN, USD)")
        String currencyMnemonic,

        @Min(value = 0, message = "Decimal places must be 0 or more")
        @Max(value = 8, message = "Decimal places must be 8 or fewer")
        short decimalPlaces,

        // Both nullable: if one is provided, the other must also be provided.
        // This constraint is enforced by the PostgreSQL function, which raises
        // an exception if only one is non-null.
        String coaTemplateCode,
        String coaTemplateVersion
) {}