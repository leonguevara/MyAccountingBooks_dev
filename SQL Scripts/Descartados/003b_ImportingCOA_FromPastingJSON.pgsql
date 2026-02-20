-- ============================================================
-- Import CoA JSON by pasting the JSON into the query.
-- ============================================================

WITH tmpl AS (
  INSERT INTO coa_template (code, name, description, country, locale, industry, version)
  VALUES ('MX_SAT_STD', 'Mexico SAT (Standard)', 'Pasted JSON import', 'MX', 'es-MX', 'general', '2026.01')
  ON CONFLICT (code, version)
  DO UPDATE SET updated_at = now()
  RETURNING id
),
doc AS (
  SELECT
    (SELECT id FROM tmpl) AS template_id,
    -- Paste your JSON array below:
    $$[  ]$$::jsonb AS j
),
nodes AS (
  SELECT
    template_id,
    jsonb_array_elements(j) AS n
  FROM doc
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
DO UPDATE SET updated_at = now();
 