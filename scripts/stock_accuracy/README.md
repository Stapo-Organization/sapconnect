# ضبط مخزون المعارض — تحليل قرائي لبيانات SAP (RUH010 معرض الملك فهد)

تحليل لمرة واحدة (لا يغيّر النظام): يعيد بناء دفتر حركات المعرض من SAP، يرصد بصمات سيناريوهات عدم التطابق، يرتّب الأصناف بدرجة خطورة، ويرسم منحنى «كم صنفاً نجرد لنلتقط كم % من قيمة الفروق».

## حواجز
- SAP: GET فقط على PPTC_V5_PROD عبر `PagedSapClient` (لا POST/PATCH، لا إنشاء SQLQueries). الاستعلام المحفوظ `SQLQueries('batchesitems')` قائم مسبقاً.
- الإنتاج: SELECT فقط عبر `ssh alofq 'sudo -n mysql sapapimuntajat_apisap --batch'` (لا كتابة على الخادم).
- البيانات والمخرجات في `storage/analysis/` (مُهمَلة في git).

## التشغيل
```
./.venv/bin/python …    # uv venv (python 3.12): pandas duckdb numpy scipy scikit-learn
WH=RUH010 ./10_extract_prod.sh                 # مرآة الإنتاج → raw/db/*.tsv.gz
WH=RUH010 SINCE=2026-07-01 ./20_pull_sap.sh    # Items, StockTransfers, GenEntries/Exits, رؤوس OINC/OIQR, عيّنة UoM, مسبار التسليمات
php php/pull_doc_by_key.php --resource=InventoryCountings --keys=… --out=…   # مستندات الجرد (مستند/طلب)
php php/pull_batches.php --keys=raw/sap/ruh010_items.keys --out=raw/sap/batches_ruh010.ndjson.gz
python py/20_load.py      # → work/stock_accuracy.duckdb
python py/30_ledger.py    # الدفتر اليومي + اختبارا الإغلاق (قبل الافتتاح = 0، لقطة 2026-07-27)
python py/40_signals.py   # الإشارات (كتالوج السيناريوهات) → signals_RUH010 + out/signals_RUH010.csv
python py/50_backtest.py  # اختبار رجعي على جرود نهاية 2025 (يحتاج سحوبات 2025-H2: invoices_2025m07..12, credit notes, transfers, deliveries, returns, gen entries/exits)
python py/55_score_forward.py   # قائمة الجرد النهائية + عيّنة ضابطة → out/count_list_RUH010.csv
python py/60_report.py    # تقرير عربي HTML (ملف مستقل + نسخة Artifact)
```

## حقائق مثبتة
- بنود بيع التجزئة بالحبّة (Quantity = InventoryQuantity، UoM PC). التحويلات بالكرتون غالباً → استخدم InventoryQuantity دائماً.
- SL يحترم `Prefer: odata.maxpagesize`؛ الترقيم بـ `$skip` حتى صفحة فارغة.
- مستندات جرد نهاية 2025 لمعارض الرياض تحوي البنود المختلفة فقط؛ MED001/JED002/UZH001/DMM001 تحوي المطابق أيضاً (صالحة لقياس الدقة).
