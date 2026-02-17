-- 014_alter_coa_template_node_add_account_type_code.sql
-- Adds account_type_code to coa_template_node (Option 2).
-- Strategy:
--   1) Add column nullable (safe)
--   2) Add FK to account_type(code) as NOT VALID (allows backfill)
--   3) Add CHECK to require type for non-placeholder nodes as NOT VALID
--   4) Provide VALIDATE commands after backfill
--
-- Run:
--   psql -h localhost -U postgres -d myaccounting_dev -f 014_alter_coa_template_node_add_account_type_code.sql

BEGIN;

-- Ensure account_type.code is unique (required for FK target)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'account_type_code_uq'
  ) THEN
    ALTER TABLE public.account_type
      ADD CONSTRAINT account_type_code_uq UNIQUE (code);
  END IF;
END $$;

-- Add column (nullable first)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='coa_template_node'
      AND column_name='account_type_code'
  ) THEN
    ALTER TABLE public.coa_template_node
      ADD COLUMN account_type_code text;
  END IF;
END $$;

-- Helpful index for instantiation
CREATE INDEX IF NOT EXISTS idx_coa_template_node_template_typecode
  ON public.coa_template_node (template_id, account_type_code);

-- FK (NOT VALID for safe backfill)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'coa_template_node_account_type_code_fkey'
  ) THEN
    ALTER TABLE public.coa_template_node
      ADD CONSTRAINT coa_template_node_account_type_code_fkey
      FOREIGN KEY (account_type_code)
      REFERENCES public.account_type(code)
      ON UPDATE RESTRICT
      ON DELETE RESTRICT
      NOT VALID;
  END IF;
END $$;

-- Require account_type_code for non-placeholder nodes (NOT VALID for safe backfill)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_coa_node_account_type_code_required'
  ) THEN
    ALTER TABLE public.coa_template_node
      ADD CONSTRAINT chk_coa_node_account_type_code_required
      CHECK (is_placeholder OR account_type_code IS NOT NULL)
      NOT VALID;
  END IF;
END $$;

COMMIT;

-- After you backfill existing templates, validate:
--   ALTER TABLE public.coa_template_node VALIDATE CONSTRAINT coa_template_node_account_type_code_fkey;
--   ALTER TABLE public.coa_template_node VALIDATE CONSTRAINT chk_coa_node_account_type_code_required;
