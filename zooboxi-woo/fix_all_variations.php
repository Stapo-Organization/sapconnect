<?php
/**
 * Fix Variation Meta Slugs for Zooboxi
 * =====================================
 * This script scans the database for variation postmeta keys starting with 'attribute_pa_'
 * and ensures that their values store the term slug instead of the raw Arabic term name.
 * 
 * Run using: wp eval-file fix_all_variations.php --path=/home/storezooboxi/public_html
 */

if (!defined('ABSPATH')) {
    exit; // Exit if accessed directly
}

global $wpdb;

echo "🔍 Starting Variable Product Meta Sweep...\n";
echo str_repeat('=', 60) . "\n";

// Query all postmeta records for product variations that are global taxonomies
$meta_records = $wpdb->get_results("
    SELECT meta_id, post_id, meta_key, meta_value 
    FROM {$wpdb->postmeta} 
    WHERE meta_key LIKE 'attribute_pa_%'
");

if (empty($meta_records)) {
    echo "✅ No variation attributes found in database.\n";
    exit;
}

echo "Found " . count($meta_records) . " variation attribute meta records to check.\n\n";

$updated_count = 0;
$skipped_count = 0;

foreach ($meta_records as $record) {
    $meta_id = $record->meta_id;
    $post_id = $record->post_id;
    $meta_key = $record->meta_key;
    $meta_value = trim($record->meta_value);

    // Skip empty values
    if ($meta_value === '') {
        $skipped_count++;
        continue;
    }

    // Determine the taxonomy name (remove 'attribute_' prefix)
    $taxonomy = str_replace('attribute_', '', $meta_key);

    if (!taxonomy_exists($taxonomy)) {
        echo "⚠️ Taxonomy '{$taxonomy}' does not exist (meta_key: '{$meta_key}'). Skipping.\n";
        $skipped_count++;
        continue;
    }

    // Look up term by name or by current slug to verify
    // First, try by name
    $term = get_term_by('name', $meta_value, $taxonomy);
    
    // If not found by name, it might already be the slug (URL-encoded or raw)
    if (!$term) {
        $term = get_term_by('slug', $meta_value, $taxonomy);
    }
    
    // If we still can't find it, try decoding URL-encoded value in case it is double-encoded
    if (!$term && strpos($meta_value, '%') !== false) {
        $decoded_value = urldecode($meta_value);
        $term = get_term_by('name', $decoded_value, $taxonomy);
        if (!$term) {
            $term = get_term_by('slug', $decoded_value, $taxonomy);
        }
    }

    if (!$term || is_wp_error($term)) {
        echo "❓ No matching term found for value '{$meta_value}' in taxonomy '{$taxonomy}' (Variation ID: {$post_id}). Skipping.\n";
        $skipped_count++;
        continue;
    }

    $correct_slug = $term->slug;

    // If the meta value is NOT already the correct slug, we need to update it
    if ($meta_value !== $correct_slug) {
        $wpdb->update(
            $wpdb->postmeta,
            ['meta_value' => $correct_slug],
            ['meta_id' => $meta_id]
        );

        echo "🔄 Updated Meta ID {$meta_id} (Variation ID: {$post_id}) | Key: '{$meta_key}'\n";
        echo "   From: '{$meta_value}'\n";
        echo "   To:   '{$correct_slug}' (Term Name: '{$term->name}')\n\n";
        $updated_count++;
    } else {
        $skipped_count++;
    }
}

echo str_repeat('=', 60) . "\n";
echo "🎉 Sweep Completed!\n";
echo "   Total Checked: " . count($meta_records) . "\n";
echo "   Total Updated: " . $updated_count . "\n";
echo "   Total Skipped: " . $skipped_count . "\n";

// Flush transients and cache to ensure changes take effect immediately
echo "\n🧹 Flushing WooCommerce transients and WordPress cache...\n";
delete_transient('wc_attribute_taxonomies');
if (function_exists('wc_delete_product_transients')) {
    wc_delete_product_transients();
}
wp_cache_flush();
echo "✅ Cache and transients flushed successfully!\n";
