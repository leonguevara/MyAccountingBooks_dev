-- 020_import_personales_2026_psql_fixed_v4.sql
-- pgAdmin PSQL Tool compatible import (NO psql variables inside \copy).
--
-- You MUST edit the JSON_PATH below (absolute path).
-- This script hardcodes the path directly into the \copy ... FROM PROGRAM command
-- to avoid pgAdmin/psql parsing issues with ':' variable expansion.
--
-- Requirements:
--   brew install jq
--   CREATE EXTENSION IF NOT EXISTS pgcrypto;

\set ON_ERROR_STOP on

ROLLBACK;

\echo == Importing PERSONALES_2026 template ==
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Create or update template (unique: code+version)
INSERT INTO coa_template (id, code, name, description, country, locale, industry, version, is_active, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'PERSONALES_2026',
  'Personal Chart of Accounts 2026',
  'Personal chart of accounts (Mexico-oriented) for 2026',
  'MX',
  'es-MX',
  NULL,
  'v1',
  TRUE,
  now(),
  now()
)
ON CONFLICT (code, version)
DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  country = EXCLUDED.country,
  locale = EXCLUDED.locale,
  is_active = EXCLUDED.is_active,
  updated_at = now()
RETURNING id AS template_id \gset

\echo Template id: :template_id

-- 2) Load JSON into staging
DROP TABLE IF EXISTS _stg_raw;
CREATE TEMP TABLE _stg_raw (payload jsonb NOT NULL);

-- >>> EDIT THIS LINE <<<
-- Example:
--   \set JSON_PATH /Users/l00792192/Documents/dev/tmp/Personales_2026_normalized_for_import.json
\set JSON_PATH /Users/l00792192/Documents/dev/tmp/Personales_2026_normalized_for_import.json

\echo Loading JSON from :JSON_PATH

-- IMPORTANT:
-- - We wrap the file path in double quotes inside the command, so paths with spaces work.
-- - We do NOT use :'var' inside \copy (pgAdmin PSQL Tool can choke on it).
\copy _stg_raw(payload) FROM '/Users/l00792192/Documents/dev/tmp/Personales_2026.ndjson'

-- 3) Parse payload into typed staging
DROP TABLE IF EXISTS _stg_nodes;
CREATE TEMP TABLE _stg_nodes (
  code           text PRIMARY KEY,
  parent_code    text NULL,
  name           text NOT NULL,
  level          integer NOT NULL,
  kind           smallint NOT NULL,
  role           smallint NOT NULL,
  is_placeholder boolean NOT NULL
);

INSERT INTO _stg_nodes (code, parent_code, name, level, kind, role, is_placeholder)
SELECT
  NULLIF(payload->>'code','')                            AS code,
  NULLIF(payload->>'parent_code','')                     AS parent_code,
  COALESCE(NULLIF(payload->>'name',''), 'No Name')       AS name,
  COALESCE((payload->>'level')::int, 0)                  AS level,
  COALESCE((payload->>'kind')::smallint, 0)              AS kind,
  COALESCE((payload->>'role')::smallint, 0)              AS role,
  COALESCE((payload->>'is_placeholder')::boolean, FALSE) AS is_placeholder
FROM _stg_raw;

-- 4) Insert / upsert nodes
INSERT INTO coa_template_node
(id, template_id, code, parent_code, name, level, kind, role, is_placeholder, created_at, updated_at)
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
  updated_at = now();

COMMIT;
\echo == Done. Imported/updated nodes for PERSONALES_2026 ==
