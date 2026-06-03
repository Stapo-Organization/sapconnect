<?php
/**
 * Import brand images from ppte.sa CDN into WooCommerce.
 * Run: wp eval-file import_brand_images.php
 */

if (!defined('ABSPATH')) {
    require_once dirname(__FILE__) . '/../wp-load.php';
}

require_once ABSPATH . 'wp-admin/includes/media.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

// Brand code => image URL mapping from SAP
$brand_images = [
    '173' => 'https://ppte.sa/imghd/brands/P100.png',
    '174' => 'https://ppte.sa/imghd/brands/P101.png',
    '175' => 'https://ppte.sa/imghd/brands/P102.png',
    '252' => 'https://ppte.sa/imghd/brands/P171.png',
    '180' => 'https://ppte.sa/imghd/brands/P165.png',
    '177' => 'https://ppte.sa/imghd/brands/P104.png',
    '178' => 'https://ppte.sa/imghd/brands/P105.png',
    '179' => 'https://ppte.sa/imghd/brands/P106.png',
    '181' => 'https://ppte.sa/imghd/brands/P107.png',
    '182' => 'https://ppte.sa/imghd/brands/P108.png',
    '183' => 'https://ppte.sa/imghd/brands/P109.png',
    '185' => 'https://ppte.sa/imghd/brands/P111.png',
    '102' => 'https://ppte.sa/imghd/brands/P163.png',
    '184' => 'https://ppte.sa/imghd/brands/P110.png',
    '103' => 'https://ppte.sa/imghd/brands/P164.png',
    '187' => 'https://ppte.sa/imghd/brands/P112.png',
    '189' => 'https://ppte.sa/imghd/brands/P114.png',
    '188' => 'https://ppte.sa/imghd/brands/P113.png',
    '190' => 'https://ppte.sa/imghd/brands/P115.png',
    '191' => 'https://ppte.sa/imghd/brands/P116.png',
    '100' => 'https://ppte.sa/imghd/brands/P161.png',
    '101' => 'https://ppte.sa/imghd/brands/P162.png',
    '176' => 'https://ppte.sa/imghd/brands/P103.png',
    '186' => 'https://ppte.sa/imghd/brands/P166.png',
    '192' => 'https://ppte.sa/imghd/brands/P117.png',
    '193' => 'https://ppte.sa/imghd/brands/P120.png',
    '194' => 'https://ppte.sa/imghd/brands/P119.png',
    '195' => 'https://ppte.sa/imghd/brands/P120.png',
    '196' => 'https://ppte.sa/imghd/brands/P167.png',
    '197' => 'https://ppte.sa/imghd/brands/P121.png',
    '198' => 'https://ppte.sa/imghd/brands/P122.png',
    '199' => 'https://ppte.sa/imghd/brands/P123.png',
    '200' => 'https://ppte.sa/imghd/brands/P124.png',
    '201' => 'https://ppte.sa/imghd/brands/P168.png',
    '202' => 'https://ppte.sa/imghd/brands/P125.png',
    '203' => 'https://ppte.sa/imghd/brands/P126.png',
    '204' => 'https://ppte.sa/imghd/brands/P127.png',
    '205' => 'https://ppte.sa/imghd/brands/P128.png',
    '206' => 'https://ppte.sa/imghd/brands/P129.png',
    '207' => 'https://ppte.sa/imghd/brands/P130.png',
    '208' => 'https://ppte.sa/imghd/brands/P131.png',
    '209' => 'https://ppte.sa/imghd/brands/P169.png',
    '210' => 'https://ppte.sa/imghd/brands/P132.png',
    '211' => 'https://ppte.sa/imghd/brands/P133.png',
    '212' => 'https://ppte.sa/imghd/brands/P134.png',
    '213' => 'https://ppte.sa/imghd/brands/P135.png',
    '214' => 'https://ppte.sa/imghd/brands/P136.png',
    '215' => 'https://ppte.sa/imghd/brands/P137.png',
    '217' => 'https://ppte.sa/imghd/brands/P138.png',
    '218' => 'https://ppte.sa/imghd/brands/P139.png',
    '219' => 'https://ppte.sa/imghd/brands/P140.png',
    '220' => 'https://ppte.sa/imghd/brands/P141.png',
    '221' => 'https://ppte.sa/imghd/brands/P142.png',
    '222' => 'https://ppte.sa/imghd/brands/P143.png',
    '223' => 'https://ppte.sa/imghd/brands/P144.png',
    '224' => 'https://ppte.sa/imghd/brands/P145.png',
    '225' => 'https://ppte.sa/imghd/brands/P146.png',
    '226' => 'https://ppte.sa/imghd/brands/P147.png',
    '227' => 'https://ppte.sa/imghd/brands/P148.png',
    '228' => 'https://ppte.sa/imghd/brands/P149.png',
    '230' => 'https://ppte.sa/imghd/brands/P150.png',
    '231' => 'https://ppte.sa/imghd/brands/P151.png',
    '232' => 'https://ppte.sa/imghd/brands/P152.png',
    '233' => 'https://ppte.sa/imghd/brands/P153.png',
    '234' => 'https://ppte.sa/imghd/brands/P154.png',
    '235' => 'https://ppte.sa/imghd/brands/P155.png',
    '236' => 'https://ppte.sa/imghd/brands/P156.png',
    '237' => 'https://ppte.sa/imghd/brands/P157.png',
    '238' => 'https://ppte.sa/imghd/brands/P158.png',
    '239' => 'https://ppte.sa/imghd/brands/P159.png',
    '240' => 'https://ppte.sa/imghd/brands/P160.png',
    '241' => 'https://ppte.sa/imghd/brands/P170.png',
    '255' => 'https://ppte.sa/imghd/brands/P172.png',
    '256' => 'https://ppte.sa/imghd/brands/P173.png',
    '257' => 'https://ppte.sa/imghd/brands/P174.png',
    '258' => 'https://ppte.sa/imghd/brands/P175.png',
    '260' => 'https://ppte.sa/imghd/brands/P176.png',
    '261' => 'https://ppte.sa/imghd/brands/P177.png',
    '262' => 'https://ppte.sa/imghd/brands/P178.png',
    '263' => 'https://ppte.sa/imghd/brands/P179.png',
    '264' => 'https://ppte.sa/imghd/brands/P180.png',
    '265' => 'https://ppte.sa/imghd/brands/P181.png',
    '266' => 'https://ppte.sa/imghd/brands/P182.png',
    '271' => 'https://ppte.sa/imghd/brands/P183.png',
    '272' => 'https://ppte.sa/imghd/brands/P184.png',
    '273' => 'https://ppte.sa/imghd/brands/P185.png',
];

// Brand code => brand name (for matching WC terms)
$brand_names = [
    '173' => 'Absolute Holistic', '174' => "Alfie's Diner", '175' => 'Altimate Pet',
    '252' => "Dr.Clauder's", '180' => 'Bags On Board', '177' => 'Bavaro',
    '178' => 'Beaphar', '179' => 'BioSand', '181' => 'Buddy Biscuits',
    '182' => 'Buddy Wash', '183' => "Butcher's", '185' => 'CATIDEA',
    '102' => 'CEDE', '184' => 'Cat H2O & Dog', '103' => 'Country',
    '187' => 'Crazy Dog', '189' => 'EHP', '188' => "Earth's Goodies",
    '190' => 'Espree', '191' => 'Feline Go', '100' => 'Princess',
    '101' => 'Pet Clay', '176' => 'Applaws', '186' => 'Solid Gold',
    '192' => 'Fida', '193' => 'Fop', '194' => 'Fruitables',
    '195' => 'GEO IMPERIAL', '196' => 'YowUp', '197' => 'GoDog',
    '198' => 'Hear Doggy', '199' => 'INABA', '200' => 'Inodorina',
    '201' => 'Felyn Go', '202' => 'Josera', '203' => 'Kit Cat',
    '204' => 'LindoCat', '205' => 'Mark & Chappell', '206' => 'MDF',
    '207' => 'MPB', '208' => 'MPS', '209' => 'PUUR',
    '210' => 'My Family', '211' => 'Purina-Pro Plan', '212' => 'Nutri-Vet',
    '213' => 'Our Pets', '214' => 'PET HEAD', '215' => 'PetLinks',
    '217' => 'PPTCO', '218' => 'Prevuepet', '219' => 'Profine',
    '220' => 'Remedy + Recovery', '221' => 'Rigor Cat', '222' => 'Sanal',
    '223' => 'Schesir', '224' => 'Sherpa', '225' => 'Signor Gatto',
    '226' => 'Simple Solution', '227' => 'SmartyKat', '228' => 'Stefan Plast',
    '230' => 'The Higgins', '231' => 'TIKICAT', '232' => 'Twist Fresh',
    '233' => 'Versele Laga', '234' => 'Vets Best', '235' => 'Whimzees',
    '236' => 'Wilda Siberica', '237' => 'Wildly Natural', '238' => 'Witte Molen',
    '239' => 'Zolux', '240' => 'Zupreem', '241' => 'Local Brands',
    '255' => 'Babin', '256' => 'Forza10', '257' => 'Garden Bites',
    '258' => 'I love Happy Cats', '260' => 'Zesty Paws', '261' => 'Core',
    '262' => 'Bio PetActive', '263' => 'Acana', '264' => 'Orijen',
    '265' => 'Arya', '266' => 'Coockoo', '271' => 'Felyn Go Raw',
    '272' => 'Natural Code', '273' => 'Instinct',
];

echo "=== IMPORTING BRAND IMAGES ===\n";
echo "Total brands: " . count($brand_images) . "\n\n";

$imported = 0;
$skipped = 0;
$failed = 0;

foreach ($brand_images as $code => $url) {
    $name = $brand_names[$code] ?? "Brand $code";
    
    // Find WC brand term
    $term = get_term_by('name', $name, 'product_brand');
    if (!$term) {
        echo "  SKIP: $name — term not found\n";
        $skipped++;
        continue;
    }
    
    // Check if already has thumbnail
    $existing = get_term_meta($term->term_id, 'thumbnail_id', true);
    if ($existing && $existing > 0) {
        echo "  EXISTS: $name — already has image\n";
        $skipped++;
        continue;
    }
    
    // Download and sideload the image
    $tmp = download_url($url, 15);
    if (is_wp_error($tmp)) {
        echo "  FAIL: $name — download error: " . $tmp->get_error_message() . "\n";
        $failed++;
        continue;
    }
    
    $file_array = [
        'name'     => "brand-" . sanitize_title($name) . ".png",
        'tmp_name' => $tmp,
    ];
    
    $attach_id = media_handle_sideload($file_array, 0, "Brand: $name");
    
    if (is_wp_error($attach_id)) {
        @unlink($tmp);
        echo "  FAIL: $name — sideload error: " . $attach_id->get_error_message() . "\n";
        $failed++;
        continue;
    }
    
    // Set as brand thumbnail
    update_term_meta($term->term_id, 'thumbnail_id', $attach_id);
    
    $imported++;
    echo "  OK: $name (attach=$attach_id)\n";
}

echo "\n=== DONE ===\n";
echo "Imported: $imported\n";
echo "Skipped: $skipped\n";
echo "Failed: $failed\n";

// Verify
echo "\n=== BRANDS WITH IMAGES ===\n";
$terms = get_terms(['taxonomy' => 'product_brand', 'hide_empty' => false]);
$with_img = 0;
foreach ($terms as $t) {
    $thumb = get_term_meta($t->term_id, 'thumbnail_id', true);
    if ($thumb && $thumb > 0) $with_img++;
}
echo "Brands with images: $with_img / " . count($terms) . "\n";
