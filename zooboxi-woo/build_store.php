<?php
/**
 * Zooboxi Professional Store Builder v2.0
 * ========================================
 * Reads Zid CSV files and builds WooCommerce store.
 * Usage: wp eval-file build_store.php
 */

set_time_limit(0);
ini_set('memory_limit', '1024M');

$zbx_stats = ['cats' => 0, 'attrs' => 0, 'variable' => 0, 'simple' => 0, 'variations' => 0, 'images' => 0, 'skipped' => 0, 'errors' => []];

echo "🏗️  Zooboxi Store Builder v2.0\n";
echo str_repeat('═', 60) . "\n\n";

// ═══════════ LOAD CSV DATA ═══════════
echo "📂 Loading CSV files...\n";
$all_data = [];
$headers = null;

foreach (['zid_batch0.csv', 'zid_batch1.csv', 'zid_batch2.csv'] as $file) {
    $path = dirname(__FILE__) . '/' . $file;
    if (!file_exists($path)) { echo "  ⚠️ Missing: $file\n"; continue; }
    
    $handle = fopen($path, 'r');
    $file_headers = fgetcsv($handle);
    if ($headers === null) $headers = $file_headers;
    
    $count = 0;
    while (($row = fgetcsv($handle)) !== false) {
        $data = [];
        foreach ($headers as $i => $h) {
            $data[$h] = isset($row[$i]) ? $row[$i] : '';
        }
        $all_data[] = $data;
        $count++;
    }
    fclose($handle);
    echo "  ✅ $file: $count rows\n";
}

$total_rows = count($all_data);
echo "\n📊 Total rows: $total_rows\n\n";

// ═══════════ BUILD CATEGORIES ═══════════
echo "🏷️  Building categories...\n";

$cat_cache = [];

function zbx_get_cat($name, $parent = 0) {
    global $cat_cache, $zbx_stats;
    $key = $parent . ':' . $name;
    if (isset($cat_cache[$key])) return $cat_cache[$key];
    
    // Search existing
    $terms = get_terms(['taxonomy' => 'product_cat', 'name' => $name, 'parent' => $parent, 'hide_empty' => false]);
    if (!empty($terms) && !is_wp_error($terms)) {
        $cat_cache[$key] = $terms[0]->term_id;
        return $terms[0]->term_id;
    }
    
    $r = wp_insert_term($name, 'product_cat', ['parent' => $parent]);
    if (is_wp_error($r)) {
        $existing = get_term_by('name', $name, 'product_cat');
        if ($existing) { $cat_cache[$key] = $existing->term_id; return $existing->term_id; }
        return 0;
    }
    $cat_cache[$key] = $r['term_id'];
    $zbx_stats['cats']++;
    return $r['term_id'];
}

// Extract category paths
$cat_paths = [];
foreach ($all_data as $row) {
    $cats = trim($row['categories_ar'] ?? '');
    if (empty($cats)) continue;
    foreach (explode(',', $cats) as $p) {
        $p = trim($p);
        if (!empty($p) && strpos($p, 'العلامات التجارية') !== 0) {
            $cat_paths[$p] = true;
        }
    }
}

foreach (array_keys($cat_paths) as $path) {
    $parts = array_map('trim', explode('>', $path));
    $pid = 0;
    foreach ($parts as $part) {
        if (!empty($part)) $pid = zbx_get_cat($part, $pid);
    }
}

echo "  ✅ {$zbx_stats['cats']} categories created\n\n";

// ═══════════ REGISTER ATTRIBUTES ═══════════
echo "🔧 Registering attributes...\n";
global $wpdb;

$wc_attrs = [
    'brand' => 'العلامة التجارية',
    'age' => 'المرحلة العمرية',
    'flavor' => 'النكهة',
    'food-type' => 'شكل الطعام',
    'health' => 'ميزة صحية',
    'litter-type' => 'نوع الرمل',
    'color' => 'اللون',
    'material' => 'المادة',
    'product-type' => 'نوع المنتج',
    'weight-opt' => 'الوزن',
    'size-opt' => 'الحجم',
    'color-opt' => 'اللون (اختيار)',
    'flavor-opt' => 'النكهة (اختيار)',
    'smell-opt' => 'الرائحة',
    'choose-opt' => 'اختر',
];

foreach ($wc_attrs as $slug => $label) {
    $exists = $wpdb->get_var($wpdb->prepare(
        "SELECT attribute_id FROM {$wpdb->prefix}woocommerce_attribute_taxonomies WHERE attribute_name = %s", $slug
    ));
    if (!$exists) {
        $wpdb->insert($wpdb->prefix . 'woocommerce_attribute_taxonomies', [
            'attribute_name' => $slug,
            'attribute_label' => $label,
            'attribute_type' => 'select',
            'attribute_orderby' => 'menu_order',
            'attribute_public' => 1,
        ]);
        $zbx_stats['attrs']++;
        // Register the taxonomy
        register_taxonomy('pa_' . $slug, 'product', []);
    }
}
delete_transient('wc_attribute_taxonomies');
wp_cache_flush();

echo "  ✅ {$zbx_stats['attrs']} attributes registered\n\n";

// ═══════════ GROUP PRODUCTS ═══════════
echo "📦 Grouping products...\n";

$products = [];
$current = null;

foreach ($all_data as $row) {
    $hv = strtolower(trim($row['has_variants'] ?? ''));
    $sku = trim($row['sku'] ?? '');
    $opt_val = trim($row['option1_value_ar'] ?? '');
    
    if ($hv === 'yes') {
        if ($current !== null) $products[] = $current;
        $current = ['parent' => $row, 'variants' => []];
    } elseif ($current !== null && !empty($sku) && !empty($opt_val)) {
        $current['variants'][] = $row;
    } else {
        if ($current !== null) { $products[] = $current; $current = null; }
        $name = trim($row['name_ar'] ?? '');
        if (!empty($name) || !empty($sku)) {
            $products[] = ['parent' => $row, 'variants' => []];
        }
    }
}
if ($current !== null) $products[] = $current;

$vp = 0; $sp = 0;
foreach ($products as $p) { if (count($p['variants']) > 0) $vp++; else $sp++; }
echo "  Variable: $vp | Simple: $sp | Total: " . count($products) . "\n\n";

// ═══════════ IMPORT PRODUCTS ═══════════
echo "🚀 Importing products...\n\n";

$count = 0;
$total = count($products);

$filter_slug_map = [
    'العلامة التجارية' => 'brand', 'المرحلة العمرية' => 'age',
    'النكهة' => 'flavor', 'البروتين الأساسي / النكهة' => 'flavor',
    'المكون الأساسي / النكهة' => 'flavor', 'النكهة / المكون الأساسي' => 'flavor',
    'شكل الطعام' => 'food-type', 'قوام / نوع الطعام' => 'food-type',
    'التركيبة / القوام' => 'food-type', 'ميزة صحية' => 'health',
    'مشاكل صحية / فوائد' => 'health', 'الفائدة الصحية / الوظيفة' => 'health',
    'نوع الرمل' => 'litter-type', 'اللون' => 'color', 'المادة' => 'material',
    'الرائحة' => 'material', 'نوع المستلزمات' => 'product-type',
    'نوع اللعبة' => 'product-type', 'نوع الإكسسوار' => 'product-type',
    'نوع منتج التنظيف' => 'product-type',
    'نوع المنتج (إكسسوارات ومستلزمات)' => 'product-type',
    'نوع المنتج (طعام ومكافآت)' => 'product-type',
];

$var_slug_map = [
    'Weight' => 'weight-opt', 'Size' => 'size-opt', 'Color' => 'color-opt',
    'Flavor' => 'flavor-opt', 'Smell' => 'smell-opt', 'Choose' => 'choose-opt',
];

foreach ($products as $prod) {
    $count++;
    $parent = $prod['parent'];
    $variants = $prod['variants'];
    $name = trim($parent['name_ar'] ?? '') ?: trim($parent['name_en'] ?? '');
    
    if (empty($name)) { $zbx_stats['skipped']++; continue; }
    
    $sku = trim($parent['sku'] ?? '');
    $desc = trim($parent['description_ar'] ?? '');
    $short_desc = trim($parent['short_description_ar'] ?? '');
    $price = floatval($parent['price'] ?? 0);
    $sale_price = floatval($parent['sale_price'] ?? 0);
    $img_url = trim($parent['images'] ?? '');
    $cats_str = trim($parent['categories_ar'] ?? '');
    
    try {
        if (count($variants) > 0) {
            // ─── VARIABLE PRODUCT ───
            $wc = new WC_Product_Variable();
            $wc->set_name($name);
            if ($desc) $wc->set_description($desc);
            if ($short_desc) $wc->set_short_description($short_desc);
            $wc->set_status('publish');
            
            // Categories
            $cat_ids = zbx_resolve_cats($cats_str);
            if (!empty($cat_ids)) $wc->set_category_ids($cat_ids);
            
            // Variation attribute
            $opt_en = trim($parent['option1_name_en'] ?? 'Weight');
            $attr_slug = $var_slug_map[$opt_en] ?? 'weight-opt';
            $taxonomy = 'pa_' . $attr_slug;
            
            // Ensure taxonomy registered
            if (!taxonomy_exists($taxonomy)) {
                register_taxonomy($taxonomy, 'product', []);
            }
            
            // Collect variant values
            $vals = [];
            foreach ($variants as $v) {
                $val = trim($v['option1_value_ar'] ?? '');
                if (!empty($val)) $vals[] = $val;
            }
            $vals = array_unique($vals);
            
            // Register terms
            foreach ($vals as $val) {
                if (!term_exists($val, $taxonomy)) wp_insert_term($val, $taxonomy);
            }
            
            // Build attributes
            $attr = new WC_Product_Attribute();
            $tax_id = wc_attribute_taxonomy_id_by_name($taxonomy);
            if ($tax_id > 0) {
                $attr->set_id($tax_id);
            }
            $attr->set_name($taxonomy);
            $attr->set_options($vals);
            $attr->set_visible(true);
            $attr->set_variation(true);
            
            $all_attrs = [$attr];
            $filter_attrs = zbx_get_filters($parent, $filter_slug_map);
            $all_attrs = array_merge($all_attrs, $filter_attrs);
            $wc->set_attributes($all_attrs);
            
            // Image from first variant
            $first_img = '';
            foreach ($variants as $v) {
                $i = trim($v['images'] ?? '');
                if (!empty($i)) { $first_img = $i; break; }
            }
            if (empty($first_img)) $first_img = $img_url;
            
            $sap = zbx_sap_code($first_img);
            $pid = $wc->save();
            
            if ($pid > 0) {
                wp_set_object_terms($pid, $vals, $taxonomy, false);
            }
            
            if ($sap) update_post_meta($pid, '_zooboxi_item_code', $sap);
            if (!empty($first_img)) {
                update_post_meta($pid, '_zooboxi_image_url', $first_img);
                $zbx_stats['images']++;
            }
            
            // Create variations
            foreach ($variants as $v) {
                $vsku = trim($v['sku'] ?? '');
                $vprice = floatval($v['price'] ?? 0);
                $vsale = floatval($v['sale_price'] ?? 0);
                $vval = trim($v['option1_value_ar'] ?? '');
                $vimg = trim($v['images'] ?? '');
                $vweight = floatval($v['weight'] ?? 0);
                $vsap = zbx_sap_code($vimg);
                
                if (empty($vval)) continue;
                
                $term = get_term_by('name', $vval, $taxonomy);
                $vval_slug = ($term && !is_wp_error($term)) ? $term->slug : sanitize_title($vval);
                
                $var = new WC_Product_Variation();
                $var->set_parent_id($pid);
                if (!empty($vsku)) $var->set_sku($vsku);
                if ($vprice > 0) {
                    $var->set_regular_price($vprice);
                    if ($vsale > 0 && $vsale < $vprice) $var->set_sale_price($vsale);
                }
                if ($vweight > 0) $var->set_weight($vweight / 1000);
                $var->set_status('publish');
                $var->set_attributes([$taxonomy => $vval_slug]);
                
                $vid = $var->save();
                if ($vsap) update_post_meta($vid, '_zooboxi_item_code', $vsap);
                if (!empty($vimg)) update_post_meta($vid, '_zooboxi_image_url', $vimg);
                $zbx_stats['variations']++;
            }
            
            WC_Product_Variable::sync($pid);
            $zbx_stats['variable']++;
            
        } else {
            // ─── SIMPLE PRODUCT ───
            $wc = new WC_Product_Simple();
            $wc->set_name($name);
            if (!empty($sku)) $wc->set_sku($sku);
            if ($desc) $wc->set_description($desc);
            if ($short_desc) $wc->set_short_description($short_desc);
            if ($price > 0) {
                $wc->set_regular_price($price);
                if ($sale_price > 0 && $sale_price < $price) $wc->set_sale_price($sale_price);
            }
            $wc->set_status('publish');
            
            $cat_ids = zbx_resolve_cats($cats_str);
            if (!empty($cat_ids)) $wc->set_category_ids($cat_ids);
            
            $filter_attrs = zbx_get_filters($parent, $filter_slug_map);
            if (!empty($filter_attrs)) $wc->set_attributes($filter_attrs);
            
            $weight = floatval($parent['weight'] ?? 0);
            if ($weight > 0) $wc->set_weight($weight / 1000);
            
            $sap = zbx_sap_code($img_url);
            $pid = $wc->save();
            
            if ($sap) update_post_meta($pid, '_zooboxi_item_code', $sap);
            if (!empty($img_url)) {
                update_post_meta($pid, '_zooboxi_image_url', $img_url);
                $zbx_stats['images']++;
            }
            
            $zbx_stats['simple']++;
        }
    } catch (Exception $e) {
        $zbx_stats['errors'][] = substr("$name: " . $e->getMessage(), 0, 100);
        $zbx_stats['skipped']++;
    }
    
    if ($count % 50 === 0) {
        $pct = round($count / $total * 100);
        echo "  ✅ $count/$total ($pct%) — V:{$zbx_stats['variable']} S:{$zbx_stats['simple']} Var:{$zbx_stats['variations']}\n";
        wp_cache_flush();
        gc_collect_cycles();
    }
}

echo "\n" . str_repeat('═', 60) . "\n";
echo "🎉 DONE!\n";
echo "  Categories: {$zbx_stats['cats']}\n";
echo "  Attributes: {$zbx_stats['attrs']}\n";
echo "  Variable Products: {$zbx_stats['variable']}\n";
echo "  Variations: {$zbx_stats['variations']}\n";
echo "  Simple Products: {$zbx_stats['simple']}\n";
echo "  Images: {$zbx_stats['images']}\n";
echo "  Skipped: {$zbx_stats['skipped']}\n";
echo "  Errors: " . count($zbx_stats['errors']) . "\n";
if (!empty($zbx_stats['errors'])) {
    foreach (array_slice($zbx_stats['errors'], 0, 5) as $e) echo "    ⚠️ $e\n";
}

// ═══════════ HELPERS ═══════════
function zbx_resolve_cats($cats_str) {
    $ids = [];
    foreach (explode(',', $cats_str) as $path) {
        $path = trim($path);
        if (empty($path) || strpos($path, 'العلامات التجارية') === 0) continue;
        $parts = array_map('trim', explode('>', $path));
        $pid = 0;
        foreach ($parts as $part) {
            if (!empty($part)) $pid = zbx_get_cat($part, $pid);
        }
        if ($pid > 0) $ids[] = $pid;
    }
    return array_unique($ids);
}

function zbx_sap_code($url) {
    if (preg_match('/(P\d{8,})\.png/', $url, $m)) return $m[1];
    return '';
}

function zbx_get_filters($row, $map) {
    $grouped = [];
    for ($i = 1; $i <= 14; $i++) {
        $attr_name = trim($row["filtration_attribute_{$i}_ar"] ?? '');
        $attr_value = trim($row["filtration_value_{$i}_ar"] ?? '');
        if (empty($attr_name) || empty($attr_value)) continue;
        
        $clean = $attr_name;
        if (preg_match('/^(?:القطط|الكلاب|الطيور|الحيوانات الصغيرة)\s*-\s*(.+)$/', $attr_name, $m)) {
            $clean = trim($m[1]);
        }
        
        $slug = $map[$clean] ?? null;
        if (!$slug) continue;
        
        if (!isset($grouped[$slug])) $grouped[$slug] = [];
        $grouped[$slug][] = $attr_value;
    }
    
    $attrs = [];
    foreach ($grouped as $slug => $values) {
        $tax = 'pa_' . $slug;
        if (!taxonomy_exists($tax)) register_taxonomy($tax, 'product', []);
        $values = array_unique($values);
        foreach ($values as $v) {
            if (!term_exists($v, $tax)) wp_insert_term($v, $tax);
        }
        $a = new WC_Product_Attribute();
        $tax_id = wc_attribute_taxonomy_id_by_name($tax);
        if ($tax_id > 0) {
            $a->set_id($tax_id);
        }
        $a->set_name($tax);
        $a->set_options($values);
        $a->set_visible(true);
        $a->set_variation(false);
        $attrs[] = $a;
    }
    return $attrs;
}
