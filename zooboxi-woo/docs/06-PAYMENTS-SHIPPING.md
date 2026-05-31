# 06 — بوابات الدفع وطرق الشحن

## بوابات الدفع

### 1. Tamara (تقسيط — اشترِ الآن وادفع لاحقاً)

**الوصف**: تقسيط المدفوعات على 3-4 أقساط بدون فوائد

**التكامل**:
- Plugin رسمي: [Tamara Checkout for WooCommerce](https://wordpress.org/plugins/tamara-checkout/)
- يتطلب حساب تاجر في Tamara

**الإعدادات**:
```
Tamara Settings:
├── Environment: Production (Sandbox للتجربة)
├── Merchant Token: {from Tamara dashboard}
├── API URL: https://api.tamara.co
├── Min Order Amount: 100 SAR
├── Max Order Amount: 5000 SAR
├── Number of Installments: 3-4
├── Payment Types: Pay in 3, Pay in 4, Pay Later
└── Country: Saudi Arabia
```

**تجربة العميل**:
```
┌──────────────────────────────────────────┐
│  اختر طريقة الدفع:                       │
│                                          │
│  ○ 💳 Tamara - اشترِ الآن وادفع لاحقاً   │
│     قسّط 300 ر.س على 3 أقساط           │
│     الدفعة الأولى: 100 ر.س اليوم        │
│     الدفعة الثانية: 100 ر.س بعد شهر     │
│     الدفعة الثالثة: 100 ر.س بعد شهرين   │
│                                          │
│  ○ 💳 Apple Pay / مدى                     │
│                                          │
│  ○ 💵 الدفع عند الاستلام                  │
│                                          │
└──────────────────────────────────────────┘
```

---

### 2. Apple Pay + مدى (بوابة لم تُحدد بعد)

**الخيارات المتاحة في السعودية**:

| البوابة | Apple Pay | مدى | Visa/MC | الرسوم | Plugin WooCommerce |
|---------|-----------|------|---------|--------|-------------------|
| **Moyasar** | ✅ | ✅ | ✅ | 2.0% + 0.50 SAR | ✅ رسمي |
| **HyperPay** | ✅ | ✅ | ✅ | 2.0% + 1.00 SAR | ✅ رسمي |
| **MyFatoorah** | ✅ | ✅ | ✅ | 2.0% + 0.50 SAR | ✅ رسمي |
| **PayTabs** | ✅ | ✅ | ✅ | 2.75% | ✅ رسمي |
| **Tap** | ✅ | ✅ | ✅ | 2.0% + 1.00 SAR | ✅ رسمي |

> **توصية**: **Moyasar** أو **HyperPay** — الأكثر استخداماً في السوق السعودي مع WooCommerce

**الإعداد (مثال Moyasar)**:
```
Moyasar Settings:
├── API Key (Publishable): pk_live_xxx
├── Secret Key: sk_live_xxx
├── Apple Pay Merchant ID: merchant.com.zooboxi
├── Apple Pay Certificate: (uploaded)
├── Supported Methods: mada, applepay, creditcard
├── 3D Secure: Enabled
└── Currency: SAR
```

---

### 3. الدفع عند الاستلام (COD)

**إعدادات WooCommerce المدمجة**:
```
COD Settings:
├── Enable: Yes
├── Title: 💵 الدفع عند الاستلام
├── Description: ادفع نقداً عند استلام طلبك
├── Instructions: يرجى تجهيز المبلغ المطلوب
├── Enable for shipping methods: 
│   ├── zooboxi_express ✅
│   ├── zooboxi_standard ✅
│   ├── zooboxi_shipping ❌ (معطل للشحن الخارجي)
│   └── zooboxi_pickup ✅
├── Min Order: 50 SAR
├── Max Order: 1000 SAR (لتقليل المخاطر)
└── Extra Fee: 10 SAR (رسوم إضافية)
```

---

## طرق الشحن والتوصيل

### 1. التوصيل السريع (Express — ساعتين)

```php
// Shipping Method Registration
class Zooboxi_Express_Shipping extends WC_Shipping_Method {
    
    public $id = 'zooboxi_express';
    
    public function __construct($instance_id = 0) {
        $this->instance_id = absint($instance_id);
        $this->method_title = __('توصيل سريع Zooboxi', 'zooboxi');
        $this->method_description = __('توصيل خلال ساعتين من أقرب مستودع', 'zooboxi');
        $this->supports = ['shipping-zones', 'instance-settings'];
        
        $this->init();
    }
    
    public function calculate_shipping($package = []) {
        $lat = WC()->session->get('zooboxi_customer_lat');
        $lng = WC()->session->get('zooboxi_customer_lng');
        
        if (!$lat || !$lng) return; // لا يمكن حساب بدون موقع
        
        // التحقق من وجود مستودع قريب
        $nearest = Zooboxi_Warehouse_Manager::findNearest($lat, $lng);
        
        if ($nearest && $nearest['distance'] <= $nearest['warehouse']->express_radius_km) {
            // التحقق من توفر كل المنتجات
            if (Zooboxi_Stock_Manager::hasAllItems($nearest['warehouse']->warehouse_code, $package['contents'])) {
                $this->add_rate([
                    'id' => $this->id,
                    'label' => '🚀 توصيل سريع (خلال ساعتين)',
                    'cost' => get_option('zooboxi_express_fee', 15),
                    'meta_data' => [
                        'warehouse_code' => $nearest['warehouse']->warehouse_code,
                        'delivery_type' => 'express',
                        'estimated_time' => '2 hours',
                    ],
                ]);
            }
        }
    }
}
```

### 2. التوصيل العادي (Same-Day — 24 ساعة)

```php
class Zooboxi_Standard_Shipping extends WC_Shipping_Method {
    
    public $id = 'zooboxi_standard';
    
    public function calculate_shipping($package = []) {
        $city = WC()->session->get('zooboxi_customer_city');
        
        // البحث عن مستودع مركزي في نفس المدينة
        $central = Zooboxi_Warehouse_Manager::findCentral($city);
        
        if ($central) {
            $this->add_rate([
                'id' => $this->id,
                'label' => '📦 توصيل عادي (خلال 24 ساعة)',
                'cost' => get_option('zooboxi_standard_fee', 10),
                'meta_data' => [
                    'warehouse_code' => $central->warehouse_code,
                    'delivery_type' => 'same_day',
                ],
            ]);
        }
    }
}
```

### 3. الشحن (Shipping — 2-4 أيام)

```php
class Zooboxi_National_Shipping extends WC_Shipping_Method {
    
    public $id = 'zooboxi_shipping';
    
    public function calculate_shipping($package = []) {
        $mainHub = Zooboxi_Warehouse_Manager::getMainHub();
        
        $this->add_rate([
            'id' => $this->id,
            'label' => '🚚 شحن (2-4 أيام عمل)',
            'cost' => get_option('zooboxi_shipping_fee', 25),
            'meta_data' => [
                'warehouse_code' => $mainHub->warehouse_code,
                'delivery_type' => 'shipping',
            ],
        ]);
    }
}
```

### 4. استلام من الفرع (Click & Collect)

```php
class Zooboxi_Pickup_Shipping extends WC_Shipping_Method {
    
    public $id = 'zooboxi_pickup';
    
    public function calculate_shipping($package = []) {
        $lat = WC()->session->get('zooboxi_customer_lat');
        $lng = WC()->session->get('zooboxi_customer_lng');
        
        // الحصول على الفروع التي تدعم الاستلام
        $pickupWarehouses = Zooboxi_Warehouse_Manager::getPickupLocations($lat, $lng);
        
        foreach ($pickupWarehouses as $wh) {
            $label = sprintf(
                '🏬 استلام من %s (%.1f كم)',
                $wh['warehouse']->display_name_ar,
                $wh['distance']
            );
            
            $this->add_rate([
                'id' => $this->id . '_' . $wh['warehouse']->warehouse_code,
                'label' => $label,
                'cost' => 0, // مجاني
                'meta_data' => [
                    'warehouse_code' => $wh['warehouse']->warehouse_code,
                    'delivery_type' => 'pickup',
                    'pickup_address' => $wh['warehouse']->address_ar,
                ],
            ]);
        }
    }
}
```

---

## شركات الشحن المحلية

### التكامل المطلوب:

| الشركة | Plugin | API | ملاحظات |
|--------|--------|-----|---------|
| SMSA Express | ✅ متوفر | REST API | الأكثر استخداماً في السعودية |
| Aramex | ✅ متوفر | SOAP/REST | تغطية واسعة |
| SPL (البريد السعودي) | ✅ متوفر | REST API | اقتصادي |

### لوحة إدارة الشحنات (مستقبلاً):

```
┌─────────────────────────────────────────────────────┐
│  إدارة شحنات Zooboxi                                 │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ الطلب #ZB-1234 │ Express │ مستودع الرياض       │ │
│  │ الحالة: في الطريق 🚗                           │ │
│  │ السائق: أحمد │ هاتف: 050xxxxxxx               │ │
│  │ الوقت المتبقي: 45 دقيقة                        │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ الطلب #ZB-1235 │ Shipping │ SMSA               │ │
│  │ الحالة: تم التسليم لشركة الشحن 📦              │ │
│  │ رقم التتبع: SM1234567890                       │ │
│  │ التوصيل المتوقع: 2 يونيو 2026                  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## ملخص تكاليف التوصيل

| طريقة التوصيل | التكلفة | ملاحظات |
|---------------|---------|---------|
| توصيل سريع (2 ساعة) | 15 ر.س | سائق داخلي |
| توصيل عادي (24 ساعة) | 10 ر.س | سائق داخلي |
| شحن (2-4 أيام) | 25 ر.س | شركة شحن |
| استلام من الفرع | مجاناً | Click & Collect |
| توصيل مجاني | عند طلب > 200 ر.س | (قابل للتعديل) |

> **ملاحظة**: الأسعار تقريبية وقابلة للتعديل من لوحة تحكم WooCommerce
