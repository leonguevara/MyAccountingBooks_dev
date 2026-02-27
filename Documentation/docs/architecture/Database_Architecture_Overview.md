# Database Architecture Overview

**Last updated:** 2026-02-27

## Scope

This document summarizes the current PostgreSQL schema used by MyAccountingBooks.

## Core Entities (Conceptual)

- **Ledger**: top-level container for an accounting book.
- **Account**: hierarchical chart of accounts within a ledger.
- **Transaction**: accounting event (posting header).
- **Split**: line items implementing double-entry.
- **Commodity**: currencies and other units (ISO 4217 + crypto).
- **COA Templates**: reusable account trees for instantiation into ledgers.  These include:
    - **coa_template**: header of the template.
    - **coa_template_node**: account nodes for the tamplate.

## Hierarchy Rules

- level = 0 → root node
- root nodes MUST have parent_code IS NULL
- level > 0 → parent_code references same-template node

Root is dynamically derived during Excel import.

## Integrity Model (High-level)

- Splits must reference existing accounts.
- Transactions and accounts must remain within the same ledger boundary (enforced in posting engine).
- Placeholders and soft-deleted records must not be posted to.
- Rational arithmetic is used for authoritative values (value_num/value_denom).

## Extensions

- Template-driven ledger creation.
- Posting engine functions enforce invariants in-database.
