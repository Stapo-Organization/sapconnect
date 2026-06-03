<?php
/**
 * Zooboxi Corrupt Products Cleanup
 * =================================
 * Finds and safely deletes all products that have post_type = 'product'
 * but are incorrectly linked to a 'variation' product type.
 * 
 * Usage: wp eval-file delete_corrupt.php --path=public_html
 */

global $wpdb;

// Query the ID of all corrupted products
$ids = $wpdb->get_col(
    "SELECT p.ID FROM {$wpdb->posts} p 
     INNER JOIN {$wpdb->term_relationships} tr ON p.ID = tr.object_id 
     INNER JOIN {$wpdb->term_taxonomy} tt ON tr.term_taxonomy_id = tt.term_taxonomy_id 
     WHERE p.post_type = 'product' 
       AND tt.taxonomy = 'product_type' 
       AND tt.term_id = 2253"
);

$total = count($ids);
WP_CLI::log("🔍 Found {$total} corrupted products in the database.");

if ($total === 0) {
    WP_CLI::success("No corrupted products found!");
    exit(0);
}

WP_CLI::log("🗑️ Starting deletion...");

foreach ($ids as $index => $id) {
    wp_delete_post($id, true); // true forces bypass trash for immediate deletion
    
    if (($index + 1) % 100 === 0) {
        WP_CLI::log("  Deleted " . ($index + 1) . "/{$total} products...");
        wp_cache_flush(); // Flush cache to prevent memory leak
    }
}

WP_CLI::success("All {$total} corrupted products have been safely deleted!");
