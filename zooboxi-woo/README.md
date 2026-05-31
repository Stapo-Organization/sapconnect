# 🐾 Zooboxi — Pet Store (WooCommerce)

> متجر منتجات الحيوانات الأليفة المربوط بنظام المستودعات المركزي (sapconnect)

---

## نظرة عامة

**Zooboxi** هو متجر إلكتروني مبني على **WordPress + WooCommerce** لبيع منتجات الحيوانات الأليفة في السعودية. يتميز المتجر بنظام **Multi-Warehouse ذكي** يحدد المستودع الأنسب بناءً على موقع العميل، مع دعم **التوصيل السريع خلال ساعتين** و**التوصيل العادي**.

## 🏗 البنية المعمارية

```
┌─────────────────────────────────────────────────────┐
│                   العملاء (Frontend)                 │
│               WordPress + WooCommerce                │
│            ثنائي اللغة (عربي/إنجليزي)                │
└─────────────┬───────────────────────────┬───────────┘
              │                           │
              ▼                           ▼
┌─────────────────────┐     ┌─────────────────────────┐
│  WooCommerce REST   │     │   Zooboxi Custom Plugin  │
│       API           │     │  (Multi-Warehouse Logic) │
└────────┬────────────┘     └────────┬────────────────┘
         │                           │
         ▼                           ▼
┌──────────────────────────────────────────────────────┐
│              sapconnect Sync Layer (API)              │
│  Products │ Warehouses │ Stock │ Orders │ Prices      │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────┐
│                 SAP Business One                      │
│          (Source of Truth for Inventory)              │
└──────────────────────────────────────────────────────┘
```

## 📁 هيكل المشروع

```
zooboxi-woo/
├── README.md                          # أنت هنا
├── docs/
│   ├── 01-PROJECT-OVERVIEW.md         # نظرة شاملة على المشروع
│   ├── 02-DATABASE-SCHEMA.md          # خريطة قاعدة البيانات و العلاقات
│   ├── 03-MULTI-WAREHOUSE.md          # نظام المستودعات الذكي والتوصيل
│   ├── 04-SYNC-ENGINE.md             # محرك المزامنة (sapconnect ↔ WooCommerce)
│   ├── 05-WOOCOMMERCE-SETUP.md       # إعداد WordPress + WooCommerce
│   ├── 06-PAYMENTS-SHIPPING.md       # بوابات الدفع وطرق الشحن
│   ├── 07-THEME-CUSTOMIZATION.md     # تخصيص التصميم والهوية البصرية
│   ├── 08-PLUGIN-ARCHITECTURE.md     # بنية البلقن المخصص
│   └── 09-DEPLOYMENT-CHECKLIST.md    # خطة النشر
├── plugin/                            # Zooboxi WordPress Plugin
│   └── zooboxi-multi-warehouse/       # (سيتم البناء)
├── theme/                             # تخصيصات الثيم
│   └── zooboxi-child/                 # (Child Theme)
└── scripts/                           # سكربتات المزامنة والنشر
```

## 🎯 الميزات الرئيسية

| الميزة | الوصف |
|--------|-------|
| 🏪 Multi-Warehouse | كل فرع/مستودع يخدم منطقة جغرافية محددة |
| 🚀 توصيل سريع (2 ساعة) | العميل داخل نطاق المستودع = توصيل خلال ساعتين |
| 📦 توصيل عادي (24 ساعة) | مستودع مركزي في نفس المدينة |
| 🚚 شحن (4 أيام) | شحن من المستودع المركزي لمدن أخرى |
| 🏬 Click & Collect | استلام من الفرع |
| 🔄 مزامنة SAP | منتجات + مخزون + أسعار من SAP تلقائياً |
| 🌐 ثنائي اللغة | عربي + إنجليزي (WPML/Polylang) |
| 💳 دفع إلكتروني | Tamara + Apple Pay + مدى |
| 🛵 توصيل داخلي | سائقين خاصين للتوصيل السريع |

## 🔗 الروابط المهمة

- **sapconnect API**: `https://sapapi.muntajat.sa/api/`
- **Store API** (الحالي): `/api/store/brands`, `/api/store/products`
- **صور المنتجات**: `https://ppte.sa/imghd/{prefix}/{item_code}.png`

## 🗃 مصدر البيانات (sapconnect)

| الجدول | الوصف |
|--------|-------|
| `products` | المنتجات (item_code, item_name, foreign_name, prices) |
| `brands` | البراندات (code, name) |
| `warehouses` | المستودعات (warehouse_code, warehouse_name) |
| `warehouse_item_stocks` | كمية كل منتج في كل مستودع (item_code, warehouse_code, in_stock) |
| `customers` | العملاء |

## 🚀 البدء السريع

```bash
# 1. إعداد WordPress
# (راجع 05-WOOCOMMERCE-SETUP.md)

# 2. تفعيل البلقن
# (راجع 08-PLUGIN-ARCHITECTURE.md)

# 3. تشغيل أول مزامنة
# (راجع 04-SYNC-ENGINE.md)
```

---

> 📌 **ملاحظة**: هذا المشروع مستقل عن تطبيق Flutter (pets_customer_app) ولكن يشارك نفس قاعدة البيانات (sapconnect)
