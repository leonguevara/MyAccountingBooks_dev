-- Ensures level consistency: child.level must be parent.level + 1.
CREATE OR REPLACE FUNCTION trg_coa_node_level_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent_level int;
BEGIN
  IF NEW.parent_code IS NULL THEN
    -- Root should be level 0 (recommended).
    IF NEW.level <> 0 THEN
      RAISE EXCEPTION 'Root node % must have level 0 (got %)', NEW.code, NEW.level;
    END IF;
    RETURN NEW;
  END IF;

  SELECT level INTO v_parent_level
  FROM coa_template_node
  WHERE template_id = NEW.template_id
    AND code = NEW.parent_code;

  IF v_parent_level IS NULL THEN
    -- Parent existence is checked by the other trigger.
    RETURN NEW;
  END IF;

  IF NEW.level <> v_parent_level + 1 THEN
    RAISE EXCEPTION 'Level mismatch for node %: expected %, got %',
      NEW.code, v_parent_level + 1, NEW.level;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coa_node_level_consistency_insupd ON coa_template_node;
CREATE TRIGGER coa_node_level_consistency_insupd
BEFORE INSERT OR UPDATE OF parent_code, level, template_id
ON coa_template_node
FOR EACH ROW
EXECUTE FUNCTION trg_coa_node_level_consistency();
