from pathlib import Path
HERE = Path(__file__).resolve()
ROOT = HERE.parents[4]            # repo root (…/sapconnect)
ANALYSIS = ROOT / "storage" / "analysis"
RAW_DB = ANALYSIS / "raw" / "db"
RAW_SAP = ANALYSIS / "raw" / "sap"
WORK = ANALYSIS / "work"
OUT = ANALYSIS / "out"
DUCK = WORK / "stock_accuracy.duckdb"
for p in (WORK, OUT):
    p.mkdir(parents=True, exist_ok=True)
