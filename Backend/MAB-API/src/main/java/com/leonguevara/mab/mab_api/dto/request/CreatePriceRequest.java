// ============================================================
// CreatePriceRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /ledgers/{id}/prices.
//
//          All monetary values use the rational-number convention:
//            rate = valueNum / valueDenom
//          e.g. USD/MXN = 19.50 → valueNum=1950, valueDenom=100
// ============================================================
// Last edited: 2026-04-03
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Request body for {@code POST /ledgers/{id}/prices}.
 *
 * <p>The exchange rate is encoded as a rational number: {@code rate = valueNum / valueDenom}.
 * For example, USD/MXN = 19.50 → {@code valueNum=1950, valueDenom=100}.
 *
 * @param commodityId UUID of the commodity being priced (e.g. USD). Required.
 * @param currencyId  UUID of the reference currency (e.g. MXN). Required.
 * @param date        Effective timestamp; defaults to {@code now()} if null.
 * @param valueNum    Rational numerator. Must be &gt;= 0.
 * @param valueDenom  Rational denominator. Must be &gt;= 1.
 * @param source      Optional source label (e.g. "manual", "Banxico").
 * @param type        Optional price type (e.g. "last", "bid", "ask").
 */
public record CreatePriceRequest(

        @NotNull(message = "commodityId is required")
        UUID commodityId,

        @NotNull(message = "currencyId is required")
        UUID currencyId,

        OffsetDateTime date,

        @Min(value = 0, message = "valueNum must be >= 0")
        long valueNum,

        @Min(value = 1, message = "valueDenom must be >= 1")
        int valueDenom,

        String source,

        String type
) {}
