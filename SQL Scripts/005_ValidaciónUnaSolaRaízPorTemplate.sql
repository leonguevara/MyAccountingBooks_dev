SELECT template_id, COUNT(*) AS root_count
FROM coa_template_node
WHERE parent_code IS NULL
GROUP BY template_id
HAVING COUNT(*) <> 1;
