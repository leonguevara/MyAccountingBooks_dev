-- 007b_posting_usage_examples.sql
-- Usage examples for the Posting Engine
\set ON_ERROR_STOP on

-- 1) Pick a ledger to post into
--    (Replace with your actual ledger id)
-- \set LEDGER_ID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

-- 2) Pick two real accounts from that ledger
--    Example query:
--      SELECT id, code, name FROM account WHERE ledger_id = :'LEDGER_ID' AND is_placeholder=false AND deleted_at IS NULL ORDER BY code LIMIT 20;
-- \set ACC_DEBIT  '...'
-- \set ACC_CREDIT '...'

-- 3) Post a balanced transaction (value_num/value_denom canonical)
--    Here: 1,234.56 currency units if value_denom=100
SELECT mab_post_transaction(
  p_ledger_id := :'LEDGER_ID',
  p_splits := jsonb_build_array(
    jsonb_build_object('account_id', :'ACC_DEBIT',  'side', 0, 'value_num', 123456, 'value_denom', 100, 'memo', 'Example debit'),
    jsonb_build_object('account_id', :'ACC_CREDIT', 'side', 1, 'value_num', 123456, 'value_denom', 100, 'memo', 'Example credit')
  ),
  p_memo := 'Posting engine test',
  p_num := 'TEST-0001'
) AS new_tx_id;

-- 4) Reverse a transaction
-- \set TX_ID '...'
-- SELECT mab_reverse_transaction(:'TX_ID');

-- 5) Void a transaction
-- SELECT mab_void_transaction(:'TX_ID', 'User cancelled');
