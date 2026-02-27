
# Excel-Based Import Pipeline

## COA Template Import

Script:
import_coa_template_from_excel.py

Features:
- Flexible header detection
- Dynamic root detection (level = 0)
- Upsert semantics
- Hierarchy validation

## ISO 4217 Commodity Import

Script:
import_iso4217_to_commodity_from_excel.py

Features:
- Reads official SIX Excel file
- Computes fraction from minor_unit
- Upserts by (namespace, mnemonic)
- Optional deactivate missing
