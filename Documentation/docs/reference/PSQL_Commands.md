# PostgreSQL — Helpful Commands

## Connection

```bash
# Connect as postgres superuser
psql postgres

# Connect as project user
psql -U myaccounting_user myaccounting_dev

# Connect with explicit host and port
psql -h localhost -U postgres -d myaccounting_dev
```

---

## Schema Dump

```bash
# Schema only (for migration diffs and storage in version control)
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --schema-only --clean --if-exists --no-owner --no-privileges \
  -f /absolute/path/myaccounting_dev_schema_clean.sql

# Full dump — plain text
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --format=plain --no-owner --no-privileges \
  -f myaccounting_dev_full.sql

# Full dump — custom format (recommended for production backups)
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --format=custom --no-owner --no-privileges \
  -f myaccounting_dev.dump

# Restore from custom format
pg_restore -h localhost -U postgres -d myaccounting_dev_restored \
  --clean --if-exists \
  myaccounting_dev.dump
```

---

## Useful Inspection Queries

```sql
-- List all tables in public schema
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
 ORDER BY table_name;

-- Table row counts
SELECT relname AS table, n_live_tup AS rows
  FROM pg_stat_user_tables
 ORDER BY n_live_tup DESC;

-- List all indexes
SELECT indexname, tablename, indexdef
  FROM pg_indexes
 WHERE schemaname = 'public'
 ORDER BY tablename, indexname;

-- List all functions
SELECT proname, pg_get_function_arguments(oid) AS args
  FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
 ORDER BY proname;

-- List RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
  FROM pg_policies
 WHERE schemaname = 'public'
 ORDER BY tablename;

-- Check RLS status on tables
SELECT relname, relrowsecurity, relforcerowsecurity
  FROM pg_class
 WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
 ORDER BY relname;

-- Verify generated column on split
SELECT column_name, generation_expression
  FROM information_schema.columns
 WHERE table_name = 'split' AND column_name = 'amount';

-- Check constraint list for a table
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
  FROM pg_constraint
 WHERE conrelid = 'public.coa_template_node'::regclass
 ORDER BY contype, conname;

-- Role password age / expiry
SELECT * FROM public.v_role_password_age;

-- Check mab_* role attributes
SELECT rolname, rolcanlogin, rolsuper, rolbypassrls, rolvaliduntil
  FROM pg_roles
 WHERE rolname LIKE 'mab_%'
 ORDER BY rolname;
```

---

## RLS Testing

```sql
-- Test as mab_app with no owner set (expect 0 rows)
SET ROLE mab_app;
SET LOCAL app.current_owner_id = '';
SELECT COUNT(*) FROM public.ledger;
RESET ROLE;

-- Test as mab_app with owner set
SET ROLE mab_app;
SET LOCAL app.current_owner_id = '<owner-uuid>';
SELECT COUNT(*) FROM public.ledger;
RESET ROLE;

-- Test mab_readonly cannot see password_hash
SET ROLE mab_readonly;
SELECT * FROM public.ledger_owner LIMIT 1;       -- expect: permission denied
SELECT * FROM public.v_ledger_owner_redacted LIMIT 1;  -- expect: success, no hash column
RESET ROLE;
```

---

## Posting Engine — Quick Tests

```sql
-- Post a simple balanced transaction (replace UUIDs)
SELECT mab_post_transaction(
    p_ledger_id             => '<ledger-uuid>',
    p_splits                => '[
        {"account_id": "<debit-account-uuid>",  "side": 0, "value_num": 10000, "value_denom": 100},
        {"account_id": "<credit-account-uuid>", "side": 1, "value_num": 10000, "value_denom": 100}
    ]'::jsonb,
    p_currency_commodity_id => '<commodity-uuid>',
    p_memo                  => 'Test transaction'
);

-- Reverse a transaction
SELECT mab_reverse_transaction(
    p_tx_id  => '<tx-uuid>',
    p_memo   => 'Reversal test'
);

-- Void a transaction
SELECT mab_void_transaction(
    p_tx_id  => '<tx-uuid>',
    p_reason => 'Test void'
);
```

---

## PATH Setup (macOS — EDB installer)

If `psql` is not in your PATH after installing via EDB:

```bash
# Add to ~/.zshrc
export PATH="/Library/PostgreSQL/18/bin:$PATH"

# Reload
source ~/.zshrc
```

---

## Homebrew PostgreSQL

```bash
# Start / stop service
brew services start postgresql@18
brew services stop postgresql@18
brew services restart postgresql@18

# Config file location
brew --prefix postgresql@18
# Example: /opt/homebrew/etc/postgresql@18/postgresql.conf
```
