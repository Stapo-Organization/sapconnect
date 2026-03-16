<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$sapDatabase = 'TEST_RETAIL01';
$itemCodeToFetch = 'P16800085';

echo "Fetching Product {$itemCodeToFetch} from {$sapDatabase}...\n";

try {
    $sap = app(\App\Services\SAP\SapClient::class);
    $sap->setCompanyDb($sapDatabase);

    // Fetch specific Item with select fields, including ItemPrices
    // Note: OData filter syntax is required for SAP B1 Service Layer
    $response = $sap->get("Items('{$itemCodeToFetch}')", [
        '$select' => 'ItemCode,ItemName,ForeignName,ItemsGroupCode,InventoryUOM,BarCode,SalesItemsPerUnit,CreateDate,UpdateDate,ItemPrices',
    ]);

    $item = $response;

    if (empty($item) || !isset($item['ItemCode'])) {
        echo "Product not found or invalid response.\n";
        exit;
    }

    $envSource = 'test';
    $pricesData = $item['ItemPrices'] ?? [];

    $data = [
        'item_code' => $item['ItemCode'],
        'item_name' => $item['ItemName'] ?? null,
        'foreign_name' => $item['ForeignName'] ?? null,
        'items_group_code' => $item['ItemsGroupCode'] ?? null,
        'inventory_uom' => $item['InventoryUOM'] ?? null,
        'piece_barcode' => $item['BarCode'] ?? null,
        'sales_items_per_unit' => $item['SalesItemsPerUnit'] ?? null,
        'create_date' => isset($item['CreateDate']) ? date('Y-m-d', strtotime($item['CreateDate'])) : null,
        'update_date' => isset($item['UpdateDate']) ? date('Y-m-d', strtotime($item['UpdateDate'])) : null,
        'source' => $envSource,
        'prices' => $pricesData,
    ];

    \App\Models\Product::updateOrCreate(
        [
            'item_code' => $data['item_code'],
            'source' => $data['source'],
        ],
        $data
    );

    echo "Product {$item['ItemCode']} synced successfully!\n";
    echo "Stored Prices:\n";
    
    $foundPrice = false;
    foreach($pricesData as $price) {
         if($price['Price'] > 0) {
             echo "PriceList: {$price['PriceList']} - Price: {$price['Price']} {$price['Currency']}\n";
             $foundPrice = true;
         }
    }
    if(!$foundPrice) {
         echo "All stored prices were 0.\n";
    }

} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
