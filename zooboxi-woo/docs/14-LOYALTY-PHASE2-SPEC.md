# 14 — عائلة زوبوكسي · المرحلة 2 «العادة» — المواصفات التقنية

> العقد الملزم بين إضافة المتجر (`zooboxi/v2`) وتطبيق Flutter للمرحلة الثانية. الخطة الأم: `12-LOYALTY-PROGRAM.md` §3.4–3.5، §3.9–3.11. المرحلة الأولى: `13-LOYALTY-PHASE1-SPEC.md` (كل قواعدها سارية). اعتمد المالك تنفيذ المرحلة 2026-09-05.

---

## 0. نطاق المرحلة 2

| يُبنى الآن | يبقى للمرحلة 3 |
|---|---|
| عدّاد الأكل (تنبؤ + تعلّم من الفواصل + زر «خلص») + مكافأة «في وقته» +20% | الاشتراك التلقائي بالدفع المحفوظ |
| الاشتراك المرن (أ): جدول، تذكير، «اطلب الآن» بضغطة، شحن مجاني على توصيلة الاشتراك، +10% بصمات، هدية كل ثالث توصيل | رحلة الموسم، صورة الشهر |
| الإحالة: كود + رابط + مكافأة الطرفين + سقف + قائمة مراجعة | أدوات الرفيق (حاسبة، سجل وزن) |
| عيد ميلاد الحيوان (منحة سنوية لكل حيوان) | لوحة أفواج |
| الاسترجاع: مهمة «نشتاق لـ{pet}» بعد 45 يوماً من الموعد المتوقع | العرض الخاص بعد 90 يوماً (قرار مالك يدوي) |
| هدية الترحيب (موجودة من المرحلة 1 كمهمة `first_app_order` + مكافأة `welcome_gift`) | — |
| بطاقات الماركات: المحرك + لوحة الإدارة (لا برنامج فعّال حتى يقرّر المالك ماركة) | تشغيل أول ماركة |
| الهبوط الناعم للمستوى (تنبيه قبل 30 يوماً) | — |
| «تنبيهات» بلا Push: قائمة `nudges` في الملخّص + إشعارات محلية على iOS + بريد بسقف أسبوعي | Push عبر FCM |

**حقائق يجب احترامها:** لا خصم علني؛ الاستحقاق عند `completed`؛ الدفتر إلحاقي؛ رسوم التوصيل عبر الفلترين فقط (`zooboxi_free_shipping_min`, `zooboxi_express_fee`)؛ التطبيق لا يملك Push (لا Firebase) — التنبيهات إمّا داخل التطبيق أو إشعار محلي أو بريد.

---

## 1. نموذج البيانات (إصدار المخطط 2 — `dbDelta`)

### `zbx_zb_members` — أعمدة جديدة
`winback_at DATETIME NULL` (آخر مهمة استرجاع)، `nudge_week CHAR(7)`، `nudge_count TINYINT` (سقف الأسبوع للبريد).

### `zbx_zb_subscriptions`
id, user_id (idx), pet_id NULL, product_id, variation_id 0, qty INT 1, interval_days INT, next_at DATE, state VARCHAR(10) ∈ {active, paused, cancelled}, deliveries INT 0, reminder_for DATE NULL, last_order_id NULL, created_at, updated_at. **UNIQUE (user_id, product_id, variation_id)**. idx (state, next_at).

### `zbx_zb_supply_events`
id, user_id, product_id, variation_id 0, kind VARCHAR(8) ∈ {out, snooze}, until DATE NULL (snooze), created_at. idx (user_id, product_id, created_at).

### `zbx_zb_referrals`
id, referrer_id (idx), referee_id **UNIQUE**, code VARCHAR(12), state VARCHAR(10) ∈ {pending, qualified, review, rewarded, rejected}, first_order_id NULL, qualified_at NULL, rewarded_at NULL, flags VARCHAR(200) '', created_at, updated_at.

### `zbx_zb_stamp_programs`
id, title_ar, title_en, brand_term_id, units_required INT, min_pack_kg DECIMAL(5,2) 0, reward_id, is_active, sort, created_at, updated_at.

### `zbx_zb_stamps`
id, user_id, program_id, order_id, order_item_id, units INT, created_at. **UNIQUE (program_id, order_item_id)**. idx (user_id, program_id).

### `zbx_zb_notices`
id, user_id, kind VARCHAR(24), ref VARCHAR(40), channel VARCHAR(8), sent_at. **UNIQUE (user_id, kind, ref)** — لا يُرسل التنبيه نفسه مرتين.

### الدفتر — أسباب جديدة
`on_time` (+20% على سطور «في وقتها»), `sub_bonus` (+10% على توصيلة اشتراك), `referral` (300 للداعي), `birthday` (بديل الهدية إن لم يُربط منتج), `welcome` (المدعو بلا منتج ترحيب).

### الكتالوج — مفاتيح جديدة تُزرع (بلا منتج، يربطها المالك)
`welcome_gift` (موجود)، `birthday_gift`، `winback_gift`، `sub_gift`، `referral_welcome` (هدية المدعو). كلها `gift_product`, `paws_cost = 0` (تُمنح ولا تُشترى).

---

## 2. عدّاد الأكل `Zooboxi_Loyalty_Supply`

### 2.1 المدخلات
- الطلبات: `completed` + `processing` + `zb-ready` خلال 365 يوماً (حتى 40 طلباً). لكل سطر غير هدية: (وقت الطلب، الكمية، product_id، variation_id).
- **الصنف المستهلك**: نوعه من التصنيفات (أسلاف `product_cat`) والاسم:
  - `wet`: اسم/تصنيف يطابق `رطب|معلب|باوتش|pouch|صلصة|مرق|جيلي|jelly|gravy|wet`.
  - `litter`: اسم يطابق `رمل|تراب|litter` **و** حجم عبوة ≥ 1 كجم.
  - `dry`: سلف في تصنيفات الطعام (خيار `supply_food_cats`، افتراضي 108, 115, 247, 8649, 8773, 8671) أو الاسم يطابق `طعام جاف|دراي|dry|غذاء كامل`، مع حجم عبوة معروف.
  - `treat`: سلف في تصنيفات المكافآت (خيار `supply_treat_cats`، افتراضي 132, 174, 8685, 8805) أو `مكافآت|مكافات|treat|سناك|بسكويت`.
  - وإلا: مستهلك فقط إن اشتُري ≥ 2 مرة (`other`).
- **حجم العبوة (كجم)**: من اسم المنتج (`15كغ`, `1.5 كجم`, `415غ`, `374 غ`, `12x85غ`)، ثم من خصائص المتغيّر (`2-5-كغ` → 2.5، `400-غ`، `كرتون-24-حبة` → مضاعف × وزن الحبة من الاسم)، ثم `_weight` (غرام إن ≥ 100، وإلا كجم).
- **الحيوان**: جذر التصنيف (خيار `species_roots`، افتراضي cat=107, dog=114, bird=202, small=194) → أول حيوان من ذلك النوع، وإلا أول حيوان.

### 2.2 جدول التغذية (خيار `feeding_table` JSON، غرام/يوم)
| نوع | dry | wet | litter | treat |
|---|---|---|---|---|
| cat | 12 × وزن (افتراضي 4 كجم) | 30 × وزن | 500 | 10 |
| dog | 30 × وزن (<10 كجم)، 25 (10–25)، 20 (>25) — افتراضي 12 كجم | 40 × وزن | — | 20 |
| bird | 30 | — | — | 5 |
| small | 60 | — | 250 | 5 |
| fish | 1 | — | — | — |
| reptile | 5 | — | — | — |

الافتراضي القبلي لدورة الوحدة = `pack_kg × 1000 / g_per_day` (أيام). `other`/`treat` بلا حجم = 30 يوماً.

### 2.3 التعلّم
- **المشاهدات**: فواصل الشراء المتتالية للمنتج نفسه ÷ كمية الشراء الأقدم، وأحداث «خلص» (`out`): (وقت الحدث − آخر طلب) ÷ الكمية.
- **المزج**: `cycle = (prior + Σ observed) / (1 + n)` حين يوجد قبلي؛ وإلا متوسط المشاهدات؛ وإلا 30. القيد: 2 ≤ cycle ≤ 180 يوماً/وحدة.
- **الثقة**: `high` n ≥ 2 · `medium` n = 1 أو قبلي بوزن مسجّل · `low` غير ذلك.

### 2.4 الإسقاط
`runs_out_at = last_order_at + qty_last × cycle`؛ حدث `out` بعد آخر طلب → `runs_out_at = وقت الحدث`؛ `snooze` → `runs_out_at = max(runs_out_at, until)`.
`days_left = ceil((runs_out_at − now) / يوم)`. الحالة: `ok` (> 7) · `soon` (1..7) · `due` (−3..0) · `overdue` (< −3). **نافذة «في وقته»** = `days_left ∈ [−3, 7]` (خياران `on_time_before` 7, `on_time_after` 3).

### 2.5 «في وقته» (+20%)
- عند `woocommerce_checkout_order_processed`: كل سطر منتجه في العدّاد بحالة `soon|due` → ميتا الطلب `_zb_on_time_products` = JSON ids.
- عند `completed`: `on_time = floor(Σ(line_total للسطور المعلَّمة) × points_per_riyal × on_time_pct/100)` (خيار `on_time_pct` 20) → قيد `on_time` ref order. يُعكس عند الإلغاء.
- مهمة `on_time` (kind `regular`, هدف 1, 100 بصمة) تتقدّم بهذه الطلبات.

### 2.6 التخزين المؤقت
`zb_supply_{uid}` 15 دقيقة؛ يُبطَل عند تغيّر حالة أي طلب وعند كل حدث عدّاد وحفظ حيوان.

---

## 3. الاشتراك المرن `Zooboxi_Loyalty_Subscriptions`
- **الإنشاء**: من بند العدّاد (interval الافتراضي = `round(qty × cycle)`، `next_at = runs_out_at − 2`) أو من أي منتج (30 يوماً). القيود: 7 ≤ interval ≤ 120، qty 1..10، حتى `max_subscriptions` (6).
- **`order-now`**: يضمن السلة، يضيف المنتج بالكمية، يكتب `zb_sub_cart = [sub ids]` في جلسة WC، يعيد CartDTO. عند `checkout_order_processed`: ميتا `_zb_subscription_ids`، `last_order_id`، وتُمسح الجلسة.
- **الشحن**: ما دام `zb_sub_cart` في الجلسة والسلة تحتوي المنتج المشترك → فلتر الحد الأدنى يعيد 0، والسبب `free_delivery_reason = "subscription"`.
- **عند `completed`** لطلب اشتراك: `deliveries++`، `next_at = اليوم + interval`، قيد `sub_bonus = floor(order_paws × sub_bonus_pct/100)` (10)، وكل `sub_gift_every` (3) توصيلة → منحة `sub_gift` (إن رُبط منتج، وإلا 150 بصمة بسبب `sub_bonus` ref sub). أي طلب مكتمل يحوي المنتج المشترك (ولو يدوياً) يحرّك `next_at` أيضاً.
- **skip / pause / resume / cancel** بلا شروط.
- **التذكير**: الكرون اليومي: `active` و`next_at ≤ اليوم + sub_reminder_days` (3) و`reminder_for ≠ next_at` → تنبيه (بريد إن سمح السقف) و`reminder_for = next_at`.

---

## 4. الإحالة `Zooboxi_Loyalty_Referrals`
- **الكود**: `referral_code` الممنوح في المرحلة 1. الرابط: `{site}/?ref=CODE` → كوكي `zb_ref` 30 يوماً → يُطبَّق عند `user_register` (تسجيل OTP الويب/التطبيق).
- **`apply(referee, code)`**: الكود موجود · ليس الداعي نفسه · لا إحالة سابقة للمدعو · المدعو بلا أي طلب · سقف الداعي الشهري (`referral_cap` 10) → صف `pending` + للمدعو: منحة `referral_welcome` (إن رُبط منتج، صلاحية 30 يوماً) وإلا `referral_welcome_paws` (100) بسبب `welcome` ref referral.
- **التأهّل**: أول طلب `completed` للمدعو → `qualified` (+ `first_order_id`). أعلام الاحتيال: عنوان الشحن (address_1+city مطبَّعة) أو الجوال يطابق أحد طلبات الداعي → `review` بدل `qualified`.
- **المكافأة**: الكرون اليومي: `qualified` أقدم من `referral_hold_days` (7) وطلبها ليس `cancelled|refunded` → قيد `referral` للداعي (`referral_paws` 300) ref referral، `rewarded`، مهمة `refer_friend` تتقدّم، بريد للداعي. `review` يُعتمد أو يُرفض من اللوحة.

---

## 5. اللحظات `Zooboxi_Loyalty_Moments`
- **عيد الميلاد**: الكرون اليومي: حيوان حيّ بعيد ميلاد خلال ≤ 7 أيام ومالكه بمستوى ≥ `birthday_min_tier` (friend) ولم يُمنح هذه السنة (منحة `source=birthday, source_ref=pet` خلال 300 يوم أو قيد `birthday` ref pet) → منحة `birthday_gift` (صلاحية 28 يوماً) وإلا `birthday_paws` (100). بريد + بطاقة على الرئيسية.
- **الاسترجاع**: الكرون اليومي (دفعة ≤ 200 عضو، `last_earn_at` أقدم من `winback_days` (45) و`winback_at` أقدم من 90 يوماً وليس holdout): الموعد المتوقع = آخر طلب مكتمل + الوسيط الشخصي للفواصل (أو 30) → إن تجاوز اليوم الموعد + 45 → مهمة `winback` في الفترة الحالية (kind `winback`, هدف 1, مكافأة `winback_gift` وإلا 200 بصمة) + بريد. تكتمل بأي طلب مكتمل.
- **الهبوط الناعم**: `tier.at_risk = { in_days, orders_dropping, would_drop_to }` حين يخرج طلب من نافذة 365 يوماً خلال 30 يوماً ويهبط العدّ تحت حد المستوى الحالي. مخزَّن 6 ساعات.
- **التنبيهات `nudges[]`** (تُحسب حيّةً في الملخّص، مرتّبة بالتاريخ): `kind ∈ {birthday, supply, subscription, winback, tier_risk, referral}`, `title`, `body`, `at` (ISO, قد يكون مستقبلاً), `route` (مسار في التطبيق), `product_id?`, `subscription_id?`, `pet_id?`. التطبيق يعرض ما حان وقته ويجدول إشعاراً محلياً لما لم يحن (iOS: `zb/notify.schedule`).
- **البريد**: `Zooboxi_Loyalty_Mail::send()` — قالب HTML بهوية زوبوكسي، عربي + إنجليزي، يتخطى `@zooboxi.local`، سقف `mail_weekly_cap` (2) لكل عضو لأنواع التسويق (`supply`, `subscription`, `birthday`, `winback`)؛ `referral_rewarded` خارج السقف. مسجَّل في `zb_notices`.

---

## 6. بطاقات الماركات `Zooboxi_Loyalty_Stamps`
- برنامج = ماركة (`product_brand`) + `units_required` + `min_pack_kg` + مكافأة من الكتالوج. **لا برنامج فعّال افتراضياً** — القرار والتمويل للمالك.
- عند `completed`: لكل برنامج فعّال، السطور المطابقة (الماركة وحجم العبوة ≥ الحد) → طوابع بعدد الكمية (فريدة على السطر). `earned = floor(total/required)`; ما دام عدد المنح (`source=stamps, source_ref=program`) < earned → منحة.
- API: `GET /loyalty/stamps` → البطاقات النشطة فقط (فارغة = يخفي التطبيق القسم).

---

## 7. المهمات — قوالب جديدة
| template_key | kind | الشرط | الهدف | المكافأة |
|---|---|---|---|---|
| `on_time` | regular | لديه بند عدّاد واحد على الأقل | 1 | 100 بصمة |
| `refer_friend` | growth | دائماً (بعد `frequency`) | 1 | 100 بصمة (فوق الـ300) |
| `winback` | winback | يُنشئه الاسترجاع فقط، ليس في التعيين الشهري | 1 | `winback_gift` / 200 |

الترتيب: profile → first_app_order → on_time → frequency → try_new_brand → refer_friend → species_category. المقاعد 4.

---

## 8. واجهة `zooboxi/v2` — الإضافات (كلها Bearer، `private, no-store`)

### `GET /meta`
`features` تضيف `supply`, `subscriptions`, `referral`, `stamps`. `loyalty` تضيف `referral_paws`, `on_time_pct`, `sub_bonus_pct`.

### `GET /loyalty/summary` — إضافات
```json
"supply":        { "items": [SupplyDTO ×3], "due_count": 1, "total": 5 },
"subscriptions": { "active": 2, "next": SubscriptionDTO|null },
"moments":       { "birthday": { "pet": PetDTO, "days": 3, "grant_id": 71|null, "paws": null } | null },
"referral":      { "code": "ZBUCNBN", "url": "https://store.zooboxi.com/?ref=ZBUCNBN", "reward_paws": 300, "rewarded": 2 },
"stamps":        [StampCardDTO],
"nudges":        [NudgeDTO],
"tier.at_risk":  { "in_days": 12, "orders_dropping": 1, "would_drop_to": "star" } | null
```

### العدّاد
- `GET /loyalty/supply` → `{ "items": [SupplyDTO], "window": {"before": 7, "after": 3}, "on_time_pct": 20 }`
- `POST /loyalty/supply/{product_id}/out` body `{variation_id?}` → `{ "item": SupplyDTO }`
- `POST /loyalty/supply/{product_id}/snooze` body `{days: 7, variation_id?}` → `{ "item": SupplyDTO }`

SupplyDTO: `{ "product": Card, "variation_id", "kind": "dry|wet|litter|treat|other", "pet": {id,name,species}|null, "qty_last", "last_ordered_at", "cycle_days", "days_left", "runs_out_at", "status": "ok|soon|due|overdue", "confidence", "on_time": bool, "pack_kg": 2.5|null, "subscription_id": 12|null }`

### الاشتراكات
- `GET /loyalty/subscriptions` → `{ "items": [SubscriptionDTO], "max": 6 }`
- `POST /loyalty/subscriptions` body `{product_id, variation_id?, qty?, interval_days?, pet_id?}` → `{ "subscription": SubscriptionDTO, "items": [...] }`
- `PATCH /loyalty/subscriptions/{id}` body `{qty?, interval_days?, next_at?, state?: active|paused}` → نفس الرد
- `POST /loyalty/subscriptions/{id}/skip` → نفس الرد (`next_at += interval`)
- `POST /loyalty/subscriptions/{id}/order-now` → `{ "cart": CartDTO, "subscription": SubscriptionDTO }`
- `DELETE /loyalty/subscriptions/{id}` → `{ "items": [...] }`

SubscriptionDTO: `{ "id", "product": Card, "variation_id", "qty", "interval_days", "next_at": "2026-09-19", "days_until": 14, "state", "deliveries", "next_gift_in": 2, "pet": {…}|null, "perks": {"free_delivery": true, "bonus_pct": 10, "gift_every": 3} }`
أخطاء: `subscription_limit` 409، `subscription_exists` 409، `subscription_invalid` 422، `subscription_not_found` 404.

### الإحالة
- `GET /loyalty/referral` → `{ "code", "url", "share_text", "reward_paws": 300, "welcome": "هدية ترحيب…", "cap": 10, "this_month": 1, "stats": {"invited": 3, "qualified": 1, "rewarded": 2}, "items": [{ "name": "م…", "state", "created_at" }], "applied": { "code", "state" } | null }`
- `POST /loyalty/referral/apply` body `{code}` → `{ "applied": {…}, "paws_balance", "grant": GrantDTO|null }` · أخطاء: `referral_invalid` 404, `referral_self` 409, `referral_used` 409, `referral_not_new` 409, `referral_cap` 409.

### الطوابع
- `GET /loyalty/stamps` → `{ "items": [StampCardDTO] }`
StampCardDTO: `{ "program": {"id","title","brand": {"name","slug"}, "units_required", "min_pack_kg", "reward": RewardDTO}, "units", "cycles_done", "remaining" }`

### تعديلات قائمة
- **CartDTO.loyalty**: `free_delivery_reason` يقبل `"subscription"`؛ يضيف `"subscription_ids": [12]`.
- **`POST /checkout`**: يضيف `"subscription_order": true|false`.
- **`POST /events`**: أنواع جديدة `supply_action` (`{product_id, action: out|snooze|order|subscribe}`), `subscription` (`{subscription_id, action}`), `referral_share`.

---

## 9. الإدارة
تبويب **«🔁 العادة»**: مفاتيح التفعيل (العدّاد، الاشتراكات، الإحالة، عيد الميلاد، الاسترجاع، البريد)، الأرقام (`on_time_pct`, `on_time_before/after`, `sub_reminder_days`, `sub_bonus_pct`, `sub_gift_every`, `max_subscriptions`, `referral_paws`, `referral_cap`, `referral_hold_days`, `referral_welcome_paws`, `birthday_min_tier`, `birthday_paws`, `winback_days`, `winback_paws`, `mail_weekly_cap`)، جدول التغذية JSON، تصنيفات الطعام/المكافآت وجذور الأنواع، وقائمة الإحالات قيد المراجعة (اعتماد/رفض).
تبويب **«🏷️ بطاقات الماركات»**: جدول البرامج + نموذج (ماركة، وحدات، حد العبوة، مكافأة، نشط).
المؤشرات تضيف: اشتراكات نشطة، توصيلات اشتراك هذا الشهر، إحالات مكافأة، منح عيد ميلاد، مهمات استرجاع.

**WP-CLI:** `wp zooboxi loyalty habit-daily` (يشغّل مهام المرحلة 2 اليومية)، `wp zooboxi loyalty supply <user_id>` (يطبع العدّاد).

---

## 10. التطبيق
- **الرئيسية / بطاقة عائلتي** — ترتيب الأوجه: `birthday` → `pending` → `supply` (soon/due/overdue: حلقة الأيام + «اطلب الآن» + «اشترك») → `subscription` (توصيلة خلال ≤ 3 أيام: «اطلب الآن» / «تخطَّ») → `due` (من الخلاصة، احتياط) → `mission` → `tier`.
- **مركز العائلة**: بعد الإجراءات السريعة: بطاقة عيد الميلاد (إن وُجدت) → «مخزون البيت» (حتى 3 عدّادات + الكل) → «اشتراكاتي» (التالية + إدارة) → المهمات… → «ادعُ صديقاً» (الكود، مشاركة) → «بطاقات الماركات» (إن وُجدت). بطاقة المستوى تعرض سطر الهبوط الناعم.
- **شاشات جديدة**: `/family/supply` (القائمة: حلقة الأيام، الحيوان، «خلص»، «عندي كفاية»، «اطلب الآن»، «اشترك»)، `/family/subscriptions` (+ ورقة تحرير: الكمية، كل N يوماً، التاريخ التالي، إيقاف/إلغاء)، `/family/referral` (الكود، الرابط، مشاركة نظام، إدخال كود صديق، الحالات).
- **الحيوانات**: بطاقة الحيوان تعرض شريحة «يكفي N أيام» لأقرب بند عدّاد له.
- **السلة**: احتفال التوصيل المجاني بسبب `subscription`. **النجاح**: سطر «توصيلة اشتراك: +10% بصمات» عند `subscription_order`.
- **الإشعارات المحلية**: `LocalNotify.sync(nudges)` بعد كل ملخّص (iOS عبر `zb/notify`: `schedule {id,title,body,at}` و`cancelAll`). أندرويد يتجاهل بصمت.
- **i18n**: كل النصوص في `app_ar.arb` + `app_en.arb` (بادئات `supply*`, `sub*`, `referral*`, `moment*`, `stamp*`, `nudge*`).
- **الأحداث**: `supply_action`, `subscription`, `referral_share`.

---

## 11. معايير القبول
- طلب في نافذة العدّاد يكسب +20% مرة واحدة ويُعكس عند الإلغاء؛ مهمة `on_time` تكتمل به.
- «اطلب الآن» من اشتراك يبني السلة ويجعل الشحن 0 بسبب `subscription`، وتوصيلته المكتملة تدفع +10% وتحرّك `next_at`؛ التوصيلة الثالثة تمنح `sub_gift`.
- تطبيق كود إحالة لعميل جديد يمنحه الترحيب فوراً؛ اكتمال أول طلب له + 7 أيام يدفع 300 للداعي مرة واحدة؛ نفس العنوان → `review` بلا دفع.
- حيوان بعيد ميلاد خلال 7 أيام لعضو «صديق» فأعلى يحصل على منحة واحدة في السنة.
- عضو صامت 45 يوماً بعد موعده المتوقع يجد مهمة «نشتاق لـ…» ولا تتكرر خلال 90 يوماً.
- عضو holdout: لا مهمات استرجاع ولا نُدج لعب، لكن العدّاد والاشتراك والإحالة وعيد الميلاد للجميع.
- `php -l` على كل ملف، `flutter analyze` صفر، اختبارات التطبيق خضراء.
