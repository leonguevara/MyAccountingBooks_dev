# Posting Engine Design Specification

**Last updated:** 2026-03-01  
**Implemented in:** `000_MyAccountingBooks_CreateFromScratch_v2.psql`

---

## Goals

- Enforce double-entry accounting invariants at write-time, in the database.
- Prevent cross-ledger corruption.
- Support memo-only postings without affecting real balances.
- Use **rational values** (`value_num` / `value_denom`) as the authoritative monetary representation.
- Provide safe transaction reversal and voiding semantics.

---

## Canonical Value Model

| Field                           | Role                      |
|---------------------------------|---------------------------|
| `value_num` / `value_denom`     | **Authoritative** monetary value |
| `quantity_num` / `quantity_denom` | Unit quantities (commodity amounts) |
| `amount` (generated column)     | Presentation only: `ABS(value_num) / value_denom` |

`amount` is a PostgreSQL stored generated column. It is **never inserted** — it is always derived. Do not use it for balance computations.

---

## Core API (SQL Functions)

### `mab_post_transaction(p_ledger_id, p_splits, ...)`

Posts a balanced double-entry transaction.

```sql
SELECT mab_post_transaction(
    p_ledger_id             => '<ledger-uuid>',
    p_splits                => '[
        {"account_id": "<uuid>", "side": 0, "value_num": 10000, "value_denom": 100, "memo": "debit leg"},
        {"account_id": "<uuid>", "side": 1, "value_num": 10000, "value_denom": 100, "memo": "credit leg"}
    ]'::jsonb,
    p_post_date             => now(),
    p_enter_date            => now(),
    p_memo                  => 'Monthly rent',
    p_currency_commodity_id => '<commodity-uuid>'
);
```

Returns: `transaction.id` (uuid)

**Split JSON fields:**

| Field           | Type    | Required | Description                               |
|-----------------|---------|----------|-------------------------------------------|
| `account_id`    | text    | Yes      | UUID of the target account                |
| `side`          | integer | Yes      | `0` = DEBIT, `1` = CREDIT                |
| `value_num`     | bigint  | Yes      | Numerator (positive integer)              |
| `value_denom`   | integer | Yes      | Denominator (e.g. 100 for centavos)       |
| `quantity_num`  | bigint  | No       | Commodity quantity numerator              |
| `quantity_denom`| integer | No       | Commodity quantity denominator            |
| `memo`          | text    | No       | Line-item memo                            |
| `action`        | text    | No       | Action label                              |

---

### `mab_reverse_transaction(p_tx_id, p_post_date, p_enter_date, p_memo)`

Creates a mirror transaction with all split sides flipped (DEBIT↔CREDIT). Marks the original with `reversed_by_tx_id`.

```sql
SELECT mab_reverse_transaction(
    p_tx_id     => '<original-tx-uuid>',
    p_post_date => now(),
    p_memo      => 'Reversal — wrong account'
);
```

Guards: cannot reverse a voided, deleted, or already-reversed transaction.

---

### `mab_void_transaction(p_tx_id, p_reason)`

Marks a transaction as voided. Sets `is_voided = true` and `voided_at = now()`. Appends `[VOID: reason]` to memo.

```sql
SELECT mab_void_transaction(
    p_tx_id  => '<tx-uuid>',
    p_reason => 'Duplicate entry'
);
```

Guards: cannot void an already-voided transaction.

---

## Validation Steps (inside `mab_post_transaction`)

**Step 1 — Concurrency lock**  
`pg_advisory_xact_lock(hashtext(p_ledger_id))` — prevents concurrent postings to the same ledger from interleaving.

**Step 2 — Basic guards**  
- `ledger_id` is not null  
- `currency_commodity_id` is not null  
- `splits` is a non-empty JSON array

**Step 3 — Stage splits**  
Parsed into a temp table (`_mab_stg_splits`) via `jsonb_to_recordset()`.

**Step 4 — Staging row validation**  
- All rows have `account_id`  
- `side` ∈ {0, 1}  
- `value_denom > 0`, `quantity_denom > 0`  
- All splits share the same `value_denom` (single precision per transaction)

**Step 5 — Account validation**  
- All `account_id` values exist  
- All accounts belong to `p_ledger_id`  
- No placeholder accounts (`is_placeholder = false`)  
- No deleted accounts (`deleted_at IS NULL`)

**Step 6 — Memo / real account separation**  
Accounts with `account_type.code IN ('MEM_DEBIT', 'MEM_CREDIT')` are memo accounts.

- Memo and non-memo accounts cannot be mixed in a single transaction.
- Memo-only transactions must include at least one `MEM_DEBIT` and one `MEM_CREDIT` account.

**Step 7 — Balance check**  
```
SUM(value_num WHERE side = 0) - SUM(value_num WHERE side = 1) = 0
```

**Step 8 — Insert transaction header**  
INSERT into `transaction` returning `id`.

**Step 9 — Bulk insert splits**  
INSERT all splits from staging. `amount` is auto-generated; it is not supplied.

---

## Core Invariants

| # | Invariant                                                         |
|---|-------------------------------------------------------------------|
| 1 | All splits belong to the same ledger as the transaction           |
| 2 | No posting to placeholder or deleted accounts                     |
| 3 | Real account transactions must balance to zero (by `value_num`)   |
| 4 | Memo accounts must balance internally                             |
| 5 | Memo and real accounts cannot be mixed in one transaction         |
| 6 | All splits in a transaction share the same `value_denom`          |
| 7 | A transaction cannot be reversed twice                            |
| 8 | A voided transaction cannot be reversed                           |
| 9 | `voided_at IS NOT NULL` iff `is_voided = true` (CHECK constraint) |
| 10| A transaction cannot reference itself as its own reversal         |

---

## Concurrency Model

Per-ledger advisory lock:

```sql
SELECT pg_advisory_xact_lock(hashtext(p_ledger_id::text));
```

This serializes all postings within a single ledger, preventing race conditions from multi-device writes. The lock is automatically released at transaction commit/rollback.

---

## Void vs Reversal

| Operation  | Mechanism                                      | When to use                         |
|------------|------------------------------------------------|-------------------------------------|
| **Void**   | `is_voided = true`, `voided_at = now()`        | Exclude from all reporting; no new transaction created |
| **Reversal** | New balanced transaction with flipped sides | Preferred for audit trails; original remains visible |

Voided transactions are excluded from reporting queries. Reversed transactions remain visible with the reversal linked via `reversed_by_tx_id`.

---

## Performance Notes

All hot-path indexes are partial (`WHERE deleted_at IS NULL`):

- `idx_split_transaction_id` — join from transaction to splits
- `idx_split_account_id` — account balance queries
- `idx_transaction_ledger_postdate` — ledger register by date
- `idx_transaction_ledger_id` — all transactions per ledger
- `idx_transaction_reversed_by` — reversal lookup

---

## Audit Trail

Every INSERT / UPDATE / DELETE on `transaction`, `split`, `ledger`, `account`, `payee`, `scheduled_transaction`, and `scheduled_split` is captured by `trg_audit` → `mab_audit_trigger()`. The trigger runs `SECURITY DEFINER` and can always write to `audit_log` regardless of calling role privileges.

The `audit_log` table is append-only: `UPDATE` and `DELETE` are revoked from all application roles.
