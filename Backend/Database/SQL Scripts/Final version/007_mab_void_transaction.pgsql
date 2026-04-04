-- Function: public.mab_void_transaction(uuid, text)
--
-- Purpose:
--   Mark a transaction as voided without deleting it, preserving an auditable
--   trail and optional operator reason.
--
-- Parameters:
--   p_tx_id   : UUID of the transaction to void.
--   p_reason  : Optional free-text reason appended to memo as "[VOID: ...]".
--
-- Returns:
--   void
--
-- Contract:
--   - p_tx_id must be non-null.
--   - The target transaction must exist.
--   - The target transaction must not already be voided.
--
-- Concurrency:
--   Uses a transaction-scoped advisory lock keyed by ledger_id to serialize
--   state changes for transactions belonging to the same ledger.
--
-- Side effects:
--   - Sets transaction.is_voided = true.
--   - Sets transaction.voided_at to current timestamp.
--   - Appends a standardized void marker to transaction.memo when p_reason is
--     provided.
--   - Updates transaction.updated_at and increments transaction.revision.
--
-- Failure model:
--   Raises exceptions on invalid input, missing transaction, or when the
--   transaction is already voided.
CREATE OR REPLACE FUNCTION public.mab_void_transaction(
    p_tx_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS void
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
    is_voided  = true,
    voided_at  = now(),
    memo       = COALESCE(memo, '') ||
                 CASE WHEN p_reason IS NULL
                      THEN ''
                      ELSE ' [VOID: ' || p_reason || ']'
                 END,
    updated_at = now(),
    revision   = revision + 1
  WHERE id         = p_tx_id
    AND is_voided  = false;

  PERFORM mab__assert(FOUND, 'Transaction is already voided (or not found)');
END;
$$;