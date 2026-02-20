-- ============================================================
-- 000_MyAccountingBooks_CreateFromScratch_NoAlters.sql
--
-- PostgreSQL schema for the MyAccountingBooks multiplatform app. It is
-- derived from an initial CoreData XML model.  However, it has some
-- modifications:
-- 1) AccountOwner -> LedgerOwner
-- 2) Multi-provider login via auth_identity (account linking)
-- 3) Sync metadata added to all syncable tables:
--    updated_at, revision, deleted_at (tombstones)
--
-- Important note:
--   A strict "no ALTER ever" script cannot create the circular FK:
--     ledger.root_account_id -> account.id
--   because ledger and account reference each other.
--   This script therefore leaves that FK as an OPTIONAL commented statement.
--
-- Notes:
-- - UUID PKs support offline-first clients.
-- - Some CoreData optional relationships are enforced server-side for integrity.
--
-- Run:
--   createdb myaccounting_dev
--   psql -h localhost -U postgres -d myaccounting_dev -f 000Y_MyAccountingBooks_CreateFromScratch_NoAlters.sql
-- ============================================================

-- Enable strict error handling: the script will stop on the first error.
\set ON_ERROR_STOP on

-- Use a transaction to ensure the entire script is applied atomically.
BEGIN;

-- Enable the pgcrypto extension for gen_random_uuid() function.  This will be
-- a no-op if the extension is already enabled, and it is required for UUID 
-- generation in the schema.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop for idempotency in dev/test
DROP TABLE IF EXISTS scheduled_split CASCADE;
DROP TABLE IF EXISTS recurrence CASCADE;
DROP TABLE IF EXISTS scheduled_transaction CASCADE;
DROP TABLE IF EXISTS scheduled_split CASCADE;
DROP TABLE IF EXISTS split CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS price CASCADE;
DROP TABLE IF EXISTS account CASCADE;
DROP TABLE IF EXISTS payee CASCADE;
DROP TABLE IF EXISTS ledger CASCADE;
DROP TABLE IF EXISTS coa_template_node CASCADE;
DROP TABLE IF EXISTS coa_template CASCADE;
DROP TABLE IF EXISTS commodity CASCADE;
DROP TABLE IF EXISTS account_type CASCADE;
DROP TABLE IF EXISTS auth_identity CASCADE;
DROP TABLE IF EXISTS ledger_owner CASCADE;
DROP TABLE IF EXISTS enum_label CASCADE;

-- Commit the drops before starting to create tables, to avoid locking issues 
-- in case of FK dependencies.
COMMIT;

-- Start a new transaction for creating tables.
BEGIN;

-- =========================
-- enum_label
-- This table stores localized labels and descriptions for enum values used
-- in the application.
-- =========================
CREATE TABLE IF NOT EXISTS enum_label (
  enum_name text NOT NULL,   -- 'AccountKind' or 'AccountRole'
  enum_value int NOT NULL,   -- numeric value
  locale text NOT NULL,      -- 'es-MX', 'en-US'
  label text NOT NULL,
  description text NULL,
  PRIMARY KEY (enum_name, enum_value, locale)
);

-- =========================
-- Core tables
-- =========================

-- =========================
-- ledger_owner
-- This table represents the owner of a ledger, which can be an individual 
-- or an organization.
-- =========================
CREATE TABLE ledger_owner (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Primary account email (used for contact + optional local login)
  email          text NOT NULL UNIQUE,
  email_verified boolean NOT NULL DEFAULT false,

  -- Local auth (nullable if the user relies only on external providers)
  password_hash  text NULL,

  -- Profile
  display_name   text NOT NULL DEFAULT 'No Name',
  is_active      boolean NOT NULL DEFAULT true,

  -- Audit
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  last_login_at  timestamptz NULL,

  -- Sync / lifecycle
  revision       bigint NOT NULL DEFAULT 0,
  deleted_at     timestamptz NULL
);

-- =========================
-- auth_identity
-- This table supports multiple authentication providers for a single ledger owner.
-- =========================
CREATE TABLE auth_identity (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_owner_id uuid NOT NULL REFERENCES ledger_owner(id) ON DELETE CASCADE,

  -- Provider identifiers
  provider        text NOT NULL,   -- 'local', 'google', 'apple', 'github', etc.
  provider_user_id text NOT NULL,  -- stable unique id from provider (sub)

  -- Optional provider metadata
  provider_email  text NULL,       -- may be a relay (e.g., Apple)
  email_verified  boolean NOT NULL DEFAULT false,

  -- Audit
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_login_at   timestamptz NULL,

  -- Sync / lifecycle
  revision        bigint NOT NULL DEFAULT 0,
  deleted_at      timestamptz NULL,

  UNIQUE (provider, provider_user_id)
);

-- =========================
-- account_type
-- This table defines the types of accounts that can be used in the chart 
-- of accounts. It serves as a catalog that can be referenced by coa_template_node 
-- and account.  It defines the operational semantics of accounts (e.g., normal 
-- balance, reporting role), and can be extended with additional metadata as needed.
-- =========================
CREATE TABLE account_type (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text NOT NULL DEFAULT 'No Code',
  name           text NOT NULL DEFAULT 'No Name',
  standard       text NULL DEFAULT 'SAT/NIIF',
  kind           smallint NOT NULL DEFAULT 1,
  normal_balance smallint NOT NULL DEFAULT 0,
  sort_order     smallint NOT NULL DEFAULT 0,
  is_active      boolean NOT NULL DEFAULT true,

  -- CoreData: createdAt
  created_at     timestamptz NOT NULL DEFAULT now(),

  -- Sync metadata
  updated_at     timestamptz NOT NULL DEFAULT now(),
  revision       bigint NOT NULL DEFAULT 0,
  deleted_at     timestamptz NULL,
  CONSTRAINT account_type_code_uq UNIQUE (code)
);

-- =========================
-- commodity
-- This table defines the commodities (currencies, securities) that can be used 
-- in accounts and transactions.
-- =========================
CREATE TABLE commodity (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mnemonic    text NOT NULL DEFAULT 'MXN',
  namespace   text NOT NULL DEFAULT 'CURRENCY',
  full_name   text NULL DEFAULT 'No Name',
  fraction bigint NOT NULL DEFAULT 100,
  is_active   boolean NOT NULL DEFAULT true,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  revision    bigint NOT NULL DEFAULT 0,
  deleted_at  timestamptz NULL
);

-- =========================
-- COA Templates (final shape)
-- =========================

-- =========================
-- coa_template
-- This table defines chart of accounts templates, which can be used to 
-- instantiate a ledger's chart of accounts.  It allows for versioning and 
-- metadata to support different standards.
-- =========================
CREATE TABLE coa_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL,                 -- e.g., 'MX_SAT_STD'
  name        text NOT NULL,                 -- human-friendly template name
  description text NULL,
  country     text NULL,                     -- e.g., 'MX'
  locale      text NULL,                     -- e.g., 'es-MX'
  industry    text NULL,                     -- e.g., 'general', 'retail'
  version     text NOT NULL,                 -- e.g., '2026.01'
  is_active   boolean NOT NULL DEFAULT true,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (code, version)
);

-- =========================
-- coa_template_node
-- This table defines the nodes of a chart of accounts template. Each node 
-- represents an account or a placeholder within the template.
-- =========================
CREATE TABLE coa_template_node (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id    uuid NOT NULL REFERENCES coa_template(id) ON DELETE CASCADE,

  code           text NOT NULL,              -- node code, unique within a template
  parent_code    text NULL,                  -- parent code (string reference within same template)
  name           text NOT NULL,
  level          integer NOT NULL,
  kind           smallint NOT NULL,
  role           smallint NOT NULL,
  is_placeholder boolean NOT NULL DEFAULT false,

  -- Option 2: stable reference to account_type catalog
  account_type_code text NULL REFERENCES account_type(code) ON DELETE RESTRICT,

  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),

  UNIQUE (template_id, code),
  CHECK (level >= 0),

  CHECK (is_placeholder OR account_type_code IS NOT NULL)
);

-- Index to optimize lookups by template_id and account_type_code, 
-- which are common in account instantiation.
CREATE INDEX IF NOT EXISTS idx_coa_node_template_typecode
  ON coa_template_node(template_id, account_type_code);

-- =========================
-- Ledger and operational tables
-- =========================

-- =========================
-- ledger
-- This table represents a ledger, which is the core entity that ties together 
-- accounts, transactions, and other financial data. Each ledger belongs to a 
-- ledger owner and can have its own chart of accounts (optionally instantiated 
-- from a coa_template).
-- =========================
CREATE TABLE ledger (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- CoreData relationship: Ledger.owner (AccountOwner) -> LedgerOwner
  owner_id              uuid NOT NULL REFERENCES ledger_owner(id) ON DELETE RESTRICT,

  name                  text NOT NULL DEFAULT 'No Name',
  currency_code         text NOT NULL DEFAULT 'MXN',
  precision             smallint NOT NULL DEFAULT 2,
  template              text NOT NULL DEFAULT 'SAT',
  is_active             boolean NOT NULL DEFAULT true,

  closed_at             timestamptz NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),

  -- CoreData relationship: currencyCommodity
  currency_commodity_id uuid NULL REFERENCES commodity(id) ON DELETE SET NULL,

  -- CoreData relationship: rootAccount (added FK after account exists)
  root_account_id       uuid NULL,

  -- COA template used to instantiate this ledger
  coa_template_id       uuid NULL REFERENCES coa_template(id) ON DELETE SET NULL,

  updated_at            timestamptz NOT NULL DEFAULT now(),
  revision              bigint NOT NULL DEFAULT 0,
  deleted_at            timestamptz NULL
);

-- =========================
-- payee
-- This table represents payees, which can be associated with transactions.
-- =========================
CREATE TABLE payee (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id   uuid NOT NULL REFERENCES ledger(id) ON DELETE CASCADE,

  name        text NOT NULL DEFAULT 'No Name',
  is_active   boolean NOT NULL DEFAULT true,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  revision    bigint NOT NULL DEFAULT 0,
  deleted_at  timestamptz NULL,

  UNIQUE (ledger_id, name)
);

-- =========================
-- account
-- This table represents accounts in the ledger. Accounts can be organized
-- hierarchically (parent-child) and can reference an account type and a commodity.
-- =========================
CREATE TABLE account (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id       uuid NOT NULL REFERENCES ledger(id) ON DELETE CASCADE,

  account_role    smallint NOT NULL DEFAULT 0,
  code            text NULL,
  commodity_scu   integer NOT NULL DEFAULT 100,
  created_at      timestamptz NOT NULL DEFAULT now(),
  is_active       boolean NOT NULL DEFAULT true,
  is_hidden       boolean NOT NULL DEFAULT false,
  is_placeholder  boolean NOT NULL DEFAULT false,
  kind            smallint NOT NULL DEFAULT 1,
  name            text NOT NULL DEFAULT 'No Name',
  non_std_scu     integer NOT NULL DEFAULT 0,
  notes           text NULL,

  -- Relationships
  account_type_id uuid NULL REFERENCES account_type(id) ON DELETE SET NULL,
  commodity_id    uuid NULL REFERENCES commodity(id) ON DELETE SET NULL,
  parent_id       uuid NULL REFERENCES account(id) ON DELETE SET NULL,

  updated_at      timestamptz NOT NULL DEFAULT now(),
  revision        bigint NOT NULL DEFAULT 0,
  deleted_at      timestamptz NULL,

  CONSTRAINT chk_account_kind
  CHECK (kind IN (0,1,2,3,4,5,6,7,8)),

  CONSTRAINT chk_account_role
  CHECK (account_role IN (
    -- Generic
    0,

    -- Assets
    100,101,110,120,130,131,199,

    -- Liabilities
    200,210,220,299,

    -- Equity
    300,310,320,

    -- Income
    400,410,420,430,499,

    -- Cost of Sales
    500,510,

    -- Expenses
    600,610,620,699,

    -- Memorandum (classic)
    700,800,

    -- Financial result roles (RIF / SAT 700s)
    4300,4301,
    4310,4311,
    4320,4321,
    4330,4331,
    4340,4341,
    4390,4391,

    -- Statistical
    900
  ))
);

-- =========================
-- price
-- This table represents prices of commodities in different currencies.
-- =========================
CREATE TABLE price (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- CoreData relationships are optional, but the server should enforce integrity.
  commodity_id uuid NOT NULL REFERENCES commodity(id) ON DELETE CASCADE,
  currency_id  uuid NOT NULL REFERENCES commodity(id) ON DELETE RESTRICT,

  date        timestamptz NOT NULL DEFAULT now(),
  source      text NULL,
  type        text NULL,
  value_denom integer NOT NULL DEFAULT 100,
  value_num   bigint NOT NULL DEFAULT 0,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  revision    bigint NOT NULL DEFAULT 0,
  deleted_at  timestamptz NULL,

  UNIQUE (commodity_id, currency_id, date)
);

-- =========================
-- transaction
-- This table represents financial transactions, which consist of two or more splits.
-- =========================
CREATE TABLE transaction (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id              uuid NOT NULL REFERENCES ledger(id) ON DELETE CASCADE,

  created_at            timestamptz NOT NULL DEFAULT now(),
  enter_date            timestamptz NOT NULL DEFAULT now(),
  is_voided             boolean NOT NULL DEFAULT false,
  memo                  text NULL,
  num                   text NULL,
  post_date             timestamptz NOT NULL DEFAULT now(),
  status                smallint NOT NULL DEFAULT 0,

  -- Relationships
  currency_commodity_id uuid NULL REFERENCES commodity(id) ON DELETE SET NULL,
  payee_id              uuid NULL REFERENCES payee(id) ON DELETE SET NULL,

  updated_at            timestamptz NOT NULL DEFAULT now(),
  revision              bigint NOT NULL DEFAULT 0,
  deleted_at            timestamptz NULL
);

-- =========================
-- split
-- This table represents the splits that make up a transaction. Each split belongs
-- to one account and one transaction, and has an amount and quantity.
-- =========================
CREATE TABLE split (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  action         text NULL,
  amount         numeric(38,10) NOT NULL DEFAULT 0.0, -- CoreData Decimal
  created_at     timestamptz NOT NULL DEFAULT now(),
  memo           text NULL,
  quantity_denom integer NOT NULL DEFAULT 100,
  quantity_num   bigint NOT NULL DEFAULT 0,
  reconcile_date timestamptz NULL,
  reconcile_state boolean NOT NULL DEFAULT false,
  side           smallint NOT NULL DEFAULT 0,
  value_denom    integer NOT NULL DEFAULT 100,
  value_num      bigint NOT NULL DEFAULT 0,

  -- Server integrity: a split must always belong to an account and a transaction.
  -- CoreData marks these as optional, but enforcing NOT NULL prevents orphan rows.
  account_id     uuid NOT NULL REFERENCES account(id) ON DELETE RESTRICT,
  transaction_id uuid NOT NULL REFERENCES transaction(id) ON DELETE CASCADE,

  updated_at     timestamptz NOT NULL DEFAULT now(),
  revision       bigint NOT NULL DEFAULT 0,
  deleted_at     timestamptz NULL
);

-- =========================
-- scheduled_transaction
-- This table represents transactions that are scheduled to occur in the future,
-- potentially with a recurrence pattern. It allows for auto-creation and 
-- auto-notification.
-- =========================
CREATE TABLE scheduled_transaction (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id              uuid NOT NULL REFERENCES ledger(id) ON DELETE CASCADE,

  adv_creation           integer NOT NULL DEFAULT 0,
  adv_notify             integer NOT NULL DEFAULT 1,
  auto_create            boolean NOT NULL DEFAULT false,
  auto_notify            boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  enabled                boolean NOT NULL DEFAULT true,
  end_date               timestamptz NULL,
  instance_count         integer NOT NULL DEFAULT 0,
  is_active              boolean NOT NULL DEFAULT true,
  last_occur             timestamptz NULL,
  name                   text NULL,
  num_occur              integer NOT NULL DEFAULT 0,
  rem_occur              integer NOT NULL DEFAULT 0,
  start_date             timestamptz NULL,

  -- Relationships
  currency_commodity_id  uuid NULL REFERENCES commodity(id) ON DELETE SET NULL,
  payee_id               uuid NULL REFERENCES payee(id) ON DELETE SET NULL,
  template_root_account_id uuid NULL REFERENCES account(id) ON DELETE SET NULL,

  updated_at             timestamptz NOT NULL DEFAULT now(),
  revision               bigint NOT NULL DEFAULT 0,
  deleted_at             timestamptz NULL
);

-- =========================
-- recurrence
-- This table defines the recurrence patterns for scheduled transactions, such as 
-- daily, weekly, monthly, etc., along with any adjustments for weekends.
-- =========================
CREATE TABLE recurrence (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  created_at              timestamptz NOT NULL DEFAULT now(),
  mult                    integer NOT NULL DEFAULT 1,
  period_start            timestamptz NULL,
  period_type             text NULL,
  weekend_adjust          text NOT NULL DEFAULT 'none',

  scheduled_transaction_id uuid NOT NULL REFERENCES scheduled_transaction(id) ON DELETE CASCADE,

  updated_at              timestamptz NOT NULL DEFAULT now(),
  revision                bigint NOT NULL DEFAULT 0,
  deleted_at              timestamptz NULL
);

-- =========================
-- scheduled_split
-- This table represents the splits that are part of a scheduled transaction. It 
-- has a similar structure to the regular split table, but is associated with 
-- a scheduled_transaction.  When a scheduled transaction is instantiated, these 
-- splits can be copied to the regular split table with the appropriate 
--transaction_id.
-- =========================
CREATE TABLE scheduled_split (
id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  action                  text NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  memo                    text NULL,
  side                    smallint NOT NULL DEFAULT 0,
  value_denom             integer NOT NULL DEFAULT 0,
  value_num               bigint NOT NULL DEFAULT 0,

  scheduled_transaction_id uuid NOT NULL REFERENCES scheduled_transaction(id) ON DELETE CASCADE,
  account_id              uuid NOT NULL REFERENCES account(id) ON DELETE RESTRICT,

  updated_at              timestamptz NOT NULL DEFAULT now(),
  revision                bigint NOT NULL DEFAULT 0,
  deleted_at              timestamptz NULL
);

-- NOTE: root_account_id is intentionally left without an FK here to avoid a circular 
-- dependency at CREATE time.
-- After initial creation, we add it with:
ALTER TABLE ledger
  ADD CONSTRAINT fk_ledger_root_account
  FOREIGN KEY (root_account_id) REFERENCES account(id) ON DELETE SET NULL;


-- =========================
-- Indices
-- =========================

-- Run once
CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_ux
ON commodity(namespace, mnemonic)
WHERE deleted_at IS NULL;


COMMIT;
