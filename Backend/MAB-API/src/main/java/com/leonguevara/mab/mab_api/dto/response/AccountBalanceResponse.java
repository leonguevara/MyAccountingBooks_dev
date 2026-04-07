// ============================================================
// AccountBalanceResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: Balance for a single account — two rational numbers.
//
//   balanceNum / balanceDenom
//     Always in the LEDGER's base currency (from value_num/value_denom).
//     Used by: AccountTree roll-ups and base-currency balance column.
//
//   nativeBalanceNum / nativeBalanceDenom
//     In the ACCOUNT's native commodity (from quantity_num/quantity_denom).
//     Equals base balance for same-currency accounts.
//     Used by: AccountTree native-currency column, AccountRegisterView.
// ============================================================
// Last edited: 2026-04-06
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Balance for a single account within a ledger.
 *
 * <p>Two rational-number balances are returned:
 *
 * <ul>
 *   <li><b>Base currency</b> — {@code balanceNum / balanceDenom}: always in the
 *       ledger's base currency (e.g. MXN). Computed from
 *       {@code split.value_num / split.value_denom}. Used for account tree
 *       roll-ups and the base-currency balance column.</li>
 *   <li><b>Native currency</b> — {@code nativeBalanceNum / nativeBalanceDenom}:
 *       in the account's own commodity (e.g. USD). Computed from
 *       {@code split.quantity_num / split.quantity_denom}. For same-currency
 *       accounts this equals the base balance. Used for the account tree's
 *       native column and the register view.</li>
 * </ul>
 *
 * @param accountId          The account UUID.
 * @param balanceNum         Signed base-currency numerator.
 * @param balanceDenom       Base-currency denominator (e.g. 100 for 2 decimal places).
 * @param nativeBalanceNum   Signed native-currency numerator.
 * @param nativeBalanceDenom Native-currency denominator.
 */
public record AccountBalanceResponse(
        UUID accountId,
        long balanceNum,
        int  balanceDenom,
        long nativeBalanceNum,
        int  nativeBalanceDenom
) {}
