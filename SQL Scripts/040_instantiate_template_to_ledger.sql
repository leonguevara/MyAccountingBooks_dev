-- 040_instantiate_template_to_ledger.sql
-- Instantiate a Chart of Accounts (COA) template into a specific ledger as Account rows.
--
-- This script creates a single function:
--   public.instantiate_coa_template_to_ledger(p_ledger_id uuid, p_template_id uuid) RETURNS uuid
--
-- Comments are in English by request.

BEGIN;

CREATE OR REPLACE FUNCTION public.instantiate_coa_template_to_ledger(
    p_ledger_id   uuid,
    p_template_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_root_code text;
    v_root_account_id uuid;
    v_max_level int;
    v_level int;
    v_nodes_inserted int;
    v_currency_commodity_id uuid;
    v_existing_accounts int;
    v_new_account_id uuid;
    r record;
BEGIN
    -- Lock ledger row to prevent concurrent instantiations.
    SELECT l.currency_commodity_id
      INTO v_currency_commodity_id
      FROM ledger l
     WHERE l.id = p_ledger_id
     FOR UPDATE;

    IF v_currency_commodity_id IS NULL THEN
        RAISE EXCEPTION 'Ledger % has NULL currency_commodity_id; set ledger currency first.', p_ledger_id;
    END IF;

    -- Avoid duplicating an already-instantiated ledger.
    SELECT COUNT(*)
      INTO v_existing_accounts
      FROM account a
     WHERE a.ledger_id = p_ledger_id;

    IF v_existing_accounts > 0 THEN
        RAISE EXCEPTION 'Ledger % already has % accounts. Refusing to instantiate template on a non-empty ledger.',
            p_ledger_id, v_existing_accounts;
    END IF;

    -- Validate: template must exist and have nodes.
    IF NOT EXISTS (SELECT 1 FROM coa_template WHERE id = p_template_id) THEN
        RAISE EXCEPTION 'Template % does not exist in coa_template.', p_template_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM coa_template_node WHERE template_id = p_template_id) THEN
        RAISE EXCEPTION 'Template % has no nodes in coa_template_node.', p_template_id;
    END IF;

    -- Validate: exactly one root node (parent_code IS NULL), and it must be level 0.
    SELECT n.code
      INTO v_root_code
      FROM coa_template_node n
     WHERE n.template_id = p_template_id
       AND n.parent_code IS NULL
     ORDER BY n.code
     LIMIT 1;

    IF v_root_code IS NULL THEN
        RAISE EXCEPTION 'Template % has no root node (parent_code IS NULL).', p_template_id;
    END IF;

    IF (SELECT COUNT(*) FROM coa_template_node n WHERE n.template_id = p_template_id AND n.parent_code IS NULL) <> 1 THEN
        RAISE EXCEPTION 'Template % must have exactly 1 root node (parent_code IS NULL).', p_template_id;
    END IF;

    IF EXISTS (
        SELECT 1
          FROM coa_template_node n
         WHERE n.template_id = p_template_id
           AND n.parent_code IS NULL
           AND n.level <> 0
    ) THEN
        RAISE EXCEPTION 'Template % root node must be level=0.', p_template_id;
    END IF;

    -- Validate: parent exists for all non-root nodes.
    IF EXISTS (
        SELECT 1
          FROM coa_template_node c
          LEFT JOIN coa_template_node p
                 ON p.template_id = c.template_id
                AND p.code = c.parent_code
         WHERE c.template_id = p_template_id
           AND c.parent_code IS NOT NULL
           AND p.code IS NULL
    ) THEN
        RAISE EXCEPTION 'Template % has nodes whose parent_code does not exist.', p_template_id;
    END IF;

    -- Validate: level correctness (child.level = parent.level + 1)
    IF EXISTS (
        SELECT 1
          FROM coa_template_node c
          JOIN coa_template_node p
            ON p.template_id = c.template_id
           AND p.code = c.parent_code
         WHERE c.template_id = p_template_id
           AND c.parent_code IS NOT NULL
           AND c.level <> p.level + 1
    ) THEN
        RAISE EXCEPTION 'Template % has nodes with invalid level (must be parent.level + 1).', p_template_id;
    END IF;

    -- Validate: no cycles (detect a repeated code during ancestry traversal).
    IF EXISTS (
        WITH RECURSIVE walk AS (
            SELECT n.template_id,
                   n.code,
                   n.parent_code,
                   ARRAY[n.code] AS path
              FROM coa_template_node n
             WHERE n.template_id = p_template_id
               AND n.parent_code IS NULL
            UNION ALL
            SELECT c.template_id,
                   c.code,
                   c.parent_code,
                   w.path || c.code
              FROM coa_template_node c
              JOIN walk w
                ON w.template_id = c.template_id
               AND w.code = c.parent_code
        )
        SELECT 1
          FROM walk w
          JOIN coa_template_node c
            ON c.template_id = w.template_id
           AND c.parent_code = w.code
         WHERE c.code = ANY(w.path)
         LIMIT 1
    ) THEN
        RAISE EXCEPTION 'Template % has a cycle (or duplicated ancestry path).', p_template_id;
    END IF;

    -- Determine max level.
    SELECT MAX(level)
      INTO v_max_level
      FROM coa_template_node
     WHERE template_id = p_template_id;

    IF v_max_level IS NULL THEN
        RAISE EXCEPTION 'Template % has no levels (unexpected).', p_template_id;
    END IF;

    -- Mapping table: template node code -> created account id
    CREATE TEMP TABLE _coa_map(
        code text PRIMARY KEY,
        account_id uuid NOT NULL
    ) ON COMMIT DROP;

    -- Insert accounts level-by-level so parent rows exist when we insert children.
    FOR v_level IN 0..v_max_level LOOP
        v_nodes_inserted := 0;

        FOR r IN
            SELECT n.code, n.parent_code, n.name, n.kind, n.role, n.is_placeholder
              FROM coa_template_node n
             WHERE n.template_id = p_template_id
               AND n.level = v_level
             ORDER BY n.code
        LOOP
            INSERT INTO account(
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
                account_type_id,
                commodity_id,
                parent_id
            )
            VALUES (
                p_ledger_id,
                COALESCE(r.role, 0),
                r.code,
                100,
                TRUE,
                FALSE,
                COALESCE(r.is_placeholder, FALSE),
                COALESCE(r.kind, 1),
                COALESCE(r.name, 'No Name'),
                0,
                NULL,
                NULL,
                v_currency_commodity_id,
                CASE
                    WHEN r.parent_code IS NULL THEN NULL
                    ELSE (SELECT m.account_id FROM _coa_map m WHERE m.code = r.parent_code)
                END
            )
            RETURNING id INTO v_new_account_id;

            INSERT INTO _coa_map(code, account_id)
            VALUES (r.code, v_new_account_id);

            IF r.parent_code IS NULL THEN
                v_root_account_id := v_new_account_id;
            END IF;

            v_nodes_inserted := v_nodes_inserted + 1;
        END LOOP;

        IF v_nodes_inserted <> (SELECT COUNT(*) FROM coa_template_node WHERE template_id = p_template_id AND level = v_level) THEN
            RAISE EXCEPTION 'Inserted % nodes at level %, but template has % nodes at that level.',
                v_nodes_inserted, v_level,
                (SELECT COUNT(*) FROM coa_template_node WHERE template_id = p_template_id AND level = v_level);
        END IF;
    END LOOP;

    -- Root should exist and match the root code.
    IF v_root_account_id IS NULL THEN
        RAISE EXCEPTION 'Root account was not created (unexpected). Root code was %.', v_root_code;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM _coa_map WHERE code = v_root_code AND account_id = v_root_account_id) THEN
        -- If for any reason the root created is not the same as the root_code row (should not happen),
        -- pick the mapped root_code row.
        SELECT m.account_id INTO v_root_account_id FROM _coa_map m WHERE m.code = v_root_code;
    END IF;

    -- Update ledger pointers
    UPDATE ledger
       SET root_account_id = v_root_account_id,
           coa_template_id = p_template_id,
           updated_at = now(),
           revision = revision + 1
     WHERE id = p_ledger_id;

    RETURN v_root_account_id;
END;
$$;

-- Example usage:
--   SELECT public.instantiate_coa_template_to_ledger(
--       p_ledger_id   => 'YOUR-LEDGER-UUID'::uuid,
--       p_template_id => 'YOUR-TEMPLATE-UUID'::uuid
--   );

COMMIT;
