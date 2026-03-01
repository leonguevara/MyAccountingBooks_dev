#!/usr/bin/env python3
"""
import_coa_template_from_excel.py  (v2)

Cross-platform importer for COA templates from an Excel file into PostgreSQL.

CHANGES FROM v1:
  - Template metadata (code, name, description, country, locale, industry,
    version) is now read from a dedicated "Meta" sheet inside the Excel file.
  - All --template-* CLI arguments are OPTIONAL overrides.  If an override is
    supplied it takes precedence over the value in the Meta sheet.
  - The --dsn argument is the only required parameter.
  - The importer validates that all required metadata fields are present before
    attempting any database operation.

─────────────────────────────────────────────────────────────────────────────
EXCEL FILE STRUCTURE
─────────────────────────────────────────────────────────────────────────────

Sheet 1 — "Meta"  (required)
  A two-column sheet with a Key column and a Value column.
  Supported keys (case-insensitive):

    Key                 Value example
    ─────────────────── ──────────────────────────────────────────────
    code                PERSONALES_2026
    name                Personal Chart of Accounts 2026
    description         Personal chart of accounts (Mexico) for 2026
    country             MX
    locale              es-MX
    industry            personal          ← leave blank for NULL
    version             1

  Any extra rows are silently ignored.

Sheet 2 — "Nodes" (or any other name; passed via --sheet)
  Same column layout as v1:
    Code, Parent, Level, Name, Kind, Role, Placeholder, Account_Type

─────────────────────────────────────────────────────────────────────────────
EXAMPLES
─────────────────────────────────────────────────────────────────────────────

  # All metadata from Excel:
  python import_coa_template_from_excel.py \\
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \\
    --excel "/path/to/Personales_2026.xlsx"

  # Override version from CLI:
  python import_coa_template_from_excel.py \\
    --dsn "..." \\
    --excel "/path/to/Personales_2026.xlsx" \\
    --template-version 2

  # Use a non-default Meta sheet name and a specific node sheet:
  python import_coa_template_from_excel.py \\
    --dsn "..." \\
    --excel "/path/to/Personales_2026.xlsx" \\
    --meta-sheet "Metadata" \\
    --sheet "Cuentas"
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field, fields
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd

try:
    import psycopg
except ImportError as e:
    raise SystemExit(
        "Missing dependency: psycopg (v3). Install with: pip install psycopg[binary]"
    ) from e


# ─────────────────────────────────────────────────────────────────────────────
# Data classes
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class TemplateMetadata:
    """Holds all header-level fields for a coa_template row."""
    code:        Optional[str] = None
    name:        Optional[str] = None
    description: Optional[str] = None
    country:     Optional[str] = None
    locale:      Optional[str] = None
    industry:    Optional[str] = None   # NULL-able
    version:     Optional[str] = None

    # Fields that must be non-empty before we touch the database
    REQUIRED: tuple = field(default=("code", "name", "version"), init=False, repr=False)

    def validate(self) -> None:
        missing = [f for f in self.REQUIRED if not getattr(self, f)]
        if missing:
            raise ValueError(
                f"Template metadata is missing required field(s): {', '.join(missing)}. "
                f"Add them to the Meta sheet or supply via --template-<field> CLI arguments."
            )

    def merge_cli(self, cli_args: argparse.Namespace) -> None:
        """
        CLI --template-* overrides take precedence over the Meta sheet.
        Only override when the CLI value is explicitly supplied (not None).
        """
        mapping = {
            "template_code":        "code",
            "template_name":        "name",
            "template_description": "description",
            "template_country":     "country",
            "template_locale":      "locale",
            "template_industry":    "industry",
            "template_version":     "version",
        }
        for cli_key, meta_attr in mapping.items():
            cli_val = getattr(cli_args, cli_key, None)
            if cli_val is not None:
                # Normalize version to str regardless of input type
                setattr(self, meta_attr, str(cli_val).strip() if cli_val != "" else None)


# ─────────────────────────────────────────────────────────────────────────────
# Utility helpers
# ─────────────────────────────────────────────────────────────────────────────

def _norm_header(h: Any) -> str:
    return str(h).strip().lower().replace(" ", "_").replace("-", "_")


def _pick_col(df: pd.DataFrame, *names: str) -> Optional[str]:
    """Return the first df column name matching any of *names (normalized)."""
    if df.empty:
        return None
    norm_map = {_norm_header(c): c for c in df.columns}
    for n in names:
        if _norm_header(n) in norm_map:
            return norm_map[_norm_header(n)]
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
    return s in ("1", "true", "t", "yes", "y")


def _null_industry(v: Optional[str]) -> Optional[str]:
    """Treat blank / 'null' strings as SQL NULL for the industry field."""
    if v is None:
        return None
    return None if v.lower() in ("", "null", "none", "-") else v


# ─────────────────────────────────────────────────────────────────────────────
# Excel readers
# ─────────────────────────────────────────────────────────────────────────────

# Meta sheet keys the importer recognises (normalised form → TemplateMetadata attr)
_META_KEY_MAP: Dict[str, str] = {
    "code":             "code",
    "template_code":    "code",
    "name":             "name",
    "template_name":    "name",
    "description":      "description",
    "desc":             "description",
    "country":          "country",
    "locale":           "locale",
    "industry":         "industry",
    "version":          "version",
}


def load_metadata_from_excel(excel_path: str, meta_sheet: str) -> TemplateMetadata:
    """
    Read the Meta sheet from the workbook.

    Expected layout — two columns (Key | Value), no mandatory header row.
    The importer tries both with and without a header row automatically.

    Returns a TemplateMetadata instance (fields may still be None if absent).
    """
    try:
        xl = pd.ExcelFile(excel_path)
    except Exception as e:
        raise ValueError(f"Cannot open Excel file '{excel_path}': {e}") from e

    if meta_sheet not in xl.sheet_names:
        raise ValueError(
            f"Meta sheet '{meta_sheet}' not found in '{excel_path}'. "
            f"Available sheets: {xl.sheet_names}. "
            f"Use --meta-sheet to specify a different name, or add the sheet."
        )

    # Read with header=None first, then detect whether row 0 is actually a header
    df = pd.read_excel(excel_path, sheet_name=meta_sheet, header=None, dtype=str)

    if df.empty:
        raise ValueError(f"Meta sheet '{meta_sheet}' is empty.")

    # If the first cell looks like a column header ("key", "field", etc.), skip it
    first_cell = _norm_header(df.iloc[0, 0]) if len(df.columns) >= 1 else ""
    if first_cell in ("key", "field", "property", "attribute", "parameter"):
        df = df.iloc[1:].reset_index(drop=True)

    meta = TemplateMetadata()

    for _, row in df.iterrows():
        if len(row) < 2:
            continue
        raw_key = _as_str(row.iloc[0])
        raw_val = _as_str(row.iloc[1])
        if not raw_key:
            continue
        norm_key = _norm_header(raw_key)
        attr = _META_KEY_MAP.get(norm_key)
        if attr and raw_val is not None:
            setattr(meta, attr, raw_val)

    return meta


def load_nodes_from_excel(
    excel_path: str, sheet: Optional[str]
) -> List[Dict[str, Any]]:
    """Read COA node rows from the specified (or first) sheet."""
    df = pd.read_excel(excel_path, sheet_name=sheet or 0, dtype=str)

    col_code = _pick_col(df, "code", "Code")
    if not col_code:
        raise ValueError("Node sheet is missing a 'Code' column.")

    col_parent      = _pick_col(df, "parent_code", "Parent", "parent", "ParentCode")
    col_level       = _pick_col(df, "level", "Level")
    col_name        = _pick_col(df, "name", "Name")
    col_kind        = _pick_col(df, "kind", "Kind")
    col_role        = _pick_col(df, "role", "Role")
    col_placeholder = _pick_col(df, "is_placeholder", "Placeholder", "IsPlaceholder")
    col_type        = _pick_col(df, "account_type_code", "Account_Type", "Type", "AccountTypeCode")

    # Determine root codes (Level == 0) to enforce parent_code = NULL
    root_codes: set[str] = set()
    if col_level:
        for v_code, v_level in zip(df[col_code].tolist(), df[col_level].tolist()):
            try:
                lvl = int(float(v_level)) if _as_str(v_level) else 0
            except Exception:
                lvl = 0
            code0 = _as_str(v_code)
            if code0 and lvl == 0:
                root_codes.add(code0)

    if not root_codes:
        raise ValueError(
            "Could not infer root node: no rows found with Level == 0. "
            "Check the 'Level' column in the node sheet."
        )

    nodes: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        code = _as_str(row.get(col_code))
        if not code:
            continue

        level       = _as_int(row.get(col_level)) if col_level else 0
        parent_code = _as_str(row.get(col_parent)) if col_parent else None
        if level == 0:
            parent_code = None  # enforce DB invariant: root has no parent

        name = (_as_str(row.get(col_name)) if col_name else None) or "No Name"

        nodes.append({
            "code":              code,
            "parent_code":       parent_code,
            "name":              name,
            "level":             level,
            "kind":              _as_int(row.get(col_kind))        if col_kind        else 0,
            "role":              _as_int(row.get(col_role))        if col_role        else 0,
            "is_placeholder":    _as_bool(row.get(col_placeholder)) if col_placeholder else False,
            "account_type_code": _as_str(row.get(col_type))       if col_type        else None,
        })

    return nodes


# ─────────────────────────────────────────────────────────────────────────────
# Database operations
# ─────────────────────────────────────────────────────────────────────────────

def upsert_template(cur, meta: TemplateMetadata) -> str:
    cur.execute(
        """
        INSERT INTO public.coa_template
          (id, code, name, description, country, locale, industry,
           version, is_active, created_at, updated_at)
        VALUES
          (gen_random_uuid(), %s, %s, %s, %s, %s, %s,
           %s, true, now(), now())
        ON CONFLICT (code, version) DO UPDATE SET
          name        = EXCLUDED.name,
          description = EXCLUDED.description,
          country     = EXCLUDED.country,
          locale      = EXCLUDED.locale,
          industry    = EXCLUDED.industry,
          updated_at  = now()
        RETURNING id
        """,
        (
            meta.code,
            meta.name,
            meta.description,
            meta.country,
            meta.locale,
            _null_industry(meta.industry),
            meta.version,
        ),
    )
    return str(cur.fetchone()[0])


def upsert_nodes(cur, template_id: str, nodes: List[Dict[str, Any]]) -> None:
    rows: List[Tuple[Any, ...]] = [
        (
            template_id,
            n["code"],
            n["parent_code"],
            n["name"],
            n["level"],
            n["kind"],
            n["role"],
            n["is_placeholder"],
            n["account_type_code"],
        )
        for n in nodes
    ]

    cur.executemany(
        """
        INSERT INTO public.coa_template_node
          (id, template_id, code, parent_code, name, level, kind, role,
           is_placeholder, account_type_code, created_at, updated_at)
        VALUES
          (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), now())
        ON CONFLICT (template_id, code) DO UPDATE SET
          parent_code       = EXCLUDED.parent_code,
          name              = EXCLUDED.name,
          level             = EXCLUDED.level,
          kind              = EXCLUDED.kind,
          role              = EXCLUDED.role,
          is_placeholder    = EXCLUDED.is_placeholder,
          account_type_code = EXCLUDED.account_type_code,
          updated_at        = now()
        """,
        rows,
    )


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        description=(
            "Import a COA template from Excel into PostgreSQL. "
            "Template metadata is read from the 'Meta' sheet; "
            "node rows are read from the node sheet (default: first sheet)."
        )
    )

    # ── Required ──────────────────────────────────────────────────────────────
    ap.add_argument(
        "--dsn", required=True,
        help='psycopg connection string. '
             'Example: "host=localhost dbname=myaccounting_dev user=postgres password=SECRET"',
    )
    ap.add_argument(
        "--excel", required=True,
        help="Path to the Excel workbook (.xlsx / .xls).",
    )

    # ── Sheet selection ───────────────────────────────────────────────────────
    ap.add_argument(
        "--meta-sheet", default="Meta",
        help="Name of the sheet containing template metadata. Default: 'Meta'.",
    )
    ap.add_argument(
        "--sheet", default=None,
        help="Name of the sheet containing node rows. Default: first sheet.",
    )

    # ── Optional CLI overrides (take precedence over Meta sheet) ──────────────
    grp = ap.add_argument_group(
        "template metadata overrides",
        "These override the corresponding values read from the Meta sheet. "
        "Useful for scripted pipelines where you want to bump the version "
        "without editing the workbook.",
    )
    grp.add_argument("--template-code",        default=None)
    grp.add_argument("--template-name",        default=None)
    grp.add_argument("--template-description", default=None)
    grp.add_argument("--template-country",     default=None)
    grp.add_argument("--template-locale",      default=None)
    grp.add_argument("--template-industry",    default=None)
    grp.add_argument("--template-version",     default=None,
                     help="Version string (e.g. '1', '2026.01'). "
                          "Stored as TEXT in the database.")

    return ap


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    args = build_parser().parse_args()

    # 1) Load metadata from the Meta sheet
    print(f"Reading metadata from sheet '{args.meta_sheet}' in '{args.excel}' …")
    meta = load_metadata_from_excel(args.excel, args.meta_sheet)

    # 2) Apply CLI overrides (CLI wins over sheet)
    meta.merge_cli(args)

    # 3) Validate that all required fields are present
    try:
        meta.validate()
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(
        f"  Template : {meta.code}  v{meta.version}\n"
        f"  Name     : {meta.name}\n"
        f"  Country  : {meta.country}   Locale: {meta.locale}   Industry: {meta.industry}"
    )

    # 4) Load node rows
    print(f"Reading nodes from sheet '{args.sheet or '(first sheet)'}' …")
    try:
        nodes = load_nodes_from_excel(args.excel, args.sheet)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if not nodes:
        print("WARNING: No node rows found. The template will be created with no accounts.",
              file=sys.stderr)

    print(f"  Nodes loaded: {len(nodes)}")

    # 5) Database operations (single transaction)
    print("Connecting to database …")
    try:
        with psycopg.connect(args.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
                template_id = upsert_template(cur, meta)
                print(f"  Template upserted: id={template_id}")
                if nodes:
                    upsert_nodes(cur, template_id, nodes)
                    print(f"  Nodes upserted: {len(nodes)}")
            conn.commit()
    except psycopg.Error as exc:
        print(f"DATABASE ERROR: {exc}", file=sys.stderr)
        return 1

    print(
        f"\nOK: Imported template '{meta.code}' v{meta.version} "
        f"with {len(nodes)} node(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
