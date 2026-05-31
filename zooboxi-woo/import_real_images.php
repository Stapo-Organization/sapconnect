<?php
/**
 * Download and attach product images v2
 * Uses curl directly for more control, skips errors, longer timeout
 */
require_once __DIR__ . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/media.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

echo "=== IMPORTING PRODUCT IMAGES v2 ===\n\n";

global $wpdb;

$products = $wpdb->get_results("
    SELECT p.ID, pm.meta_value as item_code
    FROM {$wpdb->posts} p
    INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = '_zooboxi_item_code'
    LEFT JOIN {$wpdb->postmeta} thumb ON p.ID = thumb.post_id AND thumb.meta_key = '_thumbnail_id' AND thumb.meta_value > 0
    WHERE p.post_type = 'product' AND p.post_status = 'publish'
    AND thumb.meta_id IS NULL
    ORDER BY p.ID ASC
");

$total = count($products);
echo "Products without thumbnail: {$total}\n\n";

$imported = $failed = $skipped = 0;
$start = time();

function check_image_url($url) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_NOBODY => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 8,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => false,
    ]);
    curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return $code === 200;
}

function download_image_curl($url, $dest) {
    $ch = curl_init($url);
    $fp = fopen($dest, 'wb');
    curl_setopt_array($ch, [
        CURLOPT_FILE => $fp,
        CURLOPT_TIMEOUT => 60,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => false,
    ]);
    curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $size = curl_getinfo($ch, CURLINFO_SIZE_DOWNLOAD);
    curl_close($ch);
    fclose($fp);
    return ($code === 200 && $size > 1000);
}

foreach ($products as $prod) {
    $code = $prod->item_code;
    $folder = substr($code, 0, 4);
    
    $urls = [
        "https://gal.holeno.com/imghd/{$code}.png",
        "https://ppte.sa/imghd/{$folder}/{$code}.png",
    ];
    
    $found_url = null;
    foreach ($urls as $url) {
        if (check_image_url($url)) {
            $found_url = $url;
            break;
        }
    }
    
    if (!$found_url) {
        $skipped++;
        continue;
    }
    
    // Download to temp
    $tmp = wp_tempnam("{$code}.png");
    $ok = download_image_curl($found_url, $tmp);
    
    if (!$ok) {
        @unlink($tmp);
        $failed++;
        continue;
    }
    
    $file_array = ['name' => "{$code}.png", 'tmp_name' => $tmp];
    $attach_id = media_handle_sideload($file_array, $prod->ID, $code);
    
    if (is_wp_error($attach_id)) {
        @unlink($tmp);
        $failed++;
        continue;
    }
    
    set_post_thumbnail($prod->ID, $attach_id);
    $imported++;
    
    if ($imported % 25 === 0) {
        $elapsed = time() - $start;
        $rate = round($elapsed / $imported, 1);
        $eta = round(($total - $imported - $skipped - $failed) * $rate / 60);
        echo "[{$imported}/{$total}] imported={$imported} skip={$skipped} fail={$failed} ({$rate}s/img, ETA ~{$eta}min)\n";
        // Flush output
        ob_flush(); flush();
    }
    
    usleep(100000); // 100ms between downloads
}

$elapsed = time() - $start;
echo "\n=== RESULTS ===\n";
echo "Imported: {$imported}\n";
echo "Skipped: {$skipped}\n";
echo "Failed: {$failed}\n";
echo "Time: " . round($elapsed/60, 1) . " min\n";
echo "Done!\n";
