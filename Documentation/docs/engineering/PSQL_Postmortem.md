# MyAccountingBooks Engineering Postmortem

Date: 2026-02-26
Project: MyAccountingBooks – Database & Import Pipeline Development

---

## 1. Executive Summary

During development of the PostgreSQL-based accounting engine, multiple cross-platform
issues were encountered related to psql meta-commands, variable substitution,
Windows/macOS path handling, and transaction abort behavior.

This document captures root causes, remediation, and lessons learned.

---

## 2. Key Incidents

- Parameterized \copy failed across environments.
- Windows CMD quoting broke variable expansion.
- Transactions aborted silently after first error.
- ON CONFLICT failed due to missing UNIQUE constraints.
- Meta-commands unusable inside pgAdmin Query Tool.
- Hardcoded paths worked but were not reusable.

---

## 3. Root Causes

### 3.1 \copy Is a Client Meta-Command

It is not SQL. Variable expansion differs from SQL literals.
Quoting rules depend on the shell environment.

### 3.2 Windows vs macOS Shell Differences

- Windows CMD treats single quotes literally.
- Double quoting required for -v parameters.
- Backslashes and escaping differ.
- Forward slashes safer for cross-platform paths.

### 3.3 Transaction Abort Behavior

After first failure:

    ERROR: current transaction is aborted

All subsequent commands are ignored until ROLLBACK.

### 3.4 ON CONFLICT Requires UNIQUE Constraint

PostgreSQL requires a UNIQUE or PRIMARY KEY constraint
matching the conflict target.

---

## 4. Resolution Strategy

### 4.1 Dynamic \copy via \gexec

Used:

    SELECT format(
      E'\\copy table(cols) FROM %L WITH (FORMAT csv, HEADER true)',
      :'csv_path'
    ) \gexec;

This ensured safe quoting and cross-platform compatibility.

### 4.2 Python Import Alternative

Implemented psycopg-based importers to eliminate shell quoting issues.

Advantages:

- Production-safe
- CI-friendly
- Better error diagnostics

### 4.3 Enforced ON_ERROR_STOP

All scripts now executed with:

    -v ON_ERROR_STOP=1

---

## 5. Lessons Learned

1. Never treat \copy like SQL.
2. Always validate variable expansion with \echo.
3. Windows shell behavior differs fundamentally.
4. Avoid meta-commands in production migrations.
5. Always create UNIQUE indexes before ON CONFLICT.
6. Wrap imports in explicit transactions.
7. Add post-import validation queries.

---

## 6. Production Risk Mitigation

- Prefer Python importers in CI/CD.
- Avoid psql meta-commands in production.
- Version migrations deterministically.
- Backup before applying migrations.
- Use advisory locks in posting engine.

---

## 7. Final Outcome

The system now includes:

- Stable cross-platform import pipeline
- Deterministic migration order
- Posting engine with advisory locking
- Rational arithmetic monetary model
- CI-ready schema validation

The final architecture is migration-safe and production-ready.

---

End of Engineering Postmortem
