Done — I updated **both attached `.pgsql` pipelines** to use **dynamic `\copy` via `\gexec`**, and I also generated **Python importers** for both workflows (ISO4217 → `commodity`, and COA template JSON → `coa_template` / `coa_template_node`).

## 1) Updated SQL scripts (dynamic `\copy` with `\gexec`)

### ISO4217 → `commodity` (patched)

* Replaces the fragile `\copy ... FROM :'csv_path'` with a `SELECT format(... %L ...) \gexec` pattern.

[Download 002_import_iso4217_to_commodity_with_sync_gexec.pgsql](sandbox:/mnt/data/002_import_iso4217_to_commodity_with_sync_gexec.pgsql)

### Generic COA template pipeline (patched)

* Replaces `\copy ... FROM PROGRAM ... :'json_file'` with `\gexec` + `format(%L)` so the file path is safely quoted.
* **Note:** still requires `jq` in PATH (use the Python version if you don’t want jq / you’re on Windows without it).

[Download 004_generic_import_coa_template_pipeline_gexec.pgsql](sandbox:/mnt/data/004_generic_import_coa_template_pipeline_gexec.pgsql)

---

## 2) Python importers (cross-platform, no `\copy` quirks)

### A) ISO4217 CSV → `commodity`

* Reads the CSV
* Computes `fraction = 10 ** minor_unit` (uses `--na-fraction` when minor_unit is missing / N.A.)
* UPSERTs by `(namespace, mnemonic)`
* Optional: deactivate missing currencies for that namespace

[Download import_iso4217_to_commodity.py](sandbox:/mnt/data/import_iso4217_to_commodity.py)

**Run example**

```bash
pip install psycopg[binary]
python import_iso4217_to_commodity.py \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --csv "C:/tmp/iso4217_current_list_one.csv" \
  --namespace CURRENCY \
  --default-fraction 100 \
  --na-fraction 100 \
  --deactivate-missing
```

### B) COA template JSON → `coa_template` / `coa_template_node`

* Loads the normalized JSON array
* Upserts `coa_template` by `(code, version)`
* Upserts nodes by `(template_id, code)`
* Uses `account_type_code` as expected by your current pipeline

[Download import_coa_template_from_json.py](sandbox:/mnt/data/import_coa_template_from_json.py)

**Run example**

```bash
pip install psycopg[binary]
python import_coa_template_from_json.py \
  --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
  --template-code PERSONALES_2026 \
  --template-name "Personal Chart of Accounts 2026" \
  --template-description "Personal chart of accounts (Mexico-oriented) for 2026" \
  --template-country MX \
  --template-locale es-MX \
  --template-industry NULL \
  --template-version 1 \
  --json "C:/tmp/Personales_2026_normalized_for_import_with_account_type_code.json"
```

---

## Practical summary / action plan

1. If you want to stay in **psql-only pipelines**, use the new `_gexec.pgsql` scripts.
2. If you want the most reliable cross-platform automation (and easiest batching), use the Python scripts.
3. For importing **many files**, Python is the cleanest path (loop folders, log failures, CI/CD friendly).

If you want, I can also add:

* “import a whole folder” mode to each Python script, and/or
* a unified `import_all.py` runner that imports ISO4217 + crypto seeds + templates in a single pass.
