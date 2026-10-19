"""Pick 50 items for a validation count that can CONFIRM or REFUTE the analysis: predicted-wrong groups (different mechanisms) + a predicted-right control group.
Writes out/validation_count_RUH010.csv and out/validation_targets_RUH010.json"""
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import duckdb, pandas as pd, numpy as np
from lib.paths import DUCK, OUT
WH = "RUH010"; SEED = 20261005
con = duckdb.connect(str(DUCK), read_only=True)
S = con.execute(f"SELECT * FROM signals_{WH}").fetchdf().set_index("item_code")
rng = np.random.default_rng(SEED)
picked = []  # (item_code, group, abc_for_app, direction, rationale)
def take(df, n, group, cls, direction, why):
    df = df[~df.index.isin([p[0] for p in picked])]
    for code, r in df.head(n).iterrows():
        picked.append((code, group, cls, direction, why(r)))
# G1 — deterministic ("مؤكد")
g1 = S[S["tier"] == "مؤكد"].sort_values("score", ascending=False)
take(g1, 4, "G1 مؤكد: بصمة مباشرة", "A", "زيادة/أي فرق", lambda r: f"بصمة {r['reason_codes'].split('|')[0]}: نُفّذ وارد ورقي صغير ثم بيع فوري — نتوقع وجود وحدات غير مسجّلة أو فرقاً يُثبت المسار" if r["FIX_TO_SELL"] == 1 else f"إشارة مؤكدة: {r['reason_codes']}")
# G3 — sibling pairs first (so G2 doesn't eat the phantom sibling)
fam = S[S["SIBLING_SUB"] == 1]
pairs = []
for f, g in fam.groupby("family"):
    ph = g[(g["POISSON_ZERO"] == 1)].sort_values("p_zero"); hot = g[(g["POISSON_ZERO"] == 0)].sort_values("over_sell", ascending=False)
    if len(ph) and len(hot): pairs.append((ph.index[0], hot.index[0], ph.iloc[0]["expected_var_value"] + hot.iloc[0]["sold_units"]))
pairs.sort(key=lambda x: -x[2])
for ph, hot, _ in pairs[:4]:
    r = S.loc[ph]; picked.append((ph, "G3 تبديل أشقاء (الوهمي)", "A", "نقص", f"شقيق لا يُباع منذ {int(r['zero_streak_instock_days'])} يوماً رغم رصيد {int(r['stock_now'])} — نتوقع نقصاً لأن مبيعاته سُجِّلت على شقيقه"))
    r = S.loc[hot]; picked.append((hot, "G3 تبديل أشقاء (الساخن)", "A", "زيادة", f"شقيق يُباع {r['over_sell']:.1f}× أكثر من معدّل الشبكة — نتوقع زيادة فعلية على الرف (مسح بدل شقيقه)"))
# G2 — strongest phantom stock, not in pairs
g2 = S[(S["POISSON_ZERO_STRONG"] == 1) & (S["stock_now"] >= 1)].sort_values(["p_zero", "expected_var_value"], ascending=[True, False])
take(g2, 12, "G2 مخزون وهمي قوي", "A", "نقص", lambda r: f"رصيد {int(r['stock_now'])} ولا بيع منذ {int(r['zero_streak_instock_days'])} يوماً توفر؛ المتوقع بيعه فيها {r['expected_sales_in_streak']:.0f} (احتمال الصدفة {r['p_zero']*100:.3f}%) — نتوقع عدداً أقل بكثير أو صفراً")
# G4 — expired on hand
g4 = S[(S["EXPIRED_ON_HAND"] == 1)].sort_values("expired_units", ascending=False)
take(g4, 6, "G4 منتهي الصلاحية برصيد", "B", "نقص أو مطابق-منتهي", lambda r: f"{int(r['expired_units'])} حبّة من رصيد {int(r['stock_now'])} بدفعات منتهية الصلاحية — إمّا أُزيلت بلا مستند (نقص) أو ما زالت على الرف (تحتاج إخراجاً)")
# G5 — velocity drop + sold-at-zero-possible with stock
g5a = S[(S["VELOCITY_DROP"] == 1) & (S["POISSON_ZERO"] == 0) & (S["stock_now"] >= 3)].sort_values("expected_var_value", ascending=False)
take(g5a, 3, "G5 هبوط البيع", "B", "نقص", lambda r: f"بيع آخر 28 يوماً هبط إلى {r['vel_ratio_own']*100 if pd.notna(r['vel_ratio_own']) else 0:.0f}% من الفترة السابقة بينما الشبكة {r['vel_ratio_net']*100 if pd.notna(r['vel_ratio_net']) else 100:.0f}% — رصيد {int(r['stock_now'])}")
g5b = S[(S["SOLD_AT_ZERO_POSSIBLE"] == 1) & (S["stock_now"] >= 1) & (S["POISSON_ZERO"] == 0)].sort_values("sold_at_zero_pos_lines", ascending=False)
take(g5b, 3, "G5 بيع بلا رصيد محتمل", "B", "نقص", lambda r: f"{int(r['sold_at_zero_pos_lines'])} عملية بيع في أيام كان الرصيد المُعاد بناؤه صفراً قبل تحويل نفس اليوم — نختبر هل البضاعة تصل قبل مستندها")
# G6 — opening cartons, otherwise clean
g6 = S[(S["OPENING_BULK"] == 1) & (S["MULTIPACK"] == 1) & (S[["NEG_STOCK","SOLD_AT_ZERO","FIX_TO_SELL","POISSON_ZERO","SIBLING_SUB","VELOCITY_DROP","EXPIRED_ON_HAND","SOLD_AT_ZERO_POSSIBLE"]].sum(axis=1) == 0) & (S["stock_now"] >= 24)].sort_values("opening_units", ascending=False)
take(g6, 4, "G6 احترازي: كراتين الافتتاح", "B", "مضاعفات العبوة إن وُجد فرق", lambda r: f"استُلم {int(r['opening_units'])} حبّة بالكرتون في الافتتاح (عبوة {int(r['spu']) if pd.notna(r['spu']) else '?'}) — أي فرق سيكون مضاعفاً للعبوة إن كان خطأ وحدات")
# G7 — control: predicted correct
g7 = S[(S["tier"] == "منخفض") & (S["score"] <= 1.0) & (S["stock_now"].between(3, 60)) & (S["lam_own"] > 0.2) & (S["days_since_last_move"] <= 7)].copy()
g7["strat"] = pd.qcut(g7["stock_value"].rank(method="first"), 3, labels=["low", "mid", "high"])
ctrl = pd.concat([g.sample(min(4 if k != "high" else 2, len(g)), random_state=int(rng.integers(1e9))) for k, g in g7.groupby("strat", observed=True)])
ctrl = ctrl.head(10)
for code, r in ctrl.iterrows(): picked.append((code, "G7 ضابطة: متنبَّأ بمطابقته", "C", "مطابق", f"يُباع بانتظام ({r['lam_own']:.2f}/يوم)، آخر حركة قبل {int(r['days_since_last_move'])} يوم، بلا أي إشارة — نتوقع مطابقة ±1"))
assert len(picked) == 50, len(picked)
V = pd.DataFrame(picked, columns=["item_code", "group", "abc_for_app", "predicted_direction", "rationale"]).set_index("item_code")
cols = ["name_ar", "item_name", "piece_barcode", "stock_now", "sold_units", "zero_streak_instock_days", "lam_blend", "p_zero", "expected_sales_in_streak", "expired_units", "over_sell", "tier", "score", "reason_codes", "expected_abs_var", "unit_cost", "family"]
V = V.join(S[cols])
V.reset_index().to_csv(OUT / f"validation_count_{WH}.csv", index=False, encoding="utf-8-sig")
targets = [{"item_code": c, "abc_class": r["abc_for_app"]} for c, r in V.iterrows()]
json.dump(targets, open(OUT / f"validation_targets_{WH}.json", "w"), ensure_ascii=False)
print(V.groupby("group").agg(n=("stock_now", "size"), system_units=("stock_now", "sum"), exp_abs_var=("expected_abs_var", "sum")).to_string())
print("\nsystem units in sample:", int(V["stock_now"].sum()), "| items with system 0:", int((V["stock_now"] == 0).sum()))
print(V.reset_index()[["item_code", "group", "name_ar", "stock_now", "predicted_direction"]].to_string(index=False, max_colwidth=40))
