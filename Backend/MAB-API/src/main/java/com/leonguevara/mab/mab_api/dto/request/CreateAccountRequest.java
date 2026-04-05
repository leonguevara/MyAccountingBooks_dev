// ============================================================
// CreateAccountRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for POST /accounts.
//
//          commodityId: optional override for the account's
//          commodity. When null, the account inherits the
//          commodity from the parent account (standard behaviour).
//          Provide a non-null UUID only for foreign-currency accounts.
// ============================================================
// Last edited: 2026-04-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.util.UUID;

/**
 * Request body for creating a new account in the chart of accounts.
 * <p>
 * <strong>Account Classification:</strong> Uses three orthogonal dimensions:
 * <ul>
 *   <li><strong>kind</strong> (implicit via parent): Accounting nature</li>
 *   <li><strong>accountTypeCode</strong>: Functional classification (BANK, CASH, etc.)</li>
 *   <li><strong>accountRole</strong>: Operational role bitmask</li>
 * </ul>
 * <p>
 * <strong>Commodity:</strong> When {@code commodityId} is null, the repository
 * inherits the commodity from the parent account (standard for same-currency ledgers).
 * Provide a non-null {@code commodityId} only for foreign-currency accounts.
 *
 * @param ledgerId        Target ledger UUID. Required.
 * @param name            Human-readable account name. Required.
 * @param code            Optional account code (e.g., "1000", "2110").
 * @param parentId        Parent account UUID. Required.
 * @param accountTypeCode FK to {@code account_type.code}. Required for non-placeholders.
 * @param accountRole     Operational role bitmask. Defaults to 0.
 * @param isPlaceholder   {@code true} if grouping-only (cannot post transactions).
 * @param isHidden        {@code true} to hide from default views.
 * @param commodityId     Optional commodity UUID override. Null = inherit from parent.
 */
public record CreateAccountRequest(
        UUID    ledgerId,
        String  name,
        String  code,
        UUID    parentId,
        String  accountTypeCode,
        int     accountRole,
        boolean isPlaceholder,
        boolean isHidden,
        UUID    commodityId      // nullable — null means inherit from parent
) {}
