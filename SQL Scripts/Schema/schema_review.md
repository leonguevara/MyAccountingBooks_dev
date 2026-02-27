# Schema Review: `myaccounting_dev_schema_clean.sql`
**Reviewed by:** Senior Full-Stack / PostgreSQL Architect  
**PostgreSQL version detected:** 18.1 (pg_dump header)  
**Review date:** 2026-02-27

---

## Executive Summary

This is a **well-structured, production-grade double-entry bookkeeping schema** with clear GnuCash-lineage design decisions. The rational number representation for monetary values (`value_num / value_denom`) is architecturally correct. The stored procedure layer is mature, with proper concurrency control via advisory locks. Overall quality is **high**. The findings below are ordered by severity.

---

## 1. Critical Issues

### 1.1 Duplicate Unique Index on `commodity`
```sql
CREATE UNIQUE INDEX commodity_namespace_mnemonic_uq ON public.commodity(namespace, mnemonic);
CREATE UNIQUE INDEX commodity_namespace_mnemonic_ux ON public.commodity(namespace, mnemonic) WHERE (deleted_at IS NULL);
```
**Problem:** Two separate unique indexes on the same columns. The unconditional `_uq` index makes the partial `_ux` index redundant AND creates a conflict: a soft-deleted commodity with the same `(namespace, mnemonic)` cannot be re-created because `_uq` blocks it globally.

**Fix:** Drop the unconditional index. Keep only the partial one:
```sql
DROP INDEX IF EXISTS public.commodity_namespace_mnemonic_uq;
-- Keep: commodity_namespace_mnemonic_ux WHERE (deleted_at IS NULL)
```

---

### 1.2 `ledger.currency_commodity_id` is NULLABLE but semantically required
```sql
currency_commodity_id uuid,  -- no NOT NULL
```
**Problem:** A ledger without a currency is functionally broken. The FK is `ON DELETE SET NULL`, which means deleting a commodity silently orphans all ledgers. A ledger with `currency_commodity_id = NULL` will pass validation but fail at posting time.

**Fix:**
```sql
-- Make it NOT NULL
ALTER TABLE public.ledger ALTER COLUMN currency_commodity_id SET NOT NULL;
-- Change FK to RESTRICT instead of SET NULL
ALTER TABLE public.ledger DROP CONSTRAINT ledger_currency_commodity_id_fkey;
ALTER TABLE public.ledger ADD CONSTRAINT ledger_currency_commodity_id_fkey
  FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE RESTRICT;
```

---

### 1.3 `transaction.currency_commodity_id` is NULLABLE
Same issue as above. A transaction posted to a ledger must have a currency. The `mab_post_transaction` function accepts it as optional (`DEFAULT NULL`), which means the column can be NULL in production data.

**Fix:** Either enforce NOT NULL at the column level or add a NOT NULL constraint enforced inside `mab_post_transaction` before insert. The function-level check is preferred given the current architecture:
```sql
PERFORM mab__assert(p_currency_commodity_id IS NOT NULL, 'currency_commodity_id is required');
```

---

## 2. Design Concerns (Medium Severity)

### 2.1 `split.amount` is a Derived Redundant Column
```sql
amount numeric(38,10) DEFAULT 0.0 NOT NULL,
-- computed in mab_post_transaction as:
-- (ABS(s.value_num)::numeric / NULLIF(s.value_denom, 0))::numeric(38,10)
```
**Problem:** `amount` is derived from `value_num / value_denom`. Storing it creates a denormalization risk — if `value_num` or `value_denom` is ever updated outside the stored procedure, `amount` becomes stale. The `numeric(38,10)` precision is also overkill for a display value.

**Recommendation:** Either:
- Remove `amount` and use a generated column: `amount numeric(38,10) GENERATED ALWAYS AS (ABS(value_num::numeric) / NULLIF(value_denom, 0)) STORED`
- Or keep it but add a trigger to enforce consistency.

---

### 2.2 `ledger` Has Both `currency_code TEXT` and `currency_commodity_id UUID`
```sql
currency_code text DEFAULT 'MXN'::text NOT NULL,
currency_commodity_id uuid,
```
**Problem:** Two representations of the same thing. `currency_code` is a denormalized text copy of `commodity.mnemonic`. If they ever diverge, the ledger is in an inconsistent state. `currency_code` is not referenced by any FK or constraint linking it back to `commodity`.

**Fix:** Remove `currency_code` from `ledger`. Derive it at query time via JOIN to `commodity`. If performance is a concern, use a view:
```sql
CREATE VIEW v_ledger AS
  SELECT l.*, c.mnemonic AS currency_code
  FROM ledger l
  JOIN commodity c ON c.id = l.currency_commodity_id;
```

---

### 2.3 `account.commodity_scu` vs `commodity.fraction` Mismatch Risk
In `create_ledger_with_optional_template`:
```sql
LEAST((SELECT c.fraction FROM public.commodity c WHERE c.id = v_currency_id)::bigint, 2147483647)::int
```
But in `instantiate_coa_template`:
```sql
commodity_scu: 100  -- hardcoded
```
And in `instantiate_coa_template_to_ledger`:
```sql
commodity_scu: 100  -- also hardcoded
```
**Problem:** The three instantiation functions use inconsistent SCU logic. Two of them hardcode `100` while the primary function uses the commodity's actual fraction. This means accounts created via the older functions may have wrong precision for non-standard currencies (e.g., JPY with fraction=1, BHD with fraction=1000).

**Fix:** Centralize SCU resolution into a single function or macro, and use it consistently across all three instantiation paths.

---

### 2.4 `split` CHECK Constraints Block Negative Adjustments
```sql
CONSTRAINT chk_split_value CHECK ((value_num >= 0)),
CONSTRAINT chk_split_amount CHECK ((amount >= (0)::numeric)),
CONSTRAINT chk_split_quantity CHECK ((quantity_num >= 0))
```
**Problem:** All values are forced non-negative, with direction encoded via `side` (0=DEBIT, 1=CREDIT). This is a valid design choice, BUT it means corrections and adjustments that naturally have negative components cannot be expressed directly — they require reversals. This is consistent with GnuCash's model but may be limiting if you want to support journal entry corrections or fractional rounding entries natively.

**Recommendation:** Document this constraint explicitly as an architectural decision. If partial negative adjustments are ever needed, this will require a schema migration.

---

### 2.5 `recurrence.period_type` and `recurrence.weekend_adjust` Are Unvalidated TEXT
```sql
period_type text,
weekend_adjust text DEFAULT 'none'::text NOT NULL,
```
**Problem:** These are effectively enums stored as free text. Any string can be inserted. Typos (`'mounthly'`, `'weeknd'`) will cause silent failures in scheduling logic.

**Fix:** Either use PostgreSQL native `ENUM` types or add CHECK constraints:
```sql
CONSTRAINT chk_recurrence_period_type CHECK (period_type IN ('daily','weekly','monthly','yearly') OR period_type IS NULL),
CONSTRAINT chk_recurrence_weekend_adjust CHECK (weekend_adjust IN ('none','forward','back','nearest'))
```

---

### 2.6 `coa_template` Missing `deleted_at` / Soft-Delete
```sql
-- coa_template has no deleted_at column
```
**Problem:** Every other major table supports soft delete, but `coa_template` does not. A template in use by active ledgers could be hard-deleted, breaking `ledger.coa_template_id` FK (which is `ON DELETE SET NULL`).

**Fix:** Add `deleted_at timestamp with time zone` to `coa_template` and filter active templates with `WHERE is_active = TRUE AND deleted_at IS NULL`.

---

## 3. Missing Indexes (Performance)

| Table | Missing Index | Reason |
|---|---|---|
| `split` | `(transaction_id)` | Most frequent join; no index exists |
| `split` | `(account_id)` | Account balance queries scan this constantly |
| `transaction` | `(ledger_id, post_date DESC)` | Ledger register queries always filter+sort by these |
| `transaction` | `(ledger_id)` WHERE `deleted_at IS NULL` | Soft-delete filter on high-volume table |
| `account` | `(ledger_id)` | Account tree lookups |
| `account` | `(parent_id)` | Tree traversal (children of a node) |
| `payee` | `(ledger_id)` | Payee lookups scoped to ledger |
| `scheduled_transaction` | `(ledger_id)` | Scheduler queries by ledger |
| `price` | `(commodity_id, date DESC)` | Price history lookups |
| `auth_identity` | `(ledger_owner_id)` | Login flow joins |

**Recommended additions:**
```sql
CREATE INDEX idx_split_transaction_id ON public.split(transaction_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_split_account_id ON public.split(account_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_transaction_ledger_postdate ON public.transaction(ledger_id, post_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_account_ledger_id ON public.account(ledger_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_account_parent_id ON public.account(parent_id) WHERE parent_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_price_commodity_date ON public.price(commodity_id, date DESC) WHERE deleted_at IS NULL;
```

---

## 4. Naming & Convention Notes (Low Severity)

| Issue | Location | Recommendation |
|---|---|---|
| Mixed constraint naming: `ledger_owner_id_not_null1` | `ledger.owner_id` | Rename to `ledger_owner_id_nn` or just use `NOT NULL` directly — this is a column constraint, not a named one |
| `transaction` is a **PostgreSQL reserved word** | Table name | Works but may cause issues in some ORM contexts. Consider `txn`, `financial_transaction`, or quoting always |
| `precision` is a **PostgreSQL reserved word** | `ledger.precision` | Always requires quoting. Rename to `decimal_places` or `currency_precision` |
| `_stg_` temp table naming not consistent | Functions | `_stg_new_accounts`, `_node_to_account`, `tmp_coa_map`, `_mab_stg_splits` — standardize to one prefix |
| `instantiate_coa_template` vs `instantiate_coa_template_to_ledger` | Functions | Two functions do nearly identical work with different signatures. Consider consolidating into one. |

---

## 5. Audit & Temporal Design — Assessment

| Feature | Status | Notes |
|---|---|---|
| `created_at` | ✅ All tables | Consistent |
| `updated_at` | ✅ All tables | Consistent |
| `deleted_at` (soft delete) | ✅ Most tables | Missing on `coa_template` and `coa_template_node` |
| `revision` (optimistic locking) | ✅ All major tables | Well implemented |
| `is_voided` on transaction | ✅ | Good — separate from soft delete |
| Full audit log table | ❌ Not present | Consider adding `audit_log` for compliance |

---

## 6. Multi-Currency Assessment

| Aspect | Status | Notes |
|---|---|---|
| Rational number storage (`value_num` / `value_denom`) | ✅ Excellent | Avoids floating-point errors entirely |
| `commodity` table for currencies + assets | ✅ Correct | Proper GnuCash-style commodity model |
| `price` table for exchange rates | ✅ Present | Supports historical pricing |
| ISO-4217 enforcement | ⚠️ Partial | `namespace = 'CURRENCY'` convention exists but no CHECK constraint enforces valid ISO codes on `mnemonic` |
| Single denominator per transaction enforced | ✅ In `mab_post_transaction` | Prevents mixed-precision splits |

---

## 7. Stored Function Review Summary

| Function | Assessment |
|---|---|
| `mab_post_transaction` | ✅ Solid. Advisory lock, staging table, balance validation, bulk insert. Missing: NULL check on `currency_commodity_id`. |
| `mab_void_transaction` | ✅ Clean. Advisory lock. Consider recording voided_at timestamp. |
| `mab_reverse_transaction` | ✅ Good. Side-flip logic is correct. Does not mark source as reversed — consider adding `reversed_by_tx_id uuid` to `transaction`. |
| `create_ledger_with_optional_template` | ⚠️ Complex. Uses RETURNING without capturing full result set. Staging table join could fail if `code` is not unique within ledger pre-insert. |
| `instantiate_coa_template` | ⚠️ Older version — hardcoded SCU=100. Should be deprecated in favor of `instantiate_coa_template_to_ledger`. |
| `instantiate_coa_template_to_ledger` | ✅ Best version. Has guards, validates root, validates type codes, uses WITH...RETURNING for atomic mapping. |
| `mab__assert` | ✅ Clean utility. Correct use of `ERRCODE = 'P0001'`. |

---

## 8. Cloud Deployment Readiness

| Concern | Status | Recommendation |
|---|---|---|
| `pgcrypto` extension | ✅ Used for `gen_random_uuid()` | In PG 13+ prefer `gen_random_uuid()` built-in (no extension needed) |
| `pg_advisory_xact_lock` | ✅ Correct scope (transaction-scoped) | Will work on RDS/Cloud SQL but verify max lock limits |
| Temp tables `ON COMMIT DROP` | ✅ Correct | Safe for connection-pooled environments |
| Row-level security (RLS) | ❌ Not implemented | For multi-tenant SaaS: add RLS policies on `ledger`, `account`, `transaction`, `split` scoped by `owner_id` |
| Schema migrations | ❌ No migration tooling evident | Adopt Flyway or Liquibase before deploying to cloud environments |
| Connection pooling compatibility | ✅ Advisory locks are xact-scoped | Safe with PgBouncer in transaction mode |

---

## 9. Priority Action List

| Priority | Action |
|---|---|
| 🔴 P1 | Remove duplicate `commodity_namespace_mnemonic_uq` index |
| 🔴 P1 | Add `NOT NULL` to `ledger.currency_commodity_id` |
| 🔴 P1 | Add `currency_commodity_id IS NOT NULL` assert in `mab_post_transaction` |
| 🟠 P2 | Add missing indexes on `split`, `transaction`, `account` |
| 🟠 P2 | Remove `ledger.currency_code` text column (redundant with FK) |
| 🟠 P2 | Convert `split.amount` to a `GENERATED ALWAYS AS` computed column |
| 🟠 P2 | Add `deleted_at` to `coa_template` |
| 🟡 P3 | Add CHECK constraints on `recurrence.period_type` and `weekend_adjust` |
| 🟡 P3 | Standardize SCU resolution across all three instantiation functions |
| 🟡 P3 | Rename `ledger.precision` → `decimal_places` |
| 🟡 P3 | Deprecate `instantiate_coa_template` (older version) |
| 🔵 P4 | Add Row-Level Security policies for multi-tenant cloud deployment |
| 🔵 P4 | Add `reversed_by_tx_id` to `transaction` for reversal traceability |
| 🔵 P4 | Introduce Flyway/Liquibase migration versioning |
