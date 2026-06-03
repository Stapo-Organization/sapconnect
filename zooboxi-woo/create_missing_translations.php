<?php
/**
 * Create Missing WooCommerce Page Translations
 * ============================================
 * This script ensures that Cart, Checkout, My Account, and Shop pages have
 * linked Arabic and English translations in Polylang, and sets up correct shortcodes.
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!function_exists('pll_set_post_language') || !function_exists('pll_save_post_translations')) {
    echo "❌ Polylang is not active or available.\n";
    exit;
}

echo "🌐 Setting up bilingual pages for WooCommerce...\n";
echo str_repeat('=', 60) . "\n";

$core_pages = [
    'cart' => [
        'ar_id' => 7,
        'ar_title' => 'السلة',
        'en_title' => 'Cart',
        'content' => '<!-- wp:shortcode -->[woocommerce_cart]<!-- /wp:shortcode -->'
    ],
    'checkout' => [
        'ar_id' => 8,
        'ar_title' => 'إتمام الطلب',
        'en_title' => 'Checkout',
        'content' => '<!-- wp:shortcode -->[woocommerce_checkout]<!-- /wp:shortcode -->'
    ],
    'myaccount' => [
        'ar_id' => 9,
        'ar_title' => 'حسابي',
        'en_title' => 'My Account',
        'content' => '<!-- wp:shortcode -->[woocommerce_my_account]<!-- /wp:shortcode -->'
    ],
    'shop' => [
        'ar_id' => 6,
        'ar_title' => 'المتجر',
        'en_title' => 'Shop',
        'content' => ''
    ]
];

foreach ($core_pages as $key => $info) {
    $ar_id = $info['ar_id'];
    $ar_title = $info['ar_title'];
    $en_title = $info['en_title'];
    $content = $info['content'];

    // Verify Arabic page exists
    $ar_post = get_post($ar_id);
    if (!$ar_post) {
        echo "⚠️ Arabic page for {$key} (ID: {$ar_id}) not found! Skipping.\n";
        continue;
    }

    echo "📦 Core Page: {$key}\n";

    // 1. Rename Arabic page to Arabic title if it's currently English
    if ($ar_post->post_title !== $ar_title) {
        wp_update_post([
            'ID' => $ar_id,
            'post_title' => $ar_title
        ]);
        echo "   ✅ Renamed Arabic page ID {$ar_id} to: '{$ar_title}'\n";
    }

    // Ensure Arabic language is set
    pll_set_post_language($ar_id, 'ar');

    // 2. Check if English translation exists
    $translations = pll_get_post_translations($ar_id);
    $en_id = $translations['en'] ?? null;

    if (!$en_id) {
        // Create English translation page
        $en_post_id = wp_insert_post([
            'post_title' => $en_title,
            'post_content' => $content,
            'post_status' => 'publish',
            'post_type' => 'page'
        ]);

        if (is_wp_error($en_post_id)) {
            echo "   ❌ Failed to create English page for {$key}\n";
            continue;
        }

        // Set English language
        pll_set_post_language($en_post_id, 'en');

        // Link them in Polylang
        pll_save_post_translations([
            'ar' => $ar_id,
            'en' => $en_post_id
        ]);

        echo "   🎉 Created English Page ID {$en_post_id}: '{$en_title}' and linked as translation!\n";
    } else {
        echo "   ✅ English Page exists (ID: {$en_id}): '" . get_the_title($en_id) . "'\n";
    }
    echo "\n";
}

echo str_repeat('=', 60) . "\n";
echo "🎉 Bilingual WooCommerce Pages Setup Completed!\n";
