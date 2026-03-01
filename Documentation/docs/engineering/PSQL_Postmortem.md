# MyAccountingBooks — Engineering Postmortem

**Date:** 2026-02-26 (updated 2026-03-01)  
**Project:** MyAccountingBooks — Database & Import Pipeline Development

---

## 1. Executive Summary

During development of the PostgreSQL-based accounting engine, multiple cross-platform issues were encountered related to psql meta-commands, variable substitution, Windows/macOS path handling, and transaction abort behavior. This document captures root causes, resolutions, and lessons learned.

---

## 2. Key Incidents

| Incident | Symptom |
|----------|---------|
| `\copy` meta-command failures | Parameterized paths broke across environments |
| Windows CMD quoting | Single-quote variable expansion failed silently |
| Transaction abort propagation | All subsequent commands ignored after first error |
| `ON CONFLICT` failures | Missing UNIQUE constraint caused runtime errors |
| pgAdmin meta-command incompatibility | `\copy`, `\gexec` etc. unusable in Query Tool |
| Hardcoded paths | Scripts non-portable between developer machines |
| Partial index `ON CONFLICT` mismatch | ISO 4217 importer targeted wrong constraint |

---

## 3. Root Causes

### 3.1 `\copy` Is a Client Meta-Command

`\copy` is not SQL. It runs in the psql client process. Variable expansion (`:'csv_path'`) behaves differently from SQL literals, and quoting rules depend on the shell environment.

### 3.2 Windows vs macOS Shell Differences

- Windows CMD treats single quotes literally — `:'path'` fails.
- Double quoting required for `-v` parameters on Windows.
- Backslashes vs. forward slashes differ between OSes.
- The same script that works on macOS can silently fail on Windows.

### 3.3 Transaction Abort Behavior

After any error inside a transaction:

```
ERROR: current transaction is aborted, commands ignored until end of transaction block
```

All subsequent commands are silently ignored until `ROLLBACK`. Without `ON_ERROR_STOP=1`, partial migrations can be applied invisibly.

### 3.4 `ON CONFLICT` Requires Matching Constraint

PostgreSQL requires that the conflict target exactly matches a UNIQUE or PRIMARY KEY constraint — including the `WHERE` predicate for partial indexes.

The `commodity` table uses a partial unique index:
```sql
CREATE UNIQUE INDEX commodity_namespace_mnemonic_ux
  ON commodity(namespace, mnemonic) WHERE deleted_at IS NULL;
```

The `ON CONFLICT` clause must mirror this predicate:
```sql
ON CONFLICT (namespace, mnemonic) WHERE deleted_at IS NULL
DO UPDATE SET ...
```

Omitting `WHERE deleted_at IS NULL` caused: `"there is no unique or exclusion constraint matching the ON CONFLICT specification"`.

### 3.5 Soft-Delete + Partial Index Edge Case

Rows with `deleted_at IS NOT NULL` are invisible to the partial index. A row that was soft-deleted and then re-imported would **not** trigger the ON CONFLICT — it would result in a second active row for the same `(namespace, mnemonic)`. Solution: restore soft-deleted rows before the upsert runs.

---

## 4. Resolution Strategy

### 4.1 Python Importers (Primary Solution)

Replaced all `\copy` / shell-based imports with `psycopg` v3 Python scripts. This eliminates:

- Shell quoting issues
- Platform path differences
- Transaction visibility problems

Advantages: production-safe, CI/CD-friendly, better error diagnostics, batch-able.

### 4.2 `ON_ERROR_STOP=1` Enforced

All psql executions now use:

```bash
psql -v ON_ERROR_STOP=1 -f script.sql
```

This causes psql to exit immediately on any error, preventing partial migrations.

### 4.3 Dynamic `\copy` via `\gexec` (Fallback for psql pipelines)

For environments where Python is unavailable, a safe `\copy` pattern uses `\gexec`:

```sql
SELECT format(
  E'\copy table(cols) FROM %L WITH (FORMAT csv, HEADER true)',
  :'csv_path'
) \gexec;
```

This ensures safe quoting via `%L` and avoids shell variable expansion issues.

### 4.4 Partial Index ON CONFLICT Alignment

Fixed by always mirroring the partial index predicate in the `ON CONFLICT` clause and adding a pre-upsert step to restore soft-deleted rows.

---

## 5. Lessons Learned

1. **Never treat `\copy` like SQL.** It is a client meta-command with its own quoting rules.
2. **Always validate variable expansion** with `\echo` before using in `\copy`.
3. **Windows shell behavior differs fundamentally** from macOS/Linux. If cross-platform is a requirement, use Python.
4. **Avoid meta-commands in production migrations.** Python importers are the right tool.
5. **Always create UNIQUE indexes before using `ON CONFLICT`.** Partial indexes require the `WHERE` clause to be mirrored.
6. **Wrap imports in explicit transactions.** Never rely on autocommit for multi-statement imports.
7. **Add post-import validation queries** as part of every migration to catch silent failures.
8. **Soft-delete + partial unique index** requires extra care: restore soft-deleted rows before upserting.

---

## 6. Final Architecture

The system now includes:

- Stable cross-platform import pipeline (Python)
- Deterministic migration order with `ON_ERROR_STOP=1`
- Posting engine with advisory locking and in-database invariant enforcement
- Rational arithmetic monetary model (`value_num / value_denom`)
- Append-only audit log (`SECURITY DEFINER` trigger)
- Row-Level Security tenant isolation
- CI-ready schema validation queries
