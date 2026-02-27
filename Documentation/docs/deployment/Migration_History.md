# Versioned Migration History

**Last updated:** 2026-02-26

## Naming Convention

- `000_...` baseline / schema creation
- `01x_...` schema evolution
- `02x_...` seed/reference data
- `04x_...` business logic (functions)

## Migration Log

| Version | Date | Migration(s) | Purpose | Notes |
|---|---:|---|---|---|
| v0.1 | 2026-02-26 | baseline + imports + posting engine | Initial deliverable | Dev baseline |
| v0.2 | 2026-02-26 | COA template system | Initial deliverable | Dev baseline |
| v0.3 | 2026-02-26 | Commodity ISO 4217 integration | Importing world currencies | Dev baseline |
| v0.4 | 2026-02-27 | Excel-only import pipline. Removed JSON ingestion. Dynamic root detection | Initial deliverable | Dev Baseline |
