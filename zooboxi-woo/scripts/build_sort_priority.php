<?php
/**
 * Build _zooboxi_sort_priority meta for all products.
 * Priority 1 = has express stock + has image (best)
 * Priority 2 = has express stock + no image
 * Priority 3 = no express stock + has image
 * Priority 4 = no express stock + no image (worst)
 */
global $wpdb;

// Get all express-enabled warehouse codes
$express_codes = $wpdb->get_col(
    "SELECT warehouse_code FROM {$wpdb->prefix}zooboxi_warehouses WHERE is_express_enabled = 1 AND is_active = 1"
);
WP_CLI::log('Express codes: ' . implode(', ', $express_codes));

// Get all published products with stock and thumbnail info
$products = $wpdb->get_results("
    SELECT p.ID,
           pm_stock.meta_value as warehouse_stock,
           pm_thumb.meta_value as thumbnail_id
    FROM {$wpdb->posts} p
    LEFT JOIN {$wpdb->postmeta} pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_zooboxi_warehouse_stock'
    LEFT JOIN {$wpdb->postmeta} pm_thumb ON p.ID = pm_thumb.post_id AND pm_thumb.meta_key = '_thumbnail_id'
    WHERE p.post_type = 'product' AND p.post_status = 'publish'
");

WP_CLI::log('Processing ' . count($products) . ' products...');

$counts = [1 => 0, 2 => 0, 3 => 0, 4 => 0];
$batch = [];

foreach ($products as $product) {
    $has_express = false;
    $has_image = !empty($product->thumbnail_id) && intval($product->thumbnail_id) > 0;

    if (!empty($product->warehouse_stock)) {
        $stock = json_decode($product->warehouse_stock, true);
        if (is_array($stock)) {
            foreach ($stock as $s) {
                $code = $s['warehouse_code'] ?? '';
                $qty = intval($s['in_stock'] ?? 0);
                if (in_array($code, $express_codes) && $qty > 0) {
                    $has_express = true;
                    break;
                }
            }
        }
    }

    // Priority: lower = better
    if ($has_express && $has_image)       $priority = 1;
    elseif ($has_express && !$has_image)  $priority = 2;
    elseif (!$has_express && $has_image)  $priority = 3;
    else                                  $priority = 4;

    $counts[$priority]++;
    $batch[] = $wpdb->prepare("(%d, '_zooboxi_sort_priority', %d)", $product->ID, $priority);
}

// Batch insert/update
WP_CLI::log('Clearing old priorities...');
$wpdb->query("DELETE FROM {$wpdb->postmeta} WHERE meta_key = '_zooboxi_sort_priority'");

WP_CLI::log('Inserting priorities...');
$chunks = array_chunk($batch, 500);
foreach ($chunks as $i => $chunk) {
    $sql = "INSERT INTO {$wpdb->postmeta} (post_id, meta_key, meta_value) VALUES " . implode(',', $chunk);
    $wpdb->query($sql);
    WP_CLI::log('  Batch ' . ($i + 1) . '/' . count($chunks) . ' done');
}

WP_CLI::success(sprintf(
    'Done! P1(express+img): %d | P2(express): %d | P3(img only): %d | P4(neither): %d',
    $counts[1], $counts[2], $counts[3], $counts[4]
));
