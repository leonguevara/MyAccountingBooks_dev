# CHANGELOG — MyAccountingBooks

---

## [v0.9] — 2026-03-07

### Added

- **Backend API (MAB-API):** Spring Boot 3.5 / Java 23 REST service fully implemented.
  - JWT authentication via JJWT 0.12.6 (HMAC-SHA256, 24h expiry).
  - `TenantContext` pattern: `SET LOCAL app.current_owner_id` scopes every DB query to the authenticated owner — bridges JWT auth to PostgreSQL RLS.
  - Controllers: `AuthController`, `HealthController`, `LedgerController`, `AccountController`, `CommodityController`, `TransactionController`.
  - Services: `AuthService`, `LedgerService`, `AccountService`, `CommodityService`, `TransactionService`.
  - Repositories: `LedgerRepository`, `AccountRepository`, `CommodityRepository`, `TransactionRepository`.
  - `GlobalExceptionHandler`: uniform JSON error responses for `ApiException`, `DataIntegrityViolationException`, `UncategorizedSQLException`.
  - OpenAPI 3 / Swagger UI via springdoc-openapi at `/swagger-ui.html`.
  - Docker Compose stack: `postgres` (PostgreSQL 18, port 5433) + `mab-api` (port 8080).
  - Multi-stage Dockerfile (JDK 23 builder → JRE 23 runtime).
  - Spring profiles: `application.properties` (local dev) + `application-docker.properties` (Docker).
- `docs/api/Backend_API_Architecture.md` — package structure, security model, TenantContext, error handling, Docker deployment.
- `docs/api/API_Quick_Start.md` — full developer workflow: Docker, seed, create user, login, create ledger, post transaction, Swagger UI.
- `CHANGELOG.md` — this file.

### Updated

- `README.md` — Architecture v5; added API Quick Start section; updated status table.
- `docs/api/API_Contract.md` — replaced placeholder stub with full implemented contract.
- `docs/architecture/Data_Flow.md` — updated diagrams to show actual Spring Boot stack and TenantContext; added transaction posting flow.
- `docs/architecture/Database_Architecture_Overview.md` — Backend API status updated to ✅.
- `technical_db_architecture_summary.md` — Sections 15–16 updated to reflect completed API layer.

---

## [v0.8] — 2026-03-01

### Added on v0.8

- Consolidated schema dump `myaccounting_dev_schema_clean_v20260301.psql`.
- `v_role_password_age` view for credential monitoring.

---

## [v0.7] — 2026-03-01

### Added on v0.7

- Python importer v2: `coa_importer_script.py` reads metadata from Excel Meta sheet.
- `iso4217_importer_script.py` v2: partial-index `ON CONFLICT` fix.

---

## [v0.6] — 2026-02-27

### Added on v0.6

- `001_roles_setup.pgsql`: `mab_owner`, `mab_app`, `mab_readonly`, `mab_auditor`.

---

## [v0.5] — 2026-02-27

### Added on v0.5

- Schema v2: `split.amount` generated column, `ledger.decimal_places`, `transaction.voided_at` + `reversed_by_tx_id`, RLS policies, `audit_log` + trigger.

---

## [v0.4] — 2026-02-27

### Changed on v0.4

- Removed JSON/NDJSON import pipeline. Excel-only pipeline adopted. Python importers v1.

---

## [v0.3] — 2026-02-26

### Added on v0.3

- ISO 4217 commodity integration via SIX Group Excel.

---

## [v0.2] — 2026-02-26

### Added  on v0.2

- COA template system: `coa_template`, `coa_template_node`, instantiation functions.

---

## [v0.1] — 2026-02-26

### Added on v0.1

- Initial schema (17 tables), baseline posting engine design, Python import scripts v1.
