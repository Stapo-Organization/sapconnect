<?php
/**
 * Remove duplicate products (same _zooboxi_item_code).
 * Keeps the version with stock+image, trashes the rest.
 * Run: wp eval-file remove_duplicates.php
 */

global $wpdb;

$dupes = $wpdb->get_results("
    SELECT pm.meta_value as item_code
    FROM {$wpdb->postmeta} pm
    JOIN {$wpdb->posts} p ON p.ID = pm.post_id
    WHERE pm.meta_key = '_zooboxi_item_code'
    AND p.post_type = 'product'
    AND p.post_status = 'publish'
    GROUP BY pm.meta_value
    HAVING COUNT(*) > 1
");

echo "=== REMOVING DUPLICATE PRODUCTS ===\n";
echo "Duplicate groups found: " . count($dupes) . "\n\n";

$trashed = 0;
$errors = 0;

foreach ($dupes as $d) {
    $prods = $wpdb->get_results($wpdb->prepare("
        SELECT pm.post_id,
            (SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id=pm.post_id AND meta_key='_stock') as stock,
            (SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id=pm.post_id AND meta_key='_thumbnail_id') as thumb,
            (SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id=pm.post_id AND meta_key='_zooboxi_warehouse_stock') as wh_stock
        FROM {$wpdb->postmeta} pm
        JOIN {$wpdb->posts} p ON p.ID = pm.post_id
        WHERE pm.meta_key = '_zooboxi_item_code' AND pm.meta_value = %s
        AND p.post_type = 'product' AND p.post_status = 'publish'
        ORDER BY pm.post_id ASC
    ", $d->item_code));

    if (count($prods) < 2) continue;

    // Score each: stock > 0 = +10, has_thumbnail = +5, has_wh_stock = +3, lower ID = +1
    $best = null;
    $best_score = -1;

    foreach ($prods as $p) {
        $score = 0;
        if ((float)$p->stock > 0) $score += 10;
        if (!empty($p->thumb) && $p->thumb > 0) $score += 5;
        if (!empty($p->wh_stock) && strlen($p->wh_stock) > 5) $score += 3;
        $score += 1; // older = lower ID gets picked first if tied

        if ($score > $best_score) {
            $best_score = $score;
            $best = $p;
        }
    }

    // Trash everything except best
    foreach ($prods as $p) {
        if ($p->post_id == $best->post_id) continue;

        $result = wp_trash_post($p->post_id);
        if ($result) {
            $trashed++;
        } else {
            echo "  ERROR trashing #{$p->post_id}\n";
            $errors++;
        }
    }
}

echo "=== DONE ===\n";
echo "Trashed: $trashed\n";
echo "Errors: $errors\n";

// Verify
$remaining_dupes = $wpdb->get_var("
    SELECT COUNT(*) FROM (
        SELECT pm.meta_value
        FROM {$wpdb->postmeta} pm
        JOIN {$wpdb->posts} p ON p.ID = pm.post_id
        WHERE pm.meta_key = '_zooboxi_item_code'
        AND p.post_type = 'product'
        AND p.post_status = 'publish'
        GROUP BY pm.meta_value
        HAVING COUNT(*) > 1
    ) x
");
$total = $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status = 'publish'");
echo "\nRemaining duplicates: $remaining_dupes\n";
echo "Total published products: $total\n";
