<?php
/**
 * ════════════════════════════════════════════════════════════════════
 * Zooboxi_V2_Scope — which shelf the app is browsing
 *
 * The app is two storefronts behind two tabs:
 *
 *   إكسبريس — the 2-hour dark store: ONLY what the nearest open express
 *              branch holds. Available when the customer stands inside an
 *              express zone during its working hours.
 *   زوبكسي  — the full store: everything that can reach this address at
 *              all (express branch ∪ city central ∪ national hub), each
 *              product carrying its own honest promise chip.
 *
 * The tab travels as the `X-ZB-Shelf` header ('express' | 'all'). An older
 * app build sends none and gets the AUTO behaviour: the fastest single
 * shelf, which is what those builds already showed.
 *
 * Warehouse order mirrors Zooboxi_Fulfillment::resolve() exactly — nearest
 * express, then city central, then hub — so the shelf a customer browses
 * and the promise their cart makes can never name different warehouses.
 *
 * Availability is read from `_zb_avail_branches` (a comma-joined list of
 * warehouse codes holding stock, rewritten by the intelligence module on
 * every stock sync): one indexed meta clause instead of a JSON scan.
 *
 * WEB IS UNTOUCHED: every entry point here is a v2/app request.
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
     * The shelf this request browses. Null when the customer has no location
     * (they get the whole catalogue and a "set your location" prompt) or the
     * feature is off.
     *
     * @return array{
     *   shelf:string, tier:string, codes:string[],
     *   warehouse_code:string, warehouse_name:string,
     *   label:string, icon:string, date:string,
     *   express_available:bool, express_branch:string
     * }|null
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

        // The reachable warehouses, fastest first — the same three rungs the
        // fulfillment resolver climbs.
        $express = null;
        $found   = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        if (!empty($found[0]['warehouse'])) {
            $express = $found[0]['warehouse'];
        }

        $central = null;
        $city    = Zooboxi_V2_Bootstrap::city();
        if ($city === '') {
            $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
            $city    = (string) ($nearest['warehouse']['city'] ?? '');
        }
        if ($city !== '') {
            $row = Zooboxi_Warehouse_Manager::find_central($city);
            if (!empty($row['warehouse_code'])) {
                $central = $row;
            }
        }

        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if (empty($hub['warehouse_code'])) {
            $hub = null;
        }

        $shelf = Zooboxi_V2_Bootstrap::shelf();

        // ── إكسبريس: the dark store, only while it actually exists here.
        if ($shelf === 'express' && $express) {
            return self::$memo = self::build('express', Zooboxi_Delivery_Engine::TYPE_EXPRESS, $express, [$express], $express);
        }

        // ── زوبكسي (and an express request from somewhere without express):
        //    everything reachable, guaranteed by the slowest rung present.
        if ($shelf !== '') {
            $rungs = array_values(array_filter([$express, $central, $hub]));
            if (empty($rungs)) {
                return null;
            }
            // The guarantee the whole shelf can honour comes from the slowest
            // NON-express rung — express items are a faster subset, flagged by
            // their own chips.
            $anchor = $central ?: ($hub ?: $express);
            $tier   = $central
                ? Zooboxi_Delivery_Engine::TYPE_STANDARD
                : ($hub ? Zooboxi_Delivery_Engine::TYPE_SHIPPING : Zooboxi_Delivery_Engine::TYPE_EXPRESS);

            return self::$memo = self::build('all', $tier, $anchor, $rungs, $express);
        }

        // ── No header — an app build from before the tabs: fastest shelf.
        if ($express) {
            return self::$memo = self::build('auto', Zooboxi_Delivery_Engine::TYPE_EXPRESS, $express, [$express], $express);
        }
        if ($central) {
            return self::$memo = self::build('auto', Zooboxi_Delivery_Engine::TYPE_STANDARD, $central, [$central], null);
        }
        if ($hub) {
            return self::$memo = self::build('auto', Zooboxi_Delivery_Engine::TYPE_SHIPPING, $hub, [$hub], null);
        }

        return null;
    }

    /**
     * @param array      $anchor  The warehouse whose promise names the shelf.
     * @param array[]    $rungs   Every warehouse whose stock belongs on it.
     * @param array|null $express The express branch serving this point, if any.
     */
    private static function build(string $shelf, string $tier, array $anchor, array $rungs, ?array $express): array
    {
        $pres  = Zooboxi_Fulfillment::tier_presentation($tier);
        $codes = [];
        foreach ($rungs as $rung) {
            $code = (string) ($rung['warehouse_code'] ?? '');
            if ($code !== '' && !in_array($code, $codes, true)) {
                $codes[] = $code;
            }
        }

        return [
            'shelf'             => $shelf,
            'tier'              => $tier,
            'codes'             => $codes,
            'warehouse_code'    => (string) ($anchor['warehouse_code'] ?? ''),
            'warehouse_name'    => self::wh_name($anchor),
            'label'             => Zooboxi_Product_DTO::promise_label($tier),
            'icon'              => (string) $pres['icon'],
            'date'              => (string) $pres['date'],
            'express_available' => $express !== null,
            'express_branch'    => $express ? self::wh_name($express) : '',
        ];
    }

    private static function wh_name(array $wh): string
    {
        $ar = (string) ($wh['display_name_ar'] ?? '');
        $en = (string) ($wh['display_name_en'] ?? '');
        return Zooboxi_V2_Bootstrap::lang() === 'en' ? ($en ?: $ar) : ($ar ?: $en);
    }

    /** The scoped warehouse codes, [] when the catalogue is not narrowed. */
    public static function codes(): array
    {
        $scope = self::current();
        return $scope ? $scope['codes'] : [];
    }

    /**
     * A cache-key fragment naming this shelf: '' when unscoped. Used by the
     * per-shelf rail pools and the category-count transient.
     */
    public static function cache_suffix(): string
    {
        $codes = self::codes();
        return empty($codes) ? '' : '_' . implode('-', $codes);
    }

    /** Kept for call sites that only need to know "is scoping on here?". */
    public static function warehouse_code(): string
    {
        $scope = self::current();
        return $scope ? (string) $scope['warehouse_code'] : '';
    }

    /**
     * A `meta_query` clause selecting products at least one shelf warehouse
     * holds. Null when nothing should be filtered.
     */
    public static function meta_clause(): ?array
    {
        $codes = self::codes();
        if (empty($codes)) {
            return null;
        }
        return [
            'key'     => '_zb_avail_branches',
            'value'   => self::regexp($codes),
            'compare' => 'REGEXP',
        ];
    }

    /** Anchored per code so RUH01 can never match RUH010. */
    private static function regexp(array $codes): string
    {
        $quoted = array_map(static fn($c) => preg_quote($c, '/'), $codes);
        return '(^|,)(' . implode('|', $quoted) . ')(,|$)';
    }

    /**
     * Keeps only the ids some shelf warehouse holds, in the caller's order.
     * Used by every id-driven surface (home rails, the personal feed, curated
     * brand picks) — the ones a meta_query cannot reach.
     *
     * @param int[] $ids
     * @return int[]
     */
    public static function filter_ids(array $ids): array
    {
        $codes = self::codes();
        if (empty($codes) || empty($ids)) {
            return $ids;
        }

        global $wpdb;
        $ids          = array_values(array_unique(array_map('intval', $ids)));
        $placeholders = implode(',', array_fill(0, count($ids), '%d'));
        $params       = $ids;
        $params[]     = self::regexp($codes);

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
     * Products per category term for this shelf — one grouped query for the
     * whole tree, so the category screen counts what it will actually show.
     * Cached per shelf; the stock sync is hourly at most.
     *
     * @return array<int,int> term_id => product count
     */
    public static function category_counts(): array
    {
        $codes = self::codes();
        if (empty($codes)) {
            return [];
        }

        $key    = 'zb_v2_catcount' . self::cache_suffix();
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
            self::regexp($codes)
        ));

        $out = [];
        foreach ((array) $rows as $row) {
            $out[(int) $row->term_id] = (int) $row->total;
        }
        set_transient($key, $out, 15 * MINUTE_IN_SECONDS);
        return $out;
    }

    /**
     * What the app needs to draw its two tabs and the shelf band. Null when
     * the catalogue is not narrowed, so the app shows neither.
     */
    public static function payload(): ?array
    {
        $scope = self::current();
        if (!$scope) {
            return null;
        }
        return [
            'shelf'             => $scope['shelf'],
            'tier'              => $scope['tier'],
            'warehouse_name'    => $scope['warehouse_name'],
            'label'             => $scope['label'],
            'icon'              => $scope['icon'],
            'date'              => $scope['date'],
            'express_available' => $scope['express_available'],
            'express_branch'    => $scope['express_branch'],
            'note'              => self::note($scope),
        ];
    }

    private static function note(array $scope): string
    {
        $en = Zooboxi_V2_Bootstrap::lang() === 'en';

        // The full store, browsed by someone who also has the express tab:
        // point at the ⚡ subset instead of restating the slow guarantee.
        if ($scope['shelf'] === 'all' && $scope['express_available']) {
            return $en
                ? 'The whole store — items marked ⚡ reach you within two hours'
                : 'كل المتجر — الأصناف الموسومة بـ⚡ تصلك خلال ساعتين';
        }

        // One line on a phone-width ribbon: every word earns its place.
        switch ($scope['tier']) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return $en
                    ? sprintf('Everything here in 2 hours — %s', $scope['warehouse_name'])
                    : sprintf('كل ما هنا يصلك خلال ساعتين — %s', $scope['warehouse_name']);
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return $en
                    ? 'Everything here reaches you tomorrow'
                    : 'كل ما هنا يصلك غدًا';
            default:
                return $en
                    ? sprintf('Ships to you, arriving by %s', $scope['date'])
                    : sprintf('يصلك شحنًا بحلول %s', $scope['date']);
        }
    }
}
