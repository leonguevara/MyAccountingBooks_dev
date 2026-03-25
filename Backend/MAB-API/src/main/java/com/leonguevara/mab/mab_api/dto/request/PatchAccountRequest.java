// ============================================================
// PatchAccountRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for PATCH /accounts/{id}.
//
//          All fields are nullable. Only non-null fields are
//          applied. This follows JSON Merge Patch semantics
//          (RFC 7396) — send only what you want to change.
//
//          Editable fields:
//            - name            : account display name
//            - code            : account code (e.g., "1000", "2110")
//            - parentId        : move account to new parent
//            - accountTypeCode : change functional classification
//            - accountRole     : change operational role bitmask
//            - isPlaceholder   : convert to/from grouping-only node
//            - isHidden        : toggle visibility in UI
//
//          Important constraints:
//            - parentId change: must not create circular hierarchy
//            - isPlaceholder → true: only if account has zero transactions
//            - accountTypeCode change: may violate business rules if
//              account has posted transactions (e.g., posting to CONTROL)
//
//          All updates are validated by mab_update_account() stored
//          function and respect Row-Level Security (RLS).
// ============================================================
// Last edited: 2026-03-23
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.util.UUID;

/**
 * Request DTO for partially updating an existing account via PATCH /accounts/{id}.
 * <p>
 * This record supports sparse updates: all fields are nullable, and only non-null values
 * are applied to the target account. Fields set to {@code null} retain their existing
 * database values. This follows RFC 7396 (JSON Merge Patch) semantics.
 * <p>
 * <strong>Important Constraints:</strong>
 * <ul>
 *   <li><strong>Parent changes:</strong> The new parent must belong to the same ledger
 *       and must not create a circular hierarchy. Validation is enforced by
 *       {@code mab_update_account()} in the database layer.</li>
 *   <li><strong>Placeholder transitions:</strong> Converting a non-placeholder account to
 *       a placeholder is only allowed if the account has no posted transactions.</li>
 *   <li><strong>Account type:</strong> Changing {@code accountTypeCode} on an account
 *       with existing transactions may violate business rules (e.g., posting to a
 *       control account). Proceed with caution.</li>
 * </ul>
 * <p>
 * All updates respect Row-Level Security (RLS) and are scoped to the authenticated
 * owner via {@code TenantContext.withOwner()}.
 *
 * @param name            New human-readable account name. {@code null} = keep existing.
 * @param code            New account code (e.g., "1000", "2110"). {@code null} = keep existing.
 * @param parentId        New parent account UUID. {@code null} = keep existing parent.
 *                        Must belong to the same ledger; cannot create circular references.
 * @param accountTypeCode New FK to {@code account_type.code} (e.g., "BANK", "EQUITY").
 *                        {@code null} = keep existing. Setting to {@code null} explicitly
 *                        is only valid for placeholder accounts.
 * @param accountRole     New operational role bitmask (0 = Normal, 1 = Control, 2 = Tax, 4 = Memo).
 *                        {@code null} = keep existing.
 * @param isPlaceholder   New placeholder flag. {@code true} = grouping-only (no transactions).
 *                        {@code null} = keep existing. Converting to placeholder requires zero transactions.
 * @param isHidden        New hidden flag. {@code true} = hide from default views. {@code null} = keep existing.
 */
public record PatchAccountRequest(
        String  name,
        String  code,
        UUID    parentId,
        String  accountTypeCode,
        Integer accountRole,
        Boolean isPlaceholder,
        Boolean isHidden
) {}