-- Run once
CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_ux
ON commodity(namespace, mnemonic)
WHERE deleted_at IS NULL;
