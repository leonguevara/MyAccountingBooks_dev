-- ============================================================
-- e2e_coa_pgadmin.sql
-- End-to-end: DDL + Import JSON (paste) + Validation + Ledger Instantiation
-- Pure SQL (pgAdmin-friendly).
-- ============================================================

BEGIN;

-- ---------------------------
-- 1) Prereqs
-- ---------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------
-- 2) DDL: Templates
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

ALTER TABLE ledger
  ADD COLUMN IF NOT EXISTS coa_template_id uuid NULL REFERENCES coa_template(id) ON DELETE SET NULL;

-- ---------------------------
-- 3) Validation triggers (recommended)
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
-- 4) Config values (edit here)
-- ---------------------------
WITH cfg AS (
  SELECT
    'MX_SAT_STD'::text AS template_code,
    'Mexico SAT (Standard)'::text AS template_name,
    '2026.01'::text AS template_version,
    'MX'::text AS template_country,
    'es-MX'::text AS template_locale,
    'general'::text AS template_industry,
    'End-to-end import from JSON (pgAdmin)'::text AS template_description,

    'dev@example.com'::text AS dev_owner_email,
    'DEV_ONLY_HASH'::text AS dev_owner_password_hash,
    'Dev User'::text AS dev_owner_display_name,

    'Dev Ledger (E2E)'::text AS dev_ledger_name,
    'MXN'::text AS dev_ledger_currency,
    'SAT'::text AS dev_ledger_template,
    2::smallint AS dev_ledger_precision,

    -- Paste your JSON array below (must be a JSON array):
    $$[ ]$$::jsonb AS coa_json
),
-- ---------------------------
-- 5) Upsert template and get template_id
-- ---------------------------
tmpl AS (
  INSERT INTO coa_template (code, name, description, country, locale, industry, version)
  SELECT template_code, template_name, template_description, template_country, template_locale, template_industry, template_version
  FROM cfg
  ON CONFLICT (code, version)
  DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    country = EXCLUDED.country,
    locale = EXCLUDED.locale,
    industry = EXCLUDED.industry,
    updated_at = now()
  RETURNING id, code, version
),
template_id AS (
  SELECT id AS id FROM tmpl
),
-- ---------------------------
-- 6) Insert nodes
-- ---------------------------
nodes AS (
  SELECT
    (SELECT id FROM template_id) AS template_id,
    jsonb_array_elements((SELECT coa_json FROM cfg)) AS n
)
INSERT INTO coa_template_node (template_id, code, parent_code, name, level, kind, role, is_placeholder)
SELECT
  template_id,
  (n->>'code')::text,
  NULLIF(n->>'parentCode','')::text,
  (n->>'name')::text,
  (n->>'level')::int,
  (n->>'kind')::smallint,
  (n->>'role')::smallint,
  COALESCE((n->>'isPlaceholder')::boolean, false)
FROM nodes
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
-- 7) Post-import validations (run as separate SELECTs)
-- ---------------------------

-- Single root (must be 1)
SELECT COUNT(*) AS root_count
FROM coa_template_node
WHERE template_id = (SELECT id FROM coa_template WHERE code='MX_SAT_STD' AND version='2026.01')
  AND parent_code IS NULL;

-- Missing parents (must return 0 rows)
SELECT c.*
FROM coa_template_node c
LEFT JOIN coa_template_node p
  ON p.template_id = c.template_id
 AND p.code = c.parent_code
WHERE c.template_id = (SELECT id FROM coa_template WHERE code='MX_SAT_STD' AND version='2026.01')
  AND c.parent_code IS NOT NULL
  AND p.id IS NULL;

-- Level mismatches (must return 0 rows)
SELECT c.code, c.level AS child_level, p.level AS parent_level, c.parent_code
FROM coa_template_node c
JOIN coa_template_node p
  ON p.template_id = c.template_id
 AND p.code = c.parent_code
WHERE c.template_id = (SELECT id FROM coa_template WHERE code='MX_SAT_STD' AND version='2026.01')
  AND c.parent_code IS NOT NULL
  AND c.level <> p.level + 1;

-- Cycle detection (must return 0 rows)
WITH RECURSIVE walk AS (
  SELECT template_id, code, parent_code, code AS start_code, ARRAY[code] AS path
  FROM coa_template_node
  WHERE template_id = (SELECT id FROM coa_template WHERE code='MX_SAT_STD' AND version='2026.01')
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
-- 8) Seed dev owner + ledger
-- ---------------------------
WITH cfg AS (
  SELECT
    'dev@example.com'::text AS dev_owner_email,
    true::boolean AS dev_owner_email_verified,
    'DEV_ONLY_HASH'::text AS dev_owner_password_hash,
    'Dev User'::text AS dev_owner_display_name,
    'Dev Ledger (E2E)'::text AS dev_ledger_name,
    'MXN'::text AS dev_ledger_currency,
    'SAT'::text AS dev_ledger_template,
    2::smallint AS dev_ledger_precision
),
ins_owner AS (
  INSERT INTO ledger_owner (email, email_verified, password_hash, display_name, is_active)
  SELECT dev_owner_email, dev_owner_email_verified, dev_owner_password_hash, dev_owner_display_name, true
  FROM cfg
  ON CONFLICT (email) DO NOTHING
  RETURNING id
),
owner_id AS (
  SELECT id FROM ins_owner
  UNION ALL
  SELECT id FROM ledger_owner WHERE email = (SELECT dev_owner_email FROM cfg)
  LIMIT 1
),
ins_ledger AS (
  INSERT INTO ledger (owner_id, name, currency_code, precision, template, is_active)
  SELECT
    (SELECT id FROM owner_id),
    dev_ledger_name,
    dev_ledger_currency,
    dev_ledger_precision,
    dev_ledger_template,
    true
  FROM cfg
  RETURNING id
)
SELECT id AS dev_ledger_id FROM ins_ledger;

-- ---------------------------
-- 9) Instantiate function (create once)
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

-- ---------------------------
-- 10) Instantiate into the most recently created dev ledger
-- ---------------------------
DO $$
DECLARE
  v_template_id uuid;
  v_ledger_id uuid;
BEGIN
  SELECT id INTO v_template_id
  FROM coa_template
  WHERE code='MX_SAT_STD' AND version='2026.01';

  SELECT id INTO v_ledger_id
  FROM ledger
  WHERE name='Dev Ledger (E2E)'
  ORDER BY created_at DESC
  LIMIT 1;

  PERFORM instantiate_coa_template(v_ledger_id, v_template_id);
END;
$$;

-- ---------------------------
-- 11) Final reports
-- ---------------------------
SELECT
  t.id, t.code, t.version,
  (SELECT COUNT(*) FROM coa_template_node n WHERE n.template_id = t.id) AS node_count
FROM coa_template t
WHERE t.code='MX_SAT_STD' AND t.version='2026.01';

SELECT
  l.id, l.name, l.coa_template_id, l.root_account_id,
  (SELECT COUNT(*) FROM account a WHERE a.ledger_id = l.id) AS account_count
FROM ledger l
WHERE l.name='Dev Ledger (E2E)'
ORDER BY l.created_at DESC
LIMIT 1;

SELECT a.*
FROM account a
JOIN ledger l ON l.root_account_id = a.id
WHERE l.name='Dev Ledger (E2E)'
ORDER BY l.created_at DESC
LIMIT 1;

COMMIT;
