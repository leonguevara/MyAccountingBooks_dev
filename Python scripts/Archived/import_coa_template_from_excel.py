#!/usr/bin/env python3
"""
import_coa_template_from_excel.py

Cross-platform importer for COA templates from an Excel file into PostgreSQL.

This replaces the JSON-based importer and reads node rows from Excel.
It mirrors the logic in your SQL pipelines:
- Upserts coa_template by (code, version)
- Upserts coa_template_node by (template_id, code)

Expected columns (case-insensitive; supports multiple header variants):
  - Code (or code)
  - Parent (or parent_code)
  - Level (or level)
  - Name (or name)
  - Kind (or kind)                -> integer code
  - Role (or role)                -> integer code
  - Placeholder (or is_placeholder)-> 0/1 or true/false
  - Account_Type / Type / account_type_code -> text (account_type_code)

IMPORTANT schema invariant:
  - Root nodes (level = 0) MUST have parent_code NULL.
  - If your Excel uses a sentinel parent like "000-00.000.00-000.000", this script normalizes it to NULL.

Example:
  python import_coa_template_from_excel.py \
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
    --template-code PERSONALES_2026 \
    --template-name "Personal Chart of Accounts 2026" \
    --template-description "Personal chart of accounts (Mexico-oriented) for 2026" \
    --template-country MX \
    --template-locale es-MX \
    --template-industry "" \
    --template-version 1 \
    --excel "/path/to/Personales_2026.xlsx" \
    --sheet "Cuentas"
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
import sys

import pandas as pd

try:
    import psycopg
except ImportError as e:
    raise SystemExit("Missing dependency: psycopg (v3). Install with: pip install psycopg[binary]") from e



def _connect(dsn: str):
    # autocommit False; we control transaction boundaries
    return psycopg.connect(dsn)


def _norm_header(h: Any) -> str:
    return str(h).strip().lower().replace(" ", "_").replace("-", "_")


def _pick_col(df: pd.DataFrame, *names: str) -> Optional[str]:
    """
    Find a column in df matching any of the given names, case-insensitive,
    allowing simple normalization (spaces/underscores).
    Returns the actual df column name if found.
    """
    if df.empty:
        return None
    norm_map = {_norm_header(c): c for c in df.columns}
    for n in names:
        key = _norm_header(n)
        if key in norm_map:
            return norm_map[key]
    return None


def _as_str(v: Any) -> Optional[str]:
    if v is None:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    s = str(v).strip()
    return s if s else None


def _as_int(v: Any, default: int = 0) -> int:
    if v is None:
        return default
    if isinstance(v, float) and pd.isna(v):
        return default
    try:
        return int(float(v))
    except Exception:
        s = str(v).strip()
        return int(s) if s.isdigit() else default


def _as_bool(v: Any) -> bool:
    if v is None:
        return False
    if isinstance(v, float) and pd.isna(v):
        return False
    if isinstance(v, bool):
        return v
    s = str(v).strip().lower()
    if s in ("1", "true", "t", "yes", "y"):
        return True
    if s in ("0", "false", "f", "no", "n", ""):
        return False
    # fallback: non-empty string truthy
    return True


def load_nodes_from_excel(excel_path: str, sheet: Optional[str]) -> List[Dict[str, Any]]:
    # Read as strings to preserve codes like "100-00.000.00-000.000"
    df = pd.read_excel(excel_path, sheet_name=sheet or 0, dtype=str)

    col_code = _pick_col(df, "code", "Code")
    if not col_code:
        raise ValueError("Excel is missing a 'Code' column.")

    col_parent = _pick_col(df, "parent_code", "Parent", "parent", "ParentCode")
    col_level = _pick_col(df, "level", "Level")
    col_name = _pick_col(df, "name", "Name")
    col_kind = _pick_col(df, "kind", "Kind")
    col_role = _pick_col(df, "role", "Role")
    col_placeholder = _pick_col(df, "is_placeholder", "Placeholder", "IsPlaceholder")
    col_type = _pick_col(df, "account_type_code", "Account_Type", "Type", "AccountTypeCode")

    nodes: List[Dict[str, Any]] = []

    # Determine root code(s) dynamically from the sheet.
    # In our templates, the root account is always the row(s) with Level == 0.
    # We will:
    #   - force parent_code NULL for level 0 rows (DB invariant)
    #   - optionally treat empty parent values as NULL
    root_codes = set()
    if col_level:
        for v_code, v_level in zip(df[col_code].tolist(), df[col_level].tolist()):
            try:
                lvl = int(float(v_level)) if v_level is not None and str(v_level).strip() != "" else 0
            except Exception:
                lvl = 0
            code0 = _as_str(v_code)
            if code0 and lvl == 0:
                root_codes.add(code0)

    if not root_codes:
        # If there is truly no level-0 row, we cannot infer the root sentinel safely.
        # Fail fast so the user fixes the file.
        raise ValueError("Could not infer root code: no rows found with Level == 0.")
    for _, row in df.iterrows():
        code = _as_str(row.get(col_code))
        if not code:
            continue

        parent_code = _as_str(row.get(col_parent)) if col_parent else None
        level = _as_int(row.get(col_level)) if col_level else 0
        if level == 0:
            parent_code = None  # enforce DB invariant

        name = _as_str(row.get(col_name)) if col_name else None
        if not name:
            name = "No Name"

        kind = _as_int(row.get(col_kind)) if col_kind else 0
        role = _as_int(row.get(col_role)) if col_role else 0
        is_placeholder = _as_bool(row.get(col_placeholder)) if col_placeholder else False
        account_type_code = _as_str(row.get(col_type)) if col_type else None

        nodes.append({
            "code": code,
            "parent_code": parent_code,
            "name": name,
            "level": level,
            "kind": kind,
            "role": role,
            "is_placeholder": is_placeholder,
            "account_type_code": account_type_code,
        })

    return nodes


def upsert_template(cur, args) -> str:
    cur.execute("""
        INSERT INTO public.coa_template
          (id, code, name, description, country, locale, industry, version, is_active, created_at, updated_at)
        VALUES
          (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, true, now(), now())
        ON CONFLICT (code, version)
        DO UPDATE SET
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          country = EXCLUDED.country,
          locale = EXCLUDED.locale,
          industry = EXCLUDED.industry,
          updated_at = now()
        RETURNING id
    """, (
        args.template_code,
        args.template_name,
        args.template_description,
        args.template_country,
        args.template_locale,
        None if (args.template_industry in (None, "", "NULL", "null")) else args.template_industry,
        args.template_version,
    ))
    template_id = cur.fetchone()[0]
    return str(template_id)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", required=True, help="psycopg DSN string")
    ap.add_argument("--template-code", required=True)
    ap.add_argument("--template-name", required=True)
    ap.add_argument("--template-description", default=None)
    ap.add_argument("--template-country", default=None)
    ap.add_argument("--template-locale", default=None)
    ap.add_argument("--template-industry", default=None)
    ap.add_argument("--template-version", type=int, required=True)
    ap.add_argument("--excel", required=True, help="Path to Excel file (.xlsx/.xls)")
    ap.add_argument("--sheet", default=None, help="Sheet name (optional). Defaults to first sheet.")

    args = ap.parse_args()

    nodes = load_nodes_from_excel(args.excel, args.sheet)
    if not nodes:
        print(f"WARNING: No nodes found in Excel: {args.excel}", file=sys.stderr)

    with _connect(args.dsn) as conn:
        with conn.cursor() as cur:
            # Ensure pgcrypto exists for gen_random_uuid()
            cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")

            template_id = upsert_template(cur, args)

            rows: List[Tuple[Any, ...]] = []
            for n in nodes:
                rows.append((
                    template_id,
                    n["code"],
                    n["parent_code"],
                    n["name"],
                    n["level"],
                    n["kind"],
                    n["role"],
                    n["is_placeholder"],
                    n["account_type_code"],
                ))

            if rows:
                cur.executemany("""
                    INSERT INTO public.coa_template_node
                      (id, template_id, code, parent_code, name, level, kind, role, is_placeholder, account_type_code, created_at, updated_at)
                    VALUES
                      (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), now())
                    ON CONFLICT (template_id, code)
                    DO UPDATE SET
                      parent_code = EXCLUDED.parent_code,
                      name = EXCLUDED.name,
                      level = EXCLUDED.level,
                      kind = EXCLUDED.kind,
                      role = EXCLUDED.role,
                      is_placeholder = EXCLUDED.is_placeholder,
                      account_type_code = EXCLUDED.account_type_code,
                      updated_at = now()
                """, rows)

        conn.commit()

    print(f"OK: Imported template {args.template_code} v{args.template_version} with {len(nodes)} nodes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
