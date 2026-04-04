// ============================================================
// PriceResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: Response body for price endpoints.
//
//          Represents one exchange-rate entry in the price table.
//          The rate is expressed as a rational number:
//            rate = valueNum / valueDenom
//          e.g. USD/MXN = 19.50 → valueNum=1950, valueDenom=100
// ============================================================
// Last edited: 2026-04-03
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * One exchange-rate entry returned by the price endpoints.
 *
 * <p>The rate is encoded as a rational number: {@code rate = valueNum / valueDenom}.
 * For example, USD/MXN = 19.50 → {@code valueNum=1950, valueDenom=100}.
 *
 * @param id          UUID of the price entry.
 * @param ledgerId    UUID of the owning ledger.
 * @param commodityId UUID of the commodity being priced (e.g. USD).
 * @param currencyId  UUID of the reference currency (e.g. MXN).
 * @param date        Timestamp at which this rate is effective.
 * @param valueNum    Rational numerator of the exchange rate.
 * @param valueDenom  Rational denominator of the exchange rate.
 * @param source      Optional source label (e.g. "manual", "Banxico").
 * @param type        Optional price type (e.g. "last", "bid", "ask").
 */
public record PriceResponse(
        UUID           id,
        UUID           ledgerId,
        UUID           commodityId,
        UUID           currencyId,
        OffsetDateTime date,
        long           valueNum,
        int            valueDenom,
        String         source,
        String         type
) {}
