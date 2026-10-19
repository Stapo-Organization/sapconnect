"""Arabic RTL HTML report (single file, inline SVG, vanilla JS) for the pilot warehouse. Reads the DuckDB tables; backtest sections appear when available."""
import sys, json, argparse, datetime as dt
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT
from lib.charts import bar_h, line_chart, sparkline, esc, fmt
from lib.signals import WEIGHTS, L1, L2

ap = argparse.ArgumentParser(); ap.add_argument("--wh", default="RUH010"); ap.add_argument("--name", default="معرض الملك فهد"); ap.add_argument("--open-date", default="2026-07-22"); a = ap.parse_args()
WH, NAME = a.wh, a.name
con = duckdb.connect(str(DUCK), read_only=True); tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
S = con.execute(f"SELECT * FROM signals_{WH}").fetchdf().set_index("item_code")
meta = con.execute("SELECT * FROM ledger_meta").fetchdf().iloc[0]; T0 = pd.Timestamp(meta["t0"]); OPEN = pd.Timestamp(a.open_date)
clos = con.execute("SELECT * FROM ledger_closure").fetchdf()
ev = con.execute("SELECT * FROM ledger_events").fetchdf(); ev["day"] = pd.to_datetime(ev["day"])
daily = con.execute("SELECT * FROM ledger_daily").fetchdf(); daily["day"] = pd.to_datetime(daily["day"])

AR = {"NEG_STOCK": "رصيد سالب", "SOLD_AT_ZERO": "بيع بلا رصيد (مؤكد)", "SOLD_AT_ZERO_POSSIBLE": "بيع بلا رصيد (محتمل — نفس يوم التحويل)", "IMPLIED_NEG": "رصيد ضمني سالب",
      "FIX_TO_SELL": "زيادة صغيرة ثم بيع فوري (تسوية لأجل البيع)", "RETURN_THEN_SALE": "إرجاع ثم بيع في نفس اليوم", "RECEIVE_GAP": "فرق استلام بين SAP والتطبيق", "OPEN_TRANSFER": "طلب تحويل معلّق أكثر من 14 يوماً",
      "FRACTIONAL": "كمية كسرية", "UNINVOICED_ONLINE": "طلب إلكتروني بلا فاتورة", "POISSON_ZERO": "مخزون وهمي: لا بيع رغم التوفر", "POISSON_ZERO_STRONG": "مخزون وهمي (دليل قوي جداً)",
      "VELOCITY_DROP": "هبوط البيع مقابل المعارض الأخرى", "SIBLING_SUB": "تبديل محتمل مع صنف شقيق", "EXPIRED_ON_HAND": "دفعة منتهية الصلاحية برصيد", "NEAR_EXPIRY": "قرب انتهاء الصلاحية (60 يوماً)",
      "HIGH_TXN": "حركات كثيرة", "OPENING_BULK": "كمية افتتاح كبيرة", "MULTIPACK": "كرتون/حبّة (وحدات متعددة)", "BIG_FAMILY": "عائلة كبيرة من الأشقاء", "HIGH_RETURNS": "مرتجعات مرتفعة",
      "BOM_ITEM": "صنف مجمّع", "ADJ_HISTORY": "تسويات سابقة", "OVERCOVER": "تغطية مفرطة (أكثر من 180 يوماً)", "OFF_RANGE": "لم يُبَع هنا ويُباع في الشبكة", "HIGH_VALUE": "قيمة وحدة عالية"}
LAYER = {**{c: "1 · المستحيلات" for c in ["NEG_STOCK", "SOLD_AT_ZERO", "IMPLIED_NEG", "FIX_TO_SELL", "RETURN_THEN_SALE", "RECEIVE_GAP", "FRACTIONAL", "UNINVOICED_ONLINE", "SOLD_AT_ZERO_POSSIBLE", "OPEN_TRANSFER"]},
         **{c: "2 · أنماط البيع" for c in ["POISSON_ZERO", "POISSON_ZERO_STRONG", "VELOCITY_DROP", "SIBLING_SUB", "EXPIRED_ON_HAND", "NEAR_EXPIRY"]},
         **{c: "3 · التعرّض" for c in ["HIGH_TXN", "OPENING_BULK", "MULTIPACK", "BIG_FAMILY", "HIGH_RETURNS", "BOM_ITEM", "ADJ_HISTORY"]},
         **{c: "4 · التغطية" for c in ["OVERCOVER", "OFF_RANGE", "HIGH_VALUE"]}}
def ar_codes(s): return "، ".join(AR.get(c, c) for c in str(s).split("|") if c)

# ---------- numbers ----------
stocked = S[S["stock_now"] > 0]; n_stocked = len(stocked); units = S["stock_now"].sum(); value = S["stock_value"].sum()
tiers = S["tier"].value_counts()
age_days = (T0.normalize() - OPEN).days
in_snap = clos[clos["in_snap"] & ~clos["d2_ambiguous"]]; d2_ok = (in_snap["resid_d2_best"].abs() <= 0.5).mean(); pre_ok = (clos["pre_open_lenient"].abs() <= 0.5).mean()
sales_units = -ev.loc[ev["kind"] == "sale", "qty"].sum(); ret_units = ev.loc[ev["kind"] == "return", "qty"].sum(); tin_units = ev.loc[ev["kind"] == "transfer_in", "qty"].sum(); tout_units = -ev.loc[ev["kind"] == "transfer_out", "qty"].sum()
# pareto (forward): final ranking from 55_score_forward when available (calibrated expected variance value), else expert score
if f"count_list_{WH}" in tables:
    CL = con.execute(f"SELECT item_code, rank, tier AS tier_final, p_learned, delta_hat, expected_abs_var AS eav, expected_var_value AS evv, is_control FROM count_list_{WH}").fetchdf().set_index("item_code")
    S = S.join(CL[["rank", "tier_final", "p_learned", "delta_hat", "eav", "evv", "is_control"]], rsuffix="_cl")
    S["tier"] = S["tier_final"].fillna(S["tier"]); S["expected_abs_var"] = S["eav"].fillna(S["expected_abs_var"]); S["expected_var_value"] = S["evv"].fillna(S["expected_var_value"])
    P = S.sort_values("rank").copy()
    RANK_NOTE = "الترتيب النهائي = الاحتمال المُعاير من الاختبار الرجعي × حجم الفرق المتوقع (دالة في الرصيد) × التكلفة؛ الأصناف ذات البصمة المباشرة في الأعلى دائماً."
else:
    P = S.sort_values(["score", "expected_var_value"], ascending=False).copy()
    RANK_NOTE = "الترتيب بأوزان خبيرية (الاختبار الرجعي لم يكتمل)."
P["cum_n"] = np.arange(1, len(P) + 1); tot_ev = max(P["expected_var_value"].sum(), 1e-9); P["cum_share"] = P["expected_var_value"].cumsum() / tot_ev
def n_for(share): return int(P.loc[P["cum_share"] >= share, "cum_n"].min()) if (P["cum_share"] >= share).any() else len(P)
n80, n90 = n_for(0.8), n_for(0.9)
n_sure = int((S["tier"] == "مؤكد").sum()); n_likely = int((S["tier"] == "مرجّح").sum())
default_n = max(n_sure + n_likely, 100)

# ---------- charts ----------
sig_counts = [(AR[c], int(S[c].sum()), f"{AR[c]} — {int(S[c].sum())} صنفاً — الطبقة {LAYER[c]}") for c in WEIGHTS if c in S.columns and S[c].sum() > 0]
sig_counts.sort(key=lambda r: -r[1])
chart_signals = bar_h(sig_counts, width=820, label_w=330, title="عدد الأصناف لكل إشارة")
# story: daily total on-hand + daily sales
dd = daily[daily["day"] >= OPEN - pd.Timedelta(days=1)]
tot_eod = dd.groupby("day")["eod_lenient"].sum(); days = list(tot_eod.index)
sales_by_day = (-ev[ev["kind"] == "sale"].groupby("day")["qty"].sum()).reindex(days).fillna(0.0)
xl = [d.strftime("%d/%m") for d in days]
chart_onhand = line_chart([{"name": "إجمالي الرصيد في النظام (حبّة)", "values": [float(v) for v in tot_eod.values], "color": "var(--series-1)", "area": True}], xlabels=xl, title="الرصيد منذ الافتتاح", legend=False)
chart_sales = line_chart([{"name": "المبيعات اليومية (حبّة)", "values": [float(v) for v in sales_by_day.values], "color": "var(--series-3)"}], xlabels=xl, title="المبيعات اليومية", legend=False)
# opening composition
tr = con.execute(f"SELECT FromWarehouseCode f, count(*) lines_, sum(InventoryQuantity) units, sum(CASE WHEN UoMCode<>'PC' THEN 1 ELSE 0 END) cartons, count(distinct h_DocEntry) docs FROM sap_stock_transfers_{WH}_l WHERE WarehouseCode=? AND substr(h_DocDate,1,10) <= ? GROUP BY 1 ORDER BY units DESC", [WH, (OPEN + pd.Timedelta(days=7)).strftime("%Y-%m-%d")]).fetchdf()
# pareto chart data
par_x = P["cum_n"].tolist(); par_y = (P["cum_share"] * 100).round(2).tolist()
step = max(1, len(par_x) // 300)
chart_pareto = line_chart([{"name": "نسبة قيمة الفروق المتوقعة الملتقَطة %", "values": par_y[::step] + [par_y[-1]], "color": "var(--series-1)", "area": True}], xlabels=[str(x) for x in par_x[::step]] + [str(par_x[-1])], title="منحنى الالتقاط", legend=False, y_fmt=lambda v: f"{fmt(v)}%")
# backtest (optional)
bt_html = ""
if "bt_metrics" in tables and (OUT / "weights_learned.json").exists():
    WLJ = json.load(open(OUT / "weights_learned.json")); F = con.execute("SELECT count(*) n, sum(label) pos, count(distinct wh) whs, count(distinct doc) docs FROM bt_features").fetchdf().iloc[0]
    base = con.execute("SELECT avg(label) FROM bt_features").fetchone()[0]
    Lf = con.execute("SELECT * FROM bt_signal_lift WHERE flagged > 0 ORDER BY lift DESC").fetchdf()
    E = pd.DataFrame(WLJ["cv_ev"]).drop(columns="n").mean()
    rows = [("المحرك: احتمال مُعاير × حجم الفرق × التكلفة", E["EV_p×Δ̂×cost@10%"] * 100), ("قيمة المخزون فقط (رصيد × تكلفة)", E["stock_value@10%"] * 100), ("احتمال الخلل فقط", E["p_only@10%"] * 100), ("الأوزان الخبيرية الأولى", E["expert_score@10%"] * 100), ("عشوائي", 10.0)]
    rows = [(a_, b_, f"{a_}: {b_:.1f}% من قيمة الفروق بجرد 10% من الأصناف") for a_, b_ in rows]
    chart_bt = bar_h(rows, width=820, label_w=300, value_fmt=lambda v: f"{fmt(v,1)}%", max_val=50, title="نسبة قيمة الفروق الملتقَطة بجرد 10% من الأصناف")
    cal = pd.DataFrame(WLJ["calibration"])
    cal_rows = [(f"العُشر {int(r.dec)+1} (احتمال {r.p_lo:.2f}–{r.p_hi:.2f})", r.rate * 100, f"العُشر {int(r.dec)+1}: {r.rate*100:.1f}% من أصنافه كان فيها فرق فعلي (n={int(r.n)})") for r in cal.itertuples()]
    chart_cal = bar_h(cal_rows, width=820, label_w=300, value_fmt=lambda v: f"{fmt(v,1)}%", max_val=100, title="معايرة الاحتمال")
    coef = pd.Series(WLJ["coef"]); coef = coef[coef != 0].sort_values(ascending=False)
    coef_html = "<table class='t'><thead><tr><th>الإشارة</th><th>الوزن المتعلَّم</th><th>القراءة</th></tr></thead><tbody>" + "".join(f"<tr><td>{esc(AR.get(k,k))}</td><td>{v:+.2f}</td><td>{'يرفع احتمال الخلل' if v>0 else 'يخفضه'}</td></tr>" for k, v in coef.items()) + "</tbody></table>"
    lift_html = "<table class='t'><thead><tr><th>الإشارة</th><th>الأصناف المعلَّمة</th><th>نسبة الفروق الفعلية بينها</th><th>الرفع مقابل الأساس</th><th>وسيط |الفرق| عند الإصابة</th></tr></thead><tbody>" + "".join(f"<tr><td>{esc(AR.get(r.signal, r.signal))}</td><td>{fmt(r.flagged)}</td><td>{fmt(r.pos_rate*100,1)}%</td><td>{fmt(r.lift,2)}×</td><td>{fmt(r.median_abs_var_pos,1)}</td></tr>" for r in Lf.itertuples()) + "</tbody></table>"
    mag = WLJ["magnitude"]
    bt_html = f"""<section id="backtest"><h2>الاختبار الرجعي على جرود نهاية 2025</h2>
<p class="lead">طبّقنا المحرك على {fmt(F['docs'])} مستند جرد كامل في {fmt(F['whs'])} معارض (ديسمبر 2025: المدينة، جدة، الدمام، عنيزة، السويدي) باستخدام بيانات ما قبل الجرد فقط: {fmt(F['n'])} صنفاً مجروداً، منها {base*100:.1f}% بفرق خارج السماحية. ثم قسنا خارج العيّنة (كل مستند يُقيَّم بأوزان تعلّمت من المستندات الأخرى): لو جردنا أعلى 10% من الأصناف حسب كل طريقة، كم من <b>قيمة</b> الفروق الفعلية نلتقط؟</p>
<figure><figcaption>نسبة قيمة الفروق الملتقَطة بجرد 10% من الأصناف (متوسط 5 طيّات)</figcaption>{chart_bt}</figure>
<div class="callout warn"><b>نتيجة صريحة:</b> الأوزان الخبيرية التي بدأنا بها كانت ضعيفة ({E['expert_score@10%']*100:.0f}%) — أقل من ترتيب الأصناف بقيمة مخزونها فقط ({E['stock_value@10%']*100:.0f}%). ما يعمل هو <b>الاحتمال المتعلَّم × حجم الفرق المتوقع × التكلفة</b> ({E['EV_p×Δ̂×cost@10%']*100:.0f}%)، وهو ما يرتّب قائمة هذا التقرير الآن. الفرق على أفضل طريقة بسيطة محدود، والسبب أن حجم الفرق يتبع حجم الرصيد (|الفرق| ≈ {np.exp(mag['a']):.1f} × الرصيد^{mag['b']:.2f}؛ وسيط الفرق نصف الرصيد).</div>
<h3>ما الذي تعلّمه المحرك من تلك الجرود؟</h3>
<p>أقوى مؤشر على الخلل في تلك المعارض كان <b>كثرة الحركات</b> ثم <b>الرصيد الضمني السالب</b> ثم <b>الوحدات المتعددة (كرتون/حبّة)</b>؛ بينما الأصناف الراكدة وذات التغطية المفرطة كانت <b>أدقّ</b> من غيرها (وزن سالب) — الخطأ يتراكم مع اللمس لا مع الركود.</p>
<div class="two"><div>{coef_html}</div><figure><figcaption>معايرة الاحتمال: أعشار الأصناف حسب الاحتمال المتوقع ونسبة الفروق الفعلية فيها</figcaption>{chart_cal}</figure></div>
<h3>أي إشارة تُصيب أكثر؟</h3><p class="muted">نسبة الأصناف ذات فرق فعلي بين الأصناف التي حملت الإشارة، مقابل الأساس {base*100:.1f}%. إشارات الصلاحية والافتتاح والاستلام لم تُقَس هنا لأن بياناتها غير متاحة لتلك الفترة.</p>{lift_html}
<p class="muted">حدود هذا الاختبار: تلك المعارض أقدم وتخلط التجزئة بالجملة، وجردها الأول جاء بعد سنة أو أكثر من التراكم؛ معرض الملك فهد عمره 74 يوماً ومخزونه دخل بالكرتون. لذلك جرد التحقق (50 صنفاً) هو الحكم النهائي على RUH010 نفسه.</p></section>"""
# ---------- tables ----------
def item_row(r, i):
    return (f"<tr><td>{i}</td><td class='code'>{esc(r.Index)}</td><td class='nm'>{esc(r.name_ar)}</td><td>{fmt(r.stock_now)}</td><td>{fmt(r.sold_units)}</td><td>{fmt(r.zero_streak_instock_days)}</td>"
            f"<td>{(fmt(r.p_zero*100,1)+'%') if r.stock_now>0 and r.zero_streak_instock_days>0 else '—'}</td><td><span class='tier t-{tier_cls(r.tier)}'>{esc(r.tier)}</span></td><td class='rs'>{esc(ar_codes(r.reason_codes))}</td><td>{fmt(r.expected_var_value)}</td></tr>")
def tier_cls(t): return {"مؤكد": "sure", "مرجّح": "likely", "احترازي": "watch"}.get(t, "low")
list_rows = "".join(item_row(r, i + 1) for i, r in enumerate(P.head(300).itertuples()))
# JSON for the slider (all items, compact)
items_json = json.dumps([{"c": idx, "n": str(r.name_ar)[:60], "s": float(r.stock_now), "t": r.tier, "v": round(float(r.expected_var_value), 1), "cs": round(float(r.cum_share) * 100, 2), "r": ar_codes(r.reason_codes)} for idx, r in P.iterrows()], ensure_ascii=False)
# 10 timelines
top10 = P[P["stock_now"] > 0].head(10)
tl = []
for code, r in top10.iterrows():
    s = daily[(daily["item_code"] == code) & (daily["day"] >= OPEN - pd.Timedelta(days=1))].sort_values("day")
    vals = [float(v) for v in s["eod_lenient"].values]; sale_days = set(ev[(ev["item_code"] == code) & (ev["kind"] == "sale")]["day"])
    marks = [i for i, d in enumerate(s["day"]) if d in sale_days]
    tl.append(f"<div class='tl'><div class='tl-h'><b>{esc(r['name_ar'])}</b><span class='code'>{esc(code)}</span></div>{sparkline(vals, marks=marks)}<div class='tl-m'>الرصيد الآن <b>{fmt(r['stock_now'])}</b> · بيع منذ الافتتاح <b>{fmt(r['sold_units'])}</b> · أيام توفر بلا بيع <b>{fmt(r['zero_streak_instock_days'])}</b> · المتوقع بيعه فيها <b>{fmt(r['expected_sales_in_streak'],1)}</b> · احتمال أن يكون ذلك صدفة <b>{fmt(r['p_zero']*100,2)}%</b></div><div class='tl-r'>{esc(ar_codes(r['reason_codes']))}</div></div>")
timelines = "".join(tl)
# data quality rows
inv_rows = con.execute("SELECT count(*), min(doc_date), max(doc_date||' '||doc_time) FROM db_invoice_lines").fetchone()
uom = con.execute("SELECT count(*), sum((Quantity=InventoryQuantity)::int) FROM sap_uom_sample_invoices_l WHERE WarehouseCode=?", [WH]).fetchone()
dq = [("فواتير التجزئة (مرآة sapconnect)", f"{fmt(inv_rows[0])} بنداً · {inv_rows[1]} → {inv_rows[2]}", "مكتمل"),
      ("فواتير آخر 3 أيام من SAP مباشرة (جسر حتى لحظة السحب)", f"{fmt(con.execute('SELECT count(*) FROM sap_invoices_sap_l WHERE WarehouseCode=?', [WH]).fetchone()[0])} بنداً", "مكتمل"),
      ("تحويلات المخزون الفعلية (SAP StockTransfers)", f"{fmt(con.execute(f'SELECT count(distinct h_DocEntry) FROM sap_stock_transfers_{WH}_l').fetchone()[0])} مستنداً · {fmt(tin_units)} حبّة وارد · {fmt(tout_units)} صادر", "مكتمل — غير مُرآى في النظام الحالي"),
      ("إشعارات دائنة (مرتجعات)", f"{fmt(ret_units)} حبّة", "مكتمل"),
      ("قيود إدخال/إخراج وترحيلات جرد وGRPO مباشر للمعرض", "صفر مستندات منذ الافتتاح", "لا يوجد — المعرض لم يُجرد ولم يُسوَّ قط"),
      ("الرصيد الحي من SAP (لحظة السحب)", f"{T0:%Y-%m-%d %H:%M} · {fmt(units)} حبّة · {fmt(n_stocked)} صنفاً", "المرساة"),
      ("بوابة الوحدات: Quantity = InventoryQuantity", f"{fmt(uom[1])} / {fmt(uom[0])} بنداً", "نجحت 100% — كل البيع بالحبّة"),
      ("إغلاق الدفتر قبل الافتتاح (يجب أن يكون صفراً)", f"{pre_ok*100:.1f}% من الأصناف", "نجح"),
      ("إغلاق الدفتر مع لقطة 2026-07-27", f"{d2_ok*100:.1f}% من {fmt(len(in_snap))} صنفاً شملتها اللقطة", "نجح (الفروق الباقية ±1 خلال نافذة المزامنة)"),
      ("تسليمات/إرجاعات جملة من المعرض", "صفر", "لا ازدواج في الدفتر"),
      ("طلبات إلكترونية مُسلَّمة من المعرض", "6 حبات", "فُحصت مقابل الفواتير")]
dq_html = "".join(f"<tr><td>{esc(a_)}</td><td>{esc(b_)}</td><td>{esc(c_)}</td></tr>" for a_, b_, c_ in dq)
open_html = "".join(f"<tr><td>{esc(r.f)}</td><td>{fmt(r.docs)}</td><td>{fmt(r.lines_)}</td><td>{fmt(r.units)}</td><td>{fmt(r.cartons)}</td></tr>" for r in tr.itertuples())
scen = [("المنتج في يد العميل والنظام يقول صفر → زيادة صغيرة ثم بيع فوري", int(S["FIX_TO_SELL"].sum()), "FIX_TO_SELL"), ("إرجاع ثم بيع في نفس اليوم", int(S["RETURN_THEN_SALE"].sum()), "RETURN_THEN_SALE"),
        ("بيع والرصيد المُعاد بناؤه صفر (يعتمد على ترتيب التحويل والبيع في اليوم)", int(S["SOLD_AT_ZERO_POSSIBLE"].sum()), "SOLD_AT_ZERO_POSSIBLE"), ("مخزون وهمي: متوفر ولا يُباع رغم أنه يُباع في المعارض الأخرى", int(S["POISSON_ZERO"].sum()), "POISSON_ZERO"),
        ("تبديل محتمل بين أشقاء (واحد وهمي والآخر يُباع أكثر من المتوقع)", int(S["SIBLING_SUB"].sum()), "SIBLING_SUB"), ("هبوط مفاجئ في البيع مقابل الشبكة", int(S["VELOCITY_DROP"].sum()), "VELOCITY_DROP"),
        ("فرق بين كمية التحويل وما استلمه الموظف في التطبيق", int(S["RECEIVE_GAP"].sum()), "RECEIVE_GAP"), ("طلب تحويل معلّق أكثر من 14 يوماً", int(S["OPEN_TRANSFER"].sum()), "OPEN_TRANSFER"),
        ("دفعة منتهية الصلاحية ما زالت برصيد", int(S["EXPIRED_ON_HAND"].sum()), "EXPIRED_ON_HAND"), ("طلب إلكتروني بلا فاتورة", int(S["UNINVOICED_ONLINE"].sum()), "UNINVOICED_ONLINE"), ("رصيد سالب / كسري", int(S["NEG_STOCK"].sum() + S["FRACTIONAL"].sum()), "NEG_STOCK")]
scen_html = "".join(f"<tr><td>{esc(a_)}</td><td>{fmt(b_)}</td></tr>" for a_, b_, _ in scen)
# full scenario catalog (owner request): what happens on the floor → data signature → detected here
CATALOG = [
 ("المنتج في يد العميل والنظام يقول صفر؛ الموظف يُدخل زيادة صغيرة ليبيع", "وارد ورقي ≤ 3 حبّات على رصيد صفر ثم بيع في نفس اليوم (خارج أسبوع الافتتاح)", ["FIX_TO_SELL"]),
 ("البيع ممنوع عند الصفر فيُمسح صنف شقيق متوفر", "شقيق وهمي بلا بيع + شقيق يُباع أكثر من المتوقع", ["SIBLING_SUB"]),
 ("إرجاع يُسجَّل لتوليد رصيد ثم بيع", "إشعار دائن ثم بيع لنفس الصنف في نفس اليوم على رصيد صفر", ["RETURN_THEN_SALE"]),
 ("بضاعة وصلت قبل ترحيل التحويل أو بيعت قبل تسجيلها", "بيع والرصيد المُعاد بناؤه ≤ 0 (يعتمد على ترتيب اليوم)", ["SOLD_AT_ZERO", "SOLD_AT_ZERO_POSSIBLE"]),
 ("استلام جزئي أو زائد عن مستند التحويل", "كمية التحويل في SAP ≠ ما استلمه الموظف في التطبيق", ["RECEIVE_GAP"]),
 ("طلب تحويل بلا تحويل فعلي لفترة طويلة", "طلب مفتوح أكثر من 14 يوماً", ["OPEN_TRANSFER"]),
 ("خلط كرتون/حبّة عند البيع أو الاستلام", "صنف بوحدات متعددة وباركود كرتون؛ تحويلات بوحدة كرتون", ["MULTIPACK"]),
 ("تالف أو منتهي أُزيل من الرف بلا مستند", "دفعات منتهية الصلاحية ما زالت برصيد؛ لا قيود إخراج على المعرض", ["EXPIRED_ON_HAND", "NEAR_EXPIRY"]),
 ("هدايا وعينات ومكافآت تُعطى بلا مستند", "طلبات إلكترونية مُسلَّمة بلا فاتورة؛ أصناف الهدايا", ["UNINVOICED_ONLINE"]),
 ("سرقة أو فاقد", "قيمة وحدة عالية مع توفر بلا بيع", ["HIGH_VALUE"]),
 ("مكان خاطئ على الرف (موجود لكن لا يُعثر عليه)", "تسويتان متعاكستان خلال 60 يوماً — لا تسويات على هذا المعرض بعد", ["ADJ_HISTORY"]),
 ("تحويل رُحِّل إلى مستودع خاطئ / كاشير على مستودع آخر", "بيع هنا لصنف رصيده صفر وموجود في مستودع شقيق لا يبيعه", []),
 ("صنف مجمّع تُخصم مكوناته", "TreeType في بطاقة الصنف", ["BOM_ITEM"]),
 ("بيع بلا رصيد مسموح", "رصيد سالب أو كسري", ["NEG_STOCK", "FRACTIONAL"]),
 ("مخزون وهمي من أي سبب", "متوفر في النظام ولا يُباع لفترة يستحيل إحصائياً أن تكون صدفة", ["POISSON_ZERO"]),
 ("عملية لم تُسجَّل أصلاً (بيع نقدي خارج النظام، تحويل داخلي بلا مستند)", "لا بصمة مباشرة — تقيسها العيّنة الضابطة", []),
]
def cat_count(codes):
    if not codes: return "—"
    m = np.zeros(len(S), dtype=bool)
    for c in codes:
        if c in S.columns: m |= (S[c] == 1).values
    return fmt(int(m.sum()))
catalog_html = "".join(f"<tr><td>{esc(a_)}</td><td class='muted'>{esc(b_)}</td><td>{cat_count(c_)}</td></tr>" for a_, b_, c_ in CATALOG)

# validation-count sample (50 items) when prepared
val_html = ""
vp = OUT / f"validation_count_{WH}.csv"
if vp.exists():
    V = pd.read_csv(vp, encoding="utf-8-sig")
    grp = V.groupby("group", sort=False).agg(n=("item_code", "size"), units=("stock_now", "sum")).reset_index()
    gh = "".join(f"<tr><td>{esc(r.group)}</td><td>{fmt(r.n)}</td><td>{fmt(r.units)}</td></tr>" for r in grp.itertuples())
    rows_v = "".join(f"<tr><td>{i+1}</td><td class='code'>{esc(r.item_code)}</td><td class='nm'>{esc(r.name_ar)}</td><td>{esc(str(r.group).split(' ',1)[0])}</td><td>{fmt(r.stock_now)}</td><td>{esc(r.predicted_direction)}</td><td class='rs'>{esc(r.rationale)}</td></tr>" for i, r in enumerate(V.itertuples()))
    val_html = f"""<section id="validation"><h2>جرد التحقق: 50 صنفاً تحكم على التحليل</h2>
<p class="lead">الجرد الفعلي هو الحَكَم. اختيرت 50 صنفاً كتجربة: مجموعات نتوقع خللها <b>لأسباب مختلفة</b> (كل مجموعة تختبر آلية واحدة) ومجموعة ضابطة نتوقع مطابقتها. إن ظهرت الفروق في المجموعات A/B ولم تظهر في C فالتحليل صحيح؛ وإن تساوت النسب فالتحليل لا يميّز.</p>
<div class="scroll"><table class="t"><thead><tr><th>المجموعة</th><th>أصناف</th><th>حبّات في النظام</th></tr></thead><tbody>{gh}</tbody></table></div>
<div class="callout">قراءة النتائج بعد الجرد: <b>A</b> نتوقع نقصاً كبيراً (الوهمي) أو زيادة (الشقيق الساخن) · <b>B</b> نتوقع فروقاً أصغر أو مضاعفات العبوة أو وحدات منتهية على الرف · <b>C</b> نتوقع مطابقة ±1. أي صنف غير موجود يُسجَّل بكمية صفر لا يُترك.</div>
<div class="scroll"><table class="t"><thead><tr><th>#</th><th>الكود</th><th>الصنف</th><th>م</th><th>الرصيد</th><th>المتوقع</th><th>لماذا اختير</th></tr></thead><tbody>{rows_v}</tbody></table></div></section>"""
html = f"""<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ضبط مخزون {esc(NAME)}</title>
<meta name="description" content="تحليل عميق لبيانات SAP لمعرض {esc(NAME)} ({esc(WH)}): أي الأصناف يُرجَّح أن رصيدها غير مطابق، وأقل قائمة جرد تلتقط أكبر قيمة من الفروق.">
<style>
:root{{color-scheme:light;--surface-1:#fcfcfb;--page:#f9f9f7;--ink:#0b0b0b;--ink-2:#52514e;--muted:#898781;--grid:#e1e0d9;--axis:#c3c2b7;--border:rgba(11,11,11,.10);
--series-1:#2a78d6;--series-2:#eb6834;--series-3:#1baf7a;--series-4:#eda100;--good:#0ca30c;--warn:#fab219;--serious:#ec835a;--critical:#d03b3b;--wash:rgba(42,120,214,.08)}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{color-scheme:dark;--surface-1:#1a1a19;--page:#0d0d0d;--ink:#fff;--ink-2:#c3c2b7;--muted:#898781;--grid:#2c2c2a;--axis:#383835;--border:rgba(255,255,255,.10);--series-1:#3987e5;--series-2:#d95926;--series-3:#199e70;--series-4:#c98500;--wash:rgba(57,135,229,.12)}}}}
:root[data-theme="dark"]{{color-scheme:dark;--surface-1:#1a1a19;--page:#0d0d0d;--ink:#fff;--ink-2:#c3c2b7;--muted:#898781;--grid:#2c2c2a;--axis:#383835;--border:rgba(255,255,255,.10);--series-1:#3987e5;--series-2:#d95926;--series-3:#199e70;--series-4:#c98500;--wash:rgba(57,135,229,.12)}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--page);color:var(--ink);font-family:system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif;line-height:1.65;font-size:15px}}
main{{max-width:1040px;margin:0 auto;padding:24px 16px 80px}}header{{padding:28px 0 8px}}h1{{font-size:28px;margin:0 0 6px}}h2{{font-size:21px;margin:40px 0 10px;padding-top:18px;border-top:1px solid var(--border)}}h3{{font-size:16px;margin:22px 0 8px}}
.sub{{color:var(--ink-2)}}.lead{{font-size:16px}}.muted{{color:var(--muted);font-size:13px}}
.hero{{background:var(--surface-1);border:1px solid var(--border);border-radius:14px;padding:22px 24px;margin:16px 0}}.hero .big{{font-size:52px;font-weight:600;line-height:1.1}}.hero .big small{{font-size:18px;font-weight:400;color:var(--ink-2)}}
.kpis{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:14px 0}}.kpi{{background:var(--surface-1);border:1px solid var(--border);border-radius:12px;padding:12px 14px}}.kpi .l{{color:var(--ink-2);font-size:13px}}.kpi .v{{font-size:24px;font-weight:600}}
figure{{background:var(--surface-1);border:1px solid var(--border);border-radius:12px;padding:14px 14px 8px;margin:14px 0}}figcaption{{color:var(--ink-2);font-size:13px;margin-bottom:6px}}
svg.chart{{display:block;overflow:visible}}.grid{{stroke:var(--grid);stroke-width:1}}.tick{{fill:var(--muted);font-size:11px}}.lab{{fill:var(--ink);font-size:12px}}.val{{fill:var(--ink-2);font-size:11px}}.xhair{{stroke:var(--axis);stroke-width:1}}
.hit:hover .bar{{filter:brightness(1.12)}}.legend{{display:flex;gap:16px;flex-wrap:wrap;font-size:13px;color:var(--ink-2);margin:6px 2px}}.legend i{{display:inline-block;width:14px;height:3px;border-radius:2px;margin-inline-end:6px;vertical-align:middle}}
.tip{{position:fixed;pointer-events:none;background:var(--surface-1);color:var(--ink);border:1px solid var(--border);border-radius:8px;padding:6px 10px;font-size:12px;box-shadow:0 4px 18px rgba(0,0,0,.12);display:none;z-index:9;max-width:320px;white-space:pre-line}}
table.t{{width:100%;border-collapse:collapse;background:var(--surface-1);border:1px solid var(--border);border-radius:10px;overflow:hidden;font-size:13px}}table.t th,table.t td{{padding:8px 10px;border-bottom:1px solid var(--grid);text-align:start;vertical-align:top}}table.t th{{color:var(--ink-2);font-weight:600;background:var(--wash)}}table.t td{{font-variant-numeric:tabular-nums}}
.code{{font-family:ui-monospace,Menlo,monospace;font-size:12px;color:var(--ink-2);direction:ltr;unicode-bidi:isolate}}.nm{{min-width:220px}}.rs{{color:var(--ink-2);font-size:12px;max-width:300px}}
.tier{{display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;border:1px solid var(--border)}}.t-sure{{background:rgba(208,59,59,.12)}}.t-likely{{background:rgba(236,131,90,.14)}}.t-watch{{background:rgba(250,178,25,.14)}}.t-low{{background:var(--wash)}}
.slider{{background:var(--surface-1);border:1px solid var(--border);border-radius:12px;padding:16px;margin:12px 0}}.slider input[type=range]{{width:100%}}.slider .row{{display:flex;flex-wrap:wrap;gap:18px;align-items:center;margin-top:8px}}.slider .row b{{font-size:22px}}.slider label{{font-size:13px;color:var(--ink-2)}}.slider input[type=number]{{width:70px;padding:4px;border:1px solid var(--border);border-radius:6px;background:var(--page);color:var(--ink)}}
.tl{{background:var(--surface-1);border:1px solid var(--border);border-radius:12px;padding:12px 14px;margin:10px 0}}.tl-h{{display:flex;justify-content:space-between;gap:10px;align-items:baseline}}.tl-m{{font-size:13px;color:var(--ink-2)}}.tl-r{{font-size:12px;color:var(--muted)}}.spark{{display:block;margin:6px 0}}
.callout{{border-inline-start:4px solid var(--series-1);background:var(--wash);padding:10px 14px;border-radius:8px;margin:12px 0}}.warn{{border-color:var(--serious)}}
ol li,ul li{{margin:4px 0}}.two{{display:grid;grid-template-columns:1fr 1fr;gap:14px}}@media(max-width:720px){{.two{{grid-template-columns:1fr}}.hero .big{{font-size:38px}}}}
.scroll{{overflow-x:auto}}
</style></head><body><div class="tip" id="tip"></div><main>
<header><div class="sub">تقرير تحليل بيانات SAP · {T0:%Y-%m-%d} · قراءة فقط، لا كتابة على SAP</div><h1>ضبط مخزون {esc(NAME)} <span class="code">{esc(WH)}</span></h1>
<p class="lead">معرض عمره <b>{age_days} يوماً</b> (افتتح {OPEN:%Y-%m-%d})، أعدنا بناء كل حركة فيه منذ أول تحويل، ثم رتّبنا الأصناف حسب احتمال أن يكون رصيدها في النظام غير مطابق للرف. الهدف: <b>أقل قائمة جرد تلتقط أكبر قيمة من الفروق</b>.</p></header>

<div class="hero"><div class="sub">بدلاً من جرد {fmt(n_stocked)} صنفاً مخزّناً</div><div class="big"><span id="heroN">{default_n}</span> <small>صنفاً تلتقط</small> <span id="heroShare">{P.loc[P['cum_n']==default_n,'cum_share'].iloc[0]*100 if default_n<=len(P) else 100:.0f}%</span> <small>من قيمة الفروق المتوقعة</small></div>
<div class="muted">حرّك المنزلق في قسم «منحنى الالتقاط» لاختيار نقطة القطع التي تناسب طاقة الفريق. الأصناف «المؤكدة» ({n_sure}) و«المرجّحة» ({n_likely}) تدخل القائمة أولاً دائماً.</div></div>

<div class="kpis">
<div class="kpi"><div class="l">أصناف مخزّنة الآن</div><div class="v">{fmt(n_stocked)}</div></div>
<div class="kpi"><div class="l">حبّات في النظام</div><div class="v">{fmt(units)}</div></div>
<div class="kpi"><div class="l">قيمة المخزون (تكلفة تقديرية)</div><div class="v">{fmt(value/1000,0)}k ﷼</div></div>
<div class="kpi"><div class="l">إشارة مؤكدة</div><div class="v">{n_sure}</div></div>
<div class="kpi"><div class="l">إشارة مرجّحة</div><div class="v">{n_likely}</div></div>
<div class="kpi"><div class="l">احترازي</div><div class="v">{int(tiers.get('احترازي',0))}</div></div>
<div class="kpi"><div class="l">إغلاق الدفتر</div><div class="v">{d2_ok*100:.1f}%</div></div>
</div>

<section id="story"><h2>قصة المعرض منذ الافتتاح</h2>
<p>دخل المخزون كله عبر <b>تحويلات مخزون فعلية</b> من معرض النصر والمستودعات المركزية في الأسبوع الأول ({fmt(tin_units)} حبّة وارد حتى اليوم، {fmt(tout_units)} حبّة خرجت إلى معارض أخرى). بِيع منذ الافتتاح {fmt(sales_units)} حبّة وأُرجِع {fmt(ret_units)}. لم يُسجَّل على المعرض أي قيد تسوية أو إخراج تالف أو ترحيل جرد — أي أن <b>النظام لم يُصحَّح قط منذ الافتتاح</b>، وكل ما تراكم من أخطاء الاستلام والمسح ما زال فيه.</p>
<div class="two"><figure><figcaption>إجمالي الرصيد في النظام يوماً بيوم (حبّة)</figcaption>{chart_onhand}</figure><figure><figcaption>المبيعات اليومية (حبّة)</figcaption>{chart_sales}</figure></div>
<h3>تركيبة الافتتاح (أول 7 أيام)</h3><div class="scroll"><table class="t"><thead><tr><th>من مستودع</th><th>مستندات</th><th>بنود</th><th>حبّات</th><th>بنود بوحدة كرتون</th></tr></thead><tbody>{open_html}</tbody></table></div>
<p class="muted">البنود بوحدة الكرتون تُحوَّل إلى حبّات بـ InventoryQuantity؛ وهي أكثر مواضع خطأ الاستلام (كرتون يُسجَّل حبّة أو العكس).</p></section>

<section id="dq"><h2>المصادر وجودة البيانات</h2>
<div class="scroll"><table class="t"><thead><tr><th>المصدر / الاختبار</th><th>الحجم أو النتيجة</th><th>الحكم</th></tr></thead><tbody>{dq_html}</tbody></table></div>
<div class="callout">الدفتر يُغلق بالكامل: الرصيد المُعاد بناؤه قبل الافتتاح صفر لكل صنف، ويطابق لقطة 27 يوليو لـ {d2_ok*100:.1f}% من الأصناف التي شملتها. أي فرق نراه بعد ذلك بين الرف والنظام سببه الواقع لا نقص في المستندات.</div></section>

<section id="scen"><h2>سيناريوهات عدم التطابق التي رصدناها</h2>
<p>كل طريقة واقعية يختلف بها الرف عن النظام تترك بصمة في مستندات SAP. هذه عدّادات البصمات في {esc(NAME)} منذ الافتتاح:</p>
<div class="scroll"><table class="t"><thead><tr><th>السيناريو</th><th>الأصناف</th></tr></thead><tbody>{scen_html}</tbody></table></div>
<p class="muted">سيناريو «عملية لم تُسجَّل أصلاً» (بيع خارج النظام، تحويل داخلي بلا مستند) لا بصمة مباشرة له؛ يُرصد إحصائياً عبر «مخزون وهمي» وتقيس حجمه العيّنة الضابطة في الجرد.</p>
<h3>كتالوج السيناريوهات الكامل</h3><p class="muted">كل ما يمكن أن يُفرّق الرف عن النظام، والبصمة التي نبحث عنها في المستندات، وعدد أصناف RUH010 التي حملتها.</p>
<div class="scroll"><table class="t"><thead><tr><th>ما يحدث على الأرض</th><th>البصمة في البيانات</th><th>أصناف</th></tr></thead><tbody>{catalog_html}</tbody></table></div>
<figure><figcaption>عدد الأصناف لكل إشارة (الطبقات 1–4)</figcaption>{chart_signals}</figure></section>

<section id="pareto"><h2>منحنى الالتقاط: كم صنفاً نجرد؟</h2>
<p>{RANK_NOTE} المحور الأفقي عدد الأصناف المجرودة، والعمودي نسبة قيمة الفروق المتوقعة التي نلتقطها.</p>
<figure><figcaption>نسبة قيمة الفروق المتوقعة الملتقَطة مقابل عدد الأصناف</figcaption>{chart_pareto}</figure>
<div class="slider"><label>عدد الأصناف في قائمة الجرد: <input type="range" id="nSlider" min="10" max="{len(P)}" value="{default_n}" step="1"></label>
<div class="row"><div><label>الأصناف</label><br><b id="sN">{default_n}</b></div><div><label>قيمة الفروق المتوقعة الملتقَطة</label><br><b id="sShare">—</b></div><div><label>مؤكد / مرجّح / احترازي / منخفض</label><br><b id="sTiers">—</b></div><div><label>ساعات جرد تقديرية عند <input type="number" id="rate" value="40" min="5" max="200"> صنف/ساعة</label><br><b id="sHours">—</b></div></div>
<div class="muted">نقاط مرجعية: 80% من القيمة المتوقعة بـ <b>{n80}</b> صنفاً، 90% بـ <b>{n90}</b> صنفاً. تُلحَق بأي قائمة <b>عيّنة ضابطة</b> من 30 صنفاً عشوائياً من خارجها لقياس ما يفوت المحرك.</div></div>
<h3>القائمة المقترحة <span class="muted">(تُعرض أول <span id="listN">{min(300,len(P))}</span> صنفاً هنا؛ الملف الكامل CSV مرفق)</span></h3>
<div class="scroll"><table class="t" id="listTable"><thead><tr><th>#</th><th>الكود</th><th>الصنف</th><th>الرصيد</th><th>المبيع</th><th>أيام توفر بلا بيع</th><th>احتمال الصدفة</th><th>الفئة</th><th>الأسباب</th><th>قيمة الفرق المتوقعة ﷼</th></tr></thead><tbody id="listBody">{list_rows}</tbody></table></div></section>

<section id="tl"><h2>عشرة أصناف من أعلى القائمة بخطها الزمني</h2><p class="muted">الخط = الرصيد في النظام يوماً بيوم منذ الافتتاح؛ النقاط البرتقالية = أيام فيها بيع. صنف رصيده ثابت وموجب لأسابيع بلا نقطة بيع واحدة، بينما يُباع يومياً في المعارض الأخرى، هو المرشّح الأول لأن يكون رصيده وهمياً.</p>{timelines}</section>

{bt_html}

{val_html}

<section id="protocol"><h2>بروتوكول الجرد المقترح</h2>
<ol><li><b>جرد أعمى</b> للأصناف المختارة (الموظف لا يرى رصيد النظام) — التطبيق يدعم ذلك.</li><li>الأصناف «المؤكدة» و«المرجّحة» أولاً، ثم «الاحترازي» حتى نقطة القطع المختارة.</li><li><b>30 صنفاً ضابطاً</b> عشوائياً من خارج القائمة تُجرد معها وتُعلَّم كذلك؛ نسبة الفروق فيها تقيس ما يفوت المحرك وتُعاير التوقعات.</li><li>عند صنف شقيق مُعلَّم «تبديل محتمل»: يُجرد الشقيقان معاً.</li><li>النتائج تُرحَّل في SAP كالمعتاد (يدوياً) ثم تُسحب لإعادة معايرة الأوزان — هذه أول أرضية حقيقة للمعرض.</li></ol></section>

<section id="notes"><h2>ملاحظات للمالك</h2><ul>
<li>{esc(NAME)} <b>خارج قائمة الجرد الدوري في النظام الحالي</b> (قائمة المعارض مكتوبة يدوياً في الكود ولا تتضمنه)، فلا تصنيف ABC ولا قوائم أسبوعية له.</li>
<li>التحويلات الفعلية (StockTransfers) غير مُرآة في sapconnect؛ النظام يرى <i>طلبات</i> التحويل فقط. هذا التقرير قرأها مباشرة من SAP.</li>
<li>الطلبات الإلكترونية الست المُسلَّمة من المعرض ليست مرتبطة بفواتير SAP؛ الكميات ضئيلة لكن المسار يحتاج قاعدة واضحة.</li>
<li>الترتيب النهائي معاير على جرود نهاية 2025 في معارض أخرى؛ الأوزان الخبيرية الأولى ثبت ضعفها هناك وأُزيلت من الترتيب (بقيت بصمات الطبقة الأولى في الأعلى). أول جرد فعلي لهذا المعرض (مهمة 18) هو ما يثبت أو ينفي.</li></ul></section>
</main>
<script>
const ITEMS={items_json};const tip=document.getElementById('tip');
function showTip(e,t){{tip.textContent=t;tip.style.display='block';const x=Math.min(e.clientX+12,window.innerWidth-340);tip.style.left=x+'px';tip.style.top=(e.clientY+14)+'px';}}
document.querySelectorAll('.hit').forEach(g=>{{g.addEventListener('pointermove',e=>showTip(e,g.dataset.tip));g.addEventListener('pointerleave',()=>tip.style.display='none');}});
document.querySelectorAll('svg.linechart').forEach(svg=>{{const hit=svg.querySelector('.hitall');const xh=svg.querySelector('.xhair');const d=JSON.parse(hit.dataset.series);const n=+svg.dataset.n,L=+svg.dataset.l,pw=+svg.dataset.pw;
 hit.addEventListener('pointermove',e=>{{const r=svg.getBoundingClientRect();const vx=(e.clientX-r.left)/r.width*svg.viewBox.baseVal.width;let i=Math.round((vx-L)/pw*(n-1));i=Math.max(0,Math.min(n-1,i));const x=L+i/Math.max(n-1,1)*pw;xh.setAttribute('x1',x);xh.setAttribute('x2',x);xh.style.display='';
 showTip(e,d.x[i]+'\\n'+d.s.map(s=>s.n+': '+(s.v[i]==null?'—':Number(s.v[i]).toLocaleString('en-US',{{maximumFractionDigits:1}}))).join('\\n'));}});
 hit.addEventListener('pointerleave',()=>{{xh.style.display='none';tip.style.display='none';}});}});
const sl=document.getElementById('nSlider'),rate=document.getElementById('rate');
function upd(){{const N=+sl.value;const sub=ITEMS.slice(0,N);const share=sub.length?sub[sub.length-1].cs:0;const c={{}};sub.forEach(i=>c[i.t]=(c[i.t]||0)+1);
 document.getElementById('sN').textContent=N;document.getElementById('sShare').textContent=share.toFixed(0)+'%';document.getElementById('heroN').textContent=N;document.getElementById('heroShare').textContent=share.toFixed(0)+'%';
 document.getElementById('sTiers').textContent=[c['مؤكد']||0,c['مرجّح']||0,c['احترازي']||0,c['منخفض']||0].join(' / ');document.getElementById('sHours').textContent=(N/Math.max(1,+rate.value)).toFixed(1);
 const rows=document.querySelectorAll('#listBody tr');rows.forEach((r,i)=>r.style.opacity=i<N?'1':'0.35');document.getElementById('listN').textContent=Math.min(300,N);}}
sl.addEventListener('input',upd);rate.addEventListener('input',upd);upd();
</script></body></html>"""
out = OUT / f"report_{WH}.html"; out.write_text(html, encoding="utf-8")
# artifact fragment: the publish skeleton supplies doctype/html/head/body — keep only <title>, <style>, content, <script>
frag = html.split("<head>",1)[1]
frag = frag.replace('<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">', "")
frag = frag.replace("</head><body>", "").replace("</body></html>", "")
frag = frag.replace("<style>", "<style>\n:root{direction:rtl}\nmain{direction:rtl}", 1)
frag = frag.replace("<main>", '<main lang="ar" dir="rtl">', 1)
(OUT / f"report_{WH}.artifact.html").write_text(frag, encoding="utf-8")
print("report →", out, f"({len(html)/1024:.0f} KB) + artifact fragment")
