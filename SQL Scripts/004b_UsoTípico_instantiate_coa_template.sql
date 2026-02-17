-- Example:
-- 1) Create a ledger first (with owner_id etc.)
-- 2) Instantiate a template into it.

SELECT instantiate_coa_template(
  'PUT_LEDGER_UUID_HERE'::uuid,
  'PUT_TEMPLATE_UUID_HERE'::uuid
);
