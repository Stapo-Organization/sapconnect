<?php
/**
 * Zooboxi Category Translation Script
 * Creates English translations for all product categories using Polylang API
 * Run via: wp eval-file translate_categories.php
 */

// Load the JSON data
$json_file = dirname(__FILE__) . '/category_translations.json';
if (!file_exists($json_file)) {
    WP_CLI::error("category_translations.json not found!");
    exit(1);
}

$categories = json_decode(file_get_contents($json_file), true);
if (!$categories) {
    WP_CLI::error("Failed to parse category_translations.json!");
    exit(1);
}

// Check Polylang is active
if (!function_exists('pll_save_term_translations')) {
    WP_CLI::error("Polylang is not active!");
    exit(1);
}

WP_CLI::log("Starting category translation...");
WP_CLI::log("Total categories to process: " . count($categories));

// Cache: ar_path -> term_id (Arabic), en_path -> term_id (English)
$ar_term_cache = [];
$en_term_cache = [];
$created = 0;
$skipped = 0;
$errors = 0;

foreach ($categories as $cat) {
    $ar_name = $cat['ar_name'];
    $en_name = $cat['en_name'];
    $ar_path = $cat['ar_path'];
    $en_path = $cat['en_path'];
    $ar_parent_path = $cat['ar_parent'];
    $en_parent_path = $cat['en_parent'];
    $depth = $cat['depth'];
    
    // 1. Find the Arabic term
    $ar_parent_id = 0;
    if ($ar_parent_path && isset($ar_term_cache[$ar_parent_path])) {
        $ar_parent_id = $ar_term_cache[$ar_parent_path];
    }
    
    // Try to find Arabic term by name + parent
    $ar_term = get_term_by('name', $ar_name, 'product_cat');
    if (!$ar_term) {
        // Try by slug
        $ar_slug = sanitize_title($ar_name);
        $ar_term = get_term_by('slug', $ar_slug, 'product_cat');
    }
    
    // If multiple matches, find the one with correct parent
    if ($ar_term && $ar_parent_id > 0 && $ar_term->parent != $ar_parent_id) {
        // Search more carefully
        $args = [
            'taxonomy' => 'product_cat',
            'name' => $ar_name,
            'parent' => $ar_parent_id,
            'hide_empty' => false,
        ];
        $terms = get_terms($args);
        if (!empty($terms)) {
            $ar_term = $terms[0];
        }
    }
    
    if (!$ar_term) {
        WP_CLI::warning("Arabic term not found: {$ar_name} (path: {$ar_path})");
        $errors++;
        continue;
    }
    
    $ar_term_cache[$ar_path] = $ar_term->term_id;
    
    // Set Arabic term language
    pll_set_term_language($ar_term->term_id, 'ar');
    
    // 2. Check if English translation already exists
    $existing_en = pll_get_term($ar_term->term_id, 'en');
    if ($existing_en && $existing_en != $ar_term->term_id) {
        $en_term_cache[$en_path] = $existing_en;
        $skipped++;
        continue;
    }
    
    // 3. Create English term
    $en_slug = sanitize_title($en_name);
    
    // Determine English parent
    $en_parent_id = 0;
    if ($en_parent_path && isset($en_term_cache[$en_parent_path])) {
        $en_parent_id = $en_term_cache[$en_parent_path];
    }
    
    // Check if slug already exists and make unique
    $existing_slug = get_term_by('slug', $en_slug, 'product_cat');
    if ($existing_slug) {
        // If it's already the English translation, use it
        $lang = pll_get_term_language($existing_slug->term_id);
        if ($lang === 'en') {
            $en_term_cache[$en_path] = $existing_slug->term_id;
            pll_save_term_translations([
                'ar' => $ar_term->term_id,
                'en' => $existing_slug->term_id,
            ]);
            $skipped++;
            continue;
        }
        $en_slug .= '-en';
    }
    
    $result = wp_insert_term($en_name, 'product_cat', [
        'slug' => $en_slug,
        'parent' => $en_parent_id,
    ]);
    
    if (is_wp_error($result)) {
        // Maybe term exists with different slug
        if ($result->get_error_code() === 'term_exists') {
            $en_term_id = $result->get_error_data();
            if (is_array($en_term_id)) $en_term_id = $en_term_id['term_id'] ?? 0;
            if ($en_term_id) {
                $en_term_cache[$en_path] = $en_term_id;
                pll_set_term_language($en_term_id, 'en');
                pll_save_term_translations([
                    'ar' => $ar_term->term_id,
                    'en' => $en_term_id,
                ]);
                $skipped++;
                continue;
            }
        }
        WP_CLI::warning("Failed to create EN term '{$en_name}': " . $result->get_error_message());
        $errors++;
        continue;
    }
    
    $en_term_id = $result['term_id'];
    $en_term_cache[$en_path] = $en_term_id;
    
    // 4. Set language and link translations
    pll_set_term_language($en_term_id, 'en');
    pll_save_term_translations([
        'ar' => $ar_term->term_id,
        'en' => $en_term_id,
    ]);
    
    // Copy term meta (thumbnail, etc.)
    $thumbnail_id = get_term_meta($ar_term->term_id, 'thumbnail_id', true);
    if ($thumbnail_id) {
        update_term_meta($en_term_id, 'thumbnail_id', $thumbnail_id);
    }
    
    $created++;
    
    if ($created % 50 === 0) {
        WP_CLI::log("Progress: {$created} created, {$skipped} skipped, {$errors} errors...");
    }
}

WP_CLI::success("Category translation complete!");
WP_CLI::log("  Created: {$created}");
WP_CLI::log("  Skipped: {$skipped}");
WP_CLI::log("  Errors:  {$errors}");
