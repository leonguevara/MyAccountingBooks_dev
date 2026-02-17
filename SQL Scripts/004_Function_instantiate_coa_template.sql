-- ============================================================
-- Instantiate CoA template into the account table for a given ledger.
-- ============================================================

CREATE OR REPLACE FUNCTION instantiate_coa_template(p_ledger_id uuid, p_template_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_root_code text;
BEGIN
  -- 1) Attach template to ledger for traceability.
  UPDATE ledger
  SET coa_template_id = p_template_id,
      updated_at = now(),
      revision = revision + 1
  WHERE id = p_ledger_id;

  -- 2) Insert accounts from template nodes.
  -- We keep a mapping (template_id, ledger_id, code -> account_id) using a temp table.
  CREATE TEMP TABLE IF NOT EXISTS tmp_coa_map (
    code text PRIMARY KEY,
    account_id uuid NOT NULL
  ) ON COMMIT DROP;

  INSERT INTO account (
    ledger_id,
    account_role,
    code,
    commodity_scu,
    is_active,
    is_hidden,
    is_placeholder,
    kind,
    name,
    non_std_scu,
    notes,
    created_at,
    updated_at,
    revision
  )
  SELECT
    p_ledger_id,
    n.role,
    n.code,
    100,                 -- commoditySCU default from your CoreData model
    true,                -- isActive
    false,               -- isHidden
    n.is_placeholder,
    n.kind,
    n.name,
    0,                   -- nonStdSCU default
    NULL,                -- notes
    now(),
    now(),
    0
  FROM coa_template_node n
  WHERE n.template_id = p_template_id
  ON CONFLICT (ledger_id, code) DO NOTHING;

  -- 3) Build code -> account_id mapping for this ledger.
  INSERT INTO tmp_coa_map (code, account_id)
  SELECT a.code, a.id
  FROM account a
  WHERE a.ledger_id = p_ledger_id
    AND a.code IS NOT NULL;

  -- 4) Update parent_id according to template parent_code.
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

  -- 5) Determine root node (parent_code IS NULL). Enforce single root.
  SELECT code INTO v_root_code
  FROM coa_template_node
  WHERE template_id = p_template_id
    AND parent_code IS NULL
  ORDER BY level ASC, code ASC
  LIMIT 1;

  IF v_root_code IS NULL THEN
    RAISE EXCEPTION 'Template % has no root node (parent_code IS NULL).', p_template_id;
  END IF;

  -- 6) Set ledger.root_account_id to the root account in this ledger.
  UPDATE ledger l
  SET root_account_id = m.account_id,
      updated_at = now(),
      revision = l.revision + 1
  FROM tmp_coa_map m
  WHERE l.id = p_ledger_id
    AND m.code = v_root_code;

END;
$$;
