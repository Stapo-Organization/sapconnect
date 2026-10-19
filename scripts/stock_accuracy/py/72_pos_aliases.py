"""Barcodes the cashiers actually scanned (invoice DocumentLines.BarCode) that SAP's
ItemBarCodeCollection does not list for that item → alias rows to import into
product_barcodes (source=pos_invoice), excluding junk and cross-item conflicts.

Output: storage/analysis/out/pos_barcode_aliases.csv (+ summary on stdout)
"""
from __future__ import annotations

import csv
import glob
import gzip
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "storage/analysis/raw/sap"
OUT = ROOT / "storage/analysis/out"
DIGITS = re.compile(r"^\d{8,14}$")


def iter_ndjson(path: Path):
    try:
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    return
    except EOFError:
        return


def norm(v: str) -> str:
    return re.sub(r"\D+", "", v).lstrip("0")


# SAP collection per item (all real barcodes, any UoM) + owner map by normalised barcode
sap_item_bcs: dict[str, set[str]] = {}
owner: dict[str, set[str]] = defaultdict(set)
for it in iter_ndjson(RAW / "items.ndjson.gz"):
    code = it["ItemCode"]
    s = set()
    for bc in it.get("ItemBarCodeCollection") or []:
        v = (bc.get("Barcode") or "").strip()
        if DIGITS.match(v) and v != code:
            s.add(v)
    mb = (it.get("BarCode") or "").strip()
    if DIGITS.match(mb) and mb != code:
        s.add(mb)
    sap_item_bcs[code] = s
    for v in s:
        owner[norm(v)].add(code)

# scanned barcodes per item
scanned: dict[str, Counter] = defaultdict(Counter)
first_m: dict[tuple, str] = {}
last_m: dict[tuple, str] = {}
for f in sorted(glob.glob(str(RAW / "invoices_*.ndjson.gz"))):
    for doc in iter_ndjson(Path(f)):
        if doc.get("Cancelled") == "tYES":
            continue
        m = (doc.get("DocDate") or "")[:7]
        for ln in doc.get("DocumentLines") or []:
            code, bc = ln.get("ItemCode"), (ln.get("BarCode") or "").strip()
            if not code or not bc or code not in sap_item_bcs:
                continue
            scanned[code][bc] += 1
            k = (code, bc)
            first_m[k] = min(first_m.get(k, m), m)
            last_m[k] = max(last_m.get(k, m), m)

rows, summary = [], Counter()
for code, ctr in scanned.items():
    for bc, n in ctr.items():
        action = "add"
        conflict = ""
        if not DIGITS.match(bc) or bc == code:
            action = "skip_junk"
        else:
            nb = norm(bc)
            if any(norm(x) == nb for x in sap_item_bcs[code]):
                action = "skip_in_sap"
            else:
                others = owner.get(nb, set()) - {code}
                if others:
                    action = "skip_conflict"
                    conflict = "|".join(sorted(others))
                elif n < 2:
                    action = "skip_single_scan"
        summary[action] += 1
        rows.append(dict(item_code=code, barcode=bc, scan_count=n, first_month=first_m[(code, bc)],
                         last_month=last_m[(code, bc)], action=action, conflict_items=conflict))

rows.sort(key=lambda r: (r["item_code"], -r["scan_count"]))
with open(OUT / "pos_barcode_aliases.csv", "w", newline="", encoding="utf-8-sig") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
# import file: only the adds
with open(OUT / "pos_barcode_aliases_import.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["item_code", "barcode", "kind", "source", "scan_count"])
    for r in rows:
        if r["action"] == "add":
            w.writerow([r["item_code"], r["barcode"], "pos", "pos_invoice", r["scan_count"]])

print(json.dumps(summary, indent=1))
adds = [r for r in rows if r["action"] == "add"]
print(f"alias rows to import: {len(adds)} for {len({r['item_code'] for r in adds})} items")
print("conflicts:")
for r in rows:
    if r["action"] == "skip_conflict":
        print(f"  {r['item_code']} scanned {r['barcode']} x{r['scan_count']} ({r['first_month']}..{r['last_month']}) but SAP gives it to {r['conflict_items']}")
