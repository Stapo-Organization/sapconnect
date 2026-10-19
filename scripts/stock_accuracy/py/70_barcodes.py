"""Derive piece/carton barcodes for every SAP item and validate the rule.

Rule under test (what the backfill will use):
  piece  = ItemBarCodeCollection entry whose UoMEntry == InventoryUoMEntry
           (fallback: Items.BarCode when it is a real barcode), ignoring
           placeholders ('X', the item code, < 8 digits)
  carton = entry whose UoMEntry == DefaultSalesUoMEntry (when != inventory UoM),
           else any other UoMEntry

Ground truth: the barcode the cashier actually scanned on retail invoices
(DocumentLines.BarCode with UoMEntry == the item's inventory UoM).
"""
from __future__ import annotations

import csv
import glob
import gzip
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "storage/analysis/raw/sap"
OUT = ROOT / "storage/analysis/out"
OUT.mkdir(parents=True, exist_ok=True)

DIGITS = re.compile(r"^\d{8,14}$")


def real_barcode(v: str | None, item_code: str) -> str | None:
    if not v:
        return None
    v = v.strip()
    if v.upper() in ("X", "XX", "N/A", "NA", "-") or v == item_code:
        return None
    if not DIGITS.match(v):
        return None
    return v


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
                    return  # truncated tail of an aborted pull
    except EOFError:
        print(f"  (truncated gzip, stopped early: {path.name})")
        return


# ── 1. items ─────────────────────────────────────────────────────────────────
items = {}
for it in iter_ndjson(RAW / "items.ndjson.gz"):
    code = it["ItemCode"]
    inv = it.get("InventoryUoMEntry")
    sales = it.get("DefaultSalesUoMEntry")
    coll = it.get("ItemBarCodeCollection") or []
    piece, carton, other = [], [], []
    for bc in coll:
        v = real_barcode(bc.get("Barcode"), code)
        if not v:
            continue
        u = bc.get("UoMEntry")
        if u == inv:
            piece.append(v)
        elif sales is not None and u == sales and sales != inv:
            carton.append(v)
        else:
            other.append((u, v))
    main = real_barcode(it.get("BarCode"), code)
    items[code] = dict(
        item_code=code,
        name=it.get("ItemName"),
        main_barcode=main,
        inv_uom=inv,
        sales_uom=sales,
        spu=it.get("SalesItemsPerUnit"),
        piece_candidates=piece,
        carton_candidates=carton,
        other_candidates=other,
        coll_size=len(coll),
    )

print(f"items: {len(items)}")
c = Counter()
for d in items.values():
    c["has_main"] += bool(d["main_barcode"])
    c["piece_1"] += len(d["piece_candidates"]) == 1
    c["piece_many"] += len(d["piece_candidates"]) > 1
    c["piece_0"] += len(d["piece_candidates"]) == 0
    c["piece_0_but_main"] += (len(d["piece_candidates"]) == 0 and bool(d["main_barcode"]))
    c["main_in_piece"] += bool(d["main_barcode"]) and d["main_barcode"] in d["piece_candidates"]
    c["main_in_carton"] += bool(d["main_barcode"]) and d["main_barcode"] in d["carton_candidates"]
    c["carton_any"] += len(d["carton_candidates"]) > 0
    c["other_any"] += len(d["other_candidates"]) > 0
    c["coll_empty"] += d["coll_size"] == 0
print(json.dumps(c, indent=1))

# ── 2. ground truth from retail invoices ──────────────────────────────────────
scanned = defaultdict(Counter)        # item -> Counter(barcode) for piece-UoM lines
scanned_uom = defaultdict(Counter)    # item -> Counter((uom, barcode)) all lines
files = sorted(glob.glob(str(RAW / "invoices_*.ndjson.gz")))
n_docs = n_lines = 0
for f in files:
    for doc in iter_ndjson(Path(f)):
        if doc.get("Cancelled") == "tYES":
            continue
        n_docs += 1
        for ln in doc.get("DocumentLines") or []:
            code = ln.get("ItemCode")
            bc = ln.get("BarCode")
            if not code or not bc:
                continue
            n_lines += 1
            u = ln.get("UoMEntry")
            scanned_uom[code][(u, bc)] += 1
            inv = items.get(code, {}).get("inv_uom")
            if inv is not None and u == inv:
                scanned[code][bc] += 1
print(f"invoice docs {n_docs}, lines with barcode {n_lines}, items with scanned piece barcodes {len(scanned)}")

# ── 2b. production products (this morning's extract) ─────────────────────────
prod = {}
for r in iter_ndjson(ROOT / "storage/analysis/raw/db/products.ndjson.gz"):
    prod[r.get("item_code")] = (r.get("piece_barcode") or "").strip() or None
print(f"prod products: {len(prod)}, with barcode: {sum(1 for v in prod.values() if v)}")

# ── 3. compare rule vs scanned ───────────────────────────────────────────────
rows = []
agree = Counter()
for code, d in items.items():
    piece = d["piece_candidates"]
    rule = None
    if len(piece) == 1:
        rule = piece[0]
    elif len(piece) > 1:
        rule = d["main_barcode"] if d["main_barcode"] in piece else piece[0]
    elif d["main_barcode"] and d["main_barcode"] not in d["carton_candidates"]:
        rule = d["main_barcode"]
    top = scanned.get(code)
    top_bc, top_n = (top.most_common(1)[0] if top else (None, 0))
    status = "no_scan"
    if top_bc:
        if rule is None:
            status = "rule_none_scan_has"
        elif rule == top_bc:
            status = "agree"
        elif rule.lstrip("0") == top_bc.lstrip("0"):
            status = "agree_lz"
        elif top_bc in piece:
            status = "scan_other_piece_candidate"
        else:
            status = "DISAGREE"
    agree[status] += 1
    cur = prod.get(code)
    if cur is None and code not in prod:
        prod_status = "not_in_prod"
    elif cur is None:
        prod_status = "prod_empty_fill" if rule else "prod_empty_no_rule"
    elif rule is None:
        prod_status = "prod_has_rule_none"
    elif cur == rule:
        prod_status = "prod_same"
    elif cur.lstrip("0") == rule.lstrip("0"):
        prod_status = "prod_same_lz"
    elif cur in d["carton_candidates"]:
        prod_status = "PROD_IS_CARTON"
    elif cur in piece:
        prod_status = "prod_other_piece"
    else:
        prod_status = "PROD_DIFFERS"
    agree["prod:" + prod_status] += 1
    rows.append(dict(
        item_code=code, name=d["name"], rule_piece=rule, prod_barcode=cur, prod_status=prod_status,
        scanned_top=top_bc, scanned_n=top_n,
        scanned_distinct=len(top) if top else 0, status=status,
        main_barcode=d["main_barcode"], inv_uom=d["inv_uom"], sales_uom=d["sales_uom"], spu=d["spu"],
        piece_candidates="|".join(piece), carton_candidates="|".join(d["carton_candidates"]),
        other_candidates="|".join(f"{u}:{v}" for u, v in d["other_candidates"]),
    ))
print(json.dumps(agree, indent=1))

with open(OUT / "barcode_rule_vs_scanned.csv", "w", newline="", encoding="utf-8-sig") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

# duplicates: same piece barcode on several items
dup = defaultdict(list)
for r in rows:
    if r["rule_piece"]:
        dup[r["rule_piece"]].append(r["item_code"])
dups = {k: v for k, v in dup.items() if len(v) > 1}
print(f"piece barcodes shared by >1 item: {len(dups)}")
for k, v in list(dups.items())[:10]:
    print("  ", k, v)

# disagreements detail
print("\nDISAGREE / rule_none / prod-conflict samples:")
for r in rows:
    if r["status"] in ("DISAGREE", "rule_none_scan_has", "scan_other_piece_candidate") or r["prod_status"] in ("PROD_IS_CARTON", "PROD_DIFFERS"):
        print(f"  [{r['prod_status']}] prod={r['prod_barcode']}", end=" ")
        print(f"  {r['item_code']:<11} rule={r['rule_piece']} scanned={r['scanned_top']}x{r['scanned_n']} "
              f"piece={r['piece_candidates']} carton={r['carton_candidates']} other={r['other_candidates']} main={r['main_barcode']}")
