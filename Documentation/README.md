# MyAccountingBooks

A multi-ledger, multi-currency, double-entry accounting system built on PostgreSQL.

## Architecture Version: v4 — Schema v2 (Excel-Only Pipeline)

Current architecture highlights:

- COA Templates imported from Excel (`.xlsx`) via Python importers
- ISO 4217 currencies imported from the official SIX Excel file
- No JSON/NDJSON import pipeline (removed in v0.4)
- Root node inferred dynamically from `level = 0`
- Python-based importers (cross-platform, CI/CD-safe)
- Row-Level Security (RLS) enforcing tenant isolation
- Append-only `audit_log` populated by `SECURITY DEFINER` trigger
- Posting engine enforcing double-entry invariants in-database

---

## Documentation Index

### Architecture
- [`docs/architecture/Database_Architecture_Overview.md`](docs/architecture/Database_Architecture_Overview.md)
- [`docs/architecture/ERD.md`](docs/architecture/ERD.md)
- [`docs/architecture/Data_Flow.md`](docs/architecture/Data_Flow.md)
- [`docs/architecture/Schema_Inventory.md`](docs/architecture/Schema_Inventory.md)

### Engine
- [`docs/engine/Posting_Engine_Design_Specification.md`](docs/engine/Posting_Engine_Design_Specification.md)
- [`docs/engine/Posting_Engine_Sequence.md`](docs/engine/Posting_Engine_Sequence.md)

### Deployment
- [`docs/deployment/Deployment_and_Migration_Guide.md`](docs/deployment/Deployment_and_Migration_Guide.md)
- [`docs/deployment/Migration_History.md`](docs/deployment/Migration_History.md)
- [`docs/deployment/CI_CD.md`](docs/deployment/CI_CD.md)

### Engineering / Operations
- [`docs/engineering/PSQL_Postmortem.md`](docs/engineering/PSQL_Postmortem.md)
- [`docs/engineering/Import_Pipeline.md`](docs/engineering/Import_Pipeline.md)
- [`docs/operations/Production_Risk_Mitigation.md`](docs/operations/Production_Risk_Mitigation.md)

### Reference
- [`docs/reference/PSQL_Commands.md`](docs/reference/PSQL_Commands.md)
- [`docs/reference/Dev_Settings.md`](docs/reference/Dev_Settings.md)
- [`docs/reference/DB_Creation_Process.md`](docs/reference/DB_Creation_Process.md)

### API (future)
- [`docs/api/API_Contract.md`](docs/api/API_Contract.md)

---

## Quick Start

```bash
# 1. Create database and role
psql postgres -f sql/db_creation.sql

# 2. Apply schema (from scratch)
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/000_MyAccountingBooks_CreateFromScratch_v2.psql"

# 3. Apply roles
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/001_roles_setup.pgsql"

# 4. Seed account types
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/002_Populating_account_type.pgsql"

# 5. Seed crypto commodities
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/003_seed_crypto_to_commodity.pgsql"

# 6. Import ISO 4217 currencies (download + import)
python "Python scripts/Final/download_iso4217_current_to_excel.py"
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel iso4217_current_list_one.xlsx

# 7. Import a COA template
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel "your_template.xlsx"
```

---

Last Updated: 2026-03-01
