-- Ensures parent_code references an existing node code within the same template.
CREATE OR REPLACE FUNCTION trg_coa_node_parent_exists()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.parent_code IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM coa_template_node p
      WHERE p.template_id = NEW.template_id
        AND p.code = NEW.parent_code
    ) THEN
      RAISE EXCEPTION 'Invalid parent_code % for node % in template %',
        NEW.parent_code, NEW.code, NEW.template_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coa_node_parent_exists_insupd ON coa_template_node;
CREATE TRIGGER coa_node_parent_exists_insupd
BEFORE INSERT OR UPDATE OF parent_code, code, template_id
ON coa_template_node
FOR EACH ROW
EXECUTE FUNCTION trg_coa_node_parent_exists();
