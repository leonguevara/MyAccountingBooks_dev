-- =============================================================================
-- Migration: V3__p3_p4_improvements.sql
-- Target:    myaccounting_dev (PostgreSQL 18.1)
-- Author:    Schema Review — 2026-02-27
-- Scope:     P3 Naming/Convention + P4 Architecture improvements
--            Depends on: V2__corrective_fixes.sql (must be applied first)
--
-- Sections:
--   P3-A  Rename ledger."precision"      → ledger.decimal_places
--   P3-B  Rename ledger_owner_id_not_null1 constraint
--   P3-C  Add reversed_by_tx_id to transaction (reversal traceability)
--   P3-D  Add voided_at timestamp to transaction
--   P3-E  Unify temp table naming convention (documentation — no DDL needed)
--   P4-A  Row-Level Security (RLS) for multi-tenant isolation
--   P4-B  audit_log table for compliance trail
--   P4-C  Updated mab_post_transaction, mab_void_transaction,
--          mab_reverse_transaction to use new columns + audit_log
--
-- Run with: psql -v ON_ERROR_STOP=1 -f V3__p3_p4_improvements.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- GUARD: Verify V2 was applied (check generated column on split.amount)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'split'
          AND column_name  = 'amount'
          AND generation_expression IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'V2__corrective_fixes.sql has not been applied. '
            'split.amount is not a generated column. Aborting V3.';
    END IF;
END;
$$;


-- =============================================================================
-- P3-A · Rename ledger."precision" → ledger.decimal_places
--         "precision" is a PostgreSQL reserved word; always required quoting.
-- =============================================================================

ALTER TABLE public.ledger
    RENAME COLUMN "precision" TO decimal_places;

-- Recreate v_ledger view (defined in V2) to reflect the column rename
CREATE OR REPLACE VIEW public.v_ledger AS
    SELECT
        l.id,
        l.owner_id,
        l.name,
        c.mnemonic              AS currency_code,
        l.decimal_places,
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
    'Use instead of direct ledger table access when currency_code text is needed. '
    'Updated in V3: precision → decimal_places.';

-- Update create_ledger_with_optional_template to use new column name
CREATE OR REPLACE FUNCTION public.create_ledger_with_optional_template(
    p_owner_id             uuid,
    p_ledger_name          text,
    p_currency_mnemonic    text      DEFAULT 'MXN'::text,
    p_decimal_places       smallint  DEFAULT 2,           -- renamed param for clarity
    p_template_label       text      DEFAULT 'CUSTOM'::text,
    p_coa_template_code    text      DEFAULT NULL::text,
    p_coa_template_version text      DEFAULT NULL::text
) RETURNS TABLE(ledger_id uuid, root_account_id uuid, coa_template_id uuid, currency_commodity_id uuid)
    LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_exists  boolean;
    v_currency_id   uuid;
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
    SELECT c.id INTO v_currency_id
      FROM public.commodity c
     WHERE c.namespace  = 'CURRENCY'
       AND c.mnemonic   = p_currency_mnemonic
       AND c.deleted_at IS NULL
     LIMIT 1;

    IF v_currency_id IS NULL THEN
        RAISE EXCEPTION 'Currency commodity not found for mnemonic=% (namespace=CURRENCY)', p_currency_mnemonic;
    END IF;

    -- 3) Resolve template (optional)
    v_template_id := NULL;
    IF p_coa_template_code IS NOT NULL AND p_coa_template_version IS NOT NULL THEN
        SELECT t.id INTO v_template_id
          FROM public.coa_template t
         WHERE t.code       = p_coa_template_code
           AND t.version    = p_coa_template_version
           AND t.is_active  = TRUE
           AND t.deleted_at IS NULL
         LIMIT 1;

        IF v_template_id IS NULL THEN
            RAISE EXCEPTION 'COA template not found for code=% version=%',
                p_coa_template_code, p_coa_template_version;
        END IF;
    ELSIF p_coa_template_code IS NOT NULL OR p_coa_template_version IS NOT NULL THEN
        RAISE EXCEPTION 'Both p_coa_template_code and p_coa_template_version must be provided together (or both NULL)';
    END IF;

    -- 4) Create ledger
    INSERT INTO public.ledger (
        owner_id, name, decimal_places, template, is_active,
        currency_commodity_id, root_account_id, coa_template_id
    )
    VALUES (
        p_owner_id,
        COALESCE(NULLIF(p_ledger_name, ''), 'No Name'),
        COALESCE(p_decimal_places, 2),
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
        v_root_id := public.instantiate_coa_template_to_ledger(v_template_id, ledger_id);
    END IF;

    root_account_id := v_root_id;
    RETURN NEXT;
END;
$$;


-- =============================================================================
-- P3-B · Rename malformed constraint name on ledger.owner_id
--         "ledger_owner_id_not_null1" is non-standard; replace with NOT NULL
--         enforced at column level (already true) + a clean FK constraint name.
-- =============================================================================

-- The constraint was a named NOT NULL — PostgreSQL doesn't support named NOT NULL
-- constraints directly; this was likely a CHECK workaround. Drop and rely on
-- the column-level NOT NULL instead (already enforced since table creation).
ALTER TABLE public.ledger
    DROP CONSTRAINT IF EXISTS ledger_owner_id_not_null1;

-- Verify NOT NULL is still present at column level
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name   = 'ledger'
           AND column_name  = 'owner_id'
           AND is_nullable  = 'YES'
    ) THEN
        -- Reapply if somehow lost
        ALTER TABLE public.ledger ALTER COLUMN owner_id SET NOT NULL;
    END IF;
END;
$$;


-- =============================================================================
-- P3-C · Add reversed_by_tx_id to transaction (reversal traceability)
--         Enables bidirectional lookup: source → reversal and reversal → source.
-- =============================================================================

ALTER TABLE public.transaction
    ADD COLUMN IF NOT EXISTS reversed_by_tx_id uuid;

ALTER TABLE public.transaction
    ADD CONSTRAINT IF NOT EXISTS transaction_reversed_by_tx_id_fkey
        FOREIGN KEY (reversed_by_tx_id)
        REFERENCES public.transaction(id)
        ON DELETE SET NULL;

-- Prevent a transaction from pointing to itself as its own reversal
ALTER TABLE public.transaction
    ADD CONSTRAINT IF NOT EXISTS chk_transaction_no_self_reversal
        CHECK (reversed_by_tx_id IS NULL OR reversed_by_tx_id <> id);

-- Index for reverse lookups (find the reversal of a given transaction)
CREATE INDEX IF NOT EXISTS idx_transaction_reversed_by
    ON public.transaction(reversed_by_tx_id)
    WHERE reversed_by_tx_id IS NOT NULL;


-- =============================================================================
-- P3-D · Add voided_at timestamp to transaction
--         Captures the exact moment a transaction was voided, separate from
--         updated_at (which changes on any update).
-- =============================================================================

ALTER TABLE public.transaction
    ADD COLUMN IF NOT EXISTS voided_at timestamp with time zone;

-- Enforce consistency: if is_voided = true then voided_at must be set, and vice versa
ALTER TABLE public.transaction
    ADD CONSTRAINT IF NOT EXISTS chk_transaction_voided_consistency
        CHECK (
            (is_voided = false AND voided_at IS NULL) OR
            (is_voided = true  AND voided_at IS NOT NULL)
        );

-- Backfill: for any already-voided transactions, set voided_at = updated_at
-- (best approximation available without a full audit log)
UPDATE public.transaction
   SET voided_at = updated_at
 WHERE is_voided = true
   AND voided_at IS NULL;


-- =============================================================================
-- P4-A · Row-Level Security (RLS) for multi-tenant isolation
--         Scope: ledger, account, transaction, split, payee, scheduled_transaction
--
--         Strategy:
--           - App connects as role 'mab_app' (limited privileges)
--           - Current owner is set via: SET LOCAL app.current_owner_id = '<uuid>'
--           - RLS policies enforce that rows are only visible/mutable by their owner
--
--         Setup required outside this migration:
--           CREATE ROLE mab_app LOGIN PASSWORD '...';
--           GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mab_app;
-- =============================================================================

-- Helper: current owner UUID from session variable (set by app layer)
-- Returns NULL if not set (will cause all RLS policies to deny — safe default)
CREATE OR REPLACE FUNCTION public.mab_current_owner_id()
RETURNS uuid
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
AS $$
    SELECT NULLIF(current_setting('app.current_owner_id', TRUE), '')::uuid;
$$;

COMMENT ON FUNCTION public.mab_current_owner_id() IS
    'Returns the UUID of the authenticated ledger_owner for the current session. '
    'Set via: SET LOCAL app.current_owner_id = ''<uuid>''; '
    'Returns NULL if not set — RLS policies will deny access.';

-- ── ledger ──────────────────────────────────────────────────────────────────
ALTER TABLE public.ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_ledger_owner ON public.ledger;
CREATE POLICY rls_ledger_owner ON public.ledger
    USING      (owner_id = public.mab_current_owner_id())
    WITH CHECK (owner_id = public.mab_current_owner_id());

-- ── account ─────────────────────────────────────────────────────────────────
ALTER TABLE public.account ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_account_owner ON public.account;
CREATE POLICY rls_account_owner ON public.account
    USING (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    )
    WITH CHECK (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    );

-- ── transaction ──────────────────────────────────────────────────────────────
ALTER TABLE public.transaction ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_transaction_owner ON public.transaction;
CREATE POLICY rls_transaction_owner ON public.transaction
    USING (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    )
    WITH CHECK (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    );

-- ── split ────────────────────────────────────────────────────────────────────
ALTER TABLE public.split ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_split_owner ON public.split;
CREATE POLICY rls_split_owner ON public.split
    USING (
        account_id IN (
            SELECT a.id FROM public.account a
            JOIN public.ledger l ON l.id = a.ledger_id
             WHERE l.owner_id = public.mab_current_owner_id()
        )
    )
    WITH CHECK (
        account_id IN (
            SELECT a.id FROM public.account a
            JOIN public.ledger l ON l.id = a.ledger_id
             WHERE l.owner_id = public.mab_current_owner_id()
        )
    );

-- ── payee ────────────────────────────────────────────────────────────────────
ALTER TABLE public.payee ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payee FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_payee_owner ON public.payee;
CREATE POLICY rls_payee_owner ON public.payee
    USING (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    )
    WITH CHECK (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    );

-- ── scheduled_transaction ────────────────────────────────────────────────────
ALTER TABLE public.scheduled_transaction ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_transaction FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_scheduled_transaction_owner ON public.scheduled_transaction;
CREATE POLICY rls_scheduled_transaction_owner ON public.scheduled_transaction
    USING (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    )
    WITH CHECK (
        ledger_id IN (
            SELECT id FROM public.ledger
             WHERE owner_id = public.mab_current_owner_id()
        )
    );

-- NOTE: ledger_owner, commodity, account_type, coa_template, coa_template_node,
--       enum_label, price are NOT tenant-scoped (shared reference data or
--       owner-keyed directly). Apply RLS selectively if needed.


-- =============================================================================
-- P4-B · audit_log table
--         Immutable append-only trail for all INSERT/UPDATE/DELETE on
--         core financial tables. Populated via trigger function below.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at   timestamp with time zone DEFAULT now() NOT NULL,
    table_name    text    NOT NULL,
    operation     text    NOT NULL,   -- INSERT | UPDATE | DELETE
    row_id        uuid,               -- id of the affected row (if applicable)
    owner_id      uuid,               -- resolved at trigger time from session var
    old_data      jsonb,              -- previous state (UPDATE/DELETE)
    new_data      jsonb,              -- new state (INSERT/UPDATE)
    app_user      text DEFAULT current_user NOT NULL,
    CONSTRAINT chk_audit_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- audit_log is append-only: deny UPDATE and DELETE to the app role
-- (Run as superuser / migration role outside this transaction if needed)
-- REVOKE UPDATE, DELETE ON public.audit_log FROM mab_app;

-- Indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_audit_log_table_row
    ON public.audit_log(table_name, row_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_owner
    ON public.audit_log(owner_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_occurred_at
    ON public.audit_log(occurred_at DESC);

COMMENT ON TABLE public.audit_log IS
    'Append-only compliance audit trail. Populated by mab_audit_trigger(). '
    'Never DELETE or UPDATE rows in this table.';

-- Trigger function (shared across all audited tables)
CREATE OR REPLACE FUNCTION public.mab_audit_trigger()
RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    v_owner_id uuid;
    v_row_id   uuid;
BEGIN
    -- Resolve owner from session variable (best-effort; NULL if not set)
    v_owner_id := NULLIF(current_setting('app.current_owner_id', TRUE), '')::uuid;

    -- Extract row id (assumes all audited tables have uuid 'id' column)
    IF TG_OP = 'DELETE' THEN
        v_row_id := OLD.id;
    ELSE
        v_row_id := NEW.id;
    END IF;

    INSERT INTO public.audit_log(table_name, operation, row_id, owner_id, old_data, new_data)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        v_row_id,
        v_owner_id,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
    );

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

-- Attach audit trigger to core financial tables
DO $$
DECLARE
    tbl text;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'transaction', 'split', 'ledger', 'account',
        'payee', 'scheduled_transaction', 'scheduled_split'
    ] LOOP
        -- Drop existing trigger if present (idempotent)
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit ON public.%I', tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_audit
             AFTER INSERT OR UPDATE OR DELETE ON public.%I
             FOR EACH ROW EXECUTE FUNCTION public.mab_audit_trigger()',
            tbl
        );
    END LOOP;
END;
$$;


-- =============================================================================
-- P4-C · Updated stored functions to use new columns
-- =============================================================================

-- ── mab_void_transaction: now sets voided_at ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.mab_void_transaction(
    p_tx_id  uuid,
    p_reason text DEFAULT NULL::text
) RETURNS void
    LANGUAGE plpgsql
AS $$
DECLARE
    v_ledger_id uuid;
BEGIN
    PERFORM mab__assert(p_tx_id IS NOT NULL, 'tx_id is required');

    SELECT ledger_id INTO v_ledger_id
      FROM public.transaction
     WHERE id = p_tx_id;

    PERFORM mab__assert(v_ledger_id IS NOT NULL, 'Transaction not found');

    PERFORM pg_advisory_xact_lock(hashtext(v_ledger_id::text));

    UPDATE public.transaction
       SET is_voided   = true,
           voided_at   = now(),                                          -- ← P3-D
           memo        = COALESCE(memo, '') ||
                             CASE WHEN p_reason IS NULL THEN ''
                                  ELSE ' [VOID: ' || p_reason || ']'
                             END,
           updated_at  = now(),
           revision    = revision + 1
     WHERE id          = p_tx_id
       AND is_voided   = false;

    PERFORM mab__assert(FOUND, 'Transaction is already voided (or not found)');
END;
$$;


-- ── mab_reverse_transaction: now sets reversed_by_tx_id on source ────────────
CREATE OR REPLACE FUNCTION public.mab_reverse_transaction(
    p_tx_id      uuid,
    p_post_date  timestamp with time zone DEFAULT now(),
    p_enter_date timestamp with time zone DEFAULT now(),
    p_memo       text DEFAULT NULL::text
) RETURNS uuid
    LANGUAGE plpgsql
AS $$
DECLARE
    v_src        public.transaction%ROWTYPE;
    v_new_tx_id  uuid;
BEGIN
    PERFORM mab__assert(p_tx_id IS NOT NULL, 'tx_id is required');

    SELECT * INTO v_src FROM public.transaction WHERE id = p_tx_id;

    PERFORM mab__assert(v_src.id IS NOT NULL,       'Transaction not found');
    PERFORM mab__assert(v_src.deleted_at IS NULL,   'Cannot reverse a deleted transaction');
    PERFORM mab__assert(v_src.is_voided = false,    'Cannot reverse a voided transaction');
    PERFORM mab__assert(
        v_src.reversed_by_tx_id IS NULL,
        'Transaction has already been reversed (reversed_by_tx_id is set)'  -- ← P3-C guard
    );

    PERFORM pg_advisory_xact_lock(hashtext(v_src.ledger_id::text));

    -- Create reversal transaction
    INSERT INTO public.transaction(
        ledger_id, enter_date, post_date, memo, num,
        status, currency_commodity_id, payee_id
    )
    VALUES (
        v_src.ledger_id,
        COALESCE(p_enter_date, now()),
        COALESCE(p_post_date,  now()),
        COALESCE(p_memo, 'Reversal of ' || v_src.id::text),
        v_src.num,
        v_src.status,
        v_src.currency_commodity_id,
        v_src.payee_id
    )
    RETURNING id INTO v_new_tx_id;

    -- Insert reversed splits (flip side)
    INSERT INTO public.split(
        account_id, transaction_id, side,
        value_num, value_denom,
        quantity_num, quantity_denom,
        memo, action
    )
    SELECT
        s.account_id,
        v_new_tx_id,
        CASE WHEN s.side = 0 THEN 1 ELSE 0 END,   -- flip DEBIT ↔ CREDIT
        s.value_num,   s.value_denom,
        s.quantity_num, s.quantity_denom,
        COALESCE(s.memo, '') || ' (reversal)',
        s.action
    FROM public.split s
    WHERE s.transaction_id = v_src.id
      AND s.deleted_at IS NULL;

    -- Mark source transaction as reversed                                ← P3-C
    UPDATE public.transaction
       SET reversed_by_tx_id = v_new_tx_id,
           updated_at        = now(),
           revision          = revision + 1
     WHERE id = p_tx_id;

    RETURN v_new_tx_id;
END;
$$;


-- =============================================================================
-- FINALIZE
-- =============================================================================

COMMIT;


-- =============================================================================
-- Post-migration verification queries (run manually)
-- =============================================================================
--
-- P3-A: Column renamed
--   SELECT column_name FROM information_schema.columns
--    WHERE table_name='ledger' AND column_name IN ('precision','decimal_places');
--
-- P3-B: Old constraint gone
--   SELECT conname FROM pg_constraint WHERE conrelid='public.ledger'::regclass;
--
-- P3-C: reversed_by_tx_id present
--   SELECT column_name FROM information_schema.columns
--    WHERE table_name='transaction' AND column_name='reversed_by_tx_id';
--
-- P3-D: voided_at present + consistency check active
--   SELECT column_name FROM information_schema.columns
--    WHERE table_name='transaction' AND column_name='voided_at';
--
-- P4-A: RLS enabled on core tables
--   SELECT relname, relrowsecurity, relforcerowsecurity
--     FROM pg_class
--    WHERE relname IN ('ledger','account','transaction','split','payee','scheduled_transaction')
--      AND relnamespace = 'public'::regnamespace;
--
-- P4-A: Test RLS (should return 0 rows when owner not set)
--   SET LOCAL app.current_owner_id = '';
--   SELECT COUNT(*) FROM public.ledger;   -- expect 0
--
-- P4-A: Test RLS (should return rows for a known owner)
--   SET LOCAL app.current_owner_id = '<a-real-owner-uuid>';
--   SELECT COUNT(*) FROM public.ledger;   -- expect > 0
--
-- P4-B: audit_log table and trigger
--   SELECT * FROM public.audit_log ORDER BY occurred_at DESC LIMIT 10;
--
-- P4-C: Void a test transaction and verify voided_at is set
--   SELECT id, is_voided, voided_at FROM public.transaction
--    WHERE is_voided = true LIMIT 5;
--
-- P4-C: Reverse a test transaction and verify reversed_by_tx_id is set
--   SELECT id, reversed_by_tx_id FROM public.transaction
--    WHERE reversed_by_tx_id IS NOT NULL LIMIT 5;
