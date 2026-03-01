# Schema Object Inventory

Generated from: `myaccounting_dev_schema_clean_v20260301.psql`  
Last updated: 2026-03-01

---

## Tables (17)

| Table                    | RLS | Soft-Delete | Audit Trigger |
|--------------------------|-----|-------------|---------------|
| `public.account`         | ✅  | ✅          | ✅            |
| `public.account_type`    | ❌  | ✅          | ❌            |
| `public.audit_log`       | ❌  | ❌          | —             |
| `public.auth_identity`   | ❌  | ✅          | ❌            |
| `public.coa_template`    | ❌  | ✅          | ❌            |
| `public.coa_template_node` | ❌ | ❌         | ❌            |
| `public.commodity`       | ❌  | ✅          | ❌            |
| `public.enum_label`      | ❌  | ❌          | ❌            |
| `public.ledger`          | ✅  | ✅          | ✅            |
| `public.ledger_owner`    | ❌  | ✅          | ❌            |
| `public.payee`           | ✅  | ✅          | ✅            |
| `public.price`           | ❌  | ✅          | ❌            |
| `public.recurrence`      | ❌  | ✅          | ❌            |
| `public.scheduled_split` | ❌  | ✅          | ✅            |
| `public.scheduled_transaction` | ✅ | ✅       | ✅            |
| `public.split`           | ✅  | ✅          | ✅            |
| `public.transaction`     | ✅  | ✅          | ✅            |

---

## Views (3)

| View                          | Purpose                                                         |
|-------------------------------|-----------------------------------------------------------------|
| `public.v_ledger`             | Adds `currency_code` (from `commodity.mnemonic`) to ledger rows |
| `public.v_ledger_owner_redacted` | Excludes `password_hash`; safe for reporting roles           |
| `public.v_role_password_age`  | Monitors `mab_*` role credential expiry                        |

---

## Functions (7)

| Function                                          | Returns   | Purpose                                          |
|---------------------------------------------------|-----------|--------------------------------------------------|
| `mab__assert(boolean, text)`                      | `void`    | Lightweight assertion helper used internally     |
| `mab_current_owner_id()`                          | `uuid`    | Returns owner UUID from `app.current_owner_id` session var |
| `mab_audit_trigger()`                             | `trigger` | Appends rows to `audit_log` (SECURITY DEFINER)   |
| `mab_post_transaction(uuid, jsonb, ...)`          | `uuid`    | Posts a balanced double-entry transaction        |
| `mab_void_transaction(uuid, text)`                | `void`    | Voids a transaction (sets `is_voided`, `voided_at`) |
| `mab_reverse_transaction(uuid, ...)`              | `uuid`    | Creates a reversed mirror transaction            |
| `instantiate_coa_template_to_ledger(uuid, uuid)` | `uuid`    | Materializes a COA template into a ledger's account tree |
| `instantiate_coa_template(uuid, uuid)`            | `void`    | **DEPRECATED** — raises exception directing to replacement |
| `create_ledger_with_optional_template(uuid, ...)` | `TABLE`   | Creates a ledger and optionally instantiates a COA template |

---

## Triggers (7)

All `trg_audit` triggers call `mab_audit_trigger()` (AFTER INSERT OR UPDATE OR DELETE, FOR EACH ROW):

- `public.account`
- `public.ledger`
- `public.payee`
- `public.scheduled_split`
- `public.scheduled_transaction`
- `public.split`
- `public.transaction`

---

## Indexes (18)

| Index Name                                  | Table                  | Type          | Notes                                     |
|---------------------------------------------|------------------------|---------------|-------------------------------------------|
| `commodity_namespace_mnemonic_ux`           | `commodity`            | UNIQUE partial | `WHERE deleted_at IS NULL`               |
| `idx_account_ledger_code_ux`               | `account`              | UNIQUE partial | `WHERE code IS NOT NULL AND deleted_at IS NULL` |
| `idx_account_ledger_id`                    | `account`              | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_account_parent_id`                    | `account`              | B-tree partial | `WHERE parent_id IS NOT NULL AND deleted_at IS NULL` |
| `idx_audit_log_occurred_at`               | `audit_log`            | B-tree        | `occurred_at DESC`                        |
| `idx_audit_log_owner`                     | `audit_log`            | B-tree        | `(owner_id, occurred_at DESC)`            |
| `idx_audit_log_table_row`                 | `audit_log`            | B-tree        | `(table_name, row_id)`                    |
| `idx_auth_identity_owner_id`              | `auth_identity`        | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_coa_node_template_typecode`          | `coa_template_node`    | B-tree        | `(template_id, account_type_code)`        |
| `idx_coa_template_one_root_per_template_ux` | `coa_template_node`  | UNIQUE partial | `WHERE parent_code IS NULL` — enforces single root per template |
| `idx_payee_ledger_id`                     | `payee`                | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_price_commodity_date`                | `price`                | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_scheduled_transaction_ledger_id`     | `scheduled_transaction`| B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_split_account_id`                    | `split`                | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_split_transaction_id`                | `split`                | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_transaction_ledger_id`               | `transaction`          | B-tree partial | `WHERE deleted_at IS NULL`               |
| `idx_transaction_ledger_postdate`         | `transaction`          | B-tree partial | `(ledger_id, post_date DESC) WHERE deleted_at IS NULL` |
| `idx_transaction_reversed_by`             | `transaction`          | B-tree partial | `WHERE reversed_by_tx_id IS NOT NULL`    |

---

## RLS Policies (6)

| Policy                           | Table                    | Condition                                    |
|----------------------------------|--------------------------|----------------------------------------------|
| `rls_ledger_owner`              | `ledger`                 | `owner_id = mab_current_owner_id()`          |
| `rls_account_owner`             | `account`                | `ledger_id` in owner's ledgers               |
| `rls_transaction_owner`         | `transaction`            | `ledger_id` in owner's ledgers               |
| `rls_split_owner`               | `split`                  | `account_id` in owner's accounts             |
| `rls_payee_owner`               | `payee`                  | `ledger_id` in owner's ledgers               |
| `rls_scheduled_transaction_owner` | `scheduled_transaction` | `ledger_id` in owner's ledgers               |

---

## Database Roles (4)

| Role           | Login | BYPASSRLS | Purpose                      |
|----------------|-------|-----------|------------------------------|
| `mab_owner`    | Yes   | Yes       | DDL, migrations              |
| `mab_app`      | Yes   | No        | Runtime application DML      |
| `mab_readonly` | Yes   | No        | Reporting / BI               |
| `mab_auditor`  | Yes   | No        | `audit_log` SELECT only      |
