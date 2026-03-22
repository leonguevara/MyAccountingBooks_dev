# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyAccountingBooks is a multi-ledger, multi-currency, double-entry accounting system. The monorepo contains three distinct components:

- **`Backend/MAB-API/`** — Spring Boot 3.5 / Java 23 REST API
- **`Clients/apple_multiplatform/`** — SwiftUI app (macOS / iOS / watchOS)
- **`Backend/Database/`** — PostgreSQL schema scripts, Python data importers, and seed data

Accounting correctness lives entirely in the database (PostgreSQL stored functions). The API and clients are intentionally thin — they delegate all invariant enforcement to the DB layer.

---

## Backend API (Spring Boot)

### Build & Run

```bash
cd Backend/MAB-API

# Run locally (requires local PostgreSQL on port 5432)
./mvnw spring-boot:run

# Run via Docker (API on :8080, PostgreSQL on :5433)
docker-compose up --build

# Run tests
./mvnw test

# Run a single test class
./mvnw test -Dtest=MabApiApplicationTests
```

### Package Structure

```
com.leonguevara.mab.mab_api
├── config/          — DataSource, Security, OpenAPI, TenantContext
├── controller/      — HTTP routing only; no business logic
├── service/         — Orchestration: ownership checks + TenantContext wrapping
├── repository/      — All SQL via NamedParameterJdbcTemplate
├── security/        — JwtUtil, JwtAuthFilter, UserPrincipal
├── dto/             — request/ and response/ POJOs
└── exception/       — ApiException + GlobalExceptionHandler
```

### Critical: TenantContext

Every authenticated DB call must be wrapped in `TenantContext.withOwner(ownerID, jdbc, tx, work)`. This opens a JDBC transaction, issues `SET LOCAL app.current_owner_id = '<uuid>'`, and runs the repository lambda — activating PostgreSQL Row-Level Security. Omitting this wrapper returns zero rows for all tenant-scoped tables.

### Environment Variables

| Variable | Default | Notes |
|---|---|---|
| `JWT_SECRET` | `change_me_in_production_use_a_256_bit_key` | Must change in production |
| `SPRING_DATASOURCE_URL` | from docker profile | JDBC URL |
| `SPRING_DATASOURCE_USERNAME` | `mab_app` | DB role — no DDL, no BYPASSRLS |
| `SPRING_DATASOURCE_PASSWORD` | `dev_password` | |
| `SPRING_PROFILES_ACTIVE` | `docker` | Switches datasource to `postgres` hostname |

### Swagger UI

Available at `http://localhost:8080/swagger-ui.html` when running.

---

## iOS / macOS Client (SwiftUI)

Open `Clients/apple_multiplatform/MyAccountingBooks/MyAccountingBooks.xcodeproj` in Xcode. Build and run from there. Tests live in `MyAccountingBooksTests/` and `MyAccountingBooksUITests/`.

### Client Architecture

The app follows an MVVM pattern with a feature-based directory layout:

```
MyAccountingBooks/
├── App/                 — App entry point (MyAccountingBooksApp.swift)
├── Core/
│   ├── Auth/            — AuthService, TokenStore (Keychain), SessionStore (UserDefaults)
│   ├── Models/          — Decodable response types
│   └── Network/         — APIClient (singleton), APIEndpoint (enum), APIError
└── Features/
    ├── Auth/            — LoginView
    ├── App/             — ContentView (root navigation)
    ├── Ledgers/         — LedgerListView + ViewModel
    ├── Accounts/        — AccountTreeView, AccountRegisterView + ViewModels
    └── Transactions/    — TransactionListView, PostTransactionView + ViewModels
```

### Key Networking Conventions

- `APIClient.shared.request(_:method:body:token:)` is the single network entry point — generic, async/await.
- All JSON keys are **camelCase** (no snake_case conversion). Models must use explicit `CodingKeys` if field names deviate.
- Dates use ISO 8601 encoding/decoding.
- `APIEndpoint` is a typed enum; to add a new route, add a case and handle it in the `url` computed property.
- The JWT token is stored in Keychain via `TokenStore`. `SessionStore` (UserDefaults) only persists the last-selected ledger ID — no financial data.
- `AuthService` checks token validity on init; expired tokens clear both `TokenStore` and `SessionStore`.

---

## Database

### Schema Bootstrap (local, no Docker)

```bash
cd "Backend/Database"

psql postgres -c "CREATE ROLE myaccounting_user LOGIN PASSWORD 'dev_password' CREATEDB;"
psql postgres -c "CREATE DATABASE myaccounting_dev OWNER myaccounting_user;"

psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/000_MyAccountingBooks_CreateFromScratch_v2.psql"
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/001_roles_setup.pgsql"
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/002_Populating_account_type.pgsql"
psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/003_seed_crypto_to_commodity.pgsql"
```

### Python Data Import (requires psycopg v3, pandas, openpyxl)

```bash
pip install "psycopg[binary]" pandas openpyxl xlrd requests

# Download and import ISO 4217 currencies
python "Python scripts/Final/download_iso4217_current_to_excel.py"
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel iso4217_current_list_one.xlsx

# Import a Chart of Accounts template
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel "your_coa_template.xlsx"
```

### Database Role Model

| Role | Purpose | RLS bypass |
|---|---|---|
| `mab_owner` | DDL / migration runner | Yes |
| `mab_app` | Runtime API (DML only) | No |
| `mab_readonly` | Reporting / BI | No |
| `mab_auditor` | SELECT on `audit_log` only | No |

### Key Design Decisions

- **Exact arithmetic**: All monetary values stored as rationals (`value_num / value_denom`). Never use the `amount` column (a generated convenience field) for balance calculations.
- **Posting engine**: `mab_post_transaction()`, `mab_reverse_transaction()`, `mab_void_transaction()` enforce double-entry invariants. The API calls these functions; it never does arithmetic directly.
- **Account classification uses three orthogonal dimensions**: `kind` (accounting nature: Asset/Liability/etc.), `account_type` (functional: BANK, CASH, AP…), and `role` (operational: Control/Tax/Memo). Do not conflate them.
- **COA Templates**: Instantiated atomically via `instantiate_coa_template_to_ledger()`. Every non-placeholder node must have an `account_type_code`.
- **`audit_log`**: Written exclusively by `mab_audit_trigger()` (SECURITY DEFINER). No application role may UPDATE or DELETE rows.
- **`v_ledger`**: Use this view (not the `ledger` table directly) when `currency_code` is needed — it joins `commodity.mnemonic`.

---

## Documentation

Full documentation is in `Documentation/docs/`:

- Architecture: `docs/architecture/`
- Posting engine spec: `docs/engine/`
- API contract & architecture: `docs/api/`
- Deployment & migrations: `docs/deployment/`
- DB creation & PSQL reference: `docs/reference/`
