ALTER TABLE coa_template_node
ADD COLUMN account_type_code text;

ALTER TABLE coa_template_node
ADD CONSTRAINT chk_template_node_account_type_required
CHECK (
  is_placeholder = true
  OR account_type_code IS NOT NULL
);

ALTER TABLE coa_template_node
ADD CONSTRAINT fk_template_node_account_type_code
FOREIGN KEY (account_type_code)
REFERENCES account_type(code)
ON UPDATE CASCADE
ON DELETE RESTRICT;
