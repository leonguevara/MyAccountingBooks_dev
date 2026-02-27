-- ============================================================
-- cleanup_e2e.sql
-- Cleans up E2E seed data for CoA templates + dev ledger.
--
-- What it removes (by default):
--  - Accounts created under the dev ledger
--  - Dev ledger (by name)
--  - CoA template + nodes (by code+version)
--  - Dev owner (by email) ONLY if they have no remaining ledgers
--
-- What it does NOT remove (by default):
--  - Tables, indexes, schema objects
--  - Triggers and functions (optional section provided)
--
-- IMPORTANT:
--  Edit the constants below to match your E2E config if you changed them.
-- ============================================================

BEGIN;

-- ---------------------------
-- Configuration (edit if needed)
-- ---------------------------
-- Must match what you used in the E2E scripts:
-- Template identity
DO $$
DECLARE
  v_template_code    text := 'MX_SAT_STD';
  v_template_version text := '2026.01';

  -- Dev objects
  v_dev_owner_email  text := 'dev@example.com';
  v_dev_ledger_name  text := 'Dev Ledger (E2E)';

  v_template_id uuid;
  v_ledger_ids uuid[];
  v_owner_id uuid;
BEGIN
  -- ---------------------------
  -- Locate template
  -- ---------------------------
  SELECT id INTO v_template_id
  FROM coa_template
  WHERE code = v_template_code
    AND version = v_template_version;

  -- ---------------------------
  -- Locate dev owner (if exists)
  -- ---------------------------
  SELECT id INTO v_owner_id
  FROM ledger_owner
  WHERE email = v_dev_owner_email;

  -- ---------------------------
  -- Locate dev ledgers (could be multiple if you ran E2E multiple times)
  -- ---------------------------
  SELECT COALESCE(array_agg(id), ARRAY[]::uuid[])
  INTO v_ledger_ids
  FROM ledger
  WHERE name = v_ledger_name
     OR (v_owner_id IS NOT NULL AND owner_id = v_owner_id AND coa_template_id = v_template_id);

  -- ---------------------------
  -- 1) Delete accounts for those ledgers (if any)
  --    Use CASCADE behavior from your schema (splits/transactions/etc.) if present,
  --    but we delete accounts explicitly first to avoid FK surprises.
  -- ---------------------------
  IF array_length(v_ledger_ids, 1) IS NOT NULL THEN
    DELETE FROM account
    WHERE ledger_id = ANY (v_ledger_ids);
  END IF;

  -- ---------------------------
  -- 2) Delete the dev ledgers
  --    If your schema cascades from ledger to transactions/payees/accounts, this is safe;
  --    we already removed accounts explicitly above.
  -- ---------------------------
  IF array_length(v_ledger_ids, 1) IS NOT NULL THEN
    DELETE FROM ledger
    WHERE id = ANY (v_ledger_ids);
  END IF;

  -- ---------------------------
  -- 3) Delete template nodes + template
  -- ---------------------------
  IF v_template_id IS NOT NULL THEN
    -- Nodes will be removed automatically via ON DELETE CASCADE,
    -- but we delete explicitly for clarity.
    DELETE FROM coa_template_node
    WHERE template_id = v_template_id;

    DELETE FROM coa_template
    WHERE id = v_template_id;
  END IF;

  -- ---------------------------
  -- 4) Delete dev owner only if they have no remaining ledgers
  -- ---------------------------
  IF v_owner_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM ledger WHERE owner_id = v_owner_id) THEN
      DELETE FROM ledger_owner WHERE id = v_owner_id;
    END IF;
  END IF;

END $$;

COMMIT;

-- How to use it with CLI:
-- /Library/PostgreSQL/18/bin/psql -U myaccounting_user -d myaccounting_dev -f cleanup_e2e.sql


-- ============================================================
-- Optional: remove helper function and triggers created by E2E
-- Uncomment if you want to remove these schema objects.
-- ============================================================

-- DROP FUNCTION IF EXISTS instantiate_coa_template(uuid, uuid);

-- DROP TRIGGER IF EXISTS coa_node_parent_exists_insupd ON coa_template_node;
-- DROP FUNCTION IF EXISTS trg_coa_node_parent_exists();

-- DROP TRIGGER IF EXISTS coa_node_level_consistency_insupd ON coa_template_node;
-- DROP FUNCTION IF EXISTS trg_coa_node_level_consistency();

-- ============================================================
-- Optional: sanity output (run manually)
-- ============================================================
-- SELECT * FROM coa_template WHERE code='MX_SAT_STD' AND version='2026.01';
-- SELECT * FROM ledger WHERE name='Dev Ledger (E2E)';
-- SELECT * FROM ledger_owner WHERE email='dev@example.com';
