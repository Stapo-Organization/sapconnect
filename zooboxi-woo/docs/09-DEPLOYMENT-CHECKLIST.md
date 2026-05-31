# 09 — خطة النشر والتشغيل (Deployment Checklist)

## المراحل

```
Phase 1: التأسيس (أسبوع 1-2)
├── إعداد الاستضافة والدومين
├── تثبيت WordPress + WooCommerce
├── تثبيت وتكوين WPML
└── إعداد البيئة التطويرية

Phase 2: البلقن المخصص (أسبوع 2-4)
├── تطوير Zooboxi Multi-Warehouse Plugin
├── إعداد API في sapconnect
├── ربط المزامنة الأولية
└── اختبار المخزون والأسعار

Phase 3: التصميم (أسبوع 3-5)
├── إعداد Child Theme
├── تصميم الصفحة الرئيسية
├── تخصيص صفحات المنتجات
└── تصميم صفحة الدفع

Phase 4: التكاملات (أسبوع 5-6)
├── ربط بوابات الدفع (Tamara + مدى)
├── ربط شركات الشحن
├── إعداد الإشعارات
└── اختبار الدفع (Sandbox)

Phase 5: الاختبار (أسبوع 6-7)
├── اختبار المزامنة الكامل
├── اختبار التوصيل الذكي
├── اختبار بوابات الدفع
├── اختبار الأداء
└── اختبار الأمان

Phase 6: الإطلاق (أسبوع 7-8)
├── مراجعة نهائية
├── تحويل DNS
├── مراقبة أولية
└── إطلاق رسمي
```

---

## قائمة التحقق التفصيلية

### Phase 1: التأسيس

#### الاستضافة
- [ ] حجز الدومين `zooboxi.com`
- [ ] شراء/إعداد حساب استضافة (cPanel)
- [ ] تأكد من متطلبات PHP 8.1+ / MySQL 8.0+
- [ ] إعداد SSL (Let's Encrypt أو Premium)
- [ ] إعداد البريد الإلكتروني (info@zooboxi.com, noreply@zooboxi.com)
- [ ] إعداد Subdomain للتطوير: `dev.zooboxi.com`

#### WordPress
- [ ] تثبيت WordPress (أحدث نسخة)
- [ ] إعداد wp-config.php (Memory, Security, Cron)
- [ ] تغيير الـ Permalink إلى Post Name
- [ ] إعداد Media settings
- [ ] حذف المحتوى الافتراضي (Hello World, Sample Page)

#### WooCommerce
- [ ] تثبيت WooCommerce
- [ ] إعداد العنوان والعملة (SAR)
- [ ] إعداد الضريبة (VAT 15%)
- [ ] إعداد إدارة المخزون
- [ ] إنشاء الصفحات الأساسية (Shop, Cart, Checkout, My Account)

#### WPML
- [ ] تثبيت WPML + WooCommerce Multilingual
- [ ] إعداد اللغات (عربي = افتراضي, إنجليزي)
- [ ] إعداد URL Format (Directory: /en/)
- [ ] ترجمة الصفحات الأساسية

---

### Phase 2: البلقن المخصص

#### sapconnect API
- [ ] إنشاء Migration لإضافة حقل `woo_sync` لجدول `products`
- [ ] إنشاء Migration لإضافة `woo_product_id` و `woo_synced_at`
- [ ] إنشاء جدول `zooboxi_warehouses` (في sapconnect)
- [ ] إنشاء جدول `zooboxi_orders` (في sapconnect)
- [ ] إنشاء جدول `zooboxi_order_lines` (في sapconnect)
- [ ] إنشاء جدول `zooboxi_sync_logs` (في sapconnect)
- [ ] إنشاء `WooSyncController` في sapconnect
- [ ] إنشاء routes لـ `/api/woo/*`
- [ ] إنشاء middleware `auth.woo_token`
- [ ] إنشاء Models: ZooboxiWarehouse, ZooboxiOrder, ZooboxiOrderLine
- [ ] اختبار APIs بـ Postman/Insomnia

#### WordPress Plugin
- [ ] إنشاء هيكل البلقن (zooboxi-multi-warehouse)
- [ ] تطوير Zooboxi_Warehouse_Manager
- [ ] تطوير Zooboxi_Stock_Manager
- [ ] تطوير Zooboxi_Delivery_Engine (Haversine)
- [ ] تطوير Zooboxi_Sync_Engine
- [ ] تطوير Shipping Methods (4 أنواع)
- [ ] إعداد WP-Cron للمزامنة
- [ ] اختبار المزامنة الأولية

---

### Phase 3: التصميم

- [ ] اختيار وتثبيت Block Theme أساسي
- [ ] إنشاء Child Theme (zooboxi-child)
- [ ] إعداد theme.json (ألوان، خطوط، تخطيط)
- [ ] تصميم الصفحة الرئيسية (Hero, Categories, Products)
- [ ] تصميم بطاقة المنتج مع شارة التوصيل
- [ ] تصميم صفحة المنتج مع معلومات التوصيل
- [ ] تصميم صفحة السلة
- [ ] تصميم صفحة الدفع
- [ ] تصميم نافذة تحديد الموقع
- [ ] تصميم شارة الموقع (Location Bar)
- [ ] تطبيق RTL والتأكد من التصميم بالعربي والإنجليزي
- [ ] Responsive Design (Mobile First)
- [ ] إنشاء Logo و Favicon

---

### Phase 4: التكاملات

#### بوابات الدفع
- [ ] التسجيل في Tamara كتاجر
- [ ] تثبيت Tamara WooCommerce Plugin
- [ ] اختبار Tamara في Sandbox
- [ ] اختيار بوابة الدفع (Moyasar/HyperPay/...)
- [ ] التسجيل وإعداد بوابة الدفع
- [ ] إعداد Apple Pay (Merchant ID, Certificate)
- [ ] إعداد مدى
- [ ] اختبار الدفع في Sandbox

#### الشحن
- [ ] التسجيل في SMSA Express (أو البديل)
- [ ] تثبيت Plugin شركة الشحن
- [ ] إعداد الأسعار والمناطق
- [ ] اختبار إنشاء شحنة

#### الإشعارات
- [ ] تخصيص قوالب إيميلات WooCommerce
- [ ] إعداد إشعارات SMS (اختياري)
- [ ] اختبار الإشعارات

---

### Phase 5: الاختبار

#### اختبار وظيفي
- [ ] تسجيل عميل جديد
- [ ] تصفح المنتجات
- [ ] تحديد الموقع (GPS + يدوي)
- [ ] إضافة منتج للسلة
- [ ] اختيار طريقة التوصيل
- [ ] إتمام الدفع (كل البوابات)
- [ ] استقبال الطلب في sapconnect
- [ ] تحديث حالة الطلب
- [ ] استلام من الفرع (Click & Collect)

#### اختبار المزامنة
- [ ] مزامنة منتجات جديدة من SAP
- [ ] تحديث مخزون تلقائي
- [ ] تحديث أسعار تلقائي
- [ ] إرسال طلب لـ SAP
- [ ] التعامل مع أخطاء المزامنة

#### اختبار الأداء
- [ ] PageSpeed Insights > 80
- [ ] TTFB < 1 second
- [ ] Mobile Usability: Pass
- [ ] Load test (50 concurrent users)

#### اختبار الأمان
- [ ] SSL صحيح (A+ on SSL Labs)
- [ ] Security headers configured
- [ ] Admin protection
- [ ] API token validation
- [ ] Input sanitization

#### اختبار التوافق
- [ ] Chrome (Desktop + Mobile)
- [ ] Safari (Desktop + Mobile)
- [ ] Firefox
- [ ] Edge
- [ ] iOS Safari
- [ ] Android Chrome

---

### Phase 6: الإطلاق

#### قبل الإطلاق
- [ ] إنشاء صفحات قانونية:
  - [ ] سياسة الخصوصية
  - [ ] الشروط والأحكام
  - [ ] سياسة الإرجاع والاستبدال
  - [ ] سياسة الشحن
- [ ] إعداد Google Analytics / Tag Manager
- [ ] إعداد Google Search Console
- [ ] إعداد sitemap.xml
- [ ] إنشاء robots.txt
- [ ] إعداد 404 page
- [ ] نسخ احتياطي كامل

#### الإطلاق
- [ ] تحويل DNS إلى الاستضافة
- [ ] التأكد من HTTPS يعمل
- [ ] التأكد من WooCommerce في وضع Live
- [ ] تحويل بوابات الدفع من Sandbox إلى Live
- [ ] إطلاق أول مزامنة حقيقية
- [ ] اختبار طلب حقيقي

#### بعد الإطلاق
- [ ] مراقبة Logs لمدة 48 ساعة
- [ ] مراقبة المزامنة
- [ ] مراقبة أداء الموقع
- [ ] مراقبة الطلبات
- [ ] التأكد من وصول الإيميلات

---

## Environment Variables

### sapconnect (.env) — إضافات:

```bash
# Zooboxi WooCommerce Integration
WOO_API_TOKEN=your_secure_token_here
WOO_STORE_URL=https://zooboxi.com
WOO_CONSUMER_KEY=ck_xxxxx
WOO_CONSUMER_SECRET=cs_xxxxx
WOO_WEBHOOK_SECRET=whsec_xxxxx
```

### WordPress (wp-config.php أو بلقن):

```php
// في لوحة تحكم البلقن أو wp-config
define('ZOOBOXI_API_URL', 'https://sapapi.muntajat.sa/api/woo');
define('ZOOBOXI_API_TOKEN', 'your_secure_token_here');
```

---

## Backup Strategy

```
Daily:   Full database backup (UpdraftPlus → Google Drive/S3)
Weekly:  Full files backup
Monthly: Full server snapshot

Retention: 30 days
```

---

## Monitoring

| العنصر | الأداة | التكرار |
|--------|--------|---------|
| Uptime | UptimeRobot / StatusCake | كل دقيقة |
| Performance | Google PageSpeed | أسبوعياً |
| Security | Wordfence Scan | يومياً |
| Sync Status | Zooboxi Dashboard | كل 5 دقائق |
| Orders | WooCommerce + sapconnect | فوري |
| Errors | WP Debug Log + sapconnect Log | فوري |
