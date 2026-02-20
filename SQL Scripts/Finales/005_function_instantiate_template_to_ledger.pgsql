-- 005_function_instantiate_template_to_ledger.pgsql
-- Instantiates a COA template into a Ledger, using:
--   coa_template_node.account_type_code -> account_type.id -> account.account_type_id
--
-- Run:
--   psql -h localhost -U postgres -d myaccounting_dev -f 005_function_instantiate_template_to_ledger.pgsql

CREATE OR REPLACE FUNCTION public.instantiate_coa_template_to_ledger(
  p_template_id uuid,
  p_ledger_id   uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_root_account_id uuid;
  v_currency_commodity_id uuid;
BEGIN
  -- Guards
  IF NOT EXISTS (SELECT 1 FROM public.coa_template WHERE id = p_template_id) THEN
    RAISE EXCEPTION 'Template % not found', p_template_id;
  END IF;

  SELECT currency_commodity_id
    INTO v_currency_commodity_id
  FROM public.ledger
  WHERE id = p_ledger_id;

  IF v_currency_commodity_id IS NULL THEN
    RAISE EXCEPTION 'Ledger % not found or missing currency_commodity_id', p_ledger_id;
  END IF;

  -- Prevent accidental duplication
  IF EXISTS (SELECT 1 FROM public.account WHERE ledger_id = p_ledger_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Ledger % already has accounts. Refusing to instantiate template.', p_ledger_id;
  END IF;

  -- Validate one root for the template
  IF (SELECT COUNT(*)
      FROM public.coa_template_node
      WHERE template_id = p_template_id
        AND parent_code IS NULL) <> 1 THEN
    RAISE EXCEPTION 'Template % must have exactly one root node (parent_code IS NULL).', p_template_id;
  END IF;

  -- Validate required type on non-placeholders
  IF EXISTS (
    SELECT 1
    FROM public.coa_template_node
    WHERE template_id = p_template_id
      AND NOT is_placeholder
      AND account_type_code IS NULL
  ) THEN
    RAISE EXCEPTION 'Template % has non-placeholder nodes without account_type_code.', p_template_id;
  END IF;

  -- Validate type codes exist (and are not soft-deleted)
  IF EXISTS (
    SELECT 1
    FROM public.coa_template_node n
    WHERE n.template_id = p_template_id
      AND n.account_type_code IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.account_type at
        WHERE at.code = n.account_type_code
          AND at.deleted_at IS NULL
      )
  ) THEN
    RAISE EXCEPTION 'Template % references account_type codes that do not exist (or are deleted).', p_template_id;
  END IF;

  -- Mapping: node.code -> created account.id
  CREATE TEMP TABLE _node_to_account (
    node_code text PRIMARY KEY,
    account_id uuid NOT NULL
  ) ON COMMIT DROP;

  -- Insert accounts ordered by level (parents must exist first)
  WITH ordered AS (
    SELECT
      n.code,
      n.parent_code,
      n.name,
      n.level,
      n.kind,
      n.role,
      n.is_placeholder,
      n.account_type_code
    FROM public.coa_template_node n
    WHERE n.template_id = p_template_id
    ORDER BY n.level ASC, n.code ASC
  ),
  ins AS (
    INSERT INTO public.account (
      ledger_id,
      account_role,
      code,
      commodity_scu,
      created_at,
      is_active,
      is_hidden,
      is_placeholder,
      kind,
      name,
      non_std_scu,
      notes,
      account_type_id,
      commodity_id,
      parent_id,
      updated_at,
      revision,
      deleted_at
    )
    SELECT
      p_ledger_id,
      o.role,
      o.code,
      100,
      now(),
      true,
      false,
      o.is_placeholder,
      o.kind,
      o.name,
      0,
      NULL,
      CASE
        WHEN o.is_placeholder THEN NULL
        ELSE (SELECT at.id
              FROM public.account_type at
              WHERE at.code = o.account_type_code
                AND at.deleted_at IS NULL)
      END,
      v_currency_commodity_id,
      CASE
        WHEN o.parent_code IS NULL THEN NULL
        ELSE (SELECT m.account_id FROM _node_to_account m WHERE m.node_code = o.parent_code)
      END,
      now(),
      0,
      NULL
    FROM ordered o
    RETURNING id, code
  )
  INSERT INTO _node_to_account (node_code, account_id)
  SELECT code, id FROM ins;

  -- Root account id
  SELECT m.account_id
    INTO v_root_account_id
  FROM _node_to_account m
  JOIN public.coa_template_node n
    ON n.template_id = p_template_id
   AND n.parent_code IS NULL
   AND n.code = m.node_code
  LIMIT 1;

  -- Update ledger pointers
  UPDATE public.ledger
     SET root_account_id = v_root_account_id,
         coa_template_id = p_template_id,
         updated_at = now()
   WHERE id = p_ledger_id;

  RETURN v_root_account_id;
END;
$$;
