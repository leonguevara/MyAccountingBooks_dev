# Posting Engine Design Specification

**Last updated:** 2026-02-26

## Goals

- Enforce double-entry accounting invariants at write-time.
- Prevent cross-ledger corruption.
- Support memo-only postings (if enabled) without affecting real balances.
- Use **rational values** (`value_num` / `value_denom`) as authoritative monetary representation.

## Canonical Value Model

- **Authoritative**: `value_num`, `value_denom`
- **Presentation-only**: `amount`

## Core API (SQL)

- `post_transaction(...) -> transaction_id`
- `reverse_transaction(tx_id) -> new_transaction_id`
- Optional: `void_transaction(tx_id)` (if business rules allow)

## Concurrency

- Ledger-level `pg_advisory_xact_lock` per posting.
- Ensures multi-device writes do not interleave inconsistently.

## Validation Checklist

- Accounts exist and belong to the specified ledger
- Not placeholder / not deleted / active
- Denominators > 0
- Memo vs real accounts are not mixed (if memo mode is enabled)
- Balanced transaction (net sum = 0, using rational values)
