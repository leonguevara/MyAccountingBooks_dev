# Excel-Based Import Pipeline

**Last updated:** 2026-03-01  
**Scripts:** `Python scripts/Final/`

---

## Overview

All external data flows through Python-based importers. psql `\copy` meta-commands are not used in production or CI/CD because of cross-platform quoting issues (see [PSQL Postmortem](PSQL_Postmortem.md)).

The pipeline covers two data sources:

1. **ISO 4217 currencies** — downloaded from the SIX Group and imported into `commodity`
2. **COA templates** — imported from Excel workbooks into `coa_template` + `coa_template_node`

---

## Script 1: ISO 4217 Currency Import

### Download

**Script:** `download_iso4217_current_to_excel.py`

Downloads the official SIX Group "List One" (current currencies and funds) as an `.xls` file, auto-detects the header row, normalizes column names, and exports a clean `.xlsx` and `.csv`.

```bash
python "Python scripts/Final/download_iso4217_current_to_excel.py"
# Outputs: iso4217_current_list_one.xlsx, iso4217_current_list_one.csv
```

**Column detection** (flexible, handles SIX format variations):

| Detected column       | Mapped to                    |
|-----------------------|------------------------------|
| Alphabetic Code       | `mnemonic`                   |
| Numeric Code          | informational only           |
| Minor Unit            | `fraction = 10 ^ minor_unit` |
| Currency              | prefix of `full_name`        |
| Entity                | suffix of `full_name`        |

---

### Import

**Script:** `iso4217_importer_script.py` (v2)

```bash
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel iso4217_current_list_one.xlsx \
  --namespace CURRENCY \
  --na-fraction 100 \
  --do-deactivate-missing 0
```

**Arguments:**

| Argument               | Default    | Description                                                       |
|------------------------|------------|-------------------------------------------------------------------|
| `--dsn`                | required   | psycopg v3 connection string                                      |
| `--excel`              | required   | Path to ISO 4217 Excel file                                       |
| `--sheet`              | first sheet | Sheet name override                                              |
| `--namespace`          | `CURRENCY` | Commodity namespace                                               |
| `--na-fraction`        | `100`      | Fraction to use when `minor_unit` is N.A. or missing              |
| `--do-deactivate-missing` | `0`     | Set to `1` to deactivate currencies absent from this import       |

**Upsert logic:**

- `ON CONFLICT (namespace, mnemonic) WHERE deleted_at IS NULL` — targets the partial unique index
- Soft-deleted rows matching the import are first restored (`deleted_at = NULL`) before the upsert runs, preventing duplicate-row edge cases
- `fraction = 10 ^ minor_unit` (e.g. `minor_unit = 2` → `fraction = 100`)

---

## Script 2: COA Template Import

**Script:** `coa_importer_script.py` (v2)

### Excel Workbook Structure

The importer expects an Excel file with two sheets:

#### Sheet 1 — "Meta" (required)

A two-column sheet with **Key** and **Value** columns. Supported keys:

| Key         | Example                                   |
|-------------|-------------------------------------------|
| `code`      | `PERSONALES_2026`                         |
| `name`      | `Personal Chart of Accounts 2026`         |
| `description` | `Personal chart of accounts for 2026`  |
| `country`   | `MX`                                      |
| `locale`    | `es-MX`                                   |
| `industry`  | `personal` (or blank for NULL)            |
| `version`   | `1`                                       |

An optional header row (`key`, `field`, etc.) is auto-detected and skipped.

#### Sheet 2 — Nodes (default: first sheet)

Flexible column detection. Supported column names (case-insensitive):

| Column              | Detected aliases                                       |
|---------------------|--------------------------------------------------------|
| Code                | `code`, `Code`                                         |
| Parent Code         | `parent_code`, `Parent`, `parent`, `ParentCode`        |
| Level               | `level`, `Level`                                       |
| Name                | `name`, `Name`                                         |
| Kind                | `kind`, `Kind`                                         |
| Role                | `role`, `Role`                                         |
| Is Placeholder      | `is_placeholder`, `Placeholder`, `IsPlaceholder`       |
| Account Type Code   | `account_type_code`, `Account_Type`, `Type`, `AccountTypeCode` |

**Root detection:** rows where `level = 0` are treated as root nodes and their `parent_code` is forced to `NULL`.

---

### Usage

```bash
# All metadata from Excel:
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --excel "Personales_2026.xlsx"

# Override version from CLI (without editing the workbook):
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "..." \
  --excel "Personales_2026.xlsx" \
  --template-version 2

# Specify sheet names explicitly:
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "..." \
  --excel "MyTemplate.xlsx" \
  --meta-sheet "Metadata" \
  --sheet "Cuentas"
```

**CLI arguments:**

| Argument               | Required | Description                                                         |
|------------------------|----------|---------------------------------------------------------------------|
| `--dsn`                | Yes      | psycopg v3 connection string                                        |
| `--excel`              | Yes      | Path to Excel workbook                                              |
| `--meta-sheet`         | No       | Meta sheet name (default: `Meta`)                                   |
| `--sheet`              | No       | Node sheet name (default: first sheet)                              |
| `--template-code`      | No       | Override `code` from Meta sheet                                     |
| `--template-name`      | No       | Override `name`                                                     |
| `--template-description` | No     | Override `description`                                              |
| `--template-country`   | No       | Override `country`                                                  |
| `--template-locale`    | No       | Override `locale`                                                   |
| `--template-industry`  | No       | Override `industry`                                                 |
| `--template-version`   | No       | Override `version`                                                  |

**Upsert logic:**

- Template: `ON CONFLICT (code, version) DO UPDATE` — updates all metadata fields
- Nodes: `ON CONFLICT (template_id, code) DO UPDATE` — updates all node fields including `account_type_code`

---

## Error Handling

Both scripts wrap all database operations in a single transaction. On any error:

- The transaction is rolled back.
- A descriptive error message is printed to stderr.
- Exit code `1` is returned (CI/CD-safe).

Validation errors (missing columns, empty sheets, missing metadata) raise before touching the database.

---

## Extending the Pipeline

To import multiple templates in a batch:

```bash
for f in templates/*.xlsx; do
  python "Python scripts/Final/coa_importer_script.py" \
    --dsn "$DSN" \
    --excel "$f"
done
```

A unified `import_all.py` runner (ISO 4217 + crypto seeds + all templates in one pass) can be added as a future improvement.
