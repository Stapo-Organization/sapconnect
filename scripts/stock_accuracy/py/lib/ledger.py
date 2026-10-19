"""Daily on-hand reconstruction for one warehouse, backwards from a live SAP anchor (T0).

Sign convention: qty > 0 increases the warehouse on-hand.
Events without a time of day (StockTransfers, GRPO, postings) get two placements:
  lenient      → inbound at 00:00:00 / outbound at 23:59:58 (movement happened before that day's sales)
  conservative → inbound at 23:59:59 / outbound at 00:00:00 (movement happened after that day's sales)
"""
from __future__ import annotations
import pandas as pd, numpy as np

def _ts(date_s: pd.Series, time_s: pd.Series | None, default: str) -> pd.Series:
    d = pd.to_datetime(date_s.astype(str).str.slice(0, 10), errors="coerce")
    if time_s is None:
        return d + pd.to_timedelta(default)
    t = time_s.fillna("").astype(str).str.strip()
    t = t.where(t.str.match(r"^\d{1,2}:\d{2}(:\d{2})?$"), default)
    t = t.where(t.str.count(":") == 2, t + ":00")
    return d + pd.to_timedelta(t)

def build_events(con, wh: str, bridge_date: str | None, t0: pd.Timestamp) -> pd.DataFrame:
    ev = []
    tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
    # --- sales (mirror) ---
    inv = con.execute("SELECT doc_num, card_code, doc_date, doc_time, item_code, quantity, cancelled FROM db_invoice_lines WHERE warehouse_code = ?", [wh]).fetchdf()
    inv = inv[inv["cancelled"].fillna("N") != "Y"]
    if bridge_date:
        inv = inv[inv["doc_date"].astype(str) < bridge_date]
    ev.append(pd.DataFrame({"item_code": inv["item_code"], "ts": _ts(inv["doc_date"], inv["doc_time"], "12:00:00"), "has_time": inv["doc_time"].notna(),
                            "qty": -inv["quantity"].astype(float), "kind": "sale", "ref": "INV " + inv["doc_num"].astype(str), "card": inv["card_code"]}))
    # --- sales bridge from SAP (DocDate >= bridge_date), InventoryQuantity ---
    if bridge_date and "sap_invoices_sap_l" in tables:
        s = con.execute("""SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity FROM sap_invoices_sap_l
                           WHERE WarehouseCode = ? AND substr(h_DocDate,1,10) >= ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'""", [wh, bridge_date]).fetchdf()
        if len(s):
            q = pd.to_numeric(s["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(s["Quantity"], errors="coerce"))
            ev.append(pd.DataFrame({"item_code": s["ItemCode"], "ts": _ts(s["h_DocDate"], s["h_DocTime"], "12:00:00"), "has_time": True,
                                    "qty": -q, "kind": "sale", "ref": "INV " + s["h_DocNum"].astype(str), "card": s["h_CardCode"]}))
    # --- returns: prefer SAP credit notes (time + base refs), else mirror ---
    if "sap_credit_notes_sap_l" in tables:
        c = con.execute("""SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity FROM sap_credit_notes_sap_l
                           WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'""", [wh]).fetchdf()
        q = pd.to_numeric(c["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(c["Quantity"], errors="coerce"))
        ev.append(pd.DataFrame({"item_code": c["ItemCode"], "ts": _ts(c["h_DocDate"], c["h_DocTime"], "12:00:00"), "has_time": True,
                                "qty": q, "kind": "return", "ref": "CM " + c["h_DocNum"].astype(str), "card": c["h_CardCode"]}))
    else:
        c = con.execute("SELECT doc_num, card_code, doc_date, item_code, quantity, cancelled FROM db_credit_memo_lines WHERE warehouse_code = ?", [wh]).fetchdf()
        c = c[c["cancelled"].fillna("N") != "Y"]
        ev.append(pd.DataFrame({"item_code": c["item_code"], "ts": _ts(c["doc_date"], None, "12:00:00"), "has_time": False,
                                "qty": c["quantity"].astype(float), "kind": "return", "ref": "CM " + c["doc_num"].astype(str), "card": c["card_code"]}))
    # --- stock transfers (OWTR), no time of day ---
    for t in [t for t in tables if t.startswith("sap_stock_transfers_") and t.endswith("_l")]:
        x = con.execute(f"""SELECT h_DocNum, h_DocDate, ItemCode, Quantity, InventoryQuantity, WarehouseCode, FromWarehouseCode FROM {t}
                            WHERE WarehouseCode = ? OR FromWarehouseCode = ?""", [wh, wh]).fetchdf()
        if not len(x): continue
        q = pd.to_numeric(x["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(x["Quantity"], errors="coerce"))
        sign = np.where(x["WarehouseCode"] == wh, 1.0, 0.0) - np.where(x["FromWarehouseCode"] == wh, 1.0, 0.0)
        other = np.where(x["WarehouseCode"] == wh, x["FromWarehouseCode"], x["WarehouseCode"])
        e = pd.DataFrame({"item_code": x["ItemCode"], "ts": _ts(x["h_DocDate"], None, "00:00:00"), "has_time": False, "qty": q * sign,
                          "kind": np.where(sign > 0, "transfer_in", "transfer_out"), "ref": "WTR " + x["h_DocNum"].astype(str) + " " + pd.Series(other).astype(str), "card": None})
        ev.append(e[e["qty"] != 0])
    # --- goods receipts / issues ---
    for t, sgn, kind in [("sap_gen_entries_l", 1.0, "gen_entry"), ("sap_gen_exits_l", -1.0, "gen_exit")]:
        if t in tables:
            g = con.execute(f"SELECT h_DocNum, h_DocDate, h_DocTime, h_Comments, ItemCode, Quantity, InventoryQuantity FROM {t} WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'", [wh]).fetchdf()
            if len(g):
                q = pd.to_numeric(g["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(g["Quantity"], errors="coerce"))
                ev.append(pd.DataFrame({"item_code": g["ItemCode"], "ts": _ts(g["h_DocDate"], g["h_DocTime"], "12:00:00"), "has_time": g["h_DocTime"].notna(),
                                        "qty": sgn * q, "kind": kind, "ref": kind.upper() + " " + g["h_DocNum"].astype(str) + " " + g["h_Comments"].fillna("").astype(str), "card": None}))
    # --- GRPO direct (mirror) ---
    gr = con.execute("SELECT doc_num, doc_date, item_code, inventory_quantity FROM db_grpo_lines_all WHERE warehouse_code = ?", [wh]).fetchdf()
    if len(gr):
        ev.append(pd.DataFrame({"item_code": gr["item_code"], "ts": _ts(gr["doc_date"], None, "00:00:00"), "has_time": False,
                                "qty": gr["inventory_quantity"].astype(float), "kind": "grpo", "ref": "GRPO " + gr["doc_num"].astype(str), "card": None}))
    # --- inventory postings = signed variance ---
    for t in [t for t in tables if t.startswith("sap_inventory_postings_docs") and t.endswith("_l")]:
        p = con.execute(f"SELECT h_DocumentNumber, h_PostingDate, ItemCode, Variance FROM {t} WHERE WarehouseCode = ?", [wh]).fetchdf()
        if len(p):
            ev.append(pd.DataFrame({"item_code": p["ItemCode"], "ts": _ts(p["h_PostingDate"], None, "23:00:00"), "has_time": False,
                                    "qty": pd.to_numeric(p["Variance"], errors="coerce").fillna(0.0), "kind": "posting", "ref": "IQR " + p["h_DocumentNumber"].astype(str), "card": None}))
    events = pd.concat(ev, ignore_index=True)
    events = events[events["ts"].notna() & (events["ts"] <= t0)].copy()
    day = events["ts"].dt.normalize()
    timed = events["has_time"].astype(bool).values
    pos = (events["qty"] > 0).values
    events["ts_lenient"] = pd.to_datetime(np.where(timed, events["ts"].values, np.where(pos, day.values, (day + pd.Timedelta("23:59:58")).values)))
    events["ts_conservative"] = pd.to_datetime(np.where(timed, events["ts"].values, np.where(pos, (day + pd.Timedelta("23:59:59")).values, day.values)))
    events["day"] = day
    return events.sort_values(["item_code", "ts"]).reset_index(drop=True)

def balances(events: pd.DataFrame, anchor: pd.Series, variant: str) -> pd.DataFrame:
    """Per event: on-hand before/after under a time placement. anchor: item_code → InStock at T0."""
    col = f"ts_{variant}"
    tb = -np.sign(events["qty"]) if variant == "lenient" else np.sign(events["qty"])
    df = events.assign(_tb=tb).sort_values(["item_code", col, "_tb"]).copy()
    cum = df.groupby("item_code")["qty"].cumsum()
    tot = df.groupby("item_code")["qty"].transform("sum")
    a = df["item_code"].map(anchor).fillna(0.0)
    df["after"] = a - (tot - cum)
    df["before"] = df["after"] - df["qty"]
    return df.drop(columns=["_tb"])

def onhand_at(events: pd.DataFrame, anchor: pd.Series, when: pd.Timestamp, variant: str, items: pd.Index) -> pd.Series:
    """On-hand just after instant `when` (events with ts <= when applied)."""
    later = events[events[f"ts_{variant}"] > when].groupby("item_code")["qty"].sum()
    return anchor.reindex(items).fillna(0.0) - later.reindex(items).fillna(0.0)

def daily_series(events: pd.DataFrame, anchor: pd.Series, start: pd.Timestamp, t0: pd.Timestamp, variant: str):
    """(eod on-hand per item×day, net movement per item×day) for start..t0."""
    col = f"ts_{variant}"
    items = pd.Index(sorted(set(events["item_code"]) | set(anchor.index)))
    days = pd.date_range(start.normalize(), t0.normalize(), freq="D")
    ev = events.copy(); ev["d"] = ev[col].dt.normalize()
    daily = ev.pivot_table(index="item_code", columns="d", values="qty", aggfunc="sum", fill_value=0.0).reindex(index=items, columns=days, fill_value=0.0)
    rev_cum = daily.iloc[:, ::-1].cumsum(axis=1).iloc[:, ::-1]      # Σ qty on days >= d
    later = rev_cum - daily                                            # Σ qty on days > d
    eod = pd.DataFrame(anchor.reindex(items).fillna(0.0).values[:, None] - later.values, index=items, columns=days)
    return eod, daily


def build_events_sap(con, wh: str, until: pd.Timestamp, since: pd.Timestamp, suffix_inv="invoices_2025h2", suffix_cn="credit_notes_2025h2_2026h1",
                     suffix_tr="stock_transfers_2025h2", suffix_dn="delivery_notes_2025h2", suffix_rt="returns_2025h2",
                     suffix_ge="gen_entries_2025h2_2026h1", suffix_gx="gen_exits_2025h2_2026h1") -> pd.DataFrame:
    """Events for warehouse `wh` in [since, until] from the SAP document pulls (used for the historical backtest)."""
    tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
    ev = []
    def lines(name):
        t = f"sap_{name}_l"
        return t if t in tables else None
    if (t := lines(suffix_inv)):
        s = con.execute(f"""SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity, BaseType FROM {t}
                            WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES' AND coalesce(CAST(BaseType AS VARCHAR),'-1') <> '15'""", [wh]).fetchdf()
        q = pd.to_numeric(s["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(s["Quantity"], errors="coerce"))
        ev.append(pd.DataFrame({"item_code": s["ItemCode"], "ts": _ts(s["h_DocDate"], s["h_DocTime"], "12:00:00"), "has_time": True, "qty": -q, "kind": "sale", "ref": "INV " + s["h_DocNum"].astype(str), "card": s["h_CardCode"]}))
    if (t := lines(suffix_dn)):
        s = con.execute(f"SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity FROM {t} WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'", [wh]).fetchdf()
        if len(s):
            q = pd.to_numeric(s["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(s["Quantity"], errors="coerce"))
            ev.append(pd.DataFrame({"item_code": s["ItemCode"], "ts": _ts(s["h_DocDate"], s["h_DocTime"], "12:00:00"), "has_time": True, "qty": -q, "kind": "sale", "ref": "DLN " + s["h_DocNum"].astype(str), "card": s["h_CardCode"]}))
    if (t := lines(suffix_cn)):
        c = con.execute(f"""SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity FROM {t}
                            WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES' AND coalesce(CAST(BaseType AS VARCHAR),'-1') <> '16'""", [wh]).fetchdf()
        if len(c):
            q = pd.to_numeric(c["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(c["Quantity"], errors="coerce"))
            ev.append(pd.DataFrame({"item_code": c["ItemCode"], "ts": _ts(c["h_DocDate"], c["h_DocTime"], "12:00:00"), "has_time": True, "qty": q, "kind": "return", "ref": "CM " + c["h_DocNum"].astype(str), "card": c["h_CardCode"]}))
    if (t := lines(suffix_rt)):
        c = con.execute(f"SELECT h_DocNum, h_DocDate, h_DocTime, h_CardCode, ItemCode, Quantity, InventoryQuantity FROM {t} WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'", [wh]).fetchdf()
        if len(c):
            q = pd.to_numeric(c["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(c["Quantity"], errors="coerce"))
            ev.append(pd.DataFrame({"item_code": c["ItemCode"], "ts": _ts(c["h_DocDate"], c["h_DocTime"], "12:00:00"), "has_time": True, "qty": q, "kind": "return", "ref": "RTN " + c["h_DocNum"].astype(str), "card": c["h_CardCode"]}))
    if (t := lines(suffix_tr)):
        x = con.execute(f"SELECT h_DocNum, h_DocDate, ItemCode, Quantity, InventoryQuantity, WarehouseCode, FromWarehouseCode FROM {t} WHERE WarehouseCode = ? OR FromWarehouseCode = ?", [wh, wh]).fetchdf()
        if len(x):
            q = pd.to_numeric(x["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(x["Quantity"], errors="coerce"))
            sign = np.where(x["WarehouseCode"] == wh, 1.0, 0.0) - np.where(x["FromWarehouseCode"] == wh, 1.0, 0.0)
            other = np.where(x["WarehouseCode"] == wh, x["FromWarehouseCode"], x["WarehouseCode"])
            e = pd.DataFrame({"item_code": x["ItemCode"], "ts": _ts(x["h_DocDate"], None, "00:00:00"), "has_time": False, "qty": q * sign, "kind": np.where(sign > 0, "transfer_in", "transfer_out"), "ref": "WTR " + x["h_DocNum"].astype(str) + " " + pd.Series(other).astype(str), "card": None})
            ev.append(e[e["qty"] != 0])
    for name, sgn, kind in [(suffix_ge, 1.0, "gen_entry"), (suffix_gx, -1.0, "gen_exit")]:
        if (t := lines(name)):
            g = con.execute(f"SELECT h_DocNum, h_DocDate, h_DocTime, h_Comments, ItemCode, Quantity, InventoryQuantity FROM {t} WHERE WarehouseCode = ? AND coalesce(h_Cancelled,'tNO') <> 'tYES'", [wh]).fetchdf()
            if len(g):
                q = pd.to_numeric(g["InventoryQuantity"], errors="coerce").fillna(pd.to_numeric(g["Quantity"], errors="coerce"))
                ev.append(pd.DataFrame({"item_code": g["ItemCode"], "ts": _ts(g["h_DocDate"], g["h_DocTime"], "12:00:00"), "has_time": g["h_DocTime"].notna(), "qty": sgn * q, "kind": kind, "ref": kind.upper() + " " + g["h_DocNum"].astype(str), "card": None}))
    gr = con.execute("SELECT doc_num, doc_date, item_code, inventory_quantity FROM db_grpo_lines_all WHERE warehouse_code = ?", [wh]).fetchdf()
    if len(gr):
        ev.append(pd.DataFrame({"item_code": gr["item_code"], "ts": _ts(gr["doc_date"], None, "00:00:00"), "has_time": False, "qty": gr["inventory_quantity"].astype(float), "kind": "grpo", "ref": "GRPO " + gr["doc_num"].astype(str), "card": None}))
    if not ev:
        return pd.DataFrame(columns=["item_code", "ts", "has_time", "qty", "kind", "ref", "card", "ts_lenient", "ts_conservative", "day"])
    events = pd.concat(ev, ignore_index=True)
    events = events[events["ts"].notna() & (events["ts"] <= until) & (events["ts"] >= since)].copy()
    day = events["ts"].dt.normalize(); timed = events["has_time"].astype(bool).values; pos = (events["qty"] > 0).values
    events["ts_lenient"] = pd.to_datetime(np.where(timed, events["ts"].values, np.where(pos, day.values, (day + pd.Timedelta("23:59:58")).values)))
    events["ts_conservative"] = pd.to_datetime(np.where(timed, events["ts"].values, np.where(pos, (day + pd.Timedelta("23:59:59")).values, day.values)))
    events["day"] = day
    return events.sort_values(["item_code", "ts"]).reset_index(drop=True)
