-- 006_function_create_ledger_with_optional_template.sql
-- Purpose:
--   Create a new Ledger and (optionally) instantiate its Chart of Accounts from a COA template.
--
-- Dependencies:
--   - pgcrypto extension (for gen_random_uuid())
--   - Tables: ledger_owner, ledger, commodity, coa_template, coa_template_node, account
--
-- Notes:
--   - This function is "single-user multi-device" friendly: Ledger ownership is modeled by ledger.owner_id.
--   - It performs a best-effort mapping of template nodes into account rows (kind/role/name/code/is_placeholder).
--   - account_type_id is left NULL by default because coa_template_node does not store an AccountType.
--     If you later add "account_type_code" to coa_template_node, you can wire it here.
--
-- Safety:
--   - Uses a single transaction per function call.
--   - Raises explicit exceptions for missing owner/template/currency.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.create_ledger_with_optional_template(
    p_owner_id uuid,
    p_ledger_name text,
    p_currency_mnemonic text DEFAULT 'MXN',   -- e.g. 'MXN', 'USD'
    p_precision smallint DEFAULT 2,
    p_template_label text DEFAULT 'CUSTOM',   -- informational label, stored in ledger.template
    p_coa_template_code text DEFAULT NULL,    -- e.g. 'PERSONALES_2026', 'SAT_2025'
    p_coa_template_version text DEFAULT NULL -- e.g. '2026', '2025'
)
RETURNS TABLE (
    ledger_id uuid,
    root_account_id uuid,
    coa_template_id uuid,
    currency_commodity_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_exists boolean;
    v_currency_id uuid;
    v_template_id uuid;
    v_root_id uuid;
BEGIN
    -- 1) Validate owner
    SELECT EXISTS(SELECT 1 FROM public.ledger_owner lo WHERE lo.id = p_owner_id AND lo.deleted_at IS NULL)
      INTO v_owner_exists;

    IF NOT v_owner_exists THEN
        RAISE EXCEPTION 'ledger_owner % not found (or deleted)', p_owner_id;
    END IF;

    -- 2) Resolve currency commodity (namespace='CURRENCY')
    SELECT c.id
      INTO v_currency_id
      FROM public.commodity c
     WHERE c.namespace = 'CURRENCY'
       AND c.mnemonic = p_currency_mnemonic
       AND c.deleted_at IS NULL
     LIMIT 1;

    IF v_currency_id IS NULL THEN
        RAISE EXCEPTION 'Currency commodity not found for mnemonic=% (namespace=CURRENCY)', p_currency_mnemonic;
    END IF;

    -- 3) Resolve template (optional)
    v_template_id := NULL;
    IF p_coa_template_code IS NOT NULL AND p_coa_template_version IS NOT NULL THEN
        SELECT t.id
          INTO v_template_id
          FROM public.coa_template t
         WHERE t.code = p_coa_template_code
           AND t.version = p_coa_template_version
           AND t.is_active = TRUE
         LIMIT 1;

        IF v_template_id IS NULL THEN
            RAISE EXCEPTION 'COA template not found for code=% version=%', p_coa_template_code, p_coa_template_version;
        END IF;
    ELSIF p_coa_template_code IS NOT NULL OR p_coa_template_version IS NOT NULL THEN
        RAISE EXCEPTION 'Both p_coa_template_code and p_coa_template_version must be provided together (or both NULL)';
    END IF;

    -- 4) Create ledger
    INSERT INTO public.ledger (
        owner_id,
        name,
        currency_code,
        precision,
        template,
        is_active,
        currency_commodity_id,
        root_account_id,
        coa_template_id
    )
    VALUES (
        p_owner_id,
        COALESCE(NULLIF(p_ledger_name, ''), 'No Name'),
        p_currency_mnemonic,
        COALESCE(p_precision, 2),
        COALESCE(NULLIF(p_template_label, ''), 'CUSTOM'),
        TRUE,
        v_currency_id,
        NULL,
        v_template_id
    )
    RETURNING id INTO ledger_id;

    currency_commodity_id := v_currency_id;
    coa_template_id := v_template_id;

    -- 5) If template selected, instantiate into account tree
    v_root_id := NULL;
    IF v_template_id IS NOT NULL THEN
        -- Staging map: template node code -> created account id
        CREATE TEMP TABLE _stg_new_accounts (
            node_code text PRIMARY KEY,
            parent_code text,
            account_id uuid NOT NULL
        ) ON COMMIT DROP;

        -- Insert accounts ordered by level (parents before children).
        -- parent_id is filled later via the staging table.
        INSERT INTO public.account (
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
        SELECT
            ledger_id,
            n.role,
            n.code,
            -- account.commodity_scu is INT; commodity.fraction is BIGINT.
            LEAST((SELECT c.fraction FROM public.commodity c WHERE c.id = v_currency_id)::bigint, 2147483647)::int,
            TRUE,
            FALSE,
            n.is_placeholder,
            n.kind,
            n.name,
            0,
            NULL,
            NULL,           -- account_type_id (see header note)
            v_currency_id,  -- default commodity for accounts within this ledger
            NULL            -- parent_id (patched below)
        FROM public.coa_template_node n
        WHERE n.template_id = v_template_id
        ORDER BY n.level, n.code
        RETURNING code, id;

        -- Build map from code -> account_id using the inserted accounts
        INSERT INTO _stg_new_accounts (node_code, parent_code, account_id)
        SELECT n.code,
               n.parent_code,
               a.id
        FROM public.coa_template_node n
        JOIN public.account a
          ON a.ledger_id = ledger_id
         AND a.code = n.code
        WHERE n.template_id = v_template_id;

        -- Patch parent_id using the staging map
        UPDATE public.account a
           SET parent_id = p.account_id
          FROM _stg_new_accounts self
          JOIN _stg_new_accounts p ON p.node_code = self.parent_code
         WHERE a.id = self.account_id
           AND self.parent_code IS NOT NULL;

        -- Identify root node: parent_code IS NULL, lowest level (typically 0)
        SELECT self.account_id
          INTO v_root_id
          FROM _stg_new_accounts self
          JOIN public.coa_template_node n
            ON n.template_id = v_template_id
           AND n.code = self.node_code
         WHERE n.parent_code IS NULL
         ORDER BY n.level ASC, n.code ASC
         LIMIT 1;

        -- Set ledger.root_account_id
        UPDATE public.ledger l
           SET root_account_id = v_root_id,
               coa_template_id = v_template_id
         WHERE l.id = ledger_id;

    END IF;

    root_account_id := v_root_id;

    RETURN NEXT;
END;
$$;

COMMIT;

-- End of 041_create_ledger.sql
