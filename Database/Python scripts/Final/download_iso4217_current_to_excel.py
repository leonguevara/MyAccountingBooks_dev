#!/usr/bin/env python3
"""
Download ISO 4217 "List One" (current currency & funds) from SIX and export to Excel.

Source:
- SIX Group "List one: Currency, fund and precious metal codes" (list-one.xls)
  https://www.six-group.com/.../iso-currrency/lists/list-one.xls

Notes:
- The ISO 4217 official PDFs are paywalled, but SIX publishes machine-readable tables.
- Columns may slightly change over time; this script tries to auto-detect headers.

Requires:
  pip install pandas openpyxl xlrd requests
"""

from __future__ import annotations

import re
from pathlib import Path

import requests
import pandas as pd


SIX_LIST_ONE_URL = (
    "https://www.six-group.com/dam/download/financial-information/data-center/"
    "iso-currrency/lists/list-one.xls"
)

OUT_XLSX = Path("iso4217_current_list_one.xlsx")
OUT_CSV = Path("iso4217_current_list_one.csv")


def download_file(url: str, dest: Path, timeout: int = 60) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        with dest.open("wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 256):
                if chunk:
                    f.write(chunk)


def find_header_row(df: pd.DataFrame) -> int:
    """
    SIX xls often includes some title rows before the real header.
    We'll scan for a row containing something like "Alphabetic Code" / "Currency" / "Entity".
    """
    header_candidates = [
        r"alphabetic",
        r"currency",
        r"entity",
        r"numeric",
        r"minor",
    ]
    for i in range(min(len(df), 60)):
        row = df.iloc[i].fillna("").astype(str).str.lower().tolist()
        joined = " | ".join(map(str, row))
        if sum(1 for pat in header_candidates if re.search(pat, joined)) >= 3:
            return i
    return 0


def normalize_columns(cols: list[str]) -> list[str]:
    norm = []
    for c in cols:
        c0 = re.sub(r"\s+", " ", str(c)).strip().lower()
        c0 = c0.replace("\n", " ")
        # common mappings
        if "alphabetic" in c0 and "code" in c0:
            norm.append("alphabetic_code")
        elif "numeric" in c0 and "code" in c0:
            norm.append("numeric_code")
        elif "minor" in c0 and ("unit" in c0 or "units" in c0):
            norm.append("minor_unit")
        elif c0 in ("currency", "currency name", "currencyname"):
            norm.append("currency")
        elif "entity" in c0:
            norm.append("entity")
        elif "withdrawal" in c0 or "withdraw" in c0:
            norm.append("withdrawal_date")
        elif "remark" in c0 or "remarks" in c0:
            norm.append("remarks")
        elif "country" in c0:
            norm.append("country")
        else:
            norm.append(re.sub(r"[^a-z0-9_]+", "_", c0).strip("_") or "col")
    return norm


def main() -> None:
    xls_path = Path("list-one.xls")
    print(f"Downloading: {SIX_LIST_ONE_URL}")
    download_file(SIX_LIST_ONE_URL, xls_path)
    print(f"Saved: {xls_path.resolve()}")

    # Read raw (no header) to locate header row
    raw = pd.read_excel(xls_path, header=None, dtype=str, engine="xlrd")
    header_row = find_header_row(raw)
    print(f"Detected header row: {header_row}")

    # Re-read using that header row
    df = pd.read_excel(xls_path, header=header_row, dtype=str, engine="xlrd")

    # Drop completely empty columns
    df = df.dropna(axis=1, how="all")

    # Normalize column names
    df.columns = normalize_columns(list(df.columns))

    # Keep only the columns we care about (if present)
    wanted = [
        "alphabetic_code",
        "numeric_code",
        "minor_unit",
        "currency",
        "entity",
        "withdrawal_date",
        "remarks",
    ]
    existing = [c for c in wanted if c in df.columns]
    df_out = df[existing].copy()

    # Clean up values
    if "alphabetic_code" in df_out.columns:
        df_out["alphabetic_code"] = df_out["alphabetic_code"].str.strip().str.upper()

    if "numeric_code" in df_out.columns:
        df_out["numeric_code"] = (
            df_out["numeric_code"]
            .astype(str)
            .str.strip()
            .str.replace(r"\.0$", "", regex=True)
        )

    if "minor_unit" in df_out.columns:
        df_out["minor_unit"] = (
            df_out["minor_unit"]
            .astype(str)
            .str.strip()
            .str.replace(r"\.0$", "", regex=True)
        )

    # Remove obvious header repeats / junk rows
    if "alphabetic_code" in df_out.columns:
        df_out = df_out[df_out["alphabetic_code"].notna()]
        df_out = df_out[df_out["alphabetic_code"].str.fullmatch(r"[A-Z]{3}", na=False)]

    df_out = df_out.drop_duplicates(subset=["alphabetic_code"], keep="first")

    # Export
    df_out.to_excel(OUT_XLSX, index=False)
    df_out.to_csv(OUT_CSV, index=False, encoding="utf-8")

    print(f"Exported Excel: {OUT_XLSX.resolve()}")
    print(f"Exported CSV:   {OUT_CSV.resolve()}")
    print(f"Rows: {len(df_out)}")


if __name__ == "__main__":
    main()
