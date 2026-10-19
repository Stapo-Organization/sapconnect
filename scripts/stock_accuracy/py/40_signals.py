"""Live signals for the pilot warehouse (anchor = SAP InStock at T0). Writes signals_<WH> + out/signals_<WH>.csv"""
import sys, argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT
from lib.signals import compute, WEIGHTS

ap = argparse.ArgumentParser(); ap.add_argument("--wh", default="RUH010"); ap.add_argument("--open-date", default="2026-07-22"); a = ap.parse_args()
WH = a.wh
con = duckdb.connect(str(DUCK)); tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
meta = con.execute("SELECT * FROM ledger_meta").fetchdf().iloc[0]; T0 = pd.Timestamp(meta["t0"]); OPEN = pd.Timestamp(a.open_date)
SHOWROOMS = ["RUH002","RUH004","RUH005","RUH006","RUH007","RUH008","RUH009","RUH010","JED002","DMM001","MED001","ABH001","UZH001","KHO001","HBT001","BRD001"]
PEERS = [w for w in SHOWROOMS if w != WH]
st = con.execute("SELECT ItemCode AS item_code, InStock AS s, Committed AS c FROM sap_item_wh WHERE WarehouseCode = ?", [WH]).fetchdf().set_index("item_code")
anchor = pd.to_numeric(st["s"], errors="coerce").fillna(0.0); committed = pd.to_numeric(st["c"], errors="coerce").fillna(0.0)
events = con.execute("SELECT * FROM ledger_events").fetchdf()
for c in ["ts", "ts_lenient", "ts_conservative", "day"]: events[c] = pd.to_datetime(events[c])
peer_sales = con.execute("SELECT warehouse_code, item_code, doc_date AS day, qty FROM db_invoice_daily_all WHERE warehouse_code IN (SELECT UNNEST(?)) AND doc_date >= ?", [PEERS, (T0 - pd.Timedelta(days=100)).strftime("%Y-%m-%d")]).fetchdf()
prod = con.execute("SELECT item_code, item_name, foreign_name, zb_name_ar, items_group_code, piece_barcode, sales_items_per_unit spu, u_proprt2, u_proprt3, u_proprt4, price_l1, price_l2 FROM db_products").fetchdf().set_index("item_code")
sitems = con.execute("SELECT ItemCode item_code, TreeType, ManageBatchNumbers, InventoryUoMEntry, DefaultSalesUoMEntry FROM sap_items").fetchdf().set_index("item_code")
bars = con.execute("SELECT ItemCode item_code, count(*) n_barcodes, count(distinct UoMEntry) n_uom_barcodes FROM sap_item_barcodes GROUP BY 1").fetchdf().set_index("item_code")
brand = con.execute("SELECT code, name FROM db_brands").fetchdf().set_index("code")["name"]
treq = con.execute("SELECT * FROM db_transfer_requests").fetchdf()
batches = con.execute("SELECT _item item_code, WhsCode, BatchNumber, Quantity, ExpiryDate FROM sap_batches_ruh010 WHERE WhsCode = ?", [WH]).fetchdf() if "sap_batches_ruh010" in tables else None
online = con.execute("SELECT item_code, quantity, substr(created_at,1,10) d FROM db_zooboxi_orders WHERE delivery_status IN ('delivered','completed')").fetchdf()
pc = con.execute("SELECT item_code, cost_proxy_sar FROM db_product_costs").fetchdf().set_index("item_code")["cost_proxy_sar"]
gr = con.execute("SELECT item_code, median(line_total/NULLIF(inventory_quantity,0)) c FROM db_grpo_lines_all WHERE inventory_quantity>0 AND line_total>0 GROUP BY 1").fetchdf().set_index("item_code")["c"]
unit_cost = pc.combine_first(gr)
S = compute(wh=WH, T0=T0, open_date=OPEN, anchor=anchor, committed=committed, events=events, peer_sales=peer_sales, prod=prod, sitems=sitems, bars=bars, brand=brand,
            transfer_requests=treq, batches=batches, online=online, unit_cost=unit_cost)
con.register("_s", S.reset_index()); con.execute(f"CREATE OR REPLACE TABLE signals_{WH} AS SELECT * FROM _s"); con.unregister("_s")
S.reset_index().to_csv(OUT / f"signals_{WH}.csv", index=False)
print(f"universe={len(S)} stocked={int((S['stock_now']>0).sum())} T0={T0} peer_scale={S.attrs['peer_scale']:.3f} own_units/day={S.attrs['own_rate_total']:.1f} batches={'yes' if batches is not None else 'no'}")
print("\n== scenario counters =="); print(S[[c for c in WEIGHTS if c in S.columns]].sum().astype(int).sort_values(ascending=False).to_string())
print("\n== tiers =="); print(S["tier"].value_counts().to_string())
print("\n== top 20 =="); print(S.head(20)[["rank","name_ar","stock_now","sold_units","zero_streak_instock_days","lam_blend","p_zero","tier","score","reason_codes"]].to_string(max_colwidth=34))
