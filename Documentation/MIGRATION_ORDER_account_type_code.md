# Migration order: adding account_type_code to coa_template_node (safe for existing data)

## Goal
Make COA templates deterministic by storing `coa_template_node.account_type_code` (FK to `account_type.code`)
so that instantiation can always populate `account.account_type_id`.

## Step 0 — Prereqs (already true in your project)
- `account_type` is the authoritative catalog and has stable `code` values.
- Existing templates currently store a `Type` value that matches `account_type.code` (e.g., OTHER_ASSET, MEM_DEBIT, ...).

## Step 1 — Deploy schema change (no data changes yet)
Run:
- `014_alter_coa_template_node_add_account_type_code.sql`

This will:
- add nullable column `account_type_code`
- add FK + CHECK as NOT VALID (does not block existing rows)
- add helpful index

## Step 2 — Backfill existing templates (online-safe)
Backfill using your current node metadata.
Example (if your existing node column is named `type` or similar, adapt accordingly):

- If you have a legacy column that already holds the same value:
  UPDATE coa_template_node SET account_type_code = legacy_type_column
  WHERE NOT is_placeholder;

If you **do not** have the value in the table (only in Excel/JSON), re-import templates (Step 3).

## Step 3 — Re-import or update templates (recommended)
Regenerate your template import artifacts with `account_type_code` included:
- Personales_2026_normalized_for_import_with_account_type_code.json
- SAT_2025_normalized_for_import_with_account_type_code.json
(and optionally update your template Excel files too)

Then update templates in DB:
- either by an UPDATE script that sets account_type_code per node.code
- or by re-running your template import pipeline

## Step 4 — Validate constraints (make it enforceable)
After you confirm every non-placeholder node has a valid `account_type_code`, run:

ALTER TABLE public.coa_template_node
  VALIDATE CONSTRAINT coa_template_node_account_type_code_fkey;

ALTER TABLE public.coa_template_node
  VALIDATE CONSTRAINT chk_coa_node_account_type_code_required;

## Step 5 — Deploy instantiation v2
Replace old instantiation with:
- `040_instantiate_template_to_ledger_v2.sql`

From now on, `account.account_type_id` will be populated for every non-placeholder account.
