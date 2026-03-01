#!/usr/bin/env python3
"""
import_iso4217_to_commodity.py

Cross-platform ISO 4217 (SIX list-one CSV) importer into PostgreSQL `commodity`.

- Upserts by (namespace, mnemonic)
- Sets fraction from Minor unit: fraction = 10 ** minor_unit
- Uses `na_fraction` when minor_unit is missing / "N.A."
- Optionally deactivates missing mnemonics for a namespace

Example:
  python import_iso4217_to_commodity.py \
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
    --csv "C:/tmp/iso4217_current_list_one.csv" \
    --namespace CURRENCY \
    --default-fraction 100 \
    --na-fraction 100 \
    --deactivate-missing

Requires:
  pip install psycopg[binary]   (preferred)  OR  pip install psycopg2-binary
"""
from __future__ import annotations

import argparse
import csv
import os
import re
from dataclasses import dataclass
from typing import Iterable, List, Optional, Tuple

def _connect(dsn: str):
    # Prefer psycopg v3, fallback to psycopg2
    try:
        import psycopg
        return psycopg.connect(dsn)
    except ImportError:
        import psycopg2  # type: ignore
        return psycopg2.connect(dsn)

def _norm_header(h: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", h.strip().lower()).strip("_")

@dataclass(frozen=True)
class IsoRow:
    mnemonic: str
    numeric_code: Optional[str]
    minor_unit: Optional[str]
    currency: Optional[str]
    entity: Optional[str]

def read_iso_csv(path: str) -> List[IsoRow]:
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise ValueError("CSV has no header row.")
        # normalize headers to tolerate slight variations
        field_map = {_norm_header(h): h for h in reader.fieldnames}
        def get(d: dict, key: str) -> Optional[str]:
            src = field_map.get(key)
            if not src:
                return None
            v = d.get(src)
            if v is None:
                return None
            v = v.strip()
            return v if v != "" else None

        rows: List[IsoRow] = []
        for r in reader:
            mnemonic = get(r, "alphabetic_code") or get(r, "alphabeticcode") or get(r, "currency_code")
            if not mnemonic:
                continue
            rows.append(IsoRow(
                mnemonic=mnemonic,
                numeric_code=get(r, "numeric_code"),
                minor_unit=get(r, "minor_unit"),
                currency=get(r, "currency"),
                entity=get(r, "entity"),
            ))
        return rows

def fraction_from_minor_unit(minor_unit: Optional[str], default_fraction: int, na_fraction: int) -> int:
    if minor_unit is None:
        return na_fraction
    mu = minor_unit.strip()
    if mu == "":
        return na_fraction
    if mu.upper() in {"N.A.", "NA", "N/A"}:
        return na_fraction
    try:
        n = int(mu)
        if n < 0 or n > 9:
            return default_fraction
        return 10 ** n
    except ValueError:
        return default_fraction

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", default=os.getenv("PG_DSN", ""), help="PostgreSQL DSN. Or set PG_DSN.")
    ap.add_argument("--csv", required=True, help="Path to ISO 4217 list-one CSV file.")
    ap.add_argument("--namespace", default="CURRENCY")
    ap.add_argument("--default-fraction", type=int, default=100)
    ap.add_argument("--na-fraction", type=int, default=100)
    ap.add_argument("--deactivate-missing", action="store_true")
    args = ap.parse_args()

    if not args.dsn:
        raise SystemExit("ERROR: Provide --dsn or set PG_DSN env var.")

    rows = read_iso_csv(args.csv)
    if not rows:
        raise SystemExit("ERROR: No rows read from CSV (check file format).")

    # Prepare upsert payload
    payload: List[Tuple[str, str, str, int]] = []
    seen: set[str] = set()
    for r in rows:
        mnemonic = r.mnemonic.strip().upper()
        if not mnemonic:
            continue
        frac = fraction_from_minor_unit(r.minor_unit, args.default_fraction, args.na_fraction)
        full_name = (r.currency or r.entity or "No Name").strip()
        payload.append((args.namespace, mnemonic, full_name, frac))
        seen.add(mnemonic)

    conn = _connect(args.dsn)
    try:
        with conn:
            with conn.cursor() as cur:
                # Ensure unique index exists (matches your schema convention)
                cur.execute("""
                    CREATE UNIQUE INDEX IF NOT EXISTS commodity_namespace_mnemonic_ux
                    ON public.commodity(namespace, mnemonic)
                    WHERE deleted_at IS NULL;
                """)

                # Upsert currencies
                # psycopg2/3 both support executemany; for speed you can use execute_values if desired.
                cur.executemany("""
                    INSERT INTO public.commodity(namespace, mnemonic, full_name, fraction, is_active, created_at, updated_at, revision)
                    VALUES (%s, %s, %s, %s, TRUE, now(), now(), 0)
                    ON CONFLICT (namespace, mnemonic)
                    DO UPDATE SET
                        full_name = EXCLUDED.full_name,
                        fraction = EXCLUDED.fraction,
                        is_active = TRUE,
                        updated_at = now(),
                        revision = public.commodity.revision + 1
                    WHERE public.commodity.deleted_at IS NULL;
                """, payload)

                if args.deactivate_missing:
                    cur.execute("""
                        UPDATE public.commodity
                        SET is_active = FALSE,
                            updated_at = now(),
                            revision = revision + 1
                        WHERE namespace = %s
                          AND deleted_at IS NULL
                          AND mnemonic NOT IN (SELECT unnest(%s::text[]));
                    """, (args.namespace, list(seen)))

        print(f"OK: Upserted {len(payload)} rows into commodity (namespace={args.namespace}).")
        if args.deactivate_missing:
            print("OK: Deactivated missing mnemonics for that namespace.")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
