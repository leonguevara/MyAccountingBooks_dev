-- Migration: Scope `price` rows to a ledger for tenant isolation.
-- This change introduces `ledger_id`, enables RLS, and updates uniqueness
-- so prices are unique per ledger/commodity/currency/date.

-- 1) Add `ledger_id` with FK to `ledger`.
ALTER TABLE public.price
    ADD COLUMN ledger_id uuid
    REFERENCES public.ledger(id) ON DELETE CASCADE;

-- 2) Enforce NOT NULL after backfill if pre-existing rows exist.
-- In this environment, the table is expected to be empty.
ALTER TABLE public.price
    ALTER COLUMN ledger_id SET NOT NULL;

-- 3) Enable and force Row-Level Security (RLS).
ALTER TABLE public.price ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price FORCE ROW LEVEL SECURITY;

-- 4) Create tenant policy using current owner context.
-- Access is allowed only when `price.ledger_id` belongs to the active owner.
CREATE POLICY rls_price_owner ON public.price
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

-- 5) Grant runtime DML permissions to application role.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.price TO mab_app;

-- 6) Replace global uniqueness with ledger-scoped uniqueness.
ALTER TABLE public.price
    DROP CONSTRAINT IF EXISTS price_commodity_id_currency_id_date_key;

ALTER TABLE public.price
    ADD CONSTRAINT price_ledger_commodity_currency_date_key
    UNIQUE (ledger_id, commodity_id, currency_id, date);

-- 7) Optional: adjust view ownership if `v_price` exists.
-- ALTER VIEW public.v_price OWNER TO mab_app;