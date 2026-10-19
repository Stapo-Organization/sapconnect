"""Final count list for the pilot warehouse: tiers, learned weights when available, control sample, UTF-8-BOM CSV."""
import sys, json, argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT
from lib.signals import WEIGHTS, CODES, L1, L2

ap = argparse.ArgumentParser(); ap.add_argument("--wh", default="RUH010"); ap.add_argument("--control", type=int, default=30); ap.add_argument("--seed", type=int, default=2026); a = ap.parse_args()
WH = a.wh
con = duckdb.connect(str(DUCK)); tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
S = con.execute(f"SELECT * FROM signals_{WH}").fetchdf().set_index("item_code")
learned = None
wl = OUT / "weights_learned.json"
if wl.exists():
    learned = json.load(open(wl))
    coef = learned["coef"]; b0 = learned["intercept"]
    z = b0 + sum(S[c] * w for c, w in coef.items() if c in S.columns)
    S["p_raw"] = 1 / (1 + np.exp(-z))
    # decile calibration from the backtest → P(variance beyond tolerance)
    cal = pd.DataFrame(learned["calibration"]).sort_values("p_lo")
    def calib(p):
        r = cal[(cal["p_lo"] <= p)]; return float(r["rate"].iloc[-1]) if len(r) else float(cal["rate"].iloc[0])
    S["p_learned"] = S["p_raw"].map(calib)
    mag = learned["magnitude"]
    S["delta_hat"] = np.exp(mag["a"]) * np.power(S["stock_now"].abs() + 1, mag["b"])
    # items with no stock but a direct signature: at least one unit is the thing being tested
    S.loc[S["stock_now"] <= 0, "delta_hat"] = np.maximum(1.0, S.loc[S["stock_now"] <= 0, "expected_abs_var"])
    S["ev_learned"] = S["p_learned"] * S["delta_hat"] * S["unit_cost"]
    # deterministic signatures stay on top; everything else ranks by calibrated expected variance value
    S["score_final"] = np.where(S["tier"] == "مؤكد", 1e9 + S["ev_learned"], S["ev_learned"])
    S["expected_abs_var"] = S["p_learned"] * S["delta_hat"]; S["expected_var_value"] = S["ev_learned"]
else:
    S["p_raw"] = np.nan; S["p_learned"] = np.nan; S["delta_hat"] = np.nan; S["ev_learned"] = np.nan; S["score_final"] = S["score"]
# expected |Δ| calibration from the backtest when available: median abs_var of positives per tier
exp_cal = None
if "bt_features" in tables:
    bt = con.execute("SELECT tier, median(abs_var) m, avg(label) p FROM bt_features WHERE label=1 GROUP BY tier").fetchdf().set_index("tier")
    exp_cal = bt
S = S.sort_values(["score_final", "expected_var_value"], ascending=False)
S["rank"] = np.arange(1, len(S) + 1)
tot = max(S["expected_var_value"].sum(), 1e-9); S["cum_value_share"] = S["expected_var_value"].cumsum() / tot
# control sample: stratified over the LOW tier by stock-value tercile, fixed seed
rng = np.random.default_rng(a.seed)
low = S[S["tier"] == "منخفض"].copy()
if len(low):
    low["strat"] = pd.qcut(low["stock_value"].rank(method="first"), 3, labels=["low", "mid", "high"])
    per = max(1, a.control // 3)
    ctrl = pd.concat([g.sample(min(per, len(g)), random_state=int(rng.integers(1e9))) for _, g in low.groupby("strat", observed=True)])
    S["is_control"] = S.index.isin(ctrl.index)
else:
    S["is_control"] = False
S.loc[S["is_control"], "tier"] = "ضابط"
bars = con.execute("SELECT ItemCode item_code, max(CASE WHEN UoMEntry<>58 THEN Barcode END) carton_barcode FROM sap_item_barcodes GROUP BY 1").fetchdf().set_index("item_code")["carton_barcode"]
S["carton_barcode"] = bars.reindex(S.index)
abc = con.execute("SELECT item_code, abc_class FROM db_abc_all WHERE warehouse_code = ?", [WH]).fetchdf().set_index("item_code")["abc_class"]
S["abc_class"] = abc.reindex(S.index).fillna("—")
cols = ["rank", "name_ar", "item_name", "piece_barcode", "carton_barcode", "brand", "abc_class", "stock_now", "committed", "sold_units", "transfer_in_units", "opening_units", "zero_streak_instock_days", "lam_blend", "p_zero", "expected_sales_in_streak",
        "score", "p_learned", "delta_hat", "tier", "reason_codes", "fix_to_sell_events", "receive_gap_units", "open_request_units", "expired_units", "near_expiry_units", "days_since_last_move", "family", "unit_cost", "expected_abs_var", "expected_var_value", "cum_value_share", "is_control"]
out = S.reset_index()[["item_code"] + cols]
out.to_csv(OUT / f"count_list_{WH}.csv", index=False, encoding="utf-8-sig")
con.register("_s", out); con.execute(f"CREATE OR REPLACE TABLE count_list_{WH} AS SELECT * FROM _s"); con.unregister("_s")
print(f"count list → {OUT / f'count_list_{WH}.csv'}  rows={len(out)}  learned_weights={'yes' if learned else 'no'}")
print(out["tier"].value_counts().to_string())
for sh in (0.5, 0.8, 0.9): print(f"  {sh:.0%} of expected variance value → top {int((out['cum_value_share']>=sh).idxmax())+1} items")
