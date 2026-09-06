<?php
/**
 * ════════════════════════════════════════════════════════════════════
 * Zooboxi_V2_Scope — the app catalogue is ONE warehouse's assortment
 *
 * A quick-commerce storefront should not advertise what it cannot bring you.
 * So the app shows the shelf of the single warehouse that serves the customer
 * fastest, and nothing else:
 *
 *   inside an express zone   → that branch's stock,  «خلال ساعتين»
 *   a city we keep stock in  → the city central,     «يوصلك غدًا»
 *   anywhere else            → the national hub,     «يصلك يوم …»
 *
 * The order mirrors Zooboxi_Fulfillment::resolve() exactly — nearest express
 * branch, then city central, then hub — so the shelf a customer browses and
 * the promise their cart makes can never describe different warehouses.
 *
 * Availability is read from `_zb_avail_branches` (a comma-joined list of the
 * warehouse codes holding stock, rewritten by the intelligence module on every
 * stock sync), which makes the filter one indexed meta clause instead of a
 * JSON scan.
 *
 * WEB IS UNTOUCHED: every entry point here is a v2/app request. The website
 * keeps showing the full catalogue.
 * ════════════════════════════════════════════════════════════════════
 */

class Zooboxi_V2_Scope
{
    /** Kill-switch. `no` restores the full catalogue to the app instantly. */
    public const OPTION = 'zooboxi_app_catalog_scope';

    /** false = not resolved yet for this request; null = no scope applies. */
    private static $memo = false;

    public static function is_enabled(): bool
    {
        return get_option(self::OPTION, 'yes') !== 'no';
    }

    /** Forget the memo — for tests and long-running CLI loops. */
    public static function reset(): void
    {
        self::$memo = false;
    }

    /**
     * The warehouse this request's catalogue is drawn from, with the promise
     * that comes with it. Null when the customer has no location (they get the
     * whole catalogue and a "set your location" prompt) or scoping is off.
     *
     * @return array{tier:string,warehouse_code:string,warehouse_name:string,label:string,icon:string,date:string}|null
     */
    public static function current(): ?array
    {
        if (self::$memo !== false) {
            return self::$memo;
        }
        self::$memo = null;

        if (!self::is_enabled() || !class_exists('Zooboxi_Warehouse_Manager')) {
            return null;
        }

        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        if (!$lat && !$lng) {
            return null;
        }

        // 1) Express — the nearest in-zone branch that is open right now. When
        //    it closes for the night the customer falls to the city central and
        //    the catalogue widens; that is honest, not a glitch.
        $express = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        if (!empty($express[0]['warehouse'])) {
            return self::$memo = self::build(
                Zooboxi_Delivery_Engine::TYPE_EXPRESS,
                $express[0]['warehouse']
            );
        }

        // 2) The city we are standing in, if we keep a central warehouse there.
        $city = Zooboxi_V2_Bootstrap::city();
        if ($city === '') {
            $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
            $city    = (string) ($nearest['warehouse']['city'] ?? '');
        }
        if ($city !== '') {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if (!empty($central['warehouse_code'])) {
                return self::$memo = self::build(Zooboxi_Delivery_Engine::TYPE_STANDARD, $central);
            }
        }

        // 3) Out of town — the national hub, with a real delivery date.
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if (!empty($hub['warehouse_code'])) {
            return self::$memo = self::build(Zooboxi_Delivery_Engine::TYPE_SHIPPING, $hub);
        }

        return null;
    }

    /** @param array $warehouse Row from the warehouses table. */
    private static function build(string $tier, array $warehouse): array
    {
        $pres = Zooboxi_Fulfillment::tier_presentation($tier);

        return [
            'tier'           => $tier,
            'warehouse_code' => (string) ($warehouse['warehouse_code'] ?? ''),
            'warehouse_name' => self::wh_name($warehouse),
            'label'          => Zooboxi_Product_DTO::promise_label($tier),
            'icon'           => (string) $pres['icon'],
            'date'           => (string) $pres['date'],
        ];
    }

    private static function wh_name(array $wh): string
    {
        $ar = (string) ($wh['display_name_ar'] ?? '');
        $en = (string) ($wh['display_name_en'] ?? '');
        return Zooboxi_V2_Bootstrap::lang() === 'en' ? ($en ?: $ar) : ($ar ?: $en);
    }

    /** The scoped warehouse code, or '' when the catalogue is not narrowed. */
    public static function warehouse_code(): string
    {
        $scope = self::current();
        return $scope ? (string) $scope['warehouse_code'] : '';
    }

    /**
     * A `meta_query` clause selecting products this warehouse actually holds.
     * Null when nothing should be filtered.
     */
    public static function meta_clause(): ?array
    {
        $code = self::warehouse_code();
        if ($code === '') {
            return null;
        }
        return [
            'key'     => '_zb_avail_branches',
            'value'   => self::regexp($code),
            'compare' => 'REGEXP',
        ];
    }

    /** Anchored so RUH01 can never match RUH010. */
    private static function regexp(string $code): string
    {
        return '(^|,)' . preg_quote($code, '/') . '(,|$)';
    }

    /**
     * Keeps only the ids this warehouse holds, in the caller's order. Used by
     * every id-driven surface (home rails, the personal feed, curated brand
     * picks) — the ones a meta_query cannot reach.
     *
     * @param int[] $ids
     * @return int[]
     */
    public static function filter_ids(array $ids): array
    {
        $code = self::warehouse_code();
        if ($code === '' || empty($ids)) {
            return $ids;
        }

        global $wpdb;
        $ids         = array_values(array_unique(array_map('intval', $ids)));
        $placeholders = implode(',', array_fill(0, count($ids), '%d'));
        $params      = $ids;
        $params[]    = self::regexp($code);

        $keep = $wpdb->get_col($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta}
             WHERE meta_key = '_zb_avail_branches'
               AND post_id IN ($placeholders)
               AND meta_value REGEXP %s",
            $params
        ));

        $keep = array_flip(array_map('intval', (array) $keep));
        return array_values(array_filter($ids, static fn($id) => isset($keep[$id])));
    }

    /**
     * Products per category term for the scoped warehouse — one grouped query
     * for the whole tree, so the category screen counts what it will actually
     * show. Cached per warehouse; the stock sync is hourly at most.
     *
     * @return array<int,int> term_id => product count
     */
    public static function category_counts(): array
    {
        $code = self::warehouse_code();
        if ($code === '') {
            return [];
        }

        $key    = 'zb_v2_catcount_' . $code;
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT tt.term_id AS term_id, COUNT(DISTINCT p.ID) AS total
               FROM {$wpdb->term_relationships} tr
               JOIN {$wpdb->term_taxonomy} tt
                 ON tt.term_taxonomy_id = tr.term_taxonomy_id AND tt.taxonomy = 'product_cat'
               JOIN {$wpdb->posts} p
                 ON p.ID = tr.object_id AND p.post_type = 'product' AND p.post_status = 'publish'
               JOIN {$wpdb->postmeta} m
                 ON m.post_id = p.ID AND m.meta_key = '_zb_avail_branches' AND m.meta_value REGEXP %s
              GROUP BY tt.term_id",
            self::regexp($code)
        ));

        $out = [];
        foreach ((array) $rows as $row) {
            $out[(int) $row->term_id] = (int) $row->total;
        }
        set_transient($key, $out, 15 * MINUTE_IN_SECONDS);
        return $out;
    }

    /**
     * What the app tells the customer about the shelf they are browsing.
     * Null when the catalogue is not narrowed, so the app shows nothing.
     */
    public static function payload(): ?array
    {
        $scope = self::current();
        if (!$scope) {
            return null;
        }
        return [
            'tier'           => $scope['tier'],
            'warehouse_name' => $scope['warehouse_name'],
            'label'          => $scope['label'],
            'icon'           => $scope['icon'],
            'date'           => $scope['date'],
            'note'           => self::note($scope),
        ];
    }

    private static function note(array $scope): string
    {
        $en = Zooboxi_V2_Bootstrap::lang() === 'en';

        switch ($scope['tier']) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return $en
                    ? sprintf('Showing what %s can bring you within two hours', $scope['warehouse_name'])
                    : sprintf('نعرض ما يمكن أن يصلك خلال ساعتين من %s', $scope['warehouse_name']);
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return $en
                    ? 'Showing what we can deliver to you tomorrow'
                    : 'نعرض ما يمكن أن يصلك غدًا';
            default:
                return $en
                    ? sprintf('Showing what we can ship to you by %s', $scope['date'])
                    : sprintf('نعرض ما يمكن شحنه إليك ووصوله %s', $scope['date']);
        }
    }
}
