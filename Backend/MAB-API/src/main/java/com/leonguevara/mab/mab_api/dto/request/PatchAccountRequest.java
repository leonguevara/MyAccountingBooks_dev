// ============================================================
// PatchAccountRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Request body for PATCH /accounts/{id}.
//
//          All fields are nullable — only non-null values are applied.
//          commodityId: pass a UUID to change the account's commodity,
//          or omit (null) to leave the existing commodity unchanged.
// ============================================================
// Last edited: 2026-04-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.util.UUID;

/**
 * Partial update request for an existing account.
 * <p>
 * Implements JSON Merge Patch semantics (RFC 7396): only non-null fields
 * are applied. All fields are optional — send only what you want to change.
 * <p>
 * All updates respect Row-Level Security (RLS) and are scoped to the
 * authenticated owner via {@code TenantContext.withOwner()}.
 *
 * @param name            New account name. {@code null} = keep existing.
 * @param code            New account code. {@code null} = keep existing.
 * @param parentId        New parent UUID. {@code null} = keep existing.
 * @param accountTypeCode New account type code. {@code null} = keep existing.
 * @param accountRole     New operational role. {@code null} = keep existing.
 * @param isPlaceholder   New placeholder flag. {@code null} = keep existing.
 * @param isHidden        New hidden flag. {@code null} = keep existing.
 * @param commodityId     New commodity UUID. {@code null} = keep existing.
 */
public record PatchAccountRequest(
        String  name,
        String  code,
        UUID    parentId,
        String  accountTypeCode,
        Integer accountRole,
        Boolean isPlaceholder,
        Boolean isHidden,
        UUID    commodityId      // nullable — null means no change
) {}
