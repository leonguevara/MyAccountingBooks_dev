#!/usr/bin/env python3
"""
import_iso4217_to_commodity_from_excel.py

Excel-based importer for ISO 4217 currency list into PostgreSQL `commodity`.

This replaces the CSV-based importer and reads ISO 4217 data from an Excel file.

The SIX "list-one" file has commonly these columns (but headers vary):
  - Alphabetic Code
  - Numeric Code
  - Minor unit
  - Currency
  - Entity

This script auto-detects common header variants.

Upsert key:
  (namespace, mnemonic)

fraction rules:
  - if minor_unit is numeric: fraction = 10 ** minor_unit
  - if minor_unit is missing / "N.A.": fraction = na_fraction
  - else: default_fraction

Example:
  python import_iso4217_to_commodity_from_excel.py \
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
    --excel "/path/to/list-one.xlsx" \
    --sheet "Sheet1" \
    --namespace CURRENCY \
    --default-fraction 100 \
    --na-fraction 100 \
    --do-deactivate-missing 1
"""

from __future__ import annotations

import argparse
from typing import Any, Dict, List, Optional, Tuple
import sys
import math

import pandas as pd

try:
    import psycopg
except ImportError as e:
    raise SystemExit("Missing dependency: psycopg (v3). Install with: pip install psycopg[binary]") from e


def _connect(dsn: str):
    return psycopg.connect(dsn)


def _norm_header(h: Any) -> str:
    return str(h).strip().lower().replace(" ", "_").replace("-", "_").replace("/", "_")


def _pick_col(df: pd.DataFrame, *names: str) -> Optional[str]:
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


def _parse_minor_unit(v: Any) -> Optional[int]:
    if v is None:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    s = str(v).strip()
    if not s:
        return None
    if s.lower() in ("n.a.", "na", "n/a"):
        return None
    try:
        return int(float(s))
    except Exception:
        return None


def load_iso_rows(excel_path: str, sheet: Optional[str]) -> List[Dict[str, Any]]:
    df = pd.read_excel(excel_path, sheet_name=sheet or 0, dtype=str)

    col_alpha = _pick_col(df, "alphabetic_code", "alphabetic code", "alpha_code", "alphabetic")
    col_curr = _pick_col(df, "currency", "Currency")
    col_entity = _pick_col(df, "entity", "Entity", "country")
    col_minor = _pick_col(df, "minor_unit", "minor unit", "minorunit")
    # numeric code is optional
    col_num = _pick_col(df, "numeric_code", "numeric code", "numeric")

    if not col_alpha:
        raise ValueError("Excel is missing 'Alphabetic Code' column (or equivalent).")

    out: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        alpha = _as_str(row.get(col_alpha))
        if not alpha:
            continue
        currency = _as_str(row.get(col_curr)) if col_curr else None
        entity = _as_str(row.get(col_entity)) if col_entity else None
        minor = _parse_minor_unit(row.get(col_minor)) if col_minor else None
        num = _as_str(row.get(col_num)) if col_num else None

        out.append({
            "mnemonic": alpha,
            "currency": currency,
            "entity": entity,
            "minor_unit": minor,
            "numeric_code": num,
        })
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", required=True, help="psycopg DSN string")
    ap.add_argument("--excel", required=True, help="Path to ISO 4217 Excel (.xlsx/.xls)")
    ap.add_argument("--sheet", default=None, help="Sheet name (optional). Defaults to first sheet.")
    ap.add_argument("--namespace", default="CURRENCY")
    ap.add_argument("--default-fraction", type=int, default=100)
    ap.add_argument("--na-fraction", type=int, default=100)
    ap.add_argument("--do-deactivate-missing", type=int, default=0, help="If 1, deactivates missing mnemonics for namespace.")
    args = ap.parse_args()

    rows = load_iso_rows(args.excel, args.sheet)
    if not rows:
        print(f"WARNING: No ISO rows found in Excel: {args.excel}", file=sys.stderr)

    # Compute fraction + full_name
    computed: List[Tuple[Any, ...]] = []
    seen = set()

    for r in rows:
        mnemonic = r["mnemonic"].upper()
        seen.add(mnemonic)

        minor = r["minor_unit"]
        if minor is None:
            fraction = int(args.na_fraction)
        else:
            # 10 ** minor (0 -> 1, 2 -> 100, 3 -> 1000)
            fraction = int(pow(10, int(minor)))

        currency = r.get("currency") or "No Name"
        entity = r.get("entity")
        full_name = f"{currency} ({entity})" if entity else currency

        computed.append((args.namespace, mnemonic, full_name, fraction))

    with _connect(args.dsn) as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
            # Ensure uniqueness for ON CONFLICT
            cur.execute("""
                DO $$
                BEGIN
                  IF NOT EXISTS (
                    SELECT 1
                    FROM pg_indexes
                    WHERE schemaname = 'public'
                      AND indexname = 'commodity_namespace_mnemonic_ux'
                  ) THEN
                    EXECUTE 'CREATE UNIQUE INDEX commodity_namespace_mnemonic_ux ON public.commodity(namespace, mnemonic) WHERE deleted_at IS NULL';
                  END IF;
                END $$;
            """)

            if computed:
                cur.executemany("""
                    INSERT INTO public.commodity
                      (id, namespace, mnemonic, full_name, fraction, is_active, created_at, updated_at, revision)
                    VALUES
                      (gen_random_uuid(), %s, %s, %s, %s, true, now(), now(), 0)
                    ON CONFLICT (namespace, mnemonic)
                    DO UPDATE SET
                      full_name = EXCLUDED.full_name,
                      fraction = EXCLUDED.fraction,
                      is_active = true,
                      updated_at = now(),
                      revision = public.commodity.revision + 1
                """, computed)

            if args.do_deactivate_missing == 1:
                # Deactivate currencies not present in this import for the namespace
                cur.execute("""
                    UPDATE public.commodity
                    SET is_active = false,
                        updated_at = now(),
                        revision = revision + 1
                    WHERE namespace = %s
                      AND deleted_at IS NULL
                      AND mnemonic NOT IN (
                        SELECT unnest(%s::text[])
                      );
                """, (args.namespace, list(seen) or ["__EMPTY__"]))

        conn.commit()

    print(f"OK: Upserted {len(computed)} commodities into namespace={args.namespace}.")
    if args.do_deactivate_missing == 1:
        print(f"OK: Deactivated missing commodities (namespace={args.namespace}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
