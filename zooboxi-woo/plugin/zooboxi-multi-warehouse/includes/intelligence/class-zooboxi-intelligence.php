<?php
/**
 * Zooboxi Intelligence — consumes the sapconnect intelligence API and surfaces it in
 * the store: caches ranking/health/clearance into product meta, a "تصفية" clearance
 * collection, a "Frequently Bought Together" block, a recommended catalog sort, and
 * the capture-only event beacon. The store NEVER talks to SAP — only to /api/woo/*.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Intelligence
{
    private string $api_base;
    private string $api_token;

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = get_option('zooboxi_api_token', '');

        // Nightly snapshot sync (rank/health/clearance → product meta).
        add_action('zooboxi_sync_intelligence', [$this, 'sync_snapshot']);
        if (!wp_next_scheduled('zooboxi_sync_intelligence')) {
            wp_schedule_event(time() + 300, 'hourly', 'zooboxi_sync_intelligence');
        }

        // Storefront surfaces.
        add_shortcode('zooboxi_clearance', [$this, 'clearance_shortcode']);
        add_action('woocommerce_after_single_product_summary', [$this, 'render_fbt_block'], 18);

        // Recommended (intelligence) catalog sort — toggleable from the settings page.
        if (get_option('zooboxi_recommended_sort', 'yes') === 'yes') {
            add_filter('woocommerce_get_catalog_ordering_args', [$this, 'recommended_ordering_args']);
            add_filter('woocommerce_catalog_orderby', [$this, 'recommended_orderby_option']);
            add_filter('woocommerce_default_catalog_orderby', [$this, 'default_orderby'], 5);
        }

        // Express-delivery priority — toggleable. Runs at 1000 (after the core in-stock sort).
        if (get_option('zooboxi_express_ranking', 'yes') === 'yes') {
            add_filter('posts_clauses', [$this, 'prioritize_express_availability'], 1000, 2);
        }
        // Keep _zb_avail_branches fresh with every stock sync (needed regardless of the ranking toggle).
        add_action('updated_post_meta', [$this, 'maybe_refresh_avail_branches'], 10, 4);
        add_action('added_post_meta', [$this, 'maybe_refresh_avail_branches'], 10, 4);

        // Capture-only event beacon (cold-start spine).
        add_action('wp_footer', [$this, 'beacon_script']);
        add_action('wp_ajax_zooboxi_track', [$this, 'ajax_track']);
        add_action('wp_ajax_nopriv_zooboxi_track', [$this, 'ajax_track']);
    }

    /* ── API helpers ─────────────────────────────── */

    private function api_get(string $path)
    {
        $res = wp_remote_get($this->api_base . $path, [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Accept' => 'application/json'],
            'timeout' => 30,
        ]);
        if (is_wp_error($res)) {
            return null;
        }
        return json_decode(wp_remote_retrieve_body($res), true);
    }

    private function api_post(string $path, array $body): void
    {
        wp_remote_post($this->api_base . $path, [
            'headers'  => ['Authorization' => 'Bearer ' . $this->api_token, 'Content-Type' => 'application/json'],
            'body'     => wp_json_encode($body),
            'timeout'  => 8,
            'blocking' => false,
        ]);
    }

    private function find_product_id(string $itemCode): ?int
    {
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s LIMIT 1",
            $itemCode
        ));
        return $id ? (int) $id : null;
    }

    /* ── Snapshot sync (rank/health/clearance → meta) ─ */

    public function sync_snapshot(): array
    {
        $page = 1;
        $perPage = 500;
        $updated = 0;

        do {
            $resp = $this->api_get("/snapshot?page={$page}&per_page={$perPage}");
            $rows = $resp['data'] ?? [];
            foreach ($rows as $r) {
                $pid = $this->find_product_id($r['item_code'] ?? '');
                if (!$pid) {
                    continue;
                }
                update_post_meta($pid, '_zb_rank_score', (float) ($r['composite_rank_score'] ?? 0));
                update_post_meta($pid, '_zb_health', sanitize_text_field($r['health_status'] ?? ''));
                update_post_meta($pid, '_zb_is_hero', !empty($r['is_hero']) ? 1 : 0);
                update_post_meta($pid, '_zb_clearance', !empty($r['is_clearance']) ? 1 : 0);
                update_post_meta($pid, '_zb_demand', sanitize_text_field($r['demand_class'] ?? ''));
                update_post_meta($pid, '_zb_abc', sanitize_text_field($r['abc_class'] ?? ''));
                update_post_meta($pid, '_zb_instock_rate', (float) ($r['in_stock_rate'] ?? 1));
                // Backfill the in-stock-branches index (for express-delivery ranking + badges).
                $this->write_avail_branches($pid, get_post_meta($pid, '_zooboxi_warehouse_stock', true));
                $updated++;
            }
            $page++;
        } while (count($rows) >= $perPage);

        update_option('zooboxi_intelligence_synced_at', current_time('mysql'));
        return ['updated' => $updated];
    }

    /* ── "تصفية" clearance collection ─────────────── */

    public function clearance_shortcode($atts): string
    {
        if (get_option('zooboxi_clearance_collection', 'yes') !== 'yes') {
            return '';
        }
        $atts = shortcode_atts(['limit' => 24, 'columns' => 4], $atts);

        $q = new WP_Query([
            'post_type'      => 'product',
            'posts_per_page' => (int) $atts['limit'],
            'meta_key'       => '_zb_rank_score',
            'orderby'        => 'meta_value_num',
            'order'          => 'DESC',
            'meta_query'     => [
                ['key' => '_zb_clearance', 'value' => '1'],
                ['key' => '_stock_status', 'value' => 'instock'],
            ],
            'tax_query'      => [['taxonomy' => 'product_visibility', 'field' => 'name', 'terms' => 'exclude-from-catalog', 'operator' => 'NOT IN']],
        ]);

        if (!$q->have_posts()) {
            return '<p class="zb-clearance-empty">' . esc_html__('لا توجد عروض تصفية حالياً', 'zooboxi') . '</p>';
        }

        ob_start();
        echo '<div class="zb-clearance woocommerce columns-' . (int) $atts['columns'] . '"><ul class="products columns-' . (int) $atts['columns'] . '">';
        while ($q->have_posts()) {
            $q->the_post();
            wc_get_template_part('content', 'product');
        }
        echo '</ul></div>';
        wp_reset_postdata();
        return ob_get_clean();
    }

    /* ── Recommended catalog sort (uses _zb_rank_score) ─ */

    public function recommended_orderby_option(array $options): array
    {
        return ['zb_recommended' => __('موصى به', 'zooboxi')] + $options;
    }

    public function default_orderby(string $default): string
    {
        // Make "recommended" the default sort on shop/category pages.
        return $default === 'menu_order' ? 'zb_recommended' : $default;
    }

    public function recommended_ordering_args(array $args): array
    {
        $orderby = isset($_GET['orderby']) ? wc_clean(wp_unslash($_GET['orderby'])) : get_option('woocommerce_default_catalog_orderby');
        if ($orderby !== 'zb_recommended') {
            return $args;
        }
        $args['meta_key'] = '_zb_rank_score';
        $args['orderby']  = 'meta_value_num';
        $args['order']    = 'DESC';
        return $args;
    }

    /* ── Express-delivery (2-hour) priority ────────── */

    /**
     * Prepend a top sort tier: products in stock at the customer's EXPRESS branch
     * (2-hour delivery) come first. Runs at priority 1000, after the core in-stock
     * sort (999), so it only adds a tier above the existing order — non-destructive.
     */
    public function prioritize_express_availability(array $clauses, \WP_Query $query): array
    {
        global $wpdb;

        if (is_admin() || !$query->is_main_query()) {
            return $clauses;
        }
        $pt = $query->get('post_type');
        $isProduct = ($pt === 'product' || (is_array($pt) && in_array('product', $pt, true)));
        if (!$isProduct && !$query->is_tax('product_cat') && !$query->is_tax('product_tag')
            && !$query->is_tax('product_brand') && !$query->is_search()) {
            return $clauses;
        }

        $express = $this->get_express_warehouse_codes();
        if (empty($express)) {
            return $clauses; // No express zone for this customer → leave order untouched.
        }

        $clauses['join'] .= " LEFT JOIN {$wpdb->postmeta} AS zb_avail
            ON ({$wpdb->posts}.ID = zb_avail.post_id AND zb_avail.meta_key = '_zb_avail_branches')";

        $parts = [];
        foreach ($express as $code) {
            $parts[] = "FIND_IN_SET('" . esc_sql($code) . "', zb_avail.meta_value) > 0";
        }
        $expressSql = '(' . implode(' OR ', $parts) . ')';

        $existing = $clauses['orderby'] ?: "{$wpdb->posts}.menu_order ASC, {$wpdb->posts}.post_date DESC";
        $clauses['orderby'] = "CASE WHEN {$expressSql} THEN 0 ELSE 1 END ASC, " . $existing;

        return $clauses;
    }

    /** The customer's express (2-hour) warehouse code(s), from their saved location. */
    private function get_express_warehouse_codes(): array
    {
        static $cache = null;
        if ($cache !== null) {
            return $cache;
        }

        $lat = $lng = null;
        if (function_exists('WC') && WC()->session) {
            $lat = WC()->session->get('zooboxi_customer_lat');
            $lng = WC()->session->get('zooboxi_customer_lng');
        }
        if (($lat === null || $lng === null) && isset($_COOKIE['zooboxi_lat'], $_COOKIE['zooboxi_lng'])) {
            $lat = (float) $_COOKIE['zooboxi_lat'];
            $lng = (float) $_COOKIE['zooboxi_lng'];
        }
        if ($lat === null || $lng === null || (!$lat && !$lng)) {
            return $cache = [];
        }

        $codes = [];
        if (class_exists('Zooboxi_Warehouse_Manager')) {
            foreach (Zooboxi_Warehouse_Manager::find_express_warehouses((float) $lat, (float) $lng) as $wh) {
                // find_express_warehouses() returns ['warehouse' => row, 'distance' => km].
                $code = $wh['warehouse']['warehouse_code'] ?? $wh['warehouse_code'] ?? null;
                if (!empty($code)) {
                    $codes[] = $code;
                }
            }
        }
        return $cache = array_values(array_unique($codes));
    }

    /** Recompute _zb_avail_branches whenever a product's per-warehouse stock changes. */
    public function maybe_refresh_avail_branches($meta_id, $post_id, $meta_key, $meta_value): void
    {
        if ($meta_key === '_zooboxi_warehouse_stock') {
            $this->write_avail_branches((int) $post_id, $meta_value);
        }
    }

    /** CSV of warehouse codes where the product has real stock (>0) — fast express lookup. */
    private function write_avail_branches(int $post_id, $warehouseStock): void
    {
        $arr = is_array($warehouseStock) ? $warehouseStock : json_decode((string) $warehouseStock, true);
        $codes = [];
        if (is_array($arr)) {
            foreach ($arr as $w) {
                if (!empty($w['warehouse_code']) && (float) ($w['in_stock'] ?? 0) > 0) {
                    $codes[] = $w['warehouse_code'];
                }
            }
        }
        update_post_meta($post_id, '_zb_avail_branches', implode(',', array_values(array_unique($codes))));
    }

    /* ── Frequently Bought Together block ──────────── */

    public function render_fbt_block(): void
    {
        if (get_option('zooboxi_fbt_block', 'yes') !== 'yes') {
            return;
        }
        global $product;
        if (!$product) {
            return;
        }
        $itemCode = get_post_meta($product->get_id(), '_zooboxi_item_code', true);
        if (!$itemCode) {
            return;
        }
        $recs = $this->api_get('/recommendations/' . rawurlencode($itemCode));
        $fbt = $recs['frequently_bought_together'] ?? [];
        if (empty($fbt)) {
            return;
        }

        $ids = [];
        foreach ($fbt as $r) {
            $pid = !empty($r['woo_product_id']) ? (int) $r['woo_product_id'] : $this->find_product_id($r['item_code'] ?? '');
            if ($pid && get_post_status($pid) === 'publish') {
                $ids[] = $pid;
            }
        }
        $ids = array_slice(array_unique($ids), 0, 4);
        if (empty($ids)) {
            return;
        }

        echo '<section class="zb-fbt up-sells products"><h2>' . esc_html__('يُشترى عادةً معاً', 'zooboxi') . '</h2>';
        $q = new WP_Query(['post_type' => 'product', 'post__in' => $ids, 'orderby' => 'post__in', 'posts_per_page' => 4]);
        echo '<ul class="products columns-4">';
        while ($q->have_posts()) {
            $q->the_post();
            wc_get_template_part('content', 'product');
        }
        echo '</ul></section>';
        wp_reset_postdata();
    }

    /* ── Event beacon (capture-only) ───────────────── */

    public function beacon_script(): void
    {
        if (is_admin()) {
            return;
        }
        $ajax = admin_url('admin-ajax.php');
        $itemCode = '';
        if (is_product()) {
            global $product;
            if ($product) {
                $itemCode = (string) get_post_meta($product->get_id(), '_zooboxi_item_code', true);
            }
        }
        ?>
        <script>
        (function () {
            var ZB_AJAX = <?php echo wp_json_encode($ajax); ?>;
            function zbAnon() {
                try {
                    var k = 'zb_anon';
                    var v = localStorage.getItem(k);
                    if (!v) { v = (Date.now().toString(36) + Math.random().toString(36).slice(2, 10)); localStorage.setItem(k, v); }
                    return v;
                } catch (e) { return ''; }
            }
            function zbTrack(type, itemCode, extra) {
                try {
                    var body = new FormData();
                    body.append('action', 'zooboxi_track');
                    body.append('event_type', type);
                    body.append('anon_id', zbAnon());
                    if (itemCode) body.append('item_code', itemCode);
                    if (extra) body.append('payload', JSON.stringify(extra));
                    if (navigator.sendBeacon) { navigator.sendBeacon(ZB_AJAX, body); }
                    else { fetch(ZB_AJAX, { method: 'POST', body: body, keepalive: true }); }
                } catch (e) {}
            }
            window.zbTrack = zbTrack;
            var pageItem = <?php echo wp_json_encode($itemCode); ?>;
            if (pageItem) { zbTrack('view', pageItem); }
            document.body.addEventListener('click', function (e) {
                var btn = e.target.closest('.add_to_cart_button, .single_add_to_cart_button');
                if (btn) {
                    var ic = btn.getAttribute('data-zb-item') || pageItem || '';
                    zbTrack('add_to_cart', ic, { product_id: btn.getAttribute('data-product_id') || null });
                }
            }, true);
        })();
        </script>
        <?php
    }

    public function ajax_track(): void
    {
        $type = isset($_POST['event_type']) ? sanitize_text_field(wp_unslash($_POST['event_type'])) : '';
        $allowed = ['view', 'search', 'add_to_cart', 'begin_checkout', 'purchase', 'impression', 'click'];
        if (!in_array($type, $allowed, true)) {
            wp_die('', '', ['response' => 204]);
        }
        $payload = null;
        if (!empty($_POST['payload'])) {
            $decoded = json_decode(wp_unslash($_POST['payload']), true);
            $payload = is_array($decoded) ? $decoded : null;
        }
        // Server-side forward (keeps the API token out of the browser).
        $this->api_post('/events', array_filter([
            'event_type'   => $type,
            'anon_id'      => isset($_POST['anon_id']) ? sanitize_text_field(wp_unslash($_POST['anon_id'])) : null,
            'item_code'    => isset($_POST['item_code']) ? sanitize_text_field(wp_unslash($_POST['item_code'])) : null,
            'query'        => isset($_POST['query']) ? sanitize_text_field(wp_unslash($_POST['query'])) : null,
            'zone'         => isset($_POST['zone']) ? sanitize_text_field(wp_unslash($_POST['zone'])) : null,
            'ab_variant'   => isset($_POST['ab_variant']) ? sanitize_text_field(wp_unslash($_POST['ab_variant'])) : null,
            'payload'      => $payload,
        ], fn ($v) => $v !== null));

        wp_die('', '', ['response' => 202]);
    }
}
