// ============================================================
// AccountResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a single account node.
//
//          Clients use parentId to reconstruct the COA tree
//          hierarchy on the UI side. The flat list approach
//          is intentional — each platform's UI framework
//          (SwiftUI OutlineGroup, Android LazyColumn, JavaFX
//          TreeView) reconstructs the hierarchy from parentId.
//
//          accountTypeCode: the string code from account_type
//          (e.g. "CASH", "AP", "SALES") joined from the
//          account_type table. Allows clients to apply
//          display logic without a separate lookup call.
// ============================================================
// Last edited: 2026-03-05
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body representing a single account.
 * <p>
 * Returned JSON example:
 * {
 *   "id":            "uuid",
 *   "name":          "Cash and Cash Equivalents",
 *   "code":          "1010",
 *   "parentId":      "uuid-of-parent",
 *   "isPlaceholder": false,
 *   "isHidden":        false,
 *   "kind":            1,
 *   "accountTypeCode": "CASH"
 * }
 *
 * @param id              UUID primary key of the account.
 * @param name            Display name.
 * @param code            Account code (e.g. "1010"). Nullable.
 * @param parentId        UUID of the parent account. Null for the root account.
 * @param isPlaceholder   True if this account is a grouping node only
 *                        (cannot receive transactions directly).
 * @param isHidden        True if this account should be hidden in UI.
 * @param kind            Accounting nature: 1=asset, 2=liability,
 *                        3=equity, 4=income, 5=costOfSales,
 *                        6=expense, 7=memorandum, 8=statistical.
 * @param accountTypeCode The code from account_type (e.g. "CASH", "AP", "SALES").
 *                        Null if no account type is assigned.
 */
public record AccountResponse(
        UUID    id,
        String  name,
        String  code,
        UUID    parentId,
        boolean isPlaceholder,
        boolean isHidden,
        int     kind,
        String  accountTypeCode
) {}