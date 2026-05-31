# 03 — نظام المستودعات الذكي والتوصيل

## الفكرة الأساسية

نظام التوصيل في Zooboxi يعتمد على **3 مستويات** بناءً على المسافة بين العميل والمستودعات:

```
العميل → [تحديد الموقع] → [حساب المسافة] → [اختيار المستوى]
```

---

## 1. جمع موقع العميل

### عند الدخول للمتجر:

```
┌──────────────────────────────────────────────┐
│  🐾 مرحباً في Zooboxi!                       │
│                                              │
│  عشان نعرض لك المنتجات المتاحة              │
│  والوقت المتوقع للتوصيل:                     │
│                                              │
│  📍 [السماح بتحديد موقعك]                    │
│                                              │
│  أو اختر مدينتك يدوياً:                      │
│  [▼ اختر المدينة]                            │
│                                              │
└──────────────────────────────────────────────┘
```

### الآلية:
1. **GPS (أولوية)**: استخدام Browser Geolocation API
2. **اختيار يدوي (Fallback)**: قائمة المدن المتاحة
3. **تخزين**: حفظ الموقع في Session + Cookie للزيارات القادمة

### الكود المقترح (JavaScript):

```javascript
// في header أو popup عند أول زيارة
function detectUserLocation() {
    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const { latitude, longitude } = position.coords;
                // إرسال للخادم لتحديد أقرب مستودع
                fetch('/wp-json/zooboxi/v1/detect-warehouse', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ lat: latitude, lng: longitude })
                })
                .then(res => res.json())
                .then(data => {
                    // data: { warehouse, delivery_type, estimated_time }
                    updateDeliveryBadge(data);
                });
            },
            (error) => {
                // Fallback: عرض اختيار المدينة
                showCitySelector();
            }
        );
    }
}
```

---

## 2. خوارزمية اختيار المستودع

### Haversine Formula (حساب المسافة):

```php
/**
 * حساب المسافة بين نقطتين (بالكيلومتر)
 */
function haversineDistance($lat1, $lng1, $lat2, $lng2): float
{
    $earthRadius = 6371; // km
    
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    
    $a = sin($dLat/2) * sin($dLat/2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLng/2) * sin($dLng/2);
    
    $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    
    return $earthRadius * $c;
}
```

### منطق الاختيار:

```php
function determineDelivery($customerLat, $customerLng, $cartItems): array
{
    $warehouses = ZooboxiWarehouse::where('is_active', true)->get();
    
    // 1. حساب المسافة لكل مستودع
    $warehouseDistances = [];
    foreach ($warehouses as $wh) {
        $distance = haversineDistance(
            $customerLat, $customerLng,
            $wh->latitude, $wh->longitude
        );
        $warehouseDistances[] = [
            'warehouse' => $wh,
            'distance' => $distance,
        ];
    }
    
    // ترتيب حسب القرب
    usort($warehouseDistances, fn($a, $b) => $a['distance'] <=> $b['distance']);
    
    // 2. البحث عن مستودع يدعم التوصيل السريع
    foreach ($warehouseDistances as $wd) {
        if ($wd['distance'] <= $wd['warehouse']->express_radius_km) {
            // التحقق من توفر كل المنتجات في هذا المستودع
            if (hasAllItems($wd['warehouse']->warehouse_code, $cartItems)) {
                return [
                    'delivery_type' => 'express',
                    'warehouse' => $wd['warehouse'],
                    'estimated_time' => '2 ساعة',
                    'delivery_fee' => 15.00, // رسوم التوصيل السريع
                ];
            }
        }
    }
    
    // 3. البحث عن مستودع مركزي في نفس المدينة
    $customerCity = reverseGeocode($customerLat, $customerLng);
    $centralWarehouse = $warehouses->where('city', $customerCity)
                                    ->where('is_central', true)
                                    ->first();
    
    if ($centralWarehouse && hasAllItems($centralWarehouse->warehouse_code, $cartItems)) {
        return [
            'delivery_type' => 'same_day',
            'warehouse' => $centralWarehouse,
            'estimated_time' => '24 ساعة',
            'delivery_fee' => 10.00,
        ];
    }
    
    // 4. Fallback: شحن من المستودع المركزي الرئيسي
    $mainHub = $warehouses->where('is_main_hub', true)->first();
    
    return [
        'delivery_type' => 'shipping',
        'warehouse' => $mainHub,
        'estimated_time' => '2-4 أيام عمل',
        'delivery_fee' => 25.00, // رسوم الشحن
    ];
}
```

---

## 3. التحقق من التوفر

```php
function hasAllItems(string $warehouseCode, array $cartItems): bool
{
    foreach ($cartItems as $item) {
        $stock = WarehouseItemStock::where('item_code', $item['sku'])
                    ->where('warehouse_code', $warehouseCode)
                    ->first();
        
        if (!$stock || $stock->in_stock < $item['quantity']) {
            return false;
        }
    }
    return true;
}
```

### حالة عدم التوفر الكامل في مستودع واحد:

```
السيناريو: العميل طلب 3 منتجات
- المنتج A: متوفر في مستودع الرياض (5 قطع)
- المنتج B: متوفر في مستودع الرياض (3 قطع)
- المنتج C: غير متوفر في مستودع الرياض ❌

الحلول الممكنة:
├── الخيار 1: الطلب كامل من المستودع المركزي (fallback)
├── الخيار 2: تقسيم الشحنة (Split Shipment) ← معقد
└── الخيار 3: إخفاء المنتج C عن العميل في هذا المستودع
```

> **القرار**: في المرحلة الأولى نستخدم **الخيار 1** (Fallback للمستودع المركزي)

---

## 4. عرض معلومات التوصيل

### في صفحة المنتج:

```
┌─────────────────────────────────────────────┐
│  📍 التوصيل إلى: الرياض - حي النرجس        │
│                                             │
│  🚀 توصيل سريع: خلال ساعتين (15 ر.س)      │
│     متوفر من معرض الرياض                    │
│                                             │
│  📦 توصيل عادي: خلال 24 ساعة (10 ر.س)     │
│     من المستودع المركزي                      │
│                                             │
│  🏬 استلام من الفرع: مجاناً                  │
│     معرض الرياض - حي العليا                  │
│                                             │
│  [تغيير الموقع]                              │
└─────────────────────────────────────────────┘
```

### في صفحة الـ Checkout:

```
┌─────────────────────────────────────────────┐
│  اختر طريقة التوصيل:                        │
│                                             │
│  ○ 🚀 توصيل سريع (خلال ساعتين)   15 ر.س   │
│  ● 📦 توصيل عادي (خلال 24 ساعة)  10 ر.س   │
│  ○ 🚚 شحن (2-4 أيام عمل)        25 ر.س   │
│  ○ 🏬 استلام من الفرع             مجاناً    │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 5. Click & Collect (استلام من الفرع)

### الآلية:
1. العميل يختار "استلام من الفرع"
2. يظهر قائمة الفروع المتاحة مع المسافة والمخزون
3. العميل يختار الفرع
4. يتم تأكيد الطلب وإرسال إشعار للفرع
5. الفرع يجهز الطلب ويُشعر العميل بالجاهزية

### عرض الفروع:

```
┌─────────────────────────────────────────────┐
│  اختر فرع الاستلام:                         │
│                                             │
│  📍 معرض الرياض - العليا (2.5 كم)          │
│     ✅ جميع المنتجات متوفرة                 │
│     🕐 الأحد - الخميس: 9ص - 11م           │
│     [اختيار هذا الفرع]                      │
│                                             │
│  📍 معرض الرياض - النرجس (8 كم)            │
│     ⚠️ منتج واحد غير متوفر                 │
│     🕐 الأحد - الخميس: 9ص - 11م           │
│     [اختيار هذا الفرع]                      │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 6. المدن والمستودعات المتوقعة

| المدينة | المستودع | النوع | التوصيل السريع |
|---------|----------|-------|----------------|
| الرياض | RYD-01 | معرض + مستودع مركزي | ✅ نعم (10 كم) |
| جدة | JED-01 | معرض + مستودع مركزي | ✅ نعم (10 كم) |
| الدمام | DMM-01 | معرض | ✅ نعم (8 كم) |
| ShipGo | SG-01 | مستودع شحن (Hub) | ❌ شحن فقط |

> **ملاحظة**: المدن والمستودعات هنا أمثلة تقريبية. سيتم تحديثها بالبيانات الفعلية.

---

## 7. WooCommerce Integration Points

### Custom Shipping Method:

```php
class Zooboxi_Smart_Shipping extends WC_Shipping_Method {
    
    public function calculate_shipping($package = []) {
        $customer_lat = WC()->session->get('zooboxi_lat');
        $customer_lng = WC()->session->get('zooboxi_lng');
        
        $delivery = determineDelivery($customer_lat, $customer_lng, $package['contents']);
        
        // إضافة خيارات التوصيل المتاحة
        if ($delivery['delivery_type'] === 'express') {
            $this->add_rate([
                'id' => 'zooboxi_express',
                'label' => '🚀 توصيل سريع (خلال ساعتين)',
                'cost' => 15,
                'meta_data' => ['warehouse' => $delivery['warehouse']->warehouse_code],
            ]);
        }
        
        $this->add_rate([
            'id' => 'zooboxi_standard',
            'label' => '📦 توصيل عادي (خلال 24 ساعة)',
            'cost' => 10,
        ]);
        
        $this->add_rate([
            'id' => 'zooboxi_shipping',
            'label' => '🚚 شحن (2-4 أيام عمل)',
            'cost' => 25,
        ]);
        
        $this->add_rate([
            'id' => 'zooboxi_pickup',
            'label' => '🏬 استلام من الفرع (مجاناً)',
            'cost' => 0,
        ]);
    }
}
```

---

## 8. تحديثات المخزون Real-time

عند كل عملية شراء:

```
1. WooCommerce Webhook → sapconnect API
2. sapconnect يخصم الكمية من warehouse_item_stocks
3. sapconnect يُنشئ فاتورة في SAP
4. SAP يُحدث المخزون الفعلي
```

### حماية من Overselling:

```php
// عند إضافة للسلة: التحقق الأولي
// عند الـ Checkout: التحقق النهائي (lock)
// بعد الدفع: خصم فوري من المخزون
```
