<?php
/**
 * One-shot backfill: stamp `_zooboxi_units` (pieces per cart unit) on every
 * variation, sourced from SAP's Sales Items Per Unit via the backend feed.
 *
 * Run on the server:  wp eval-file backfill_units.php
 *
 * Rules per variation:
 *   - has its OWN _zooboxi_item_code → its own SAP identity → units = 1
 *   - option label/slug mentions كرتون → units = parent's SAP factor
 *     (fallback: the first integer ≥ 2 in the decoded label, e.g. "كرتون (17 حبة)")
 *   - otherwise → units = 1 (حبة)
 * Sanity: when a sibling piece-variation exists, carton_price ≈ units × piece_price
 * (±15%) — mismatches are stamped anyway but listed for the owner to eyeball.
 *
 * Safe to re-run; only writes meta. Missing meta everywhere = behaviour
 * identical to before the feature existed.
 */

$base  = rtrim((string) get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
$token = (string) get_option('zooboxi_api_token', '');
if ($token === '') {
    echo "ABORT: no backend token configured\n";
    exit;
}

// 1) Pull the whole product feed once → item_code => sales_items_per_unit.
$factors = [];
$page    = 1;
do {
    $res = wp_remote_get($base . '/products?page=' . $page . '&per_page=500', [
        'headers' => ['Authorization' => 'Bearer ' . $token, 'Accept' => 'application/json'],
        'timeout' => 60,
    ]);
    if (is_wp_error($res)) {
        echo "ABORT: feed page {$page} failed: " . $res->get_error_message() . "\n";
        exit;
    }
    $body  = json_decode(wp_remote_retrieve_body($res), true);
    $items = $body['products'] ?? ($body['data'] ?? []);
    foreach ((array) $items as $p) {
        $code = (string) ($p['item_code'] ?? '');
        $f    = (float) ($p['sales_items_per_unit'] ?? 0);
        if ($code !== '' && $f > 0) {
            $factors[$code] = (int) round($f);
        }
    }
    $last = (int) ($body['last_page'] ?? ($body['meta']['last_page'] ?? $page));
    $page++;
} while ($page <= $last && $page < 100);

echo 'feed factors: ' . count($factors) . " item codes\n";

// 2) Walk every variable product.
$stamped_parents = 0;
$stamped_cartons = 0;
$stamped_ones    = 0;
$anomalies       = [];

$ids = get_posts([
    'post_type'      => 'product',
    'post_status'    => 'publish',
    'posts_per_page' => -1,
    'fields'         => 'ids',
    'tax_query'      => [[
        'taxonomy' => 'product_type',
        'field'    => 'slug',
        'terms'    => ['variable'],
    ]],
]);
echo 'variable products: ' . count($ids) . "\n";

foreach ($ids as $pid) {
    $parent_code = (string) get_post_meta($pid, '_zooboxi_item_code', true);
    $factor      = $factors[$parent_code] ?? 0;
    if ($factor > 1) {
        update_post_meta($pid, '_zooboxi_sales_items_per_unit', (string) $factor);
        $stamped_parents++;
    }

    $product = wc_get_product($pid);
    if (!$product) {
        continue;
    }

    // Find the sibling piece price for the sanity check.
    $children    = $product->get_children();
    $piece_price = null;
    $rows        = [];
    foreach ($children as $vid) {
        $v = wc_get_product($vid);
        if (!$v) {
            continue;
        }
        $label = '';
        foreach ($v->get_attributes() as $slug) {
            $label .= ' ' . rawurldecode((string) $slug);
        }
        $own_code  = (string) get_post_meta($vid, '_zooboxi_item_code', true);
        $is_carton = mb_strpos($label, 'كرتون') !== false || stripos($label, 'carton') !== false;
        $rows[]    = ['vid' => $vid, 'label' => trim($label), 'own' => $own_code !== '' && $own_code !== $parent_code, 'carton' => $is_carton, 'price' => (float) $v->get_price()];
        if (!$is_carton && $piece_price === null) {
            $piece_price = (float) $v->get_price();
        }
    }

    foreach ($rows as $r) {
        $units = 1;
        if (!$r['own'] && $r['carton']) {
            $units = $factor > 1 ? $factor : 0;
            if ($units === 0 && preg_match('/(\d{1,3})/u', $r['label'], $m) && (int) $m[1] >= 2) {
                $units = (int) $m[1];
            }
            if ($units < 2) {
                $anomalies[] = "vid {$r['vid']} «{$r['label']}»: carton w/o factor (parent {$parent_code})";
                $units = 1;
            } elseif ($piece_price && $r['price'] > 0) {
                $expected = $piece_price * $units;
                if (abs($r['price'] - $expected) / max($expected, 0.01) > 0.15) {
                    $anomalies[] = "vid {$r['vid']} «{$r['label']}»: price {$r['price']} vs {$units}×{$piece_price}={$expected}";
                }
            }
        }
        update_post_meta($r['vid'], '_zooboxi_units', (string) $units);
        $units > 1 ? $stamped_cartons++ : $stamped_ones++;
    }
}

echo "parents stamped: {$stamped_parents}\n";
echo "carton variations (units>1): {$stamped_cartons}\n";
echo "piece variations (units=1): {$stamped_ones}\n";
echo 'anomalies: ' . count($anomalies) . "\n";
foreach (array_slice($anomalies, 0, 25) as $a) {
    echo "  ! {$a}\n";
}
