# 07 — تخصيص التصميم والهوية البصرية

## هوية Zooboxi

### الألوان الأساسية:

| اللون | الكود | الاستخدام |
|-------|-------|----------|
| 🟢 أخضر رئيسي | `#2DB87B` | الأزرار، CTA، العناصر النشطة |
| 🟡 أصفر مميز | `#F5A623` | Badges، العروض، التنبيهات |
| ⚫ أسود داكن | `#1A1A2E` | النصوص، الخلفيات الداكنة |
| ⚪ رمادي فاتح | `#F8F9FA` | الخلفيات |
| 🔵 أزرق (Express) | `#3498DB` | شارات التوصيل السريع |

> **ملاحظة**: الألوان مقترحة — يمكن تعديلها بناءً على الهوية البصرية النهائية لـ Zooboxi

### الخطوط:

```css
/* العربي */
@import url('https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700&display=swap');

/* الإنجليزي */
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap');

:root {
    --font-ar: 'Tajawal', sans-serif;
    --font-en: 'Poppins', sans-serif;
}

/* RTL */
html[dir="rtl"] body {
    font-family: var(--font-ar);
}

/* LTR */
html[dir="ltr"] body {
    font-family: var(--font-en);
}
```

---

## اختيار الثيم

### الخيارات الموصى بها:

| الثيم | السعر | الأفضل لـ | RTL |
|-------|-------|----------|-----|
| **Flavor (flavor theme - مخصص)** | مجاني | تخصيص كامل | ✅ |
| **Flavor + Flavor Child** | مجاني | الطريقة الأفضل | ✅ |
| **Flavor + مطور خاص** | حسب المطور | أداء عالي وتميز | ✅ |

> **التوصية**: استخدام ثيم WooCommerce الرسمي (Flavor/Flavor child) أو Block theme حديث مع Full Site Editing (FSE) للاستفادة من أحدث إمكانيات WordPress

### Block Theme vs Classic Theme:

| الميزة | Block Theme (FSE) | Classic Theme |
|--------|-------------------|---------------|
| محرر الصفحات | Full Site Editing | Customizer |
| المرونة | عالية جداً | متوسطة |
| الأداء | ممتاز (أقل JS) | جيد |
| WooCommerce Block | ✅ أصلي | ✅ مع إضافات |
| RTL | يحتاج تخصيص | متوفر |
| التوافق المستقبلي | ✅ المعيار الجديد | يتراجع تدريجياً |

> **التوصية**: استخدام **Block Theme (FSE)** للاستفادة من أحدث إمكانيات WordPress

---

## Child Theme Structure

```
zooboxi-child/
├── style.css                    # Theme metadata + custom styles
├── functions.php                # Theme functions
├── theme.json                   # Block theme settings (colors, fonts, spacing)
├── templates/                   # Block templates (FSE)
│   ├── archive-product.html     # صفحة قائمة المنتجات
│   ├── single-product.html      # صفحة المنتج
│   ├── page-cart.html           # صفحة السلة
│   ├── page-checkout.html       # صفحة الدفع
│   └── front-page.html          # الصفحة الرئيسية
├── parts/                       # Template parts
│   ├── header.html              # الهيدر
│   ├── footer.html              # الفوتر
│   ├── delivery-badge.html      # شارة التوصيل
│   └── warehouse-selector.html  # اختيار المستودع
├── assets/
│   ├── css/
│   │   ├── zooboxi-base.css     # الأساسيات
│   │   ├── zooboxi-rtl.css      # تعديلات RTL
│   │   └── zooboxi-woo.css      # تخصيصات WooCommerce
│   ├── js/
│   │   ├── zooboxi-location.js  # تحديد الموقع
│   │   ├── zooboxi-delivery.js  # عرض معلومات التوصيل
│   │   └── zooboxi-cart.js      # تحسينات السلة
│   └── images/
│       ├── logo.svg             # شعار Zooboxi
│       ├── logo-dark.svg        # شعار للوضع الداكن
│       └── icons/               # أيقونات مخصصة
└── woocommerce/                 # WooCommerce template overrides
    ├── content-product.php      # بطاقة المنتج في القائمة
    ├── single-product/          # تخصيصات صفحة المنتج
    │   ├── delivery-info.php    # معلومات التوصيل
    │   └── stock-per-warehouse.php # المخزون لكل مستودع
    └── checkout/                # تخصيصات صفحة الدفع
        └── delivery-options.php # خيارات التوصيل المخصصة
```

---

## theme.json (Block Theme Settings)

```json
{
    "$schema": "https://schemas.wp.org/wp/6.7/theme.json",
    "version": 3,
    "settings": {
        "color": {
            "palette": [
                {"slug": "primary", "color": "#2DB87B", "name": "Primary Green"},
                {"slug": "accent", "color": "#F5A623", "name": "Accent Yellow"},
                {"slug": "dark", "color": "#1A1A2E", "name": "Dark"},
                {"slug": "light", "color": "#F8F9FA", "name": "Light Background"},
                {"slug": "express", "color": "#3498DB", "name": "Express Blue"},
                {"slug": "white", "color": "#FFFFFF", "name": "White"}
            ]
        },
        "typography": {
            "fontFamilies": [
                {
                    "fontFamily": "'Tajawal', sans-serif",
                    "name": "Tajawal",
                    "slug": "tajawal",
                    "fontFace": [
                        {"fontFamily": "Tajawal", "fontWeight": "400", "src": ["https://fonts.googleapis.com/css2?family=Tajawal:wght@400"]},
                        {"fontFamily": "Tajawal", "fontWeight": "700", "src": ["https://fonts.googleapis.com/css2?family=Tajawal:wght@700"]}
                    ]
                },
                {
                    "fontFamily": "'Poppins', sans-serif",
                    "name": "Poppins",
                    "slug": "poppins"
                }
            ]
        },
        "spacing": {
            "units": ["px", "em", "rem", "%"]
        },
        "layout": {
            "contentSize": "1200px",
            "wideSize": "1400px"
        }
    },
    "styles": {
        "color": {
            "background": "var(--wp--preset--color--light)",
            "text": "var(--wp--preset--color--dark)"
        },
        "typography": {
            "fontFamily": "var(--wp--preset--font-family--tajawal)"
        },
        "elements": {
            "button": {
                "color": {
                    "background": "var(--wp--preset--color--primary)",
                    "text": "var(--wp--preset--color--white)"
                },
                "border": {
                    "radius": "8px"
                }
            },
            "link": {
                "color": {
                    "text": "var(--wp--preset--color--primary)"
                }
            }
        }
    }
}
```

---

## الصفحات الرئيسية

### 1. الصفحة الرئيسية (Homepage):

```
┌─────────────────────────────────────────────────────────┐
│  [Logo Zooboxi]  🔍 بحث...  🛒(3)  👤  📍 الرياض     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │     🐾 كل ما يحتاجه حيوانك الأليف               ││
│  │     توصيل سريع خلال ساعتين 🚀                     ││
│  │                                                     ││
│  │     [تسوق الآن]                                     ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
│  📂 التصنيفات                                          │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐         │
│  │ 🐱   │ │ 🐶   │ │ 🐦   │ │ 🐟   │ │ 🐹   │         │
│  │قطط   │ │كلاب  │ │طيور  │ │أسماك │ │قوارض │         │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘         │
│                                                         │
│  🔥 الأكثر مبيعاً                                      │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐          │
│  │[صورة]  │ │[صورة]  │ │[صورة]  │ │[صورة]  │          │
│  │منتج 1  │ │منتج 2  │ │منتج 3  │ │منتج 4  │          │
│  │45 ر.س  │ │32 ر.س  │ │78 ر.س  │ │120 ر.س │          │
│  │🚀 2 ساعة│ │📦 24 ساعة│ │🚀 2 ساعة│ │📦 24 ساعة│          │
│  └────────┘ └────────┘ └────────┘ └────────┘          │
│                                                         │
│  🏷️ عروض خاصة                                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │  خصم 20% على جميع أطعمة القطط! الكود: PET20      ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
│  🆕 وصل حديثاً                                         │
│  [Grid of new products]                                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Footer: روابط | سياسات | تواصل | سوشل ميديا          │
└─────────────────────────────────────────────────────────┘
```

### 2. صفحة المنتج:

```
┌─────────────────────────────────────────────────────────┐
│  الرئيسية > طعام قطط > Royal Canin Indoor 1kg          │
│                                                         │
│  ┌──────────────┐  ┌────────────────────────────────┐  │
│  │              │  │  Royal Canin Indoor Adult 1kg   │  │
│  │   [صورة      │  │  طعام جاف للقطط المنزلية       │  │
│  │    المنتج]   │  │                                │  │
│  │              │  │  ⭐⭐⭐⭐⭐ (23 تقييم)           │  │
│  │              │  │                                │  │
│  │  [ثم صور     │  │  💰 45.00 ر.س (شامل الضريبة)  │  │
│  │   أصغر]     │  │  أو 3 أقساط × 15 ر.س مع تمارا  │  │
│  │              │  │                                │  │
│  └──────────────┘  │  📍 التوصيل إلى: حي النرجس     │  │
│                    │  ┌────────────────────────────┐ │  │
│                    │  │ 🚀 توصيل سريع: ساعتين     │ │  │
│                    │  │    ✅ متوفر (25 قطعة)      │ │  │
│                    │  │ 📦 توصيل عادي: 24 ساعة    │ │  │
│                    │  │ 🏬 استلام: معرض العليا     │ │  │
│                    │  └────────────────────────────┘ │  │
│                    │                                │  │
│                    │  الكمية: [- 1 +]               │  │
│                    │                                │  │
│                    │  [🛒 أضف للسلة]  [❤️]          │  │
│                    └────────────────────────────────┘  │
│                                                         │
│  📋 التفاصيل  |  📊 المواصفات  |  ⭐ التقييمات        │
│  ─────────────────────────────────────────────────────  │
│  طعام جاف مخصص للقطط المنزلية البالغة...               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Custom CSS Examples

### بطاقة المنتج:

```css
.zooboxi-product-card {
    border-radius: 12px;
    overflow: hidden;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    background: #fff;
    border: 1px solid #eee;
}

.zooboxi-product-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 24px rgba(0,0,0,0.1);
}

.zooboxi-delivery-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 500;
}

.zooboxi-delivery-badge--express {
    background: rgba(52, 152, 219, 0.1);
    color: #3498DB;
}

.zooboxi-delivery-badge--standard {
    background: rgba(45, 184, 123, 0.1);
    color: #2DB87B;
}
```

### شارة الموقع:

```css
.zooboxi-location-bar {
    position: sticky;
    top: 0;
    z-index: 100;
    background: linear-gradient(135deg, #1A1A2E, #2C3E50);
    color: white;
    padding: 8px 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-size: 14px;
}

.zooboxi-location-bar__icon {
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}
```
