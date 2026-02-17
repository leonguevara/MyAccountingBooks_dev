-- ============================================================
-- Import CoA JSON into coa_template + coa_template_node
-- This script is intended to be run with psql.
-- ============================================================

\set ON_ERROR_STOP on

-- Parameters you can edit:
\set TEMPLATE_CODE 'MX_SAT_STD'
\set TEMPLATE_NAME 'Mexico SAT (Standard)'
\set TEMPLATE_VERSION '2026.01'
\set TEMPLATE_COUNTRY 'MX'
\set TEMPLATE_LOCALE 'es-MX'
\set TEMPLATE_INDUSTRY 'general'
\set TEMPLATE_DESCRIPTION 'Imported from JSON chart of accounts'

-- 1) Create template row (or reuse if it already exists).
WITH upsert AS (
  INSERT INTO coa_template (code, name, description, country, locale, industry, version)
  VALUES (:'TEMPLATE_CODE', :'TEMPLATE_NAME', :'TEMPLATE_DESCRIPTION',
          :'TEMPLATE_COUNTRY', :'TEMPLATE_LOCALE', :'TEMPLATE_INDUSTRY', :'TEMPLATE_VERSION')
  ON CONFLICT (code, version)
  DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    country = EXCLUDED.country,
    locale = EXCLUDED.locale,
    industry = EXCLUDED.industry,
    updated_at = now()
  RETURNING id
)
SELECT id AS template_id FROM upsert \gset

-- 2) Staging table to load the JSON array.
DROP TABLE IF EXISTS coa_json_stage;
CREATE TEMP TABLE coa_json_stage (doc jsonb NOT NULL);

-- 3) Load the JSON file into staging.
-- Replace the path with your local path.
\copy coa_json_stage(doc) FROM 'chart_of_accounts.json';

-- 4) Insert nodes.
-- Expected JSON format: an array of objects with keys:
-- code, parentCode, name, level, kind, role, isPlaceholder
INSERT INTO coa_template_node (
  template_id, code, parent_code, name, level, kind, role, is_placeholder
)
SELECT
  :'template_id'::uuid AS template_id,
  (n->>'code')::text AS code,
  NULLIF(n->>'parentCode','')::text AS parent_code,
  (n->>'name')::text AS name,
  (n->>'level')::int AS level,
  (n->>'kind')::smallint AS kind,
  (n->>'role')::smallint AS role,
  COALESCE((n->>'isPlaceholder')::boolean, false) AS is_placeholder
FROM (
  SELECT jsonb_array_elements(doc) AS n
  FROM coa_json_stage
) s
ON CONFLICT (template_id, code)
DO UPDATE SET
  parent_code = EXCLUDED.parent_code,
  name = EXCLUDED.name,
  level = EXCLUDED.level,
  kind = EXCLUDED.kind,
  role = EXCLUDED.role,
  is_placeholder = EXCLUDED.is_placeholder,
  updated_at = now();

-- 5) Basic sanity check.
SELECT COUNT(*) AS imported_nodes
FROM coa_template_node
WHERE template_id = :'template_id'::uuid;

-- Remember to run the following CLI statement
-- /Library/PostgreSQL/18/bin/psql -U myaccounting_user -d myaccounting_dev -f import_coa.sql
-- JSON file must reside in the script's same path
