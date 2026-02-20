-- 007_posting_engine.pgsql
-- MyAccountingBooks Posting Engine (v1)
-- Canonical monetary source of truth: split.value_num / split.value_denom
-- split.amount is treated as a presentation field (optional; can be derived at insert time).
--
-- Conventions:
--   split.side: 0 = DEBIT, 1 = CREDIT
--
-- Safety:
--   Uses a per-ledger transactional advisory lock to prevent concurrent postings from racing.

\set ON_ERROR_STOP on

BEGIN;

-- =========================
-- Helper: raise a clean exception
-- =========================
CREATE OR REPLACE FUNCTION mab__assert(p_ok boolean, p_message text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT p_ok THEN
    RAISE EXCEPTION USING MESSAGE = p_message, ERRCODE = 'P0001';
  END IF;
END;
$$;

-- =========================
-- Main: post a transaction (atomic)
-- =========================
CREATE OR REPLACE FUNCTION mab_post_transaction(
    p_ledger_id uuid,
    p_splits jsonb,

    -- Header fields (optional)
    p_post_date timestamptz DEFAULT now(),
    p_enter_date timestamptz DEFAULT now(),
    p_memo text DEFAULT NULL,
    p_num text DEFAULT NULL,
    p_status smallint DEFAULT 0,
    p_currency_commodity_id uuid DEFAULT NULL,
    p_payee_id uuid DEFAULT NULL
)
RETURNS uuid
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

-- =========================
-- Reverse a transaction (preferred over edits)
-- =========================
CREATE OR REPLACE FUNCTION mab_reverse_transaction(
    p_tx_id uuid,
    p_post_date timestamptz DEFAULT now(),
    p_enter_date timestamptz DEFAULT now(),
    p_memo text DEFAULT NULL
)
RETURNS uuid
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

-- =========================
-- Void a transaction (soft cancel)
-- =========================
CREATE OR REPLACE FUNCTION mab_void_transaction(
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
    is_voided = true,
    memo = COALESCE(memo, '') || CASE WHEN p_reason IS NULL THEN '' ELSE ' [VOID: ' || p_reason || ']' END,
    updated_at = now(),
    revision = revision + 1
  WHERE id = p_tx_id
    AND is_voided = false;

  PERFORM mab__assert(FOUND, 'Transaction is already voided (or not found)');
END;
$$;

COMMIT;
