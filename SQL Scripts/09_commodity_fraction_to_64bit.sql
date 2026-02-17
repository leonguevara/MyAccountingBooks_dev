BEGIN;

ALTER TABLE commodity
  ALTER COLUMN fraction TYPE bigint;

COMMIT;
