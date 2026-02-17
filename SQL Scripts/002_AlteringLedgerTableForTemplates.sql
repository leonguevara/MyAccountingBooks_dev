ALTER TABLE ledger
  ADD COLUMN coa_template_id uuid NULL REFERENCES coa_template(id) ON DELETE SET NULL;
