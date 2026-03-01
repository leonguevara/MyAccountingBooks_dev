-- 003_seed_crypto_to_commodity.pgsql
-- Seed common crypto "commodities" into public.commodity.
--
-- Notes:
-- - namespace='CRYPTO' keeps crypto separate from fiat.
-- - fraction is the smallest unit scaling:
--     BTC: 100,000,000 satoshis per BTC
--     ETH: 1,000,000,000,000,000,000 wei per ETH
--
-- Run in psql / pgAdmin Query Tool / PSQL Tool.

BEGIN;

-- Ensure uniqueness index exists (optional but recommended):
CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_ux
ON commodity(namespace, mnemonic)
WHERE deleted_at IS NULL;

WITH seed(namespace, mnemonic, full_name, fraction) AS (
  VALUES
    ('CRYPTO','BTC','Bitcoin',100000000),
    ('CRYPTO','ETH','Ethereum',1000000000000000000),
    ('CRYPTO','USDT','Tether USDt',1000000),  -- many systems treat USDT as 6 decimals
    ('CRYPTO','USDC','USD Coin',1000000)      -- commonly 6 decimals
)
INSERT INTO commodity (mnemonic, namespace, full_name, fraction, is_active, created_at, updated_at, revision, deleted_at)
SELECT s.mnemonic, s.namespace, s.full_name, s.fraction, TRUE, now(), now(), 0, NULL
FROM seed s
ON CONFLICT (namespace, mnemonic) WHERE deleted_at IS NULL  -- only consider active records for conflict
DO UPDATE SET
  full_name  = EXCLUDED.full_name,
  fraction   = EXCLUDED.fraction,
  is_active  = TRUE,
  updated_at = now(),
  revision   = commodity.revision + 1,
  deleted_at = NULL;

COMMIT;

-- Quick check:
SELECT namespace, mnemonic, full_name, fraction
FROM commodity
WHERE namespace='CRYPTO' AND deleted_at IS NULL
ORDER BY mnemonic;
