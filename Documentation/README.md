# MyAccountingBooks

A multi-ledger, multi-currency accounting system built on PostgreSQL.

## Architecture Version: v4 (Excel-Only Pipeline)

This version reflects the current architecture:

- COA Templates are imported from Excel (.xlsx)
- ISO 4217 currencies are imported from Excel
- No JSON/NDJSON import pipeline
- Root node inferred from level = 0
- Python-based importers (cross-platform)

## Documentation

- **Architecture**
  - `docs/architecture/Database_Architecture_Overview.md`
  - `docs/architecture/ERD.md`
  - `docs/architecture/Data_Flow.md`
  - `docs/architecture/Schema_Inventory.md`
- **Engine**
  - `docs/engine/Posting_Engine_Design_Specification.md`
  - `docs/engine/Posting_Engine_Sequence.md`
- **Deployment**
  - `docs/deployment/Deployment_and_Migration_Guide.md`
  - `docs/deployment/Migration_History.md`
  - `docs/deployment/CI_CD.md`
- **Engineering / Operations**
  - `docs/engineering/PSQL_Postmortem.md`
  - `docs/operations/Production_Risk_Mitigation.md`
- **API (future)**
  - `docs/api/openapi.yaml`
  - `docs/api/API_Contract.md`

Last Updated: 2026-02-27
