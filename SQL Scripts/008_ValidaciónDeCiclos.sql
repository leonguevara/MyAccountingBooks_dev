-- Detects cycles by attempting to walk parent links; any node that reaches itself indicates a cycle.
WITH RECURSIVE walk AS (
  SELECT
    template_id,
    code,
    parent_code,
    code AS start_code,
    ARRAY[code] AS path
  FROM coa_template_node

  UNION ALL

  SELECT
    w.template_id,
    n.code,
    n.parent_code,
    w.start_code,
    w.path || n.code
  FROM walk w
  JOIN coa_template_node n
    ON n.template_id = w.template_id
   AND n.code = w.parent_code
  WHERE w.parent_code IS NOT NULL
)
SELECT template_id, start_code, path
FROM walk
WHERE parent_code IS NOT NULL
  AND parent_code = start_code;
