-- 015_import_iso4217_to_commodity_with_sync_v2.sql
-- Fix for: "there is no unique or exclusion constraint matching the ON CONFLICT specification"
--
-- Root cause:
--   ON CONFLICT (namespace, mnemonic) requires a UNIQUE CONSTRAINT or a UNIQUE INDEX
--   that matches exactly those columns WITHOUT a predicate.
--   A partial unique index like (namespace, mnemonic) WHERE deleted_at IS NULL will NOT match.
--
-- This version creates a non-partial UNIQUE index on (namespace, mnemonic) and uses it for UPSERT.
-- Soft-delete behavior is preserved by "restoring" rows (deleted_at = NULL) on upsert.

\set ON_ERROR_STOP on
ROLLBACK;

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
\copy _stg_iso4217(alphabetic_code, numeric_code, minor_unit, currency, entity)  FROM '/Users/l00792192/Documents/dev/tmp/iso4217_current_list_one.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

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
    COALESCE(full_name, 'No Name') AS full_name,
    CASE
      WHEN minor_unit_txt ~ '^[0-9]+(\.0)?$'
        THEN (10 ^ (regexp_replace(minor_unit_txt, '\\.0$', '')::int))::int
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

-- 3) Upsert + sync (deactivate missing)
BEGIN;

-- Upsert / restore
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

-- Deactivate currencies that are NOT in the latest list
UPDATE commodity c
SET
  is_active  = FALSE,
  deleted_at = COALESCE(c.deleted_at, now()),
  updated_at = now(),
  revision   = c.revision + 1
WHERE
  c.namespace = 'CURRENCY'
  AND c.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM _stg_iso4217_norm n WHERE n.mnemonic = c.mnemonic
  );

COMMIT;

-- 4) Sanity checks
\echo '== ISO 4217 sync done =='
SELECT COUNT(*) AS active_currencies
FROM commodity
WHERE namespace='CURRENCY' AND deleted_at IS NULL AND is_active = TRUE;

SELECT mnemonic, full_name, fraction
FROM commodity
WHERE namespace='CURRENCY' AND mnemonic IN ('MXN','USD','EUR','JPY')
ORDER BY mnemonic;
