// ============================================================
// AccountTypeResponse.java
// Package: com.leonguevara.mab.mab_api.dto.response
//
// Purpose: JSON representation of a single account_type catalog entry.
//
//          Account types define the functional classification of accounts,
//          one of three orthogonal dimensions in MyAccountingBooks:
//            1. kind — accounting nature (Asset, Liability, etc.)
//            2. account_type — functional classification (this record)
//            3. accountRole — operational role (Control, Tax, Memo)
//
//          Account types are system-wide (not tenant-scoped) and seeded
//          during schema bootstrap via 002_Populating_account_type.pgsql.
//
//          They are referenced by:
//            - account.account_type_code (FK to account_type.code)
//            - coa_template_node.account_type_code
//
//          Examples: BANK, CASH, RECEIVABLE, PAYABLE, EQUITY, STOCK
//
//          kind: determines accounting nature:
//            1 = Asset
//            2 = Liability
//            3 = Equity
//            4 = Revenue
//            5 = Gain/Loss
//            6 = Expense
//
//          normalBalance: debit/credit convention:
//            0 = Debit (Assets, Expenses)
//            1 = Credit (Liabilities, Equity, Revenue)
//
//          sortOrder: display order hint within kind group.
// ============================================================
// Last edited: 2026-03-25
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.dto.response;

import java.util.UUID;

/**
 * Response DTO representing a single entry from the {@code account_type} catalog.
 * <p>
 * The {@code account_type} table defines the functional classification of accounts,
 * which is one of three orthogonal dimensions used to categorize accounts in MyAccountingBooks:
 * <ul>
 *   <li><strong>kind</strong>: Accounting nature (Asset, Liability, Equity, Revenue, Expense, Gain/Loss)</li>
 *   <li><strong>account_type</strong>: Functional classification (this record)</li>
 *   <li><strong>accountRole</strong>: Operational role (Control, Tax, Memo)</li>
 * </ul>
 * <p>
 * Account types are predefined in the database and seeded during schema bootstrap
 * (see {@code 002_Populating_account_type.pgsql}). They are system-wide and not
 * tenant-scoped. Examples include BANK, CASH, RECEIVABLE, PAYABLE, EQUITY, STOCK, etc.
 * <p>
 * The {@code code} field is the stable identifier used in Chart of Accounts (COA)
 * templates and API requests. The {@code kind} and {@code normalBalance} fields
 * determine the accounting behavior of accounts assigned this type.
 *
 * @param id            UUID primary key. Immutable.
 * @param code          Stable functional code (e.g., "CASH", "BANK", "RECEIVABLE", "EQUITY").
 *                      Used as a foreign key in {@code account.account_type_code}.
 * @param name          Human-readable display name (e.g., "Cash", "Bank Account", "Accounts Receivable").
 * @param kind          Accounting kind enumeration:
 *                      <ul>
 *                        <li>1 = Asset</li>
 *                        <li>2 = Liability</li>
 *                        <li>3 = Equity</li>
 *                        <li>4 = Revenue</li>
 *                        <li>5 = Gain/Loss</li>
 *                        <li>6 = Expense</li>
 *                      </ul>
 * @param normalBalance Normal balance convention:
 *                      <ul>
 *                        <li>0 = Debit (Assets, Expenses)</li>
 *                        <li>1 = Credit (Liabilities, Equity, Revenue)</li>
 *                      </ul>
 * @param sortOrder     Display order hint for sorting within the same {@code kind} group.
 *                      Lower values appear first in UI lists.
 */
public record AccountTypeResponse(
        UUID   id,
        String code,
        String name,
        int    kind,
        int    normalBalance,
        int    sortOrder
) {}