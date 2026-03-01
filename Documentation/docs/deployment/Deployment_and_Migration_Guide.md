# Deployment & Migration Guide

**Last updated:** 2026-03-01

---

## Environments

| Environment | Notes                                                                 |
|-------------|-----------------------------------------------------------------------|
| Dev         | psql meta-commands acceptable; pgAdmin Query Tool is fine             |
| CI/CD       | SQL-only migrations; Python importers; `-v ON_ERROR_STOP=1` required  |
| Prod        | Python importers preferred; avoid psql meta-commands; always back up first |

---

## Requirements

- PostgreSQL 14+ (tested on 18.3)
- Python 3.10+
- `psycopg` (v3) — `pip install psycopg[binary]`
- `pandas` — `pip install pandas`
- `openpyxl` / `xlrd` — `pip install openpyxl xlrd`
- `requests` — `pip install requests` (for ISO 4217 download script)

---

## Deployment Order (Fresh Install)

### Step 1 — Create database and role

```bash
psql postgres
```

```sql
CREATE ROLE myaccounting_user
    LOGIN PASSWORD 'dev_password' CREATEDB;

CREATE DATABASE myaccounting_dev
    OWNER myaccounting_user;

\q
```

### Step 2 — Apply schema (from scratch)

```bash
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/000_MyAccountingBooks_CreateFromScratch_v2.psql"
```

This creates all tables, indexes, triggers, functions, views, and RLS policies in a single transaction.

### Step 3 — Apply database roles

```bash
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/001_roles_setup.pgsql"
```

Creates `mab_owner`, `mab_app`, `mab_readonly`, `mab_auditor` with appropriate privileges.  
**Replace placeholder passwords before deploying.** Use a secrets manager in production.

### Step 4 — Seed account types

```bash
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/002_Populating_account_type.pgsql"
```

Seeds the `account_type` catalog (~50 types: assets, liabilities, equity, income, expenses, financial results, memorandum).

### Step 5 — Seed crypto commodities

```bash
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/003_seed_crypto_to_commodity.pgsql"
```

Seeds BTC, ETH, USDT, USDC into `commodity` (namespace = `CRYPTO`).

### Step 6 — Import ISO 4217 currencies

```bash
# Download the SIX Excel file
python "Python scripts/Final/download_iso4217_current_to_excel.py"

# Import into commodity table
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel iso4217_current_list_one.xlsx \
  --namespace CURRENCY \
  --na-fraction 100 \
  --do-deactivate-missing 0
```

### Step 7 — Import COA templates

COA template Excel files must contain:
- A **"Meta"** sheet with key-value rows (code, name, description, country, locale, industry, version)
- A **nodes sheet** (default: first sheet) with columns: Code, Parent, Level, Name, Kind, Role, Placeholder, Account_Type

```bash
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel "Personales_2026.xlsx"
```

Optionally override any metadata field from the CLI:

```bash
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "..." \
  --excel "Personales_2026.xlsx" \
  --template-version 2
```

### Step 8 — Verification

```sql
-- Table count (expect 17)
SELECT count(*) FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- RLS enabled
SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class
 WHERE relname IN ('ledger','account','transaction','split','payee','scheduled_transaction')
   AND relnamespace = 'public'::regnamespace;

-- Generated column on split
SELECT column_name, generation_expression
  FROM information_schema.columns
 WHERE table_name = 'split' AND column_name = 'amount';

-- Verify account_types seeded
SELECT COUNT(*) FROM public.account_type WHERE deleted_at IS NULL;

-- Verify currencies loaded
SELECT COUNT(*) FROM public.commodity WHERE namespace = 'CURRENCY' AND deleted_at IS NULL;

-- Verify templates
SELECT code, version, name FROM public.coa_template WHERE is_active = true;
```

---

## Adding a COA Template Column: `account_type_code` Migration

If you have an older schema without `account_type_code` on `coa_template_node`, follow these steps:

**Step 1** — Add column (safe, does not block reads):
```sql
-- 014_alter_coa_template_node_add_account_type_code.sql
ALTER TABLE public.coa_template_node
  ADD COLUMN account_type_code text
  REFERENCES public.account_type(code)
  ON UPDATE CASCADE ON DELETE RESTRICT
  NOT VALID;
```

**Step 2** — Backfill from existing data or re-import templates.

**Step 3** — Validate constraints:
```sql
ALTER TABLE public.coa_template_node
  VALIDATE CONSTRAINT coa_template_node_account_type_code_fkey;
```

**Step 4** — Deploy `instantiate_coa_template_to_ledger` v2 (current version in schema).

---

## Backup Strategy

```bash
# Schema only (before migrations)
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --schema-only --clean --if-exists --no-owner --no-privileges \
  -f myaccounting_dev_schema_$(date +%Y%m%d).sql

# Full backup (custom format — recommended)
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --format=custom --no-owner --no-privileges \
  -f myaccounting_dev_$(date +%Y%m%d).dump

# Restore
pg_restore -h localhost -U postgres -d myaccounting_dev_restored \
  --clean --if-exists \
  myaccounting_dev_YYYYMMDD.dump
```

---

## Production Checklist

- [ ] Replace all `REPLACE_WITH_STRONG_SECRET_*` passwords in `001_roles_setup.pgsql`
- [ ] Configure `pg_hba.conf` to restrict connections by role and source IP
- [ ] Enable SSL for all production connections
- [ ] Run `ALTER ROLE mab_app VALID UNTIL ...` to enforce password rotation
- [ ] Back up before every migration
- [ ] Apply migrations with `ON_ERROR_STOP=1`
- [ ] Use Python importers (not psql meta-commands) for data imports
- [ ] Verify `audit_log` is append-only (`UPDATE`/`DELETE` revoked from all app roles)
- [ ] Test RLS isolation: `SET LOCAL app.current_owner_id = ''; SELECT COUNT(*) FROM ledger;` → expect 0
