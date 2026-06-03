<?php
/**
 * Zooboxi Product Translation Script
 * Creates English translations for products using Polylang API
 * Run via: wp eval-file translate_products.php
 * 
 * Processes in batches to avoid memory issues.
 * Pass --offset=N and --limit=N to control batching.
 */

// Parse CLI args - support both positional (offset limit) and named (--offset=N)
$offset = 0;
$limit = 500;

// Positional: first arg = offset, second arg = limit
if (isset($args[0]) && is_numeric($args[0])) $offset = intval($args[0]);
if (isset($args[1]) && is_numeric($args[1])) $limit = intval($args[1]);

// Named args override
foreach ($args as $arg) {
    if (strpos($arg, '--offset=') === 0) $offset = intval(substr($arg, 9));
    if (strpos($arg, '--limit=') === 0) $limit = intval(substr($arg, 8));
}

$json_file = dirname(__FILE__) . '/product_translations.json';
if (!file_exists($json_file)) {
    WP_CLI::error("product_translations.json not found!");
    exit(1);
}

if (!function_exists('pll_save_post_translations')) {
    WP_CLI::error("Polylang is not active!");
    exit(1);
}

$all_products = json_decode(file_get_contents($json_file), true);
$total = count($all_products);
$products = array_slice($all_products, $offset, $limit);

WP_CLI::log("Processing products {$offset} to " . ($offset + count($products)) . " of {$total}");

$created = 0;
$skipped = 0;
$errors = 0;
$not_found = 0;

foreach ($products as $i => $p) {
    $sku = $p['sku'];
    $name_en = $p['name_en'];
    $desc_en = $p['desc_en'];
    $short_desc_en = $p['short_desc_en'];
    $cats_en_str = $p['cats_en'];
    
    // Find Arabic product by SKU
    $ar_product_id = wc_get_product_id_by_sku($sku);
    if (!$ar_product_id) {
        $not_found++;
        continue;
    }
    
    $ar_product = wc_get_product($ar_product_id);
    if (!$ar_product) {
        $errors++;
        continue;
    }

    // Skip if it is a product variation (variations are handled inside their variable parents)
    if ($ar_product->is_type('variation') || $ar_product->get_parent_id() > 0) {
        $skipped++;
        continue;
    }
    
    // Set Arabic product language
    pll_set_post_language($ar_product_id, 'ar');
    
    // Check if English translation already exists
    $existing_en = pll_get_post($ar_product_id, 'en');
    if ($existing_en && $existing_en != $ar_product_id) {
        $skipped++;
        continue;
    }
    
    // Create English product post
    $en_slug = sanitize_title($name_en);
    
    $en_post_data = [
        'post_title'   => $name_en,
        'post_content' => $desc_en,
        'post_excerpt' => $short_desc_en,
        'post_status'  => $ar_product->get_status(),
        'post_type'    => 'product',
        'post_name'    => $en_slug,
    ];
    
    $en_post_id = wp_insert_post($en_post_data);
    
    if (is_wp_error($en_post_id) || !$en_post_id) {
        WP_CLI::warning("Failed to create EN product for SKU {$sku}");
        $errors++;
        continue;
    }
    
    // Copy all product meta from Arabic to English
    $meta_keys_to_copy = [
        '_price', '_regular_price', '_sale_price', '_sale_price_dates_from', '_sale_price_dates_to',
        '_sku', '_stock', '_stock_status', '_manage_stock', '_backorders',
        '_weight', '_length', '_width', '_height',
        '_thumbnail_id', '_product_image_gallery',
        '_virtual', '_downloadable', '_tax_status', '_tax_class',
        'total_sales', '_wc_average_rating', '_wc_review_count',
    ];
    
    foreach ($meta_keys_to_copy as $key) {
        $val = get_post_meta($ar_product_id, $key, true);
        if ($val !== '' && $val !== false) {
            update_post_meta($en_post_id, $key, $val);
        }
    }
    
    // Set product type term
    $product_type = $ar_product->get_type();
    wp_set_object_terms($en_post_id, $product_type, 'product_type');
    
    // Set product visibility
    wp_set_object_terms($en_post_id, 'visible', 'product_visibility');
    
    // Assign English categories
    if ($cats_en_str) {
        $cat_names = array_map('trim', explode(',', $cats_en_str));
        $en_cat_ids = [];
        foreach ($cat_names as $cat_path) {
            $parts = array_map('trim', explode('>', $cat_path));
            $cat_name = end($parts);
            // Find EN category by name
            $term = get_term_by('name', $cat_name, 'product_cat');
            if ($term) {
                $lang = pll_get_term_language($term->term_id);
                if ($lang === 'en') {
                    $en_cat_ids[] = $term->term_id;
                }
            }
        }
        if (!empty($en_cat_ids)) {
            wp_set_object_terms($en_post_id, $en_cat_ids, 'product_cat');
        }
    }
    
    // Copy product attributes
    $product_attributes = get_post_meta($ar_product_id, '_product_attributes', true);
    if (!empty($product_attributes)) {
        update_post_meta($en_post_id, '_product_attributes', $product_attributes);
    }
    
    // For variable products, handle variations
    if ($product_type === 'variable') {
        // Copy default attributes
        $default_attrs = get_post_meta($ar_product_id, '_default_attributes', true);
        if ($default_attrs) {
            update_post_meta($en_post_id, '_default_attributes', $default_attrs);
        }
        
        // Clone variations
        $variations = $ar_product->get_children();
        foreach ($variations as $var_id) {
            $var_post = get_post($var_id);
            if (!$var_post) continue;
            
            $en_var_data = [
                'post_title' => $var_post->post_title,
                'post_content' => '',
                'post_status' => $var_post->post_status,
                'post_type' => 'product_variation',
                'post_parent' => $en_post_id,
                'menu_order' => $var_post->menu_order,
            ];
            
            $en_var_id = wp_insert_post($en_var_data);
            if (!$en_var_id || is_wp_error($en_var_id)) continue;
            
            // Copy variation meta
            $var_meta = get_post_meta($var_id);
            foreach ($var_meta as $mk => $mv) {
                if (strpos($mk, '_') === 0 || strpos($mk, 'attribute_') === 0) {
                    update_post_meta($en_var_id, $mk, $mv[0]);
                }
            }
        }
        
        // Sync variable product price range
        WC_Product_Variable::sync($en_post_id);
    }
    
    // Set language and link translations
    pll_set_post_language($en_post_id, 'en');
    pll_save_post_translations([
        'ar' => $ar_product_id,
        'en' => $en_post_id,
    ]);
    
    // Copy product tags
    $tags = wp_get_object_terms($ar_product_id, 'product_tag', ['fields' => 'ids']);
    if (!empty($tags) && !is_wp_error($tags)) {
        wp_set_object_terms($en_post_id, $tags, 'product_tag');
    }
    
    $created++;
    
    if ($created % 100 === 0) {
        WP_CLI::log("Progress: {$created} created, {$skipped} skipped, {$not_found} not found, {$errors} errors...");
        wp_cache_flush();
    }
}

WP_CLI::success("Batch complete (offset={$offset}, limit={$limit})!");
WP_CLI::log("  Created:   {$created}");
WP_CLI::log("  Skipped:   {$skipped}");
WP_CLI::log("  Not Found: {$not_found}");
WP_CLI::log("  Errors:    {$errors}");

if ($offset + $limit < $total) {
    $next_offset = $offset + $limit;
    WP_CLI::log("\nNext batch: wp eval-file translate_products.php -- --offset={$next_offset} --limit={$limit}");
}
