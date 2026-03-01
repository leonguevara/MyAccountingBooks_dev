# Versioned Migration History

**Last updated:** 2026-03-01

---

## Naming Convention

| Prefix | Purpose                        |
|--------|--------------------------------|
| `000_` | Baseline / schema creation     |
| `001_` | Roles and security setup       |
| `01x_` | Schema evolution (alterations) |
| `02x_` | Seed / reference data          |
| `03x_` | Import pipeline artifacts      |
| `04x_` | Business logic (functions)     |

---

## Migration Log

| Version | Date       | Script(s)                                               | Purpose                                                      | Notes              |
|---------|------------|---------------------------------------------------------|--------------------------------------------------------------|--------------------|
| v0.1    | 2026-02-26 | baseline + imports + posting engine                     | Initial deliverable                                          | Dev baseline       |
| v0.2    | 2026-02-26 | COA template system                                     | `coa_template` + `coa_template_node` + instantiation function | Dev baseline       |
| v0.3    | 2026-02-26 | Commodity ISO 4217 integration                          | World currencies via SIX Excel file                          | Dev baseline       |
| v0.4    | 2026-02-27 | Excel-only import pipeline; removed JSON ingestion; dynamic root detection | Python importers v1                      | Dev baseline       |
| v0.5    | 2026-02-27 | Schema v2: generated `amount` column; `decimal_places` rename; `currency_code` removed from `ledger`; `voided_at`; `reversed_by_tx_id`; RLS policies; `audit_log` + trigger | Full v2 schema | Stable |
| v0.6    | 2026-02-27 | `001_roles_setup.pgsql`: `mab_owner`, `mab_app`, `mab_readonly`, `mab_auditor` | Role-based access control + audit hardening | Stable |
| v0.7    | 2026-03-01 | Python importer v2: `coa_importer_script.py` reads metadata from Excel Meta sheet; `iso4217_importer_script.py` partial-index ON CONFLICT fix | Cross-platform import pipeline v2 | Current |

---

## Key Schema Changes by Version

### v0.5 — Schema v2 highlights

**[V2-P1-A]** Removed duplicate `commodity_namespace_mnemonic_uq` index; only the partial `_ux` index retained.

**[V2-P1-B]** `ledger.currency_commodity_id` → `NOT NULL`, FK `ON DELETE RESTRICT`.

**[V2-P1-C]** `transaction.currency_commodity_id` → `NOT NULL`, FK `ON DELETE RESTRICT`.

**[V2-P2-A]** `split.amount` → `GENERATED ALWAYS AS (ABS(value_num) / NULLIF(value_denom, 0)) STORED`. Eliminates staleness risk.

**[V2-P2-B]** `ledger.currency_code` removed; derived via `v_ledger` view.

**[V2-P2-C]** `coa_template.deleted_at` added for soft-delete support.

**[V2-P2-D]** `recurrence.period_type` and `weekend_adjust` validated via CHECK constraints.

**[V2-P2-E]** Performance indexes on `split`, `transaction`, `account`, `payee`, `scheduled_transaction`, `price`, `auth_identity`.

**[V2-P2-F]** `instantiate_coa_template()` deprecated — raises exception directing callers to the replacement.

**[V3-P3-A]** `ledger.decimal_places` renamed from `precision` (reserved word conflict mitigation).

**[V3-P3-B]** Named constraint `ledger_owner_id_not_null1` removed; column-level `NOT NULL` used.

**[V3-P3-C]** `transaction.reversed_by_tx_id` added for reversal traceability.

**[V3-P3-D]** `transaction.voided_at` added with consistency CHECK (`voided_at IS NOT NULL` iff `is_voided = true`).

**[V3-P4-A]** Row-Level Security (RLS) policies defined on all tenant-scoped tables.

**[V3-P4-B]** `audit_log` table + `mab_audit_trigger()` (`SECURITY DEFINER`) — append-only compliance trail.

### v0.7 — Python importer v2 highlights

- `coa_importer_script.py` now reads template metadata (code, name, country, etc.) from a dedicated **Meta sheet** inside the Excel workbook. CLI `--template-*` arguments remain available as overrides.
- `iso4217_importer_script.py` fixes `ON CONFLICT` targeting the partial unique index (`WHERE deleted_at IS NULL`). Soft-deleted rows are restored in-place before the upsert to prevent duplicate-row edge cases.
