<?php
/**
 * Fix Parent Product Attributes for Zooboxi
 * =========================================
 * Scans all products, checks if any 'pa_' attributes are marked as local (is_taxonomy = 0),
 * fixes them to be global taxonomies (is_taxonomy = 1, sets taxonomy ID), associates the parent
 * product with the terms using wp_set_object_terms(), and saves the updated attributes.
 * 
 * Run using: wp eval-file fix_parent_attributes.php --path=/home/storezooboxi/public_html
 */

if (!defined('ABSPATH')) {
    exit;
}

global $wpdb;

echo "🔍 Starting Parent Product Attributes Analysis & Repair...\n";
echo str_repeat('=', 70) . "\n";

// Query all parent products (both variable and simple)
$products = get_posts([
    'post_type' => 'product',
    'posts_per_page' => -1,
    'post_status' => 'any',
]);

if (empty($products)) {
    echo "❌ No products found in database.\n";
    exit;
}

echo "Found " . count($products) . " products to check.\n\n";

$updated_products_count = 0;
$fixed_attributes_count = 0;

foreach ($products as $prod) {
    $product_id = $prod->ID;
    $product_title = $prod->post_title;
    
    // Get product attributes meta
    $attributes = get_post_meta($product_id, '_product_attributes', true);
    
    if (empty($attributes) || !is_array($attributes)) {
        continue;
    }
    
    $is_dirty = false;
    
    foreach ($attributes as $key => $attr) {
        $name = $attr['name'];
        
        // If it starts with 'pa_' and is currently marked as local (is_taxonomy = 0)
        if (strpos($name, 'pa_') === 0 && (!isset($attr['is_taxonomy']) || $attr['is_taxonomy'] == 0)) {
            echo "🛠️ Fixing Attribute '{$name}' for Product ID {$product_id} ('{$product_title}'):\n";
            
            // Get correct taxonomy ID
            $taxonomy_id = wc_attribute_taxonomy_id_by_name($name);
            
            if ($taxonomy_id > 0) {
                // Determine terms to associate
                $terms_to_set = [];
                
                // If it is stored as an array of options or pipe-separated value string
                if (isset($attr['value']) && !empty($attr['value'])) {
                    // Extract term names from the pipe-separated string
                    $term_names = array_map('trim', explode('|', $attr['value']));
                    
                    foreach ($term_names as $term_name) {
                        if (empty($term_name)) continue;
                        
                        // Insert term if it doesn't exist
                        if (!term_exists($term_name, $name)) {
                            $inserted = wp_insert_term($term_name, $name);
                            if (!is_wp_error($inserted)) {
                                $terms_to_set[] = $term_name;
                            }
                        } else {
                            $terms_to_set[] = $term_name;
                        }
                    }
                }
                
                // Associate terms with the parent product
                if (!empty($terms_to_set)) {
                    $set_result = wp_set_object_terms($product_id, $terms_to_set, $name, false);
                    if (is_wp_error($set_result)) {
                        echo "   ⚠️ Failed to set object terms for '{$name}': " . $set_result->get_error_message() . "\n";
                    } else {
                        echo "   ✅ Associated terms: " . implode(', ', $terms_to_set) . "\n";
                    }
                }
                
                // Update attribute array to be a proper taxonomy attribute
                $attributes[$key]['id'] = $taxonomy_id;
                $attributes[$key]['is_taxonomy'] = 1;
                $attributes[$key]['value'] = ''; // Clear value for taxonomy attributes in _product_attributes
                
                $fixed_attributes_count++;
                $is_dirty = true;
            } else {
                echo "   ⚠️ Global taxonomy '{$name}' exists in DB but WooCommerce taxonomy ID not found.\n";
            }
        }
    }
    
    if ($is_dirty) {
        update_post_meta($product_id, '_product_attributes', $attributes);
        $updated_products_count++;
        echo "💾 Saved updated attributes for Product ID {$product_id}!\n\n";
    }
}

echo str_repeat('=', 70) . "\n";
echo "🎉 Repair Completed!\n";
echo "   Total Products Updated: " . $updated_products_count . "\n";
echo "   Total Attributes Fixed: " . $fixed_attributes_count . "\n";

// Clear WooCommerce transients and site cache
echo "\n🧹 Flushing WooCommerce transients and WordPress cache...\n";
delete_transient('wc_attribute_taxonomies');
if (function_exists('wc_delete_product_transients')) {
    wc_delete_product_transients();
}
wp_cache_flush();
echo "✅ Cache and transients flushed successfully!\n";
