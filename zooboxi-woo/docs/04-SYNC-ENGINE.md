# 04 — محرك المزامنة (sapconnect ↔ WooCommerce)

## نظرة عامة

المزامنة تعمل بطريقة **هجينة**:
- **المخزون والأسعار**: مزامنة دورية (Cron) كل 5-10 دقائق
- **الطلبات**: مزامنة فورية عبر Webhooks
- **المنتجات**: مزامنة عند الحاجة + دورية كل ساعة

---

## 1. بنية المزامنة

```
┌─────────────────┐                        ┌──────────────────┐
│   sapconnect     │                        │   WooCommerce    │
│   (Laravel)      │                        │   (WordPress)    │
│                  │                        │                  │
│  Products ───────┤── PUSH (API) ─────────→│  WC Products     │
│  Warehouses ─────┤── PUSH (API) ─────────→│  WC Meta         │
│  Stock ──────────┤── PUSH (API) ─────────→│  WC Stock        │
│  Prices ─────────┤── PUSH (API) ─────────→│  WC Prices       │
│                  │                        │                  │
│  Zooboxi Orders ←│── PULL (Webhook) ──────┤  WC Orders       │
│                  │                        │                  │
└─────────────────┘                        └──────────────────┘
```

---

## 2. API Endpoints المطلوبة

### في sapconnect (Laravel) — إضافة routes جديدة:

```php
// routes/api.php — إضافة مجموعة woo

Route::prefix('woo')->middleware(['auth.woo_token'])->group(function () {
    // المنتجات
    Route::get('/products', [WooSyncController::class, 'getProducts']);
    Route::get('/products/{item_code}', [WooSyncController::class, 'getProduct']);
    
    // المخزون
    Route::get('/stock', [WooSyncController::class, 'getStock']);
    Route::get('/stock/{warehouse_code}', [WooSyncController::class, 'getWarehouseStock']);
    
    // الأسعار
    Route::get('/prices', [WooSyncController::class, 'getPrices']);
    
    // المستودعات
    Route::get('/warehouses', [WooSyncController::class, 'getWarehouses']);
    
    // الطلبات
    Route::post('/orders', [WooSyncController::class, 'receiveOrder']);
    Route::put('/orders/{woo_order_id}/status', [WooSyncController::class, 'updateOrderStatus']);
    
    // حالة المزامنة
    Route::get('/sync-status', [WooSyncController::class, 'getSyncStatus']);
});
```

### Response Formats:

#### GET `/api/woo/products`
```json
{
    "data": [
        {
            "item_code": "P1001-001",
            "item_name": "طعام قطط - دجاج 1كجم",
            "foreign_name": "Cat Food - Chicken 1kg",
            "brand_code": 101,
            "brand_name": "Royal Canin",
            "barcode": "6281234567890",
            "uom": "PCS",
            "prices": {
                "1": {"price": 45.00, "name": "Retail"},
                "2": {"price": 38.00, "name": "Wholesale"}
            },
            "image_url": "https://ppte.sa/imghd/P100/P1001-001.png",
            "properties": {
                "u_proprt1": "Adult",
                "u_proprt2": "Indoor",
                "u_proprt3": "1kg"
            },
            "woo_product_id": null,
            "updated_at": "2026-05-31T10:00:00Z"
        }
    ],
    "meta": {
        "total": 250,
        "page": 1,
        "per_page": 50,
        "last_sync": "2026-05-31T10:00:00Z"
    }
}
```

#### GET `/api/woo/stock`
```json
{
    "data": [
        {
            "item_code": "P1001-001",
            "warehouses": [
                {"warehouse_code": "RYD-01", "in_stock": 25, "ordered": 50},
                {"warehouse_code": "JED-01", "in_stock": 12, "ordered": 0},
                {"warehouse_code": "DMM-01", "in_stock": 0, "ordered": 30}
            ],
            "total_stock": 37
        }
    ],
    "timestamp": "2026-05-31T10:05:00Z"
}
```

#### POST `/api/woo/orders`
```json
{
    "woo_order_id": 1234,
    "woo_order_number": "#ZB-1234",
    "customer": {
        "name": "أحمد محمد",
        "phone": "+966501234567",
        "email": "ahmed@example.com",
        "latitude": 24.7136,
        "longitude": 46.6753,
        "city": "الرياض",
        "address": "حي النرجس - شارع الأمير محمد بن سلمان"
    },
    "delivery": {
        "type": "express",
        "warehouse_code": "RYD-01",
        "fee": 15.00
    },
    "items": [
        {
            "item_code": "P1001-001",
            "quantity": 2,
            "unit_price": 45.00,
            "total": 90.00
        }
    ],
    "payment": {
        "method": "tamara",
        "status": "paid",
        "total": 105.00
    }
}
```

---

## 3. WooCommerce Plugin — Sync Engine

### كلاس المزامنة الرئيسي:

```php
class Zooboxi_Sync_Engine {
    
    private $api_base;
    private $api_token;
    
    public function __construct() {
        $this->api_base = get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo');
        $this->api_token = get_option('zooboxi_api_token');
    }
    
    /**
     * مزامنة المنتجات من sapconnect إلى WooCommerce
     */
    public function syncProducts(): array {
        $page = 1;
        $synced = 0;
        $failed = 0;
        
        do {
            $response = $this->apiGet("/products?page={$page}&per_page=50");
            $products = $response['data'];
            
            foreach ($products as $product) {
                try {
                    $this->upsertProduct($product);
                    $synced++;
                } catch (\Exception $e) {
                    $failed++;
                    error_log("Zooboxi Sync Error: {$e->getMessage()}");
                }
            }
            
            $page++;
        } while (count($products) === 50);
        
        return ['synced' => $synced, 'failed' => $failed];
    }
    
    /**
     * مزامنة المخزون (كل 5-10 دقائق)
     */
    public function syncStock(): array {
        $response = $this->apiGet('/stock');
        $updated = 0;
        
        foreach ($response['data'] as $item) {
            $product_id = $this->getWooProductBySku($item['item_code']);
            if (!$product_id) continue;
            
            // تحديث المخزون الإجمالي في WooCommerce
            update_post_meta($product_id, '_stock', $item['total_stock']);
            update_post_meta($product_id, '_stock_status', 
                $item['total_stock'] > 0 ? 'instock' : 'outofstock');
            
            // حفظ التفصيل لكل مستودع (للمنطق الذكي)
            update_post_meta($product_id, '_zooboxi_warehouse_stock', 
                json_encode($item['warehouses']));
            
            $updated++;
        }
        
        return ['updated' => $updated];
    }
    
    /**
     * مزامنة الأسعار
     */
    public function syncPrices(): array {
        $response = $this->apiGet('/prices');
        $updated = 0;
        
        foreach ($response['data'] as $item) {
            $product_id = $this->getWooProductBySku($item['item_code']);
            if (!$product_id) continue;
            
            // السعر الرئيسي = Price List 1 (تجزئة)
            if (isset($item['prices']['1'])) {
                update_post_meta($product_id, '_regular_price', $item['prices']['1']['price']);
                update_post_meta($product_id, '_price', $item['prices']['1']['price']);
            }
            
            // حفظ كل الأسعار للاستخدام المستقبلي
            update_post_meta($product_id, '_zooboxi_price_lists', json_encode($item['prices']));
            
            $updated++;
        }
        
        return ['updated' => $updated];
    }
    
    /**
     * إرسال طلب جديد إلى sapconnect
     */
    public function pushOrder(int $woo_order_id): bool {
        $order = wc_get_order($woo_order_id);
        if (!$order) return false;
        
        $payload = $this->buildOrderPayload($order);
        $response = $this->apiPost('/orders', $payload);
        
        if ($response && isset($response['id'])) {
            $order->update_meta_data('_zooboxi_synced', true);
            $order->update_meta_data('_zooboxi_synced_at', current_time('mysql'));
            $order->save();
            return true;
        }
        
        return false;
    }
    
    // ─── Helper Methods ────────────────────────────────
    
    private function apiGet(string $endpoint): array {
        $response = wp_remote_get($this->api_base . $endpoint, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->api_token,
                'Accept' => 'application/json',
            ],
            'timeout' => 30,
        ]);
        
        if (is_wp_error($response)) {
            throw new \Exception($response->get_error_message());
        }
        
        return json_decode(wp_remote_retrieve_body($response), true);
    }
    
    private function apiPost(string $endpoint, array $data): array {
        $response = wp_remote_post($this->api_base . $endpoint, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->api_token,
                'Content-Type' => 'application/json',
                'Accept' => 'application/json',
            ],
            'body' => json_encode($data),
            'timeout' => 30,
        ]);
        
        if (is_wp_error($response)) {
            throw new \Exception($response->get_error_message());
        }
        
        return json_decode(wp_remote_retrieve_body($response), true);
    }
    
    private function upsertProduct(array $data): void {
        $existing_id = $this->getWooProductBySku($data['item_code']);
        
        if ($existing_id) {
            $this->updateWooProduct($existing_id, $data);
        } else {
            $this->createWooProduct($data);
        }
    }
    
    private function getWooProductBySku(string $sku): ?int {
        $product_id = wc_get_product_id_by_sku($sku);
        return $product_id ?: null;
    }
}
```

---

## 4. جدولة المزامنة (WP-Cron)

```php
// في البلقن الرئيسي

// تسجيل الأحداث
register_activation_hook(__FILE__, function() {
    // مزامنة المخزون كل 5 دقائق
    if (!wp_next_scheduled('zooboxi_sync_stock')) {
        wp_schedule_event(time(), 'every_5_minutes', 'zooboxi_sync_stock');
    }
    
    // مزامنة المنتجات كل ساعة
    if (!wp_next_scheduled('zooboxi_sync_products')) {
        wp_schedule_event(time(), 'hourly', 'zooboxi_sync_products');
    }
    
    // مزامنة الأسعار كل 30 دقيقة
    if (!wp_next_scheduled('zooboxi_sync_prices')) {
        wp_schedule_event(time(), 'every_30_minutes', 'zooboxi_sync_prices');
    }
});

// تنفيذ المزامنة
add_action('zooboxi_sync_stock', function() {
    $engine = new Zooboxi_Sync_Engine();
    $result = $engine->syncStock();
    
    // تسجيل النتيجة
    Zooboxi_Logger::log('stock_sync', $result);
});

add_action('zooboxi_sync_products', function() {
    $engine = new Zooboxi_Sync_Engine();
    $result = $engine->syncProducts();
    
    Zooboxi_Logger::log('product_sync', $result);
});

// Custom cron interval
add_filter('cron_schedules', function($schedules) {
    $schedules['every_5_minutes'] = [
        'interval' => 300,
        'display' => 'Every 5 Minutes'
    ];
    $schedules['every_30_minutes'] = [
        'interval' => 1800,
        'display' => 'Every 30 Minutes'
    ];
    return $schedules;
});
```

---

## 5. WooCommerce Webhooks (الطلبات)

### إعداد في WooCommerce:

```
WooCommerce > Settings > Advanced > Webhooks

Webhook 1: New Order
├── Name: Zooboxi Order Sync
├── Status: Active
├── Topic: Order created
├── Delivery URL: https://sapapi.muntajat.sa/api/woo/orders
├── Secret: {WEBHOOK_SECRET}
└── API Version: WP REST API v3

Webhook 2: Order Updated
├── Name: Zooboxi Order Update
├── Status: Active
├── Topic: Order updated
├── Delivery URL: https://sapapi.muntajat.sa/api/woo/orders/{id}/status
├── Secret: {WEBHOOK_SECRET}
└── API Version: WP REST API v3
```

### في sapconnect (استقبال Webhook):

```php
// app/Http/Controllers/Api/WooSyncController.php

class WooSyncController extends Controller
{
    public function receiveOrder(Request $request)
    {
        // التحقق من التوقيع
        $this->verifyWebhookSignature($request);
        
        $data = $request->all();
        
        // إنشاء الطلب محلياً
        $order = ZooboxiOrder::create([
            'woo_order_id' => $data['id'],
            'woo_order_number' => $data['number'],
            'warehouse_code' => $data['meta_data']['_zooboxi_warehouse'] ?? null,
            'delivery_type' => $data['meta_data']['_zooboxi_delivery_type'] ?? 'shipping',
            'delivery_status' => 'pending',
            'customer_latitude' => $data['meta_data']['_zooboxi_lat'] ?? null,
            'customer_longitude' => $data['meta_data']['_zooboxi_lng'] ?? null,
            'customer_city' => $data['shipping']['city'] ?? null,
            'total_amount' => $data['total'],
        ]);
        
        // إنشاء أسطر الطلب
        foreach ($data['line_items'] as $item) {
            ZooboxiOrderLine::create([
                'zooboxi_order_id' => $order->id,
                'item_code' => $item['sku'],
                'warehouse_code' => $order->warehouse_code,
                'quantity' => $item['quantity'],
                'unit_price' => $item['price'],
                'total_price' => $item['total'],
            ]);
        }
        
        // خصم المخزون
        $this->deductStock($order);
        
        // إنشاء فاتورة SAP (async job)
        dispatch(new CreateSapInvoiceJob($order));
        
        return response()->json(['status' => 'received', 'order_id' => $order->id]);
    }
    
    private function deductStock(ZooboxiOrder $order): void
    {
        foreach ($order->lines as $line) {
            WarehouseItemStock::where('item_code', $line->item_code)
                ->where('warehouse_code', $line->warehouse_code)
                ->decrement('in_stock', $line->quantity);
        }
    }
}
```

---

## 6. مخطط التدفق الكامل

```
┌─────────────────────────────────────────────────────────────┐
│                    Sync Flow Overview                        │
│                                                             │
│  SAP B1 ──[API]──→ sapconnect ──[REST API]──→ WooCommerce  │
│                                                             │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────┐ │
│  │ Products     │  │ WooSync     │  │ WC Products        │ │
│  │ (hourly)     │→ │ Controller  │→ │ (create/update)    │ │
│  ├──────────────┤  ├─────────────┤  ├────────────────────┤ │
│  │ Stock        │  │ WooSync     │  │ WC Stock Meta      │ │
│  │ (5 min)      │→ │ Controller  │→ │ (update quantity)  │ │
│  ├──────────────┤  ├─────────────┤  ├────────────────────┤ │
│  │ Prices       │  │ WooSync     │  │ WC Price Meta      │ │
│  │ (30 min)     │→ │ Controller  │→ │ (update prices)    │ │
│  ├──────────────┤  ├─────────────┤  ├────────────────────┤ │
│  │ Orders       │  │ WooSync     │  │ WC Webhooks        │ │
│  │ (real-time)  │← │ Controller  │← │ (on order create)  │ │
│  └──────────────┘  └─────────────┘  └────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Error Handling & Retry

```php
class Zooboxi_Sync_Engine {
    
    const MAX_RETRIES = 3;
    const RETRY_DELAY = 5; // seconds
    
    private function apiGetWithRetry(string $endpoint): array {
        $attempts = 0;
        
        while ($attempts < self::MAX_RETRIES) {
            try {
                return $this->apiGet($endpoint);
            } catch (\Exception $e) {
                $attempts++;
                if ($attempts >= self::MAX_RETRIES) {
                    Zooboxi_Logger::error("API call failed after {$attempts} attempts: {$e->getMessage()}");
                    throw $e;
                }
                sleep(self::RETRY_DELAY * $attempts);
            }
        }
    }
}
```

---

## 8. لوحة تحكم المزامنة (Admin Dashboard)

```
┌─────────────────────────────────────────────────────────┐
│  Zooboxi Sync Dashboard                                  │
│                                                         │
│  آخر مزامنة مخزون:  ✅ قبل 3 دقائق (250 منتج)        │
│  آخر مزامنة منتجات: ✅ قبل 45 دقيقة (12 جديد)         │
│  آخر مزامنة أسعار:  ✅ قبل 15 دقيقة (5 تحديث)         │
│  طلبات معلقة:       ⚠️ 3 طلبات لم تُزامن               │
│                                                         │
│  [مزامنة المنتجات الآن] [مزامنة المخزون الآن]           │
│  [عرض السجل] [الإعدادات]                                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```
