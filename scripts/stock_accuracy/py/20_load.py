"""Load production extracts (+ SAP pulls when present) into DuckDB. Idempotent (CREATE OR REPLACE)."""
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd
from lib.paths import RAW_DB, RAW_SAP, DUCK
from lib.io import read_tsv, ndjson_df, explode_lines, to_num, read_ndjson

con = duckdb.connect(str(DUCK))
def put(name, df):
    con.register("_df", df); con.execute(f"CREATE OR REPLACE TABLE {name} AS SELECT * FROM _df"); con.unregister("_df")
    print(f"  {name:38s} {len(df):>9,d} rows")

print("== production mirror extracts ==")
NUM = {
 "invoice_lines": ["line_num","quantity","line_revenue","unit_cost","gross_profit","sales_employee_code"],
 "invoice_daily_all": ["qty","n","rev"], "invoice_daily_wholesale_all": ["qty","n","rev"],
 "credit_memo_lines": ["line_num","quantity","price","line_revenue"], "credit_memo_daily_all": ["is_retail","qty","n"],
 "grpo_lines_all": ["doc_entry","line_num","quantity","inventory_quantity","unit_price","line_total","base_entry","base_type"],
 "transfer_requests": ["transfer_id","doc_entry","doc_num","expected_shipments_count","line_id","quantity","received_quantity","sent_quantity","actual_received_quantity"],
 "transfer_requests_headers_all": ["transfer_id","doc_entry","doc_num"],
 "warehouse_item_stocks_all": ["in_stock","committed","ordered"],
 "abc_all": ["annual_sales_value","annual_sales_qty","current_stock","count_in_cycle","last_variance_pct"],
 "product_costs": ["cost_proxy_sar","brand_median_margin"],
 "branch_intel_all": ["ads_30","ads_90","velocity_blended","demand_rate","is_never_sold","current_stock","days_of_cover","in_stock_rate","v_true","lost_sales_monthly","excess_units","unit_cost_sar","unit_retail_sar","capital_at_risk_sar","is_hero"],
 "zooboxi_orders": ["id","woo_order_id","total_amount","quantity","unit_price"],
 "countings_all": ["id","total_target_items","counted_quantity","system_quantity","variance"],
}
for f in sorted(RAW_DB.glob("*.tsv.gz")):
    name = f.name.replace(".tsv.gz", "")
    base = name.replace("_RUH010", "")  # WH-specific extracts → generic table name + wh column kept in data
    df = read_tsv(f)
    df = to_num(df, NUM.get(base, []))
    put("db_" + base, df)
# products ndjson (prices is a JSON string inside JSON)
pf = RAW_DB / "products.ndjson.gz"
if pf.exists():
    rows = []
    for r in read_ndjson(pf):
        pr = r.get("prices")
        if isinstance(pr, str):
            try: pr = json.loads(pr)
            except Exception: pr = None
        r["price_l1"] = next((float(p["Price"]) for p in (pr or []) if p.get("PriceList") == 1 and p.get("Price") is not None), None)
        r["price_l2"] = next((float(p["Price"]) for p in (pr or []) if p.get("PriceList") == 2 and p.get("Price") is not None), None)
        r["prices"] = json.dumps(pr, ensure_ascii=False) if pr is not None else None
        rows.append(r)
    put("db_products", pd.DataFrame(rows))

print("== SAP pulls (optional, loaded when present) ==")
def done(p: Path) -> bool:
    # a pull is complete only when its JSON summary exists (pull.php / pull_doc_by_key.php write it last)
    j = RAW_SAP / "logs" / (p.name.replace(".ndjson.gz", "") + ".json")
    return p.exists() and p.stat().st_size > 20 and j.exists() and j.stat().st_size > 2
def sap(name):
    p = RAW_SAP / f"{name}.ndjson.gz"
    return p if done(p) else None

if (p := sap("items")):
    heads, whs = [], []
    bars = []
    for it in read_ndjson(p):
        h = {k: v for k, v in it.items() if not isinstance(v, (list, dict))}
        heads.append(h)
        for w in it.get("ItemWarehouseInfoCollection") or []:
            whs.append({"ItemCode": it["ItemCode"], "WarehouseCode": w.get("WarehouseCode"), "InStock": w.get("InStock"),
                        "Committed": w.get("Committed"), "Ordered": w.get("Ordered"), "StandardAveragePrice": w.get("StandardAveragePrice"),
                        "MinimalStock": w.get("MinimalStock"), "MaximalStock": w.get("MaximalStock"), "Locked": w.get("Locked")})
        for b in it.get("ItemBarCodeCollection") or []:
            bars.append({"ItemCode": it["ItemCode"], "Barcode": b.get("Barcode"), "UoMEntry": b.get("UoMEntry"), "AbsEntry": b.get("AbsEntry")})
    put("sap_items", pd.DataFrame(heads)); put("sap_item_wh", pd.DataFrame(whs)); put("sap_item_barcodes", pd.DataFrame(bars))

HDR = ["DocEntry","DocNum","DocDate","DocTime","CardCode","Cancelled","DocumentStatus","Comments","JournalMemo","Reference2","CreationDate","UpdateDate","UpdateTime","SalesPersonCode"]
LINE = ["LineNum","ItemCode","ItemDescription","Quantity","WarehouseCode","UoMEntry","UoMCode","UnitsOfMeasurment","InventoryQuantity","BaseType","BaseEntry","BaseLine","Price","LineTotal","CostingCode","MeasureUnit","UseBaseUnits","TreeType","BarCode"]
for name, coll, hdr, line in [
    ("gen_entries", "DocumentLines", HDR, LINE), ("gen_exits", "DocumentLines", HDR, LINE),
    ("uom_sample_invoices", "DocumentLines", HDR, LINE), ("delivery_notes_probe", "DocumentLines", HDR, LINE), ("returns_probe", "DocumentLines", HDR, LINE),
    ("invoices_sap", "DocumentLines", HDR, LINE), ("credit_notes_sap", "DocumentLines", HDR, LINE),
    ("invoices_2025h2", "DocumentLines", HDR, LINE), ("credit_notes_2025h2_2026h1", "DocumentLines", HDR, LINE),
    ("gen_entries_2025h2_2026h1", "DocumentLines", HDR, LINE), ("gen_exits_2025h2_2026h1", "DocumentLines", HDR, LINE),
    ("delivery_notes_2025h2", "DocumentLines", HDR, LINE), ("returns_2025h2", "DocumentLines", HDR, LINE),
]:
    if (p := sap(name)):
        h, l = explode_lines(p, coll, hdr, line); put(f"sap_{name}_h", h); put(f"sap_{name}_l", l)
for p in [q for q in sorted(RAW_SAP.glob("stock_transfers_*.ndjson.gz")) if done(q)]:
    h, l = explode_lines(p, "StockTransferLines", ["DocEntry","DocNum","DocDate","DueDate","TaxDate","DocumentStatus","FromWarehouse","ToWarehouse","Comments","JournalMemo","Reference1","Reference2","CreationDate","UpdateDate"],
                         ["LineNum","ItemCode","ItemDescription","Quantity","WarehouseCode","FromWarehouseCode","UoMEntry","UoMCode","UnitsOfMeasurment","InventoryQuantity","BaseType","BaseEntry","BaseLine","LineStatus","MeasureUnit","UseBaseUnits","Price"])
    tag = p.name.replace("stock_transfers_", "").replace(".ndjson.gz", "")
    put(f"sap_stock_transfers_{tag}_h", h); put(f"sap_stock_transfers_{tag}_l", l)
if (p := sap("batches_ruh010")): put("sap_batches_ruh010", ndjson_df(p))
# monthly 2025-H2 invoice streams → one pair of tables (only when ALL six months are complete)
months = [RAW_SAP / f"invoices_2025m{m:02d}.ndjson.gz" for m in range(7, 13)]
if all(done(m) for m in months):
    hs, ls = [], []
    for m in months:
        h, l = explode_lines(m, "DocumentLines", HDR, LINE); hs.append(h); ls.append(l)
    put("sap_invoices_2025h2_h", pd.concat(hs, ignore_index=True)); put("sap_invoices_2025h2_l", pd.concat(ls, ignore_index=True))
else:
    print("  (monthly 2025-H2 invoice pulls not all complete yet:", sum(done(m) for m in months), "/ 6)")
if (p := sap("inventory_postings_headers")): put("sap_inventory_postings_h", ndjson_df(p))
if (p := sap("inventory_countings_headers")): put("sap_inventory_countings_h", ndjson_df(p))
for p in [q for q in sorted(RAW_SAP.glob("inventory_postings_docs*.ndjson.gz")) if done(q)]:
    h, l = explode_lines(p, "InventoryPostingLines", ["DocumentEntry","DocumentNumber","PostingDate","CountDate","CountTime","Remarks","Reference2","JournalRemark"],
                         ["LineNumber","ItemCode","WarehouseCode","InWarehouseQuantity","CountedQuantity","Variance","VariancePercentage","UoMCode","UoMCountedQuantity","ItemsPerUnit","Price","Total","CountDate","CountTime","BaseType","BaseEntry","Remarks"])
    tag = p.name.replace(".ndjson.gz", "")
    put(f"sap_{tag}_h", h); put(f"sap_{tag}_l", l)
for p in [q for q in sorted(RAW_SAP.glob("inventory_countings_docs*.ndjson.gz")) if done(q)]:
    h, l = explode_lines(p, "InventoryCountingLines", ["DocumentEntry","DocumentNumber","CountDate","CountTime","DocumentStatus","Remarks","Reference2","CountingType"], None)
    tag = p.name.replace(".ndjson.gz", "")
    put(f"sap_{tag}_h", h); put(f"sap_{tag}_l", l)
con.close(); print("loaded →", DUCK)

# --- local sqlite snapshot of warehouse_item_stocks (2026-07-27) = closure anchor D2 ---
import sqlite3
from lib.paths import ROOT
con = duckdb.connect(str(DUCK))
sq = sqlite3.connect(str(ROOT / "database" / "database.sqlite"))
snap = pd.read_sql_query("SELECT item_code, warehouse_code, in_stock, committed, ordered, created_at, updated_at FROM warehouse_item_stocks", sq)
sq.close()
put("db_local_snapshot", snap)
con.close(); print("snapshot loaded")
