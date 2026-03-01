# Production Risk Mitigation

**Last updated:** 2026-03-01

---

## Import Pipeline

- Use Python importers (`iso4217_importer_script.py`, `coa_importer_script.py`) for all production and CI/CD data imports.
- Never use psql `\copy` meta-commands in production migrations.
- Always run psql with `-v ON_ERROR_STOP=1` to catch silent failures.
- Wrap all imports in explicit transactions and add post-import validation queries.

---

## Schema Migrations

- Back up the database (`pg_dump --format=custom`) before applying any migration.
- Apply migrations with `ON_ERROR_STOP=1`; review output before proceeding.
- Never run `DROP TABLE` or `TRUNCATE` in production without a verified recent backup.
- Use `NOT VALID` constraints for online-safe backfills on large tables, then `VALIDATE CONSTRAINT` in a separate step.
- Avoid `ALTER TABLE ... ADD COLUMN NOT NULL` without a `DEFAULT` on populated tables (full table rewrite in PostgreSQL < 11; safe in 14+ only if default is immutable).

---

## Security

- Replace all `REPLACE_WITH_STRONG_SECRET_*` placeholders in `001_roles_setup.pgsql` before any non-local deployment.
- Use a secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.) for credentials in CI/CD.
- Restrict `pg_hba.conf` to specific role/IP pairs. Never allow `trust` authentication in production.
- Enable SSL (`sslmode=require`) for all production connections.
- Set `VALID UNTIL` on application roles (`mab_app`, `mab_readonly`) and rotate regularly.
- `mab_owner` (`BYPASSRLS`) must only connect from a bastion host or CI/CD runner IP — never from the application server.

---

## Row-Level Security

- RLS is `FORCE ROW LEVEL SECURITY` on all tenant-scoped tables — even `mab_owner` is subject to RLS unless `BYPASSRLS` is set.
- The session variable `app.current_owner_id` must be set before any query using `mab_app`:
  ```sql
  SET LOCAL app.current_owner_id = '<owner-uuid>';
  ```
- Always test RLS isolation before deploying:
  ```sql
  SET ROLE mab_app;
  SET LOCAL app.current_owner_id = '';
  SELECT COUNT(*) FROM public.ledger;  -- must return 0
  RESET ROLE;
  ```

---

## Audit Log

- `audit_log` is append-only. `UPDATE` and `DELETE` are revoked from all non-superuser roles.
- `mab_audit_trigger()` runs `SECURITY DEFINER` — it can always write to `audit_log` regardless of the calling role.
- Never grant `UPDATE` or `DELETE` on `audit_log` to any application role.
- `mab_auditor` has `SELECT` on `audit_log` only — no access to financial data tables.

---

## Posting Engine

- All postings use `pg_advisory_xact_lock(hashtext(ledger_id::text))`. Never bypass this when posting from custom scripts.
- All balance invariants are enforced in `mab_post_transaction`. Do not INSERT directly into `transaction`/`split` outside this function in production.
- Use `mab_reverse_transaction` for corrections, not manual UPDATE.

---

## Commodities and Account Types

- The `account_type` table is a stable reference catalog. Add new types carefully — existing `account_type_code` FKs in `coa_template_node` use `ON DELETE RESTRICT`, so deleting a type that is in use will fail.
- Commodity fraction values (e.g. 100 for 2-decimal currencies) are used in `commodity_scu` during ledger instantiation. Changing fraction after accounts are created will not retroactively update existing accounts.

---

## Cloud Deployment Notes

The schema is cloud-agnostic (no vendor-specific extensions beyond `pgcrypto`). Compatible with:

- Local PostgreSQL (dev)
- DigitalOcean Managed PostgreSQL
- AWS RDS for PostgreSQL
- Google Cloud SQL for PostgreSQL

For managed services, note that `pg_advisory_xact_lock` is fully supported. RLS and `SECURITY DEFINER` functions are supported. `\copy` meta-commands are not available via managed query consoles — use Python importers exclusively.
