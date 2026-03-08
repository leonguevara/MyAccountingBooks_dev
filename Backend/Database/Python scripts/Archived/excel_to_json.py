import pandas as pd, json
from pathlib import Path

xlsx = Path("Personales_2026.xlsx")
df = pd.read_excel(xlsx, dtype=object)

records = df.where(pd.notnull(df), None).to_dict(orient="records")

xlsx.with_suffix(".json").write_text(
    json.dumps(records, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
