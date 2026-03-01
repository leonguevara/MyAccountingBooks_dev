# CI/CD Deployment Documentation

**Last updated:** 2026-03-01

---

## Pipeline Steps

1. Start PostgreSQL service container
2. Create role and database (`db_creation_process.md`)
3. Apply schema: `000_MyAccountingBooks_CreateFromScratch_v2.psql`
4. Apply roles: `001_roles_setup.pgsql`
5. Seed reference data: `002_Populating_account_type.pgsql`, `003_seed_crypto_to_commodity.pgsql`
6. Import ISO 4217 currencies via `iso4217_importer_script.py`
7. Import COA templates via `coa_importer_script.py`
8. Run smoke tests / verification queries
9. Dump schema artifact

---

## Key CI Rules

- Always use `-v ON_ERROR_STOP=1` for all psql commands.
- Use Python importers (`iso4217_importer_script.py`, `coa_importer_script.py`) — never psql `\copy` meta-commands in CI.
- Run verification queries after seeding (see Deployment Guide Step 8).
- Schema dump artifact should be committed or stored per pipeline run for regression comparison.

---

## GitHub Actions Reference

See `.github/workflows/db-ci.yml`.

---

## Environment Variables (recommended)

```yaml
env:
  DB_HOST: localhost
  DB_PORT: 5432
  DB_NAME: myaccounting_dev
  DB_USER: postgres
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  DSN: "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=${{ secrets.DB_PASSWORD }}"
```

---

## Python Dependency Installation

```bash
pip install psycopg[binary] pandas openpyxl xlrd requests
```

---

## Smoke Test Queries

```sql
-- All 17 tables present
SELECT count(*) FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
-- expect: 17

-- Functions present
SELECT count(*) FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
   AND proname LIKE 'mab%';
-- expect: >= 5

-- account_type seeded
SELECT count(*) FROM public.account_type WHERE deleted_at IS NULL;
-- expect: ~50

-- Currencies loaded
SELECT count(*) FROM public.commodity
 WHERE namespace = 'CURRENCY' AND deleted_at IS NULL;
-- expect: ~170+

-- RLS enabled (no rows without owner context)
SET LOCAL app.current_owner_id = '';
SELECT count(*) FROM public.ledger;
-- expect: 0
```
