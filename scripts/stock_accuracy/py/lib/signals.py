"""Scenario-catalog signals for one warehouse as of an anchor instant T0 (today or a historical count date D).
Inputs are plain frames so the same code serves the live run (RUH010) and the backtest (year-end counts)."""
from __future__ import annotations
import numpy as np, pandas as pd
from .families import family_key
from .ledger import balances, daily_series

WEIGHTS = {"NEG_STOCK": 5, "SOLD_AT_ZERO": 4, "IMPLIED_NEG": 1, "FIX_TO_SELL": 4, "RETURN_THEN_SALE": 2, "RECEIVE_GAP": 3, "FRACTIONAL": 3, "UNINVOICED_ONLINE": 3,
           "POISSON_ZERO": 3, "POISSON_ZERO_STRONG": 1.5, "VELOCITY_DROP": 1.5, "SIBLING_SUB": 2, "SOLD_AT_ZERO_POSSIBLE": 1.5, "EXPIRED_ON_HAND": 2.5, "NEAR_EXPIRY": 0.5,
           "HIGH_TXN": 0.8, "OPENING_BULK": 0.8, "MULTIPACK": 0.7, "BIG_FAMILY": 0.3, "HIGH_RETURNS": 0.7, "BOM_ITEM": 1, "OPEN_TRANSFER": 0.8, "OVERCOVER": 0.6, "OFF_RANGE": 0.8, "HIGH_VALUE": 0.5, "ADJ_HISTORY": 1.0}
L1 = ["NEG_STOCK", "SOLD_AT_ZERO", "FIX_TO_SELL", "RECEIVE_GAP", "FRACTIONAL", "UNINVOICED_ONLINE", "RETURN_THEN_SALE"]
L2 = ["POISSON_ZERO", "SIBLING_SUB", "VELOCITY_DROP", "EXPIRED_ON_HAND", "SOLD_AT_ZERO_POSSIBLE"]
CODES = [c for c in WEIGHTS if c != "POISSON_ZERO_STRONG"]

def compute(*, wh: str, T0: pd.Timestamp, open_date: pd.Timestamp | None, anchor: pd.Series, committed: pd.Series | None, events: pd.DataFrame,
            peer_sales: pd.DataFrame, prod: pd.DataFrame, sitems: pd.DataFrame | None, bars: pd.DataFrame | None, brand: pd.Series | None,
            transfer_requests: pd.DataFrame | None = None, batches: pd.DataFrame | None = None, online: pd.DataFrame | None = None,
            unit_cost: pd.Series | None = None, adj_history: pd.Series | None = None, history_start: pd.Timestamp | None = None, weights: dict | None = None) -> pd.DataFrame:
    W = weights or WEIGHTS
    today = T0.normalize()
    start = open_date if open_date is not None else (history_start or (today - pd.Timedelta(days=365)))
    ev = events[events["ts"] <= T0].copy()
    bal_l = balances(ev, anchor, "lenient"); bal_c = balances(ev, anchor, "conservative")
    eod_l, _ = daily_series(ev, anchor, start - pd.Timedelta(days=2), T0, "lenient")
    daily = eod_l.stack().rename("eod_lenient").reset_index().rename(columns={"level_0": "item_code", "level_1": "day"}); daily["day"] = pd.to_datetime(daily["day"])

    universe = sorted(set(anchor.index[anchor != 0]) | set(ev["item_code"]))
    S = pd.DataFrame(index=pd.Index(universe, name="item_code"))
    S["stock_now"] = anchor.reindex(S.index).fillna(0.0)
    S["committed"] = (committed.reindex(S.index).fillna(0.0) if committed is not None else 0.0)
    S["available"] = (S["stock_now"] - S["committed"]).clip(lower=0)
    for c in ["item_name", "foreign_name", "zb_name_ar", "items_group_code", "piece_barcode", "spu", "u_proprt2", "u_proprt3", "u_proprt4", "price_l1", "price_l2"]:
        S[c] = prod[c].reindex(S.index) if c in prod.columns else np.nan
    S["brand"] = S["items_group_code"].map(lambda x: brand.get(int(x)) if (brand is not None and pd.notna(x)) else None)
    S["name_ar"] = S["zb_name_ar"].fillna(S["foreign_name"]).fillna(S["item_name"])

    sales = ev[ev["kind"] == "sale"]; rets = ev[ev["kind"] == "return"]; tin = ev[ev["kind"].isin(["transfer_in", "grpo", "gen_entry"])]; tout = ev[ev["kind"].isin(["transfer_out", "gen_exit"])]
    g = lambda df, col="qty", f="sum": df.groupby("item_code")[col].agg(f)
    S["sold_units"] = (-g(sales)).reindex(S.index).fillna(0.0)
    S["sale_lines"] = g(sales, "qty", "count").reindex(S.index).fillna(0).astype(int)
    S["return_units"] = g(rets).reindex(S.index).fillna(0.0)
    S["transfer_in_units"] = g(tin).reindex(S.index).fillna(0.0)
    S["transfer_out_units"] = (-g(tout)).reindex(S.index).fillna(0.0)
    S["opening_units"] = (g(tin[tin["day"] <= open_date + pd.Timedelta(days=7)]).reindex(S.index).fillna(0.0) if open_date is not None else 0.0)
    S["n_events"] = g(ev, "qty", "count").reindex(S.index).fillna(0).astype(int)
    S["last_sale_day"] = g(sales, "day", "max").reindex(S.index)
    S["last_move_day"] = g(ev, "day", "max").reindex(S.index)
    S["days_since_last_move"] = (today - S["last_move_day"]).dt.days
    d = daily[daily["day"] >= start]
    S["instock_days"] = d[d["eod_lenient"] > 0].groupby("item_code")["day"].count().reindex(S.index).fillna(0).astype(int)
    last_sale = S["last_sale_day"].fillna(start - pd.Timedelta(days=1))
    dd = d.merge(last_sale.rename("ls"), left_on="item_code", right_index=True)
    S["zero_streak_instock_days"] = dd[(dd["day"] > dd["ls"]) & (dd["eod_lenient"] > 0)].groupby("item_code")["day"].count().reindex(S.index).fillna(0).astype(int)
    # ---- layer 1 ----
    S["NEG_STOCK"] = (S["stock_now"] < 0).astype(int)
    saz_def = bal_l[(bal_l["kind"] == "sale") & (bal_l["before"] <= 0)]; saz_pos = bal_c[(bal_c["kind"] == "sale") & (bal_c["before"] <= 0)]
    S["sold_at_zero_def_lines"] = g(saz_def, "qty", "count").reindex(S.index).fillna(0).astype(int)
    S["sold_at_zero_def_units"] = (-g(saz_def)).reindex(S.index).fillna(0.0)
    S["sold_at_zero_pos_lines"] = g(saz_pos, "qty", "count").reindex(S.index).fillna(0).astype(int)
    S["min_balance"] = bal_l.groupby("item_code")["before"].min().reindex(S.index)
    S["SOLD_AT_ZERO"] = (S["sold_at_zero_def_lines"] > 0).astype(int)
    S["SOLD_AT_ZERO_POSSIBLE"] = ((S["sold_at_zero_pos_lines"] > 0) & (S["SOLD_AT_ZERO"] == 0)).astype(int)
    S["IMPLIED_NEG"] = (S["min_balance"] < 0).astype(int)
    S["FRACTIONAL"] = ((S["stock_now"] % 1).abs() > 1e-6).astype(int)
    sday = sales.groupby(["item_code", "day"])["qty"].sum().mul(-1).rename("sold_that_day")
    inb = bal_l[bal_l["kind"].isin(["transfer_in", "gen_entry", "grpo"])].merge(sday, left_on=["item_code", "day"], right_index=True, how="inner")
    # small paper inbound (<=3 units, not more than that day's sales) landing on a zero balance, followed by a sale the same day — outside the opening week
    not_opening = (inb["day"] > open_date + pd.Timedelta(days=7)) if open_date is not None else True
    fix = inb[(inb["qty"] <= 3) & (inb["qty"] <= inb["sold_that_day"]) & (inb["before"] <= 0) & not_opening]
    S["fix_to_sell_events"] = fix.groupby("item_code")["qty"].count().reindex(S.index).fillna(0).astype(int)
    S["FIX_TO_SELL"] = (S["fix_to_sell_events"] > 0).astype(int)
    rt = bal_l[bal_l["kind"] == "return"].merge(sday, left_on=["item_code", "day"], right_index=True, how="inner"); rt = rt[rt["before"] <= 0]
    S["RETURN_THEN_SALE"] = S.index.isin(rt["item_code"]).astype(int)
    S["receive_gap_units"] = 0.0; S["open_request_units"] = 0.0
    if transfer_requests is not None and len(transfer_requests):
        trin = transfer_requests[transfer_requests["to_warehouse"] == wh].copy()
        trin["app_recv"] = trin["actual_received_quantity"].fillna(0.0); trin["app_sent"] = trin["sent_quantity"].fillna(0.0)
        gap = trin[(trin["app_recv"] > 0) | (trin["app_sent"] > 0)]
        gap = gap.assign(gap_recv=lambda x: x["app_recv"] - np.where(x["app_sent"] > 0, x["app_sent"], x["quantity"]))
        S["receive_gap_units"] = gap[gap["gap_recv"].abs() >= 1].groupby("item_code")["gap_recv"].sum().reindex(S.index).fillna(0.0)
        openreq = trin[trin["internal_status"].isin(["New", "Shipped", "Partially Received"]) & (pd.to_datetime(trin["doc_date"]) < today - pd.Timedelta(days=14)) & (pd.to_datetime(trin["doc_date"]) <= today)]
        S["open_request_units"] = openreq.groupby("item_code")["quantity"].sum().reindex(S.index).fillna(0.0)
    S["RECEIVE_GAP"] = (S["receive_gap_units"].abs() >= 1).astype(int)
    S["OPEN_TRANSFER"] = (S["open_request_units"] > 0).astype(int)
    S["uninvoiced_online_units"] = 0.0
    if online is not None and len(online):
        sd = sales.assign(d=sales["day"].dt.strftime("%Y-%m-%d")).groupby(["item_code", "d"])["qty"].sum().mul(-1)
        on = online.copy(); on["sold_same_day"] = [sd.get((i, dd_), 0.0) for i, dd_ in zip(on["item_code"], on["d"])]
        S["uninvoiced_online_units"] = on[on["sold_same_day"] < on["quantity"]].groupby("item_code")["quantity"].sum().reindex(S.index).fillna(0.0)
    S["UNINVOICED_ONLINE"] = (S["uninvoiced_online_units"] > 0).astype(int)
    # ---- layer 2 ----
    net = peer_sales.copy(); net["day"] = pd.to_datetime(net["day"])
    net = net[(net["day"] > today - pd.Timedelta(days=90)) & (net["day"] <= today)]
    own_window_days = max(1, min(90, (today - start).days))
    own_rate_total = (-sales.loc[sales["day"] > today - pd.Timedelta(days=90), "qty"].sum()) / own_window_days
    peer_tot = net.groupby("warehouse_code")["qty"].sum() / 90.0
    scale = float(own_rate_total / peer_tot.mean()) if len(peer_tot) and peer_tot.mean() > 0 else 1.0
    pi = net.groupby(["item_code", "warehouse_code"])["qty"].sum() / 90.0
    S["lam_net"] = (pi.groupby("item_code").mean() * scale).reindex(S.index).fillna(0.0)
    S["peers_selling"] = pi.groupby("item_code").count().reindex(S.index).fillna(0).astype(int)
    alpha = 2.0
    own_days_in = S["instock_days"].clip(lower=1)
    prior_days = np.nan_to_num(np.where(S["lam_net"] > 0, alpha / S["lam_net"].replace(0, np.nan), 0.0), nan=0.0)
    S["lam_own"] = S["sold_units"] / own_days_in
    S["lam_blend"] = (S["sold_units"] + alpha * (S["lam_net"] > 0)) / (own_days_in + prior_days)
    S.loc[(S["lam_net"] <= 0) & (S["sold_units"] <= 0), "lam_blend"] = 0.0
    S["p_zero"] = np.exp(-S["lam_blend"] * S["zero_streak_instock_days"])
    S["expected_sales_in_streak"] = S["lam_blend"] * S["zero_streak_instock_days"]
    S["POISSON_ZERO"] = ((S["stock_now"] >= 1) & (S["zero_streak_instock_days"] >= 7) & (S["p_zero"] < 0.05)).astype(int)
    S["POISSON_ZERO_STRONG"] = ((S["POISSON_ZERO"] == 1) & (S["p_zero"] < 0.005)).astype(int)
    def win(df, lo, hi):
        m = (df["day"] > today - pd.Timedelta(days=hi)) & (df["day"] <= today - pd.Timedelta(days=lo)); return df[m].groupby("item_code")["qty"].sum()
    own28 = (-win(sales, 0, 28)).reindex(S.index).fillna(0.0); own56 = (-win(sales, 28, 56)).reindex(S.index).fillna(0.0)
    n28 = win(net, 0, 28).reindex(S.index).fillna(0.0); n56 = win(net, 28, 56).reindex(S.index).fillna(0.0)
    own_ratio = own28 / own56.replace(0, np.nan); net_ratio = n28 / n56.replace(0, np.nan)
    S["vel_ratio_own"] = own_ratio; S["vel_ratio_net"] = net_ratio
    rel = own_ratio / net_ratio.replace(0, np.nan)
    S["VELOCITY_DROP"] = ((own56 >= 5) & (S["stock_now"] >= 3) & (rel.fillna(own_ratio) < 0.4)).astype(int)
    S["family"] = [family_key(b, p3, p4, n) for b, p3, p4, n in zip(S["items_group_code"], S["u_proprt3"], S["u_proprt4"], S["item_name"].fillna(""))]
    S["family_size"] = S.groupby("family")["stock_now"].transform("count")
    S["over_sell"] = (S["lam_own"] / S["lam_net"].replace(0, np.nan)).fillna(0.0)
    fam = S.groupby("family")
    has_phantom = fam["POISSON_ZERO"].transform("max") == 1
    hot = ((S["SOLD_AT_ZERO"] == 1) | (S["SOLD_AT_ZERO_POSSIBLE"] == 1) | (S["over_sell"] > 2.5)).astype(int)
    has_hot = hot.groupby(S["family"]).transform("max") == 1
    S["SIBLING_SUB"] = ((S["family_size"] >= 2) & has_phantom & has_hot & ((S["POISSON_ZERO"] == 1) | (hot == 1))).astype(int)
    # ---- layer 3 ----
    S["HIGH_TXN"] = (S["n_events"] >= S["n_events"].quantile(0.9)).astype(int)
    op = S.loc[S["opening_units"] > 0, "opening_units"]
    S["OPENING_BULK"] = ((S["opening_units"] >= op.quantile(0.9)) if len(op) else False).astype(int) if open_date is not None else 0
    S["carton_barcode"] = ((bars["n_uom_barcodes"].reindex(S.index).fillna(1) > 1).astype(int) if bars is not None else 0)
    if sitems is not None:
        S["sales_uom_is_carton"] = (sitems["DefaultSalesUoMEntry"].reindex(S.index) != sitems["InventoryUoMEntry"].reindex(S.index)).fillna(False).astype(int)
        S["BOM_ITEM"] = (sitems["TreeType"].reindex(S.index).fillna("iNotATree") != "iNotATree").astype(int)
        S["batch_managed"] = (sitems["ManageBatchNumbers"].reindex(S.index) == "tYES").astype(int)
    else:
        S["sales_uom_is_carton"] = 0; S["BOM_ITEM"] = 0; S["batch_managed"] = 0
    S["MULTIPACK"] = ((S["spu"].fillna(1) > 1) & ((S["carton_barcode"] == 1) | (S["sales_uom_is_carton"] == 1))).astype(int)
    S["BIG_FAMILY"] = (S["family_size"] >= 4).astype(int)
    S["return_rate"] = S["return_units"] / S["sold_units"].replace(0, np.nan)
    S["HIGH_RETURNS"] = ((S["return_units"] >= 2) & (S["return_rate"] > 0.1)).astype(int)
    S["expired_units"] = np.nan; S["near_expiry_units"] = np.nan
    if batches is not None and len(batches):
        b = batches.copy(); b["exp"] = pd.to_datetime(b["ExpiryDate"].astype(str).str.slice(0, 8), format="%Y%m%d", errors="coerce"); b["Quantity"] = pd.to_numeric(b["Quantity"], errors="coerce").fillna(0.0)
        S["expired_units"] = b[(b["exp"] < today) & (b["Quantity"] > 0)].groupby("item_code")["Quantity"].sum().reindex(S.index).fillna(0.0)
        S["near_expiry_units"] = b[(b["exp"] >= today) & (b["exp"] < today + pd.Timedelta(days=60)) & (b["Quantity"] > 0)].groupby("item_code")["Quantity"].sum().reindex(S.index).fillna(0.0)
    S["EXPIRED_ON_HAND"] = (S["expired_units"].fillna(0) > 0).astype(int); S["NEAR_EXPIRY"] = (S["near_expiry_units"].fillna(0) > 0).astype(int)
    S["adj_count"] = (adj_history.reindex(S.index).fillna(0) if adj_history is not None else 0)
    S["ADJ_HISTORY"] = (S["adj_count"] > 0).astype(int)
    # ---- layer 4 ----
    S["cover_days"] = S["available"] / S["lam_blend"].replace(0, np.nan)
    S["OVERCOVER"] = ((S["available"] >= 6) & (S["cover_days"].fillna(9999) > 180)).astype(int)
    S["OFF_RANGE"] = ((S["stock_now"] > 0) & (S["sold_units"] <= 0) & (S["lam_net"] > 0)).astype(int)
    S["unit_cost"] = (unit_cost.reindex(S.index) if unit_cost is not None else pd.Series(np.nan, index=S.index))
    S["unit_cost"] = S["unit_cost"].fillna(S["price_l1"] * 0.75).fillna(S["price_l2"] * 0.6).fillna(0.0)
    S["stock_value"] = S["stock_now"] * S["unit_cost"]
    S["HIGH_VALUE"] = (S["unit_cost"] >= S["unit_cost"].quantile(0.9)).astype(int)
    # ---- score & tiers ----
    S["score"] = sum(S[k] * w for k, w in W.items() if k in S.columns)
    S["tier"] = np.where(S[L1].sum(axis=1) > 0, "مؤكد", np.where(S[L2].sum(axis=1) > 0, "مرجّح", np.where(S["score"] >= 1.5, "احترازي", "منخفض")))
    S["reason_codes"] = S[CODES].apply(lambda r: "|".join([c for c in CODES if r[c] == 1]), axis=1)
    exp_abs = np.where(S["POISSON_ZERO"] == 1, S["stock_now"] * (1 - S["p_zero"]), 0.0)
    exp_abs = np.maximum(exp_abs, np.where(S["SOLD_AT_ZERO"] == 1, np.maximum(1.0, -S["min_balance"].fillna(0)), 0.0))
    exp_abs = np.maximum(exp_abs, np.where(S["RECEIVE_GAP"] == 1, S["receive_gap_units"].abs(), 0.0))
    exp_abs = np.maximum(exp_abs, np.where(S["EXPIRED_ON_HAND"] == 1, S["expired_units"].fillna(0), 0.0))
    exp_abs = np.maximum(exp_abs, np.minimum(1.0, S["score"] / 10.0))
    S["expected_abs_var"] = exp_abs; S["expected_var_value"] = S["expected_abs_var"] * S["unit_cost"]
    S = S.sort_values(["score", "expected_var_value"], ascending=False); S["rank"] = np.arange(1, len(S) + 1)
    S.attrs["peer_scale"] = scale; S.attrs["own_rate_total"] = float(own_rate_total)
    return S
