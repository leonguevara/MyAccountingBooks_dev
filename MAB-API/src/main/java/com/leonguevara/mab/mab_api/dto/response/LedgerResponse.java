// ============================================================
// LedgerResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a ledger row returned to clients.
//          Maps columns from the v_ledger view in PostgreSQL,
//          which joins ledger + commodity to include currencyCode.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body representing a single ledger.
 *
 * Returned JSON example:
 * {
 *   "id":           "uuid",
 *   "name":         "My Business Books",
 *   "currencyCode": "MXN",
 *   "decimalPlaces": 2
 * }
 *
 * @param id            The ledger's UUID primary key.
 * @param name          Display name of the ledger.
 * @param currencyCode  ISO 4217 currency code (e.g. "MXN", "USD").
 *                      Derived from commodity.mnemonic via v_ledger view.
 * @param decimalPlaces Number of decimal places for display (e.g. 2 for cents).
 */
public record LedgerResponse(
        UUID   id,
        String name,
        String currencyCode,
        int    decimalPlaces
) {}