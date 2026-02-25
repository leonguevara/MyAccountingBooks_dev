-- 004_generic_import_coa_template_pipeline.pgsql
-- Generic script to import COA template nodes from a normalized JSON file into PostgreSQL.
-- This eliminates the need for separate import scripts for each catalog.
--
-- IMPORTANT:
--   This pipeline version expects coa_template_node.account_type_code to exist.
--
-- Run in psql (terminal or pgAdmin "PSQL Tool"):
--   psql mydb -v template_code='PERSONALES_2026' \
--             -v template_name='Personal Chart of Accounts 2026' \
--             -v template_description='Personal chart of accounts (Mexico-oriented) for 2026' \
--             -v json_file='Personales_2026_normalized_for_import_with_account_type_code.json' \
--             -f 004_generic_import_coa_template_pipeline.pgsql
--
-- Requirements:
--   - jq installed (macOS: brew install jq)
--   - pgcrypto extension (for gen_random_uuid())
--
-- REQUIRED psql variables:
--   - template_code:        Unique template identifier (e.g., 'PERSONALES_2026', 'SAT_2025')
--   - template_name:        Human-readable template name
--   - template_description: Detailed description of the template
--   - json_file:            Path to JSON file or filename (if in current directory)
--
-- OPTIONAL psql variables (defaults provided):
--   - template_country:     Country code (default: 'MX')
--   - template_locale:      Locale code (default: 'es-MX')
--   - template_industry:    Industry designation (default: NULL)
--   - template_version:     Version identifier (default: 'v1')
--
-- Example with all parameters:
--   psql mydb -v template_code='SAT_2025' \
--             -v template_name='SAT 2025 Business COA' \
--             -v template_description='SAT agrupador-based business COA, 2025 edition' \
--             -v template_country='MX' \
--             -v template_locale='es-MX' \
--             -v template_industry='NULL' \
--             -v template_version='v1' \
--             -v json_file='SAT_2025_normalized_for_import_with_account_type_code.json' \
--             -f 004_generic_import_coa_template_pipeline.pgsql

\set ON_ERROR_STOP on

-- If a previous run aborted inside a transaction, clear it:
ROLLBACK;

-- Validate required parameters
\if :{?template_code}
\else
  \echo 'ERROR: template_code is required. Set via: psql ... -v template_code=''VALUE'' ...'
  \q
\endif

\if :{?template_name}
\else
  \echo 'ERROR: template_name is required. Set via: psql ... -v template_name=''VALUE'' ...'
  \q
\endif

\if :{?template_description}
\else
  \echo 'ERROR: template_description is required. Set via: psql ... -v template_description=''VALUE'' ...'
  \q
\endif

\if :{?json_file}
\else
  \echo 'ERROR: json_file is required. Set via: psql ... -v json_file=''VALUE'' ...'
  \q
\endif

-- Set optional parameters with defaults
\if :{?template_country}
\else
  \set template_country 'MX'
\endif

\if :{?template_locale}
\else
  \set template_locale 'es-MX'
\endif

-- template_industry is allowed to be NULL, so we use a placeholder
\if :{?template_industry}
\else
  \set template_industry 'NULL'
\endif

\if :{?template_version}
\else
  \set template_version 'v1'
\endif

\echo '== Importing template: :'template_code' =='

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------------
-- 1) Create or fetch the template row (coa_template)
-- Columns:
--   id, code, name, description, country, locale, industry, version, is_active, created_at, updated_at
-- Unique: (code, version)
-- -------------------------------------------------------------------

INSERT INTO coa_template (id, code, name, description, country, locale, industry, version, is_active, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  :'template_code',
  :'template_name',
  :'template_description',
  :'template_country',
  :'template_locale',
  NULLIF(:'template_industry', 'NULL'),
  :'template_version',
  TRUE,
  now(),
  now()
)
ON CONFLICT (code, version)
DO UPDATE SET
  name = EXCLUDED.name,
  description = COALESCE(EXCLUDED.description, coa_template.description),
  country = COALESCE(EXCLUDED.country, coa_template.country),
  locale = COALESCE(EXCLUDED.locale, coa_template.locale),
  industry = COALESCE(EXCLUDED.industry, coa_template.industry),
  is_active = EXCLUDED.is_active,
  updated_at = now()
RETURNING id AS template_id \gset

\echo 'Template id: :'template_id

-- -------------------------------------------------------------------
-- 2) Load JSON -> staging
-- JSON must be an array of objects with keys:
--   code, parent_code, level, name, kind, role, is_placeholder, account_type_code
-- -------------------------------------------------------------------

DROP TABLE IF EXISTS _stg_raw;
CREATE TEMP TABLE _stg_raw (payload jsonb NOT NULL);

\echo 'Loading JSON from :'json_file
-- Robust dynamic \copy FROM PROGRAM (jq) using \gexec + format(%L).
-- NOTE: Requires jq in PATH. Use the Python importer if jq is not available on Windows.
SELECT format(E'\\copy _stg_raw(payload) FROM PROGRAM %L', 'jq -c ''.[]'' \"' || :'json_file' || '\"') \gexec

DROP TABLE IF EXISTS _stg_nodes;
CREATE TEMP TABLE _stg_nodes (
  code              text PRIMARY KEY,
  parent_code       text NULL,
  name              text NOT NULL,
  level             integer NOT NULL,
  kind              smallint NOT NULL,
  role              smallint NOT NULL,
  is_placeholder    boolean NOT NULL,
  account_type_code text NULL
);

INSERT INTO _stg_nodes (code, parent_code, name, level, kind, role, is_placeholder, account_type_code)
SELECT
  NULLIF(payload->>'code','')                            AS code,
  NULLIF(payload->>'parent_code','')                     AS parent_code,
  COALESCE(NULLIF(payload->>'name',''), 'No Name')       AS name,
  COALESCE((payload->>'level')::int, 0)                  AS level,
  COALESCE((payload->>'kind')::smallint, 0)              AS kind,
  COALESCE((payload->>'role')::smallint, 0)              AS role,
  COALESCE((payload->>'is_placeholder')::boolean, FALSE) AS is_placeholder,
  NULLIF(payload->>'account_type_code','')               AS account_type_code
FROM _stg_raw;

-- -------------------------------------------------------------------
-- 2b) Validations
-- -------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM _stg_nodes WHERE code IS NULL) THEN
    RAISE EXCEPTION 'Import failed: at least one node has NULL/empty code.';
  END IF;

  IF EXISTS (SELECT 1 FROM _stg_nodes WHERE level < 0) THEN
    RAISE EXCEPTION 'Import failed: level < 0 found (violates coa_template_node_level_check).';
  END IF;

  -- Non-placeholder nodes must have account_type_code
  IF EXISTS (SELECT 1 FROM _stg_nodes WHERE NOT is_placeholder AND account_type_code IS NULL) THEN
    RAISE EXCEPTION 'Import failed: non-placeholder nodes missing account_type_code.';
  END IF;

  -- account_type_code must exist in account_type (and not be soft-deleted)
  IF EXISTS (
    SELECT 1
    FROM _stg_nodes n
    WHERE n.account_type_code IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.account_type at
        WHERE at.code = n.account_type_code
          AND at.deleted_at IS NULL
      )
  ) THEN
    RAISE EXCEPTION 'Import failed: at least one account_type_code does not exist in account_type.';
  END IF;
END $$;

-- -------------------------------------------------------------------
-- 3) Insert nodes (coa_template_node)
-- Columns:
--   id, template_id, code, parent_code, name, level, kind, role, is_placeholder, account_type_code, created_at, updated_at
-- Unique: (template_id, code)
-- -------------------------------------------------------------------

INSERT INTO coa_template_node
(id, template_id, code, parent_code, name, level, kind, role, is_placeholder, account_type_code, created_at, updated_at)
SELECT
  gen_random_uuid(),
  :'template_id'::uuid,
  n.code,
  n.parent_code,
  n.name,
  n.level,
  n.kind,
  n.role,
  n.is_placeholder,
  n.account_type_code,
  now(),
  now()
FROM _stg_nodes n
ORDER BY n.level, n.code
ON CONFLICT (template_id, code)
DO UPDATE SET
  parent_code = EXCLUDED.parent_code,
  name = EXCLUDED.name,
  level = EXCLUDED.level,
  kind = EXCLUDED.kind,
  role = EXCLUDED.role,
  is_placeholder = EXCLUDED.is_placeholder,
  account_type_code = EXCLUDED.account_type_code,
  updated_at = now();

COMMIT;

\echo '== Done. Imported/updated nodes for :'template_code' =='
