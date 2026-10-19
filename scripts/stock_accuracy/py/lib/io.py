"""Loaders for the production TSV extracts (mysql --batch) and SAP NDJSON pulls."""
import csv, gzip, json
from pathlib import Path
import pandas as pd

def read_tsv(path: Path) -> pd.DataFrame:
    # mysql --batch escapes \t \n \\ inside values and prints NULL for nulls; no quoting.
    df = pd.read_csv(path, sep="\t", quoting=csv.QUOTE_NONE, escapechar="\\",
                     na_values=["NULL"], keep_default_na=False, dtype=str, compression="gzip")
    return df

def read_ndjson(path: Path):
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)

def ndjson_df(path: Path, drop_cols=()) -> pd.DataFrame:
    rows = []
    for r in read_ndjson(path):
        for c in drop_cols:
            r.pop(c, None)
        rows.append(r)
    return pd.DataFrame(rows)

def explode_lines(path: Path, coll: str, header_keys: list[str], line_keys: list[str] | None = None) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Split document NDJSON into (headers, lines) frames."""
    heads, lines = [], []
    for doc in read_ndjson(path):
        h = {k: doc.get(k) for k in header_keys}
        heads.append(h)
        for ln in doc.get(coll) or []:
            if line_keys:
                row = {k: ln.get(k) for k in line_keys}
            else:
                row = {k: v for k, v in ln.items() if not isinstance(v, (list, dict))}
            for k in header_keys:
                row["h_" + k] = doc.get(k)
            lines.append(row)
    return pd.DataFrame(heads), pd.DataFrame(lines)

def to_num(df: pd.DataFrame, cols) -> pd.DataFrame:
    for c in cols:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df
