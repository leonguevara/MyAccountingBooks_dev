\
-- 030_import_iso4217_to_commodity_with_sync.sql
-- Import ISO 4217 "List One" CSV into public.commodity and deactivate currencies not present.
--
-- Input CSV columns expected (header-based):
--   alphabetic_code,numeric_code,minor_unit,currency,entity,(optional withdrawal_date,remarks...)
--
-- Mapping to commodity:
--   namespace   = 'CURRENCY'
--   mnemonic    = alphabetic_code (upper)
--   full_name   = currency
--   fraction    = 10^minor_unit (0->1, 2->100, 3->1000). If N.A./blank -> 100 (conservative default)
--
-- Deactivation mechanism:
--   After upsert, any existing commodity rows (namespace='CURRENCY') whose mnemonic is NOT present
--   in the imported CSV will be marked:
--       is_active = false
--       deleted_at = now()   (soft-delete)
--       revision += 1
--
-- Safety:
--   - Uses a partial UNIQUE index to allow ON CONFLICT (namespace, mnemonic) for active rows.
--   - Soft delete avoids breaking references; FKs use ON DELETE SET NULL if you ever hard-delete.
--
-- Run in psql or pgAdmin "PSQL Tool" (because of \copy).
-- If pgAdmin chokes on variables in \copy, use the hardcoded \copy line provided below.
--
-- 1) Edit CSV_PATH, then run:
--    \i /path/to/this_script.sql

\set ON_ERROR_STOP on

-- Clear aborted state if any:
ROLLBACK;

BEGIN;

-- Recommended uniqueness to support UPSERT.
-- NOTE: If you already created it, this is a no-op.
CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_ux
ON commodity(namespace, mnemonic)
WHERE deleted_at IS NULL;

COMMIT;

-- ---------- Stage CSV ----------
DROP TABLE IF EXISTS _stg_iso4217;
CREATE TEMP TABLE _stg_iso4217 (
  alphabetic_code text,
  numeric_code    text,
  minor_unit      text,
  currency        text,
  entity          text
);

-- >>> EDIT THIS PATH (absolute) <<<
\set CSV_PATH '/Users/l00792192/Documents/dev/tmp/iso4217_current_list_one.csv'

\echo Loading ISO 4217 CSV from :CSV_PATH

-- Preferred (works in psql). If pgAdmin errors, comment this and use the hardcoded version below.
\copy _stg_iso4217(alphabetic_code, numeric_code, minor_unit, currency, entity)
FROM :'CSV_PATH'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Hardcoded fallback example:
-- \copy _stg_iso4217(alphabetic_code, numeric_code, minor_unit, currency, entity)
-- FROM '/Users/<you>/Documents/dev/tmp/iso4217_current_list_one.csv'
-- WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------- Normalize into a distinct set ----------
DROP TABLE IF EXISTS _stg_iso4217_norm;
CREATE TEMP TABLE _stg_iso4217_norm AS
WITH cleaned AS (
  SELECT
    upper(trim(alphabetic_code)) AS mnemonic,
    NULLIF(trim(currency), '')   AS full_name,
    NULLIF(trim(minor_unit), '') AS minor_unit_txt,
    NULLIF(trim(entity), '')     AS entity
  FROM _stg_iso4217
  WHERE alphabetic_code IS NOT NULL
),
typed AS (
  SELECT
    mnemonic,
    COALESCE(full_name, 'No Name') AS full_name,
    CASE
      WHEN minor_unit_txt ~ '^[0-9]+(\.0)?$' THEN (10 ^ (regexp_replace(minor_unit_txt, '\.0$', '')::int))::int
      WHEN minor_unit_txt ILIKE 'N.A%' THEN 100
      WHEN minor_unit_txt IS NULL THEN 100
      ELSE 100
    END AS fraction
  FROM cleaned
  WHERE mnemonic ~ '^[A-Z]{3}$'
)
SELECT DISTINCT ON (mnemonic)
  mnemonic, full_name, fraction
FROM typed
ORDER BY mnemonic;

-- ---------- Upsert + Deactivate in one transaction ----------
BEGIN;

-- Upsert/restore
INSERT INTO commodity (mnemonic, namespace, full_name, fraction, is_active, created_at, updated_at, revision, deleted_at)
SELECT
  n.mnemonic,
  'CURRENCY'::text,
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

-- Deactivate currencies not present in the latest import
UPDATE commodity c
SET
  is_active  = FALSE,
  deleted_at = COALESCE(c.deleted_at, now()),
  updated_at = now(),
  revision   = c.revision + 1
WHERE
  c.namespace = 'CURRENCY'
  AND c.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM _stg_iso4217_norm n
    WHERE n.mnemonic = c.mnemonic
  );

COMMIT;

-- ---------- Sanity checks ----------
\echo '== ISO 4217 import done =='
SELECT COUNT(*) AS active_currencies
FROM commodity
WHERE namespace='CURRENCY' AND deleted_at IS NULL AND is_active = TRUE;

SELECT mnemonic, full_name, fraction
FROM commodity
WHERE namespace='CURRENCY' AND mnemonic IN ('MXN','USD','EUR','JPY')
ORDER BY mnemonic;
