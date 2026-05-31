# 05 — إعداد WordPress + WooCommerce

## متطلبات الاستضافة (cPanel)

### الحد الأدنى المطلوب:

| المتطلب | الحد الأدنى | الموصى به |
|---------|------------|----------|
| PHP | 8.1 | 8.2+ |
| MySQL | 5.7 | 8.0+ |
| Memory Limit | 256MB | 512MB+ |
| Max Execution Time | 120s | 300s |
| Upload Max Filesize | 64MB | 128MB |
| Post Max Size | 64MB | 128MB |
| SSL | مطلوب | Let's Encrypt / Premium |

### إعدادات PHP الموصى بها (`php.ini` أو `.user.ini`):

```ini
memory_limit = 512M
max_execution_time = 300
upload_max_filesize = 128M
post_max_size = 128M
max_input_vars = 5000
```

---

## 1. تثبيت WordPress

### الدومين:
```
https://zooboxi.com          # الدومين الرئيسي
https://www.zooboxi.com      # redirect to non-www
```

### عبر cPanel:
1. **Softaculous** → WordPress → Install
2. أو تثبيت يدوي:

```bash
# تحميل WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* ./

# إنشاء قاعدة البيانات
# من cPanel → MySQL Databases:
# DB Name: zooboxi_wp
# DB User: zooboxi_user
# DB Pass: [strong_password]
```

### wp-config.php:

```php
// أداء
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// أمان
define('DISALLOW_FILE_EDIT', true);
define('WP_AUTO_UPDATE_CORE', 'minor');

// Cron (لأن WP-Cron بطيء على Shared Hosting)
define('DISABLE_WP_CRON', true);
// استخدم System Cron بدلاً من ذلك (راجع قسم Cron أدناه)

// Debug (في التطوير فقط)
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

// الأداء
define('WP_POST_REVISIONS', 5);
define('EMPTY_TRASH_DAYS', 7);
define('AUTOSAVE_INTERVAL', 120);

// SSL
define('FORCE_SSL_ADMIN', true);
```

---

## 2. تثبيت WooCommerce

### الإضافات الأساسية (Core Plugins):

| الإضافة | الغرض | نوع |
|---------|-------|-----|
| **WooCommerce** | المتجر الأساسي | مجاني |
| **WPML** أو **Polylang** | ثنائي اللغة | مدفوع/مجاني |
| **WPML WooCommerce Multilingual** | ترجمة المنتجات | مدفوع |
| **Tamara Checkout** | تقسيط | مجاني (من تمارا) |
| **Payment Gateway** (TBD) | Apple Pay + مدى | مدفوع |
| **Zooboxi Multi-Warehouse** | البلقن المخصص | مخصص |

### إضافات الأداء:

| الإضافة | الغرض |
|---------|-------|
| **LiteSpeed Cache** أو **WP Super Cache** | التخزين المؤقت |
| **Smush** أو **ShortPixel** | ضغط الصور |
| **Autoptimize** | تحسين CSS/JS |

### إضافات الأمان:

| الإضافة | الغرض |
|---------|-------|
| **Wordfence** أو **Sucuri** | حماية وجدار ناري |
| **UpdraftPlus** | نسخ احتياطي |

### إضافات SEO:

| الإضافة | الغرض |
|---------|-------|
| **Yoast SEO** أو **Rank Math** | تحسين محركات البحث |

---

## 3. إعدادات WooCommerce

### General:
```
Store Address:         [عنوان الشركة]
Country/Region:        Saudi Arabia
Currency:              Saudi Riyal (ر.س)
Currency Position:     Right with space (100 ر.س)
Thousand Separator:    ,
Decimal Separator:     .
Number of Decimals:    2
```

### Products:
```
Weight Unit:           kg
Dimensions Unit:       cm
Enable Reviews:        Yes
Stock Management:      Yes (managed by Zooboxi plugin)
```

### Tax:
```
Enable Tax:            Yes
Tax based on:          Shipping address
VAT Rate:              15% (ضريبة القيمة المضافة)
Display prices:        Including tax
```

### Shipping:
```
Shipping Zones:        Managed by Zooboxi Plugin
Shipping Methods:      Custom (Zooboxi Smart Shipping)
```

### Payments:
```
Tamara:                Enabled (تقسيط)
Apple Pay + مدى:       Enabled (بوابة TBD)
COD:                   Enabled (الدفع عند الاستلام)
Bank Transfer:         Disabled
```

### Checkout:
```
Guest Checkout:        Yes
Account Creation:      Optional
Order Number Format:   ZB-{number}
```

---

## 4. إعداد System Cron (بدل WP-Cron)

### في cPanel → Cron Jobs:

```bash
# تشغيل WP-Cron كل دقيقة (لمزامنة المخزون)
* * * * * /usr/local/bin/php /home/username/public_html/wp-cron.php > /dev/null 2>&1

# أو باستخدام wget
*/5 * * * * wget -q -O - https://zooboxi.com/wp-cron.php?doing_wp_cron > /dev/null 2>&1
```

> **ملاحظة**: على Shared Hosting، الحد الأدنى عادةً 5 دقائق للـ Cron

---

## 5. .htaccess المُحسّن

```apache
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress

# Security Headers
<IfModule mod_headers.c>
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set Referrer-Policy "strict-origin-when-cross-origin"
    Header set Permissions-Policy "camera=(), microphone=(), geolocation=(self)"
</IfModule>

# Cache Static Assets
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/font-woff2 "access plus 1 year"
</IfModule>

# Gzip Compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css
    AddOutputFilterByType DEFLATE application/javascript application/json
    AddOutputFilterByType DEFLATE application/font-woff2
</IfModule>

# Block xmlrpc
<Files xmlrpc.php>
    Order Deny,Allow
    Deny from all
</Files>

# Protect wp-config
<Files wp-config.php>
    Order Allow,Deny
    Deny from all
</Files>
```

---

## 6. إعدادات اللغة (WPML)

### التكوين:

```
Default Language:      Arabic (العربية)
Translation Languages: English
URL Format:            Directory (zooboxi.com/en/)
RTL Support:           Automatic
```

### ترجمة المنتجات:

| الحقل | العربي (من sapconnect) | الإنجليزي (من sapconnect) |
|-------|----------------------|--------------------------|
| Name | `item_name` | `foreign_name` |
| Description | يُضاف يدوياً أو AI | يُضاف يدوياً أو AI |
| Categories | `brand.name` (عربي) | `brand.name` (إنجليزي) |

---

## 7. إعدادات الإشعارات

### WooCommerce Emails:

| الإشعار | الحالة | المستلم |
|---------|--------|---------|
| New Order | ✅ | Admin + Warehouse |
| Processing | ✅ | Customer |
| Completed | ✅ | Customer |
| Cancelled | ✅ | Customer + Admin |
| Refunded | ✅ | Customer + Admin |
| Express Delivery | ✅ (Custom) | Customer |
| Ready for Pickup | ✅ (Custom) | Customer |

### SMS Notifications (مستقبلاً):

```
- تأكيد الطلب
- الطلب في الطريق
- تم التوصيل
- جاهز للاستلام (Click & Collect)
```

---

## 8. قائمة التحقق قبل الإطلاق

- [ ] WordPress مثبت ومحدث
- [ ] WooCommerce مفعل ومُعد
- [ ] SSL مفعل (HTTPS)
- [ ] WPML/Polylang مثبت
- [ ] Zooboxi Plugin مفعل
- [ ] بوابات الدفع مُعدة
- [ ] System Cron مُعد
- [ ] Security plugins مفعلة
- [ ] Cache plugin مُعد
- [ ] Backup مُعد
- [ ] SEO plugin مُعد
- [ ] خطة تسعير الشحن محددة
- [ ] صفحات قانونية (سياسة الخصوصية، الشروط)
- [ ] اختبار الدفع (Sandbox)
- [ ] اختبار المزامنة مع sapconnect
