<?php
/**
 * Retry missing brand images from holeno.com
 * Run: wp eval-file retry_brand_images.php
 */
require_once ABSPATH . 'wp-admin/includes/media.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

$missing = [
    'Absolute Holistic' => 'P100', 'Buddy Biscuits' => 'P107',
    'EHP' => 'P114', 'Pet Clay' => 'P162', 'Fop' => 'P120',
    'GEO IMPERIAL' => 'P120', 'MDF' => 'P129', 'Purina-Pro Plan' => 'P133',
    'PET HEAD' => 'P136', 'Profine' => 'P140', 'Rigor Cat' => 'P142',
    'Schesir' => 'P144', 'TIKICAT' => 'P151', 'Twist Fresh' => 'P152',
    'Wildly Natural' => 'P157', 'Local Brands' => 'P170',
    "Alfie's Diner" => 'P101', "Butcher's" => 'P109',
];

$ok = 0; $fail = 0;
foreach ($missing as $name => $code) {
    $term = get_term_by('name', $name, 'product_brand');
    if (!$term) { echo "SKIP: $name — no term\n"; continue; }
    
    // Check if already has image
    $existing = get_term_meta($term->term_id, 'thumbnail_id', true);
    if ($existing && $existing > 0) { echo "EXISTS: $name\n"; continue; }
    
    // Try multiple CDN sources
    $urls = [
        "https://holeno.com/imghd/brands/$code.png",
        "https://holeno.com/img/brands/$code.png",
        "https://holeno.com/imghd/brands/$code.jpg",
        "https://ppte.sa/img/brands/$code.png",
    ];
    
    $downloaded = false;
    foreach ($urls as $url) {
        $tmp = download_url($url, 10);
        if (!is_wp_error($tmp)) {
            $downloaded = $tmp;
            break;
        }
    }
    
    if (!$downloaded) {
        echo "FAIL: $name — all sources 404\n";
        $fail++;
        continue;
    }
    
    $ext = pathinfo(parse_url($url, PHP_URL_PATH), PATHINFO_EXTENSION) ?: 'png';
    $file_array = ['name' => 'brand-' . sanitize_title($name) . ".$ext", 'tmp_name' => $downloaded];
    $attach_id = media_handle_sideload($file_array, 0, "Brand: $name");
    
    if (is_wp_error($attach_id)) {
        @unlink($downloaded);
        echo "FAIL: $name — sideload error\n";
        $fail++;
        continue;
    }
    
    update_term_meta($term->term_id, 'thumbnail_id', $attach_id);
    echo "OK: $name (attach=$attach_id)\n";
    $ok++;
}

echo "\nRecovered: $ok, Still missing: $fail\n";

// Final tally
$terms = get_terms(['taxonomy' => 'product_brand', 'hide_empty' => false]);
$with = 0;
foreach ($terms as $t) {
    $thumb = get_term_meta($t->term_id, 'thumbnail_id', true);
    if ($thumb && $thumb > 0) $with++;
}
echo "Final: $with / " . count($terms) . " brands with images\n";
