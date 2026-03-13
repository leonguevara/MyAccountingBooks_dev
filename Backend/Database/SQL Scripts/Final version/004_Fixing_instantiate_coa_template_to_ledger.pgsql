-- Function: public.instantiate_coa_template_to_ledger(uuid, uuid)
--
-- Purpose:
--   Materialize a Chart of Accounts (CoA) template into concrete accounts for a
--   target ledger, preserving hierarchy and wiring the ledger root account.
--
-- Parameters:
--   p_template_id : UUID of the CoA template to instantiate.
--   p_ledger_id   : UUID of the destination ledger.
--
-- Returns:
--   UUID of the created root account for the ledger.
--
-- Behavior summary:
--   1) Validates template and ledger prerequisites.
--   2) Inserts all accounts from template nodes (initially with parent_id NULL).
--   3) Builds a temporary node-code-to-account-id map.
--   4) Backfills parent-child relationships using that map.
--   5) Updates ledger.root_account_id and ledger.coa_template_id.
--
-- Failure model:
--   Raises exceptions when input invariants are not met (missing/deleted
--   template, invalid ledger currency, non-empty ledger, or invalid template
--   root shape).
--
-- Notes:
--   - Placeholder nodes are inserted with account_type_id = NULL.
--   - The mapping temp table is ON COMMIT DROP and lives for this transaction.
--   - This function is intended for empty ledgers; it is not additive/merge-safe.
CREATE OR REPLACE FUNCTION public.instantiate_coa_template_to_ledger(
    p_template_id uuid,
    p_ledger_id   uuid
) RETURNS uuid
    LANGUAGE plpgsql
AS $$
DECLARE
    v_root_account_id       uuid;
    v_currency_commodity_id uuid;
BEGIN
    -- ── Preconditions and invariants ────────────────────────────────────────
    -- Validate that source template and destination ledger are usable.

    IF NOT EXISTS (
        SELECT 1 FROM public.coa_template
         WHERE id = p_template_id AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Template % not found (or deleted)', p_template_id;
    END IF;

    SELECT currency_commodity_id
      INTO v_currency_commodity_id
      FROM public.ledger
     WHERE id = p_ledger_id;

    IF v_currency_commodity_id IS NULL THEN
        RAISE EXCEPTION 'Ledger % not found or missing currency_commodity_id', p_ledger_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.account
         WHERE ledger_id = p_ledger_id AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Ledger % already has accounts. Refusing to instantiate template.', p_ledger_id;
    END IF;

    IF (SELECT COUNT(*) FROM public.coa_template_node
         WHERE template_id = p_template_id AND parent_code IS NULL) <> 1 THEN
        RAISE EXCEPTION 'Template % must have exactly one root node (parent_code IS NULL).', p_template_id;
    END IF;

    -- ── Step 1: Create mapping table ────────────────────────────────────────
    -- Maps node code → newly created account UUID.
    -- Must be a temp table so it persists across the two DML steps below.

    CREATE TEMP TABLE _node_to_account (
        node_code  text PRIMARY KEY,
        account_id uuid NOT NULL
    ) ON COMMIT DROP;

    -- ── Step 2: Insert account rows (parent_id deferred) ────────────────────
    -- Ordered by level ASC so parents exist in the mapping before children
    -- need them in Step 3. parent_id is intentionally NULL here.

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
        n.role,
        n.code,
        LEAST(
            (SELECT fraction FROM public.commodity
              WHERE id = v_currency_commodity_id),
            2147483647
        )::integer,
        now(),
        true,
        false,
        n.is_placeholder,
        n.kind,
        n.name,
        0,
        NULL,
        -- account_type_id: NULL for placeholders, resolved for real accounts
        CASE
            WHEN n.is_placeholder THEN NULL
            ELSE (
                SELECT at.id FROM public.account_type at
                 WHERE at.code = n.account_type_code
                   AND at.deleted_at IS NULL
                 LIMIT 1
            )
        END,
        v_currency_commodity_id,
        NULL,   -- ← parent_id: filled in Step 3
        now(),
        0,
        NULL
    FROM public.coa_template_node n
    WHERE n.template_id = p_template_id
    ORDER BY n.level ASC, n.code ASC;

    -- ── Step 3: Populate mapping table ──────────────────────────────────────
    -- Now that all accounts exist, build code → account_id map.

    INSERT INTO _node_to_account (node_code, account_id)
    SELECT a.code, a.id
    FROM public.account a
    WHERE a.ledger_id = p_ledger_id
      AND a.deleted_at IS NULL
      AND a.code IS NOT NULL;

    -- ── Step 4: Backfill parent_id from template hierarchy ──────────────────

    UPDATE public.account a
       SET parent_id  = m_parent.account_id,
           updated_at = now()
      FROM public.coa_template_node n
      JOIN _node_to_account m_self   ON m_self.node_code   = n.code
      JOIN _node_to_account m_parent ON m_parent.node_code = n.parent_code
     WHERE n.template_id  = p_template_id
       AND n.parent_code  IS NOT NULL
       AND a.id           = m_self.account_id
       AND a.ledger_id    = p_ledger_id;

    -- ── Step 5: Resolve root and update ledger metadata ─────────────────────

    SELECT m.account_id
      INTO v_root_account_id
      FROM _node_to_account m
      JOIN public.coa_template_node n
        ON n.code = m.node_code
       AND n.template_id = p_template_id
     WHERE n.parent_code IS NULL
     LIMIT 1;

    UPDATE public.ledger
       SET root_account_id = v_root_account_id,
           coa_template_id = p_template_id,
           updated_at      = now()
     WHERE id = p_ledger_id;

    RETURN v_root_account_id;
END;
$$;