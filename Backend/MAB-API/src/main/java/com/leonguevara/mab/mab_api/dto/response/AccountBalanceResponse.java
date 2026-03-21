// ============================================================
// AccountBalanceResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: Balance for a single account.
//          Uses rational arithmetic — balanceNum / balanceDenom.
//          Client computes: Decimal(balanceNum) / Decimal(balanceDenom)
//          Voided transactions are excluded.
//          Only non-deleted, active splits are included.
// ============================================================
// Last edited: 2026-03-21
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Balance for a single account within a ledger.
 *
 * @param accountId    The account UUID.
 * @param balanceNum   Signed rational numerator.
 *                     Positive = net debit, negative = net credit.
 * @param balanceDenom Rational denominator (e.g. 100 for 2 decimal places).
 */
public record AccountBalanceResponse(
        UUID accountId,
        long balanceNum,
        int  balanceDenom
) {}
