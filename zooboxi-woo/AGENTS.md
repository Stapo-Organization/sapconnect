# AGENTS.md — Zooboxi WooCommerce Plugin

## 📌 نظرة عامة

هذا المشروع هو **متجر WooCommerce مخصص** لمنتجات الحيوانات الأليفة (Zooboxi). يتكون من:
- **WordPress Plugin:** zooboxi-multi-warehouse
- **Theme:** zooboxi-child (قيد التطوير)
- **Docs:** توثيق شامل لكل جزء

## 🏗️ الهيكل المعماري

```
zooboxi-woo/
├── plugin/
│   └── zooboxi-multi-warehouse/
│       ├── zooboxi-multi-warehouse.php      # Main plugin file
│       ├── includes/
│       │   ├── class-zooboxi-plugin.php     # Singleton pattern
│       │   ├── class-zooboxi-activator.php  # Activation hooks
│       │   ├── class-zooboxi-deactivator.php
│       │   ├── core/
│       │   │   ├── class-zooboxi-warehouse-manager.php
│       │   │   ├── class-zooboxi-stock-manager.php
│       │   │   ├── class-zooboxi-delivery-engine.php
│       │   │   ├── class-zooboxi-location-detector.php
│       │   │   └── class-zooboxi-geo-helper.php
│       │   ├── sync/
│       │   │   ├── class-zooboxi-sync-engine.php
│       │   │   └── class-zooboxi-logger.php
│       │   ├── shipping/
│       │   │   ├── class-zooboxi-express-shipping.php
│       │   │   ├── class-zooboxi-standard-shipping.php
│       │   │   ├── class-zooboxi-national-shipping.php
│       │   │   └── class-zooboxi-pickup-shipping.php
│       │   ├── admin/
│       │   │   ├── class-zooboxi-admin.php
│       │   │   ├── class-zooboxi-settings-page.php
│       │   │   └── class-zooboxi-sync-dashboard.php
│       │   ├── frontend/
│       │   │   ├── class-zooboxi-location-popup.php
│       │   │   ├── class-zooboxi-delivery-badge.php
│       │   │   └── class-zooboxi-checkout-customizer.php
│       │   ├── auth/
│       │   │   ├── class-zooboxi-otp-auth.php
│       │   │   └── class-zooboxi-taqnyat.php
│       │   └── api/
│       │       ├── class-zooboxi-rest-controller.php
│       │       └── class-zooboxi-webhook-handler.php
│       ├── admin/
│       │   ├── css/zooboxi-admin.css
│       │   ├── js/zooboxi-admin.js
│       │   └── views/
│       └── public/
│           ├── css/zooboxi-public.css
│           └── js/zooboxi-public.js
├── theme/
│   └── zooboxi-child/
├── docs/
│   ├── 01-PROJECT-OVERVIEW.md
│   ├── 02-DATABASE-SCHEMA.md
│   ├── 03-MULTI-WAREHOUSE.md
│   ├── 04-SYNC-ENGINE.md
│   ├── 05-WOOCOMMERCE-SETUP.md
│   ├── 06-PAYMENTS-SHIPPING.md
│   ├── 07-THEME-CUSTOMIZATION.md
│   ├── 08-PLUGIN-ARCHITECTURE.md
│   └── 09-DEPLOYMENT-CHECKLIST.md
├── category_translations.json
└── product_translations.json
```

## 🔧 التقنيات المستخدمة

| التقنية | الإصدار | الاستخدام |
|---------|---------|-----------|
| WordPress | ^6.5 | CMS |
| WooCommerce | ^9.0 | E-commerce |
| PHP | ^8.1 | Plugin Language |
| JavaScript | ES6+ | Frontend |
| CSS3 | — | Styling |

## 🧑‍💼 أنماط التطوير

### 1. Plugin Structure
- **Namespace Prefix:** `Zooboxi_` (Class names)
- **File Prefix:** `class-zooboxi-{name}.php`
- **Autoloader:** Custom SPL autoloader (in main plugin file)
- **Singleton Pattern:** `Zooboxi_Plugin::instance()`

### 2. Class Naming Convention
```php
// Core classes
Zooboxi_Warehouse_Manager
Zooboxi_Stock_Manager
Zooboxi_Delivery_Engine

// Frontend classes
Zooboxi_Location_Popup
Zooboxi_Checkout_Customizer

// Shipping classes
Zooboxi_Express_Shipping
Zooboxi_Standard_Shipping
```

### 3. API Integration with sapconnect
```php
// Base URL
$sapconnect_api = 'https://sapapi.muntajat.sa/api/woo';

// Authentication
$headers = [
    'Authorization' => 'Bearer ' . get_option('zooboxi_api_token'),
    'Content-Type'  => 'application/json',
];
```

### 4. Warehouse Detection Flow
```
1. User visits site → Location Popup
2. GPS detection (browser geolocation)
3. Fallback: City selector dropdown
4. Haversine distance calculation
5. Stock availability check
6. Display delivery options
```

### 5. Sync Engine Flow
```
Cron Job (every 5-10 minutes):
1. Fetch products from sapconnect → Update WooCommerce products
2. Fetch stock from sapconnect → Update WooCommerce stock
3. Fetch prices from sapconnect → Update WooCommerce prices
4. Push pending orders → sapconnect → SAP
```

## 🏪 Delivery Tiers

| Tier | Time | Condition | Fee |
|------|------|-----------|-----|
| Express | ≤2 hours | Within express_radius_km | 15 SAR |
| Same-Day | ≤24 hours | Central warehouse in city | 10 SAR |
| Shipping | 2-4 days | National from main hub | 25 SAR |
| Pickup | 1-2 hours | Customer collects | Free |

## 📝 اصطلاحات الكود

### إضافة Shipping Method جديد:
```php
// في includes/shipping/
class Zooboxi_New_Shipping_Method extends WC_Shipping_Method {
    public function __construct($instance_id = 0) {
        $this->id = 'zooboxi_new';
        $this->method_title = __('Zooboxi New', 'zooboxi');
        // ...
    }
}
```

### إضافة REST Endpoint:
```php
// في includes/api/class-zooboxi-rest-controller.php
add_action('rest_api_init', function () {
    register_rest_route('zooboxi/v1', '/endpoint', [
        'methods' => 'GET',
        'callback' => [Zooboxi_REST_Controller::class, 'handleEndpoint'],
    ]);
});
```

## 🧪 الاختبارات

- اختبار الموقع الجغرافي: استخدام أدوات DevTools → Sensors
- اختبار المخزون: WooCommerce → Status → Tools → Regenerate stock
- اختبار المزامنة: زر "Force Sync" في لوحة التحكم

## 🚀 Deploy

1. رفع ملفات البلقن إلى `/wp-content/plugins/zooboxi-multi-warehouse/`
2. تفعيل البلقن من WordPress Admin
3. إدخال API Token في الإعدادات
4. إعداد المستودعات في Zooboxi Settings
5. تشغيل أول مزامنة

## 🌐 اللغة

- المتجر: عربي + إنجليزي (WPML/Polylang)
- البلقن: Text Domain = `zooboxi`
- RTL Support: مفعل افتراضياً

## ⚠️ ملاحظات مهمة

1. **HPOS Compatible:** البلقن يدعم WooCommerce High-Performance Order Storage
2. **Session Storage:** موقع العميل يُخزن في Session + Cookie
3. **Stock Cache:** المخزون يُخزن مؤقتاً لمدة 5 دقائق
4. **API Token:** لا تُخزن في الكود — استخدم WordPress Options
5. **SAP Mapping:** Zooboxi warehouse codes تختلف عن SAP warehouse codes

## 🔗 روابط مهمة

- **sapconnect API:** `https://sapapi.muntajat.sa/api/woo`
- **Product Images:** `https://ppte.sa/imghd/{prefix}/{item_code}.png`
- **Docs:** `./docs/`
