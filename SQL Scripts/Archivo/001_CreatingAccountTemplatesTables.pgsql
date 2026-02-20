-- ============================================================
-- Chart of Accounts Templates
-- ============================================================

-- Stores a chart-of-accounts template definition (metadata + versioning).
CREATE TABLE IF NOT EXISTS coa_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL,                 -- e.g., 'MX_SAT_STD'
  name        text NOT NULL,                 -- human-friendly template name
  description text NULL,
  country     text NULL,                     -- e.g., 'MX'
  locale      text NULL,                     -- e.g., 'es-MX'
  industry    text NULL,                     -- e.g., 'general', 'retail'
  version     text NOT NULL,                 -- e.g., '2026.01'
  is_active   boolean NOT NULL DEFAULT true,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (code, version)
);

-- Stores each node in the template (one row per account definition).
CREATE TABLE IF NOT EXISTS coa_template_node (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id    uuid NOT NULL REFERENCES coa_template(id) ON DELETE CASCADE,

  code           text NOT NULL,              -- node code, unique within a template
  parent_code    text NULL,                  -- parent code (string reference within same template)
  name           text NOT NULL,
  level          integer NOT NULL,
  kind           smallint NOT NULL,
  role           smallint NOT NULL,
  is_placeholder boolean NOT NULL DEFAULT false,

  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),

  UNIQUE (template_id, code),
  CHECK (level >= 0)
);

-- Helpful indexes for tree operations and instantiation.
CREATE INDEX IF NOT EXISTS idx_coa_node_template_parent
  ON coa_template_node(template_id, parent_code);

CREATE INDEX IF NOT EXISTS idx_coa_node_template_level
  ON coa_template_node(template_id, level);

CREATE INDEX IF NOT EXISTS idx_coa_node_template_code
  ON coa_template_node(template_id, code);
