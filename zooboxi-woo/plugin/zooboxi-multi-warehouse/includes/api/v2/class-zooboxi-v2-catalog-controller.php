<?php
/**
 * Zooboxi_V2_Catalog_Controller — home, categories, listing, PDP, search, brands.
 *
 * SORT PARITY is the point of this file. The website orders a category page by
 * (1) express availability, (2) in-stock first, (3) the chosen sort — two `posts_clauses`
 * filters that gate themselves on `is_main_query()`. A REST query is never a main query,
 * so the app would have shown a different order from the same category. Both filters now
 * also accept an explicit `zooboxi_v2_listing` query flag, which ONLY this controller
 * sets — the website's queries never carry it, so its behaviour is untouched.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Catalog_Controller
{
    private const PER_PAGE_DEFAULT = 24;
    private const PER_PAGE_MAX     = 48;

    /** Hero: how many manual banners count as "enough" before auto slides fill in. */
    private const HERO_MIN_MANUAL = 2;

    /** Hero: hard cap on slides returned (manual + auto). */
    private const HERO_MAX = 5;

    /** Products per home rail after cross-rail dedup. */
    private const RAIL_SIZE = 12;

    /** The 11 faceted attribute taxonomies the store curates. */
    public const FACET_TAXONOMIES = [
        'pa_brand', 'pa_age', 'pa_flavor', 'pa_food-type', 'pa_health', 'pa_litter-type',
        'pa_color', 'pa_material', 'pa_product-type', 'pa_size-opt', 'pa_weight-opt',
    ];

    /** `?rail=` on the listing → the rail query builder that shapes it. */
    private const RAIL_QUERIES = [
        'trending'    => 'q_trending',
        'bestsellers' => 'q_bestsellers',
        'new'         => 'q_new',
        'clearance'   => 'q_clearance',
    ];

    /** The default app home composition (option `zooboxi_app_home_layout` overrides). */
    private const DEFAULT_LAYOUT = [
        ['type' => 'hero'],
        ['type' => 'animal_nav'],
        ['type' => 'personal'],
        ['type' => 'shipping_nudge'],
        ['type' => 'rail', 'key' => 'trending'],
        ['type' => 'banner', 'index' => 0],
        ['type' => 'feed_rail', 'key' => 'foryou'],
        ['type' => 'rail', 'key' => 'bestsellers'],
        ['type' => 'feed_rail', 'key' => 'incity'],
        ['type' => 'clearance_band'],
        ['type' => 'rail', 'key' => 'new'],
        ['type' => 'banner', 'index' => 1],
        ['type' => 'wishlist_rail'],
        ['type' => 'brands'],
        ['type' => 'trust'],
    ];

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/home', 'GET', [$this, 'home']);
        Zooboxi_V2_Bootstrap::route('/catalog/categories', 'GET', [$this, 'categories']);
        Zooboxi_V2_Bootstrap::route('/catalog/products', 'GET', [$this, 'products']);
        Zooboxi_V2_Bootstrap::route('/catalog/products/(?P<id>\d+)', 'GET', [$this, 'product']);
        Zooboxi_V2_Bootstrap::route('/catalog/search/suggest', 'GET', [$this, 'suggest']);
        Zooboxi_V2_Bootstrap::route('/catalog/barcode/(?P<code>[A-Za-z0-9_\-\.]+)', 'GET', [$this, 'barcode']);
        Zooboxi_V2_Bootstrap::route('/brands', 'GET', [$this, 'brands']);
        Zooboxi_V2_Bootstrap::route('/brands/(?P<slug>[^/]+)', 'GET', [$this, 'brand']);
        Zooboxi_V2_Bootstrap::route('/clearance', 'GET', [$this, 'clearance']);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /home
       ══════════════════════════════════════════════════════════════ */

    public function home(\WP_REST_Request $request): \WP_REST_Response
    {
        // Rails run FIRST: they warm the shared `zbhome_ids_*` pools the hero's auto
        // slides peek at for their clearance / bestsellers artwork.
        // `$used` carries every id already shown so the four rails never repeat a
        // product (same accumulator pattern as Zooboxi_Homepage::cached_rail()).
        $used  = [];
        $rails = [
            $this->rail('trending', __('رائج الآن', 'zooboxi'), [
                Zooboxi_Product_Rail::q_trending(24),
                Zooboxi_Product_Rail::q_top_ranked(24),
            ], $used),
            $this->rail('bestsellers', __('الأكثر طلباً', 'zooboxi'), [
                Zooboxi_Product_Rail::q_bestsellers(24),
                Zooboxi_Product_Rail::q_top_ranked(24),
                Zooboxi_Product_Rail::q_newest(24),
            ], $used),
            $this->rail('new', __('وصل حديثاً', 'zooboxi'), [
                Zooboxi_Product_Rail::q_new(24),
                Zooboxi_Product_Rail::q_newest(24),
            ], $used),
            $this->rail('clearance', __('عروض التصفية', 'zooboxi'), [
                Zooboxi_Product_Rail::q_clearance(24),
            ], $used),
        ];

        return Zooboxi_V2_Bootstrap::ok([
            'hero'          => $this->hero_slides(),
            'campaigns'     => $this->campaigns(),
            'animal_nav'    => $this->animal_nav(),
            'rails'         => array_values(array_filter($rails)),
            'brands'        => $this->brand_list(12),
            'layout'        => $this->layout(),
            'lang_fallback' => Zooboxi_V2_Bootstrap::lang_fallback(),
        ], Zooboxi_V2_Bootstrap::TTL_HOME);
    }

    /**
     * The section order the app renders. Owner-overridable through the option
     * `zooboxi_app_home_layout` (a JSON string or a plain array); anything that does
     * not decode to a non-empty array falls back to the shipped composition.
     */
    private function layout(): array
    {
        $raw = get_option('zooboxi_app_home_layout', '');
        if (is_string($raw) && trim($raw) !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded) && !empty($decoded)) {
                return array_values($decoded);
            }
        }
        if (is_array($raw) && !empty($raw)) {
            return array_values($raw);
        }
        return self::DEFAULT_LAYOUT;
    }

    /* ══════════════════════════════════════════════════════════════
       HERO — owner banners first, on-brand auto slides so it is never empty
       ══════════════════════════════════════════════════════════════ */

    /**
     * Owner-uploaded hero banners (option `zooboxi_hero_slides`) exposed as data, then
     * — when the owner has fewer than two live banners — structured AUTO slides the app
     * renders natively (no image needed). Mirrors the website's never-empty hero
     * (Zooboxi_Hero_Slider::auto_slides) without touching that class.
     */
    private function hero_slides(): array
    {
        $out = [];
        $raw = get_option('zooboxi_hero_slides', []);

        if (is_array($raw) && !empty($raw)) {
            $now = current_time('timestamp');
            foreach ($raw as $r) {
                if (!is_array($r) || empty($r['active']) || empty($r['image'])) {
                    continue;
                }
                if (!empty($r['start']) && strtotime((string) $r['start']) > $now) {
                    continue;
                }
                if (!empty($r['end']) && strtotime((string) $r['end']) < $now) {
                    continue;
                }
                $out[] = [
                    'kind'         => 'manual',
                    'image'        => esc_url_raw((string) $r['image']),
                    'image_mobile' => !empty($r['image_mobile']) ? esc_url_raw((string) $r['image_mobile']) : null,
                    'link'         => !empty($r['link']) ? esc_url_raw((string) $r['link']) : null,
                    'headline'     => (string) ($r['headline'] ?? ''),
                    'subheadline'  => (string) ($r['subheadline'] ?? ''),
                    'cta_label'    => (string) ($r['cta_label'] ?? ''),
                    'order'        => (int) ($r['order'] ?? 0),
                ];
            }
            usort($out, static fn ($a, $b) => $a['order'] <=> $b['order']);
        }

        if (count($out) >= self::HERO_MIN_MANUAL) {
            return array_slice($out, 0, self::HERO_MAX);
        }

        foreach ($this->auto_hero_slides() as $auto) {
            if (count($out) >= self::HERO_MAX) {
                break;
            }
            $out[] = $auto;
        }
        return $out;
    }

    /**
     * Data-driven hero panels: the express promise, live clearance, a featured brand and
     * the bestsellers pool. Composition ported from Zooboxi_Hero_Slider::auto_slides();
     * the app draws them, so we ship copy + artwork instead of a baked banner.
     */
    private function auto_hero_slides(): array
    {
        $shop = function_exists('wc_get_page_permalink') ? (wc_get_page_permalink('shop') ?: null) : null;
        $out  = [];

        // 1) Express promise — always true, always available.
        $out[] = $this->auto_slide(
            'express',
            Zooboxi_V2_Bootstrap::pick('توصيل خلال ساعتين', 'Delivered in two hours'),
            Zooboxi_V2_Bootstrap::pick('من أقرب مستودع إليك داخل مدينتك', 'From the nearest warehouse in your city'),
            Zooboxi_V2_Bootstrap::pick('تسوّق الآن', 'Shop now'),
            $shop
        );

        // 2) Clearance — only when the collection actually has stock. The badge
        // carries the real number ("up to 45% off") because "offers" without a
        // figure is wallpaper, not merchandising.
        $clearance = $this->pool_ids('clearance', [Zooboxi_Product_Rail::q_clearance(4)]);
        if (!empty($clearance)) {
            $max_off = 0;
            foreach (array_slice($clearance, 0, 8) as $cid) {
                $p = function_exists('wc_get_product') ? wc_get_product((int) $cid) : null;
                if (!$p) {
                    continue;
                }
                $regular = (float) $p->get_regular_price();
                $now     = (float) $p->get_price();
                if ($regular > 0 && $now > 0 && $now < $regular) {
                    $max_off = max($max_off, (int) round((1 - $now / $regular) * 100));
                }
            }
            // No clearance archive exists on the website, so the app routes this slide
            // by `theme` (its own /clearance surface) rather than by URL.
            $out[] = $this->auto_slide(
                'clearance',
                Zooboxi_V2_Bootstrap::pick('عروض التصفية', 'Clearance offers'),
                Zooboxi_V2_Bootstrap::pick('أسعار مخفّضة على منتجات مختارة بكميات محدودة', 'Reduced prices on selected products, limited quantities'),
                Zooboxi_V2_Bootstrap::pick('اكتشف العروض', 'View the offers'),
                null,
                null,
                self::thumbs($clearance, 4),
                $max_off >= 10
                    ? sprintf(Zooboxi_V2_Bootstrap::pick('خصم حتى %d%%', 'Up to %d%% off'), $max_off)
                    : null
            );
        }

        // 3) Featured brand (shares the website's 6h `zbhero_featured_brand` transient).
        $brand = $this->featured_brand();
        if ($brand !== null) {
            $out[] = $this->auto_slide(
                'brand',
                sprintf(Zooboxi_V2_Bootstrap::pick('ماركة %s', '%s'), $brand['name']),
                Zooboxi_V2_Bootstrap::pick('منتجات أصلية مستوردة مباشرة', 'Original products, imported directly'),
                Zooboxi_V2_Bootstrap::pick('تسوّق الماركة', 'Shop the brand'),
                $brand['link'],
                ['name' => $brand['name'], 'logo' => $brand['logo']]
            );
        }

        // 4) Bestsellers.
        $out[] = $this->auto_slide(
            'bestsellers',
            Zooboxi_V2_Bootstrap::pick('الأكثر مبيعاً', 'Best sellers'),
            Zooboxi_V2_Bootstrap::pick('اختيارات عملائنا الأكثر طلباً', 'What our customers order most'),
            Zooboxi_V2_Bootstrap::pick('تصفّح القائمة', 'Browse the list'),
            $shop,
            null,
            self::thumbs($this->pool_ids('bestsellers', []), 4)
        );

        return $out;
    }

    private function auto_slide(
        string $theme,
        string $title,
        string $subtitle,
        string $cta,
        ?string $link,
        ?array $brand = null,
        array $images = [],
        ?string $badge = null
    ): array {
        return [
            'kind'           => 'auto',
            'theme'          => $theme,
            'title'          => $title,
            'subtitle'       => $subtitle,
            'cta_label'      => $cta,
            'link'           => $link ? esc_url_raw($link) : null,
            'brand'          => $brand,
            'product_images' => array_values($images),
            'badge'          => $badge,
        ];
    }

    /**
     * Peek a shared `zbhome_ids_{key}_{locale}` pool. `$fallback` queries run ONLY when
     * the transient is cold (the home rails normally warm it moments earlier).
     *
     * @return int[]
     */
    private function pool_ids(string $key, array $fallback): array
    {
        $ids = get_transient('zbhome_ids_' . $key . '_' . get_locale());
        if (is_array($ids)) {
            return array_map('intval', $ids);
        }
        foreach ($fallback as $args) {
            $args['fields']        = 'ids';
            $args['no_found_rows'] = true;
            $q   = new WP_Query($args);
            $ids = is_array($q->posts) ? array_map('intval', $q->posts) : [];
            wp_reset_postdata();
            if (!empty($ids)) {
                return $ids;
            }
        }
        return [];
    }

    /** Up to `$limit` product thumbnails, skipping anything without artwork. */
    private static function thumbs(array $ids, int $limit): array
    {
        $out = [];
        foreach ($ids as $id) {
            if (count($out) >= $limit) {
                break;
            }
            $url = wp_get_attachment_image_url(get_post_thumbnail_id((int) $id), 'medium');
            if ($url) {
                $out[] = $url;
            }
        }
        return $out;
    }

    /**
     * Highest-product-count brand that has an uploaded logo — same rule (and the same
     * 6h transient) as the website's hero, so both surfaces feature the same brand.
     *
     * @return array{name:string,logo:string,link:?string}|null
     */
    private function featured_brand(): ?array
    {
        $cached = get_transient('zbhero_featured_brand');
        if (is_array($cached)) {
            return !empty($cached['name']) ? $this->brand_slide_payload($cached) : null;
        }

        $terms = get_terms([
            'taxonomy'   => 'product_brand',
            'hide_empty' => true,
            'orderby'    => 'count',
            'order'      => 'DESC',
            'number'     => 12,
        ]);

        $found = null;
        if (!is_wp_error($terms)) {
            foreach ($terms as $t) {
                $logo_id = (int) get_term_meta($t->term_id, 'thumbnail_id', true);
                if (!$logo_id) {
                    continue;
                }
                $url = wp_get_attachment_image_url($logo_id, 'medium');
                if (!$url) {
                    continue;
                }
                $link  = get_term_link($t);
                $found = [
                    'name' => (string) $t->name,
                    'logo' => (string) $url,
                    'link' => is_string($link) ? $link : '',
                ];
                break;
            }
        }

        set_transient('zbhero_featured_brand', $found ?: [], 6 * HOUR_IN_SECONDS);
        return $found ? $this->brand_slide_payload($found) : null;
    }

    /**
     * Normalise a `zbhero_featured_brand` row (the website writes `link` straight from
     * get_term_link(), which can be a WP_Error — never cast that to a string).
     *
     * @return array{name:string,logo:?string,link:?string}
     */
    private function brand_slide_payload(array $row): array
    {
        $logo = isset($row['logo']) && is_string($row['logo']) ? trim($row['logo']) : '';
        $link = isset($row['link']) && is_string($row['link']) ? trim($row['link']) : '';

        return [
            'name' => (string) ($row['name'] ?? ''),
            'logo' => $logo !== '' ? esc_url_raw($logo) : null,
            'link' => $link !== '' ? esc_url_raw($link) : null,
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       CAMPAIGNS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Live owner-approved campaigns as structured data (the app composes the banner
     * itself, so every creative size ships side by side).
     *
     * Honours the master toggle, self-heals a cold cache the way the website's hero
     * does, and picks the A/B variant deterministically per requester so one device
     * always sees the same arm.
     */
    private function campaigns(): array
    {
        if (get_option('zooboxi_campaigns_enabled', 'no') !== 'yes') {
            return [];
        }

        $cached = get_transient('zooboxi_campaigns_cache');
        // Cold cache (expired / flushed) → pull the live set now, exactly like
        // Zooboxi_Hero_Slider::campaign_slides(), so the app never loses the banners
        // between the hourly sync cron runs.
        if ($cached === false && class_exists('Zooboxi_Campaigns')) {
            $cached = (new Zooboxi_Campaigns())->sync_campaigns();
        }
        if (!is_array($cached) || empty($cached)) {
            return [];
        }

        $identity = $this->requester_identity();
        $now      = current_time('timestamp');
        $out      = [];

        foreach ($cached as $c) {
            if (!is_array($c)) {
                continue;
            }
            if (!empty($c['ends_at']) && strtotime((string) $c['ends_at']) < $now) {
                continue;
            }
            if (!empty($c['starts_at']) && strtotime((string) $c['starts_at']) > $now) {
                continue;
            }

            $campaign_id = (string) ($c['id'] ?? '');
            $variant     = (!empty($c['ab_enabled']) && !empty($c['creatives']['B']))
                ? ((crc32('zbab|' . $campaign_id . '|' . $identity) % 2) ? 'B' : 'A')
                : 'A';

            $creatives = self::creative_set($c, $variant);
            if (empty($creatives)) {
                // Fall back to the other arm before dropping the campaign entirely.
                $variant   = $variant === 'B' ? 'A' : 'B';
                $creatives = self::creative_set($c, $variant);
            }
            if (empty($creatives)) {
                continue;
            }

            $woo_id    = (int) ($c['woo_product_id'] ?? 0);
            $item_code = trim((string) ($c['item_code'] ?? ''));
            $discount  = (int) ($c['discount_pct'] ?? 0);
            $coupon    = trim((string) ($c['coupon_code'] ?? ''));

            $out[] = [
                'campaign_id'   => $campaign_id,
                'ab_variant'    => $variant,
                // Passed through verbatim — Laravel keeps adding placements
                // (`app_hero`, `app_banner`, …) and the app decides what it honours.
                'zones'         => is_array($c['zones'] ?? null) ? array_values(array_map('strval', $c['zones'])) : [],
                'campaign_type' => !empty($c['campaign_type']) ? (string) $c['campaign_type'] : null,
                'headline'      => (string) ($c['headline_ar'] ?? ''),
                'subheadline'   => (string) ($c['subheadline_ar'] ?? ''),
                'cta'           => (string) ($c['cta_ar'] ?? ''),
                'badge'         => (string) ($c['badge_ar'] ?? ''),
                'coupon_code'   => $coupon !== '' ? $coupon : null,
                'discount_pct'  => $discount > 0 ? $discount : null,
                'starts_at'     => !empty($c['starts_at']) ? (string) $c['starts_at'] : null,
                'ends_at'       => !empty($c['ends_at']) ? (string) $c['ends_at'] : null,
                'item_code'     => $item_code !== '' ? $item_code : null,
                'product_id'    => $woo_id ?: null,
                'link'          => $woo_id ? (get_permalink($woo_id) ?: null) : null,
                'creatives'     => $creatives,
            ];
        }
        return $out;
    }

    /**
     * The non-empty creative URLs of one A/B arm, keyed by placement.
     *
     * @return array<string,string>
     */
    private static function creative_set(array $campaign, string $variant): array
    {
        $set = $campaign['creatives'][$variant] ?? null;
        if (!is_array($set)) {
            return [];
        }
        $out = [];
        foreach (['hero', 'wide', 'card', 'strip', 'app_hero'] as $slot) {
            $url = isset($set[$slot]) ? trim((string) $set[$slot]) : '';
            if ($url !== '') {
                $out[$slot] = esc_url_raw($url);
            }
        }
        return $out;
    }

    /**
     * A stable identity for A/B bucketing: the signed-in user, else the device's
     * X-ZB-Guest id, else 'anon' (everyone unidentified shares arm A's bucket rules).
     */
    private function requester_identity(): string
    {
        $uid = get_current_user_id();
        if ($uid > 0) {
            return 'u' . $uid;
        }
        $guest = Zooboxi_V2_Bootstrap::guest_id();
        return $guest !== '' ? 'g' . $guest : 'anon';
    }

    /**
     * "تسوّق حسب أليفك" — the SAME four curated pets the website's homepage
     * hardcodes (Zooboxi_Homepage::animal_nav), with their uploaded artwork.
     * Resolved to live terms by name so ids/slugs always match this store.
     */
    private function animal_nav(): array
    {
        // MAIN-tree root ids (the store also keeps a parallel "health criteria"
        // tree whose roots carry the same names — a name lookup lands there and
        // returns condition tags instead of the shopping subcategories).
        $curated = [
            [107, 'قطط', '/wp-content/uploads/zooboxi-assets/97125602-5f94-42eb-96da-186b483e1289.webp', '🐱'],
            [114, 'كلاب', '/wp-content/uploads/zooboxi-assets/2f1e50b9-1fbf-4dcb-aa2b-14ebe0cec716.webp', '🐶'],
            [202, 'طيور', '/wp-content/uploads/zooboxi-assets/307a4def-f718-4d79-ba2e-925454fa8faa.webp', '🦜'],
            [194, 'حيوانات صغيرة', '/wp-content/uploads/zooboxi-assets/30a11991-15ae-4b19-9f1c-56d6994424a4.webp', '🐹'],
        ];

        $out = [];
        foreach ($curated as [$id, $name, $image, $emoji]) {
            $term = get_term($id, 'product_cat');
            if (!$term || is_wp_error($term)) {
                continue;
            }
            $out[] = [
                'id'    => (int) $term->term_id,
                'slug'  => (string) $term->slug,
                'name'  => $name,
                'image' => home_url($image),
                'icon'  => $emoji,
            ];
        }
        return $out;
    }

    /**
     * One home rail. Shares the website's `zbhome_ids_{key}_{locale}` id transients so
     * both surfaces show the same products for the same hour.
     *
     * The transient stores the RAW pool (24 ids). Dedup happens per request, after the
     * cache read: `$used` accumulates every id already emitted this response, so a
     * bestseller that is also trending appears exactly once across the home rails.
     *
     * @param int[] $used Ids already shown — read and extended in place.
     */
    private function rail(string $key, string $title, array $queries, array &$used): ?array
    {
        $tkey = 'zbhome_ids_' . $key . '_' . get_locale();
        $ids  = get_transient($tkey);

        if ($ids === false) {
            $ids = [];
            foreach ($queries as $args) {
                $args['fields']        = 'ids';
                $args['no_found_rows'] = true;
                $q   = new WP_Query($args);
                $ids = is_array($q->posts) ? array_map('intval', $q->posts) : [];
                wp_reset_postdata();
                if (!empty($ids)) {
                    break;
                }
            }
            // Cache the raw pool — never the deduped slice, which is request-specific.
            set_transient($tkey, $ids, HOUR_IN_SECONDS);
        }

        $ids = array_map('intval', is_array($ids) ? $ids : []);
        if (!empty($used)) {
            $ids = array_values(array_diff($ids, $used));
        }
        $ids = array_slice($ids, 0, self::RAIL_SIZE);
        if (empty($ids)) {
            return null;
        }
        $used = array_merge($used, $ids);

        return [
            'key'      => $key,
            'title'    => $title,
            'products' => Zooboxi_Product_DTO::cards($ids),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       GET /catalog/categories
       ══════════════════════════════════════════════════════════════ */

    public function categories(\WP_REST_Request $request): \WP_REST_Response
    {
        $parent = $request->get_param('parent');
        $parent = $parent === null ? 0 : absint($parent);

        // The taxonomy's top level mixes the real shopping tree with ~80
        // brand-mirror terms. The store browses BY PET — so the root of the
        // app's tree is the same four animals the website navigates, each with
        // its true subtree; the brand terms live on the brands surface instead.
        if ($parent === 0) {
            $out = [];
            foreach ($this->animal_nav() as $animal) {
                if (empty($animal['id'])) {
                    continue;
                }
                $term = get_term((int) $animal['id'], 'product_cat');
                if (!$term || is_wp_error($term)) {
                    continue;
                }
                $dto          = $this->term_dto($term, true);
                $dto['image'] = $animal['image'] ?: $dto['image'];
                $dto['icon']  = $dto['icon'] !== '' ? $dto['icon'] : (string) $animal['icon'];
                $out[]        = $dto;
            }

            return Zooboxi_V2_Bootstrap::ok([
                'parent'     => 0,
                'categories' => $out,
            ], Zooboxi_V2_Bootstrap::TTL_CATEGORIES);
        }

        $terms = get_terms([
            'taxonomy'   => 'product_cat',
            'parent'     => $parent,
            'hide_empty' => true,
            'orderby'    => 'name',
            'order'      => 'ASC',
        ]);
        if (is_wp_error($terms)) {
            $terms = [];
        }

        $out = [];
        foreach ($terms as $t) {
            if ($t->slug === 'uncategorized') {
                continue;
            }
            $out[] = $this->term_dto($t, true);
        }

        return Zooboxi_V2_Bootstrap::ok([
            'parent'     => $parent,
            'categories' => $out,
        ], Zooboxi_V2_Bootstrap::TTL_CATEGORIES);
    }

    /** @param \WP_Term $term */
    private function term_dto($term, bool $with_children): array
    {
        $id  = Zooboxi_V2_Bootstrap::map_term((int) $term->term_id);
        $t   = $term;
        if ($id !== (int) $term->term_id) {
            $translated = get_term($id, 'product_cat');
            if ($translated instanceof WP_Term) {
                $t = $translated;
            }
        }
        $img = null;

        $thumb = (int) get_term_meta((int) $t->term_id, 'thumbnail_id', true);
        if ($thumb) {
            $img = wp_get_attachment_image_url($thumb, 'woocommerce_thumbnail') ?: null;
        }

        // The website's curated iconography (theme map) — it returns image URLs
        // for the categories it knows. Terms rarely carry WP thumbnails, so the
        // map is the primary art source; anything non-URL would be an emoji.
        $icon_art = function_exists('zooboxi_get_category_icon')
            ? (string) zooboxi_get_category_icon($t)
            : '';
        $emoji = '';
        if ($icon_art !== '' && !preg_match('#^https?://#', $icon_art)) {
            $emoji    = $icon_art;
            $icon_art = '';
        }

        $dto = [
            'id'       => (int) $t->term_id,
            'slug'     => (string) $t->slug,
            'name'     => (string) $t->name,
            'image'    => $img ?: ($icon_art !== '' ? esc_url_raw($icon_art) : null),
            'icon'     => $emoji,
            'count'    => (int) $t->count,
            'children' => [],
        ];

        if ($with_children) {
            $kids = get_terms([
                'taxonomy'   => 'product_cat',
                'parent'     => (int) $t->term_id,
                'hide_empty' => true,
                'orderby'    => 'name',
                'order'      => 'ASC',
            ]);
            if (!is_wp_error($kids)) {
                foreach ($kids as $k) {
                    $dto['children'][] = $this->term_dto($k, false);
                }
            }
        }

        return $dto;
    }

    /* ══════════════════════════════════════════════════════════════
       GET /catalog/products  (listing + facets + sort parity)
       ══════════════════════════════════════════════════════════════ */

    public function products(\WP_REST_Request $request): \WP_REST_Response
    {
        $page     = max(1, (int) $request->get_param('page'));
        $per_page = (int) $request->get_param('per_page');
        $per_page = $per_page > 0 ? min(self::PER_PAGE_MAX, $per_page) : self::PER_PAGE_DEFAULT;
        $raw_sort = sanitize_text_field((string) $request->get_param('orderby'));
        $orderby  = $raw_sort !== '' ? $raw_sort : 'recommended';
        $search   = sanitize_text_field((string) $request->get_param('q'));
        $sku      = sanitize_text_field((string) $request->get_param('sku'));

        // `?rail=` reproduces a home rail as a full, paginated listing — the app's
        // "عرض الكل" keeps the rail's filter instead of falling back to the catalogue.
        $rail      = sanitize_key((string) $request->get_param('rail'));
        $rail_args = self::rail_listing_args($rail, $per_page);
        if (empty($rail_args)) {
            $rail = '';
        }

        $category = $this->resolve_category($request->get_param('category'));

        $tax_query  = ['relation' => 'AND'];
        $meta_query = ['relation' => 'AND'];

        // Never surface catalog-hidden products.
        $tax_query[] = [
            'taxonomy' => 'product_visibility',
            'field'    => 'name',
            'terms'    => 'exclude-from-catalog',
            'operator' => 'NOT IN',
        ];

        if ($category) {
            $tax_query[] = [
                'taxonomy'         => 'product_cat',
                'field'            => 'term_id',
                'terms'            => (int) $category->term_id,
                'include_children' => true,
            ];
        }

        $brand = sanitize_title((string) $request->get_param('brand'));
        if ($brand !== '') {
            $tax_query[] = [
                'taxonomy' => taxonomy_exists('product_brand') ? 'product_brand' : 'pa_brand',
                'field'    => 'slug',
                'terms'    => [$brand],
            ];
        }

        // The 11 faceted attributes, each a comma-separated slug list.
        foreach (self::FACET_TAXONOMIES as $taxonomy) {
            $param = str_replace('-', '_', $taxonomy); // pa_food-type → pa_food_type
            $raw   = (string) ($request->get_param($param) ?: $request->get_param($taxonomy));
            if ($raw === '') {
                continue;
            }
            $slugs = array_values(array_filter(array_map('sanitize_title', explode(',', $raw))));
            if (empty($slugs) || !taxonomy_exists($taxonomy)) {
                continue;
            }
            $tax_query[] = [
                'taxonomy' => $taxonomy,
                'field'    => 'slug',
                'terms'    => $slugs,
                'operator' => 'IN',
            ];
        }

        $min_price = $request->get_param('min_price');
        $max_price = $request->get_param('max_price');
        if ($min_price !== null && $min_price !== '') {
            $meta_query[] = ['key' => '_price', 'value' => (float) $min_price, 'compare' => '>=', 'type' => 'DECIMAL(20,4)'];
        }
        if ($max_price !== null && $max_price !== '') {
            $meta_query[] = ['key' => '_price', 'value' => (float) $max_price, 'compare' => '<=', 'type' => 'DECIMAL(20,4)'];
        }

        if ($sku !== '') {
            $meta_query[] = [
                'relation' => 'OR',
                ['key' => '_sku', 'value' => $sku],
                ['key' => '_zooboxi_item_code', 'value' => $sku],
            ];
        }

        // The rail's own meta conditions ride in as ONE nested group, so its internal
        // relation (bestsellers is an OR pair) survives the merge with the facets.
        if (!empty($rail_args['meta_query'])) {
            $meta_query[] = $rail_args['meta_query'];
        }

        $args = [
            'post_type'           => 'product',
            'post_status'         => 'publish',
            'posts_per_page'      => $per_page,
            'paged'               => $page,
            'ignore_sticky_posts' => true,
            // A listing must count: Zooboxi_Product_Rail::base() opts out, and the rail
            // args are merged in below.
            'no_found_rows'       => false,
            'tax_query'           => $tax_query,
            // The flag both posts_clauses filters look for (web queries never set it).
            'zooboxi_v2_listing'  => 1,
        ];

        if (count($meta_query) > 1) {
            $args['meta_query'] = $meta_query;
        }
        if ($search !== '') {
            $args['s'] = $search;
        }

        $args = array_merge($args, $this->orderby_args($orderby));

        // An explicit ?orderby wins; otherwise the rail's own ranking defines the page.
        if ($rail !== '' && $raw_sort === '' && !empty($rail_args['orderby'])) {
            unset($args['meta_key']);
            $args = array_merge($args, $rail_args['orderby']);
        }

        $plugin       = class_exists('Zooboxi_Plugin') ? Zooboxi_Plugin::instance() : null;
        $added_sort   = false;
        $added_search = false;

        // Belt-and-braces: the two ordering filters are registered on the frontend (REST
        // counts as frontend), but re-add ours if a future refactor moves them.
        if ($plugin && !has_filter('posts_clauses', [$plugin, 'sort_products_by_stock'])) {
            add_filter('posts_clauses', [$plugin, 'sort_products_by_stock'], 999, 2);
            $added_sort = true;
        }
        if ($search !== '') {
            add_filter('posts_search', [$this, 'inject_identifier_search'], 10, 2);
            $added_search = true;
        }

        $query = new WP_Query($args);

        if ($added_sort && $plugin) {
            remove_filter('posts_clauses', [$plugin, 'sort_products_by_stock'], 999);
        }
        if ($added_search) {
            remove_filter('posts_search', [$this, 'inject_identifier_search'], 10);
        }

        $cards = self::cards_from_query($query);
        wp_reset_postdata();

        return Zooboxi_V2_Bootstrap::ok([
            'products'      => $cards,
            'total'         => (int) $query->found_posts,
            'pages'         => (int) $query->max_num_pages,
            'page'          => $page,
            'per_page'      => $per_page,
            'orderby'       => $orderby,
            'rail'          => $rail !== '' ? $rail : null,
            'facets'        => $this->facets($category),
            'sort_options'  => self::sort_options(),
            'lang_fallback' => Zooboxi_V2_Bootstrap::lang_fallback(),
        ], Zooboxi_V2_Bootstrap::TTL_LISTING);
    }

    /**
     * The meta conditions + ranking of a home rail, reshaped for a paginated listing.
     * Everything else in the rail args (post_type, the visibility tax_query, the
     * no_found_rows opt-out, its own posts_per_page) is deliberately dropped — the
     * listing already sets those, and a listing must count its rows.
     *
     * @return array{meta_query?:array,orderby?:array} Empty for an unknown rail key.
     */
    private static function rail_listing_args(string $rail, int $per_page): array
    {
        $builder = self::RAIL_QUERIES[$rail] ?? null;
        if ($builder === null || !method_exists('Zooboxi_Product_Rail', $builder)) {
            return [];
        }

        $source = call_user_func(['Zooboxi_Product_Rail', $builder], $per_page);
        if (!is_array($source)) {
            return [];
        }
        $out = [];

        if (!empty($source['meta_query']) && is_array($source['meta_query'])) {
            $out['meta_query'] = $source['meta_query'];
        }

        $orderby = [];
        if (!empty($source['meta_key'])) {
            $orderby['meta_key'] = (string) $source['meta_key'];
        }
        if (!empty($source['orderby'])) {
            $orderby['orderby'] = $source['orderby'];
        }
        if (!empty($source['order'])) {
            $orderby['order'] = (string) $source['order'];
        }
        if (!empty($orderby)) {
            $out['orderby'] = $orderby;
        }

        return $out;
    }

    /**
     * Same trick as Zooboxi_Sku_Search, scoped to our listing query: OR "matches this
     * barcode / SAP item code" into the title search so a code lookup finds the product.
     *
     * @param string    $search
     * @param \WP_Query $query
     */
    public function inject_identifier_search($search, $query): string
    {
        if (!is_string($search) || $search === '' || !($query instanceof \WP_Query)) {
            return (string) $search;
        }
        if (!$query->get('zooboxi_v2_listing')) {
            return $search;
        }

        global $wpdb;

        $term = trim((string) $query->get('s'));
        if ($term === '') {
            return $search;
        }

        $ids = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT post_id FROM {$wpdb->postmeta}
             WHERE meta_key IN ('_sku', '_zooboxi_item_code') AND meta_value LIKE %s",
            '%' . $wpdb->esc_like($term) . '%'
        ));
        if (empty($ids)) {
            return $search;
        }

        $idList   = implode(',', array_map('absint', $ids));
        $idClause = "{$wpdb->posts}.ID IN ({$idList})";

        return (string) preg_replace('/ AND \(/', " AND ( {$idClause} OR ", $search, 1);
    }

    /**
     * Serialize a finished product query, applying the SAME final pass the website does:
     * SQL can only sink globally-out-of-stock rows, so a stable PHP partition moves
     * anything unavailable AT THIS CUSTOMER'S LOCATION to the end of the page
     * (mirrors the theme's `the_posts` re-sort, which is main-query-only).
     */
    private static function cards_from_query(WP_Query $query): array
    {
        $posts = is_array($query->posts) ? $query->posts : [];
        if (empty($posts)) {
            return [];
        }

        $ids = [];
        foreach ($posts as $post) {
            $ids[] = is_object($post) ? (int) $post->ID : (int) $post;
        }

        $available = [];
        $sold_out  = [];
        foreach ($ids as $id) {
            $product = wc_get_product($id);
            if (!$product) {
                continue;
            }
            if ($product->is_in_stock()) {
                $available[] = $product;
            } else {
                $sold_out[] = $product;
            }
        }

        return Zooboxi_Product_DTO::cards(array_merge($available, $sold_out));
    }

    private function orderby_args(string $orderby): array
    {
        switch ($orderby) {
            case 'price':
                return ['meta_key' => '_price', 'orderby' => 'meta_value_num', 'order' => 'ASC'];
            case 'price-desc':
                return ['meta_key' => '_price', 'orderby' => 'meta_value_num', 'order' => 'DESC'];
            case 'date':
                return ['orderby' => 'date', 'order' => 'DESC'];
            case 'popularity':
                return ['meta_key' => 'total_sales', 'orderby' => 'meta_value_num', 'order' => 'DESC'];
            case 'recommended':
            default:
                // Identical to the website's "موصى به" sort.
                return ['meta_key' => '_zb_rank_score', 'orderby' => 'meta_value_num', 'order' => 'DESC'];
        }
    }

    public static function sort_options(): array
    {
        return [
            ['key' => 'recommended', 'label' => __('موصى به', 'zooboxi')],
            ['key' => 'date',        'label' => __('الأحدث', 'zooboxi')],
            ['key' => 'popularity',  'label' => __('الأكثر مبيعاً', 'zooboxi')],
            ['key' => 'price',       'label' => __('من الأقل إلى الأعلى', 'zooboxi')],
            ['key' => 'price-desc',  'label' => __('من الأعلى إلى الأقل', 'zooboxi')],
        ];
    }

    /** @param \WP_Term|null $category */
    private function facets($category): array
    {
        $taxonomies = $this->relevant_filters($category ? (int) $category->term_id : 0);
        $labels     = $this->filter_labels();

        $groups = [];
        foreach ($taxonomies as $taxonomy) {
            if (!taxonomy_exists($taxonomy)) {
                continue;
            }
            $terms = get_terms([
                'taxonomy'   => $taxonomy,
                'hide_empty' => true,
                'orderby'    => 'count',
                'order'      => 'DESC',
                'number'     => 30,
            ]);
            if (is_wp_error($terms) || empty($terms)) {
                continue;
            }
            $list = [];
            foreach ($terms as $t) {
                $list[] = ['slug' => (string) $t->slug, 'name' => (string) $t->name, 'count' => (int) $t->count];
            }
            $groups[] = [
                'taxonomy' => $taxonomy,
                'label'    => (string) ($labels[$taxonomy] ?? $taxonomy),
                'terms'    => $list,
            ];
        }

        return ['groups' => $groups, 'price' => $this->price_bounds()];
    }

    /**
     * The website's per-category filter picker. The theme function is loaded in the REST
     * context too; the fallback keeps the endpoint honest if the theme ever changes.
     */
    private function relevant_filters(int $cat_id): array
    {
        if ($cat_id && function_exists('zooboxi_get_relevant_filters')) {
            $filters = zooboxi_get_relevant_filters($cat_id);
            if (is_array($filters) && !empty($filters)) {
                return array_values(array_unique($filters));
            }
        }
        return ['pa_brand', 'pa_age', 'pa_food-type'];
    }

    private function filter_labels(): array
    {
        if (function_exists('zooboxi_get_filter_labels')) {
            $labels = zooboxi_get_filter_labels();
            if (is_array($labels)) {
                return $labels;
            }
        }
        return [
            'pa_brand'        => __('العلامة التجارية', 'zooboxi'),
            'pa_age'          => __('المرحلة العمرية', 'zooboxi'),
            'pa_flavor'       => __('النكهة', 'zooboxi'),
            'pa_food-type'    => __('شكل الطعام', 'zooboxi'),
            'pa_health'       => __('ميزة صحية', 'zooboxi'),
            'pa_litter-type'  => __('نوع الرمل', 'zooboxi'),
            'pa_color'        => __('اللون', 'zooboxi'),
            'pa_material'     => __('المادة', 'zooboxi'),
            'pa_product-type' => __('نوع المنتج', 'zooboxi'),
            'pa_size-opt'     => __('الحجم', 'zooboxi'),
            'pa_weight-opt'   => __('الوزن', 'zooboxi'),
        ];
    }

    /** Catalogue-wide price bounds (matches the website's slider), cached for an hour. */
    private function price_bounds(): array
    {
        $cached = get_transient('zb_v2_price_bounds');
        if (is_array($cached)) {
            return $cached;
        }

        global $wpdb;
        $row = $wpdb->get_row(
            "SELECT MIN(CAST(pm.meta_value AS DECIMAL(20,4))) AS min_price,
                    MAX(CAST(pm.meta_value AS DECIMAL(20,4))) AS max_price
             FROM {$wpdb->postmeta} pm
             JOIN {$wpdb->posts} p ON pm.post_id = p.ID
             WHERE pm.meta_key = '_price' AND p.post_type = 'product'
               AND p.post_status = 'publish' AND pm.meta_value > 0"
        );

        $bounds = [
            'min' => $row ? (float) floor((float) $row->min_price) : 0.0,
            'max' => $row ? (float) ceil((float) $row->max_price) : 1000.0,
        ];
        set_transient('zb_v2_price_bounds', $bounds, HOUR_IN_SECONDS);
        return $bounds;
    }

    /** @return \WP_Term|null */
    private function resolve_category($raw)
    {
        if ($raw === null || $raw === '') {
            return null;
        }
        if (ctype_digit((string) $raw)) {
            $term = get_term(absint($raw), 'product_cat');
            return ($term && !is_wp_error($term)) ? $term : null;
        }

        // Arabic slugs live percent-encoded in the DB while clients send them
        // readable (or vice versa) — try every honest spelling, then the name.
        $value = trim((string) $raw);
        foreach (array_unique([
            $value,
            sanitize_title($value),
            rawurldecode($value),
            sanitize_title(rawurldecode($value)),
        ]) as $candidate) {
            if ($candidate === '') {
                continue;
            }
            $term = get_term_by('slug', $candidate, 'product_cat');
            if ($term && !is_wp_error($term)) {
                return $term;
            }
        }
        $term = get_term_by('name', rawurldecode($value), 'product_cat');
        return ($term && !is_wp_error($term)) ? $term : null;
    }

    /* ══════════════════════════════════════════════════════════════
       GET /catalog/products/{id}
       ══════════════════════════════════════════════════════════════ */

    public function product(\WP_REST_Request $request): \WP_REST_Response
    {
        $id  = absint($request->get_param('id'));
        // A chosen pack variation (كرتون = N حبة) changes what the promise and
        // the per-warehouse counts MEAN — the app re-asks with the selection.
        $pdp = Zooboxi_Product_DTO::pdp($id, absint($request->get_param('variation_id')));

        if ($pdp === null) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('المنتج غير موجود', 'zooboxi'), 'Product not found.', 404);
        }
        return Zooboxi_V2_Bootstrap::ok($pdp, Zooboxi_V2_Bootstrap::TTL_PDP);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /catalog/search/suggest
       ══════════════════════════════════════════════════════════════ */

    public function suggest(\WP_REST_Request $request): \WP_REST_Response
    {
        $q = trim(sanitize_text_field((string) $request->get_param('q')));
        if (mb_strlen($q) < 2) {
            return Zooboxi_V2_Bootstrap::ok(['suggestions' => []]);
        }

        global $wpdb;

        $like   = '%' . $wpdb->esc_like($q) . '%';
        $prefix = $wpdb->esc_like($q) . '%';

        // Title contains, OR barcode / SAP code starts with — the same identifiers
        // Zooboxi_Sku_Search folds into the storefront search.
        $ids = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT p.ID
             FROM {$wpdb->posts} p
             LEFT JOIN {$wpdb->postmeta} m
                    ON m.post_id = p.ID AND m.meta_key IN ('_sku', '_zooboxi_item_code')
             WHERE p.post_type = 'product' AND p.post_status = 'publish'
               AND (p.post_title LIKE %s OR m.meta_value LIKE %s)
             LIMIT 8",
            $like,
            $prefix
        ));

        $out = [];
        foreach (array_map('intval', (array) $ids) as $id) {
            $product = wc_get_product($id);
            if (!$product) {
                continue;
            }
            $price = $product->get_price();
            $out[] = [
                'id'        => $id,
                'name'      => wp_strip_all_tags($product->get_name()),
                'image'     => Zooboxi_Product_DTO::image_url($product, 'woocommerce_thumbnail'),
                'sku'       => (string) $product->get_sku(),
                'item_code' => (string) get_post_meta($id, '_zooboxi_item_code', true),
                'price'     => ($price === '' || $price === null) ? null : (float) $price,
            ];
        }

        return Zooboxi_V2_Bootstrap::ok(['suggestions' => $out], Zooboxi_V2_Bootstrap::TTL_LISTING);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /catalog/barcode/{code}
       ══════════════════════════════════════════════════════════════ */

    public function barcode(\WP_REST_Request $request): \WP_REST_Response
    {
        $code = sanitize_text_field((string) $request->get_param('code'));
        if ($code === '') {
            return Zooboxi_V2_Bootstrap::fail('code_required', __('امسح باركود صالح', 'zooboxi'), 'A barcode is required.', 422);
        }

        global $wpdb;
        $id = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT pm.post_id FROM {$wpdb->postmeta} pm
             JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key IN ('_sku', '_zooboxi_item_code') AND pm.meta_value = %s
               AND p.post_status = 'publish' AND p.post_type IN ('product','product_variation')
             LIMIT 1",
            $code
        ));

        if (!$id) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('لم نجد منتجاً بهذا الباركود', 'zooboxi'), 'No product matches that barcode.', 404);
        }

        // A variation resolves to its parent card (that is the shoppable page).
        $product = wc_get_product($id);
        if ($product instanceof \WC_Product_Variation) {
            $product = wc_get_product($product->get_parent_id());
        }

        $card = $product ? Zooboxi_Product_DTO::card($product) : null;
        if ($card === null) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('لم نجد منتجاً بهذا الباركود', 'zooboxi'), 'No product matches that barcode.', 404);
        }

        return Zooboxi_V2_Bootstrap::ok(['product' => $card]);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /brands  ·  GET /brands/{slug}
       ══════════════════════════════════════════════════════════════ */

    public function brands(\WP_REST_Request $request): \WP_REST_Response
    {
        return Zooboxi_V2_Bootstrap::ok(['brands' => $this->brand_list(0)], Zooboxi_V2_Bootstrap::TTL_CATEGORIES);
    }

    /** Published brands (boutique payload) intersected with the store's brand terms. */
    private function brand_list(int $limit): array
    {
        $terms = get_terms([
            'taxonomy'   => 'product_brand',
            'hide_empty' => true,
            'orderby'    => 'count',
            'order'      => 'DESC',
            'number'     => $limit > 0 ? $limit : 0,
        ]);
        if (is_wp_error($terms) || empty($terms)) {
            return [];
        }

        $published = class_exists('Zooboxi_Brand_Sync') ? Zooboxi_Brand_Sync::all() : [];

        $out = [];
        foreach ($terms as $t) {
            $code    = preg_match('/(\d+)/', (string) $t->description, $m) ? $m[1] : '';
            $payload = ($code !== '' && isset($published[$code]) && is_array($published[$code])) ? $published[$code] : null;

            // Same source the website's brand slider renders: the term's own
            // thumbnail. The boutique payload's logo_url (often unset) only wins
            // when it actually exists.
            $logo = !empty($payload['logo_url']) ? esc_url_raw((string) $payload['logo_url']) : null;
            if ($logo === null) {
                $thumb = (int) get_term_meta((int) $t->term_id, 'thumbnail_id', true);
                if ($thumb) {
                    $logo = wp_get_attachment_image_url($thumb, 'medium') ?: null;
                }
            }

            $out[] = [
                'code'      => $code,
                'slug'      => (string) $t->slug,
                'name'      => $payload['name'] ?? (string) $t->name,
                'logo'      => $logo,
                'count'     => (int) $t->count,
                'boutique'  => $payload !== null,
            ];
        }
        return $out;
    }

    public function brand(\WP_REST_Request $request): \WP_REST_Response
    {
        $slug = sanitize_title((string) $request->get_param('slug'));
        $term = $slug !== '' ? get_term_by('slug', $slug, 'product_brand') : null;

        if (!$term || is_wp_error($term)) {
            return Zooboxi_V2_Bootstrap::fail('brand_not_found', __('العلامة غير موجودة', 'zooboxi'), 'Brand not found.', 404);
        }

        $code    = preg_match('/(\d+)/', (string) $term->description, $m) ? $m[1] : '';
        $payload = ($code !== '' && class_exists('Zooboxi_Brand_Sync')) ? Zooboxi_Brand_Sync::get($code) : null;
        $kit     = (is_array($payload) && isset($payload['kit']) && is_array($payload['kit'])) ? $payload['kit'] : [];

        $tiles = [];
        if (is_array($payload) && !empty($payload['tiles']) && is_array($payload['tiles'])) {
            foreach ($payload['tiles'] as $tile) {
                if (!is_array($tile) || empty($tile['url'])) {
                    continue;
                }
                $tiles[] = [
                    'image'    => esc_url_raw((string) $tile['url']),
                    'headline' => (string) ($tile['headline_ar'] ?? ''),
                ];
            }
        }

        // Curated picks: brand-scoped bestsellers, exactly like the boutique rail.
        $curated = [];
        foreach ([Zooboxi_Product_Rail::q_bestsellers(12), Zooboxi_Product_Rail::q_top_ranked(12), Zooboxi_Product_Rail::q_newest(12)] as $args) {
            $args['fields']     = 'ids';
            $args['tax_query'][] = ['taxonomy' => 'product_brand', 'field' => 'slug', 'terms' => [$term->slug]];
            $q   = new WP_Query($args);
            $ids = is_array($q->posts) ? array_map('intval', $q->posts) : [];
            wp_reset_postdata();
            if (!empty($ids)) {
                $curated = Zooboxi_Product_DTO::cards($ids);
                break;
            }
        }

        return Zooboxi_V2_Bootstrap::ok([
            'code'     => $code,
            'slug'     => (string) $term->slug,
            'name'     => is_array($payload) ? (string) ($payload['name'] ?? $term->name) : (string) $term->name,
            'boutique' => is_array($payload),
            'hero'     => is_array($payload) && !empty($payload['hero_url']) ? esc_url_raw((string) $payload['hero_url']) : null,
            'logo'     => $this->brand_logo($payload, $term),
            'kit'      => [
                'accent'      => $this->safe_color((string) ($kit['accent'] ?? '')),
                'accent_dark' => $this->safe_color((string) ($kit['accent_dark'] ?? '')),
                'gold'        => $this->safe_color((string) ($kit['gold'] ?? '')),
                'tagline'     => (string) ($kit['tagline_ar'] ?? ''),
            ],
            'story'    => [
                'lead'    => (string) ($kit['audience_ar'] ?? ''),
                'country' => (string) ($kit['country'] ?? ''),
                'founded' => (string) ($kit['founded'] ?? ''),
                'mood'    => (string) ($kit['mood_ar'] ?? ''),
            ],
            'tiles'         => $tiles,
            'products'      => $curated,
            // What the boutique's own shelf filter is built from.
            'categories'    => $this->brand_categories($term),
            'product_count' => max(0, (int) $term->count),
        ], Zooboxi_V2_Bootstrap::TTL_LISTING);
    }

    /** Boutique logo when the sync has one, else the brand term's own thumbnail. */
    private function brand_logo(?array $payload, \WP_Term $term): ?string
    {
        if (is_array($payload) && !empty($payload['logo_url'])) {
            return esc_url_raw((string) $payload['logo_url']);
        }
        $thumb = (int) get_term_meta($term->term_id, 'thumbnail_id', true);
        $url   = $thumb ? wp_get_attachment_image_url($thumb, 'medium') : null;
        return $url ? esc_url_raw($url) : null;
    }

    /**
     * The categories this brand actually sells in, busiest first — the chips a
     * boutique page filters its shelf with. Cached per brand per locale.
     *
     * The raw term list is polluted three ways and each gets a rule:
     *   • the brands-container tree ("العلامات التجارية" and the brand's own
     *     category twin) — dropped by ancestry;
     *   • terms that cover ~everything the brand sells — a filter that doesn't
     *     filter is dropped (≥95% of the shelf);
     *   • Polylang twins and the parallel health/main trees sharing one name —
     *     deduped by display name, biggest count kept.
     *
     * @return array<int,array{id:int,slug:string,name:string,count:int}>
     */
    private function brand_categories(\WP_Term $brand): array
    {
        // Keyed by the REQUEST language (get_locale() here is the site base
        // locale regardless of ?lang, which would cross-contaminate ar/en).
        $tkey   = 'zb_v2_brandcats_' . $brand->slug . '_' . Zooboxi_V2_Bootstrap::lang();
        $cached = get_transient($tkey);
        if (is_array($cached)) {
            return $cached;
        }

        $ids = get_posts([
            'post_type'      => 'product',
            'post_status'    => 'publish',
            'posts_per_page' => 500,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'tax_query'      => [[
                'taxonomy' => 'product_brand',
                'field'    => 'slug',
                'terms'    => [$brand->slug],
            ]],
        ]);
        $total = count($ids);

        // The "brands as categories" container roots, in both languages.
        $container_roots = [];
        foreach (['العلامات التجارية', 'Brands', 'brands'] as $root_name) {
            $root = get_term_by('name', $root_name, 'product_cat');
            if ($root instanceof \WP_Term) {
                $container_roots[] = (int) $root->term_id;
            }
        }

        $counts = [];
        $names  = [];
        if (!empty($ids)) {
            $terms = wp_get_object_terms($ids, 'product_cat', ['fields' => 'all_with_object_id']);
            if (!is_wp_error($terms)) {
                foreach ($terms as $t) {
                    if ($t->slug === 'uncategorized') {
                        continue;
                    }
                    if (!isset($counts[$t->term_id])) {
                        $chain = array_map('intval', get_ancestors($t->term_id, 'product_cat'));
                        $chain[] = (int) $t->term_id;
                        if (array_intersect($chain, $container_roots)) {
                            $counts[$t->term_id] = -1; // marked excluded
                            continue;
                        }
                    }
                    if (($counts[$t->term_id] ?? 0) < 0) {
                        continue;
                    }
                    $counts[$t->term_id] = ($counts[$t->term_id] ?? 0) + 1;
                    $names[$t->term_id]  = $t;
                }
            }
        }

        $counts = array_filter(
            $counts,
            static fn ($n) => $n >= 2 && ($total < 4 || $n < (int) ceil($total * 0.95))
        );
        arsort($counts);

        $out  = [];
        $seen = [];
        foreach ($counts as $tid => $n) {
            // map_term() returns the translated term ID under ?lang=en.
            $mapped_id = Zooboxi_V2_Bootstrap::map_term((int) $tid);
            $name      = $names[$tid]->name;
            if ($mapped_id !== (int) $tid) {
                $translated = get_term($mapped_id, 'product_cat');
                if ($translated instanceof \WP_Term) {
                    $name = $translated->name;
                }
            }
            $key = mb_strtolower(trim((string) $name));
            if ($key === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $out[]      = [
                'id'    => (int) $tid,
                'slug'  => (string) $names[$tid]->slug,
                'name'  => (string) $name,
                'count' => (int) $n,
            ];
            if (count($out) >= 8) {
                break;
            }
        }

        set_transient($tkey, $out, HOUR_IN_SECONDS);
        return $out;
    }

    private function safe_color(string $value): ?string
    {
        $value = trim($value);
        return preg_match('/^#[0-9A-Fa-f]{3,8}$/', $value) ? $value : null;
    }

    /* ══════════════════════════════════════════════════════════════
       GET /clearance
       ══════════════════════════════════════════════════════════════ */

    public function clearance(\WP_REST_Request $request): \WP_REST_Response
    {
        $page     = max(1, (int) $request->get_param('page'));
        $per_page = (int) $request->get_param('per_page');
        $per_page = $per_page > 0 ? min(self::PER_PAGE_MAX, $per_page) : self::PER_PAGE_DEFAULT;

        $args = Zooboxi_Product_Rail::q_clearance($per_page);
        // The rail helper opts out of counting; a paginated screen needs the totals.
        $args['no_found_rows'] = false;
        $args['paged']         = $page;
        $args['posts_per_page'] = $per_page;

        $query = new WP_Query($args);
        $cards = self::cards_from_query($query);
        wp_reset_postdata();

        return Zooboxi_V2_Bootstrap::ok([
            'products' => $cards,
            'total'    => (int) $query->found_posts,
            'pages'    => (int) $query->max_num_pages,
            'page'     => $page,
            'per_page' => $per_page,
        ], Zooboxi_V2_Bootstrap::TTL_LISTING);
    }
}
