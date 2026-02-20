-- 013_AccountEnumsAlterations.sql
-- Updates CHECK constraints to match AccountKind_v3 / AccountRole_v3.
--
-- Notes:
-- - We DROP + RECREATE constraints to avoid "already exists" errors.
-- - If you prefer allowing custom roles, remove chk_account_role entirely,
--   or relax it to a numeric range.

BEGIN;

-- Account.kind must be one of the known enum values.
ALTER TABLE account
  DROP CONSTRAINT IF EXISTS chk_account_kind;

ALTER TABLE account
  ADD CONSTRAINT chk_account_kind
  CHECK (kind IN (0,1,2,3,4,5,6,7,8));

-- Account.account_role must be one of the known roles.
ALTER TABLE account
  DROP CONSTRAINT IF EXISTS chk_account_role;

ALTER TABLE account
  ADD CONSTRAINT chk_account_role
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
  ));

COMMIT;
