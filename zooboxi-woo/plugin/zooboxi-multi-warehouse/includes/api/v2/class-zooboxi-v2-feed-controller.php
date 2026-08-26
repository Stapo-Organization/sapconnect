<?php
/**
 * Zooboxi_V2_Feed_Controller — the app's per-customer home hydration.
 *
 * GET /zooboxi/v2/home/feed is the JSON twin of the website's `/zooboxi/v1/home-feed`
 * (Zooboxi_Home_Feed): the cacheable /home payload carries everything that is the same
 * for every device, and this route — `private, no-store`, guests welcome — carries the
 * three slots that are not:
 *
 *   • personal → "اشترِها مجددًا" (order history, with a due-to-reorder signal) or,
 *                for guests / first-time buyers, "شاهدته مؤخرًا".
 *   • foryou   → recently-viewed merged with FBT + substitutes for the latest view.
 *   • incity   → top-ranked products actually stocked in the customer's own warehouses.
 *
 * The three slots never repeat a product: ids emitted by an earlier slot are excluded
 * from the later ones, so the app's home reads as one list, not three overlapping ones.
 *
 * Prices come from Zooboxi_Product_DTO::cards() only — retail, never wholesale/cost.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Feed_Controller
{
    /** Recently-viewed ids accepted per request. */
    private const RECENT_MAX = 12;

    /** Products in the personal / for-you / in-city slots. */
    private const PERSONAL_MAX = 12;
    private const FORYOU_MAX   = 14;
    private const INCITY_MAX   = 12;

    /** A slot with fewer products than this is not worth a rail — it returns null. */
    private const MIN_PRODUCTS = 4;

    /** Buy-again is derived from up to this many recent orders (matches the web rail). */
    private const ORDER_SCAN = 20;

    /** A single past purchase is "due" again after this many days. */
    private const SINGLE_BUY_DUE_DAYS = 30;

    /** Repeat buyers are "due" at this share of their own median gap. */
    private const DUE_RATIO = 0.8;

    private const BUYAGAIN_TTL = 900;   // 15 min
    private const INCITY_TTL   = 1800;  // 30 min

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/home/feed', 'GET', [$this, 'feed']);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /home/feed
       ══════════════════════════════════════════════════════════════ */

    public function feed(\WP_REST_Request $request): \WP_REST_Response
    {
        $uid    = get_current_user_id();
        $recent = $this->read_recent($request);
        [$lat, $lng, $city] = $this->read_location($request);

        $personal = $this->personal($uid, $recent);
        $used     = self::ids_of($personal['products']);

        $foryou = $this->foryou($recent, $used);
        if ($foryou !== null) {
            $used = array_merge($used, self::ids_of($foryou['products']));
        }

        $incity = $this->incity($lat, $lng, $city, $used);

        // Per-customer by construction → never cacheable.
        return Zooboxi_V2_Bootstrap::ok([
            'personal'    => $personal,
            'foryou'      => $foryou,
            'incity'      => $incity,
            'login_nudge' => $uid <= 0,
        ], null);
    }

    /* ══════════════════════════════════════════════════════════════
       INPUTS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Recently-viewed product ids: the app posts them as `?recent_ids=1,2,3`; the cookie
     * fallback keeps parity with the website's feed for a browser-issued call.
     *
     * @return int[]
     */
    private function read_recent(\WP_REST_Request $request): array
    {
        $raw = (string) $request->get_param('recent_ids');
        if ($raw === '' && !empty($_COOKIE['zooboxi_recently_viewed'])) {
            $decoded = json_decode(stripslashes((string) $_COOKIE['zooboxi_recently_viewed']), true);
            if (is_array($decoded)) {
                $raw = implode(',', $decoded);
            }
        }
        if ($raw === '') {
            return [];
        }

        $ids = [];
        foreach (explode(',', $raw) as $part) {
            $id = absint(trim((string) $part));
            if ($id > 0 && !in_array($id, $ids, true)) {
                $ids[] = $id;
            }
        }
        return array_slice($ids, 0, self::RECENT_MAX);
    }

    /**
     * Location: explicit params win, else the jar the bootstrap already seeded from the
     * X-ZB-* headers — the same order Zooboxi_Home_Feed::read_location() uses.
     *
     * @return array{0:float,1:float,2:string}
     */
    private function read_location(\WP_REST_Request $request): array
    {
        $lat  = (float) $request->get_param('lat');
        $lng  = (float) $request->get_param('lng');
        $city = sanitize_text_field((string) $request->get_param('city'));

        [$cookie_lat, $cookie_lng] = Zooboxi_V2_Bootstrap::latlng();
        if (!$lat) {
            $lat = $cookie_lat;
        }
        if (!$lng) {
            $lng = $cookie_lng;
        }
        if ($city === '') {
            $city = Zooboxi_V2_Bootstrap::city();
        }

        return [$lat, $lng, $city];
    }

    /* ══════════════════════════════════════════════════════════════
       SLOT 1 — personal (buy-again › recently viewed › nothing)
       ══════════════════════════════════════════════════════════════ */

    /**
     * @param int[] $recent
     * @return array{kind:string,title:string,products:array<int,array>}
     */
    private function personal(int $uid, array $recent): array
    {
        if ($uid > 0) {
            $rows = $this->buyagain_rows($uid);
            if (!empty($rows)) {
                $cards = $this->decorate_buyagain($rows);
                if (!empty($cards)) {
                    return [
                        'kind'     => 'buyagain',
                        'title'    => Zooboxi_V2_Bootstrap::pick('اشترِها مجددًا', 'Buy it again'),
                        'products' => $cards,
                    ];
                }
            }
        }

        $ids = $this->live_ids($recent);
        if (!empty($ids)) {
            $cards = Zooboxi_Product_DTO::cards(array_slice($ids, 0, self::PERSONAL_MAX));
            if (!empty($cards)) {
                return [
                    'kind'     => 'recent',
                    'title'    => Zooboxi_V2_Bootstrap::pick('شاهدته مؤخرًا', 'Seen recently'),
                    'products' => $cards,
                ];
            }
        }

        return ['kind' => 'none', 'title' => '', 'products' => []];
    }

    /**
     * Cards for the buy-again rows, each carrying the two extra keys the app's
     * reorder chip needs. Cards are built per request (the delivery chip and the
     * wishlist flag are location/user specific) — only the ordering is cached.
     *
     * @param array<int,array{id:int,last_ordered_days:int,due:bool}> $rows
     */
    private function decorate_buyagain(array $rows): array
    {
        $meta = [];
        foreach ($rows as $row) {
            $meta[(int) $row['id']] = $row;
        }

        $cards = Zooboxi_Product_DTO::cards(array_keys($meta));
        foreach ($cards as &$card) {
            $row = $meta[(int) ($card['id'] ?? 0)] ?? null;
            $card['last_ordered_days'] = $row ? (int) $row['last_ordered_days'] : 0;
            $card['due']               = $row ? (bool) $row['due'] : false;
        }
        unset($card);

        return $cards;
    }

    /**
     * "اشترِها مجددًا" with a rhythm: for every product the customer has bought, how long
     * ago the last purchase was and whether the next one is due.
     *
     * Due = the customer's OWN cadence, not a global rule: with two or more purchases we
     * take the median gap between them and call it due at 80% of that gap; a single
     * purchase becomes due after a month. Due items lead, most overdue first, then the
     * rest by recency.
     *
     * Cached per user for 15 minutes and busted on every order-status change
     * (Zooboxi_V2_Bootstrap::on_order_status_changed).
     *
     * @return array<int,array{id:int,last_ordered_days:int,due:bool}>
     */
    private function buyagain_rows(int $uid): array
    {
        if ($uid <= 0) {
            return [];
        }

        $key    = 'zb_v2_buyagain2_' . $uid;
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }

        // The exact order query the website's rail uses (Zooboxi_Home_Feed::buyagain_ids).
        $orders = wc_get_orders([
            'customer_id' => $uid,
            'status'      => ['completed', 'processing', 'zb-ready', 'on-hold'],
            'limit'       => self::ORDER_SCAN,
            'orderby'     => 'date',
            'order'       => 'DESC',
            'return'      => 'objects',
        ]);

        /** @var array<int,int[]> $stamps product id => purchase timestamps */
        $stamps = [];
        foreach ((array) $orders as $order) {
            if (!($order instanceof \WC_Order)) {
                continue;
            }
            $created = $order->get_date_created();
            $when    = $created ? (int) $created->getTimestamp() : 0;
            if ($when <= 0) {
                continue;
            }
            foreach ($order->get_items() as $item) {
                $pid = (int) $item->get_product_id();
                if ($pid <= 0 || get_post_status($pid) !== 'publish') {
                    continue;
                }
                $stamps[$pid][] = $when;
            }
        }

        $now  = current_time('timestamp');
        $rows = [];
        foreach ($stamps as $pid => $times) {
            $times = array_values(array_unique($times));
            rsort($times); // newest first

            $last_days = (int) max(0, floor(($now - $times[0]) / DAY_IN_SECONDS));
            $threshold = (float) self::SINGLE_BUY_DUE_DAYS;

            if (count($times) >= 2) {
                $gaps = [];
                for ($i = 0, $n = count($times) - 1; $i < $n; $i++) {
                    $gap = ($times[$i] - $times[$i + 1]) / DAY_IN_SECONDS;
                    if ($gap > 0) {
                        $gaps[] = (float) $gap;
                    }
                }
                if (!empty($gaps)) {
                    $threshold = self::median($gaps) * self::DUE_RATIO;
                }
            }

            $threshold = max(1.0, $threshold);
            $rows[]    = [
                'id'                => $pid,
                'last_ordered_days' => $last_days,
                'due'               => $last_days >= $threshold,
                'over'              => $last_days - $threshold, // sort key only
            ];
        }

        usort($rows, static function (array $a, array $b) {
            if ($a['due'] !== $b['due']) {
                return $a['due'] ? -1 : 1;   // due first
            }
            if ($a['due']) {
                return $b['over'] <=> $a['over'];              // most overdue first
            }
            return $a['last_ordered_days'] <=> $b['last_ordered_days']; // then most recent
        });

        $out = [];
        foreach (array_slice($rows, 0, self::PERSONAL_MAX) as $row) {
            $out[] = [
                'id'                => (int) $row['id'],
                'last_ordered_days' => (int) $row['last_ordered_days'],
                'due'               => (bool) $row['due'],
            ];
        }

        set_transient($key, $out, self::BUYAGAIN_TTL);
        return $out;
    }

    /** @param float[] $values */
    private static function median(array $values): float
    {
        if (empty($values)) {
            return 0.0;
        }
        sort($values);
        $count = count($values);
        $mid   = intdiv($count, 2);

        return ($count % 2)
            ? (float) $values[$mid]
            : (float) (($values[$mid - 1] + $values[$mid]) / 2);
    }

    /* ══════════════════════════════════════════════════════════════
       SLOT 2 — "مختار لك"
       ══════════════════════════════════════════════════════════════ */

    /**
     * Recently viewed first (the strongest personal signal), then the FBT + substitute
     * recommendations for the latest view — the same merge the website's foryou rail
     * does, minus anything the personal slot already showed.
     *
     * @param int[] $recent
     * @param int[] $exclude
     */
    private function foryou(array $recent, array $exclude): ?array
    {
        $ids = $this->live_ids($recent);

        if (!empty($recent)) {
            $code = (string) get_post_meta((int) $recent[0], '_zooboxi_item_code', true);
            if ($code !== '') {
                $recs = Zooboxi_Product_DTO::recommendations($code);
                foreach (array_merge($recs['fbt'] ?? [], $recs['substitutes'] ?? []) as $pid) {
                    $pid = (int) $pid;
                    if ($pid > 0 && !in_array($pid, $ids, true) && get_post_status($pid) === 'publish') {
                        $ids[] = $pid;
                    }
                }
            }
        }

        if (!empty($exclude)) {
            $ids = array_values(array_diff($ids, $exclude));
        }
        $ids = array_slice($ids, 0, self::FORYOU_MAX);
        if (count($ids) < self::MIN_PRODUCTS) {
            return null;
        }

        $cards = Zooboxi_Product_DTO::cards($ids);
        if (count($cards) < self::MIN_PRODUCTS) {
            return null;
        }

        return [
            'title'    => Zooboxi_V2_Bootstrap::pick('مختار لك', 'Picked for you'),
            'products' => $cards,
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       SLOT 3 — "الأكثر رواجاً في {city}"
       ══════════════════════════════════════════════════════════════ */

    /**
     * Top-ranked products that are actually stocked in the warehouses this customer can
     * be served from — the express branch and the city's central. Unknown location →
     * null (there is no honest "in your city" without a city).
     *
     * @param int[] $exclude
     */
    private function incity(float $lat, float $lng, string $city, array $exclude): ?array
    {
        $codes = $this->customer_warehouse_codes($lat, $lng, $city);
        if (empty($codes)) {
            return null;
        }

        $safe = array_values(array_filter(array_map(
            static fn ($c) => preg_replace('/[^A-Za-z0-9_]/', '', (string) $c),
            $codes
        )));
        if (empty($safe)) {
            return null;
        }

        $key = 'zb_v2_incity_' . md5(implode(',', $safe)) . '_' . get_locale();
        $ids = get_transient($key);

        if (!is_array($ids)) {
            $pattern = '(^|,)(' . implode('|', $safe) . ')(,|$)';
            $query   = new WP_Query([
                'post_type'           => 'product',
                'post_status'         => 'publish',
                'posts_per_page'      => self::INCITY_MAX,
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
            $ids = is_array($query->posts) ? array_map('intval', $query->posts) : [];
            wp_reset_postdata();
            set_transient($key, $ids, self::INCITY_TTL);
        }

        $ids = array_map('intval', $ids);
        if (!empty($exclude)) {
            $ids = array_values(array_diff($ids, $exclude));
        }
        if (count($ids) < self::MIN_PRODUCTS) {
            return null;
        }

        $cards = Zooboxi_Product_DTO::cards($ids);
        if (count($cards) < self::MIN_PRODUCTS) {
            return null;
        }

        return [
            'title'    => $this->incity_title($city),
            'products' => $cards,
        ];
    }

    private function incity_title(string $city): string
    {
        if ($city === '') {
            return Zooboxi_V2_Bootstrap::pick('متاح للتوصيل السريع', 'Available for express delivery');
        }

        // Reverse geocoding stores English city names; the website maps them for display.
        $display = (Zooboxi_V2_Bootstrap::lang() !== 'en' && function_exists('zooboxi_city_ar'))
            ? zooboxi_city_ar($city)
            : $city;

        return sprintf(
            Zooboxi_V2_Bootstrap::pick('الأكثر رواجاً في %s', 'Trending in %s'),
            $display
        );
    }

    /**
     * Warehouse codes reachable for this customer (nearest express branch + the city's
     * central) — a copy of Zooboxi_Home_Feed::customer_warehouse_codes(), which is
     * private to that web-rendering class.
     *
     * @return string[]
     */
    private function customer_warehouse_codes(float $lat, float $lng, string $city): array
    {
        if (!class_exists('Zooboxi_Warehouse_Manager')) {
            return [];
        }

        $codes = [];
        if ($lat && $lng) {
            $express = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
            if (!empty($express[0]['warehouse']['warehouse_code'])) {
                $codes[] = (string) $express[0]['warehouse']['warehouse_code'];
            }
        }
        if ($city !== '') {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if (!empty($central['warehouse_code']) && !in_array($central['warehouse_code'], $codes, true)) {
                $codes[] = (string) $central['warehouse_code'];
            }
        }

        return array_values(array_filter($codes));
    }

    /* ══════════════════════════════════════════════════════════════
       HELPERS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Keep only ids that still resolve to a published, catalogue-visible product,
     * preserving the caller's order.
     *
     * @param int[] $ids
     * @return int[]
     */
    private function live_ids(array $ids): array
    {
        $out = [];
        foreach ($ids as $raw) {
            $id = (int) $raw;
            if ($id <= 0 || in_array($id, $out, true)) {
                continue;
            }
            if (get_post_status($id) !== 'publish' || !wc_get_product($id)) {
                continue;
            }
            if (has_term('exclude-from-catalog', 'product_visibility', $id)) {
                continue;
            }
            $out[] = $id;
        }
        return $out;
    }

    /**
     * @param array<int,array> $cards
     * @return int[]
     */
    private static function ids_of(array $cards): array
    {
        $ids = [];
        foreach ($cards as $card) {
            $id = (int) ($card['id'] ?? 0);
            if ($id > 0) {
                $ids[] = $id;
            }
        }
        return $ids;
    }
}
