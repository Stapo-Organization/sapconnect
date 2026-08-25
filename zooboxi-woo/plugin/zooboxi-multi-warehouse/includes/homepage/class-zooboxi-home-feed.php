<?php
/**
 * Zooboxi_Home_Feed — the per-customer hydration endpoint.
 *
 * GET /zooboxi/v1/home-feed returns ready-to-inject HTML fragments for the
 * personalized homepage slots, keyed by slot name. Inputs are read from the
 * request (location + recently-viewed) and the auth cookie (login state), never
 * baked into the cacheable page. Response is `private, no-store`.
 *
 * Personalization layers (all opted-in by the owner):
 *   • location / city  → delivery promise + "الأكثر رواجاً في {city}" / express rail
 *   • browsing         → "تصفّحت مؤخراً" + "موصى لك" (FBT/substitutes)
 *   • logged-in        → "مرحباً بعودتك {name}" + "اطلبها مجدداً" (order history)
 *   • guest            → gentle phone-login invite card
 *
 * Buy-again is sourced from WooCommerce's own order records (wc_get_orders) — no
 * SAP call, no price mutation — honoring the SAP read-only + wholesale-channel rules.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Home_Feed
{
    private string $api_base;
    private string $api_token;

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = (string) get_option('zooboxi_api_token', '');
    }

    /** Registered by Zooboxi_Rest_Controller::register_routes(). */
    public function handle(\WP_REST_Request $request): \WP_REST_Response
    {
        [$lat, $lng, $city] = $this->read_location($request);
        $recent = $this->read_recent($request);

        $logged = is_user_logged_in();
        $uid    = get_current_user_id();

        $out = [
            'welcome'  => $logged ? $this->welcome_html($uid) : null,
            'promise'  => $this->promise_html($lat, $lng, $city) ?: null,
            'buyagain' => $logged ? ($this->buyagain_html($uid) ?: null) : null,
            'login'    => $logged ? null : $this->login_card_html(),
            // "مختار لك" merges recently-viewed + recommendations into one deduped rail.
            'foryou'   => $this->foryou_html($recent) ?: null,
            'incity'   => $this->incity_html($lat, $lng, $city) ?: null,
        ];

        $response = new \WP_REST_Response($out, 200);
        $response->header('Cache-Control', 'private, no-store, max-age=0');
        return $response;
    }

    /* ── Inputs ──────────────────────────────────────── */

    private function read_location(\WP_REST_Request $r): array
    {
        $lat  = (float) $r->get_param('lat');
        $lng  = (float) $r->get_param('lng');
        $city = sanitize_text_field((string) $r->get_param('city'));

        if (!$lat && !empty($_COOKIE['zooboxi_lat'])) {
            $lat = (float) $_COOKIE['zooboxi_lat'];
        }
        if (!$lng && !empty($_COOKIE['zooboxi_lng'])) {
            $lng = (float) $_COOKIE['zooboxi_lng'];
        }
        if ($city === '' && !empty($_COOKIE['zooboxi_city'])) {
            $city = sanitize_text_field(wp_unslash($_COOKIE['zooboxi_city']));
        }
        return [$lat, $lng, $city];
    }

    private function read_recent(\WP_REST_Request $r): array
    {
        $raw = (string) $r->get_param('recent_ids');
        if ($raw !== '') {
            $ids = array_filter(array_map('intval', explode(',', $raw)));
            return array_slice(array_values(array_unique($ids)), 0, 12);
        }
        if (!empty($_COOKIE['zooboxi_recently_viewed'])) {
            $dec = json_decode(stripslashes($_COOKIE['zooboxi_recently_viewed']), true);
            if (is_array($dec)) {
                $ids = array_filter(array_map('intval', $dec));
                return array_slice(array_values(array_unique($ids)), 0, 12);
            }
        }
        return [];
    }

    /* ── Slots ───────────────────────────────────────── */

    private function welcome_html(int $uid): string
    {
        $name = (string) get_user_meta($uid, 'billing_first_name', true);
        if ($name === '') {
            $u = get_userdata($uid);
            $name = $u ? (string) $u->display_name : '';
        }
        $greet = $name !== ''
            ? sprintf(__('مرحباً بعودتك، %s 👋', 'zooboxi'), $name)
            : __('مرحباً بعودتك 👋', 'zooboxi');
        return '<div class="zb-welcome"><span class="zb-welcome__txt">' . esc_html($greet) . '</span></div>';
    }

    private function promise_html(float $lat, float $lng, string $city): string
    {
        // No location yet → a gentle invite to set it (drives engagement + unlocks rails).
        if (!$lat && !$lng && $city === '') {
            return '<div class="zb-promise zb-promise--invite">'
                . '<button type="button" class="zb-promise__chip" id="zb-promise-locate">'
                . esc_html__('📍 حدّد موقعك لمعرفة سرعة التوصيل', 'zooboxi')
                . '</button></div>';
        }

        $opt  = Zooboxi_Delivery_Engine::detect_options($lat, $lng, [], $city !== '' ? $city : null);
        $best = $opt['express'] ?? $opt['standard'] ?? $opt['shipping'] ?? null;
        if (!$best) {
            return '';
        }

        $type  = $best['delivery_type'] ?? '';
        $time  = (string) ($best['estimated_time'] ?? '');
        $where = $city !== '' ? $city : (string) ($best['warehouse_name'] ?? '');
        if ($where !== '' && function_exists('zooboxi_city_ar')) { $where = zooboxi_city_ar($where); }
        $icon  = $type === Zooboxi_Delivery_Engine::TYPE_EXPRESS ? '⚡'
               : ($type === Zooboxi_Delivery_Engine::TYPE_STANDARD ? '🚚' : '📦');

        $line = $where !== ''
            ? sprintf(__('توصيل %1$s إلى %2$s', 'zooboxi'), $time, $where)
            : sprintf(__('توصيل %s', 'zooboxi'), $time);

        return '<div class="zb-promise zb-promise--' . esc_attr($type) . '">'
            . '<span class="zb-promise__icon" aria-hidden="true">' . esc_html($icon) . '</span>'
            . '<span class="zb-promise__text">' . esc_html($line) . '</span>'
            . '<a class="zb-promise__edit" href="#" id="zb-promise-edit">' . esc_html__('تغيير', 'zooboxi') . '</a>'
            . '</div>';
    }

    private function recent_html(array $recent): string
    {
        if (empty($recent)) {
            return '';
        }
        return Zooboxi_Product_Rail::render([
            'ids'   => array_slice($recent, 0, 12),
            'title' => __('تصفّحت مؤخراً', 'zooboxi'),
            'icon'  => '🕒',
            'zone'  => 'home:recent',
        ]);
    }

    private function buyagain_html(int $uid): string
    {
        $tkey   = 'zbhome_buyagain_' . $uid;
        $cached = get_transient($tkey);
        if ($cached !== false) {
            return (string) $cached;
        }

        $orders = wc_get_orders([
            'customer_id' => $uid,
            'status'      => ['completed', 'processing', 'zb-ready', 'on-hold'],
            'limit'       => 20,
            'orderby'     => 'date',
            'order'       => 'DESC',
            'return'      => 'objects',
        ]);

        $ids = [];
        foreach ($orders as $order) {
            foreach ($order->get_items() as $item) {
                $pid = $item->get_product_id();
                if ($pid && get_post_status($pid) === 'publish' && !in_array($pid, $ids, true)) {
                    $ids[] = $pid;
                }
            }
            if (count($ids) >= 24) {
                break;
            }
        }
        $ids = array_slice($ids, 0, 12);

        $html = empty($ids) ? '' : Zooboxi_Product_Rail::render([
            'ids'   => $ids,
            'title' => __('اطلبها مجدداً', 'zooboxi'),
            'icon'  => '🔁',
            'zone'  => 'home:buyagain',
        ]);

        set_transient($tkey, $html, 15 * MINUTE_IN_SECONDS);
        return $html;
    }

    private function login_card_html(): string
    {
        return '<div class="zb-login-card" id="zb-login-card">'
            . '<div class="zb-login-card__body">'
            . '<span class="zb-login-card__emoji" aria-hidden="true">🐾</span>'
            . '<div class="zb-login-card__txt">'
            . '<h3 class="zb-login-card__title">' . esc_html__('سجّل دخولك واسترجع مشترياتك بضغطة', 'zooboxi') . '</h3>'
            . '<p class="zb-login-card__sub">' . esc_html__('لطلب سريع من مشترياتك السابقة ووصول مخصّص لك', 'zooboxi') . '</p>'
            . '</div></div>'
            . '<div class="zb-login-card__actions">'
            . '<button type="button" class="zb-login-card__btn" id="zb-login-card-btn">' . esc_html__('دخول برقم الجوال', 'zooboxi') . '</button>'
            . '<button type="button" class="zb-login-card__later" id="zb-login-card-later">' . esc_html__('ربما لاحقاً', 'zooboxi') . '</button>'
            . '</div></div>';
    }

    /**
     * "مختار لك" — ONE personalized rail that merges recently-viewed (strong personal
     * signal, shown first) with recommendations (FBT + substitutes) for the latest
     * viewed item, deduped. Replaces the old separate "تصفّحت مؤخراً" + "موصى لك" rails
     * so the homepage isn't cluttered with near-duplicate personal rails.
     */
    private function foryou_html(array $recent): string
    {
        $ids = [];

        // 1) Recently viewed first.
        foreach ($recent as $pid) {
            $pid = (int) $pid;
            if ($pid && get_post_status($pid) === 'publish' && !in_array($pid, $ids, true)) {
                $ids[] = $pid;
            }
        }

        // 2) Recommendations for the latest viewed item (cached by item code).
        if (!empty($recent)) {
            $code = (string) get_post_meta((int) $recent[0], '_zooboxi_item_code', true);
            if ($code !== '') {
                $tkey   = 'zbhome_recs_' . md5($code);
                $recIds = get_transient($tkey);
                if ($recIds === false) {
                    $recs = $this->api_get('/recommendations/' . rawurlencode($code));
                    $pool = array_merge(
                        $recs['frequently_bought_together'] ?? [],
                        $recs['substitutes'] ?? []
                    );
                    $recIds = [];
                    foreach ($pool as $r) {
                        $pid = !empty($r['woo_product_id'])
                            ? (int) $r['woo_product_id']
                            : $this->find_product_id($r['item_code'] ?? '');
                        if ($pid && get_post_status($pid) === 'publish' && !in_array($pid, $recIds, true)) {
                            $recIds[] = $pid;
                        }
                    }
                    set_transient($tkey, $recIds, 30 * MINUTE_IN_SECONDS);
                }
                foreach ($recIds as $pid) {
                    if (!in_array($pid, $ids, true)) {
                        $ids[] = $pid;
                    }
                }
            }
        }

        if (empty($ids)) {
            return '';
        }
        $ids = array_slice($ids, 0, 14);

        return Zooboxi_Product_Rail::render([
            'ids'   => $ids,
            'title' => __('مختار لك', 'zooboxi'),
            'icon'  => '✨',
            'zone'  => 'home:foryou',
        ]);
    }

    private function incity_html(float $lat, float $lng, string $city): string
    {
        $codes = $this->customer_warehouse_codes($lat, $lng, $city);
        if (empty($codes)) {
            return '';
        }

        $tkey   = 'zbhome_incity_' . md5(implode(',', $codes)) . '_' . get_locale();
        $cached = get_transient($tkey);
        if ($cached !== false) {
            return (string) $cached;
        }

        $safe = array_values(array_filter(array_map(
            static fn ($c) => preg_replace('/[^A-Za-z0-9_]/', '', (string) $c),
            $codes
        )));
        if (empty($safe)) {
            return '';
        }
        $pattern = '(^|,)(' . implode('|', $safe) . ')(,|$)';

        $q = new WP_Query([
            'post_type'           => 'product',
            'post_status'         => 'publish',
            'posts_per_page'      => 12,
            'ignore_sticky_posts' => true,
            'no_found_rows'       => true,
            'fields'              => 'ids',
            'meta_key'            => '_zb_rank_score',
            'orderby'             => 'meta_value_num',
            'order'               => 'DESC',
            'meta_query'          => [
                'relation' => 'AND',
                ['key' => '_stock_status', 'value' => 'instock'],
                ['key' => '_zb_avail_branches', 'value' => $pattern, 'compare' => 'REGEXP'],
            ],
            'tax_query'           => [[
                'taxonomy' => 'product_visibility',
                'field'    => 'name',
                'terms'    => 'exclude-from-catalog',
                'operator' => 'NOT IN',
            ]],
        ]);
        $ids = is_array($q->posts) ? array_map('intval', $q->posts) : [];
        wp_reset_postdata();

        $title = $city !== ''
            ? sprintf(__('الأكثر رواجاً في %s', 'zooboxi'), function_exists('zooboxi_city_ar') ? zooboxi_city_ar($city) : $city)
            : __('متاح للتوصيل السريع', 'zooboxi');

        $html = empty($ids) ? '' : Zooboxi_Product_Rail::render([
            'ids'      => $ids,
            'title'    => $title,
            'subtitle' => __('متوفّر بفروعك القريبة', 'zooboxi'),
            'icon'     => '⚡',
            'zone'     => 'home:incity',
        ]);

        set_transient($tkey, $html, 30 * MINUTE_IN_SECONDS);
        return $html;
    }

    /* ── Helpers ─────────────────────────────────────── */

    /** Warehouse codes reachable for the customer (express branch + city central). */
    private function customer_warehouse_codes(float $lat, float $lng, string $city): array
    {
        if (!class_exists('Zooboxi_Warehouse_Manager')) {
            return [];
        }
        $codes = [];
        if ($lat && $lng) {
            $express = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
            if (!empty($express[0]['warehouse']['warehouse_code'])) {
                $codes[] = $express[0]['warehouse']['warehouse_code'];
            }
        }
        if ($city !== '') {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if (!empty($central['warehouse_code']) && !in_array($central['warehouse_code'], $codes, true)) {
                $codes[] = $central['warehouse_code'];
            }
        }
        return array_values(array_filter($codes));
    }

    private function api_get(string $path)
    {
        if ($this->api_token === '') {
            return null;
        }
        $res = wp_remote_get($this->api_base . $path, [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Accept' => 'application/json'],
            'timeout' => 8,
        ]);
        if (is_wp_error($res)) {
            return null;
        }
        return json_decode(wp_remote_retrieve_body($res), true);
    }

    private function find_product_id(string $itemCode): ?int
    {
        if ($itemCode === '') {
            return null;
        }
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s LIMIT 1",
            $itemCode
        ));
        return $id ? (int) $id : null;
    }
}
