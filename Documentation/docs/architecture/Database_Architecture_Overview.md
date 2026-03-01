# Database Architecture Overview

**Last updated:** 2026-03-01  
**Schema version:** v2 (from `000_MyAccountingBooks_CreateFromScratch_v2.psql`)

---

## Scope

This document describes the current PostgreSQL schema for MyAccountingBooks: table design, integrity model, security posture, and key design decisions.

---

## Architectural Goal

MyAccountingBooks is a **cross-platform accounting engine**, not just a CRUD application. The database is the system of record — accounting correctness is enforced in SQL, not in application code.

| Layer             | Technology                            |
|-------------------|---------------------------------------|
| Apple platforms   | Swift / SwiftUI (macOS, iOS, watchOS) |
| Android / Desktop | Java / Kotlin                         |
| Backend API       | Java (Spring-style service layer)     |
| Persistence       | PostgreSQL (single source of truth)   |

CoreData serves as a **local cache / offline persistence layer** only.

---

## Multi-Tenant Model

The schema is SaaS-ready from day one:

```
ledger_owner  1──N  ledger  1──N  account
```

Each owner holds multiple ledgers. Each ledger is logically isolated via Row-Level Security (RLS). No redesign is required when scaling to thousands of users.

---

## Core Entities

### `ledger_owner`
Owner of one or more ledgers (individual or organization). Supports multiple authentication providers via `auth_identity`.

### `auth_identity`
Multiple login providers per `ledger_owner` (email/password, Google, Apple, GitHub). Implements account-linking without duplicating ownership.

### `ledger`
Top-level container for an accounting book. Binds an owner, a base currency commodity, a root account, and an optional COA template.

Key design decisions:
- `currency_commodity_id` is `NOT NULL` — a ledger always has a base currency.
- `root_account_id` is a deferred FK (circular dependency with `account`).
- `decimal_places` replaced `precision` (renamed in v3 to avoid SQL reserved word conflicts).
- `currency_code` was removed from `ledger`; it is now derived via the `v_ledger` view.

### `account`
Hierarchical chart of accounts within a ledger. Self-referential via `parent_id`. Supports soft-delete (`deleted_at`), placeholders (`is_placeholder`), and hidden accounts (`is_hidden`).

### `commodity`
Currencies, crypto, and other tradeable assets. Uses a `namespace` field (`CURRENCY`, `CRYPTO`, etc.) to separate asset classes. Uniqueness is enforced via a **partial unique index** on `(namespace, mnemonic) WHERE deleted_at IS NULL`.

### `account_type`
Catalog of account types (e.g. `CASH`, `AP`, `SALES`, `MEM_DEBIT`). Defines `kind`, `normal_balance`, and `sort_order`. Referenced by both `coa_template_node` and `account` to classify accounts for reporting and posting logic.

### `coa_template` / `coa_template_node`
Reusable, versioned account trees importable from Excel. A template is instantiated atomically into a ledger via `instantiate_coa_template_to_ledger()`. Each non-placeholder node must carry `account_type_code` (FK to `account_type.code`) so that instantiation can always populate `account.account_type_id`.

### `transaction`
Financial transaction header. Contains `post_date`, `enter_date`, `memo`, `currency_commodity_id`, optional `payee_id`, and soft-delete / void / reversal tracking fields.

### `split`
Line items implementing double-entry. Each split references an `account` and a `transaction`. The `amount` column is a **generated stored column** (`ABS(value_num) / value_denom`), always consistent with the rational values.

### `price`
Historical commodity prices in a reference currency. Used for multi-currency valuation.

### `payee`
Payees scoped to a ledger. Used on `transaction` headers.

### `scheduled_transaction` / `scheduled_split` / `recurrence`
Future and recurring transaction templates with recurrence patterns.

### `audit_log`
Append-only compliance trail for all INSERT / UPDATE / DELETE operations on core financial tables. Populated exclusively by `mab_audit_trigger()` (`SECURITY DEFINER`). No application role may UPDATE or DELETE rows.

### `enum_label`
Localized labels for enum values (e.g. `AccountKind`, `AccountRole`) by locale.

---

## Semantic Separation: Kind vs Type vs Role

A key conceptual design decision clarifies three distinct dimensions of account classification:

| Dimension    | Meaning                    | Example              |
|--------------|----------------------------|----------------------|
| `kind`       | Accounting nature          | Asset (1)            |
| `account_type` | Functional classification | Checking Account (`BANK`) |
| `role`       | Operational usage          | Control / Tax / Memo |

This enables correct reporting, regulatory mapping (SAT), flexible UI rendering, and future extension without schema changes.

---

## Exact Arithmetic Model

All monetary values use **rational arithmetic**:

```
value_num / value_denom
quantity_num / quantity_denom
```

The `amount` column on `split` is a derived presentation convenience (`ABS(value_num) / value_denom`), generated and stored by PostgreSQL. It is never used for accounting balances.

This prevents rounding drift, FX precision errors, and ledger imbalance.

---

## Hierarchy Rules (COA Template Nodes)

- `level = 0` → root node; `parent_code` must be `NULL`
- `level > 0` → `parent_code` references another node in the same template
- Exactly one root per template is enforced by a unique partial index on `(template_id) WHERE parent_code IS NULL`
- Non-placeholder nodes must have a valid `account_type_code`

---

## Integrity Model

- Splits must reference accounts within the same ledger as the transaction.
- Transactions cannot post to placeholder or soft-deleted accounts.
- Real (non-memo) transaction splits must balance to zero (enforced by `mab_post_transaction`).
- Memo transactions (`MEM_DEBIT` / `MEM_CREDIT`) must balance internally and cannot be mixed with real accounts.
- Advisory locks (`pg_advisory_xact_lock`) prevent concurrent posting corruption within a ledger.

---

## Security Model

### Row-Level Security (RLS)

RLS is enabled and forced on all tenant-scoped tables:

| Table                   | Policy                                                        |
|-------------------------|---------------------------------------------------------------|
| `ledger`                | `owner_id = mab_current_owner_id()`                          |
| `account`               | `ledger_id` in owner's ledgers                               |
| `transaction`           | `ledger_id` in owner's ledgers                               |
| `split`                 | `account_id` in owner's accounts                             |
| `payee`                 | `ledger_id` in owner's ledgers                               |
| `scheduled_transaction` | `ledger_id` in owner's ledgers                               |

Session identity is set via:
```sql
SET LOCAL app.current_owner_id = '<owner-uuid>';
```

### Database Roles

| Role           | Purpose                                         | RLS bypass |
|----------------|-------------------------------------------------|------------|
| `mab_owner`    | Migration runner, DDL                           | Yes        |
| `mab_app`      | Runtime application, DML only                  | No         |
| `mab_readonly` | Reporting / BI, SELECT only                    | No         |
| `mab_auditor`  | SELECT on `audit_log` only                     | No         |

`mab_readonly` cannot access `ledger_owner.password_hash` or `auth_identity` directly — only through `v_ledger_owner_redacted`.

---

## Views

| View                        | Purpose                                                     |
|-----------------------------|-------------------------------------------------------------|
| `v_ledger`                  | Adds `currency_code` (from `commodity.mnemonic`) to ledger  |
| `v_ledger_owner_redacted`   | Excludes `password_hash` for reporting roles                |
| `v_role_password_age`       | Monitors `mab_*` role credential expiry                     |

---

## Extensions

- `pgcrypto` — UUID generation (`gen_random_uuid()`)

---

## Current System Status

| Area                  | Status        |
|-----------------------|---------------|
| Data Model            | ✅ Stable      |
| COA Templates         | ✅ Operational |
| Excel Import Pipeline | ✅ Working     |
| ISO Currency Dataset  | ✅ Loadable    |
| Crypto Commodities    | ✅ Seeded      |
| RLS / Audit Log       | ✅ Implemented |
| Ledger Instantiation  | ✅ SQL-Based   |
| DDL Bootstrap         | ✅ Complete    |
| Posting Engine        | ✅ Implemented |
| Backend API           | 🔲 Future      |
