<?php
/**
 * Batch Image Importer — downloads product images from ppte.sa
 * Run with: wp eval-file import_images.php
 *
 * Strategy:
 * - Fetch product images in batches of 20
 * - Skip products that already have images
 * - Use wp_upload_bits + wp_insert_attachment
 * - Set as product thumbnail
 */

if (!defined('ABSPATH')) {
    // Load WordPress
    require_once dirname(__FILE__) . '/wp-load.php';
}

// Include media functions
require_once ABSPATH . 'wp-admin/includes/media.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

$batch_size = 20;
$offset = 0;
$total_imported = 0;
$total_skipped = 0;
$total_missing = 0;

echo "🖼️  Zooboxi Image Import Starting...\n";
echo str_repeat('─', 60) . "\n";

while (true) {
    $products = wc_get_products([
        'status'  => 'publish',
        'limit'   => $batch_size,
        'offset'  => $offset,
        'orderby' => 'ID',
        'order'   => 'ASC',
    ]);

    if (empty($products)) break;

    foreach ($products as $product) {
        $sku = $product->get_sku();
        if (empty($sku)) {
            $total_skipped++;
            continue;
        }

        // Skip if already has image
        if ($product->get_image_id()) {
            $total_skipped++;
            continue;
        }

        // Build image URL: https://ppte.sa/imghd/{first4}/{sku}.png
        $folder = substr($sku, 0, 4);
        $imageUrl = "https://ppte.sa/imghd/{$folder}/{$sku}.png";

        // Check if image exists (HEAD request)
        $head = wp_remote_head($imageUrl, ['timeout' => 5, 'sslverify' => false]);
        if (is_wp_error($head) || wp_remote_retrieve_response_code($head) !== 200) {
            $total_missing++;
            continue;
        }

        // Download image
        $response = wp_remote_get($imageUrl, ['timeout' => 15, 'sslverify' => false]);
        if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {
            $total_missing++;
            continue;
        }

        $image_data = wp_remote_retrieve_body($response);
        $filename = sanitize_file_name($sku . '.png');

        // Upload to WordPress media library
        $upload = wp_upload_bits($filename, null, $image_data);
        if ($upload['error']) {
            echo "  ❌ Upload error for {$sku}: {$upload['error']}\n";
            continue;
        }

        // Create attachment
        $filetype = wp_check_filetype($upload['file']);
        $attachment = [
            'post_mime_type' => $filetype['type'],
            'post_title'     => $product->get_name(),
            'post_content'   => '',
            'post_status'    => 'inherit',
        ];

        $attach_id = wp_insert_attachment($attachment, $upload['file'], $product->get_id());
        if (is_wp_error($attach_id)) {
            echo "  ❌ Attachment error for {$sku}\n";
            continue;
        }

        // Generate thumbnails
        $attach_data = wp_generate_attachment_metadata($attach_id, $upload['file']);
        wp_update_attachment_metadata($attach_id, $attach_data);

        // Set as product image
        $product->set_image_id($attach_id);
        $product->save();

        $total_imported++;

        if ($total_imported % 50 === 0) {
            echo "  ✅ Imported {$total_imported} images so far...\n";
        }
    }

    $offset += $batch_size;

    // Memory cleanup every 100 products
    if ($offset % 100 === 0) {
        wp_cache_flush();
        gc_collect_cycles();
    }
}

echo str_repeat('─', 60) . "\n";
echo "📊 Results:\n";
echo "  ✅ Imported: {$total_imported}\n";
echo "  ⏭️  Skipped (has image): {$total_skipped}\n";
echo "  ❌ Missing (404): {$total_missing}\n";
echo "  📦 Total processed: " . ($total_imported + $total_skipped + $total_missing) . "\n";
echo "Done!\n";
