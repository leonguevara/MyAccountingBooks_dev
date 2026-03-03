-- 015_import_iso4217_to_commodity_with_sync_v2.sql
-- Generic/parameterized ISO4217 -> commodity importer (UPSERT + optional sync deactivate).
--
-- Usage examples:
--   psql -d your_db -f "SQL Scripts/002_import_iso4217_to_commodity_with_sync_gexec.pgsql"
--   psql -d your_db \
--     -v "csv_path=/absolute/path/iso4217_current_list_one.csv" \
--     -v "namespace=CURRENCY" \
--     -v "default_fraction=100" \
--     -v "na_fraction=100" \
--     -v "do_deactivate_missing=1" \
--     -f "SQL Scripts/002_import_iso4217_to_commodity_with_sync_gexec.pgsql"

\set ON_ERROR_STOP on
ROLLBACK;

-- Parameters (can be overridden with: psql -v key=value)
\if :{?csv_path}
\else
\set csv_path /Users/l00792192/Documents/dev/tmp/iso4217_current_list_one.csv
\endif

\if :{?namespace}
\else
\set namespace CURRENCY
\endif

\if :{?default_full_name}
\else
\set default_full_name 'No Name'
\endif

\if :{?default_fraction}
\else
\set default_fraction 100
\endif

\if :{?na_fraction}
\else
\set na_fraction 100
\endif

\if :{?do_deactivate_missing}
\else
\set do_deactivate_missing 1
\endif

-- 0) Ensure the required UNIQUE index exists (non-partial).
--    NOTE: If you already have a partial index named commodity_namespace_mnemonic_ux,
--    it can stay, but it won't be used by ON CONFLICT. This index is the one that matters.
BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_uq
ON commodity(namespace, mnemonic);
COMMIT;

-- 1) Stage CSV
DROP TABLE IF EXISTS _stg_iso4217;
CREATE TEMP TABLE _stg_iso4217 (
  alphabetic_code text,
  numeric_code    text,
  minor_unit      text,
  currency        text,
  entity          text
);

-- >>> EDIT THIS PATH (absolute) <<<
-- Use a literal path in \copy (most robust across terminals/pgAdmin)
-- Robust dynamic \copy (works across macOS/Windows) using \gexec + format(%L).
SELECT format(E'\copy _stg_iso4217(alphabetic_code, numeric_code, minor_unit, currency, entity) FROM %L WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')', :'csv_path') \gexec

-- 2) Normalize to a distinct set
DROP TABLE IF EXISTS _stg_iso4217_norm;
CREATE TEMP TABLE _stg_iso4217_norm AS
WITH cleaned AS (
  SELECT
    upper(trim(alphabetic_code)) AS mnemonic,
    NULLIF(trim(currency), '')   AS full_name,
    NULLIF(trim(minor_unit), '') AS minor_unit_txt
  FROM _stg_iso4217
  WHERE alphabetic_code IS NOT NULL
),
typed AS (
  SELECT
    mnemonic,
    COALESCE(full_name, :'default_full_name') AS full_name,
    CASE
      WHEN minor_unit_txt ~ '^[0-9]+(\.0)?$'
        THEN (10 ^ (regexp_replace(minor_unit_txt, '\\.0$', '')::int))::int
      WHEN minor_unit_txt ILIKE 'N.A%' THEN :na_fraction::int
      WHEN minor_unit_txt IS NULL THEN :default_fraction::int
      ELSE :default_fraction::int
    END AS fraction
  FROM cleaned
  WHERE mnemonic ~ '^[A-Z]{3}$'
)
SELECT DISTINCT ON (mnemonic)
  mnemonic, full_name, fraction
FROM typed
ORDER BY mnemonic;

-- 3) Upsert + sync (deactivate missing)
BEGIN;

-- Upsert / restore
INSERT INTO commodity (mnemonic, namespace, full_name, fraction, is_active, created_at, updated_at, revision, deleted_at)
SELECT
  n.mnemonic,
  :'namespace'::text,
  n.full_name,
  n.fraction,
  TRUE,
  now(),
  now(),
  0,
  NULL
FROM _stg_iso4217_norm n
ON CONFLICT (namespace, mnemonic)
DO UPDATE SET
  full_name  = EXCLUDED.full_name,
  fraction   = EXCLUDED.fraction,
  is_active  = TRUE,
  updated_at = now(),
  revision   = commodity.revision + 1,
  deleted_at = NULL;

-- Optional deactivate for rows not present in the latest source
\if :do_deactivate_missing
UPDATE commodity c
SET
  is_active  = FALSE,
  deleted_at = COALESCE(c.deleted_at, now()),
  updated_at = now(),
  revision   = c.revision + 1
WHERE
  c.namespace = :'namespace'
  AND c.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM _stg_iso4217_norm n WHERE n.mnemonic = c.mnemonic
  );
\else
\echo 'Skipping deactivate_missing step (do_deactivate_missing=0)'
\endif

COMMIT;

-- 4) Sanity checks
\echo '== ISO 4217 sync done =='
SELECT COUNT(*) AS active_currencies
FROM commodity
WHERE namespace = :'namespace' AND deleted_at IS NULL AND is_active = TRUE;

SELECT mnemonic, full_name, fraction
FROM commodity
WHERE namespace = :'namespace'
ORDER BY mnemonic;
