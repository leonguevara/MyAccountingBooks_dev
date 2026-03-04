// ============================================================
// AccountResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a single account node in the
//          Chart of Accounts tree.
//          Clients use parentId to reconstruct the tree hierarchy
//          on the UI side.
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response body representing a single account.
 *
 * Returned JSON example:
 * {
 *   "id":            "uuid",
 *   "name":          "Cash and Cash Equivalents",
 *   "code":          "1010",
 *   "parentId":      "uuid-of-parent",
 *   "isPlaceholder": false,
 *   "accountTypeCode": "CASH"
 * }
 *
 * @param id              UUID primary key of the account.
 * @param name            Display name.
 * @param code            Account code (e.g. "1010").
 * @param parentId        UUID of the parent account. Null for the root account.
 * @param isPlaceholder   True if this account is a grouping node only
 *                        (cannot receive transactions directly).
 * @param accountTypeCode The code from account_type (e.g. "CASH", "AP", "SALES").
 */
public record AccountResponse(
        UUID    id,
        String  name,
        String  code,
        UUID    parentId,
        boolean isPlaceholder,
        String  accountTypeCode
) {}