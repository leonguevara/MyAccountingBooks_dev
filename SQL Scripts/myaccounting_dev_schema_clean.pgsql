--
-- PostgreSQL database dump
--

\restrict S8v9g2qVKfcg4mRFnpFBu6HpyskX7QohEcyfZVZqB1OmDefRFaXnciDbigPGHRF

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.transaction DROP CONSTRAINT IF EXISTS transaction_payee_id_fkey;
ALTER TABLE IF EXISTS ONLY public.transaction DROP CONSTRAINT IF EXISTS transaction_ledger_id_fkey;
ALTER TABLE IF EXISTS ONLY public.transaction DROP CONSTRAINT IF EXISTS transaction_currency_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.split DROP CONSTRAINT IF EXISTS split_transaction_id_fkey;
ALTER TABLE IF EXISTS ONLY public.split DROP CONSTRAINT IF EXISTS split_account_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_transaction DROP CONSTRAINT IF EXISTS scheduled_transaction_template_root_account_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_transaction DROP CONSTRAINT IF EXISTS scheduled_transaction_payee_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_transaction DROP CONSTRAINT IF EXISTS scheduled_transaction_ledger_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_transaction DROP CONSTRAINT IF EXISTS scheduled_transaction_currency_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_split DROP CONSTRAINT IF EXISTS scheduled_split_scheduled_transaction_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_split DROP CONSTRAINT IF EXISTS scheduled_split_account_id_fkey;
ALTER TABLE IF EXISTS ONLY public.recurrence DROP CONSTRAINT IF EXISTS recurrence_scheduled_transaction_id_fkey;
ALTER TABLE IF EXISTS ONLY public.price DROP CONSTRAINT IF EXISTS price_currency_id_fkey;
ALTER TABLE IF EXISTS ONLY public.price DROP CONSTRAINT IF EXISTS price_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.payee DROP CONSTRAINT IF EXISTS payee_ledger_id_fkey;
ALTER TABLE IF EXISTS ONLY public.ledger DROP CONSTRAINT IF EXISTS ledger_owner_id_fkey;
ALTER TABLE IF EXISTS ONLY public.ledger DROP CONSTRAINT IF EXISTS ledger_currency_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.ledger DROP CONSTRAINT IF EXISTS ledger_coa_template_id_fkey;
ALTER TABLE IF EXISTS ONLY public.ledger DROP CONSTRAINT IF EXISTS fk_ledger_root_account;
ALTER TABLE IF EXISTS ONLY public.coa_template_node DROP CONSTRAINT IF EXISTS coa_template_node_template_id_fkey;
ALTER TABLE IF EXISTS ONLY public.auth_identity DROP CONSTRAINT IF EXISTS auth_identity_ledger_owner_id_fkey;
ALTER TABLE IF EXISTS ONLY public.account DROP CONSTRAINT IF EXISTS account_parent_id_fkey;
ALTER TABLE IF EXISTS ONLY public.account DROP CONSTRAINT IF EXISTS account_ledger_id_fkey;
ALTER TABLE IF EXISTS ONLY public.account DROP CONSTRAINT IF EXISTS account_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.account DROP CONSTRAINT IF EXISTS account_account_type_id_fkey;
DROP INDEX IF EXISTS public.uq_account_ledger_code;
DROP INDEX IF EXISTS public.idx_tx_ledger_post_date;
DROP INDEX IF EXISTS public.idx_split_tx;
DROP INDEX IF EXISTS public.idx_split_account;
DROP INDEX IF EXISTS public.idx_schedtx_ledger;
DROP INDEX IF EXISTS public.idx_schedsplit_schedtx;
DROP INDEX IF EXISTS public.idx_schedsplit_account;
DROP INDEX IF EXISTS public.idx_recur_schedtx;
DROP INDEX IF EXISTS public.idx_price_date;
DROP INDEX IF EXISTS public.idx_payee_ledger;
DROP INDEX IF EXISTS public.idx_ledger_owner;
DROP INDEX IF EXISTS public.idx_coa_node_template_parent;
DROP INDEX IF EXISTS public.idx_coa_node_template_level;
DROP INDEX IF EXISTS public.idx_coa_node_template_code;
DROP INDEX IF EXISTS public.idx_auth_identity_owner;
DROP INDEX IF EXISTS public.idx_account_parent;
DROP INDEX IF EXISTS public.idx_account_ledger;
DROP INDEX IF EXISTS public.commodity_namespace_mnemonic_ux;
DROP INDEX IF EXISTS public.commodity_namespace_mnemonic_uq;
ALTER TABLE IF EXISTS ONLY public.transaction DROP CONSTRAINT IF EXISTS transaction_pkey;
ALTER TABLE IF EXISTS ONLY public.split DROP CONSTRAINT IF EXISTS split_pkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_transaction DROP CONSTRAINT IF EXISTS scheduled_transaction_pkey;
ALTER TABLE IF EXISTS ONLY public.scheduled_split DROP CONSTRAINT IF EXISTS scheduled_split_pkey;
ALTER TABLE IF EXISTS ONLY public.recurrence DROP CONSTRAINT IF EXISTS recurrence_pkey;
ALTER TABLE IF EXISTS ONLY public.price DROP CONSTRAINT IF EXISTS price_pkey;
ALTER TABLE IF EXISTS ONLY public.price DROP CONSTRAINT IF EXISTS price_commodity_id_currency_id_date_key;
ALTER TABLE IF EXISTS ONLY public.payee DROP CONSTRAINT IF EXISTS payee_pkey;
ALTER TABLE IF EXISTS ONLY public.payee DROP CONSTRAINT IF EXISTS payee_ledger_id_name_key;
ALTER TABLE IF EXISTS ONLY public.ledger DROP CONSTRAINT IF EXISTS ledger_pkey;
ALTER TABLE IF EXISTS ONLY public.ledger_owner DROP CONSTRAINT IF EXISTS ledger_owner_pkey;
ALTER TABLE IF EXISTS ONLY public.ledger_owner DROP CONSTRAINT IF EXISTS ledger_owner_email_key;
ALTER TABLE IF EXISTS ONLY public.enum_label DROP CONSTRAINT IF EXISTS enum_label_pkey;
ALTER TABLE IF EXISTS ONLY public.commodity DROP CONSTRAINT IF EXISTS commodity_pkey;
ALTER TABLE IF EXISTS ONLY public.coa_template DROP CONSTRAINT IF EXISTS coa_template_pkey;
ALTER TABLE IF EXISTS ONLY public.coa_template_node DROP CONSTRAINT IF EXISTS coa_template_node_template_id_code_key;
ALTER TABLE IF EXISTS ONLY public.coa_template_node DROP CONSTRAINT IF EXISTS coa_template_node_pkey;
ALTER TABLE IF EXISTS ONLY public.coa_template DROP CONSTRAINT IF EXISTS coa_template_code_version_key;
ALTER TABLE IF EXISTS ONLY public.auth_identity DROP CONSTRAINT IF EXISTS auth_identity_provider_provider_user_id_key;
ALTER TABLE IF EXISTS ONLY public.auth_identity DROP CONSTRAINT IF EXISTS auth_identity_pkey;
ALTER TABLE IF EXISTS ONLY public.account_type DROP CONSTRAINT IF EXISTS account_type_pkey;
ALTER TABLE IF EXISTS ONLY public.account DROP CONSTRAINT IF EXISTS account_pkey;
DROP TABLE IF EXISTS public.transaction;
DROP TABLE IF EXISTS public.split;
DROP TABLE IF EXISTS public.scheduled_transaction;
DROP TABLE IF EXISTS public.scheduled_split;
DROP TABLE IF EXISTS public.recurrence;
DROP TABLE IF EXISTS public.price;
DROP TABLE IF EXISTS public.payee;
DROP TABLE IF EXISTS public.ledger_owner;
DROP TABLE IF EXISTS public.ledger;
DROP TABLE IF EXISTS public.enum_label;
DROP TABLE IF EXISTS public.commodity;
DROP TABLE IF EXISTS public.coa_template_node;
DROP TABLE IF EXISTS public.coa_template;
DROP TABLE IF EXISTS public.auth_identity;
DROP TABLE IF EXISTS public.account_type;
DROP TABLE IF EXISTS public.account;
DROP FUNCTION IF EXISTS public.mab_void_transaction(p_tx_id uuid, p_reason text);
DROP FUNCTION IF EXISTS public.mab_reverse_transaction(p_tx_id uuid, p_post_date timestamp with time zone, p_enter_date timestamp with time zone, p_memo text);
DROP FUNCTION IF EXISTS public.mab_post_transaction(p_ledger_id uuid, p_splits jsonb, p_post_date timestamp with time zone, p_enter_date timestamp with time zone, p_memo text, p_num text, p_status smallint, p_currency_commodity_id uuid, p_payee_id uuid);
DROP FUNCTION IF EXISTS public.mab__assert(p_ok boolean, p_message text);
DROP FUNCTION IF EXISTS public.instantiate_coa_template_to_ledger(p_template_id uuid, p_ledger_id uuid);
DROP FUNCTION IF EXISTS public.instantiate_coa_template(p_ledger_id uuid, p_template_id uuid);
DROP FUNCTION IF EXISTS public.create_ledger_with_optional_template(p_owner_id uuid, p_ledger_name text, p_currency_mnemonic text, p_precision smallint, p_template_label text, p_coa_template_code text, p_coa_template_version text);
DROP EXTENSION IF EXISTS pgcrypto;
--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: create_ledger_with_optional_template(uuid, text, text, smallint, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_ledger_with_optional_template(p_owner_id uuid, p_ledger_name text, p_currency_mnemonic text DEFAULT 'MXN'::text, p_precision smallint DEFAULT 2, p_template_label text DEFAULT 'CUSTOM'::text, p_coa_template_code text DEFAULT NULL::text, p_coa_template_version text DEFAULT NULL::text) RETURNS TABLE(ledger_id uuid, root_account_id uuid, coa_template_id uuid, currency_commodity_id uuid)
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


--
-- Name: instantiate_coa_template(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.instantiate_coa_template(p_ledger_id uuid, p_template_id uuid) RETURNS void
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


--
-- Name: instantiate_coa_template_to_ledger(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.instantiate_coa_template_to_ledger(p_template_id uuid, p_ledger_id uuid) RETURNS uuid
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


--
-- Name: mab__assert(boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mab__assert(p_ok boolean, p_message text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT p_ok THEN
    RAISE EXCEPTION USING MESSAGE = p_message, ERRCODE = 'P0001';
  END IF;
END;
$$;


--
-- Name: mab_post_transaction(uuid, jsonb, timestamp with time zone, timestamp with time zone, text, text, smallint, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mab_post_transaction(p_ledger_id uuid, p_splits jsonb, p_post_date timestamp with time zone DEFAULT now(), p_enter_date timestamp with time zone DEFAULT now(), p_memo text DEFAULT NULL::text, p_num text DEFAULT NULL::text, p_status smallint DEFAULT 0, p_currency_commodity_id uuid DEFAULT NULL::uuid, p_payee_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_tx_id uuid;
  v_distinct_value_denoms int;
  v_net_value_num bigint;
  v_has_memo boolean;
  v_has_non_memo boolean;
  v_has_mem_debit boolean;
  v_has_mem_credit boolean;
BEGIN
  -- 1) Concurrency control: one posting flow at a time per ledger
  PERFORM pg_advisory_xact_lock(hashtext(p_ledger_id::text));

  -- 2) Basic input validation
  PERFORM mab__assert(p_ledger_id IS NOT NULL, 'ledger_id is required');
  PERFORM mab__assert(p_splits IS NOT NULL AND jsonb_typeof(p_splits) = 'array', 'splits must be a JSON array');
  PERFORM mab__assert(jsonb_array_length(p_splits) > 0, 'splits array cannot be empty');

  -- 3) Stage splits into a temp table for validation + bulk insert
  CREATE TEMP TABLE _mab_stg_splits (
    account_id     uuid NOT NULL,
    side           smallint NOT NULL,
    value_num      bigint NOT NULL,
    value_denom    integer NOT NULL,
    quantity_num   bigint NOT NULL DEFAULT 0,
    quantity_denom integer NOT NULL DEFAULT 100,
    memo           text NULL,
    action         text NULL
  ) ON COMMIT DROP;

  INSERT INTO _mab_stg_splits(account_id, side, value_num, value_denom, quantity_num, quantity_denom, memo, action)
  SELECT
    (x.account_id)::uuid,
    COALESCE((x.side)::smallint, 0),
    COALESCE((x.value_num)::bigint, 0),
    COALESCE((x.value_denom)::int, 100),
    COALESCE((x.quantity_num)::bigint, 0),
    COALESCE((x.quantity_denom)::int, 100),
    x.memo,
    x.action
  FROM jsonb_to_recordset(p_splits) AS x(
    account_id text,
    side int,
    value_num bigint,
    value_denom int,
    quantity_num bigint,
    quantity_denom int,
    memo text,
    action text
  );

  -- 4) Validate staging rows
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE account_id IS NULL), 'All splits must include account_id');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE side NOT IN (0,1)), 'split.side must be 0 (DEBIT) or 1 (CREDIT)');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE value_denom <= 0), 'value_denom must be > 0');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE quantity_denom <= 0), 'quantity_denom must be > 0');

  -- For canonical arithmetic, require a single denominator per transaction (common precision)
  SELECT COUNT(DISTINCT value_denom) INTO v_distinct_value_denoms FROM _mab_stg_splits;
  PERFORM mab__assert(v_distinct_value_denoms = 1, 'All splits must share the same value_denom (single precision per transaction)');

  -- 5) Validate accounts: exist, same ledger, not placeholder/deleted
  PERFORM mab__assert(
    NOT EXISTS (
      SELECT 1
      FROM _mab_stg_splits s
      LEFT JOIN account a ON a.id = s.account_id
      WHERE a.id IS NULL
    ),
    'All splits must reference an existing account'
  );

  PERFORM mab__assert(
    NOT EXISTS (
      SELECT 1
      FROM _mab_stg_splits s
      JOIN account a ON a.id = s.account_id
      WHERE a.ledger_id <> p_ledger_id
    ),
    'All split accounts must belong to the same ledger as the transaction'
  );

  PERFORM mab__assert(
    NOT EXISTS (
      SELECT 1
      FROM _mab_stg_splits s
      JOIN account a ON a.id = s.account_id
      WHERE a.is_placeholder = true
    ),
    'Cannot post to placeholder accounts'
  );

  PERFORM mab__assert(
    NOT EXISTS (
      SELECT 1
      FROM _mab_stg_splits s
      JOIN account a ON a.id = s.account_id
      WHERE a.deleted_at IS NOT NULL
    ),
    'Cannot post to deleted accounts'
  );

  -- Optionally enforce active accounts only (uncomment if desired)
  -- PERFORM mab__assert(
  --   NOT EXISTS (
  --     SELECT 1
  --     FROM _mab_stg_splits s
  --     JOIN account a ON a.id = s.account_id
  --     WHERE a.is_active = false
  --   ),
  --   'Cannot post to inactive accounts'
  -- );

  -- 6) Memo logic: detect memo accounts via account_type.code
  -- Memo accounts are expected to be typed as MEM_DEBIT / MEM_CREDIT in account_type.code.
  SELECT
    BOOL_OR(at.code IN ('MEM_DEBIT','MEM_CREDIT')) AS has_memo,
    BOOL_OR(at.code NOT IN ('MEM_DEBIT','MEM_CREDIT') OR at.code IS NULL) AS has_non_memo,
    BOOL_OR(at.code = 'MEM_DEBIT') AS has_mem_debit,
    BOOL_OR(at.code = 'MEM_CREDIT') AS has_mem_credit
  INTO v_has_memo, v_has_non_memo, v_has_mem_debit, v_has_mem_credit
  FROM _mab_stg_splits s
  JOIN account a ON a.id = s.account_id
  LEFT JOIN account_type at ON at.id = a.account_type_id;

  -- Reject mixing memo + real in same transaction
  PERFORM mab__assert(NOT (v_has_memo AND v_has_non_memo), 'Cannot mix memo and non-memo accounts in the same transaction');

  -- If memo transaction, require at least one of each memo type (unless everything is zero)
  IF v_has_memo THEN
    PERFORM mab__assert(v_has_mem_debit AND v_has_mem_credit, 'Memo transactions must include at least one MEM_DEBIT and one MEM_CREDIT account');
  END IF;

  -- 7) Balance check (canonical): net must be zero
  SELECT COALESCE(SUM(CASE WHEN side = 0 THEN value_num ELSE -value_num END), 0)
  INTO v_net_value_num
  FROM _mab_stg_splits;

  PERFORM mab__assert(v_net_value_num = 0, 'Transaction is not balanced (net value_num must be zero)');

  -- 8) Insert transaction header
  INSERT INTO transaction(
    ledger_id,
    enter_date,
    post_date,
    memo,
    num,
    status,
    currency_commodity_id,
    payee_id
  )
  VALUES (
    p_ledger_id,
    COALESCE(p_enter_date, now()),
    COALESCE(p_post_date, now()),
    p_memo,
    p_num,
    COALESCE(p_status, 0),
    p_currency_commodity_id,
    p_payee_id
  )
  RETURNING id INTO v_tx_id;

  -- 9) Bulk insert splits
  INSERT INTO split(
    account_id,
    transaction_id,
    side,
    value_num,
    value_denom,
    quantity_num,
    quantity_denom,
    memo,
    action,

    -- presentation amount: derived (unsigned) from rational
    amount
  )
  SELECT
    s.account_id,
    v_tx_id,
    s.side,
    s.value_num,
    s.value_denom,
    s.quantity_num,
    s.quantity_denom,
    s.memo,
    s.action,
    (ABS(s.value_num)::numeric / NULLIF(s.value_denom, 0))::numeric(38,10)
  FROM _mab_stg_splits s;

  RETURN v_tx_id;
END;
$$;


--
-- Name: mab_reverse_transaction(uuid, timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mab_reverse_transaction(p_tx_id uuid, p_post_date timestamp with time zone DEFAULT now(), p_enter_date timestamp with time zone DEFAULT now(), p_memo text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_src transaction%ROWTYPE;
  v_new_tx_id uuid;
BEGIN
  PERFORM mab__assert(p_tx_id IS NOT NULL, 'tx_id is required');

  SELECT * INTO v_src
  FROM transaction
  WHERE id = p_tx_id;

  PERFORM mab__assert(v_src.id IS NOT NULL, 'Transaction not found');
  PERFORM mab__assert(v_src.deleted_at IS NULL, 'Cannot reverse a deleted transaction');
  PERFORM mab__assert(v_src.is_voided = false, 'Cannot reverse a voided transaction');

  -- Lock ledger for concurrency safety
  PERFORM pg_advisory_xact_lock(hashtext(v_src.ledger_id::text));

  INSERT INTO transaction(
    ledger_id,
    enter_date,
    post_date,
    memo,
    num,
    status,
    currency_commodity_id,
    payee_id
  )
  VALUES (
    v_src.ledger_id,
    COALESCE(p_enter_date, now()),
    COALESCE(p_post_date, now()),
    COALESCE(p_memo, 'Reversal of ' || v_src.id::text),
    v_src.num,
    v_src.status,
    v_src.currency_commodity_id,
    v_src.payee_id
  )
  RETURNING id INTO v_new_tx_id;

  INSERT INTO split(
    account_id,
    transaction_id,
    side,
    value_num,
    value_denom,
    quantity_num,
    quantity_denom,
    memo,
    action,
    amount
  )
  SELECT
    s.account_id,
    v_new_tx_id,
    CASE WHEN s.side = 0 THEN 1 ELSE 0 END AS side,
    s.value_num,
    s.value_denom,
    s.quantity_num,
    s.quantity_denom,
    COALESCE(s.memo, '') || ' (reversal)',
    s.action,
    s.amount
  FROM split s
  WHERE s.transaction_id = v_src.id
    AND s.deleted_at IS NULL;

  RETURN v_new_tx_id;
END;
$$;


--
-- Name: mab_void_transaction(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mab_void_transaction(p_tx_id uuid, p_reason text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_ledger_id uuid;
BEGIN
  PERFORM mab__assert(p_tx_id IS NOT NULL, 'tx_id is required');

  SELECT ledger_id INTO v_ledger_id
  FROM transaction
  WHERE id = p_tx_id;

  PERFORM mab__assert(v_ledger_id IS NOT NULL, 'Transaction not found');

  PERFORM pg_advisory_xact_lock(hashtext(v_ledger_id::text));

  UPDATE transaction
  SET
    is_voided = true,
    memo = COALESCE(memo, '') || CASE WHEN p_reason IS NULL THEN '' ELSE ' [VOID: ' || p_reason || ']' END,
    updated_at = now(),
    revision = revision + 1
  WHERE id = p_tx_id
    AND is_voided = false;

  PERFORM mab__assert(FOUND, 'Transaction is already voided (or not found)');
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    account_role smallint DEFAULT 0 NOT NULL,
    code text,
    commodity_scu integer DEFAULT 100 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    is_placeholder boolean DEFAULT false NOT NULL,
    kind smallint DEFAULT 1 NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    non_std_scu integer DEFAULT 0 NOT NULL,
    notes text,
    account_type_id uuid,
    commodity_id uuid,
    parent_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT chk_account_kind CHECK ((kind = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8]))),
    CONSTRAINT chk_account_role CHECK ((account_role = ANY (ARRAY[0, 100, 101, 110, 120, 130, 131, 199, 200, 210, 220, 299, 300, 310, 320, 400, 410, 420, 430, 499, 500, 510, 600, 610, 620, 699, 700, 800, 4300, 4301, 4310, 4311, 4320, 4321, 4330, 4331, 4340, 4341, 4390, 4391, 900])))
);


--
-- Name: account_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_type (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text DEFAULT 'No Code'::text NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    standard text DEFAULT 'SAT/NIIF'::text,
    kind smallint DEFAULT 1 NOT NULL,
    normal_balance smallint DEFAULT 0 NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_identity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_owner_id uuid NOT NULL,
    provider text NOT NULL,
    provider_user_id text NOT NULL,
    provider_email text,
    email_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: coa_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coa_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    country text,
    locale text,
    industry text,
    version text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: coa_template_node; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coa_template_node (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    code text NOT NULL,
    parent_code text,
    name text NOT NULL,
    level integer NOT NULL,
    kind smallint NOT NULL,
    role smallint NOT NULL,
    is_placeholder boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    account_type_code text,
    CONSTRAINT coa_template_node_level_check CHECK ((level >= 0))
);


--
-- Name: commodity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commodity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mnemonic text DEFAULT 'MXN'::text NOT NULL,
    namespace text DEFAULT 'CURRENCY'::text NOT NULL,
    full_name text DEFAULT 'No Name'::text,
    fraction bigint DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: enum_label; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enum_label (
    enum_name text NOT NULL,
    enum_value integer NOT NULL,
    locale text NOT NULL,
    label text NOT NULL,
    description text
);


--
-- Name: ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid CONSTRAINT ledger_owner_id_not_null1 NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    currency_code text DEFAULT 'MXN'::text NOT NULL,
    "precision" smallint DEFAULT 2 NOT NULL,
    template text DEFAULT 'SAT'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    currency_commodity_id uuid,
    root_account_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone,
    coa_template_id uuid
);


--
-- Name: ledger_owner; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_owner (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    password_hash text,
    display_name text DEFAULT 'No Name'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: payee; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payee (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    commodity_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    date timestamp with time zone DEFAULT now() NOT NULL,
    source text,
    type text,
    value_denom integer DEFAULT 100 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: recurrence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurrence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    mult integer DEFAULT 1 NOT NULL,
    period_start timestamp with time zone,
    period_type text,
    weekend_adjust text DEFAULT 'none'::text NOT NULL,
    scheduled_transaction_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: scheduled_split; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_split (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    memo text,
    side smallint DEFAULT 0 NOT NULL,
    value_denom integer DEFAULT 0 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    scheduled_transaction_id uuid NOT NULL,
    account_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: scheduled_transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    adv_creation integer DEFAULT 0 NOT NULL,
    adv_notify integer DEFAULT 1 NOT NULL,
    auto_create boolean DEFAULT false NOT NULL,
    auto_notify boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    end_date timestamp with time zone,
    instance_count integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_occur timestamp with time zone,
    name text,
    num_occur integer DEFAULT 0 NOT NULL,
    rem_occur integer DEFAULT 0 NOT NULL,
    start_date timestamp with time zone,
    currency_commodity_id uuid,
    payee_id uuid,
    template_root_account_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: split; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.split (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text,
    amount numeric(38,10) DEFAULT 0.0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    memo text,
    quantity_denom integer DEFAULT 100 NOT NULL,
    quantity_num bigint DEFAULT 0 NOT NULL,
    reconcile_date timestamp with time zone,
    reconcile_state boolean DEFAULT false NOT NULL,
    side smallint DEFAULT 0 NOT NULL,
    value_denom integer DEFAULT 100 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    account_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    enter_date timestamp with time zone DEFAULT now() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    memo text,
    num text,
    post_date timestamp with time zone DEFAULT now() NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    currency_commodity_id uuid,
    payee_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: account_type account_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_type
    ADD CONSTRAINT account_type_pkey PRIMARY KEY (id);


--
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY (id);


--
-- Name: auth_identity auth_identity_provider_provider_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_provider_provider_user_id_key UNIQUE (provider, provider_user_id);


--
-- Name: coa_template coa_template_code_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT coa_template_code_version_key UNIQUE (code, version);


--
-- Name: coa_template_node coa_template_node_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_pkey PRIMARY KEY (id);


--
-- Name: coa_template_node coa_template_node_template_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_template_id_code_key UNIQUE (template_id, code);


--
-- Name: coa_template coa_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT coa_template_pkey PRIMARY KEY (id);


--
-- Name: commodity commodity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commodity
    ADD CONSTRAINT commodity_pkey PRIMARY KEY (id);


--
-- Name: enum_label enum_label_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enum_label
    ADD CONSTRAINT enum_label_pkey PRIMARY KEY (enum_name, enum_value, locale);


--
-- Name: ledger_owner ledger_owner_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_owner
    ADD CONSTRAINT ledger_owner_email_key UNIQUE (email);


--
-- Name: ledger_owner ledger_owner_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_owner
    ADD CONSTRAINT ledger_owner_pkey PRIMARY KEY (id);


--
-- Name: ledger ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_pkey PRIMARY KEY (id);


--
-- Name: payee payee_ledger_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_ledger_id_name_key UNIQUE (ledger_id, name);


--
-- Name: payee payee_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_pkey PRIMARY KEY (id);


--
-- Name: price price_commodity_id_currency_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_commodity_id_currency_id_date_key UNIQUE (commodity_id, currency_id, date);


--
-- Name: price price_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_pkey PRIMARY KEY (id);


--
-- Name: recurrence recurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence
    ADD CONSTRAINT recurrence_pkey PRIMARY KEY (id);


--
-- Name: scheduled_split scheduled_split_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_pkey PRIMARY KEY (id);


--
-- Name: scheduled_transaction scheduled_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_pkey PRIMARY KEY (id);


--
-- Name: split split_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY (id);


--
-- Name: commodity_namespace_mnemonic_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX commodity_namespace_mnemonic_uq ON public.commodity USING btree (namespace, mnemonic);


--
-- Name: commodity_namespace_mnemonic_ux; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX commodity_namespace_mnemonic_ux ON public.commodity USING btree (namespace, mnemonic) WHERE (deleted_at IS NULL);


--
-- Name: idx_account_ledger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_ledger ON public.account USING btree (ledger_id);


--
-- Name: idx_account_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_parent ON public.account USING btree (parent_id);


--
-- Name: idx_auth_identity_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auth_identity_owner ON public.auth_identity USING btree (ledger_owner_id);


--
-- Name: idx_coa_node_template_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coa_node_template_code ON public.coa_template_node USING btree (template_id, code);


--
-- Name: idx_coa_node_template_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coa_node_template_level ON public.coa_template_node USING btree (template_id, level);


--
-- Name: idx_coa_node_template_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coa_node_template_parent ON public.coa_template_node USING btree (template_id, parent_code);


--
-- Name: idx_ledger_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_owner ON public.ledger USING btree (owner_id);


--
-- Name: idx_payee_ledger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payee_ledger ON public.payee USING btree (ledger_id);


--
-- Name: idx_price_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_price_date ON public.price USING btree (date);


--
-- Name: idx_recur_schedtx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recur_schedtx ON public.recurrence USING btree (scheduled_transaction_id);


--
-- Name: idx_schedsplit_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schedsplit_account ON public.scheduled_split USING btree (account_id);


--
-- Name: idx_schedsplit_schedtx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schedsplit_schedtx ON public.scheduled_split USING btree (scheduled_transaction_id);


--
-- Name: idx_schedtx_ledger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schedtx_ledger ON public.scheduled_transaction USING btree (ledger_id);


--
-- Name: idx_split_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_split_account ON public.split USING btree (account_id);


--
-- Name: idx_split_tx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_split_tx ON public.split USING btree (transaction_id);


--
-- Name: idx_tx_ledger_post_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tx_ledger_post_date ON public.transaction USING btree (ledger_id, post_date);


--
-- Name: uq_account_ledger_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_account_ledger_code ON public.account USING btree (ledger_id, code) WHERE (code IS NOT NULL);


--
-- Name: account account_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES public.account_type(id) ON DELETE SET NULL;


--
-- Name: account account_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- Name: account account_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- Name: account account_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- Name: auth_identity auth_identity_ledger_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_ledger_owner_id_fkey FOREIGN KEY (ledger_owner_id) REFERENCES public.ledger_owner(id) ON DELETE CASCADE;


--
-- Name: coa_template_node coa_template_node_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.coa_template(id) ON DELETE CASCADE;


--
-- Name: ledger fk_ledger_root_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT fk_ledger_root_account FOREIGN KEY (root_account_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- Name: ledger ledger_coa_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_coa_template_id_fkey FOREIGN KEY (coa_template_id) REFERENCES public.coa_template(id) ON DELETE SET NULL;


--
-- Name: ledger ledger_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- Name: ledger ledger_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.ledger_owner(id) ON DELETE RESTRICT;


--
-- Name: payee payee_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- Name: price price_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id) ON DELETE CASCADE;


--
-- Name: price price_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.commodity(id) ON DELETE RESTRICT;


--
-- Name: recurrence recurrence_scheduled_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence
    ADD CONSTRAINT recurrence_scheduled_transaction_id_fkey FOREIGN KEY (scheduled_transaction_id) REFERENCES public.scheduled_transaction(id) ON DELETE CASCADE;


--
-- Name: scheduled_split scheduled_split_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id) ON DELETE RESTRICT;


--
-- Name: scheduled_split scheduled_split_scheduled_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_scheduled_transaction_id_fkey FOREIGN KEY (scheduled_transaction_id) REFERENCES public.scheduled_transaction(id) ON DELETE CASCADE;


--
-- Name: scheduled_transaction scheduled_transaction_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- Name: scheduled_transaction scheduled_transaction_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- Name: scheduled_transaction scheduled_transaction_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.payee(id) ON DELETE SET NULL;


--
-- Name: scheduled_transaction scheduled_transaction_template_root_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_template_root_account_id_fkey FOREIGN KEY (template_root_account_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- Name: split split_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id) ON DELETE RESTRICT;


--
-- Name: split split_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transaction(id) ON DELETE CASCADE;


--
-- Name: transaction transaction_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- Name: transaction transaction_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- Name: transaction transaction_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.payee(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict S8v9g2qVKfcg4mRFnpFBu6HpyskX7QohEcyfZVZqB1OmDefRFaXnciDbigPGHRF

