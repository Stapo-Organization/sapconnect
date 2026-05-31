<?php
// seed_woo.php — Flag products + seed warehouses
require_once __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use Illuminate\Support\Facades\DB;
use App\Models\Product;
use App\Models\ZooboxiWarehouse;

// 1. Flag all production products for WooCommerce
$count = Product::where('source', 'production')->update(['woo_sync' => true]);
echo "Flagged {$count} products for WooCommerce sync\n";

// 2. Seed warehouses
$warehouses = [
    [
        'warehouse_code' => 'WH-RYD-01',
        'display_name_ar' => 'مستودع الرياض المركزي',
        'display_name_en' => 'Riyadh Central Warehouse',
        'city' => 'Riyadh',
        'address_ar' => 'حي النسيم، الرياض',
        'address_en' => 'Al Naseem District, Riyadh',
        'latitude' => 24.7136,
        'longitude' => 46.6753,
        'express_radius_km' => 15,
        'is_central' => true,
        'is_main_hub' => true,
        'is_pickup_enabled' => true,
        'is_active' => true,
        'phone' => '+966500000001',
    ],
    [
        'warehouse_code' => 'WH-JED-01',
        'display_name_ar' => 'مستودع جدة',
        'display_name_en' => 'Jeddah Warehouse',
        'city' => 'Jeddah',
        'address_ar' => 'حي الفيصلية، جدة',
        'address_en' => 'Al Faisaliah District, Jeddah',
        'latitude' => 21.4858,
        'longitude' => 39.1925,
        'express_radius_km' => 12,
        'is_central' => true,
        'is_main_hub' => false,
        'is_pickup_enabled' => true,
        'is_active' => true,
        'phone' => '+966500000002',
    ],
    [
        'warehouse_code' => 'WH-DMM-01',
        'display_name_ar' => 'مستودع الدمام',
        'display_name_en' => 'Dammam Warehouse',
        'city' => 'Dammam',
        'address_ar' => 'حي الشاطئ، الدمام',
        'address_en' => 'Al Shati District, Dammam',
        'latitude' => 26.3927,
        'longitude' => 50.1894,
        'express_radius_km' => 10,
        'is_central' => true,
        'is_main_hub' => false,
        'is_pickup_enabled' => true,
        'is_active' => true,
        'phone' => '+966500000003',
    ],
];

foreach ($warehouses as $wh) {
    ZooboxiWarehouse::updateOrCreate(
        ['warehouse_code' => $wh['warehouse_code']],
        $wh
    );
    echo "Seeded warehouse: {$wh['warehouse_code']} ({$wh['display_name_en']})\n";
}

echo "\nDone! All warehouses seeded.\n";
