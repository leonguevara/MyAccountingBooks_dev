// ============================================================
// CommodityResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a single commodity row.
//
//          Commodities are the currency/security catalog.
//          They are referenced by:
//            - ledger.currency_commodity_id
//            - transaction.currency_commodity_id
//            - account.commodity_id
//            - split (indirectly via transaction)
//
//          fraction: the smallest unit denominator.
//            - MXN → 100  (centavos, cents)
//            - JPY → 1    (no subunit)
//            - BTC → 100000000 (satoshis)
//          Clients use fraction to compute value_denom for splits.
//
//          namespace: commodity category.
//            - "CURRENCY" → ISO-4217 fiat currencies
//            - "STOCK", "FUND", etc. for investment commodities
// ============================================================
// Last edited: 2026-03-07
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body representing a single commodity (currency or security).
 * <p>
 * Returned JSON example:
 * {
 *   "id":        "uuid",
 *   "mnemonic":  "MXN",
 *   "namespace": "CURRENCY",
 *   "fullName":  "Mexican Peso",
 *   "fraction":  100,
 *   "isActive":  true
 * }
 *
 * @param id        UUID primary key. Used as currencyCommodityId in
 *                  PostTransactionRequest and CreateLedgerRequest.
 * @param mnemonic  ISO-4217 code for currencies (e.g. "MXN", "USD").
 *                  Ticker symbol for securities.
 * @param namespace Category: "CURRENCY", "STOCK", "FUND", etc.
 * @param fullName  Human-readable name. May be null for non-standard entries.
 * @param fraction  Smallest unit denominator. Use as value_denom in splits.
 *                  Example: MXN fraction=100 → value_num=50000 means $500.00
 * @param isActive  False if this commodity has been deactivated.
 *                  Inactive commodities are excluded from default queries.
 */
public record CommodityResponse(
        UUID    id,
        String  mnemonic,
        String  namespace,
        String  fullName,
        long    fraction,
        boolean isActive
) {}
