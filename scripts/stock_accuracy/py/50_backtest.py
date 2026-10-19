"""Backtest on the Dec-2025 year-end full counts (warehouses whose count documents include matched lines).
Features are computed as of each document's count date D with data < D only. Writes bt_* tables + out/backtest_*.csv"""
import sys, json, argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT
from lib.ledger import build_events_sap
from lib.signals import compute, WEIGHTS, CODES, L1, L2

ap = argparse.ArgumentParser(); ap.add_argument("--docs", default="", help="comma list of DocumentEntry to run (default: full-count docs)"); ap.add_argument("--min-exact", type=float, default=0.3)
a = ap.parse_args()
con = duckdb.connect(str(DUCK)); tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
SHOWROOMS = ["RUH002","RUH004","RUH005","RUH006","RUH007","RUH008","RUH009","RUH010","JED002","DMM001","MED001","ABH001","UZH001","KHO001","HBT001","BRD001"]
TOL = {"A": 0.02, "B": 0.05, "C": 0.10}

docs = con.execute("""SELECT h_DocumentEntry de, WarehouseCode wh, substr(h_CountDate,1,10) cd, count(*) n, avg((abs(CountedQuantity-InWarehouseQuantity)<=0.5)::int) exact_rate
  FROM sap_inventory_countings_docs_l WHERE Counted='tYES' AND h_DocumentStatus='cdsClosed' GROUP BY 1,2,3 HAVING count(*) >= 300 ORDER BY 2,3""").fetchdf()
if a.docs:
    want = [int(x) for x in a.docs.split(",")]; docs = docs[docs["de"].isin(want)]
else:
    docs = docs[(docs["exact_rate"] >= a.min_exact) & (docs["wh"].isin(SHOWROOMS))]   # full counts (matched lines present) in retail showrooms only
print("documents in backtest:"); print(docs.to_string(index=False))

prod = con.execute("SELECT item_code, item_name, foreign_name, zb_name_ar, items_group_code, piece_barcode, sales_items_per_unit spu, u_proprt2, u_proprt3, u_proprt4, price_l1, price_l2 FROM db_products").fetchdf().set_index("item_code")
sitems = con.execute("SELECT ItemCode item_code, TreeType, ManageBatchNumbers, InventoryUoMEntry, DefaultSalesUoMEntry FROM sap_items").fetchdf().set_index("item_code")
bars = con.execute("SELECT ItemCode item_code, count(*) n_barcodes, count(distinct UoMEntry) n_uom_barcodes FROM sap_item_barcodes GROUP BY 1").fetchdf().set_index("item_code")
brand = con.execute("SELECT code, name FROM db_brands").fetchdf().set_index("code")["name"]
pc = con.execute("SELECT item_code, cost_proxy_sar FROM db_product_costs").fetchdf().set_index("item_code")["cost_proxy_sar"]
gr = con.execute("SELECT item_code, median(line_total/NULLIF(inventory_quantity,0)) c FROM db_grpo_lines_all WHERE inventory_quantity>0 AND line_total>0 GROUP BY 1").fetchdf().set_index("item_code")["c"]
unit_cost = pc.combine_first(gr)
# network retail sales per (warehouse,item,day) from the 2025-H2 pull
net_all = con.execute("""SELECT WarehouseCode warehouse_code, ItemCode item_code, substr(h_DocDate,1,10) AS d, sum(coalesce(InventoryQuantity,Quantity)) AS qty, sum(LineTotal) AS rev
  FROM sap_invoices_2025h2_l WHERE h_CardCode='C0000001' AND coalesce(h_Cancelled,'tNO')<>'tYES' GROUP BY 1,2,3""").fetchdf()
net_all = net_all.rename(columns={"d": "day"}); net_all["day"] = pd.to_datetime(net_all["day"])

feats = []
for _, row in docs.iterrows():
    de, wh, cd = int(row["de"]), row["wh"], pd.Timestamp(row["cd"])
    D = cd + pd.Timedelta(hours=23, minutes=59, seconds=59)
    lines = con.execute("SELECT ItemCode item_code, InWarehouseQuantity sys_q, CountedQuantity cnt_q FROM sap_inventory_countings_docs_l WHERE h_DocumentEntry = ? AND Counted='tYES'", [de]).fetchdf()
    lines = lines.groupby("item_code").agg(sys_q=("sys_q", "first"), cnt_q=("cnt_q", "sum")).reset_index()
    anchor = pd.Series(pd.to_numeric(lines["sys_q"], errors="coerce").fillna(0.0).values, index=lines["item_code"])
    since = D - pd.Timedelta(days=185)
    events = build_events_sap(con, wh, until=D, since=since)
    events = events[events["item_code"].isin(anchor.index)]
    peers = net_all[(net_all["warehouse_code"] != wh) & (net_all["warehouse_code"].isin(SHOWROOMS))][["warehouse_code", "item_code", "day", "qty"]]
    S = compute(wh=wh, T0=D, open_date=None, history_start=since, anchor=anchor, committed=None, events=events, peer_sales=peers, prod=prod, sitems=sitems, bars=bars, brand=brand, unit_cost=unit_cost)
    S = S.loc[S.index.isin(anchor.index)].copy()
    S["doc"] = de; S["wh"] = wh; S["D"] = cd
    S["cnt_q"] = lines.set_index("item_code")["cnt_q"].reindex(S.index).astype(float)
    S["abs_var"] = (S["cnt_q"] - S["stock_now"]).abs()
    # ABC at D from pre-D retail sales value at this warehouse (6 months)
    sv = net_all[(net_all["warehouse_code"] == wh) & (net_all["day"] < D)].groupby("item_code")["rev"].sum().reindex(S.index).fillna(0.0).sort_values(ascending=False)
    cum = sv.cumsum() / max(sv.sum(), 1e-9)
    abc = pd.Series(np.where(cum <= 0.80, "A", np.where(cum <= 0.95, "B", "C")), index=sv.index); abc[sv <= 0] = "C"
    S["abc"] = abc.reindex(S.index).fillna("C"); S["sales_value_6m"] = sv.reindex(S.index).fillna(0.0)
    tol = S["abc"].map(TOL)
    S["label"] = ((S["abs_var"] / S["stock_now"].abs().clip(lower=1) > tol) & (S["abs_var"] >= 1)).astype(int)
    S["label_any"] = (S["abs_var"] >= 1).astype(int)
    S["var_value"] = S["abs_var"] * S["unit_cost"]
    feats.append(S.reset_index())
    print(f"  doc {de} {wh} D={cd.date()} items={len(S)} events={len(events)} positives={int(S['label'].sum())} ({S['label'].mean():.1%}) any_var={S['label_any'].mean():.1%} value={S['var_value'].sum():,.0f}")

F = pd.concat(feats, ignore_index=True)
con.register("_f", F); con.execute("CREATE OR REPLACE TABLE bt_features AS SELECT * FROM _f"); con.unregister("_f")
F.to_csv(OUT / "backtest_features.csv", index=False)

# ---------- metrics ----------
def curve(df, order_col, ascending=False, label="label", value="var_value"):
    d = df.sort_values(order_col, ascending=ascending, kind="mergesort")
    pos = d[label].values; val = (d[value] * d[label]).values
    cr = np.cumsum(pos) / max(pos.sum(), 1); cv = np.cumsum(val) / max(val.sum(), 1e-9); cp = np.cumsum(pos) / np.arange(1, len(d) + 1)
    return cr, cv, cp
def at(arr, n): return float(arr[min(n, len(arr)) - 1]) if len(arr) else np.nan
rows = []
for wh, G in list(F.groupby("wh")) + [("ALL", F)]:
    n_items = len(G); Ns = [50, 100, 200, 300, 500, int(0.1 * n_items), int(0.2 * n_items)]
    orders = {"model_score": ("score", False), "model_expected_value": ("expected_var_value", False), "value_only_abc": ("sales_value_6m", False), "stock_value": ("stock_value", False),
              "staleness": ("days_since_last_move", False), "current_method": ("_cur", True), "random": ("_rnd", True)}
    G = G.copy(); G["_cur"] = G["abc"].map({"A": 0, "B": 1, "C": 2}).astype(str) + G["item_code"]
    rng = np.random.default_rng(7)
    for name, (col, asc) in orders.items():
        if name == "random":
            accs = []
            for _ in range(100):
                G["_rnd"] = rng.random(len(G)); cr, cv, cp = curve(G, "_rnd", True); accs.append((cr, cv, cp))
            cr = np.mean([x[0] for x in accs], axis=0); cv = np.mean([x[1] for x in accs], axis=0); cp = np.mean([x[2] for x in accs], axis=0)
        else:
            cr, cv, cp = curve(G, col, asc)
        for N in Ns:
            rows.append({"wh": wh, "method": name, "N": N, "recall": at(cr, N), "value_recall": at(cv, N), "precision": at(cp, N), "items": n_items, "positives": int(G["label"].sum())})
M = pd.DataFrame(rows)
con.register("_m", M); con.execute("CREATE OR REPLACE TABLE bt_metrics AS SELECT * FROM _m"); con.unregister("_m")
M.to_csv(OUT / "backtest_metrics.csv", index=False)
print("\n== value-recall@N (ALL warehouses pooled) ==")
print(M[M["wh"] == "ALL"].pivot(index="N", columns="method", values="value_recall").round(3).to_string())
print("\n== recall@N (ALL) =="); print(M[M["wh"] == "ALL"].pivot(index="N", columns="method", values="recall").round(3).to_string())
print("\n== precision@N (ALL) =="); print(M[M["wh"] == "ALL"].pivot(index="N", columns="method", values="precision").round(3).to_string())
# signal lift table: positive rate among flagged vs base
base = F["label"].mean()
lift = []
for c in CODES:
    if c in F.columns:
        f = F[F[c] == 1]
        lift.append({"signal": c, "flagged": len(f), "pos_rate": f["label"].mean() if len(f) else np.nan, "lift": (f["label"].mean() / base) if len(f) else np.nan, "median_abs_var_pos": f.loc[f["label"] == 1, "abs_var"].median() if len(f) else np.nan})
Lf = pd.DataFrame(lift).sort_values("lift", ascending=False)
con.register("_l", Lf); con.execute("CREATE OR REPLACE TABLE bt_signal_lift AS SELECT * FROM _l"); con.unregister("_l")
print(f"\n== signal lift (base positive rate {base:.1%}) =="); print(Lf.round(3).to_string(index=False))
# pareto data for the pooled set (model order)
d = F.sort_values(["score", "expected_var_value"], ascending=False).reset_index(drop=True)
d["cum_items"] = np.arange(1, len(d) + 1); d["cum_item_share"] = d["cum_items"] / len(d)
d["cum_value_share"] = (d["var_value"] * d["label"]).cumsum() / max((d["var_value"] * d["label"]).sum(), 1e-9); d["cum_recall"] = d["label"].cumsum() / max(d["label"].sum(), 1)
d[["cum_items", "cum_item_share", "cum_value_share", "cum_recall", "wh", "item_code", "score", "label", "abs_var", "var_value", "tier", "reason_codes"]].to_csv(OUT / "backtest_pareto.csv", index=False)
# ---------- weight fitting (logistic regression, grouped CV by document) ----------
try:
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import GroupKFold
    X = F[[c for c in CODES if c in F.columns]].astype(float).values; y = F["label"].values; groups = F["doc"].values
    aps = []; coefs = []
    for tr, te in GroupKFold(n_splits=min(5, len(np.unique(groups)))).split(X, y, groups):
        m = LogisticRegression(C=0.5, max_iter=2000, class_weight="balanced").fit(X[tr], y[tr]); p = m.predict_proba(X[te])[:, 1]
        o = np.argsort(-p); yy = y[te][o]; vv = (F["var_value"].values[te] * y[te])[o]
        aps.append({"n": len(te), "value_recall@10%": float(np.cumsum(vv)[int(0.1 * len(te)) - 1] / max(vv.sum(), 1e-9)), "recall@10%": float(np.cumsum(yy)[int(0.1 * len(te)) - 1] / max(yy.sum(), 1))})
        coefs.append(m.coef_[0])
    m = LogisticRegression(C=0.5, max_iter=2000, class_weight="balanced").fit(X, y)
    learned = {c: float(w) for c, w in zip([c for c in CODES if c in F.columns], m.coef_[0])}
    # |Δ| magnitude calibration among positives: log(abs_var) ~ a + b·log(stock+1)
    pos = F[F["label"] == 1]; lx = np.log1p(pos["stock_now"].abs().values); ly = np.log(pos["abs_var"].values)
    b, a_ = np.polyfit(lx, ly, 1); mag = {"a": float(a_), "b": float(b), "median_ratio": float((pos["abs_var"] / pos["stock_now"].abs().clip(lower=1)).median())}
    # decile calibration of the LR probability (in-sample) → P(label)
    p_all = m.predict_proba(X)[:, 1]; dec = pd.qcut(p_all, 10, labels=False, duplicates="drop")
    calib = pd.DataFrame({"dec": dec, "p": p_all, "y": y}).groupby("dec").agg(p_lo=("p", "min"), p_hi=("p", "max"), rate=("y", "mean"), n=("y", "size")).reset_index()
    # CV: expected-value ranking (p × |Δ̂|(stock) × cost) vs stock_value alone vs model probability alone
    evs = []
    for tr, te in GroupKFold(n_splits=min(5, len(np.unique(groups)))).split(X, y, groups):
        mm = LogisticRegression(C=0.5, max_iter=2000, class_weight="balanced").fit(X[tr], y[tr]); pt = mm.predict_proba(X[te])[:, 1]
        st = F["stock_now"].abs().values[te]; cost = F["unit_cost"].values[te]; vv = (F["var_value"].values[te] * y[te])
        dhat = np.exp(a_) * np.power(st + 1, b)
        def vr(order, k=0.10):
            o = np.argsort(-order); n = max(1, int(k * len(te))); return float(np.cumsum(vv[o])[n - 1] / max(vv.sum(), 1e-9))
        evs.append({"n": len(te), "EV_p×Δ̂×cost@10%": vr(pt * dhat * cost), "stock_value@10%": vr(st * cost), "p_only@10%": vr(pt), "expert_score@10%": vr(F["score"].values[te]),
                    "EV@5%": vr(pt * dhat * cost, 0.05), "stock_value@5%": vr(st * cost, 0.05)})
    json.dump({"intercept": float(m.intercept_[0]), "coef": learned, "cv": aps, "magnitude": mag, "calibration": calib.to_dict(orient="records"), "cv_ev": evs}, open(OUT / "weights_learned.json", "w"), ensure_ascii=False, indent=1)
    print("\n== logistic regression (GroupKFold by document) =="); print(pd.DataFrame(aps).round(3).to_string(index=False))
    print(pd.Series(learned).sort_values(ascending=False).round(2).to_string())
    print(f"\n== |Δ| among positives: abs_var ≈ {np.exp(a_):.2f} × (stock+1)^{b:.2f}; median abs_var/stock = {mag['median_ratio']:.2f} ==")
    print("== CV value-recall: expected-value ranking vs baselines =="); E = pd.DataFrame(evs); print(E.round(3).to_string(index=False)); print(E.drop(columns="n").mean().round(3).to_string())
    print("== probability calibration (deciles) =="); print(calib.round(3).to_string(index=False))
except Exception as e:
    print("LR skipped:", e)
con.close(); print("\nbacktest written →", OUT)
