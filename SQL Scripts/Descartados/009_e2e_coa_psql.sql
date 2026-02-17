-- ============================================================
-- e2e_coa_psql.sql
-- End-to-end: DDL + Import JSON (file) + Validation + Ledger Instantiation
-- Intended to be run with psql.
-- ============================================================

\set ON_ERROR_STOP on

-- ---------------------------
-- Configuration
-- ---------------------------
\set TEMPLATE_CODE 'MX_SAT_STD'
\set TEMPLATE_NAME 'Mexico SAT (Standard)'
\set TEMPLATE_VERSION '2026.01'
\set TEMPLATE_COUNTRY 'MX'
\set TEMPLATE_LOCALE 'es-MX'
\set TEMPLATE_INDUSTRY 'general'
\set TEMPLATE_DESCRIPTION 'End-to-end import from JSON (psql)'

-- Path to your local JSON file (edit this)
\set JSON_FILE_PATH 'chart_of_accounts.json'

-- Dev seed
\set DEV_OWNER_EMAIL 'dev@example.com'
\set DEV_OWNER_PASSWORD_HASH 'DEV_ONLY_HASH'
\set DEV_OWNER_DISPLAY_NAME 'Dev User'
\set DEV_LEDGER_NAME 'Dev Ledger (E2E)'
\set DEV_LEDGER_CURRENCY 'MXN'
\set DEV_LEDGER_TEMPLATE 'SAT'
\set DEV_LEDGER_PRECISION 2

-- ---------------------------
-- Prereqs
-- ---------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------
-- DDL: Templates
-- ---------------------------
CREATE TABLE IF NOT EXISTS coa_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL,
  name        text NOT NULL,
  description text NULL,
  country     text NULL,
  locale      text NULL,
  industry    text NULL,
  version     text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (code, version)
);

CREATE TABLE IF NOT EXISTS coa_template_node (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id    uuid NOT NULL REFERENCES coa_template(id) ON DELETE CASCADE,
  code           text NOT NULL,
  parent_code    text NULL,
  name           text NOT NULL,
  level          integer NOT NULL CHECK (level >= 0),
  kind           smallint NOT NULL,
  role           smallint NOT NULL,
  is_placeholder boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (template_id, code)
);

CREATE INDEX IF NOT EXISTS idx_coa_node_template_parent
  ON coa_template_node(template_id, parent_code);

CREATE INDEX IF NOT EXISTS idx_coa_node_template_level
  ON coa_template_node(template_id, level);

CREATE INDEX IF NOT EXISTS idx_coa_node_template_code
  ON coa_template_node(template_id, code);

-- Link ledger -> template for traceability (safe if already exists)
ALTER TABLE ledger
  ADD COLUMN IF NOT EXISTS coa_template_id uuid NULL REFERENCES coa_template(id) ON DELETE SET NULL;

-- ---------------------------
-- Validation triggers (recommended)
-- ---------------------------
CREATE OR REPLACE FUNCTION trg_coa_node_parent_exists()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.parent_code IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM coa_template_node p
      WHERE p.template_id = NEW.template_id
        AND p.code = NEW.parent_code
    ) THEN
      RAISE EXCEPTION 'Invalid parent_code % for node % in template %',
        NEW.parent_code, NEW.code, NEW.template_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coa_node_parent_exists_insupd ON coa_template_node;
CREATE TRIGGER coa_node_parent_exists_insupd
BEFORE INSERT OR UPDATE OF parent_code, code, template_id
ON coa_template_node
FOR EACH ROW
EXECUTE FUNCTION trg_coa_node_parent_exists();

CREATE OR REPLACE FUNCTION trg_coa_node_level_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent_level int;
BEGIN
  IF NEW.parent_code IS NULL THEN
    IF NEW.level <> 0 THEN
      RAISE EXCEPTION 'Root node % must have level 0 (got %)', NEW.code, NEW.level;
    END IF;
    RETURN NEW;
  END IF;

  SELECT level INTO v_parent_level
  FROM coa_template_node
  WHERE template_id = NEW.template_id
    AND code = NEW.parent_code;

  IF NEW.level <> v_parent_level + 1 THEN
    RAISE EXCEPTION 'Level mismatch for node %: expected %, got %',
      NEW.code, v_parent_level + 1, NEW.level;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coa_node_level_consistency_insupd ON coa_template_node;
CREATE TRIGGER coa_node_level_consistency_insupd
BEFORE INSERT OR UPDATE OF parent_code, level, template_id
ON coa_template_node
FOR EACH ROW
EXECUTE FUNCTION trg_coa_node_level_consistency();

-- ---------------------------
-- Upsert template + capture template_id
-- ---------------------------
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

-- ---------------------------
-- Import JSON from file to staging
-- ---------------------------
DROP TABLE IF EXISTS coa_json_stage;
CREATE TEMP TABLE coa_json_stage (doc jsonb NOT NULL);

-- The file must contain a JSON array.
\copy coa_json_stage(doc) FROM :'JSON_FILE_PATH'

-- ---------------------------
-- Load nodes (upsert by (template_id, code))
-- ---------------------------
INSERT INTO coa_template_node (
  template_id, code, parent_code, name, level, kind, role, is_placeholder
)
SELECT
  :'template_id'::uuid,
  (n->>'code')::text,
  NULLIF(n->>'parentCode','')::text,
  (n->>'name')::text,
  (n->>'level')::int,
  (n->>'kind')::smallint,
  (n->>'role')::smallint,
  COALESCE((n->>'isPlaceholder')::boolean, false)
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

-- ---------------------------
-- Post-import validations (all must return ZERO rows)
-- ---------------------------

-- Single root
WITH roots AS (
  SELECT COUNT(*) AS root_count
  FROM coa_template_node
  WHERE template_id = :'template_id'::uuid
    AND parent_code IS NULL
)
SELECT * FROM roots WHERE root_count <> 1;

-- Parent exists
SELECT c.*
FROM coa_template_node c
LEFT JOIN coa_template_node p
  ON p.template_id = c.template_id
 AND p.code = c.parent_code
WHERE c.template_id = :'template_id'::uuid
  AND c.parent_code IS NOT NULL
  AND p.id IS NULL;

-- Level consistency
SELECT c.code, c.level AS child_level, p.level AS parent_level, c.parent_code
FROM coa_template_node c
JOIN coa_template_node p
  ON p.template_id = c.template_id
 AND p.code = c.parent_code
WHERE c.template_id = :'template_id'::uuid
  AND c.parent_code IS NOT NULL
  AND c.level <> p.level + 1;

-- Cycle detection
WITH RECURSIVE walk AS (
  SELECT template_id, code, parent_code, code AS start_code, ARRAY[code] AS path
  FROM coa_template_node
  WHERE template_id = :'template_id'::uuid
  UNION ALL
  SELECT w.template_id, n.code, n.parent_code, w.start_code, w.path || n.code
  FROM walk w
  JOIN coa_template_node n
    ON n.template_id = w.template_id
   AND n.code = w.parent_code
  WHERE w.parent_code IS NOT NULL
)
SELECT template_id, start_code, path
FROM walk
WHERE parent_code IS NOT NULL
  AND parent_code = start_code;

-- ---------------------------
-- Seed dev owner + ledger
-- ---------------------------
INSERT INTO ledger_owner (email, email_verified, password_hash, display_name, is_active)
VALUES (:'DEV_OWNER_EMAIL', true, :'DEV_OWNER_PASSWORD_HASH', :'DEV_OWNER_DISPLAY_NAME', true)
ON CONFLICT (email) DO NOTHING;

SELECT id AS dev_owner_id
FROM ledger_owner
WHERE email = :'DEV_OWNER_EMAIL'
\gset

INSERT INTO ledger (owner_id, name, currency_code, precision, template, is_active)
VALUES (:'dev_owner_id'::uuid, :'DEV_LEDGER_NAME', :'DEV_LEDGER_CURRENCY',
        :'DEV_LEDGER_PRECISION'::smallint, :'DEV_LEDGER_TEMPLATE', true)
RETURNING id AS dev_ledger_id \gset

-- ---------------------------
-- Instantiate function
-- ---------------------------
CREATE OR REPLACE FUNCTION instantiate_coa_template(p_ledger_id uuid, p_template_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_root_code text;
BEGIN
  UPDATE ledger
  SET coa_template_id = p_template_id,
      updated_at = now(),
      revision = revision + 1
  WHERE id = p_ledger_id;

  INSERT INTO account (
    ledger_id, account_role, code, commodity_scu,
    is_active, is_hidden, is_placeholder, kind, name,
    non_std_scu, notes, created_at, updated_at, revision
  )
  SELECT
    p_ledger_id, n.role, n.code, 100,
    true, false, n.is_placeholder, n.kind, n.name,
    0, NULL, now(), now(), 0
  FROM coa_template_node n
  WHERE n.template_id = p_template_id
  ON CONFLICT (ledger_id, code) DO NOTHING;

  CREATE TEMP TABLE tmp_coa_map (
    code text PRIMARY KEY,
    account_id uuid NOT NULL
  ) ON COMMIT DROP;

  INSERT INTO tmp_coa_map(code, account_id)
  SELECT a.code, a.id
  FROM account a
  WHERE a.ledger_id = p_ledger_id
    AND a.code IS NOT NULL;

  UPDATE account a
  SET parent_id = p.account_id,
      updated_at = now(),
      revision = a.revision + 1
  FROM coa_template_node n
  JOIN tmp_coa_map c ON c.code = n.code
  JOIN tmp_coa_map p ON p.code = n.parent_code
  WHERE n.template_id = p_template_id
    AND a.id = c.account_id
    AND n.parent_code IS NOT NULL;

  SELECT code INTO v_root_code
  FROM coa_template_node
  WHERE template_id = p_template_id
    AND parent_code IS NULL
  LIMIT 1;

  IF v_root_code IS NULL THEN
    RAISE EXCEPTION 'Template % has no root node (parent_code IS NULL).', p_template_id;
  END IF;

  UPDATE ledger l
  SET root_account_id = m.account_id,
      updated_at = now(),
      revision = l.revision + 1
  FROM tmp_coa_map m
  WHERE l.id = p_ledger_id
    AND m.code = v_root_code;
END;
$$;

SELECT instantiate_coa_template(:'dev_ledger_id'::uuid, :'template_id'::uuid);

-- ---------------------------
-- Final reports
-- ---------------------------
SELECT
  t.id, t.code, t.version,
  (SELECT COUNT(*) FROM coa_template_node n WHERE n.template_id = t.id) AS node_count
FROM coa_template t
WHERE t.id = :'template_id'::uuid;

SELECT
  l.id, l.name, l.coa_template_id, l.root_account_id,
  (SELECT COUNT(*) FROM account a WHERE a.ledger_id = l.id) AS account_count
FROM ledger l
WHERE l.id = :'dev_ledger_id'::uuid;

SELECT a.*
FROM account a
JOIN ledger l ON l.root_account_id = a.id
WHERE l.id = :'dev_ledger_id'::uuid;

-- Remember to run the following CLI statement:
-- /Library/PostgreSQL/18/bin/psql -U myaccounting_user -d myaccounting_dev -f e2e_coa_psql.sql
-- JSON file must reside in the script's same path.
