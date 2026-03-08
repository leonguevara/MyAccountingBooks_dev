-- ============================================================
-- PostgreSQL schema derived from the CoreData XML model.
-- Modifications:
-- 1) AccountOwner -> LedgerOwner
-- 2) Multi-provider login via auth_identity (account linking)
-- 3) Sync metadata added to all syncable tables:
--    updated_at, revision, deleted_at (tombstones)
-- Notes:
-- - UUID PKs support offline-first clients.
-- - Some CoreData optional relationships are enforced server-side for integrity.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================
-- LedgerOwner (renamed from AccountOwner)
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
-- Auth identities (multi-provider login / account linking)
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

  created_at      timestamptz NOT NULL DEFAULT now(),
  last_login_at   timestamptz NULL,

  revision        bigint NOT NULL DEFAULT 0,
  deleted_at      timestamptz NULL,

  UNIQUE (provider, provider_user_id)
);

CREATE INDEX idx_auth_identity_owner ON auth_identity(ledger_owner_id);


-- =========================
-- AccountType
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
  deleted_at     timestamptz NULL
);


-- =========================
-- Commodity
-- =========================
CREATE TABLE commodity (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mnemonic    text NOT NULL DEFAULT 'MXN',
  namespace   text NOT NULL DEFAULT 'CURRENCY',
  full_name   text NULL DEFAULT 'No Name',
  fraction    integer NOT NULL DEFAULT 100,
  is_active   boolean NOT NULL DEFAULT true,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  revision    bigint NOT NULL DEFAULT 0,
  deleted_at  timestamptz NULL
);


-- =========================
-- Ledger
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

  updated_at            timestamptz NOT NULL DEFAULT now(),
  revision              bigint NOT NULL DEFAULT 0,
  deleted_at            timestamptz NULL
);

CREATE INDEX idx_ledger_owner ON ledger(owner_id);


-- =========================
-- Payee
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

CREATE INDEX idx_payee_ledger ON payee(ledger_id);


-- =========================
-- Account
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
  deleted_at      timestamptz NULL
);

CREATE INDEX idx_account_ledger ON account(ledger_id);
CREATE INDEX idx_account_parent ON account(parent_id);
CREATE UNIQUE INDEX uq_account_ledger_code ON account(ledger_id, code) WHERE code IS NOT NULL;


-- Now that account exists, we can link Ledger.rootAccount
ALTER TABLE ledger
  ADD CONSTRAINT fk_ledger_root_account
  FOREIGN KEY (root_account_id) REFERENCES account(id) ON DELETE SET NULL;


-- =========================
-- Price
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

CREATE INDEX idx_price_date ON price(date);


-- =========================
-- Transaction
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

CREATE INDEX idx_tx_ledger_post_date ON transaction(ledger_id, post_date);


-- =========================
-- Split
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

CREATE INDEX idx_split_tx ON split(transaction_id);
CREATE INDEX idx_split_account ON split(account_id);


-- =========================
-- ScheduledTransaction
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

CREATE INDEX idx_schedtx_ledger ON scheduled_transaction(ledger_id);


-- =========================
-- Recurrence
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

CREATE INDEX idx_recur_schedtx ON recurrence(scheduled_transaction_id);


-- =========================
-- ScheduledSplit
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

CREATE INDEX idx_schedsplit_schedtx ON scheduled_split(scheduled_transaction_id);
CREATE INDEX idx_schedsplit_account ON scheduled_split(account_id);
