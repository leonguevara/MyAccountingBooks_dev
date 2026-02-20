# 📌 Posting Engine — Schema-Aligned Design (v1)

We are designing this around your actual tables:

* `ledger`
* `account`
* `transaction`
* `split`
* `commodity`

---

## 1️⃣ Core Accounting Invariants (Based on Your Schema)

### A. Structural Integrity

From your schema:

* `account.ledger_id NOT NULL`
* `transaction.ledger_id NOT NULL`
* `split.account_id NOT NULL`
* `split.transaction_id NOT NULL`

Therefore:

#### Rule 1

All splits in a transaction must reference accounts belonging to the same ledger as the transaction.

Enforced by:

``` cpp
account.ledger_id = transaction.ledger_id
```

---

#### Rule 2

Cannot post to:

* `account.is_placeholder = true`
* `account.deleted_at IS NOT NULL`
* optionally `account.is_active = false`

---

### B. Double Entry Balance Rule

Your schema supports two value models:

| Field                       | Meaning                  |
| --------------------------- | ------------------------ |
| amount numeric(38,10)       | presentation convenience |
| value_num/value_denom       | rational value           |
| quantity_num/quantity_denom | units                    |

#### IMPORTANT DESIGN DECISION

For the engine we must choose:

### Source of truth for monetary balancing

Recommended:

> Use `value_num / value_denom` as canonical monetary value.

`amount` becomes derived or redundant for reporting.

---

### Balance Rule (Real Accounts)

For non-memo accounts:

``` sql
SUM(
   CASE side
        WHEN 0 THEN  value_num
        WHEN 1 THEN -value_num
   END
) = 0
```

Grouped per transaction.

---

### C. Memo Accounts (Kind 700 / 800)

You implemented:

* AccountKind includes memo range
* AccountRole differentiates finer roles

We will implement:

If transaction contains only memo accounts:

* must balance internally between MEM_DEBIT and MEM_CREDIT
* but does NOT affect real balance

If mixing memo and real accounts:

* ❌ reject

---

## 2️⃣ Concurrency Model

We must prevent race conditions.

Recommended:

``` sql
SELECT 1 FROM ledger
WHERE id = p_ledger_id
FOR UPDATE;
```

Or advisory lock:

``` sql
SELECT pg_advisory_xact_lock(hashtext(p_ledger_id::text));
```

This guarantees:

* No simultaneous postings corrupting state
* Safe multi-device posting

---

## 3️⃣ Posting Function Specification

We will implement:

``` sql
post_transaction(
    p_ledger_id uuid,
    p_post_date timestamptz,
    p_enter_date timestamptz,
    p_memo text,
    p_currency_commodity_id uuid,
    p_splits jsonb
)
RETURNS uuid
```

Where `p_splits` JSON contains:

``` json
[
  {
    "account_id": "...",
    "side": 0,
    "value_num": 10000,
    "value_denom": 100,
    "memo": "optional"
  }
]
```

---

## 4️⃣ Validation Steps Inside Function

### Step 1 — Lock ledger

Prevents concurrent posting issues.

---

### Step 2 — Validate splits

Checks:

1. All account_ids exist.
2. All accounts belong to ledger.
3. No placeholder accounts.
4. No deleted accounts.
5. Denominators > 0.
6. Not mixing memo and real accounts.

---

### Step 3 — Validate Balance

If real accounts:

``` cpp
net_sum = 0
```

If memo accounts:

``` cpp
sum_debit = sum_credit
```

---

### Step 4 — Insert transaction

Insert into `transaction`.

---

### Step 5 — Insert splits

Bulk insert from parsed JSON.

---

### Step 6 — Return transaction id

---

## 5️⃣ Reversal Strategy

We will implement:

``` cpp
reverse_transaction(p_tx_id uuid)
```

This will:

1. Read original splits.
2. Create new transaction.
3. Insert inverted splits:

   * swap side
     OR
   * invert value_num

Reversal is preferable to voiding.

---

## 6️⃣ Void Strategy

You already have:

``` cpp
transaction.is_voided boolean
```

Void rule:

* Cannot void if already voided.
* Voided transactions excluded from reporting.

---

## 7️⃣ Performance Considerations

Indexes already present:

* `idx_split_account`
* `idx_split_tx`
* `idx_tx_ledger_post_date`

This is sufficient for:

* balance queries
* ledger views
* reporting by date

Future:

Materialized balance view if needed.

---

## 8️⃣ What We Will Generate Next

Now that we have exact schema alignment, I will generate:

### 📄 050_posting_engine.sql

Containing:

* `validate_splits()`
* `post_transaction()`
* `reverse_transaction()`
* `optional void_transaction()`

And:

### 📄 050b_posting_usage_examples.sql

Containing:

* normal balanced transaction
* memo transaction
* reversal example
* error example

---

## 9️⃣ Before Generating the Script

For precision:

In `split` we have:

``` sql
amount numeric(38,10)
value_num bigint
value_denom integer
```

We have three options:

A) `amount` auto-calculated from value_num/value_denom
B) `value_num/value_denom` derived from amount
C) Both allowed but value_num authoritative

And our strong recommendation is:

> C — value_num/value_denom authoritative.
> amount is computed presentation layer.

## What this Posting Engine includes (schema-aligned)

### `mab_post_transaction(...)`

* Accepts `p_ledger_id` + `p_splits jsonb` (array of objects)
* Enforces:

  * all accounts exist
  * all accounts belong to the same ledger
  * no placeholder accounts
  * no deleted accounts
  * denominators > 0
  * `side in (0,1)` where **0=DEBIT, 1=CREDIT**
  * **single `value_denom` per transaction** (one precision per tx)
  * balanced transaction: `SUM(debits) - SUM(credits) = 0` using **value_num**
  * memo-account rule using `account_type.code IN ('MEM_DEBIT','MEM_CREDIT')`

    * rejects mixing memo and non-memo accounts in one tx
    * requires at least one MEM_DEBIT and one MEM_CREDIT account in memo-only transactions
* Inserts:

  * `transaction` header
  * `split` rows in bulk
  * derives `split.amount` as `ABS(value_num)/value_denom` (presentation)

### `mab_reverse_transaction(tx_id, ...)`

* Creates a new transaction reversing the original:

  * flips `split.side` (0↔1)
  * carries rational values unchanged
* Uses a per-ledger advisory lock for concurrency safety

### `mab_void_transaction(tx_id, reason)`

* Marks the transaction as `is_voided = true`
* Appends reason into memo (light audit trail)

---

## Running from terminal (your usual workflow)

```bash
psql -h localhost -U postgres -d myaccounting_dev -f /ABS/PATH/050_posting_engine.sql
psql -h localhost -U postgres -d myaccounting_dev -f /ABS/PATH/050b_posting_usage_examples.sql
```

---

## Small note (important)

This implementation detects memo accounts through:

* `account.account_type_id → account_type.code`
* memo codes expected: **`MEM_DEBIT`** and **`MEM_CREDIT`**

---
