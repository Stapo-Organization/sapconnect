# 13 — عائلة زوبوكسي · المرحلة 1 «الأساس» — المواصفات التقنية

> العقد الملزم بين إضافة المتجر (`zooboxi/v2`) وتطبيق Flutter. الخطة الأم: `12-LOYALTY-PROGRAM.md`. اعتمدها المالك 2026-09-05 بكل التوصيات (الأسماء، الاستبدال بهدايا وخدمات فقط، حصرية اللعب للتطبيق، سقف 4%).
>
> **الأسماء:** البرنامج «عائلة زوبوكسي» / "Zooboxi Family". العملة «بصمات» (مفرد بصمة) / "Paws". المفتاح الداخلي `paws`.

---

## 0. نطاق المرحلة 1

| يُبنى الآن | يُؤجَّل (المرحلة 2/3) |
|---|---|
| ملف الحيوان (CRUD) | عدّاد الأكل الحقيقي، الاشتراك |
| دفتر البصمات + الكسب عند اكتمال الطلب + الانتهاء بعد 12 شهراً خمول | مكافأة «في وقته» +20% |
| المستويات على 12 شهراً متحركة + مزايا الشحن الفعلية | عيد الميلاد، الإحالة، الاسترجاع، بطاقات الماركات |
| اخدش واربح (طلبات التطبيق فقط) | رحلة الموسم، صورة الشهر |
| مهمات الشهر v1 (5 قوالب) | مهمات «انتظام» و«مجتمع» |
| كتالوج الهدايا + المنح + الهدية سطراً في السلة + التوصيل المجاني كمنحة | كوبونات خارجية |
| إعدادات الإضافة + مؤشرات + خط الأساس + مجموعة ضابطة | لوحة أفواج كاملة |
| التطبيق: بطاقة عائلتي على الرئيسية، شريط المهمات، مركز العائلة، الحيوانات، لحظة الخدش، الهدية في السلة | — |

**حقائق تشغيلية يجب احترامها:** رسوم التوصيل تُقرأ من الخيارات `zooboxi_express_fee` (افتراضي 15؛ **صفر الآن للتجربة فقط وسيصبح مدفوعاً** — قرار المالك 2026-09-05)، `zooboxi_standard_fee` (10)، `zooboxi_shipping_fee` (25)، وحد الشحن المجاني `zooboxi_free_shipping_min` (200). المكافآت الخدمية نوعان: **`express_free`** «ترقية توصيل سريع مجاني» (تصفّر رسم express فقط على الطلب القادم) و**`free_delivery`** «توصيل مجاني بلا حد أدنى» (تصفّر رسم أي مستوى توصيل). لا تفترض أبداً أن أي رسم صفر.

---

## 1. القواعد (لا تُخالَف)

1. **لا خصم علني.** لا كوبونات نسبة/مبلغ. المكافآت: بصمات، هدية منتج (سطر بسعر صفر)، توصيل مجاني.
2. **الاستحقاق بعد التسليم.** الكسب والتفعيل عند `completed`. الإلغاء/الاسترجاع يعكس بقيد معاكس أو يلغي المنحة.
3. **الدفتر إلحاقي فقط** (append-only). لا تعديل ولا حذف. فريد على `(user_id, reason, ref_type, ref_id)`.
4. **الخدش والمهمات حصرية للتطبيق ولغير المجموعة الضابطة.** الويب يرى الرصيد والمستوى فقط (عبر فلتر `zooboxi_account_tiers` ودالة الرصيد).
5. **المجموعة الضابطة (holdout)** تُعيَّن مرة عند الانضمام: `crc32(user_id . salt) % 100 < holdout_pct` (افتراضي 10). لا خدش ولا مهمات لها؛ البصمات والمستويات للجميع.
6. **الهدية سطر بسعر صفر** في السلة والطلب، باسم يبدأ بـ «🎁 هدية · » وميتا `_zb_gift_grant`. تنقص المخزون طبيعياً، تظهر في التحضير، وتمر بمسار SAP القائم.
7. **لا بصمات بأثر رجعي.** المستويات تُحسب من التاريخ فوراً (العميل الوفي يجد نفسه ذهبياً)، البصمات تبدأ من تفعيل البرنامج.
8. كل نص للعميل عربي + إنجليزي. كل قيمة رقمية قابلة للضبط من الإعدادات بلا نشر.

---

## 2. نموذج البيانات (بادئة `$wpdb->prefix` = `zbx_`)

التثبيت كسول بنمط `Zooboxi_App_Tokens::maybe_install()` (خيار إصدار + `dbDelta`). كل الجداول `DATETIME` بتوقيت UTC.

### `zbx_zb_members`
| عمود | نوع | ملاحظة |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT UNIQUE | |
| joined_at | DATETIME | أول تفاعل مع البرنامج |
| holdout | TINYINT | 0/1 ثابت |
| tier_key | VARCHAR(16) | مخزَّن مؤقتاً |
| tier_orders_12m | INT | |
| tier_computed_at | DATETIME NULL | يُبطل عند اكتمال/إلغاء طلب |
| paws_balance | INT | مرآة الدفتر |
| last_earn_at | DATETIME NULL | لحساب الخمول |
| profile_completed_at | DATETIME NULL | |
| referral_code | VARCHAR(12) UNIQUE NULL | يُولَّد الآن، يُستخدم في المرحلة 2 |

### `zbx_zb_pets`
id, user_id (idx), name VARCHAR(60), species ENUM-like VARCHAR(12) ∈ {cat, dog, bird, fish, small, reptile, other}, breed VARCHAR(80) '', sex VARCHAR(1) ∈ {m,f,''}, weight_kg DECIMAL(5,2) NULL, birth_date DATE NULL, neutered TINYINT NULL, photo_id BIGINT NULL (attachment), avatar VARCHAR(24) '' (مفتاح رسمة), notes VARCHAR(200) '', created_at, updated_at, deleted_at NULL.
حد 3 حيوانات نشطة (خيار `zooboxi_loyalty_max_pets`).

### `zbx_zb_paws_ledger`
id, user_id (idx), delta INT (موجب/سالب), balance_after INT, reason VARCHAR(32) ∈ {order_earn, profile_complete, pet_added, mission, scratch, redeem, reverse, expire, adjust, welcome}, ref_type VARCHAR(24) '', ref_id BIGINT 0, note VARCHAR(200) '', created_at (idx). **UNIQUE (user_id, reason, ref_type, ref_id)**.

### `zbx_zb_rewards` (الكتالوج)
id, kind VARCHAR(20) ∈ {gift_product, express_free, free_delivery, paws}, title_ar, title_en, desc_ar, desc_en, product_id BIGINT NULL, variation_id BIGINT NULL, paws_cost INT (0 = لا يُستبدل بالنقاط، يُمنح فقط), cost_sar DECIMAL(8,2) (تكلفتنا للميزانية), value_sar DECIMAL(8,2) (القيمة المدرَكة), validity_days INT (افتراضي 21), min_tier VARCHAR(16) '', monthly_cap INT NULL (سقف المنح شهرياً), is_active TINYINT, sort INT, created_at, updated_at.

### `zbx_zb_grants`
id, user_id (idx), reward_id, source VARCHAR(16) ∈ {scratch, mission, redeem, welcome, admin}, source_ref BIGINT 0, state VARCHAR(12) ∈ {pending, active, claimed, redeemed, expired, cancelled}, activates_on_order BIGINT NULL (pending حتى اكتمال هذا الطلب), expires_at DATETIME NULL (يُحدَّد عند التفعيل = now + validity_days), claimed_at NULL, redeemed_order_id BIGINT NULL, created_at, updated_at. idx (user_id, state).

### `zbx_zb_scratch_cards`
id, user_id, order_id BIGINT UNIQUE, prize_kind VARCHAR(8) ∈ {paws, reward}, prize_paws INT 0, prize_reward_id BIGINT NULL, grant_id BIGINT NULL, state VARCHAR(8) ∈ {sealed, revealed}, revealed_at NULL, settled TINYINT 0 (صار الجائزة فعلية عند اكتمال الطلب), created_at.

### `zbx_zb_missions`
id, user_id, period CHAR(7) 'YYYY-MM', template_key VARCHAR(32), kind VARCHAR(12) ∈ {profile, trial, frequency, welcome, category}, title_ar, title_en, body_ar, body_en, target INT, progress INT, params LONGTEXT JSON, reward_kind VARCHAR(8) ∈ {paws, reward}, reward_paws INT, reward_reward_id BIGINT NULL, state VARCHAR(10) ∈ {active, completed, rewarded, expired}, completed_at NULL, created_at. **UNIQUE (user_id, period, template_key)**.

---

## 3. القواعد التشغيلية

### 3.1 العضوية
`Zooboxi_Loyalty_Members::ensure(int $user_id)`: ينشئ الصف عند أول لمسة (طلب مكتمل، فتح المركز، إضافة حيوان). يحسب holdout مرة واحدة.

### 3.2 المستويات
- المقياس: عدد الطلبات بحالة `completed` للعميل خلال آخر 365 يوماً (HPOS أو posts حسب المتجر — استخدم `wc_get_orders` مع `customer_id`, `status`, `date_completed`).
- الحدود (خيار `zooboxi_loyalty_tiers` JSON، افتراضي): `new` 0، `friend` 2، `star` 4، `gold` 8، `amb` 14.
- الأسماء AR/EN: بداية الرحلة/Start · صديق/Friend · مميّز/Star · ذهبي/Gold · سفير/Ambassador. الألوان من `zooboxi_account_tiers` الحالية.
- **المزايا المنفَّذة برمجياً:**
  - `star` فأعلى: حد الشحن المجاني 150 بدل 200 (خيار `zooboxi_loyalty_star_free_min`).
  - `gold` فأعلى: رسم التوصيل السريع 0 دائماً داخل نطاق المستودع (`express_free_always`).
  - `amb`: توصيل مجاني بلا حد أدنى لكل المستويات (`free_delivery_always`).
  - المزايا الأخرى (أولوية الدعم، عينات، واتساب) نصوص تُعرض فقط (`perks[]`).
- **الآلية (فلتران):**
  1. استبدال القراءات السبع لـ `get_option('zooboxi_free_shipping_min', 200)` بـ `apply_filters('zooboxi_free_shipping_min', (float) get_option('zooboxi_free_shipping_min', 200))` (delivery-engine، smart-shipments، shipping ×3، v2 cart، v2 meta).
  2. استبدال القراءات السبع لـ `get_option('zooboxi_express_fee', 15)` بـ `apply_filters('zooboxi_express_fee', (float) get_option('zooboxi_express_fee', 15))` (fulfillment:67، delivery-engine:47 و159، smart-shipments:396، express-shipping:106، v2 meta:29، v2 cart:612).
  وحدة الولاء تسجّل الفلترين: منحة `free_delivery` مطالَب بها في الجلسة → الحد 0؛ منحة `express_free` مطالَب بها → رسم express 0؛ وإلا حسب مزايا المستوى. الفلتران يقرآن المستخدم الحالي (bearer أو جلسة الويب) ويعودان بالقيمة الأصلية للضيوف.
- الهبوط الناعم (تنبيه قبل 30 يوماً) = المرحلة 2؛ الآن الحساب المتحرك فقط.
- الويب: الوحدة تسجّل `add_filter('zooboxi_account_tiers')` لتوحيد الحدود والأسماء مع قالب الحساب.

### 3.3 كسب البصمات
- عند `woocommerce_order_status_completed` لطلب بعميل مسجّل: `paws = floor(points_per_riyal × Σ line_subtotal بعد الخصم، بدون سطور الهدايا، بدون شحن وضريبة)`. سبب `order_earn`، ref `order:{id}`. يحدّث `paws_balance` و`last_earn_at`.
- `profile_complete` 100 (مرة): عند وجود حيوان واحد على الأقل بوزن وتاريخ ميلاد. `pet_added` 50 لكل حيوان (حتى 3، ref `pet:{id}`).
- **العكس:** عند `cancelled`/`refunded` لطلب سبق الكسب منه → قيد `reverse` بسالب نفس القيمة (ref order). لا يُعكس مرتين (UNIQUE).
- **الانتهاء:** كرون يومي `zooboxi_loyalty_daily`: أعضاء `last_earn_at < now − expiry_months (12)` ورصيد > 0 → قيد `expire` بسالب الرصيد كله.
- ليس هناك مضاعفات في هذه المرحلة.

### 3.4 اخدش واربح
- الإنشاء في `woocommerce_checkout_order_processed` (يُطلق من الويب ومن v2 `place`) **فقط** إذا: عميل مسجّل، الطلب من التطبيق (ميتا `_zooboxi_app_order` = 1 يضعها v2 `place` — أضفها إن لم تكن موجودة)، العضو ليس holdout، الميزة مفعّلة.
- الجائزة تُسحب عند الإنشاء من جدول الأوزان (خيار `zooboxi_loyalty_scratch_table` JSON، افتراضي):
  `[{kind:paws, paws:50, weight:60}, {kind:reward, reward_id:<express_free>, weight:22}, {kind:reward, reward_id:<small_gift>, weight:12}, {kind:paws, paws:300, weight:5}, {kind:reward, reward_id:<mystery_box>, weight:1}]`. إن كان reward_id غير موجود/غير نشط، يسقط الصف من السحب.
- الحالة `sealed`. `POST /loyalty/scratch/{id}/reveal` → `revealed`. الجائزة **لا تصير فعلية** إلا عند `completed` (`settled=1`): بصمات → قيد `scratch` ref `scratch:{id}`; مكافأة → المنحة `pending(activates_on_order)` تصبح `active` مع `expires_at`.
- إلغاء/استرجاع الطلب قبل الاكتمال → المنحة `cancelled`، لا بصمات.
- بطاقة واحدة لكل طلب (UNIQUE order_id).

### 3.5 مهمات الشهر v1
- التعيين كسول عند أول `GET /loyalty/summary` أو `/loyalty/missions` في الشهر (أو أول اكتمال طلب في الشهر) — يختار حتى 4 قوالب مؤهلة بالترتيب التالي، مع استبدال `{pet}` باسم أول حيوان (أو «صديقك» / "your pet"):

| template_key | kind | الشرط | الهدف | المكافأة الافتراضية |
|---|---|---|---|---|
| `profile` | profile | لا يوجد حيوان بوزن+ميلاد | 1 | 100 بصمة |
| `first_app_order` | welcome | لا طلب سابق من التطبيق | 1 | منحة `welcome_gift` إن وُجدت وإلا 150 بصمة |
| `frequency` | frequency | دائماً | 2 إن كان متوسط طلباته الشهرية < 2 وإلا 3 | 300 بصمة (أو منحة إن ضُبطت) |
| `try_new_brand` | trial | يوجد ماركات لم يشترها خلال 12 شهراً | 1 | 150 بصمة / منحة |
| `species_category` | category | لديه حيوان من نوع له تصنيف مضبوط (`zooboxi_loyalty_species_categories` مثل `cat → wet-food-cats`) ولم يشترِ منه خلال 12 شهراً | 1 | 150 بصمة / منحة |

- `params`: للـ trial قائمة `brand_ids` المقترحة (حتى 3 من `product_associations` إن توفّرت عبر `/api/woo/recommendations` وإلا أشهر الماركات في مدينته)؛ للـ category `category_id`.
- **التقدّم** عند `completed`: frequency +1 لكل طلب في الفترة؛ trial إذا احتوى الطلب سطراً بماركة جديدة؛ category إذا احتوى سطراً من التصنيف؛ welcome عند اكتمال أول طلب تطبيق. `profile` عند حفظ حيوان مكتمل.
- الإكمال → `completed` ثم المكافأة فوراً (`rewarded`): بصمات (سبب `mission`, ref `mission:{id}`) أو منحة `active`.
- مهمات الشهر السابق تصير `expired` عند تعيين الشهر الجديد.

### 3.6 المنح والاستبدال والمطالبة
- `redeem`: `paws_balance ≥ paws_cost`، `min_tier` محقّق، `monthly_cap` غير مستنفد → منحة `active` (`expires_at = now + validity_days`) + قيد `redeem` بسالب التكلفة (ref `grant:{id}`).
- **المطالبة في السلة** (`claim`): تُخزَّن في جلسة WC تحت `zb_loyalty_claims` (قائمة grant ids) وتغيّر الحالة إلى `claimed`:
  - `gift_product`: يضيف سطراً للسلة بـ `cart_item_data['zb_grant_id']`، كمية 1 مقفلة (تجاهل update للسطر، الحذف = إلغاء المطالبة → `active`). السعر 0 عبر `woocommerce_before_calculate_totals` (`set_price(0)`). يجب أن يكون المنتج متاحاً في موقع العميل (`Zooboxi_Fulfillment`) وإلا `gift_unavailable` 409.
  - `free_delivery`: لا سطر؛ الفلتر `zooboxi_free_shipping_min` يعيد 0 ما دامت المطالبة في الجلسة.
  - `express_free`: لا سطر؛ الفلتر `zooboxi_express_fee` يعيد 0 ما دامت المطالبة في الجلسة (بلا أثر إن كان العميل خارج نطاق السريع — يُذكر ذلك في `reason`).
- عند `woocommerce_checkout_order_processed`: كل منحة claimed في الجلسة → `redeemed` مع `redeemed_order_id`؛ سطر الهدية يحصل على `_zb_gift_grant` + ميتا ظاهرة «هدية» + الاسم «🎁 هدية · {اسم المنتج}». تُمسح الجلسة.
- إلغاء الطلب قبل الاكتمال → المنحة تعود `active` إن لم تنتهِ.
- الكرون اليومي: `active`/`claimed` متجاوزة `expires_at` → `expired` (وتُزال من الجلسة عند القراءة التالية).
- **المطالبة تُعتمد فقط لمستخدم موثّق** والمنحة له.

### 3.7 الميزانية والمؤشرات (للوحة الإعدادات)
- تكلفة الشهر = Σ `cost_sar` للمنح `redeemed` هذا الشهر + (بصمات صادرة هذا الشهر × `paw_value_sar` (افتراضي 0.03)).
- مبيعات الشهر من `wc_order_stats` (completed+processing).
- النسبة تُعرض مع السقف (`zooboxi_loyalty_budget_pct` 4).

---

## 4. واجهة `zooboxi/v2` — العقد

كل المسارات `private, no-store`. كل ما يلي يحتاج Bearer إلا ما يُذكر. الأخطاء بالمظروف المعتاد. أضف قسم «14. Loyalty» في `10-APP-API-V2.md` بهذا المحتوى.

### `GET /meta` — إضافة
```json
"features": { "...": true, "loyalty": true, "pets": true },
"loyalty": { "program_name_ar": "عائلة زوبوكسي", "program_name_en": "Zooboxi Family",
             "points_per_riyal": 1, "paw_value_sar": 0.03 }
```

### `GET /loyalty/summary`
```json
{ "member": { "joined_at": "…", "holdout": false, "referral_code": "ZB7K2QX" },
  "paws": { "balance": 1240, "pending": 120, "expires_at": "2027-09-01T00:00:00Z" },
  "tier": { "key": "star", "name": "مميّز", "name_en": "Star", "icon": "⭐", "c1": "#e8a765", "c2": "#d48644",
            "orders_12m": 5, "min": 4,
            "next": { "key": "gold", "name": "ذهبي", "min": 8, "orders_needed": 3 },
            "progress": 25,
            "perks": [ { "key": "free_min_150", "text": "الشحن المجاني من 150 ﷼", "active": true },
                       { "key": "express_free_always", "text": "توصيل سريع مجاني دائماً", "active": false, "from_tier": "gold" },
                       { "key": "free_delivery_always", "text": "توصيل مجاني بلا حد أدنى", "active": false, "from_tier": "amb" } ] },
  "missions": { "period": "2026-09", "active": 3, "completed": 1, "items": [ …MissionDTO (حتى 4) ] },
  "rewards": { "active_count": 2, "sealed_scratch": [ { "id": 88, "order_number": "32579" } ] },
  "pets": [ …PetDTO ],
  "counters": { "orders_total": 17, "orders_app": 3 } }
```
`pending` = بصمات بطاقات خدش مكشوفة لطلبات لم تكتمل بعد. لعضو holdout: `missions.items = []` و`sealed_scratch = []` و`member.holdout = true`.

### `GET /loyalty/ledger?page=1` → `{ "items": [ { "id", "delta", "balance_after", "reason", "ref_type", "ref_id", "note", "created_at" } ], "page", "has_more" }`

### `GET /loyalty/rewards`
```json
{ "catalog": [ RewardDTO ], "grants": [ GrantDTO ] }
```
RewardDTO: `{ "id", "kind", "title", "title_en", "description", "product": CardDTO|null, "paws_cost", "value_sar", "validity_days", "min_tier", "redeemable": true|false, "reason_ar"/"reason_en" (لماذا لا) }`
GrantDTO: `{ "id", "reward": RewardDTO, "source", "state", "expires_at", "activates_on_order": {"id","number"}|null, "claimed": bool }`

### `POST /loyalty/rewards/{id}/redeem` → `{ "grant": GrantDTO, "paws_balance": 640 }` · أخطاء: `insufficient_paws` 409، `tier_required` 403، `reward_unavailable` 409.
### `POST /loyalty/grants/{id}/claim` → `{ "cart": CartDTO, "grant": GrantDTO }` · أخطاء: `grant_not_active` 409، `gift_unavailable` 409، `already_claimed` 409.
### `DELETE /loyalty/grants/{id}/claim` → `{ "cart": CartDTO, "grant": GrantDTO }`

### `GET /loyalty/missions` → `{ "period": "2026-09", "items": [ MissionDTO ] }`
MissionDTO: `{ "id", "key", "kind", "title", "body", "target", "progress", "state", "reward": { "kind": "paws", "paws": 150 } | { "kind": "reward", "reward": RewardDTO }, "suggested_products": [CardDTO] (حتى 6 للـ trial/category)، "completed_at" }`

### `GET /loyalty/scratch` → `{ "cards": [ ScratchDTO ] }` (المختومة والمكشوفة خلال 30 يوماً)
### `POST /loyalty/scratch/{id}/reveal` → ScratchDTO
ScratchDTO: `{ "id", "order": {"id","number"}, "state", "prize": { "kind": "paws", "paws": 50 } | { "kind": "reward", "reward": RewardDTO, "grant_id" }, "settled": bool, "activation_hint_ar": "تُفعَّل عند تسليم الطلب", "activation_hint_en": "Activates when your order is delivered" }`

### الحيوانات
- `GET /pets` → `{ "pets": [PetDTO], "max": 3 }`
- `POST /pets` body `{ name, species, breed?, sex?, weight_kg?, birth_date? (YYYY-MM-DD), neutered?, avatar? }` → `{ "pet": PetDTO, "pets": [...], "paws_earned": 50 }`
- `PATCH /pets/{id}` نفس الجسم → `{ "pet", "pets", "paws_earned": 0|100 }` (100 عند اكتمال الملف أول مرة)
- `DELETE /pets/{id}` → `{ "pets": [...] }` (حذف ناعم)
- PetDTO: `{ "id", "name", "species", "breed", "sex", "weight_kg", "birth_date", "age_label" (مثل «سنتان و3 أشهر»/"2y 3m"), "neutered", "avatar", "photo_url", "is_complete", "birthday_in_days": int|null }`
- أخطاء: `pets_limit` 409، `pet_invalid` 422 مع `fields`.

### تعديلات موجودة
- **CartDTO** يضيف: `"loyalty": { "paws_to_earn": 240, "holdout": false, "claims": [ GrantDTO(claimed) ], "free_delivery_reason": null|"tier"|"reward", "express_free_reason": null|"tier"|"reward" }`، وكل سطر هدية: `"is_gift": true, "grant_id": 123, "locked_qty": true`.
- **`POST /checkout` (place)** يضيف في الرد: `"scratch_card": ScratchDTO|null` (مختومة)، و`"paws_to_earn"`.
- **`GET /orders/{id}`** يضيف `"loyalty": { "paws_earned": 240|null, "scratch_card_id": 88|null, "gift_lines": ["…"] }`.
- **`GET /home`**: في `DEFAULT_LAYOUT` أضف `['type' => 'family']` بعد `hero` مباشرة و`['type' => 'missions']` بعد `personal`. الرئيسية لا تحمل بيانات الولاء (تبقى قابلة للتخزين)؛ التطبيق يهيّئ البطاقتين من `/loyalty/summary` (للمسجّلين) كما يفعل مع `/home/feed`.
- **`POST /events`**: يقبل الأنواع الجديدة `loyalty_scratch`, `loyalty_mission`, `loyalty_redeem`, `loyalty_claim`, `pet_added`, `family_card` — أضفها إلى قائمة الأنواع المقبولة في Laravel `ZooboxiIntelligenceController::events` أيضاً.

---

## 5. الإدارة (WP admin، قائمة zooboxi → «🐾 عائلة زوبوكسي»)

صفحة واحدة بتبويبات (`includes/admin/class-zooboxi-loyalty-admin.php`، صلاحية `manage_woocommerce`):
1. **عام:** تفعيل البرنامج، points_per_riyal، paw_value_sar، expiry_months، holdout_pct، max_pets، budget_pct، species→category map، حدود المستويات، حد الشحن لمستوى star.
2. **الهدايا (الكتالوج):** جدول + نموذج إضافة/تعديل (kind، عناوين، معرّف المنتج/المتغير مع بحث WC AJAX `woocommerce_json_search_products_and_variations`، paws_cost، cost_sar، value_sar، validity_days، min_tier، monthly_cap، نشط).
3. **اخدش واربح:** محرّر جدول الأوزان (صفوف: النوع، القيمة/الهدية، الوزن، ) + معاينة الاحتمالات + التكلفة المتوقعة للبطاقة.
4. **المهمات:** تفعيل/تعطيل كل قالب + مكافأته (بصمات أو هدية من الكتالوج) + هدف frequency.
5. **المؤشرات:** الأعضاء، بصمات صادرة/مستبدلة/منتهية هذا الشهر، المنح بحالاتها، البطاقات المكشوفة، المهمات المكتملة، تكلفة الشهر مقابل المبيعات والسقف. **وصندوق «خط الأساس»**: آخر 365 يوماً من `wc_order_stats` (طلبات، عملاء، متوسط الطلب، نسبة العملاء المكرِّرين، توزيع العملاء حسب عدد الطلبات 1/2/3–5/6+، إعادة الشراء خلال 90 يوماً)، مع زر تحديث وتخزين 6 ساعات.
6. **البحث عن عضو:** بالجوال/المعرّف → الرصيد والدفتر والمنح والحيوانات + تعديل يدوي للرصيد (سبب `adjust` بملاحظة إلزامية).

**WP-CLI:** `wp zooboxi loyalty baseline` (نفس صندوق خط الأساس، JSON)، `wp zooboxi loyalty daily` (يشغّل الكرون)، `wp zooboxi loyalty seed-defaults` (يزرع كتالوجاً افتراضياً: ترقية توصيل سريع مجاني 250 بصمة، توصيل مجاني بلا حد أدنى 400، هدية صغيرة 600، هدية متوسطة 1500، صندوق مفاجآت 3000 — بمنتجات فارغة يكملها المالك).

---

## 6. الإضافة — البنية

```
includes/loyalty/
  class-zooboxi-loyalty.php            ← التسجيل، الخيارات، الفلاتر، الكرون، تحميل البقية
  class-zooboxi-loyalty-schema.php     ← الجداول (maybe_install)
  class-zooboxi-loyalty-members.php    ← ensure/holdout/tier cache
  class-zooboxi-loyalty-ledger.php     ← earn/spend/reverse/expire + balance
  class-zooboxi-loyalty-tiers.php      ← الحدود، المزايا، الفلاتر (free min + account tiers)
  class-zooboxi-loyalty-pets.php       ← CRUD + validation + DTO
  class-zooboxi-loyalty-rewards.php    ← الكتالوج + المنح + المطالبة + سطر الهدية
  class-zooboxi-loyalty-scratch.php    ← الإنشاء/السحب/الكشف/التسوية
  class-zooboxi-loyalty-missions.php   ← القوالب/التعيين/التقدّم/المكافأة
  class-zooboxi-loyalty-hooks.php      ← order status transitions, checkout processed, cart hooks
  class-zooboxi-loyalty-cli.php
api/v2/class-zooboxi-v2-loyalty-controller.php
admin/class-zooboxi-loyalty-admin.php
```
- التسجيل الذاتي في `class-zooboxi-plugin.php` بجانب `intelligence` (require + instantiate) وخلف خيار `zooboxi_loyalty_enabled` (افتراضي `yes`).
- كل الهوكات على الطلبات تتحقق من `customer_id > 0`.
- **لا تعتمد على قيم الرسوم الحالية** (express = 0 مؤقت للتجربة). كل منطق الرسوم يمر بالفلترين فقط.
- الأداء: `summary` ≤ 6 استعلامات؛ المستوى مخزَّن مؤقتاً ويُبطل عند تغيّر حالة الطلب.
- **`scripts/v2_smoke.sh`**: أضف فحوصات: `/meta` يحمل `features.loyalty`؛ `/loyalty/summary` بلا توكن → 401؛ `/pets` بلا توكن → 401؛ ومع `TOKEN_USER3`: summary 200 بمفاتيح `paws/tier/missions`، `/loyalty/rewards` 200، `/pets` 200.

---

## 7. التطبيق — البنية والشاشات

```
lib/features/loyalty/
  data/loyalty_models.dart        ← LoyaltySummary, TierInfo, Mission, Reward, Grant, ScratchCard, LedgerEntry
  data/loyalty_repository.dart    ← كل المسارات أعلاه + providers (summary autoDispose+keepAlive على الجلسة، missions, rewards, ledger)
  presentation/family_hub_screen.dart     ← /family
  presentation/rewards_screen.dart        ← /family/rewards
  presentation/ledger_screen.dart         ← /family/ledger
  presentation/scratch_screen.dart        ← /family/scratch/:id (وأيضاً مضمّنة في نجاح الطلب)
  presentation/widgets/tier_card.dart, paws_pill.dart, mission_card.dart, reward_card.dart, grant_card.dart,
                       scratch_canvas.dart (CustomPainter + GestureDetector, كشف عند ≥55%), claim_reward_sheet.dart
lib/features/pets/
  data/pet_models.dart, data/pets_repository.dart
  presentation/pets_screen.dart (/pets), pet_editor_screen.dart (/pets/new, /pets/:id), widgets/species_avatar.dart, pet_card.dart
lib/features/home/presentation/widgets/family_card.dart, missions_strip.dart
```

### السلوك
- **الرئيسية:** slot `family` → `FamilyCard`: ضيف → دعوة «أضف حيوانك وابدأ جمع البصمات» (يفتح تسجيل الدخول ثم `/pets/new`)؛ مسجّل بلا حيوان → نفس الدعوة مع رصيد البصمات؛ مع حيوان → الصورة الرمزية + الاسم + سطر الحالة: إن كان في `/home/feed` منتج `due` → «حان وقت إعادة طلب {منتج}» مع زر «اطلب الآن» (يضيف للسلة)، وإلا أقرب مهمة نشطة بتقدّمها، وإلا شارة المستوى والرصيد. slot `missions` → `MissionsStrip` أفقي (يختفي للضيف/holdout/لا مهمات).
- **الحساب:** رأس الحساب يعرض للمسجّل شارة المستوى + الرصيد (يفتح `/family`). عنصران جديدان في القسم الأول: «عائلة زوبوكسي» (/family) و«عائلتي» (/pets).
- **مركز العائلة `/family`:** بطاقة المستوى (اسم، تقدّم، الطلبات المتبقية، المزايا بحالتها) · رصيد البصمات + «كيف أكسب» (ورقة توضيحية) · بطاقات خدش مختومة (إن وُجدت) · مهمات الشهر (بطاقات بتقدّم ومكافأة ومنتجات مقترحة) · مكافآتي النشطة (مع الصلاحية وزر «استخدم في السلة») · كتالوج الاستبدال (بطاقات: العنوان، التكلفة بالبصمات، القيمة، زر استبدال بتأكيد) · رابط السجل.
- **الحيوانات `/pets`:** قائمة بطاقات + إضافة (حتى 3). المحرّر: اختيار النوع بصور رمزية مرسومة (`SpeciesAvatar` بـ CustomPainter بنفس لغة الأيقونات المرسومة في `core/icons` — لا إيموجي)، الاسم، السلالة، الوزن (stepper 0.1 كجم)، تاريخ الميلاد (منتقي تاريخ)، الجنس، معقّم. حفظ → toast بالبصمات المكتسبة.
- **السلة:** سطر الهدية: صورة + الاسم + شارة «هدية» + السعر «مجاناً» بلا stepper، الحذف = إلغاء المطالبة. سطر في بطاقة الإجماليات «ستكسب {n} بصمة». زر «استخدم مكافأة» (يظهر فقط للمسجّل مع منح نشطة) → ورقة بالمنح النشطة → مطالبة → تحديث السلة. شارة الشحن المجاني تذكر السبب عند `free_delivery_reason`.
- **نجاح الطلب:** إن عاد `scratch_card` → تحت علامة النجاح بطاقة خدش مضمّنة (رقاقة تيل بنقش بصمات، نص «اخدش واربح») تُخدش بالإصبع؛ عند الكشف: Sparkles + الجائزة + «تُفعَّل عند تسليم الطلب» + زر «رائع». إن لم يخدش وغادر، تظهر في `/family` كمختومة.
- **الأحداث:** `loyalty_scratch` (zone `checkout`, payload {card_id, prize_kind})، `loyalty_mission` ({mission_id, state})، `loyalty_redeem` ({reward_id})، `loyalty_claim` ({grant_id})، `pet_added` ({species})، `family_card` ({variant}).
- **الحالات:** كل شاشة لها skeleton/empty/error عبر `AsyncView`/`EmptyState`. الضيف على `/family` يرى شاشة دعوة أنيقة لا خطأ 401.
- **i18n:** كل النصوص في `app_ar.arb` + `app_en.arb` (المفاتيح بادئة `family*`, `paws*`, `mission*`, `reward*`, `scratch*`, `pet*`). الأرقام والتواريخ عبر `formatters.dart`.
- **الاختبارات:** parsing للنماذج (summary كامل، holdout، pet age_label)، رياضيات تقدّم المستوى، widget test لبطاقة الخدش (الكشف يستدعي reveal مرة واحدة)، widget test لسطر الهدية في السلة (بلا stepper، سعر «مجاناً»)، FamilyCard بمتغيراته الأربعة، PetEditor validation.

---

## 8. Laravel (سطح صغير)
- `ZooboxiIntelligenceController::events`: قبول الأنواع الجديدة (القسم 4).
- لا تغيير في مرآة الطلبات: اسم سطر الهدية يبدأ بـ «🎁 هدية ·» فيظهر في التحضير وSAP كما هو.

---

## 9. النشر (يقوم به المراجع، لا الوكلاء)
المتجر: scp جراحي لملفات `includes/loyalty/*`, `includes/admin/class-zooboxi-loyalty-admin.php`, `includes/api/v2/class-zooboxi-v2-loyalty-controller.php`, والملفات المعدّلة (plugin, catalog, cart, checkout, orders, meta controllers, delivery engine, shipping ×3, smart shipments) — بعد مقارنة كل ملف معدّل بنسخته الحيّة. ثم `wp zooboxi loyalty seed-defaults` و`wp eval 'Zooboxi_Loyalty_Schema::maybe_install();'` وتشغيل `scripts/v2_smoke.sh`. التطبيق: TestFlight.

## 10. معايير القبول
- الطلب المكتمل من التطبيق يكسب بصمات مرة واحدة فقط، وإلغاؤه بعد الاكتمال يعكسها.
- بطاقة خدش لكل طلب تطبيق لعضو غير holdout، تُكشف مرة واحدة، جائزتها تتفعّل عند الاكتمال فقط.
- منحة هدية تُطالَب → سطر بسعر صفر في السلة والطلب باسم «🎁 هدية ·»، والمخزون ينقص، والمنحة `redeemed` مرتبطة بالطلب.
- منحة توصيل مجاني تُطالَب → رسوم أي مستوى توصيل تصبح 0 في السلة والطلب. منحة ترقية سريع تُطالَب → رسم express فقط يصبح 0 (والرسوم الأخرى كما هي).
- مستوى gold يصفّر رسم express دائماً في السلة والـ meta وطريقة الشحن السريع؛ مستوى amb يصفّر كل الرسوم.
- المستوى star يرفع حد الشحن المجاني إلى 150 في السلة والـ meta وطرق الشحن.
- عضو holdout: لا بطاقة، لا مهمات، لكن بصمات ومستوى.
- `flutter analyze` صفر، اختبارات التطبيق خضراء، `php -l` على كل ملف PHP، `v2_smoke.sh` أخضر محلياً في وضع الضيف.
