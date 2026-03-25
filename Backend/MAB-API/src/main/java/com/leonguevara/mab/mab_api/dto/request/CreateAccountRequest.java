// ============================================================
// CreateAccountRequest.java
// Package: com.leonguevara.mab.mab_api.dto.request
//
// Purpose: Represents the JSON body of a POST /accounts request.
//
//          Maps to the parameters of the PostgreSQL function:
//            mab_create_account(
//              p_ledger_id,          -- from request
//              p_name,               -- from request
//              p_code,               -- from request (nullable)
//              p_parent_id,          -- from request
//              p_account_type_code,  -- from request (nullable for placeholders)
//              p_account_role,       -- from request (default: 0)
//              p_is_placeholder,     -- from request (default: false)
//              p_is_hidden           -- from request (default: false)
//            )
//
//          Note: Owner authentication is enforced via TenantContext
//          and Row-Level Security (RLS), not via explicit parameters.
//
//          Account hierarchy:
//            - All accounts (except root) must have a parent
//            - Root accounts are created automatically when a ledger
//              is instantiated from a Chart of Accounts template
//            - Parent must belong to the same ledger
//
//          Account classification (three orthogonal dimensions):
//            1. kind (implicit via parent) — Asset/Liability/Equity/Revenue/Expense
//            2. accountTypeCode — BANK/CASH/RECEIVABLE/PAYABLE/EQUITY/etc.
//            3. accountRole — bitmask: 0=Normal, 1=Control, 2=Tax, 4=Memo
//
//          Placeholder accounts:
//            - Grouping-only nodes (cannot hold transactions)
//            - Do not require accountTypeCode
//            - Non-placeholder accounts MUST have accountTypeCode
// ============================================================
// Last edited: 2026-03-25
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.request;

import java.util.UUID;

/**
 * Request DTO for creating a new account in a ledger.
 * <p>
 * Accounts in MyAccountingBooks are arranged in a strict hierarchy (tree) where every
 * account except the root must have a parent. The root account is created automatically
 * when a ledger is instantiated from a Chart of Accounts template.
 * <p>
 * <strong>Account Classification:</strong> Uses three orthogonal dimensions:
 * <ul>
 *   <li><strong>kind</strong> (implicit via parent): Accounting nature (Asset, Liability, Equity, Revenue, Expense)</li>
 *   <li><strong>accountTypeCode</strong>: Functional classification (BANK, CASH, AP, AR, EQUITY, etc.)</li>
 *   <li><strong>accountRole</strong>: Operational role bitmask (Control, Tax, Memo)</li>
 * </ul>
 * <p>
 * <strong>Placeholder Accounts:</strong> Grouping-only nodes (cannot hold transactions).
 * Placeholders do not require an {@code accountTypeCode}. Non-placeholder (posting) accounts
 * must have a valid {@code accountTypeCode} foreign key referencing {@code account_type.code}.
 * <p>
 * All validation and insertion logic is enforced by the database layer via the
 * {@code mab_create_account()} stored function, which respects Row-Level Security (RLS)
 * and ensures the parent account belongs to the same ledger.
 *
 * @param ledgerId        Target ledger UUID. Required.
 * @param name            Human-readable account name. Required.
 * @param code            Optional account code (e.g., "1000", "2110"). Used for sorting and reporting.
 * @param parentId        Parent account UUID. Required; all accounts except root must have a parent.
 * @param accountTypeCode FK to {@code account_type.code} (e.g., "BANK", "CASH", "EQUITY").
 *                        Required for non-placeholder accounts. Null for placeholders.
 * @param accountRole     Operational role bitmask (0 = Normal, 1 = Control, 2 = Tax, 4 = Memo). Defaults to 0.
 * @param isPlaceholder   {@code true} if this account is grouping-only (cannot post transactions). Defaults to {@code false}.
 * @param isHidden        {@code true} to hide this account from default views. Defaults to {@code false}.
 */
public record CreateAccountRequest(
        UUID    ledgerId,
        String  name,
        String  code,
        UUID    parentId,
        String  accountTypeCode,
        int     accountRole,
        boolean isPlaceholder,
        boolean isHidden
) {}