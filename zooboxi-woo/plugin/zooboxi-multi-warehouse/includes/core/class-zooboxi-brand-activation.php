<?php

/**
 * Zooboxi_Brand_Activation — the brands, everywhere the customer decides.
 *
 * The owner's pick (2026-09-24, «تفعيل البراندات» A + C): a brand is not a
 * page you have to find, it is present wherever a choice is made —
 *   A «الوكيل الرسمي»: the brand in its own colours on the home page, the
 *     customer's own brands first, a wall of every brand the shelf carries,
 *     the brand answering first when searched for by name, and a follow
 *     button that brings its new products to the customer;
 *   C «لحظة القرار»: in the cart, the same line's substitute when an item
 *     cannot be delivered from this shelf, the honestly cheaper bigger pack,
 *     and more of the brand that fills the basket; on a pet's profile, the
 *     brands that pet eats with how long each one lasts.
 *
 * Everything here is read from data the store already keeps: brand terms,
 * the brand design kits (Zooboxi_Brand_Kit), the facet index (brand, line,
 * form, species per product + price and stock per product), the shelf's
 * warehouse codes and the customer's own orders. Muntajat is the official
 * distributor of the brands it sells, which is what the «من الموزّع الرسمي»
 * seal says; the option `zooboxi_brand_official` ('all' | 'none' | [slugs])
 * narrows or silences that claim without a release.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Brand_Activation
{
    public const META_FOLLOW     = '_zb_followed_brands';
    public const OPTION_OFFICIAL = 'zooboxi_brand_official';

    private const FOLLOW_MAX   = 100;
    private const ALIAS_KEY    = 'zb_brand_alias_v1';
    private const MINE_KEY     = 'zb_mybrands_';
    private const COUNTS_KEY   = 'zb_brandcounts';
    private const LINE_MIN     = 3;
    /** Words that open titles because of what the product is, folded. */
    private const PRODUCT_WORDS = [
        'طعام' => 1, 'رمل' => 1, 'شامبو' => 1, 'بلسم' => 1, 'مناديل' => 1, 'طوق' => 1, 'مكافات' => 1, 'مكافاه' => 1,
        'علاج' => 1, 'لعبه' => 1, 'العاب' => 1, 'قفص' => 1, 'حوض' => 1, 'فرشاه' => 1, 'فرش' => 1, 'وعاء' => 1, 'سناك' => 1,
        'بسكويت' => 1, 'حليب' => 1, 'دنتال' => 1, 'فيتامين' => 1, 'فيتامينات' => 1, 'مشط' => 1, 'بخاخ' => 1, 'منظف' => 1,
        'كيس' => 1, 'اكياس' => 1, 'سرير' => 1, 'بيت' => 1, 'حبل' => 1, 'ملابس' => 1, 'عظمه' => 1, 'حفاضات' => 1,
        'مقص' => 1, 'مزيل' => 1, 'معجون' => 1, 'حبوب' => 1, 'مكمل' => 1, 'زيت' => 1, 'ماء' => 1, 'نافوره' => 1,
        'شرائح' => 1, 'اعواد' => 1, 'علبه' => 1, 'معلبات' => 1, 'وجبه' => 1, 'غذاء' => 1, 'اكل' => 1, 'مخلب' => 1,
    ];
    /** Candidate price band for a substitute: close enough to be the same decision. */
    private const SUB_LOW  = 0.75;
    private const SUB_HIGH = 1.35;

    public static function boot(): void
    {
        add_action('woocommerce_order_status_changed', [__CLASS__, 'on_order_status'], 30, 4);
        add_action('zooboxi_catalog_product_published', [__CLASS__, 'on_published'], 20, 1);
        // After every stock and price sync: what came back, what got cheaper.
        add_action('zooboxi_sync_stock', [__CLASS__, 'watch'], 45);
        add_action('zooboxi_sync_prices', [__CLASS__, 'watch'], 45);
    }

    /* ══════════════════════════════════════════════════════════════
       ONE BRAND, AS THE APP DRAWS IT
       ══════════════════════════════════════════════════════════════ */

    /**
     * The brand chip every surface shares: identity, colours, the seal.
     *
     * @return array{code:string,slug:string,name:string,logo:?string,count:int,boutique:bool,accent:?string,accent_dark:?string,official:bool,tagline:string,country:string,founded:string}
     */
    public static function summary(\WP_Term $t, string $lang, ?int $count = null): array
    {
        $code      = preg_match('/(\d+)/', (string) $t->description, $m) ? $m[1] : '';
        $published = self::published();
        $payload   = ($code !== '' && isset($published[$code]) && is_array($published[$code])) ? $published[$code] : null;

        $kit = (is_array($payload) && is_array($payload['kit'] ?? null)) ? $payload['kit'] : null;
        if ($kit === null && class_exists('Zooboxi_Brand_Kit')) {
            $kit = Zooboxi_Brand_Kit::kit($code);
        }
        $story = class_exists('Zooboxi_Brand_Kit') ? Zooboxi_Brand_Kit::story($kit, $lang) : ['tagline' => '', 'country' => '', 'founded' => ''];

        return [
            'code'        => $code,
            'slug'        => (string) $t->slug,
            'name'        => trim(html_entity_decode((string) ($payload['name'] ?? $t->name), ENT_QUOTES | ENT_HTML5, 'UTF-8')),
            'logo'        => self::logo($payload, $t),
            'count'       => $count ?? (int) $t->count,
            'boutique'    => $payload !== null,
            'accent'      => self::color((string) ($kit['accent'] ?? '')),
            'accent_dark' => self::color((string) ($kit['accent_dark'] ?? '')),
            'official'    => self::official((string) $t->slug),
            'tagline'     => (string) ($story['tagline'] ?? ''),
            'country'     => (string) ($story['country'] ?? ''),
            'founded'     => (string) ($story['founded'] ?? ''),
        ];
    }

    /** Does the «من الموزّع الرسمي» seal apply to this brand? */
    public static function official(string $slug): bool
    {
        $opt = get_option(self::OPTION_OFFICIAL, 'all');
        if ($opt === 'all' || $opt === '' || $opt === false) {
            return true;
        }
        if ($opt === 'none') {
            return false;
        }
        return is_array($opt) && in_array($slug, array_map('strval', $opt), true);
    }

    private static function published(): array
    {
        static $all = null;
        if ($all === null) {
            $all = class_exists('Zooboxi_Brand_Sync') ? Zooboxi_Brand_Sync::all() : [];
        }
        return $all;
    }

    /** The boutique's logo when it has one, else the term's own thumbnail. */
    private static function logo(?array $payload, \WP_Term $t): ?string
    {
        if (is_array($payload) && !empty($payload['logo_url'])) {
            return esc_url_raw((string) $payload['logo_url']);
        }
        $thumb = (int) get_term_meta((int) $t->term_id, 'thumbnail_id', true);
        $url   = $thumb ? wp_get_attachment_image_url($thumb, 'medium') : null;
        return $url ? esc_url_raw($url) : null;
    }

    private static function color(string $value): ?string
    {
        $value = trim($value);
        return preg_match('/^#[0-9A-Fa-f]{6}$/', $value) ? $value : null;
    }

    /* ══════════════════════════════════════════════════════════════
       THE SHELF'S BRANDS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Products per brand term on the current shelf, or null when the shelf is
     * not narrowed (then the term's own count is the truth). One grouped query,
     * cached per shelf for half an hour — stock moves hourly at most.
     *
     * @return array<int,int>|null term_id => products
     */
    public static function scoped_counts(): ?array
    {
        $codes = class_exists('Zooboxi_V2_Scope') ? Zooboxi_V2_Scope::codes() : [];
        if (empty($codes)) {
            return null;
        }
        $key    = self::COUNTS_KEY . Zooboxi_V2_Scope::cache_suffix();
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT tt.term_id, COUNT(DISTINCT p.ID) AS n
               FROM {$wpdb->posts} p
               JOIN {$wpdb->term_relationships} tr ON tr.object_id = p.ID
               JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id = tr.term_taxonomy_id AND tt.taxonomy = 'product_brand'
               JOIN {$wpdb->postmeta} m ON m.post_id = p.ID AND m.meta_key = '_zb_avail_branches' AND m.meta_value REGEXP %s
              WHERE p.post_type = 'product' AND p.post_status = 'publish'
              GROUP BY tt.term_id",
            self::regexp($codes)
        ), ARRAY_N);

        $out = [];
        foreach ((array) $rows as [$term_id, $n]) {
            $out[(int) $term_id] = (int) $n;
        }
        set_transient($key, $out, 30 * MINUTE_IN_SECONDS);
        return $out;
    }

    /**
     * Every brand the shelf carries, biggest first, as summaries. `$limit` 0 = all.
     *
     * @return array<int,array>
     */
    public static function shelf_brands(string $lang, int $limit = 0): array
    {
        $rows = array_values(self::shelf_terms());
        if ($limit > 0) {
            $rows = array_slice($rows, 0, $limit);
        }
        return array_map(static fn($r) => self::summary($r[0], $lang, $r[1]), $rows);
    }

    /**
     * The brands this shelf carries with what it holds of each, biggest first.
     * One source for the wall, the seal's number, search and «براندات لولو»:
     * the term list is read the way the directory reads it (in the request's
     * language), so a brand never says 184 in one place and 154 in another.
     *
     * @return array<int,array{0:\WP_Term,1:int}> term_id => [term, products]
     */
    public static function shelf_terms(): array
    {
        static $memo = [];
        $key = class_exists('Zooboxi_V2_Scope') ? Zooboxi_V2_Scope::cache_suffix() : '';
        if (isset($memo[$key])) {
            return $memo[$key];
        }
        $terms = get_terms([
            'taxonomy'   => 'product_brand',
            'hide_empty' => true,
            'orderby'    => 'count',
            'order'      => 'DESC',
        ]);
        $counts = self::scoped_counts();
        $rows = [];
        foreach (is_wp_error($terms) ? [] : $terms as $t) {
            $n = $counts === null ? (int) $t->count : (int) ($counts[(int) $t->term_id] ?? 0);
            if ($n > 0) {
                $rows[(int) $t->term_id] = [$t, $n];
            }
        }
        uasort($rows, static fn($a, $b) => $b[1] <=> $a[1]);
        return $memo[$key] = $rows;
    }

    /** Anchored per code so RUH01 never matches RUH010 (same rule as the shelf scope). */
    private static function regexp(array $codes): string
    {
        $quoted = array_map(static fn($c) => preg_quote((string) $c, '/'), $codes);
        return '(^|,)(' . implode('|', $quoted) . ')(,|$)';
    }

    /**
     * Keep the ids one of [$codes] holds, in the caller's order. Empty codes
     * (no point, no warehouse data) keep everything: a rule that cannot be
     * evaluated must not hide a product.
     *
     * @param int[] $ids
     * @return int[]
     */
    public static function held(array $ids, array $codes): array
    {
        $ids = array_values(array_unique(array_map('intval', $ids)));
        if (empty($codes) || empty($ids)) {
            return $ids;
        }
        global $wpdb;
        $in   = implode(',', $ids);
        $keep = $wpdb->get_col($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta}
              WHERE meta_key = '_zb_avail_branches' AND post_id IN ({$in}) AND meta_value REGEXP %s",
            self::regexp($codes)
        ));
        $keep = array_flip(array_map('intval', (array) $keep));
        return array_values(array_filter($ids, static fn($id) => isset($keep[$id])));
    }

    /* ══════════════════════════════════════════════════════════════
       A · THE BRAND ANSWERS FIRST WHEN SEARCHED FOR
       ══════════════════════════════════════════════════════════════ */

    /**
     * What a customer may type for each brand, folded: its name, its slug and
     * the words its Arabic titles open with («اينابا», «فيرسل لاقا»). The
     * Arabic name is read off the catalogue rather than kept by hand: the
     * titles already spell it the way customers search for it.
     *
     * @return array<int,string[]> term_id => aliases
     */
    public static function aliases(): array
    {
        $cached = get_transient(self::ALIAS_KEY);
        if (is_array($cached)) {
            return $cached;
        }
        if (!class_exists('Zooboxi_Facet_Index')) {
            return [];
        }

        global $wpdb;
        $rows = $wpdb->get_results(
            "SELECT tt.term_id, p.post_title
               FROM {$wpdb->term_relationships} tr
               JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id = tr.term_taxonomy_id AND tt.taxonomy = 'product_brand'
               JOIN {$wpdb->posts} p ON p.ID = tr.object_id AND p.post_type = 'product' AND p.post_status = 'publish'",
            ARRAY_N
        );

        $first = [];   // term → [one-word prefix => n]
        $second = [];  // term → [two-word prefix => n]
        $total = [];
        foreach ((array) $rows as [$term_id, $title]) {
            $words = preg_split('/\s+/u', trim(Zooboxi_Facet_Index::norm((string) $title)));
            if (empty($words[0]) || mb_strlen($words[0]) < 2 || preg_match('/\d/u', $words[0])) {
                continue;
            }
            $term_id = (int) $term_id;
            $total[$term_id] = ($total[$term_id] ?? 0) + 1;
            $first[$term_id][$words[0]] = ($first[$term_id][$words[0]] ?? 0) + 1;
            if (!empty($words[1])) {
                $two = $words[0] . ' ' . $words[1];
                $second[$term_id][$two] = ($second[$term_id][$two] ?? 0) + 1;
            }
        }

        // How many titles, across every brand, open with each word: a brand's
        // name opens ITS titles and almost nobody else's.
        $opens = [];
        foreach ($first as $by) {
            foreach ($by as $w => $n) {
                $opens[$w] = ($opens[$w] ?? 0) + $n;
            }
        }

        $out = [];
        $terms = get_terms(['taxonomy' => 'product_brand', 'hide_empty' => true]);
        foreach (is_wp_error($terms) ? [] : $terms as $t) {
            $id = (int) $t->term_id;
            $a  = [Zooboxi_Facet_Index::norm((string) $t->name), Zooboxi_Facet_Index::norm(str_replace('-', ' ', rawurldecode((string) $t->slug)))];
            $n  = $total[$id] ?? 0;
            foreach (($n >= 2 ? ($first[$id] ?? []) : []) as $w1 => $c1) {
                $share = $c1 / $n;
                // «جوسيرا» opens half of Josera's titles and «جوسي» a third —
                // both are the brand. «شامبو» opening a shampoo brand's titles
                // is still a product word.
                if ($share < 0.25 || $c1 / max(1, $opens[$w1] ?? 0) < 0.8 || mb_strlen($w1) < 2 || isset(self::PRODUCT_WORDS[$w1])) {
                    continue;
                }
                $a[] = (string) $w1;
                $by2 = $second[$id] ?? [];
                arsort($by2);
                foreach ($by2 as $w2 => $c2) {
                    // «كت كات», «فيرسل لاقا»: the name is two words when the
                    // second travels with the first almost every time.
                    if (strpos((string) $w2, $w1 . ' ') === 0) {
                        if ($c2 >= 0.8 * $c1) {
                            $a[] = (string) $w2;
                        }
                        break;
                    }
                }
            }
            $out[$id] = array_values(array_unique(array_filter(array_map('trim', $a), static fn($s) => mb_strlen($s) >= 2)));
        }

        set_transient(self::ALIAS_KEY, $out, 12 * HOUR_IN_SECONDS);
        return $out;
    }

    /** The brand a query names, or null. «اينابا», «inaba», «اينابا تشورو» all find INABA. */
    public static function match(string $q): ?\WP_Term
    {
        if (!class_exists('Zooboxi_Facet_Index')) {
            return null;
        }
        $qn = trim(preg_replace('/\s+/u', ' ', Zooboxi_Facet_Index::norm($q)));
        if (mb_strlen($qn) < 2) {
            return null;
        }
        $skel = self::skeleton($qn);
        $best = null;
        $best_score = 0.0;
        foreach (self::aliases() as $term_id => $aliases) {
            foreach ($aliases as $alias) {
                $score = 0.0;
                if ($qn === $alias) {
                    $score = 3.0;
                } elseif (strpos($qn, $alias . ' ') === 0) {
                    $score = 2.5; // the brand and then what of it
                } elseif (mb_strlen($qn) >= 3 && strpos($alias, $qn) === 0) {
                    $score = 2.0 + mb_strlen($qn) / max(1, mb_strlen($alias)) * 0.4; // still typing
                } elseif (mb_strlen($skel) >= 3 && $skel === self::skeleton($alias)) {
                    $score = 1.5; // «كيت كات» for «كت كات»: the long vowels differ
                }
                if ($score > $best_score) {
                    $best_score = $score;
                    $best = (int) $term_id;
                }
            }
        }
        if ($best === null) {
            return null;
        }
        $term = get_term($best, 'product_brand');
        return $term instanceof \WP_Term ? $term : null;
    }

    /** A folded word without its long vowels — how a name is spelled several ways. */
    private static function skeleton(string $s): string
    {
        return (string) preg_replace('/[اويى]/u', '', $s);
    }

    /**
     * The card a brand search shows above the products: identity, the lines
     * it carries on this shelf, and how much of it the shelf holds. Null when
     * the shelf holds none of it — a card leading to an empty page would lie.
     */
    public static function search_card(\WP_Term $t, string $lang): ?array
    {
        $n = (int) (self::shelf_terms()[(int) $t->term_id][1] ?? 0);
        if ($n <= 0) {
            return null;
        }
        $card = self::summary($t, $lang, $n);
        $card['lines'] = self::line_names((string) $t->slug, $lang, 4);
        $card['images'] = self::faces((string) $t->slug, 2);
        return $card;
    }

    /** How many brands the current shelf carries — the seal's number. */
    public static function shelf_count(): int
    {
        return count(self::shelf_terms());
    }

    /**
     * Pictures of a brand's best-ranked in-stock products on this shelf — the
     * search card holds up the brand's actual products, not a placeholder.
     *
     * @return string[]
     */
    public static function faces(string $slug, int $limit): array
    {
        if (!class_exists('Zooboxi_Facet_Index') || !Zooboxi_Facet_Index::ensure()) {
            return [];
        }
        global $wpdb;
        $codes = class_exists('Zooboxi_V2_Scope') ? Zooboxi_V2_Scope::codes() : [];
        $scope = empty($codes) ? '' : $wpdb->prepare(
            " JOIN {$wpdb->postmeta} a ON a.post_id = f.product_id AND a.meta_key = '_zb_avail_branches' AND a.meta_value REGEXP %s",
            self::regexp($codes)
        );
        $ids = $wpdb->get_col($wpdb->prepare(
            "SELECT f.product_id FROM " . Zooboxi_Facet_Index::table() . " f
               JOIN " . Zooboxi_Facet_Index::meta_table() . " m ON m.product_id = f.product_id AND m.instock = 1
               {$scope}
               LEFT JOIN {$wpdb->postmeta} r ON r.post_id = f.product_id AND r.meta_key = '_zb_rank_score'
              WHERE f.facet = 'brand' AND f.value = %s
              ORDER BY CAST(r.meta_value AS DECIMAL(12,4)) DESC
              LIMIT 8",
            rawurldecode($slug)
        ));
        $out = [];
        foreach (array_map('intval', (array) $ids) as $pid) {
            $thumb = get_post_thumbnail_id($pid);
            $url = $thumb ? wp_get_attachment_image_url($thumb, 'woocommerce_thumbnail') : null;
            if ($url) {
                $out[] = esc_url_raw($url);
            }
            if (count($out) >= $limit) {
                break;
            }
        }
        return $out;
    }

    /**
     * A brand's biggest lines on the current shelf, as names.
     *
     * @return string[]
     */
    public static function line_names(string $slug, string $lang, int $limit): array
    {
        if (!class_exists('Zooboxi_Facet_Index') || !class_exists('Zooboxi_Brand_Kit') || !Zooboxi_Facet_Index::ensure()) {
            return [];
        }
        global $wpdb;
        $codes  = class_exists('Zooboxi_V2_Scope') ? Zooboxi_V2_Scope::codes() : [];
        $prefix = $wpdb->esc_like(sanitize_key($slug) . '_') . '%';
        if (empty($codes)) {
            $rows = $wpdb->get_results($wpdb->prepare(
                "SELECT value, COUNT(*) AS n FROM " . Zooboxi_Facet_Index::table() . "
                  WHERE facet = 'line' AND value LIKE %s GROUP BY value ORDER BY n DESC",
                $prefix
            ), ARRAY_N);
        } else {
            $rows = $wpdb->get_results($wpdb->prepare(
                "SELECT f.value, COUNT(*) AS n FROM " . Zooboxi_Facet_Index::table() . " f
                   JOIN {$wpdb->postmeta} m ON m.post_id = f.product_id AND m.meta_key = '_zb_avail_branches' AND m.meta_value REGEXP %s
                  WHERE f.facet = 'line' AND f.value LIKE %s GROUP BY f.value ORDER BY n DESC",
                self::regexp($codes),
                $prefix
            ), ARRAY_N);
        }
        $out = [];
        foreach ((array) $rows as [$value, $n]) {
            if ((int) $n < self::LINE_MIN) {
                continue;
            }
            $label = Zooboxi_Brand_Kit::line_label((string) $value);
            if ($label !== null) {
                $out[] = $lang === 'en' ? $label[1] : $label[0];
            }
            if (count($out) >= $limit) {
                break;
            }
        }
        return count($out) >= 2 ? $out : [];
    }

    /* ══════════════════════════════════════════════════════════════
       A · THE CUSTOMER'S OWN BRANDS
       ══════════════════════════════════════════════════════════════ */

    /**
     * The brands this customer buys, most-bought first: order lines in the
     * last year, gifts excluded. Cached six hours, dropped on any order move.
     *
     * @return array<int,array{n:int,last:int,pid:int}> term_id => usage
     */
    public static function purchased(int $uid): array
    {
        if ($uid <= 0 || !function_exists('wc_get_orders')) {
            return [];
        }
        $cached = get_transient(self::MINE_KEY . $uid);
        if (is_array($cached) && ($cached['_v'] ?? 0) === 1) {
            return $cached['brands'];
        }

        $orders = wc_get_orders([
            'customer_id'  => $uid,
            'status'       => ['wc-completed', 'wc-processing', 'wc-zb-ready', 'wc-zb-out-for-delivery'],
            'date_created' => '>' . (time() - YEAR_IN_SECONDS),
            'limit'        => 60,
            'orderby'      => 'date',
            'order'        => 'DESC',
        ]);

        $grant_meta = class_exists('Zooboxi_Loyalty') ? Zooboxi_Loyalty::ORDER_GRANT_META : '_zb_gift_grant';
        $brands = [];
        $memo = [];
        foreach ((array) $orders as $order) {
            if (!$order instanceof \WC_Order) {
                continue;
            }
            $ts = $order->get_date_created() ? $order->get_date_created()->getTimestamp() : 0;
            foreach ($order->get_items() as $item) {
                if (!$item instanceof \WC_Order_Item_Product || $item->get_meta($grant_meta)) {
                    continue;
                }
                $pid = (int) $item->get_product_id();
                if ($pid <= 0) {
                    continue;
                }
                if (!isset($memo[$pid])) {
                    $terms = wp_get_post_terms($pid, 'product_brand', ['fields' => 'ids']);
                    $memo[$pid] = is_wp_error($terms) ? [] : array_map('intval', $terms);
                }
                foreach ($memo[$pid] as $term_id) {
                    $row = $brands[$term_id] ?? ['n' => 0, 'last' => 0, 'pid' => 0];
                    $row['n']++;
                    if ($ts >= $row['last']) {
                        $row['last'] = $ts;
                        $row['pid'] = $pid;
                    }
                    $brands[$term_id] = $row;
                }
            }
        }
        uasort($brands, static fn($a, $b) => [$b['n'], $b['last']] <=> [$a['n'], $a['last']]);

        set_transient(self::MINE_KEY . $uid, ['_v' => 1, 'brands' => $brands], 6 * HOUR_IN_SECONDS);
        return $brands;
    }

    /**
     * «براندات لولو» on the home page: the customer's brands the current shelf
     * still carries, each with its lines and the last thing bought from it.
     *
     * @return array<int,array>
     */
    public static function mine(int $uid, string $lang, int $limit = 6): array
    {
        $shelf = self::shelf_terms();
        $out = [];
        foreach (self::purchased($uid) as $term_id => $use) {
            if (!isset($shelf[(int) $term_id])) {
                continue; // not on this shelf
            }
            [$t, $n] = $shelf[(int) $term_id];
            $row = self::summary($t, $lang, $n);
            $row['lines'] = self::line_names((string) $t->slug, $lang, 2);
            $row['last_product'] = $use['pid'] ? wp_strip_all_tags((string) get_the_title($use['pid'])) : '';
            $row['bought'] = (int) $use['n'];
            $out[] = $row;
            if (count($out) >= $limit) {
                break;
            }
        }
        return $out;
    }

    /** A moved order can change the customer's brands. */
    public static function on_order_status($order_id, $from = '', $to = '', $order = null): void
    {
        $order = $order instanceof \WC_Order ? $order : wc_get_order($order_id);
        if ($order instanceof \WC_Order && (int) $order->get_customer_id() > 0) {
            delete_transient(self::MINE_KEY . (int) $order->get_customer_id());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       A · FOLLOW
       ══════════════════════════════════════════════════════════════ */

    /** @return string[] followed brand slugs, newest first */
    public static function followed(int $uid): array
    {
        if ($uid <= 0) {
            return [];
        }
        $raw = get_user_meta($uid, self::META_FOLLOW, true);
        return is_array($raw) ? array_values(array_filter(array_map('strval', $raw))) : [];
    }

    /** Follow or unfollow; returns whether the customer follows it afterwards. */
    public static function toggle(int $uid, string $slug, ?bool $force = null): bool
    {
        $list = self::followed($uid);
        $has  = in_array($slug, $list, true);
        $on   = $force ?? !$has;
        if ($on && !$has) {
            array_unshift($list, $slug);
        } elseif (!$on && $has) {
            $list = array_values(array_diff($list, [$slug]));
        }
        update_user_meta($uid, self::META_FOLLOW, array_slice(array_values(array_unique($list)), 0, self::FOLLOW_MAX));
        return $on;
    }

    /**
     * «جديد من براندات تتابعها»: products the followed brands added in the
     * last 60 days that this shelf can send, newest first.
     *
     * @return int[]
     */
    public static function fresh_ids(int $uid, int $limit = 10): array
    {
        $slugs = self::followed($uid);
        if (empty($slugs)) {
            return [];
        }
        $q = new \WP_Query([
            'post_type'      => 'product',
            'post_status'    => 'publish',
            'fields'         => 'ids',
            'posts_per_page' => 40,
            'orderby'        => 'date',
            'order'          => 'DESC',
            'no_found_rows'  => true,
            'date_query'     => [['after' => gmdate('Y-m-d', time() - 60 * DAY_IN_SECONDS)]],
            'tax_query'      => [
                ['taxonomy' => 'product_brand', 'field' => 'slug', 'terms' => $slugs],
                ['taxonomy' => 'product_visibility', 'field' => 'name', 'terms' => ['exclude-from-catalog', 'outofstock'], 'operator' => 'NOT IN'],
            ],
        ]);
        $ids = array_map('intval', (array) $q->posts);
        if (class_exists('Zooboxi_V2_Scope')) {
            $ids = Zooboxi_V2_Scope::filter_ids($ids);
        }
        return array_slice($ids, 0, $limit);
    }

    /**
     * A followed brand published something: tell its followers, once a day
     * per brand at most (the engine's idempotency key is source:id:person:day),
     * so a catalogue import of forty products is one notification, not forty.
     */
    public static function on_published($product_id): void
    {
        $pid = (int) $product_id;
        if ($pid <= 0 || !class_exists('Zooboxi_Push_Engine') || !class_exists('Zooboxi_Push_Gate')) {
            return;
        }
        $terms = wp_get_post_terms($pid, 'product_brand');
        if (is_wp_error($terms) || empty($terms)) {
            return;
        }
        global $wpdb;
        foreach ($terms as $t) {
            $slug = (string) $t->slug;
            $users = $wpdb->get_col($wpdb->prepare(
                "SELECT user_id FROM {$wpdb->usermeta} WHERE meta_key = %s AND meta_value LIKE %s LIMIT 500",
                self::META_FOLLOW,
                '%' . $wpdb->esc_like('"' . $slug . '"') . '%'
            ));
            $name = (string) $t->name;
            foreach (array_map('intval', (array) $users) as $uid) {
                if (!in_array($slug, self::followed($uid), true)) {
                    continue;
                }
                Zooboxi_Push_Engine::submit([
                    'user_id'      => $uid,
                    'topic'        => 'offers',
                    'tier'         => 'marketing',
                    'copy'         => [
                        'ar' => ['جديد من ' . $name, 'وصل منتج جديد من براند تتابعه — شوفه قبل الكل'],
                        'en' => ['New from ' . $name, 'A brand you follow just added something new.'],
                    ],
                    'route'        => '/brand/' . rawurlencode($slug),
                    'data'         => ['brand' => $slug, 'product_id' => (string) $pid],
                    'collapse_key' => 'brand_new_' . substr($slug, 0, 40),
                    'thread_id'    => 'brands',
                    'relevance'    => 0.5,
                    'source'       => 'brand_new',
                    'source_id'    => $slug,
                    'expires_at'   => time() + 3 * DAY_IN_SECONDS,
                ]);
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════
       A · WHAT A FOLLOWED BRAND DOES — back in stock, cheaper
       ══════════════════════════════════════════════════════════════ */

    private const SNAP_OPTION = 'zb_brandwatch_snap';
    /** A price has to fall at least this far to be news (the waitlist's rule). */
    private const DROP_RATIO = 0.90;
    /**
     * A sync that flips more than this share of the watched products at once
     * is a sync glitch (the stock mirror has wiped before), not a restock wave:
     * the snapshot moves on and nobody is told.
     */
    private const GLITCH_SHARE = 0.25;

    /**
     * Compare the followed brands' products with the last snapshot and tell
     * each follower, once a day per brand and kind, what came back in stock
     * and what got at least 10% cheaper. The first run only takes the
     * snapshot — a follow is a promise about change, not about the state
     * the store happened to be in when it started watching.
     *
     * @return array{restock:int,offer:int,sent:int}
     */
    public static function watch(): array
    {
        $out = ['restock' => 0, 'offer' => 0, 'sent' => 0];
        try {
            global $wpdb;
            $followers = self::followers_by_brand();
            if (empty($followers)) {
                delete_option(self::SNAP_OPTION);
                return $out;
            }

            // The followed brands' products and their brand.
            $slugs = array_keys($followers);
            $in = implode(',', array_fill(0, count($slugs), '%s'));
            $pairs = $wpdb->get_results($wpdb->prepare(
                "SELECT tr.object_id, t.slug
                   FROM {$wpdb->term_relationships} tr
                   JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id = tr.term_taxonomy_id AND tt.taxonomy = 'product_brand'
                   JOIN {$wpdb->terms} t ON t.term_id = tt.term_id
                   JOIN {$wpdb->posts} p ON p.ID = tr.object_id AND p.post_type = 'product' AND p.post_status = 'publish'
                  WHERE t.slug IN ({$in})",
                $slugs
            ), ARRAY_N);
            $brand_of = [];
            foreach ((array) $pairs as [$pid, $slug]) {
                $brand_of[(int) $pid] = (string) $slug;
            }
            if (empty($brand_of)) {
                return $out;
            }

            // Their state now: in stock, price, regular price.
            $now = [];
            $ids = implode(',', array_keys($brand_of));
            foreach ((array) $wpdb->get_results(
                "SELECT post_id, meta_key, meta_value FROM {$wpdb->postmeta}
                  WHERE post_id IN ({$ids}) AND meta_key IN ('_stock_status', '_price', '_regular_price')",
                ARRAY_N
            ) as [$pid, $key, $value]) {
                $now[(int) $pid][$key] = (string) $value;
            }
            $state = [];
            foreach ($brand_of as $pid => $_) {
                $row = $now[$pid] ?? [];
                $state[$pid] = [
                    ($row['_stock_status'] ?? '') === 'instock' ? 1 : 0,
                    (float) ($row['_price'] ?? 0),
                    (float) ($row['_regular_price'] ?? 0),
                ];
            }

            $prev = get_option(self::SNAP_OPTION, null);
            update_option(self::SNAP_OPTION, $state, false);
            if (!is_array($prev)) {
                return $out; // first look: nothing to compare with
            }

            $restocked = [];
            $cheaper = [];
            $flips = 0;
            foreach ($state as $pid => [$in_stock, $price, $regular]) {
                if (!isset($prev[$pid])) {
                    continue; // new to the watch (a new product has its own alert)
                }
                [$was_in, $was_price] = $prev[$pid];
                if ($in_stock === 1 && (int) $was_in === 0) {
                    $restocked[$brand_of[$pid]][] = $pid;
                    $flips++;
                }
                if ($in_stock === 1 && $price > 0 && (float) $was_price > 0 && $price <= (float) $was_price * self::DROP_RATIO) {
                    $cheaper[$brand_of[$pid]][] = [$pid, (float) $was_price, $price, $regular];
                    $flips++;
                }
            }
            $out['restock'] = array_sum(array_map('count', $restocked));
            $out['offer'] = array_sum(array_map('count', $cheaper));
            if ($flips > max(20, (int) (count($state) * self::GLITCH_SHARE))) {
                error_log('[Zooboxi brands] watch skipped: ' . $flips . ' of ' . count($state) . ' products changed at once');
                return $out;
            }

            foreach ($restocked as $slug => $pids) {
                $out['sent'] += self::tell($followers[$slug] ?? [], $slug, 'restock', $pids, []);
            }
            foreach ($cheaper as $slug => $rows) {
                usort($rows, static fn($a, $b) => (1 - $b[2] / $b[1]) <=> (1 - $a[2] / $a[1]));
                $out['sent'] += self::tell($followers[$slug] ?? [], $slug, 'offer', array_column($rows, 0), $rows);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi brands] watch failed: ' . $e->getMessage());
        }
        return $out;
    }

    /**
     * Every followed brand and who follows it.
     *
     * @return array<string,int[]> slug => user ids
     */
    private static function followers_by_brand(): array
    {
        global $wpdb;
        $by = [];
        foreach ((array) $wpdb->get_results($wpdb->prepare(
            "SELECT user_id, meta_value FROM {$wpdb->usermeta} WHERE meta_key = %s LIMIT 5000",
            self::META_FOLLOW
        ), ARRAY_N) as [$uid, $raw]) {
            $list = maybe_unserialize($raw);
            foreach (is_array($list) ? $list : [] as $slug) {
                $by[(string) $slug][] = (int) $uid;
            }
        }
        return $by;
    }

    /**
     * One notification per follower for one brand's news. A single product
     * opens that product; several open the brand. The engine's key
     * (source:brand:person:day) makes it once a day per brand and kind.
     *
     * @param int[] $users
     * @param int[] $pids   the products, most newsworthy first
     * @param array $prices offer rows [pid, was, now, regular]
     */
    private static function tell(array $users, string $slug, string $kind, array $pids, array $prices): int
    {
        if (empty($users) || empty($pids) || !class_exists('Zooboxi_Push_Engine') || !class_exists('Zooboxi_Push_Gate')) {
            return 0;
        }
        $term = get_term_by('slug', $slug, 'product_brand');
        $brand = $term instanceof \WP_Term ? (string) $term->name : $slug;
        $first = wc_get_product((int) $pids[0]);
        if (!$first) {
            return 0;
        }
        [$name, $name_en] = Zooboxi_Push_Engine::product_names($first);
        $n = count($pids);

        if ($kind === 'restock') {
            $copy = $n === 1
                ? ['ar' => ['رجع ' . $name, 'من ' . $brand . ' الذي تتابعه — متوفر الآن في زوبكسي.'],
                   'en' => [$name_en . ' is back', 'From ' . $brand . ', which you follow — in stock again.']]
                : ['ar' => ['رجعت ' . $n . ' منتجات من ' . $brand, 'منها ' . $name . ' — متوفرة الآن في زوبكسي.'],
                   'en' => [$n . ' ' . $brand . ' products are back', 'Including ' . $name_en . ' — in stock again.']];
        } else {
            [, $was, $now] = $prices[0];
            $pct = (int) round((1 - $now / $was) * 100);
            $copy = $n === 1
                ? ['ar' => [$brand . ': صار بـ ' . number_format($now, 0) . ' ﷼ بدل ' . number_format($was, 0), $name . ' — من براند تتابعه، لفترة محدودة.'],
                   'en' => [$brand . ': now ' . number_format($now, 0) . ' SAR, was ' . number_format($was, 0), $name_en . ' — from a brand you follow, for a limited time.']]
                : ['ar' => ['عروض جديدة من ' . $brand, $n . ' منتجات بسعر أقل — أكبرها ' . $pct . '٪ على ' . $name . '.'],
                   'en' => ['New offers from ' . $brand, $n . ' products cost less — up to ' . $pct . '% off ' . $name_en . '.']];
        }

        $sent = 0;
        foreach (array_slice(array_unique($users), 0, 2000) as $uid) {
            $r = Zooboxi_Push_Engine::submit([
                'user_id'      => (int) $uid,
                'topic'        => 'offers',
                // The customer asked for this brand's news by following it.
                'tier'         => Zooboxi_Push_Gate::TIER_SERVICE,
                'copy'         => $copy,
                'route'        => $n === 1 ? '/product/' . (int) $pids[0] : '/brand/' . rawurlencode($slug),
                'data'         => ['brand' => $slug, 'product_id' => (string) (int) $pids[0]],
                'collapse_key' => 'brand_' . $kind . '_' . substr($slug, 0, 40),
                'thread_id'    => 'brands',
                'relevance'    => $kind === 'restock' ? 0.85 : 0.75,
                'source'       => 'brand_' . $kind,
                'source_id'    => $slug,
                'expires_at'   => time() + ($kind === 'restock' ? DAY_IN_SECONDS : 2 * DAY_IN_SECONDS),
            ]);
            if (($r['id'] ?? 0) > 0) {
                $sent++;
            }
        }
        return $sent;
    }

    /* ══════════════════════════════════════════════════════════════
       C · A PET'S BRANDS
       ══════════════════════════════════════════════════════════════ */

    /**
     * «براندات لولو»: the brands in this pet's food gauge, each with the row
     * that runs out first — how long it lasts and what to reorder.
     *
     * @param array $supply the pet's gauge rows as DTOs (Zooboxi_Loyalty_Supply::dtos)
     * @return array<int,array>
     */
    public static function for_pet(array $supply, string $lang): array
    {
        $by = [];
        foreach ($supply as $row) {
            $slug = (string) ($row['product']['brand']['slug'] ?? '');
            if ($slug === '') {
                continue;
            }
            $days = $row['days_left'] ?? null;
            if (!isset($by[$slug]) || ($days !== null && ($by[$slug]['days_left'] ?? PHP_INT_MAX) > $days)) {
                $by[$slug] = $row;
            }
        }
        $out = [];
        foreach ($by as $slug => $row) {
            $t = get_term_by('slug', $slug, 'product_brand');
            if (!$t instanceof \WP_Term) {
                continue;
            }
            $out[] = ['brand' => self::summary($t, $lang), 'supply' => $row];
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       C · THE CART
       ══════════════════════════════════════════════════════════════ */

    /**
     * What the cart can say about its brands, per line and for the basket:
     *   lines[key].substitute — the same line at about the same price, when
     *                            this shelf cannot send the item;
     *   lines[key].upgrade    — the bigger pack of the same thing when it is
     *                            honestly cheaper (12–60%);
     *   complete              — more of the brand that fills the basket.
     *
     * @param array  $items   WC cart contents
     * @param string $shelf   the basket's shelf ('express' | 'all' | '')
     * @param array  $codes   the basket shelf's warehouse codes
     */
    public static function cart(array $items, string $shelf, array $codes, string $lang): array
    {
        $out = ['lines' => (object) [], 'complete' => null];
        if (empty($items) || !class_exists('Zooboxi_Facet_Index') || !Zooboxi_Facet_Index::ensure()) {
            return $out;
        }
        $lines = [];
        $in_cart = [];
        $weight = [];
        foreach ($items as $key => $item) {
            // A gift line is the reward's, not the customer's choice.
            if (class_exists('Zooboxi_Loyalty_Rewards') && Zooboxi_Loyalty_Rewards::line_grant_id($item) > 0) {
                continue;
            }
            $pid = (int) ($item['product_id'] ?? 0);
            if ($pid <= 0) {
                continue;
            }
            $in_cart[$pid] = true;
            $lines[(string) $key] = ['pid' => $pid, 'vid' => (int) ($item['variation_id'] ?? 0), 'total' => (float) ($item['line_total'] ?? 0)];
        }
        if (empty($lines)) {
            return $out;
        }

        $express = $shelf === 'express';
        $facets = self::facets(array_keys($in_cart));
        $held_now = array_flip(self::held(array_keys($in_cart), $codes));

        $result = [];
        foreach ($lines as $key => $line) {
            $pid = $line['pid'];
            $f = $facets[$pid] ?? [];
            foreach (array_keys($f['brand'] ?? []) as $b) {
                $weight[$b] = ($weight[$b] ?? 0) + max(1.0, $line['total']);
            }
            $entry = [];
            if (!empty($codes) && !isset($held_now[$pid])) {
                $sub = self::substitute($pid, $f, $codes, $express, $in_cart);
                if ($sub !== null) {
                    $entry['substitute'] = $sub;
                }
            } elseif ($line['vid'] === 0) {
                $up = self::upgrade($pid, $f, $codes, $express, $lang);
                if ($up !== null) {
                    $entry['upgrade'] = $up;
                }
            }
            if ($entry) {
                $result[$key] = $entry;
            }
        }
        $out['lines'] = $result ?: (object) [];

        if ($weight) {
            arsort($weight);
            $slug = (string) array_key_first($weight);
            $out['complete'] = self::complete($slug, $facets, $codes, $express, $in_cart, $lang);
        }
        return $out;
    }

    /**
     * Facet rows per product: [pid][facet][value] = true.
     *
     * @param int[] $ids
     */
    private static function facets(array $ids): array
    {
        if (empty($ids)) {
            return [];
        }
        global $wpdb;
        $in = implode(',', array_map('intval', $ids));
        $rows = [];
        foreach ($wpdb->get_results("SELECT product_id, facet, value FROM " . Zooboxi_Facet_Index::table() . " WHERE product_id IN ({$in}) AND facet IN ('brand','line','form','species')", ARRAY_N) as [$p, $facet, $value]) {
            $rows[(int) $p][(string) $facet][(string) $value] = true;
        }
        return $rows;
    }

    /**
     * Products of one brand (facet), with price, stock and title, optionally
     * narrowed to a facet value.
     *
     * @return array<int,array{price:float,instock:int,title:string}>
     */
    private static function brand_products(string $brand, bool $express): array
    {
        global $wpdb;
        $col = $express ? 'm.price_express' : 'm.price';
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT f.product_id, {$col} AS price, m.instock, p.post_title
               FROM " . Zooboxi_Facet_Index::table() . " f
               JOIN " . Zooboxi_Facet_Index::meta_table() . " m ON m.product_id = f.product_id
               JOIN {$wpdb->posts} p ON p.ID = f.product_id AND p.post_status = 'publish'
              WHERE f.facet = 'brand' AND f.value = %s",
            $brand
        ), ARRAY_A);
        $out = [];
        foreach ((array) $rows as $r) {
            $price = (float) $r['price'];
            if ($price <= 0 && $express) {
                $price = (float) get_post_meta((int) $r['product_id'], '_price', true);
            }
            $out[(int) $r['product_id']] = ['price' => $price, 'instock' => (int) $r['instock'], 'title' => (string) $r['post_title']];
        }
        return $out;
    }

    /** Same line when the product has one, else the same food type for the same animal. */
    private static function kin(array $f, array $g): bool
    {
        $lines = array_keys($f['line'] ?? []);
        if (!empty($lines)) {
            return (bool) array_intersect($lines, array_keys($g['line'] ?? []));
        }
        $forms = array_keys($f['form'] ?? []);
        $species = array_keys($f['species'] ?? []);
        return !empty($forms)
            && (bool) array_intersect($forms, array_keys($g['form'] ?? []))
            && (empty($species) || (bool) array_intersect($species, array_keys($g['species'] ?? [])));
    }

    private static function substitute(int $pid, array $f, array $codes, bool $express, array $in_cart): ?array
    {
        $brand = (string) (array_key_first($f['brand'] ?? []) ?? '');
        if ($brand === '') {
            return null;
        }
        $pool = self::brand_products($brand, $express);
        $price = (float) ($pool[$pid]['price'] ?? 0);
        if ($price <= 0) {
            return null;
        }
        $candidates = array_values(array_filter(array_keys($pool), static fn($id) =>
            $id !== $pid && !isset($in_cart[$id]) && $pool[$id]['instock'] === 1
            && $pool[$id]['price'] >= $price * self::SUB_LOW && $pool[$id]['price'] <= $price * self::SUB_HIGH));
        if (empty($candidates)) {
            return null;
        }
        $facets = self::facets($candidates);
        $candidates = array_values(array_filter($candidates, static fn($id) => self::kin($f, $facets[$id] ?? [])));
        $candidates = self::held($candidates, $codes);
        if (empty($candidates)) {
            return null;
        }
        usort($candidates, static fn($a, $b) => abs($pool[$a]['price'] - $price) <=> abs($pool[$b]['price'] - $price));
        $card = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::card($candidates[0]) : null;
        if ($card === null) {
            return null;
        }
        return ['product' => $card, 'same_price' => abs($pool[$candidates[0]]['price'] - $price) < 0.01];
    }

    private static function upgrade(int $pid, array $f, array $codes, bool $express, string $lang): ?array
    {
        $brand = (string) (array_key_first($f['brand'] ?? []) ?? '');
        if ($brand === '' || !class_exists('Zooboxi_Brand_Kit')) {
            return null;
        }
        $pool = self::brand_products($brand, $express);
        $mine = $pool[$pid] ?? null;
        if ($mine === null || $mine['price'] <= 0) {
            return null;
        }
        $pack = Zooboxi_Brand_Kit::pack(Zooboxi_Facet_Index::norm($mine['title']));
        if ($pack === null || $pack['grams'] < 20) {
            return null;
        }

        $ids = array_values(array_filter(array_keys($pool), static fn($id) => $id !== $pid && $pool[$id]['instock'] === 1 && $pool[$id]['price'] > $mine['price']));
        if (empty($ids)) {
            return null;
        }
        $facets = self::facets($ids);
        $best = null;
        foreach ($ids as $id) {
            if (!self::kin($f, $facets[$id] ?? []) || !self::same_species($f, $facets[$id] ?? [])) {
                continue;
            }
            $p = Zooboxi_Brand_Kit::pack(Zooboxi_Facet_Index::norm($pool[$id]['title']));
            if ($p === null || $p['grams'] <= $pack['grams']) {
                continue;
            }
            $cand = null;
            if ($pack['units'] > 1 && $p['units'] > $pack['units'] && abs($p['unit_g'] - $pack['unit_g']) < 0.01) {
                $a = $pool[$id]['price'] / $p['units'];
                $b = $mine['price'] / $pack['units'];
                $cand = ['mode' => 'unit', 'a' => $a, 'b' => $b, 'saving' => 1 - $a / $b];
            } else {
                $a = $pool[$id]['price'] / $p['grams'] * 1000;
                $b = $mine['price'] / $pack['grams'] * 1000;
                $cand = ['mode' => 'kg', 'a' => $a, 'b' => $b, 'saving' => 1 - $a / $b];
                if ($cand['saving'] > 0.5) {
                    continue; // two different products, not a bargain
                }
            }
            if ($cand['saving'] < 0.12) {
                continue;
            }
            $better = $best === null
                || ($cand['mode'] === 'unit' && $best['mode'] === 'kg')
                || ($cand['mode'] === $best['mode'] && $cand['saving'] > $best['saving']);
            if ($better) {
                $best = $cand + ['id' => $id, 'pack' => $p];
            }
        }
        if ($best === null || empty(self::held([$best['id']], $codes))) {
            return null;
        }
        $card = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::card((int) $best['id']) : null;
        if ($card === null) {
            return null;
        }
        $term = get_term_by('slug', $brand, 'product_brand');
        return [
            'brand'   => $term instanceof \WP_Term ? self::summary($term, $lang) : null,
            'mode'    => $best['mode'],
            'product' => $card,
            'big'     => ['label' => self::pack_label($best['pack'], $lang), 'each' => round($best['a'], 2)],
            'small'   => ['label' => self::pack_label($pack, $lang), 'each' => round($best['b'], 2), 'id' => $pid],
            'saving'  => (int) round($best['saving'] * 100),
        ];
    }

    private static function same_species(array $f, array $g): bool
    {
        $a = array_keys($f['species'] ?? []);
        $b = array_keys($g['species'] ?? []);
        return empty($a) || empty($b) || (bool) array_intersect($a, $b);
    }

    private static function pack_label(array $p, string $lang): string
    {
        $en = $lang === 'en';
        $w = $p['unit_g'] >= 1000
            ? rtrim(rtrim(number_format($p['unit_g'] / 1000, 2, '.', ''), '0'), '.') . ($en ? ' kg' : ' كجم')
            : rtrim(rtrim(number_format($p['unit_g'], 1, '.', ''), '0'), '.') . ($en ? ' g' : ' جم');
        return $p['units'] > 1 ? $p['units'] . ' × ' . $w : $w;
    }

    /**
     * «أكمل من إينابا»: the basket's leading brand, what else of it this shelf
     * can send — its lines in the basket first, then the brand's best-ranked.
     */
    private static function complete(string $brand, array $facets, array $codes, bool $express, array $in_cart, string $lang): ?array
    {
        $t = get_term_by('slug', $brand, 'product_brand');
        if (!$t instanceof \WP_Term) {
            return null;
        }
        $pool = self::brand_products($brand, $express);
        $ids = array_values(array_filter(array_keys($pool), static fn($id) => !isset($in_cart[$id]) && $pool[$id]['instock'] === 1));
        $ids = self::held($ids, $codes);
        if (count($ids) < 2) {
            return null;
        }

        $lines = [];
        $species = [];
        foreach ($in_cart as $pid => $_) {
            if (isset($facets[$pid]['brand'][$brand])) {
                $lines += $facets[$pid]['line'] ?? [];
                $species += $facets[$pid]['species'] ?? [];
            }
        }
        $cand = self::facets($ids);
        global $wpdb;
        $rank = [];
        $in = implode(',', array_map('intval', $ids));
        foreach ($wpdb->get_results("SELECT post_id, meta_value FROM {$wpdb->postmeta} WHERE meta_key = '_zb_rank_score' AND post_id IN ({$in})", ARRAY_N) as [$p, $s]) {
            $rank[(int) $p] = (float) $s;
        }
        $score = static function (int $id) use ($cand, $lines, $species, $rank): float {
            $g = $cand[$id] ?? [];
            $s = $rank[$id] ?? 0.0;
            if ($lines && array_intersect_key($g['line'] ?? [], $lines)) {
                $s += 1000;
            }
            if ($species && !array_intersect_key($g['species'] ?? [], $species) && !empty($g['species'])) {
                $s -= 2000; // a dog treat does not complete a cat's basket
            }
            return $s;
        };
        usort($ids, static fn($a, $b) => $score($b) <=> $score($a));
        $ids = array_values(array_filter($ids, static fn($id) => $score($id) > -1000));
        $cards = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::cards(array_slice($ids, 0, 8)) : [];
        if (count($cards) < 2) {
            return null;
        }
        return ['brand' => self::summary($t, $lang), 'products' => $cards];
    }
}

Zooboxi_Brand_Activation::boot();
