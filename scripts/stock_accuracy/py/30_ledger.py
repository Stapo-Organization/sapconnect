"""Build the RUH010 movement ledger, reconstruct daily on-hand, run closure tests. Writes ledger_* tables + out/closure_*.csv"""
import sys, json, argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT, RAW_SAP
from lib.ledger import build_events, balances, onhand_at, daily_series

ap = argparse.ArgumentParser(); ap.add_argument("--wh", default="RUH010"); ap.add_argument("--open-date", default="2026-07-22")
ap.add_argument("--bridge-date", default="2026-10-03"); a = ap.parse_args()
WH = a.wh
con = duckdb.connect(str(DUCK))
tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}

# ---- anchor T0: SAP live InStock (items pull) else mirror ----
if "sap_item_wh" in tables:
    anc = con.execute("SELECT ItemCode item_code, InStock FROM sap_item_wh WHERE WarehouseCode = ?", [WH]).fetchdf()
    t0 = pd.Timestamp(json.loads((RAW_SAP / "logs" / "items.json").read_text()).get("t0_end") or pd.Timestamp.fromtimestamp((RAW_SAP / "items.ndjson.gz").stat().st_mtime))
    src = "SAP Items.ItemWarehouseInfoCollection"
else:
    anc = con.execute("SELECT item_code, in_stock InStock FROM db_warehouse_item_stocks_all WHERE warehouse_code = ?", [WH]).fetchdf()
    t0 = pd.Timestamp(con.execute("SELECT max(updated_at) FROM db_warehouse_item_stocks_all WHERE warehouse_code = ?", [WH]).fetchone()[0])
    src = "mirror warehouse_item_stocks (interim)"
anchor = pd.Series(pd.to_numeric(anc["InStock"], errors="coerce").fillna(0.0).values, index=anc["item_code"])
print(f"T0 = {t0}  anchor source = {src}  items with anchor = {len(anchor)}  units = {anchor.sum():,.0f}")

bridge = a.bridge_date if "sap_invoices_sap_l" in tables else None
events = build_events(con, WH, bridge, t0)
print("events:", len(events)); print(events.groupby("kind")["qty"].agg(["count", "sum"]).to_string())
items = pd.Index(sorted(set(events["item_code"]) | set(anchor.index)))

# ---- closure tests ----
res = {}
# (a) pre-opening: on-hand just before the first transfer day must be 0
pre = pd.Timestamp(a.open_date) - pd.Timedelta(seconds=1)
for v in ("lenient", "conservative"):
    oh = onhand_at(events, anchor, pre, v, items)
    res[f"pre_open_{v}"] = oh
# (b) D2 = local snapshot 2026-07-27 16:09:25 (sync window 15:57–16:09)
snap = con.execute("SELECT item_code, in_stock FROM db_local_snapshot WHERE warehouse_code = ?", [WH]).fetchdf().set_index("item_code")["in_stock"].astype(float)
d2 = pd.Timestamp("2026-07-27 16:09:25")
for v in ("lenient", "conservative"):
    oh = onhand_at(events, anchor, d2, v, items)
    res[f"d2_{v}"] = oh
clos = pd.DataFrame({"item_code": items})
for k, s in res.items(): clos[k] = s.reindex(items).values
clos["snap_0727"] = snap.reindex(items).fillna(0.0).values
clos["anchor_t0"] = anchor.reindex(items).fillna(0.0).values
clos["resid_d2_lenient"] = clos["d2_lenient"] - clos["snap_0727"]
clos["resid_d2_conservative"] = clos["d2_conservative"] - clos["snap_0727"]
clos["resid_d2_best"] = np.where(clos["resid_d2_lenient"].abs() <= clos["resid_d2_conservative"].abs(), clos["resid_d2_lenient"], clos["resid_d2_conservative"])
# same-day (07-27) timeless movement makes D2 ambiguous
amb = set(events.loc[(~events["has_time"].astype(bool)) & (events["day"] == pd.Timestamp("2026-07-27")), "item_code"])
clos["d2_ambiguous"] = clos["item_code"].isin(amb)
clos["in_snap"] = clos["item_code"].isin(snap.index)
clos["sold_or_moved"] = clos["item_code"].isin(events["item_code"])

def summ(s, label):
    s = s.dropna(); n = len(s)
    print(f"  {label:34s} n={n:5d}  |res|<=0.5: {(s.abs()<=0.5).mean():6.1%}   median|res|={s.abs().median():.1f}  p90|res|={s.abs().quantile(.9):.1f}  mean res={s.mean():+.2f}  sum res={s.sum():+.0f}")
print("\n== closure (a) pre-opening on-hand must be 0 ==")
summ(clos["pre_open_lenient"], "pre-open lenient (all items)"); summ(clos["pre_open_conservative"], "pre-open conservative")
print("== closure (b) D2 snapshot 2026-07-27 16:09 ==")
m = clos["in_snap"] | clos["sold_or_moved"]
summ(clos.loc[m, "resid_d2_lenient"], "D2 lenient"); summ(clos.loc[m, "resid_d2_conservative"], "D2 conservative"); summ(clos.loc[m, "resid_d2_best"], "D2 best-of-two")
summ(clos.loc[m & ~clos["d2_ambiguous"], "resid_d2_best"], "D2 best, unambiguous items"); summ(clos.loc[m & clos["d2_ambiguous"], "resid_d2_best"], "D2 best, ambiguous (07-27 moves)")
print("\n  worst D2 residuals (unambiguous):")
w = clos.loc[m & ~clos["d2_ambiguous"]].assign(absr=lambda d: d["resid_d2_best"].abs()).sort_values("absr", ascending=False).head(15)
print(w[["item_code","snap_0727","d2_lenient","d2_conservative","anchor_t0","resid_d2_best"]].to_string(index=False))
print("\n  worst pre-opening residuals:")
w2 = clos.assign(absr=lambda d: d["pre_open_lenient"].abs()).sort_values("absr", ascending=False).head(15)
print(w2[["item_code","pre_open_lenient","pre_open_conservative","anchor_t0","snap_0727"]].to_string(index=False))

# ---- persist ----
bal_l = balances(events, anchor, "lenient"); bal_c = balances(events, anchor, "conservative")
eod_l, daily = daily_series(events, anchor, pd.Timestamp(a.open_date) - pd.Timedelta(days=2), t0, "lenient")
eod_c, _ = daily_series(events, anchor, pd.Timestamp(a.open_date) - pd.Timedelta(days=2), t0, "conservative")
long_l = eod_l.stack().rename("eod_lenient").reset_index().rename(columns={"level_0": "item_code", "level_1": "day"})
long_c = eod_c.stack().rename("eod_conservative").reset_index().rename(columns={"level_0": "item_code", "level_1": "day"})
mv = daily.stack().rename("net_move").reset_index().rename(columns={"level_0": "item_code", "level_1": "day"})
ld = long_l.merge(long_c, on=["item_code", "day"]).merge(mv, on=["item_code", "day"])
for name, df in [("ledger_events", events), ("ledger_bal_lenient", bal_l), ("ledger_bal_conservative", bal_c), ("ledger_daily", ld), ("ledger_closure", clos)]:
    con.register("_df", df); con.execute(f"CREATE OR REPLACE TABLE {name} AS SELECT * FROM _df"); con.unregister("_df")
con.execute("CREATE OR REPLACE TABLE ledger_meta AS SELECT ? AS wh, ? AS t0, ? AS anchor_source, ? AS bridge_date", [WH, str(t0), src, bridge or ""])
clos.to_csv(OUT / f"closure_{WH}.csv", index=False)
con.close(); print("\nledger tables written; closure →", OUT / f"closure_{WH}.csv")
