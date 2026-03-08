# MyAccountingBooks

A multi-ledger, multi-currency, double-entry accounting system built on PostgreSQL with a Java Spring Boot REST API.

## Architecture Version: v5 — Schema v2 · Posting Engine · Backend API

Current architecture highlights:

- COA Templates imported from Excel (`.xlsx`) via Python importers
- ISO 4217 currencies imported from the official SIX Excel file
- Python-based importers (cross-platform, CI/CD-safe)
- Row-Level Security (RLS) enforcing tenant isolation at the DB level
- Append-only `audit_log` populated by `SECURITY DEFINER` trigger
- Posting engine enforcing double-entry invariants in-database
- Spring Boot 3.x REST API with JWT authentication
- TenantContext pattern: every DB call scoped via `SET LOCAL app.current_owner_id`
- OpenAPI 3 / Swagger UI auto-generated at `/swagger-ui.html`
- Docker Compose local stack (API + PostgreSQL 18)

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

### API

- [`docs/api/API_Contract.md`](docs/api/API_Contract.md)
- [`docs/api/Backend_API_Architecture.md`](docs/api/Backend_API_Architecture.md)
- [`docs/api/API_Quick_Start.md`](docs/api/API_Quick_Start.md)
- [`docs/api/API_Development_Postmortem.md`](docs/api/API_Development_Postmortem.md)

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

### Project History

- [`CHANGELOG.md`](CHANGELOG.md)

---

## Quick Start — Database

``` bash
# 1. Create database and role
psql postgres -c "CREATE ROLE myaccounting_user LOGIN PASSWORD 'dev_password' CREATEDB;"
psql postgres -c "CREATE DATABASE myaccounting_dev OWNER myaccounting_user;"

# 2. Apply schema
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

# 6. Import ISO 4217 currencies
python "Python scripts/Final/download_iso4217_current_to_excel.py"
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel iso4217_current_list_one.xlsx

# 7. Import COA template
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel "your_coa_template.xlsx"
```

## Quick Start — API (Docker)

``` bash
cd MAB-API
docker-compose up --build
# API: http://localhost:8080
# Swagger UI: http://localhost:8080/swagger-ui.html
```

See [`docs/api/API_Quick_Start.md`](docs/api/API_Quick_Start.md) for the full developer workflow.

---

## Current System Status

| Area                    | Status          |
|-------------------------|-----------------|
| Data Model              | ✅ Stable       |
| COA Templates           | ✅ Operational  |
| Excel Import Pipeline   | ✅ Working      |
| ISO Currency Dataset    | ✅ Loadable     |
| Crypto Commodities      | ✅ Seeded       |
| RLS / Audit Log         | ✅ Implemented  |
| Ledger Instantiation    | ✅ SQL-Based    |
| DDL Bootstrap           | ✅ Complete     |
| Posting Engine          | ✅ Implemented  |
| Backend API             | ✅ Implemented  |
| Mobile / Desktop Client | 🔲 Future.      |
