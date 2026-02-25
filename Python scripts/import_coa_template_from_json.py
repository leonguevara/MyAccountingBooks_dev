#!/usr/bin/env python3
"""
import_coa_template_from_json.py

Cross-platform importer for COA templates from a normalized JSON array file into PostgreSQL.

It mirrors the logic in 004_generic_import_coa_template_pipeline.pgsql:
- Upserts coa_template by (code, version)
- Upserts coa_template_node by (template_id, code)

Example:
  python import_coa_template_from_json.py \
    --dsn "host=localhost port=5432 dbname=myaccounting_dev user=postgres password=SECRET" \
    --template-code PERSONALES_2026 \
    --template-name "Personal Chart of Accounts 2026" \
    --template-description "Personal chart of accounts..." \
    --template-country MX \
    --template-locale es-MX \
    --template-industry NULL \
    --template-version 1 \
    --json "C:/tmp/Personales_2026_normalized_for_import_with_account_type_code.json"

Requires:
  pip install psycopg[binary]   (preferred)  OR  pip install psycopg2-binary
"""
from __future__ import annotations

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Tuple

def _connect(dsn: str):
    try:
        import psycopg
        return psycopg.connect(dsn)
    except ImportError:
        import psycopg2  # type: ignore
        return psycopg2.connect(dsn)

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", default=os.getenv("PG_DSN", ""), help="PostgreSQL DSN. Or set PG_DSN.")
    ap.add_argument("--template-code", required=True)
    ap.add_argument("--template-name", required=True)
    ap.add_argument("--template-description", default=None)
    ap.add_argument("--template-country", default=None)
    ap.add_argument("--template-locale", default=None)
    ap.add_argument("--template-industry", default="NULL", help="Use NULL to store NULL.")
    ap.add_argument("--template-version", default="1")
    ap.add_argument("--json", required=True, help="Path to normalized JSON array file.")
    args = ap.parse_args()

    if not args.dsn:
        raise SystemExit("ERROR: Provide --dsn or set PG_DSN env var.")

    industry = None if (args.template_industry or "").upper() == "NULL" else args.template_industry

    with open(args.json, "r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise SystemExit("ERROR: JSON file must contain an array of objects.")

    # Normalize nodes
    nodes: List[Dict[str, Any]] = []
    for obj in data:
        if not isinstance(obj, dict):
            continue
        code = (obj.get("code") or "").strip()
        if not code:
            continue
        nodes.append({
            "code": code,
            "parent_code": (obj.get("parent_code") or None),
            "name": (obj.get("name") or "No Name"),
            "level": int(obj.get("level") or 0),
            "kind": int(obj.get("kind") or 0),
            "role": int(obj.get("role") or 0),
            "is_placeholder": bool(obj.get("is_placeholder") or False),
            "account_type_code": (obj.get("account_type_code") or None),
        })

    conn = _connect(args.dsn)
    try:
        with conn:
            with conn.cursor() as cur:
                # Upsert template
                cur.execute("""
                    INSERT INTO public.coa_template
                      (code, name, description, country, locale, industry, version, is_active, created_at, updated_at)
                    VALUES
                      (%s, %s, %s, %s, %s, %s, %s, TRUE, now(), now())
                    ON CONFLICT (code, version)
                    DO UPDATE SET
                      name = EXCLUDED.name,
                      description = COALESCE(EXCLUDED.description, public.coa_template.description),
                      country = COALESCE(EXCLUDED.country, public.coa_template.country),
                      locale = COALESCE(EXCLUDED.locale, public.coa_template.locale),
                      industry = COALESCE(EXCLUDED.industry, public.coa_template.industry),
                      is_active = EXCLUDED.is_active,
                      updated_at = now()
                    RETURNING id;
                """, (args.template_code, args.template_name, args.template_description,
                      args.template_country, args.template_locale, industry, args.template_version))
                template_id = cur.fetchone()[0]

                # Upsert nodes
                payload: List[Tuple[Any, str, Optional[str], str, int, int, int, bool, Optional[str]]] = []
                for n in nodes:
                    payload.append((
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
                      updated_at = now();
                """, payload)

        print(f"OK: Imported template {args.template_code} v{args.template_version} with {len(nodes)} nodes.")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
