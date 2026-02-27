-- =============================================================================
-- Migration: V2__corrective_fixes.sql
-- Target:    myaccounting_dev (PostgreSQL 18.1)
-- Author:    Schema Review — 2026-02-27
-- Scope:     P1 Critical + P2 Medium fixes from architecture review
-- Strategy:  Idempotent where possible; wrapped in a single transaction.
--            Run with: psql -v ON_ERROR_STOP=1 -f V2__corrective_fixes.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- SECTION 1 · P1-A: Remove duplicate unconditional unique index on commodity
--             Keep: commodity_namespace_mnemonic_ux (partial, WHERE deleted_at IS NULL)
--             Drop: commodity_namespace_mnemonic_uq (unconditional — blocks soft-delete re-use)
-- ---------------------------------------------------------------------------

DROP INDEX IF EXISTS public.commodity_namespace_mnemonic_uq;

-- Verify the partial index still exists (guard)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename  = 'commodity'
          AND indexname  = 'commodity_namespace_mnemonic_ux'
    ) THEN
        RAISE EXCEPTION 'GUARD FAILED: commodity_namespace_mnemonic_ux is missing. Aborting.';
    END IF;
END;
$$;


-- ---------------------------------------------------------------------------
-- SECTION 2 · P1-B: Make ledger.currency_commodity_id NOT NULL
--             Pre-check: fail fast if any ledger already has NULL (data issue).
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.ledger WHERE currency_commodity_id IS NULL
    ) THEN
        RAISE EXCEPTION
            'DATA INTEGRITY VIOLATION: One or more ledger rows have currency_commodity_id = NULL. '
            'Fix the data before applying this migration.';
    END IF;
END;
$$;

ALTER TABLE public.ledger
    ALTER COLUMN currency_commodity_id SET NOT NULL;

-- Tighten the FK: SET NULL → RESTRICT (a currency in use cannot be deleted)
ALTER TABLE public.ledger
    DROP CONSTRAINT IF EXISTS ledger_currency_commodity_id_fkey;

ALTER TABLE public.ledger
    ADD CONSTRAINT ledger_currency_commodity_id_fkey
        FOREIGN KEY (currency_commodity_id)
        REFERENCES public.commodity(id)
        ON DELETE RESTRICT;


-- ---------------------------------------------------------------------------
-- SECTION 3 · P1-C: Make transaction.currency_commodity_id NOT NULL
--             Pre-check: fail fast if any existing transaction has NULL.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.transaction WHERE currency_commodity_id IS NULL
    ) THEN
        RAISE EXCEPTION
            'DATA INTEGRITY VIOLATION: One or more transaction rows have currency_commodity_id = NULL. '
            'Fix the data before applying this migration.';
    END IF;
END;
$$;

ALTER TABLE public.transaction
    ALTER COLUMN currency_commodity_id SET NOT NULL;

ALTER TABLE public.transaction
    DROP CONSTRAINT IF EXISTS transaction_currency_commodity_id_fkey;

ALTER TABLE public.transaction
    ADD CONSTRAINT transaction_currency_commodity_id_fkey
        FOREIGN KEY (currency_commodity_id)
        REFERENCES public.commodity(id)
        ON DELETE RESTRICT;


-- ---------------------------------------------------------------------------
-- SECTION 4 · P1-C (function): Add NULL assert for currency_commodity_id
--             in mab_post_transaction, immediately after existing basic checks.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mab_post_transaction(
    p_ledger_id              uuid,
    p_splits                 jsonb,
    p_post_date              timestamp with time zone DEFAULT now(),
    p_enter_date             timestamp with time zone DEFAULT now(),
    p_memo                   text    DEFAULT NULL::text,
    p_num                    text    DEFAULT NULL::text,
    p_status                 smallint DEFAULT 0,
    p_currency_commodity_id  uuid    DEFAULT NULL::uuid,
    p_payee_id               uuid    DEFAULT NULL::uuid
) RETURNS uuid
    LANGUAGE plpgsql
AS $$
DECLARE
  v_tx_id                 uuid;
  v_distinct_value_denoms int;
  v_net_value_num         bigint;
  v_has_memo              boolean;
  v_has_non_memo          boolean;
  v_has_mem_debit         boolean;
  v_has_mem_credit        boolean;
BEGIN
  -- 1) Concurrency control: one posting flow at a time per ledger
  PERFORM pg_advisory_xact_lock(hashtext(p_ledger_id::text));

  -- 2) Basic input validation
  PERFORM mab__assert(p_ledger_id IS NOT NULL,                                              'ledger_id is required');
  PERFORM mab__assert(p_currency_commodity_id IS NOT NULL,                                  'currency_commodity_id is required');   -- ← NEW P1-C fix
  PERFORM mab__assert(p_splits IS NOT NULL AND jsonb_typeof(p_splits) = 'array',            'splits must be a JSON array');
  PERFORM mab__assert(jsonb_array_length(p_splits) > 0,                                     'splits array cannot be empty');

  -- 3) Stage splits into a temp table for validation + bulk insert
  CREATE TEMP TABLE _mab_stg_splits (
    account_id     uuid    NOT NULL,
    side           smallint NOT NULL,
    value_num      bigint  NOT NULL,
    value_denom    integer NOT NULL,
    quantity_num   bigint  NOT NULL DEFAULT 0,
    quantity_denom integer NOT NULL DEFAULT 100,
    memo           text    NULL,
    action         text    NULL
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
    account_id    text,
    side          int,
    value_num     bigint,
    value_denom   int,
    quantity_num  bigint,
    quantity_denom int,
    memo          text,
    action        text
  );

  -- 4) Validate staging rows
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE account_id IS NULL),           'All splits must include account_id');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE side NOT IN (0,1)),            'split.side must be 0 (DEBIT) or 1 (CREDIT)');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE value_denom <= 0),             'value_denom must be > 0');
  PERFORM mab__assert(NOT EXISTS (SELECT 1 FROM _mab_stg_splits WHERE quantity_denom <= 0),          'quantity_denom must be > 0');

  SELECT COUNT(DISTINCT value_denom) INTO v_distinct_value_denoms FROM _mab_stg_splits;
  PERFORM mab__assert(v_distinct_value_denoms = 1, 'All splits must share the same value_denom (single precision per transaction)');

  -- 5) Validate accounts: exist, same ledger, not placeholder/deleted
  PERFORM mab__assert(
    NOT EXISTS (SELECT 1 FROM _mab_stg_splits s LEFT JOIN account a ON a.id = s.account_id WHERE a.id IS NULL),
    'All splits must reference an existing account'
  );
  PERFORM mab__assert(
    NOT EXISTS (SELECT 1 FROM _mab_stg_splits s JOIN account a ON a.id = s.account_id WHERE a.ledger_id <> p_ledger_id),
    'All split accounts must belong to the same ledger as the transaction'
  );
  PERFORM mab__assert(
    NOT EXISTS (SELECT 1 FROM _mab_stg_splits s JOIN account a ON a.id = s.account_id WHERE a.is_placeholder = true),
    'Cannot post to placeholder accounts'
  );
  PERFORM mab__assert(
    NOT EXISTS (SELECT 1 FROM _mab_stg_splits s JOIN account a ON a.id = s.account_id WHERE a.deleted_at IS NOT NULL),
    'Cannot post to deleted accounts'
  );

  -- 6) Memo logic
  SELECT
    BOOL_OR(at.code IN ('MEM_DEBIT','MEM_CREDIT'))                              AS has_memo,
    BOOL_OR(at.code NOT IN ('MEM_DEBIT','MEM_CREDIT') OR at.code IS NULL)       AS has_non_memo,
    BOOL_OR(at.code = 'MEM_DEBIT')                                              AS has_mem_debit,
    BOOL_OR(at.code = 'MEM_CREDIT')                                             AS has_mem_credit
  INTO v_has_memo, v_has_non_memo, v_has_mem_debit, v_has_mem_credit
  FROM _mab_stg_splits s
  JOIN account a ON a.id = s.account_id
  LEFT JOIN account_type at ON at.id = a.account_type_id;

  PERFORM mab__assert(NOT (v_has_memo AND v_has_non_memo), 'Cannot mix memo and non-memo accounts in the same transaction');

  IF v_has_memo THEN
    PERFORM mab__assert(v_has_mem_debit AND v_has_mem_credit, 'Memo transactions must include at least one MEM_DEBIT and one MEM_CREDIT account');
  END IF;

  -- 7) Balance check
  SELECT COALESCE(SUM(CASE WHEN side = 0 THEN value_num ELSE -value_num END), 0)
  INTO v_net_value_num
  FROM _mab_stg_splits;

  PERFORM mab__assert(v_net_value_num = 0, 'Transaction is not balanced (net value_num must be zero)');

  -- 8) Insert transaction header
  INSERT INTO transaction(ledger_id, enter_date, post_date, memo, num, status, currency_commodity_id, payee_id)
  VALUES (
    p_ledger_id,
    COALESCE(p_enter_date, now()),
    COALESCE(p_post_date,  now()),
    p_memo,
    p_num,
    COALESCE(p_status, 0),
    p_currency_commodity_id,
    p_payee_id
  )
  RETURNING id INTO v_tx_id;

  -- 9) Bulk insert splits (amount is now a generated column — omitted from INSERT)
  INSERT INTO split(
    account_id, transaction_id, side,
    value_num, value_denom,
    quantity_num, quantity_denom,
    memo, action
  )
  SELECT
    s.account_id, v_tx_id, s.side,
    s.value_num, s.value_denom,
    s.quantity_num, s.quantity_denom,
    s.memo, s.action
  FROM _mab_stg_splits s;

  RETURN v_tx_id;
END;
$$;


-- ---------------------------------------------------------------------------
-- SECTION 5 · P2-A: Convert split.amount to a GENERATED ALWAYS AS column
--             Eliminates redundant storage and staleness risk.
--             Step 1: drop old column + constraint, Step 2: add generated column.
-- ---------------------------------------------------------------------------

ALTER TABLE public.split
    DROP CONSTRAINT IF EXISTS chk_split_amount;

ALTER TABLE public.split
    DROP COLUMN IF EXISTS amount;

ALTER TABLE public.split
    ADD COLUMN amount numeric(19, 10)
        GENERATED ALWAYS AS (
            ABS(value_num::numeric) / NULLIF(value_denom, 0)
        ) STORED;


-- ---------------------------------------------------------------------------
-- SECTION 6 · P2-B: Remove ledger.currency_code (redundant with currency_commodity_id FK)
--             Then create v_ledger view to preserve application compatibility.
-- ---------------------------------------------------------------------------

ALTER TABLE public.ledger
    DROP COLUMN IF EXISTS currency_code;

-- Compatibility view: exposes currency_code as a derived field for existing queries
CREATE OR REPLACE VIEW public.v_ledger AS
    SELECT
        l.id,
        l.owner_id,
        l.name,
        c.mnemonic                      AS currency_code,
        l."precision",
        l.template,
        l.is_active,
        l.closed_at,
        l.created_at,
        l.currency_commodity_id,
        l.root_account_id,
        l.coa_template_id,
        l.updated_at,
        l.revision,
        l.deleted_at
    FROM public.ledger l
    JOIN public.commodity c ON c.id = l.currency_commodity_id;

COMMENT ON VIEW public.v_ledger IS
    'Compatibility view: exposes currency_code derived from commodity.mnemonic. '
    'Use instead of direct ledger table access when currency_code text is needed.';


-- ---------------------------------------------------------------------------
-- SECTION 7 · P2-C: Add soft-delete column to coa_template
-- ---------------------------------------------------------------------------

ALTER TABLE public.coa_template
    ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

-- Update is_active filter convention: active = is_active AND deleted_at IS NULL
-- No data change needed; existing rows default to deleted_at = NULL (not deleted).


-- ---------------------------------------------------------------------------
-- SECTION 8 · P2-D: Add CHECK constraints on recurrence free-text columns
-- ---------------------------------------------------------------------------

ALTER TABLE public.recurrence
    DROP CONSTRAINT IF EXISTS chk_recurrence_period_type,
    DROP CONSTRAINT IF EXISTS chk_recurrence_weekend_adjust;

ALTER TABLE public.recurrence
    ADD CONSTRAINT chk_recurrence_period_type CHECK (
        period_type IS NULL
        OR period_type IN ('daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly')
    ),
    ADD CONSTRAINT chk_recurrence_weekend_adjust CHECK (
        weekend_adjust IN ('none', 'forward', 'back', 'nearest')
    );


-- ---------------------------------------------------------------------------
-- SECTION 9 · P2-E: Missing performance indexes
--             All partial (WHERE deleted_at IS NULL) to match soft-delete pattern.
-- ---------------------------------------------------------------------------

-- split — hottest table in the system
CREATE INDEX IF NOT EXISTS idx_split_transaction_id
    ON public.split(transaction_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_split_account_id
    ON public.split(account_id)
    WHERE deleted_at IS NULL;

-- transaction — ledger register queries
CREATE INDEX IF NOT EXISTS idx_transaction_ledger_postdate
    ON public.transaction(ledger_id, post_date DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_transaction_ledger_id
    ON public.transaction(ledger_id)
    WHERE deleted_at IS NULL;

-- account — tree traversal + ledger-scoped lookups
CREATE INDEX IF NOT EXISTS idx_account_ledger_id
    ON public.account(ledger_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_account_parent_id
    ON public.account(parent_id)
    WHERE parent_id IS NOT NULL AND deleted_at IS NULL;

-- payee
CREATE INDEX IF NOT EXISTS idx_payee_ledger_id
    ON public.payee(ledger_id)
    WHERE deleted_at IS NULL;

-- scheduled_transaction
CREATE INDEX IF NOT EXISTS idx_scheduled_transaction_ledger_id
    ON public.scheduled_transaction(ledger_id)
    WHERE deleted_at IS NULL;

-- price — time-series lookups
CREATE INDEX IF NOT EXISTS idx_price_commodity_date
    ON public.price(commodity_id, date DESC)
    WHERE deleted_at IS NULL;

-- auth_identity — login join
CREATE INDEX IF NOT EXISTS idx_auth_identity_owner_id
    ON public.auth_identity(ledger_owner_id)
    WHERE deleted_at IS NULL;


-- ---------------------------------------------------------------------------
-- SECTION 10 · P2-F: Deprecate instantiate_coa_template (older, unsafe version)
--              Replaced by instantiate_coa_template_to_ledger.
--              Wrap in a stub that raises an informative error rather than hard-drop,
--              to avoid breaking any existing call sites silently.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.instantiate_coa_template(
    p_ledger_id   uuid,
    p_template_id uuid
) RETURNS void
    LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'instantiate_coa_template() is deprecated as of V2 migration. '
        'Use instantiate_coa_template_to_ledger(p_template_id, p_ledger_id) instead. '
        'Note argument order is reversed in the new function.';
END;
$$;

COMMENT ON FUNCTION public.instantiate_coa_template(uuid, uuid) IS
    'DEPRECATED since V2__corrective_fixes. Use instantiate_coa_template_to_ledger() instead.';


-- ---------------------------------------------------------------------------
-- SECTION 11 · P2-G: Standardize commodity_scu resolution in
--              create_ledger_with_optional_template
--              Replaces hardcoded 100 with actual commodity.fraction (capped at INT max).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_ledger_with_optional_template(
    p_owner_id            uuid,
    p_ledger_name         text,
    p_currency_mnemonic   text      DEFAULT 'MXN'::text,
    p_precision           smallint  DEFAULT 2,
    p_template_label      text      DEFAULT 'CUSTOM'::text,
    p_coa_template_code   text      DEFAULT NULL::text,
    p_coa_template_version text     DEFAULT NULL::text
) RETURNS TABLE(ledger_id uuid, root_account_id uuid, coa_template_id uuid, currency_commodity_id uuid)
    LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_exists  boolean;
    v_currency_id   uuid;
    v_currency_scu  integer;
    v_template_id   uuid;
    v_root_id       uuid;
BEGIN
    -- 1) Validate owner
    SELECT EXISTS(
        SELECT 1 FROM public.ledger_owner lo
         WHERE lo.id = p_owner_id AND lo.deleted_at IS NULL
    ) INTO v_owner_exists;

    IF NOT v_owner_exists THEN
        RAISE EXCEPTION 'ledger_owner % not found (or deleted)', p_owner_id;
    END IF;

    -- 2) Resolve currency commodity
    SELECT c.id,
           LEAST(c.fraction, 2147483647)::integer   -- cap to INT max
      INTO v_currency_id, v_currency_scu
      FROM public.commodity c
     WHERE c.namespace   = 'CURRENCY'
       AND c.mnemonic    = p_currency_mnemonic
       AND c.deleted_at  IS NULL
     LIMIT 1;

    IF v_currency_id IS NULL THEN
        RAISE EXCEPTION 'Currency commodity not found for mnemonic=% (namespace=CURRENCY)', p_currency_mnemonic;
    END IF;

    -- 3) Resolve template (optional)
    v_template_id := NULL;
    IF p_coa_template_code IS NOT NULL AND p_coa_template_version IS NOT NULL THEN
        SELECT t.id INTO v_template_id
          FROM public.coa_template t
         WHERE t.code      = p_coa_template_code
           AND t.version   = p_coa_template_version
           AND t.is_active = TRUE
           AND t.deleted_at IS NULL        -- ← respects new soft-delete on coa_template
         LIMIT 1;

        IF v_template_id IS NULL THEN
            RAISE EXCEPTION 'COA template not found for code=% version=%', p_coa_template_code, p_coa_template_version;
        END IF;
    ELSIF p_coa_template_code IS NOT NULL OR p_coa_template_version IS NOT NULL THEN
        RAISE EXCEPTION 'Both p_coa_template_code and p_coa_template_version must be provided together (or both NULL)';
    END IF;

    -- 4) Create ledger (no currency_code column — removed in P2-B)
    INSERT INTO public.ledger (
        owner_id, name, "precision", template, is_active,
        currency_commodity_id, root_account_id, coa_template_id
    )
    VALUES (
        p_owner_id,
        COALESCE(NULLIF(p_ledger_name, ''), 'No Name'),
        COALESCE(p_precision, 2),
        COALESCE(NULLIF(p_template_label, ''), 'CUSTOM'),
        TRUE,
        v_currency_id,
        NULL,
        v_template_id
    )
    RETURNING id INTO ledger_id;

    currency_commodity_id := v_currency_id;
    coa_template_id       := v_template_id;

    -- 5) Instantiate template if provided
    v_root_id := NULL;
    IF v_template_id IS NOT NULL THEN
        -- Delegate to the canonical, validated instantiation function
        v_root_id := public.instantiate_coa_template_to_ledger(v_template_id, ledger_id);
    END IF;

    root_account_id := v_root_id;
    RETURN NEXT;
END;
$$;


-- ---------------------------------------------------------------------------
-- FINALIZE
-- ---------------------------------------------------------------------------

COMMIT;

-- Post-migration verification queries (run manually to confirm):
--
-- 1. Confirm duplicate index gone:
--    SELECT indexname FROM pg_indexes WHERE tablename='commodity' AND schemaname='public';
--
-- 2. Confirm ledger.currency_commodity_id is NOT NULL:
--    SELECT column_name, is_nullable FROM information_schema.columns
--     WHERE table_name='ledger' AND column_name='currency_commodity_id';
--
-- 3. Confirm split.amount is generated:
--    SELECT column_name, generation_expression FROM information_schema.columns
--     WHERE table_name='split' AND column_name='amount';
--
-- 4. Confirm ledger.currency_code is gone:
--    SELECT column_name FROM information_schema.columns WHERE table_name='ledger';
--
-- 5. Confirm new indexes exist:
--    SELECT indexname FROM pg_indexes WHERE schemaname='public' ORDER BY indexname;
--
-- 6. Test deprecated function raises correctly:
--    SELECT instantiate_coa_template('00000000-0000-0000-0000-000000000001'::uuid,
--                                    '00000000-0000-0000-0000-000000000002'::uuid);
