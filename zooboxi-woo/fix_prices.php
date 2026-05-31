<?php
/**
 * Fix prices v2 - match products by name_ar from CSV
 */
require_once __DIR__ . '/wp-load.php';

echo "=== FIXING PRODUCT PRICES v2 ===\n\n";

// Build price map from CSV: name_ar => price
$priceMap = [];
$csvFiles = glob(__DIR__ . '/zid_batch*.csv');

foreach ($csvFiles as $csvFile) {
    $handle = fopen($csvFile, 'r');
    $headers = fgetcsv($handle);
    
    $nameIdx = array_search('name_ar', $headers);
    $priceIdx = array_search('price', $headers);
    $salePriceIdx = array_search('sale_price', $headers);
    $barcodeIdx = array_search('barcode', $headers);
    $skuIdx = array_search('sku', $headers);
    
    while (($row = fgetcsv($handle)) !== false) {
        $name = trim($row[$nameIdx] ?? '');
        $price = trim($row[$priceIdx] ?? '');
        $salePrice = trim($row[$salePriceIdx] ?? '');
        $barcode = trim($row[$barcodeIdx] ?? '');
        
        if (!empty($price) && $price > 0) {
            // Map by name
            if (!empty($name)) {
                $priceMap['name:' . $name] = ['price' => $price, 'sale' => $salePrice];
            }
            // Map by barcode 
            if (!empty($barcode)) {
                $priceMap['bc:' . $barcode] = ['price' => $price, 'sale' => $salePrice];
            }
        }
    }
    fclose($handle);
}

echo "Price map: " . count($priceMap) . " entries\n\n";

// Get all products without price
global $wpdb;
$products = $wpdb->get_results("
    SELECT p.ID, p.post_title,
           pm_code.meta_value as item_code,
           sk.meta_value as sku
    FROM {$wpdb->posts} p
    LEFT JOIN {$wpdb->postmeta} pm_code ON p.ID = pm_code.post_id AND pm_code.meta_key = '_zooboxi_item_code'
    LEFT JOIN {$wpdb->postmeta} sk ON p.ID = sk.post_id AND sk.meta_key = '_sku'
    LEFT JOIN {$wpdb->postmeta} rp ON p.ID = rp.post_id AND rp.meta_key = '_regular_price' AND rp.meta_value != '' AND rp.meta_value > 0
    WHERE p.post_type = 'product' AND p.post_status = 'publish'
    AND rp.meta_id IS NULL
");

echo "Products without price: " . count($products) . "\n\n";

$updated = $not_found = 0;

foreach ($products as $prod) {
    $price = null;
    
    // Try by name
    if (isset($priceMap['name:' . $prod->post_title])) {
        $price = $priceMap['name:' . $prod->post_title];
    }
    // Try by barcode (if it's the SKU)
    elseif (!empty($prod->sku) && isset($priceMap['bc:' . $prod->sku])) {
        $price = $priceMap['bc:' . $prod->sku];
    }
    
    if ($price && $price['price'] > 0) {
        update_post_meta($prod->ID, '_regular_price', $price['price']);
        update_post_meta($prod->ID, '_price', $price['price']);
        
        if (!empty($price['sale']) && $price['sale'] > 0 && $price['sale'] < $price['price']) {
            update_post_meta($prod->ID, '_sale_price', $price['sale']);
            update_post_meta($prod->ID, '_price', $price['sale']);
        }
        $updated++;
    } else {
        $not_found++;
        if ($not_found <= 5) {
            echo "  No price for: [{$prod->ID}] {$prod->post_title}\n";
        }
    }
}

echo "\n  Updated: $updated\n";
echo "  Not found: $not_found\n";
echo "\nDone!\n";
