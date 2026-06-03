<?php
/**
 * Zooboxi WooCommerce SKU Fixer
 * =============================
 * Finds all products in WooCommerce that lack an SKU, fetches their barcodes
 * from the sapconnect API, and updates their SKU and _zooboxi_barcode meta.
 * 
 * Usage: wp eval-file fix_skus.php --path=public_html
 */

$api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
$api_token = get_option('zooboxi_api_token', '');

if (empty($api_token)) {
    WP_CLI::error("Error: zooboxi_api_token is empty! Please verify the plugin settings.");
    exit(1);
}

global $wpdb;

// Query all products and product variations lacking _sku meta but having _zooboxi_item_code
$products = $wpdb->get_results(
    "SELECT p.ID, p.post_title, m_code.meta_value AS item_code 
     FROM {$wpdb->posts} p 
     INNER JOIN {$wpdb->postmeta} m_code ON p.ID = m_code.post_id AND m_code.meta_key = '_zooboxi_item_code'
     LEFT JOIN {$wpdb->postmeta} m_sku ON p.ID = m_sku.post_id AND m_sku.meta_key = '_sku'
     WHERE p.post_type IN ('product', 'product_variation') 
       AND (m_sku.meta_value IS NULL OR m_sku.meta_value = '')"
);

$total = count($products);
WP_CLI::log("🔍 Found {$total} products/variations lacking SKU in WooCommerce.");

if ($total === 0) {
    WP_CLI::success("All products already have an SKU!");
    exit(0);
}

$updated = 0;
$failed = 0;

foreach ($products as $index => $prod) {
    $pid = $prod->ID;
    $item_code = $prod->item_code;
    $title = $prod->post_title;
    
    // Call sapconnect API to get the product info
    $url = $api_base . '/products/' . $item_code;
    $response = wp_remote_get($url, [
        'headers' => [
            'Authorization' => 'Bearer ' . $api_token,
            'Accept'        => 'application/json',
        ],
        'timeout' => 15,
    ]);
    
    if (is_wp_error($response)) {
        WP_CLI::warning("[" . ($index + 1) . "/{$total}] Error fetching {$item_code}: " . $response->get_error_message());
        $failed++;
        continue;
    }
    
    $code = wp_remote_retrieve_response_code($response);
    if ($code !== 200) {
        WP_CLI::warning("[" . ($index + 1) . "/{$total}] Error fetching {$item_code}: API returned HTTP {$code}");
        $failed++;
        continue;
    }
    
    $body = json_decode(wp_remote_retrieve_body($response), true);
    $barcode = $body['data']['barcode'] ?? null;
    
    if (!empty($barcode)) {
        $wc_product = wc_get_product($pid);
        if ($wc_product) {
            try {
                $wc_product->set_sku($barcode);
                $wc_product->save();
                update_post_meta($pid, '_zooboxi_barcode', $barcode);
                WP_CLI::success("[" . ($index + 1) . "/{$total}] Set SKU to {$barcode} for ID {$pid} ({$title} - {$item_code})");
                $updated++;
            } catch (\Exception $e) {
                WP_CLI::warning("[" . ($index + 1) . "/{$total}] Cannot set SKU {$barcode} for ID {$pid} (may already exist on another product). Error: " . $e->getMessage());
                $failed++;
            }
        }
    } else {
        WP_CLI::warning("[" . ($index + 1) . "/{$total}] Barcode is empty in sapconnect for {$item_code}");
        $failed++;
    }
    
    // Flush WordPress object cache periodically to avoid memory exhaustion
    if ($index % 50 === 0) {
        wp_cache_flush();
    }
}

WP_CLI::log("\n" . str_repeat('═', 60));
WP_CLI::success("SKU Fixer Completed! Updated: {$updated} products, Failed/Skipped: {$failed}");
