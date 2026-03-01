#!/usr/bin/env python3
"""
iso4217_importer_script.py  (v2)

Excel-based importer for ISO 4217 currency list into PostgreSQL `commodity`.

CHANGES FROM v1:
  - ON CONFLICT now matches the partial unique index:
      commodity_namespace_mnemonic_ux  WHERE deleted_at IS NULL
    This resolves: "there is no unique or exclusion constraint matching
    the ON CONFLICT specification."
  - Removed the runtime DDL guard that attempted to CREATE the index inside
    the application connection (wrong layer; the index is owned by the schema).
  - Soft-deleted rows (deleted_at IS NOT NULL) are treated as genuinely absent
    and are re-inserted as fresh active rows rather than silently skipped.
  - Minor: deactivation query now explicitly excludes already-inactive rows to
    avoid unnecessary revision bumps.

──────────────────────────────────────────────────────────────────────────────
HOW PostgreSQL partial-index ON CONFLICT works
──────────────────────────────────────────────────────────────────────────────

A partial unique index:
    CREATE UNIQUE INDEX ... ON commodity(namespace, mnemonic) WHERE deleted_at IS NULL

enforces uniqueness only among non-deleted rows.  To use it as the conflict
target in an upsert you must mirror the predicate:

    ON CONFLICT (namespace, mnemonic) WHERE deleted_at IS NULL
    DO UPDATE SET ...

Rows with deleted_at IS NOT NULL are invisible to this index, so they do NOT
trigger a conflict — they behave like new rows.  This script handles that by
checking for soft-deleted duplicates before the upsert and restoring them
instead of inserting a duplicate.

──────────────────────────────────────────────────────────────────────────────
COLUMN DETECTION
──────────────────────────────────────────────────────────────────────────────

The SIX "list-one" Excel file typically has these columns (headers vary):
  - Alphabetic Code  → mnemonic
  - Numeric Code     → ignored (informational)
  - Minor unit       → fraction = 10 ** minor_unit
  - Currency         → full_name prefix
  - Entity           → full_name suffix

fraction rules:
  - minor_unit is numeric  →  fraction = 10 ** minor_unit
                               (0 → 1,  2 → 100,  3 → 1000)
  - minor_unit missing / "N.A."  →  --na-fraction  (default 100)

──────────────────────────────────────────────────────────────────────────────
EXAMPLE
──────────────────────────────────────────────────────────────────────────────

  python iso4217_importer_script.py \\
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \\
    --excel "/path/to/list-one.xlsx" \\
    --sheet "Sheet1" \\
    --namespace CURRENCY \\
    --default-fraction 100 \\
    --na-fraction 100 \\
    --do-deactivate-missing 1
"""

from __future__ import annotations

import argparse
import sys
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd

try:
    import psycopg
except ImportError as e:
    raise SystemExit(
        "Missing dependency: psycopg (v3). Install with: pip install psycopg[binary]"
    ) from e


# ─────────────────────────────────────────────────────────────────────────────
# Utility helpers  (unchanged from v1)
# ─────────────────────────────────────────────────────────────────────────────

def _norm_header(h: Any) -> str:
    return (
        str(h).strip().lower()
        .replace(" ", "_").replace("-", "_").replace("/", "_")
    )


def _pick_col(df: pd.DataFrame, *names: str) -> Optional[str]:
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


def _parse_minor_unit(v: Any) -> Optional[int]:
    if v is None:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    s = str(v).strip()
    if not s or s.lower() in ("n.a.", "na", "n/a"):
        return None
    try:
        return int(float(s))
    except Exception:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Excel reader  (unchanged from v1)
# ─────────────────────────────────────────────────────────────────────────────

def load_iso_rows(excel_path: str, sheet: Optional[str]) -> List[Dict[str, Any]]:
    df = pd.read_excel(excel_path, sheet_name=sheet or 0, dtype=str)

    col_alpha  = _pick_col(df, "alphabetic_code", "alphabetic code", "alpha_code", "alphabetic")
    col_curr   = _pick_col(df, "currency", "Currency")
    col_entity = _pick_col(df, "entity", "Entity", "country")
    col_minor  = _pick_col(df, "minor_unit", "minor unit", "minorunit")
    col_num    = _pick_col(df, "numeric_code", "numeric code", "numeric")

    if not col_alpha:
        raise ValueError("Excel is missing an 'Alphabetic Code' column (or equivalent).")

    out: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        alpha = _as_str(row.get(col_alpha))
        if not alpha:
            continue
        out.append({
            "mnemonic":     alpha.upper(),
            "currency":     _as_str(row.get(col_curr))   if col_curr   else None,
            "entity":       _as_str(row.get(col_entity)) if col_entity else None,
            "minor_unit":   _parse_minor_unit(row.get(col_minor)) if col_minor else None,
            "numeric_code": _as_str(row.get(col_num))   if col_num    else None,
        })
    return out


# ─────────────────────────────────────────────────────────────────────────────
# Database operations
# ─────────────────────────────────────────────────────────────────────────────

def _build_computed(
    rows: List[Dict[str, Any]],
    namespace: str,
    na_fraction: int,
) -> Tuple[List[Tuple[Any, ...]], set]:
    """
    Convert raw ISO rows into (namespace, mnemonic, full_name, fraction) tuples
    and return the set of seen mnemonics for the deactivation step.
    Deduplicates by mnemonic (last writer wins, matching Excel order).
    """
    seen: set[str] = set()
    computed: List[Tuple[Any, ...]] = []

    for r in rows:
        mnemonic = r["mnemonic"]
        seen.add(mnemonic)

        minor    = r["minor_unit"]
        fraction = na_fraction if minor is None else int(pow(10, int(minor)))

        currency  = r.get("currency") or "No Name"
        entity    = r.get("entity")
        full_name = f"{currency} ({entity})" if entity else currency

        computed.append((namespace, mnemonic, full_name, fraction))

    return computed, seen


def upsert_commodities(
    cur,
    computed: List[Tuple[Any, ...]],
) -> None:
    """
    Upsert active commodities.

    ON CONFLICT target mirrors the partial unique index:
        commodity_namespace_mnemonic_ux
        ON commodity(namespace, mnemonic) WHERE deleted_at IS NULL

    Soft-deleted rows (deleted_at IS NOT NULL) are invisible to this index
    and will be re-inserted as fresh active rows.  To avoid duplicates for
    those edge cases, call restore_soft_deleted() first.
    """
    cur.executemany(
        """
        INSERT INTO public.commodity
          (id, namespace, mnemonic, full_name, fraction,
           is_active, created_at, updated_at, revision)
        VALUES
          (gen_random_uuid(), %s, %s, %s, %s,
           true, now(), now(), 0)
        ON CONFLICT (namespace, mnemonic) WHERE deleted_at IS NULL   -- ← KEY FIX
        DO UPDATE SET
          full_name  = EXCLUDED.full_name,
          fraction   = EXCLUDED.fraction,
          is_active  = true,
          updated_at = now(),
          revision   = public.commodity.revision + 1
        """,
        computed,
    )


def restore_soft_deleted(
    cur,
    namespace: str,
    mnemonics: List[str],
) -> int:
    """
    Rows with deleted_at IS NOT NULL are outside the partial index and will
    cause a duplicate INSERT (two rows for the same namespace+mnemonic).
    Restore them in-place before the main upsert so the ON CONFLICT fires
    correctly on subsequent runs.

    Returns the count of restored rows.
    """
    if not mnemonics:
        return 0
    cur.execute(
        """
        UPDATE public.commodity
           SET deleted_at = NULL,
               is_active  = true,
               updated_at = now(),
               revision   = revision + 1
         WHERE namespace   = %s
           AND mnemonic    = ANY(%s::text[])
           AND deleted_at IS NOT NULL
        """,
        (namespace, mnemonics),
    )
    return cur.rowcount


def deactivate_missing(
    cur,
    namespace: str,
    seen: set,
) -> int:
    """
    Soft-deactivate (is_active = false) any commodity in *namespace* whose
    mnemonic was not present in the current import file.
    Only touches currently active rows to avoid unnecessary revision bumps.

    Returns the count of deactivated rows.
    """
    cur.execute(
        """
        UPDATE public.commodity
           SET is_active  = false,
               updated_at = now(),
               revision   = revision + 1
         WHERE namespace   = %s
           AND deleted_at IS NULL
           AND is_active   = true           -- skip already-inactive rows
           AND mnemonic    NOT IN (
               SELECT unnest(%s::text[])
           )
        """,
        (namespace, list(seen) if seen else ["__EMPTY__"]),
    )
    return cur.rowcount


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        description="Import ISO 4217 currency data from Excel into PostgreSQL commodity table."
    )
    ap.add_argument("--dsn",      required=True, help="psycopg connection string")
    ap.add_argument("--excel",    required=True, help="Path to ISO 4217 Excel (.xlsx/.xls)")
    ap.add_argument("--sheet",    default=None,  help="Sheet name. Defaults to first sheet.")
    ap.add_argument("--namespace",             default="CURRENCY")
    ap.add_argument("--default-fraction",      type=int, default=100)
    ap.add_argument("--na-fraction",           type=int, default=100,
                    help="fraction value to use when minor_unit is N.A. or missing.")
    ap.add_argument("--do-deactivate-missing", type=int, default=0,
                    help="Set to 1 to deactivate commodities absent from this import.")
    return ap


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    args = build_parser().parse_args()

    # 1) Load rows from Excel
    print(f"Reading ISO 4217 rows from '{args.excel}' …")
    try:
        rows = load_iso_rows(args.excel, args.sheet)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if not rows:
        print("WARNING: No rows found in Excel file.", file=sys.stderr)
        return 0

    print(f"  Rows loaded: {len(rows)}")

    # 2) Build computed tuples + seen set
    computed, seen = _build_computed(rows, args.namespace, args.na_fraction)

    # 3) Database operations — single transaction
    print("Connecting to database …")
    try:
        with psycopg.connect(args.dsn) as conn:
            with conn.cursor() as cur:

                # 3a) Restore any soft-deleted rows that are in the import
                #     so the partial-index ON CONFLICT fires correctly
                restored = restore_soft_deleted(cur, args.namespace, list(seen))
                if restored:
                    print(f"  Soft-deleted rows restored: {restored}")

                # 3b) Upsert all active commodities
                upsert_commodities(cur, computed)
                print(f"  Commodities upserted: {len(computed)}")

                # 3c) Optionally deactivate absent commodities
                if args.do_deactivate_missing == 1:
                    deactivated = deactivate_missing(cur, args.namespace, seen)
                    print(f"  Commodities deactivated (not in import): {deactivated}")

            conn.commit()

    except psycopg.Error as exc:
        print(f"DATABASE ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"\nOK: Imported {len(computed)} commodities into namespace='{args.namespace}'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
