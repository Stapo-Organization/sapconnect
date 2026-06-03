<?php
/**
 * Sync Brands from sapconnect to WooCommerce.
 * 
 * Creates brand terms and assigns products to their brands.
 * Run: wp eval-file sync_brands.php
 */

if (!defined('ABSPATH')) {
    // Allow running via wp eval-file
    require_once dirname(__FILE__) . '/../wp-load.php';
}

// ─── Configuration ───────────────────────────────────────────────
$api_url   = rtrim(get_option('zooboxi_api_url', ''), '/');
$api_token = get_option('zooboxi_api_token', '');

if (empty($api_url) || empty($api_token)) {
    echo "ERROR: Zooboxi API not configured.\n";
    exit(1);
}

// ─── Detect brand taxonomy ──────────────────────────────────────
$brand_tax = null;
$possible = ['product_brand', 'pwb-brand', 'yith_product_brand'];
foreach ($possible as $tax) {
    if (taxonomy_exists($tax)) {
        $brand_tax = $tax;
        break;
    }
}

if (!$brand_tax) {
    echo "ERROR: No brand taxonomy found. Install 'Perfect Brands for WooCommerce' or similar.\n";
    echo "Available product taxonomies:\n";
    $taxes = get_object_taxonomies('product');
    foreach ($taxes as $t) echo "  - $t\n";
    exit(1);
}

echo "Using taxonomy: $brand_tax\n\n";

// ─── Fetch products with brand info from API ────────────────────
echo "Fetching products from sapconnect API...\n";

$page = 1;
$per_page = 100;
$all_products = [];

while (true) {
    $url = "$api_url/products?page=$page&per_page=$per_page";
    $response = wp_remote_get($url, [
        'headers' => ['Authorization' => "Bearer $api_token"],
        'timeout' => 60,
    ]);

    if (is_wp_error($response)) {
        echo "API error: " . $response->get_error_message() . "\n";
        break;
    }

    $body = json_decode(wp_remote_retrieve_body($response), true);
    $items = $body['data'] ?? [];
    
    if (empty($items)) break;
    
    foreach ($items as $item) {
        if (!empty($item['brand_name'])) {
            $all_products[] = [
                'item_code'  => $item['item_code'],
                'brand_code' => $item['brand_code'],
                'brand_name' => $item['brand_name'],
            ];
        }
    }
    
    $total = $body['meta']['total'] ?? 0;
    $last_page = $body['meta']['last_page'] ?? 1;
    echo "  Page $page/$last_page — fetched " . count($items) . " products\n";
    
    if ($page >= $last_page) break;
    $page++;
}

echo "\nTotal products with brands: " . count($all_products) . "\n";

// ─── Group by brand ─────────────────────────────────────────────
$brands = [];
foreach ($all_products as $p) {
    $key = $p['brand_code'];
    if (!isset($brands[$key])) {
        $brands[$key] = [
            'name'       => $p['brand_name'],
            'code'       => $p['brand_code'],
            'item_codes' => [],
        ];
    }
    $brands[$key]['item_codes'][] = $p['item_code'];
}

echo "Unique brands: " . count($brands) . "\n\n";

// ─── Create brand terms ─────────────────────────────────────────
echo "=== CREATING BRANDS ===\n";
$brand_term_map = []; // brand_code => term_id

foreach ($brands as $code => $brand) {
    $name = trim($brand['name']);
    if (empty($name) || $name === 'Unknown') continue;
    
    // Check if brand already exists
    $existing = get_term_by('name', $name, $brand_tax);
    if ($existing) {
        $brand_term_map[$code] = $existing->term_id;
        echo "  EXISTS: $name (term_id={$existing->term_id})\n";
        continue;
    }
    
    // Create slug from name
    $slug = sanitize_title($name);
    
    $result = wp_insert_term($name, $brand_tax, [
        'slug'        => $slug,
        'description' => "Brand code: $code",
    ]);
    
    if (is_wp_error($result)) {
        echo "  FAIL: $name — " . $result->get_error_message() . "\n";
        // Try to get existing by slug
        $existing = get_term_by('slug', $slug, $brand_tax);
        if ($existing) {
            $brand_term_map[$code] = $existing->term_id;
        }
    } else {
        $brand_term_map[$code] = $result['term_id'];
        echo "  CREATED: $name (term_id={$result['term_id']})\n";
    }
}

echo "\nBrands created/found: " . count($brand_term_map) . "\n\n";

// ─── Assign products to brands ──────────────────────────────────
echo "=== ASSIGNING PRODUCTS TO BRANDS ===\n";
$assigned = 0;
$not_found = 0;
$batch = 0;

foreach ($brands as $code => $brand) {
    if (!isset($brand_term_map[$code])) continue;
    $term_id = $brand_term_map[$code];
    
    foreach ($brand['item_codes'] as $item_code) {
        // Find WC product by item_code meta
        global $wpdb;
        $product_id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} 
             WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s 
             LIMIT 1",
            $item_code
        ));
        
        if (!$product_id) {
            $not_found++;
            continue;
        }
        
        // Assign brand to product
        wp_set_object_terms($product_id, [(int) $term_id], $brand_tax, false);
        $assigned++;
        
        $batch++;
        if ($batch % 500 === 0) {
            echo "  Progress: $assigned assigned, $not_found not found\n";
        }
    }
}

echo "\n=== DONE ===\n";
echo "Brands created: " . count($brand_term_map) . "\n";
echo "Products assigned: $assigned\n";
echo "Products not found: $not_found\n";

// ─── Verify ─────────────────────────────────────────────────────
echo "\n=== TOP BRANDS BY PRODUCT COUNT ===\n";
$terms = get_terms([
    'taxonomy'   => $brand_tax,
    'orderby'    => 'count',
    'order'      => 'DESC',
    'number'     => 15,
    'hide_empty' => false,
]);

foreach ($terms as $term) {
    echo "  {$term->name}: {$term->count} products\n";
}
