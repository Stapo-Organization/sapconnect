<?php
/**
 * ════════════════════════════════════════════════════════════════════
 * Zooboxi_Facet_Index — «فهرس الفلاتر»
 *
 * The store's attributes cannot power a filter on their own: the same idea
 * is spelled several ways (تونة / تونا, «طعام جاف» / «طعام جاف (كيبل)»),
 * lives twice (a leaf category «القطط الصغيرة» AND a `pa_age` term), or not
 * at all (most flavours are only in the title). The old listing facets were
 * `get_terms()` counts — catalogue-wide, so cat food offered dog flavours
 * and a number never went down when you picked something.
 *
 * This index reads every published product ONCE (title + curated attributes
 * + its department names), writes one row per (product, facet, value) in a
 * normalised vocabulary, and keeps the numbers a listing needs to sort and
 * price (piece price per shelf, price per kilo, discount, stock).
 *
 * The query side (`search()`) takes the ids a listing already scoped
 * (category, shelf warehouse, search, rail) and answers in PHP:
 *   - the ids matching every selection (OR inside a facet, AND across),
 *   - every facet's counts computed WITHOUT its own selection (so the
 *     numbers are what you get if you tick that value),
 *   - why an empty value is empty («غير متوفر مع قطط صغيرة»),
 *   - what one tap would bring back when nothing matches.
 *
 * Rebuilt hourly by cron (a few SQL reads; ~2 s for the whole catalogue)
 * and on first use when the table is missing or the vocabulary changed.
 * Website untouched: only the app's v2 listing reads it.
 * ════════════════════════════════════════════════════════════════════
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Facet_Index
{
    /** Bump when the vocabulary or the rules change — the next read rebuilds. */
    public const VERSION = 3; // 2: the brand `line` facet + multipack-aware per_kg · 3: the `dept` facet

    public const OPTION_VERSION = 'zooboxi_facet_index_version';
    public const OPTION_BUILT   = 'zooboxi_facet_index_built';
    public const CRON           = 'zooboxi_facet_index_rebuild';

    /** Species roots of the MAIN tree (Zooboxi_V2_Catalog_Controller::animal_nav). */
    public const SPECIES_ROOTS = [107 => 'cat', 114 => 'dog', 202 => 'bird', 194 => 'small'];

    /** The parallel «المعايير الصحية» tree — condition tags, loose, never mined for facets. */
    public const NEED_TREE_ROOT = 102;

    /** Facets in the order the sheet lists them: which pet, which shelf, then the rest. */
    public const FACETS = ['species', 'dept', 'line', 'form', 'texture', 'life', 'flavor', 'need', 'brand', 'pack', 'offer'];

    /** A department's chip name, when the row above the list has no room for the full one. */
    private const DEPT_SHORT = [
        'food' => ['طعام', 'Food'], 'treat' => ['مكافآت', 'Treats'], 'health' => ['صحة', 'Health'],
        'litter' => ['رمل', 'Litter'], 'toy' => ['ألعاب', 'Toys'], 'bed' => ['بيوت وأسرّة', 'Beds'],
        'collar' => ['أطواق', 'Collars'], 'bowl' => ['أوعية', 'Bowls'], 'groom' => ['عناية', 'Grooming'],
        'carrier' => ['تنقّل', 'Carriers'], 'bundle' => ['بكجات', 'Bundles'],
    ];

    /** Facets that only mean something for food — hidden until the list is about food. */
    public const FOOD_FACETS = ['form', 'texture', 'life', 'flavor'];

    /**
     * Departments across every pet, read off the shopping tree's names
     * (leaf first). Order matters: «ادوات الطعام» is a bowl before it is food,
     * «مكافآت العناية بالأسنان» a treat before it is care.
     */
    private const DEPT_RULES = [
        'bundle'  => '/بكج/u',
        'bowl'    => '/ادوات الطعام|اوعيه|وعاء|مشربيه|معالف/u',
        'treat'   => '/مكافا|سناك/u',
        'health'  => '/فيتامين|مكمل|صحه|علاج/u',
        'food'    => '/طعام|غذاء|حليب|السوائل/u',
        'litter'  => '/رمل|نشاره/u',
        'toy'     => '/العاب|لعب|خداش|اثاث|اغصان|عجلات|عضاض/u',
        'bed'     => '/وسادات|بيوت|اقفاص|اسره|سرير/u',
        'collar'  => '/اطواق|طوق|مشدات|مشدرات|صدريات|قلادات/u',
        'carrier' => '/التنقل|شنط/u',
        'groom'   => '/التنظيف|شامبو|فرش|امشاط|الاستحمام|مزيلات|العنايه بالعين|التدريب/u',
    ];

    /** A value the sheet can show only after this many products carry it in the scope. */
    private const MIN_GROUP_VALUES = 2;

    public static function hooks(): void
    {
        add_action(self::CRON, [self::class, 'rebuild']);
        // «نبّهني إذا وصل…» asks the index again after each rebuild.
        require_once __DIR__ . '/class-zooboxi-filter-watch.php';
        Zooboxi_Filter_Watch::hooks();
        add_action('init', static function () {
            if (!wp_next_scheduled(self::CRON)) {
                wp_schedule_event(time() + 300, 'hourly', self::CRON);
            }
        });
    }

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_facets';
    }

    public static function meta_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_facet_meta';
    }

    /* ══════════════════════════════════════════════════════════════
       BUILD
       ══════════════════════════════════════════════════════════════ */

    /** Make sure a current index exists before a read. Cheap when it does. */
    public static function ensure(): bool
    {
        if ((int) get_option(self::OPTION_VERSION, 0) === self::VERSION) {
            return true;
        }
        return self::rebuild();
    }

    private static function create_tables(string $facets, string $meta): void
    {
        global $wpdb;
        $charset = $wpdb->get_charset_collate();
        $wpdb->query("CREATE TABLE IF NOT EXISTS {$facets} (
            product_id BIGINT UNSIGNED NOT NULL,
            facet VARCHAR(16) NOT NULL,
            value VARCHAR(64) NOT NULL,
            PRIMARY KEY (product_id, facet, value),
            KEY facet_value (facet, value)
        ) {$charset}");
        $wpdb->query("CREATE TABLE IF NOT EXISTS {$meta} (
            product_id BIGINT UNSIGNED NOT NULL,
            price DECIMAL(12,2) NOT NULL DEFAULT 0,
            price_express DECIMAL(12,2) NOT NULL DEFAULT 0,
            per_kg DECIMAL(12,2) NULL,
            discount TINYINT UNSIGNED NOT NULL DEFAULT 0,
            instock TINYINT UNSIGNED NOT NULL DEFAULT 1,
            PRIMARY KEY (product_id)
        ) {$charset}");
    }

    /**
     * Read the catalogue, classify every product, and swap the new rows in
     * atomically (build into *_new tables, then RENAME).
     */
    public static function rebuild(): bool
    {
        global $wpdb;

        $lock = 'zooboxi_facet_index_lock';
        if (get_transient($lock)) {
            return (int) get_option(self::OPTION_VERSION, 0) > 0;
        }
        set_transient($lock, 1, 120);

        try {
            $rows = self::classify_all();
            update_option('zooboxi_facet_brand_names', self::$brand_names, false);

            $facets = self::table();
            $meta   = self::meta_table();
            $fnew   = $facets . '_new';
            $mnew   = $meta . '_new';

            $wpdb->query("DROP TABLE IF EXISTS {$fnew}");
            $wpdb->query("DROP TABLE IF EXISTS {$mnew}");
            self::create_tables($fnew, $mnew);
            self::create_tables($facets, $meta);

            $facet_rows = [];
            $meta_rows  = [];
            foreach ($rows as $pid => $row) {
                foreach ($row['facets'] as $facet => $values) {
                    foreach (array_keys($values) as $value) {
                        $facet_rows[] = $wpdb->prepare('(%d,%s,%s)', $pid, $facet, (string) $value);
                    }
                }
                $meta_rows[] = $row['per_kg'] === null
                    ? $wpdb->prepare('(%d,%f,%f,NULL,%d,%d)', $pid, $row['price'], $row['price_express'], $row['discount'], $row['instock'])
                    : $wpdb->prepare('(%d,%f,%f,%f,%d,%d)', $pid, $row['price'], $row['price_express'], $row['per_kg'], $row['discount'], $row['instock']);
            }
            foreach (array_chunk($facet_rows, 800) as $chunk) {
                $wpdb->query("INSERT IGNORE INTO {$fnew} (product_id, facet, value) VALUES " . implode(',', $chunk));
            }
            foreach (array_chunk($meta_rows, 800) as $chunk) {
                $wpdb->query("INSERT IGNORE INTO {$mnew} (product_id, price, price_express, per_kg, discount, instock) VALUES " . implode(',', $chunk));
            }

            $wpdb->query("DROP TABLE IF EXISTS {$facets}_old");
            $wpdb->query("DROP TABLE IF EXISTS {$meta}_old");
            $wpdb->query("RENAME TABLE {$facets} TO {$facets}_old, {$fnew} TO {$facets}, {$meta} TO {$meta}_old, {$mnew} TO {$meta}");
            $wpdb->query("DROP TABLE IF EXISTS {$facets}_old");
            $wpdb->query("DROP TABLE IF EXISTS {$meta}_old");

            update_option(self::OPTION_VERSION, self::VERSION, false);
            update_option(self::OPTION_BUILT, time(), false);
            wp_cache_delete('zb_facet_base', 'zooboxi');
            return true;
        } catch (\Throwable $e) {
            error_log('[zooboxi] facet index rebuild failed: ' . $e->getMessage());
            return false;
        } finally {
            delete_transient($lock);
        }
    }

    /**
     * Every published product → its facet values and numbers.
     *
     * @return array<int, array{facets:array<string,array<string,bool>>,price:float,price_express:float,per_kg:?float,discount:int,instock:int}>
     */
    public static function classify_all(): array
    {
        global $wpdb;

        $products = $wpdb->get_results(
            "SELECT ID, post_title, post_date FROM {$wpdb->posts}
             WHERE post_type = 'product' AND post_status = 'publish'",
            ARRAY_A
        );
        if (empty($products)) {
            return [];
        }

        $ids    = array_map(static fn($r) => (int) $r['ID'], $products);
        $idList = implode(',', $ids);

        // ── Terms: departments, brand, the curated attributes, pack options.
        $taxes = ['product_cat', 'product_brand', 'pa_age', 'pa_flavor', 'pa_food-type', 'pa_health', 'pa_choose-opt'];
        $in    = "'" . implode("','", array_map('esc_sql', $taxes)) . "'";
        $terms = $wpdb->get_results(
            "SELECT tr.object_id AS pid, tt.taxonomy, t.term_id, t.name, t.slug
             FROM {$wpdb->term_relationships} tr
             JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id = tr.term_taxonomy_id
             JOIN {$wpdb->terms} t ON t.term_id = tt.term_id
             WHERE tt.taxonomy IN ({$in}) AND tr.object_id IN ({$idList})",
            ARRAY_A
        );

        // Department ancestry, so a product in «الطعام الرطب» knows it is cat food.
        $cats = $wpdb->get_results(
            "SELECT t.term_id, t.name, tt.parent FROM {$wpdb->term_taxonomy} tt
             JOIN {$wpdb->terms} t ON t.term_id = tt.term_id
             WHERE tt.taxonomy = 'product_cat'",
            ARRAY_A
        );
        $parent = [];
        $cname  = [];
        foreach ($cats as $c) {
            $parent[(int) $c['term_id']] = (int) $c['parent'];
            $cname[(int) $c['term_id']]  = (string) $c['name'];
        }

        $by = [];
        foreach ($terms as $t) {
            $by[(int) $t['pid']][$t['taxonomy']][] = $t;
        }

        // ── Numbers: WooCommerce's own lookup (min piece price, sale, stock).
        $lookup = [];
        foreach ($wpdb->get_results(
            "SELECT product_id, min_price, onsale, stock_status
             FROM {$wpdb->prefix}wc_product_meta_lookup WHERE product_id IN ({$idList})",
            ARRAY_A
        ) as $l) {
            $lookup[(int) $l['product_id']] = $l;
        }

        // The إكسبريس piece price: the product's own meta, or its cheapest variation's.
        $express = [];
        foreach ($wpdb->get_results(
            "SELECT IF(p.post_type = 'product_variation', p.post_parent, p.ID) AS pid,
                    MIN(CAST(pm.meta_value AS DECIMAL(12,2))) AS price
             FROM {$wpdb->postmeta} pm JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_zooboxi_price_express' AND pm.meta_value > 0
             GROUP BY pid",
            ARRAY_A
        ) as $e) {
            $express[(int) $e['pid']] = (float) $e['price'];
        }

        // Discount: the deepest real sale on the product or any of its variations.
        $discount = [];
        foreach ($wpdb->get_results(
            "SELECT IF(p.post_type = 'product_variation', p.post_parent, p.ID) AS pid,
                    MAX(ROUND(100 * (1 - CAST(s.meta_value AS DECIMAL(12,2)) / CAST(r.meta_value AS DECIMAL(12,2))))) AS pct
             FROM {$wpdb->postmeta} s
             JOIN {$wpdb->postmeta} r ON r.post_id = s.post_id AND r.meta_key = '_regular_price'
             JOIN {$wpdb->posts} p ON p.ID = s.post_id
             WHERE s.meta_key = '_sale_price' AND s.meta_value > 0 AND r.meta_value > 0
               AND CAST(s.meta_value AS DECIMAL(12,2)) < CAST(r.meta_value AS DECIMAL(12,2))
             GROUP BY pid",
            ARRAY_A
        ) as $d) {
            $discount[(int) $d['pid']] = max(0, min(99, (int) $d['pct']));
        }

        // English names: the brand lines match on them as well as on the title.
        $names_en = [];
        foreach ($wpdb->get_results(
            "SELECT post_id, meta_value FROM {$wpdb->postmeta}
             WHERE meta_key = '_zooboxi_name_en' AND meta_value <> '' AND post_id IN ({$idList})",
            ARRAY_N
        ) as [$npid, $nval]) {
            $names_en[(int) $npid] = self::norm((string) $nval);
        }

        $new_after = strtotime('-30 days');
        $out       = [];

        foreach ($products as $p) {
            $pid   = (int) $p['ID'];
            $title = (string) $p['post_title'];
            $mine  = $by[$pid] ?? [];

            // Department names (leaf + ancestors), species, need-tree membership.
            $dept    = [];
            $species = [];
            $bundle  = false;
            $shelves = [];
            foreach ($mine['product_cat'] ?? [] as $t) {
                $id    = (int) $t['term_id'];
                $chain = [];
                $guard = 0;
                while ($id && $guard++ < 8) {
                    $chain[] = $id;
                    $id      = $parent[$id] ?? 0;
                }
                if (in_array(self::NEED_TREE_ROOT, $chain, true)) {
                    continue; // condition tags — not a shelf, not a facet source
                }
                foreach ($chain as $cid) {
                    if (isset(self::SPECIES_ROOTS[$cid])) {
                        $species[self::SPECIES_ROOTS[$cid]] = true;
                    } else {
                        $dept[] = $cname[$cid] ?? '';
                    }
                }
                if ($shelf = self::shelf_of($chain, $cname, (string) $p['post_title'])) {
                    $shelves[$shelf] = true;
                }
            }
            $deptText = self::norm(implode(' | ', array_unique($dept)));
            if (preg_match('/بكج|باقه|bundle/u', $deptText)) {
                $bundle = true;
            }

            $attr = static function (string $tax) use ($mine): string {
                return implode(' | ', array_map(static fn($t) => (string) $t['name'], $mine[$tax] ?? []));
            };
            $titleN  = self::norm($title);
            $ageN    = self::norm($attr('pa_age'));
            $flavorN = self::norm($attr('pa_flavor'));
            $typeN   = self::norm($attr('pa_food-type'));
            $healthN = self::norm($attr('pa_health'));

            $f = array_fill_keys(self::FACETS, []);
            $f['species'] = $species;
            $f['dept']    = $shelves;

            // ── form: departments are the truth; the title fills the gaps, but only
            //    for something that IS food (a «سمكة» toy never becomes wet food).
            $isFoodDept = (bool) preg_match('/طعام|غذاء|مكافا|حليب|سناك|وجبات|food|treat/u', $deptText) || $typeN !== '';
            if ($isFoodDept) {
                $text = $deptText . ' | ' . $typeN . ' | ' . $titleN;
                // A treat is what its department (or curated type) says; the title
                // only decides when no department calls it dinner.
                $treatWords = '/مكافا|سناك|snack|treat|بسكوت|بسكويت|كريمي|عصي|ستيك|مقرمش|للمضغ|اعواد/u';
                $dinnerDept = (bool) preg_match('/الطعام الرطب|الطعام الجاف|طعام رطب|طعام جاف/u', $deptText);
                if (preg_match($treatWords, $deptText . ' ' . $typeN) || (!$dinnerDept && preg_match($treatWords, $titleN))) {
                    $f['form']['treat'] = true;
                }
                if (preg_match('/حليب|milk/u', $text)) {
                    $f['form']['milk'] = true;
                }
                if (preg_match('/رطب|معلب|علب|اظرف|ظرف|باوتش|pouch|باتيه|pate|مهروس|موس|mousse|مرق|gravy|جيلي|jelly|wet/u', $text)) {
                    $f['form']['wet'] = true;
                }
                if (preg_match('/جاف|كيبل|kibble|dry/u', $text)) {
                    $f['form']['dry'] = true;
                }
                // A treat department wins over its own "wet" words («مكافآت كريمية» is not dinner).
                if (isset($f['form']['treat']) && preg_match('/مكافا|سناك|snack|treat/u', $deptText . ' ' . $typeN)) {
                    unset($f['form']['wet'], $f['form']['dry']);
                }
            }

            // ── texture: only for wet food.
            if (isset($f['form']['wet'])) {
                if (preg_match('/اظرف|ظرف|باوتش|pouch/u', $titleN)) $f['texture']['pouch'] = true;
                if (preg_match('/معلب|علب|\bcan\b/u', $titleN)) $f['texture']['can'] = true;
                if (preg_match('/باتيه|pate|مهروس|موس|mousse/u', $titleN)) $f['texture']['pate'] = true;
                if (preg_match('/مرق|gravy|صوص/u', $titleN)) $f['texture']['gravy'] = true;
                if (preg_match('/جيلي|jelly|هلام/u', $titleN)) $f['texture']['jelly'] = true;
            }

            $edible = !empty($f['form']);

            // ── life stage: species-neutral values; the sheet names them per species.
            if ($edible || $ageN !== '') {
                $text = $ageN . ' | ' . $deptText . ' | ' . $titleN;
                if (preg_match('/جميع الاعمار|كل الاعمار|جميع المراحل|لكل الاعمار|all life stages|all ages/u', $text)) {
                    $f['life'] = ['young' => true, 'adult' => true, 'senior' => true];
                } else {
                    if (preg_match('/قطط صغيره|قطه صغيره|القطط الصغيره|كيتن|kitten|جرو|جراء|الجراء|بوبي|puppy|junior|تغذيه يدويه/u', $text)
                        || (isset($species['bird']) && preg_match('/فراخ/u', $text))) {
                        $f['life']['young'] = true;
                    }
                    if (preg_match('/كبار السن|كبيره السن|كبير السن|المسنه|مسن|سينيور|senior|ناضج|mature|7\+|\+7/u', $text)
                        || (isset($species['cat']) && preg_match('/القطط الكبيره|للقطط الكبيره/u', $text))) {
                        $f['life']['senior'] = true;
                    }
                    if (preg_match('/بالغ|للبالغين|adult/u', $text)) {
                        $f['life']['adult'] = true;
                    }
                    // Dinner that names no age is everyday adult food.
                    if (empty($f['life']) && (isset($f['form']['wet']) || isset($f['form']['dry']))) {
                        $f['life']['adult'] = true;
                    }
                }
            }

            // ── flavour / protein: food only, from the title and the curated term.
            if ($edible) {
                $text = $titleN . ' | ' . $flavorN;
                foreach (self::FLAVOR_RULES as $value => $re) {
                    if ($value === 'rabbit' && isset($species['small'])) {
                        continue; // «طعام الأرانب» is food FOR rabbits
                    }
                    if (preg_match($re, $text)) {
                        $f['flavor'][$value] = true;
                    }
                }
                // «سمك (سلمون، تونة…)» is the curated term for salmon and tuna too:
                // other fish only when the title itself names one.
                if (isset($f['flavor']['fish']) && (isset($f['flavor']['salmon']) || isset($f['flavor']['tuna']))
                    && !preg_match(self::FLAVOR_RULES['fish'], $titleN)) {
                    unset($f['flavor']['fish']);
                }
            }

            // ── needs: the title, the health attribute and the health departments.
            $text = $titleN . ' | ' . $healthN . ' | ' . $deptText;
            foreach (self::NEED_RULES as $value => [$re, $foodOnly]) {
                if ($foodOnly && !$edible) {
                    continue;
                }
                if (preg_match($re, $text)) {
                    $f['need'][$value] = true;
                }
            }
            if (isset($f['need']['hairball'])) {
                unset($f['need']['skin']); // «كرات الشعر» is not a coat product
            }

            // ── brand: the one brand taxonomy the boutique pages use.
            foreach ($mine['product_brand'] ?? [] as $t) {
                $f['brand'][rawurldecode((string) $t['slug'])] = true;
                self::$brand_names[rawurldecode((string) $t['slug'])] = (string) $t['name'];
            }

            // ── line: the brand's own product lines (curated, see Zooboxi_Brand_Kit).
            if (!empty($f['brand']) && class_exists('Zooboxi_Brand_Kit')) {
                foreach (Zooboxi_Brand_Kit::lines_of(array_keys($f['brand']), $titleN, $names_en[$pid] ?? '') as $line) {
                    $f['line'][$line] = true;
                }
            }

            // ── pack: sold by the carton too.
            foreach ($mine['pa_choose-opt'] ?? [] as $t) {
                if (preg_match('/كرتون|carton/u', (string) $t['name'])) {
                    $f['pack']['carton'] = true;
                }
            }

            // ── offers.
            $l = $lookup[$pid] ?? null;
            if (!empty($discount[$pid]) || ($l && (int) $l['onsale'] === 1)) {
                $f['offer']['sale'] = true;
            }
            if (strtotime((string) $p['post_date']) >= $new_after) {
                $f['offer']['new'] = true;
            }
            if ($bundle) {
                $f['offer']['bundle'] = true;
            }

            $price  = $l ? (float) $l['min_price'] : 0.0;
            $pexp   = $express[$pid] ?? $price;
            $per_kg = null;
            if (($edible || preg_match('/رمل|litter/u', $deptText)) && $price > 0 && class_exists('Zooboxi_Product_Story')) {
                // A multipack («4×14غ», «20 ظرف × 14غ») weighs all its pieces,
                // not the first number in the title.
                $multi = class_exists('Zooboxi_Brand_Kit') ? Zooboxi_Brand_Kit::pack($titleN) : null;
                $size  = $multi ?? Zooboxi_Product_Story::pack_size($title);
                $g     = is_array($size) ? (int) round((float) ($size['grams'] ?? 0)) : 0;
                if ($g >= 20) {
                    $per_kg = round($price / $g * 1000, 2);
                }
            }

            $out[$pid] = [
                'facets'        => array_filter($f),
                'price'         => $price,
                'price_express' => $pexp > 0 ? $pexp : $price,
                'per_kg'        => $per_kg,
                'discount'      => (int) ($discount[$pid] ?? 0),
                'instock'       => ($l && $l['stock_status'] === 'outofstock') ? 0 : 1,
            ];
        }

        return $out;
    }

    /**
     * The department one category places a product on: the first name up
     * the chain (leaf first) that a rule knows. A name that is two shelves
     * at once («المكافآت والفيتامينات», «طعام ومكافات القوارض») lets the
     * product's own title decide.
     *
     * @param int[]              $chain leaf → root
     * @param array<int,string>  $cname
     */
    public static function shelf_of(array $chain, array $cname, string $title): ?string
    {
        $titleN = self::norm($title);
        foreach ($chain as $cid) {
            if (isset(self::SPECIES_ROOTS[$cid])) {
                break;
            }
            $name = self::norm($cname[$cid] ?? '');
            if ($name === '') {
                continue;
            }
            $hits = [];
            foreach (self::DEPT_RULES as $key => $re) {
                if (preg_match($re, $name)) {
                    $hits[] = $key;
                }
            }
            if (empty($hits)) {
                continue;
            }
            if (in_array('treat', $hits, true) && in_array('health', $hits, true)) {
                return preg_match('/فيتامين|مكمل|معجون|كالسيوم|زيت|بروبيوتك|vitamin|supplement|paste/u', $titleN) ? 'health' : 'treat';
            }
            if (in_array('treat', $hits, true) && in_array('food', $hits, true)) {
                return preg_match('/مكافا|سناك|عصي|بسكوت|بسكويت|اعواد|snack|treat|stick/u', $titleN) ? 'treat' : 'food';
            }
            return $hits[0];
        }
        return null;
    }

    /** @var array<string,string> brand slug → display name, collected while building */
    private static $brand_names = [];

    /** Arabic folding: no diacritics or tatweel, one alef, ة→ه, ى→ي, lower-case Latin. */
    public static function norm(string $s): string
    {
        $s = html_entity_decode($s, ENT_QUOTES, 'UTF-8');
        $s = preg_replace('/[\x{064B}-\x{065F}\x{0670}\x{0640}]/u', '', $s) ?? $s;
        $s = strtr($s, ['أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ٱ' => 'ا', 'ة' => 'ه', 'ى' => 'ي', '×' => 'x']);
        return function_exists('mb_strtolower') ? mb_strtolower($s, 'UTF-8') : strtolower($s);
    }

    private const FLAVOR_RULES = [
        'chicken' => '/دجاج|دجاح|دواجن|chicken|poultry/u',
        'tuna'    => '/تونه|تونا|tuna/u',
        'salmon'  => '/سلمون|salmon/u',
        'fish'    => '/(?:^|[^\p{L}])(?:[وبلف])?(?:ال)?(?:سمك|اسماك|قد|بولك|ماكريل|اسقمري|سردين|رنجه|هلبوت)(?![\p{L}])|white ?fish|cod|pollock|mackerel|sardine|herring|whitefish|ocean fish/u',
        'beef'    => '/لحم بقري|بقري|لحم البقر|لحم عجل|beef|veal/u',
        'lamb'    => '/ضان|غنم|خروف|لحم ضان|lamb|mutton/u',
        'duck'    => '/(?:^|[^\p{L}])(?:[وبلف])?(?:ال)?بط(?![\p{L}])|duck/u',
        'turkey'  => '/ديك رومي|الرومي|turkey/u',
        'rabbit'  => '/(?:^|[^\p{L}])(?:[وبلف])?(?:ال)?ارنب(?![\p{L}])|rabbit/u',
        'shrimp'  => '/روبيان|جمبري|قريدس|shrimp|prawn/u',
    ];

    /** value => [regex, only for food] */
    private const NEED_RULES = [
        'grain_free' => ['/خالي من الحبوب|خاليه من الحبوب|بدون حبوب|بدون الحبوب|grain[ -]?free/u', true],
        'sterilised' => ['/معقم|sterili[sz]ed|neutered|مخصي/u', true],
        'urinary'    => ['/(?:^|[^\p{L}])(?:[وبلف])?(?:ال)?بولي(?:ه)?(?![\p{L}])|المسالك|urinary/u', false],
        'hairball'   => ['/كرات الشعر|كرات شعر|hairball/u', false],
        'weight'     => ['/التحكم في الوزن|التحكم بالوزن|(?<!وجبه )(?<!وجبات )خفيف|لايت|(?:^|[^\p{L}])light(?![\p{L}])|سمنه|weight/u', true],
        'digest'     => ['/هضم|هضمي|الهضمي|المعده|معده حساسه|sensitive digest|digest|gastro/u', false],
        'hypo'       => ['/حساسيه|هيبوالرجينيك|هايبو|hypoallergenic|hypo[ -]?allergenic|مضاد للحساسيه/u', false],
        'skin'       => ['/(?:^|[^\p{L}])(?:[وبلف])?(?:ال)?(?:جلد|فرو|فراء)(?![\p{L}])|تساقط الشعر|skin|(?:^|[^\p{L}])coat(?![\p{L}])/u', false],
        'dental'     => ['/اسنان|الاسنان|الفم|اللثه|dental|teeth|tartar/u', false],
        'indoor'     => ['/داخلي|داخل المنزل|المنزليه|indoor/u', true],
        'joints'     => ['/مفاصل|المفاصل|joint/u', false],
        'calm'       => ['/تهدئه|مهدئ|القلق|التوتر|calm/u', false],
    ];

    /* ══════════════════════════════════════════════════════════════
       VOCABULARY — labels and sticker keys (the app draws the stickers)
       ══════════════════════════════════════════════════════════════ */

    /** @return array{0:string,1:string} [ar, en] */
    private static function group_label(string $facet): array
    {
        return [
            'line'    => ['خطوط البراند', 'Product line'],
            'dept'    => ['القسم', 'Department'],
            'form'    => ['شكل الطعام', 'Food type'],
            'texture' => ['القوام', 'Texture'],
            'life'    => ['العمر', 'Life stage'],
            'flavor'  => ['النكهة', 'Flavour'],
            'need'    => ['احتياج خاص', 'Special needs'],
            'brand'   => ['العلامة', 'Brand'],
            'pack'    => ['العبوة', 'Pack'],
            'offer'   => ['العروض', 'Offers'],
            'species' => ['الأليف', 'Pet'],
            'price'   => ['السعر', 'Price'],
        ][$facet] ?? [$facet, $facet];
    }

    /** Group sticker. */
    private static function group_icon(string $facet, string $species): string
    {
        return [
            'line'    => 'brand',
            'dept'    => 'food',
            'form'    => 'pouch',
            'texture' => 'pate',
            'life'    => $species === 'dog' ? 'puppy' : 'kitten',
            'flavor'  => 'chicken',
            'need'    => 'sterilised',
            'brand'   => 'brand',
            'pack'    => 'carton',
            'offer'   => 'sale',
            'species' => 'all',
            'price'   => 'price',
        ][$facet] ?? 'star';
    }

    /**
     * A value's [ar, en, icon, sub-ar, sub-en].
     *
     * @return array{0:string,1:string,2:?string,3:?string,4:?string}
     */
    private static function value_meta(string $facet, string $value, string $species): array
    {
        if ($facet === 'life') {
            $young = [
                'cat'   => ['قطط صغيرة', 'Kitten', 'kitten', 'حتى 12 شهرًا', 'Up to 12 months'],
                'dog'   => ['جراء', 'Puppy', 'puppy', 'حتى 12 شهرًا', 'Up to 12 months'],
                'bird'  => ['فراخ', 'Chicks', null, 'تغذية يدوية وصغار', 'Hand-feeding and young'],
                'small' => ['صغار', 'Young', null, null, null],
            ][$species] ?? ['صغار', 'Young', 'kitten', null, null];
            $adult = [
                'cat' => ['بالغة', 'Adult', 'cat_adult', 'من سنة إلى 7 سنوات', '1 to 7 years'],
                'dog' => ['بالغة', 'Adult', 'dog_adult', 'من سنة إلى 7 سنوات', '1 to 7 years'],
            ][$species] ?? ['بالغ', 'Adult', $species === 'dog' ? 'dog_adult' : ($species === 'cat' ? 'cat_adult' : null), null, null];
            $senior = [
                'cat' => ['كبيرة السن', 'Senior', 'cat_senior', 'أكثر من 7 سنوات', '7 years and up'],
                'dog' => ['كبيرة السن', 'Senior', 'dog_senior', 'أكثر من 7 سنوات', '7 years and up'],
            ][$species] ?? ['كبار السن', 'Senior', null, null, null];
            return ['young' => $young, 'adult' => $adult, 'senior' => $senior][$value] ?? [$value, $value, null, null, null];
        }
        if ($facet === 'line') {
            $label = class_exists('Zooboxi_Brand_Kit') ? Zooboxi_Brand_Kit::line_label($value) : null;
            return $label ? [$label[0], $label[1], null, null, null] : [$value, $value, null, null, null];
        }
        if ($facet === 'brand') {
            $names = self::brand_names();
            $name  = $names[$value] ?? $value;
            return [$name, $name, null, null, null];
        }
        if ($facet === 'species') {
            return [
                'cat'   => ['قطط', 'Cats', 'cat_adult', null, null],
                'dog'   => ['كلاب', 'Dogs', 'dog_adult', null, null],
                'bird'  => ['طيور', 'Birds', 'bird', null, null],
                'small' => ['حيوانات صغيرة', 'Small pets', 'small', null, null],
            ][$value] ?? [$value, $value, null, null, null];
        }
        $map = [
            'dept' => [
                'food'    => ['الطعام', 'Food', 'food', null, null],
                'treat'   => ['المكافآت', 'Treats', 'treat', null, null],
                'health'  => ['الصحة والفيتامينات', 'Health & vitamins', 'health', null, null],
                'litter'  => ['الرمل والنشارة', 'Litter & bedding', 'litter', null, null],
                'toy'     => ['الألعاب والخدّاشات', 'Toys & scratchers', 'toy', null, null],
                'bed'     => ['البيوت والأسرّة', 'Beds & houses', 'bed', null, null],
                'collar'  => ['الأطواق والمشدّات', 'Collars & harnesses', 'collar', null, null],
                'bowl'    => ['أوعية الأكل والشرب', 'Bowls & feeders', 'bowl', null, null],
                'groom'   => ['العناية والنظافة', 'Grooming & care', 'groom', null, null],
                'carrier' => ['حقائب التنقل', 'Carriers', 'carrier', null, null],
                'bundle'  => ['البكجات', 'Bundles', 'bundle', null, null],
            ],
            'form' => [
                'wet'   => ['رطب', 'Wet', 'pouch', 'أظرف ومعلبات وباتيه', 'Pouches, cans and pâté'],
                'dry'   => ['جاف', 'Dry', 'dry', null, null],
                'milk'  => ['حليب', 'Milk', 'milk', null, null],
                'treat' => ['مكافآت', 'Treats', 'treat', null, null],
            ],
            'texture' => [
                'pouch' => ['أظرف', 'Pouches', 'pouch', null, null],
                'can'   => ['معلبات', 'Cans', 'wet', null, null],
                'pate'  => ['باتيه ومهروس', 'Pâté and mousse', 'pate', null, null],
                'gravy' => ['في المرق', 'In gravy', 'gravy', null, null],
                'jelly' => ['في الجيلي', 'In jelly', 'jelly', null, null],
            ],
            'flavor' => [
                'chicken' => ['دجاج', 'Chicken', 'chicken', null, null],
                'tuna'    => ['تونة', 'Tuna', 'tuna', null, null],
                'salmon'  => ['سلمون', 'Salmon', 'salmon', null, null],
                'fish'    => ['أسماك أخرى', 'Other fish', 'fish_any', 'قد، بولك، سردين…', 'Cod, pollock, sardine…'],
                'beef'    => ['لحم بقري', 'Beef', 'beef', null, null],
                'lamb'    => ['ضأن', 'Lamb', 'lamb', null, null],
                'duck'    => ['بط', 'Duck', 'duck', null, null],
                'turkey'  => ['ديك رومي', 'Turkey', 'turkey', null, null],
                'rabbit'  => ['أرنب', 'Rabbit', null, null, null],
                'shrimp'  => ['روبيان', 'Shrimp', 'shrimp', null, null],
            ],
            'need' => [
                'grain_free' => ['خالٍ من الحبوب', 'Grain free', 'grain_free', null, null],
                'sterilised' => ['للمعقّمة', 'Sterilised', 'sterilised', null, null],
                'urinary'    => ['المسالك البولية', 'Urinary care', 'urinary', null, null],
                'hairball'   => ['كرات الشعر', 'Hairball', 'hairball', null, null],
                'weight'     => ['التحكم بالوزن', 'Weight control', 'light', null, null],
                'digest'     => ['هضم حساس', 'Sensitive digestion', 'digest', null, null],
                'hypo'       => ['الحساسية', 'Hypoallergenic', 'hypo', null, null],
                'skin'       => ['الجلد والفرو', 'Skin and coat', 'brush', null, null],
                'dental'     => ['الأسنان', 'Dental', 'tooth', null, null],
                'indoor'     => ['داخل المنزل', 'Indoor', 'indoor', null, null],
                'joints'     => ['المفاصل', 'Joints', 'treat', null, null],
                'calm'       => ['التهدئة', 'Calming', 'moon', null, null],
            ],
            'pack' => [
                'carton' => ['متوفر بالكرتون', 'Sold by the carton', 'carton', 'اختر الحبة أو الكرتون في صفحة المنتج', 'Choose piece or carton on the product'],
            ],
            'offer' => [
                'sale'   => ['عليه خصم', 'On sale', 'sale', null, null],
                'bundle' => ['ضمن بكج', 'In a bundle', 'bundle', null, null],
                'new'    => ['وصل حديثًا', 'New in', 'star', 'آخر 30 يومًا', 'Last 30 days'],
            ],
        ];
        return $map[$facet][$value] ?? [$value, $value, null, null, null];
    }

    /** @return array<string,string> */
    private static function brand_names(): array
    {
        static $names = null;
        if ($names === null) {
            $names = get_option('zooboxi_facet_brand_names', []);
            if (!is_array($names)) {
                $names = [];
            }
        }
        return $names;
    }

    /** Order of values inside a group: the vocabulary's own order for small fixed sets. */
    private const FIXED_ORDER = [
        'life'    => ['young', 'adult', 'senior'],
        'form'    => ['wet', 'dry', 'milk', 'treat'],
        'texture' => ['pouch', 'can', 'pate', 'gravy', 'jelly'],
        'offer'   => ['sale', 'bundle', 'new'],
        'species' => ['cat', 'dog', 'bird', 'small'],
    ];

    /* ══════════════════════════════════════════════════════════════
       QUERY
       ══════════════════════════════════════════════════════════════ */

    /**
     * Load the index rows for a scope.
     *
     * @param int[] $ids
     * @return array{0:array<int,array<string,array<string,bool>>>,1:array<int,array>}
     */
    private static function load(array $ids): array
    {
        global $wpdb;
        $facets = [];
        $meta   = [];
        if (empty($ids)) {
            return [$facets, $meta];
        }
        foreach (array_chunk($ids, 2000) as $chunk) {
            $list = implode(',', array_map('intval', $chunk));
            foreach ($wpdb->get_results("SELECT product_id, facet, value FROM " . self::table() . " WHERE product_id IN ({$list})", ARRAY_N) as [$pid, $facet, $value]) {
                $facets[(int) $pid][$facet][$value] = true;
            }
            foreach ($wpdb->get_results("SELECT product_id, price, price_express, per_kg, discount, instock FROM " . self::meta_table() . " WHERE product_id IN ({$list})", ARRAY_A) as $m) {
                $meta[(int) $m['product_id']] = $m;
            }
        }
        return [$facets, $meta];
    }

    /**
     * Answer a listing.
     *
     * @param int[]                        $base      ids already scoped by the listing (category, shelf, search, rail)
     * @param array<string,string[]>       $selected  facet => values
     * @param array{min:?float,max:?float} $price     selected price window
     * @param string                       $species   the listing's species ('' when mixed)
     * @param bool                         $express   price the express shelf
     * @return array{ids:int[], facets:array, meta:array<int,array>}
     */
    public static function search(array $base, array $selected, array $price, string $species, bool $express, string $lang, bool $wholeStore = false): array
    {
        self::ensure();
        [$rows, $meta] = self::load($base);
        return self::answer($base, $rows, $meta, $selected, $price, $species, $express, $lang, $wholeStore);
    }

    /**
     * The pure half of search(): no database, so it can be exercised on an
     * in-memory classification.
     */
    public static function answer(array $base, array $rows, array $meta, array $selected, array $price, string $species, bool $express, string $lang, bool $wholeStore = false): array
    {
        $en  = $lang === 'en';
        $sel = [];
        foreach (self::FACETS as $facet) {
            $vals = array_values(array_unique(array_filter(array_map('strval', $selected[$facet] ?? []))));
            if (!empty($vals)) {
                $sel[$facet] = array_fill_keys($vals, true);
            }
        }
        $pmin = isset($price['min']) && $price['min'] !== null ? (float) $price['min'] : null;
        $pmax = isset($price['max']) && $price['max'] !== null ? (float) $price['max'] : null;
        $hasPrice = $pmin !== null || $pmax !== null;
        $pkey = $express ? 'price_express' : 'price';

        // Which selections each product fails ('price' included). A product counts
        // toward facet F exactly when it fails nothing but (at most) F.
        $fails = [];
        $prices = [];
        foreach ($base as $pid) {
            $pv = isset($meta[$pid]) ? (float) $meta[$pid][$pkey] : 0.0;
            $prices[$pid] = $pv;
            $miss = [];
            foreach ($sel as $facet => $vals) {
                if (empty(array_intersect_key($rows[$pid][$facet] ?? [], $vals))) {
                    $miss[] = $facet;
                }
            }
            if ($hasPrice && (($pmin !== null && $pv < $pmin) || ($pmax !== null && $pv > $pmax))) {
                $miss[] = 'price';
            }
            $fails[$pid] = $miss;
        }

        $matched = [];
        foreach ($fails as $pid => $miss) {
            if (empty($miss)) {
                $matched[] = $pid;
            }
        }

        // The pet the labels speak of: the listing's own, else the one pet picked.
        $context = $species;
        $speakAs = $species !== '' ? $species : (isset($sel['species']) && count($sel['species']) === 1 ? (string) array_key_first($sel['species']) : '');

        // Food facets wait until the list is about food: on «كل المنتجات» an age
        // would hide every toy and litter box (قطط 2,026 → صغار 78). They open
        // when a food shelf is picked, when a food value already is, or when
        // most of the scope is food anyway (a food aisle, a «تونة» search).
        $foodPicked = !empty(array_intersect(array_keys($sel), self::FOOD_FACETS))
            || isset($sel['dept']['food']) || isset($sel['dept']['treat']);
        $edibleInBase = 0;
        foreach ($base as $pid) {
            if (!empty($rows[$pid]['form'])) {
                $edibleInBase++;
            }
        }
        // «كل المنتجات» always waits: on the express shelf food is most of the
        // stock, and an age tapped there would still empty the toys and litter.
        $foodGated = !$foodPicked && !empty($base) && ($wholeStore || $edibleInBase < count($base) * 0.5);

        // A brand's lines only mean something on that brand's own shelf.
        $brandsInBase = [];
        foreach ($base as $pid) {
            foreach (array_keys($rows[$pid]['brand'] ?? []) as $b) {
                $brandsInBase[$b] = true;
            }
        }

        // ── Groups.
        $groups = [];
        $species = $speakAs; // every label below speaks of the chosen pet
        foreach (self::FACETS as $facet) {
            if ($facet === 'species' && $context !== '') {
                continue; // a cat aisle does not ask «which pet?»
            }
            if ($foodGated && in_array($facet, self::FOOD_FACETS, true)) {
                continue;
            }
            if ($facet === 'line' && count($brandsInBase) !== 1 && empty($sel['line'])) {
                continue;
            }
            $count = [];   // with the other selections
            $inBase = [];  // anywhere in this scope
            foreach ($base as $pid) {
                $vals = $rows[$pid][$facet] ?? null;
                if (!$vals) {
                    continue;
                }
                $miss = $fails[$pid];
                $ok   = empty($miss) || $miss === [$facet];
                foreach ($vals as $v => $_) {
                    $inBase[$v] = ($inBase[$v] ?? 0) + 1;
                    if ($ok) {
                        $count[$v] = ($count[$v] ?? 0) + 1;
                    }
                }
            }

            $selHere = $sel[$facet] ?? [];
            $live = array_filter($count);
            if (count($inBase) < self::MIN_GROUP_VALUES && empty($selHere)) {
                // One value in the whole scope is not a choice — unless it is a
                // yes/no facet (pack, offer) that still splits the list.
                $single = (int) reset($inBase);
                if (!in_array($facet, ['pack', 'offer'], true) || $single === 0 || $single >= count($base)) {
                    continue;
                }
            }

            // Values: the fixed vocabularies in their own order, the rest by count.
            $keys = array_keys($inBase);
            if (isset(self::FIXED_ORDER[$facet])) {
                $keys = array_values(array_intersect(self::FIXED_ORDER[$facet], $keys));
            } else {
                usort($keys, static function ($a, $b) use ($count, $inBase) {
                    return [($count[$b] ?? 0), $inBase[$b]] <=> [($count[$a] ?? 0), $inBase[$a]];
                });
            }

            $values = [];
            foreach ($keys as $v) {
                [$ar, $enL, $icon, $subAr, $subEn] = self::value_meta($facet, (string) $v, $species);
                $n = (int) ($count[$v] ?? 0);
                $row = [
                    'key'      => (string) $v,
                    'label'    => $en ? $enL : $ar,
                    'count'    => $n,
                    'icon'     => $icon,
                    'sub'      => $en ? $subEn : $subAr,
                    'selected' => isset($selHere[$v]),
                ];
                if ($facet === 'dept' && isset(self::DEPT_SHORT[$v])) {
                    $row['short'] = self::DEPT_SHORT[$v][$en ? 1 : 0];
                }
                if ($facet === 'species' && $v === 'small') {
                    $row['short'] = $en ? 'Small' : 'صغيرة'; // a fifth of a phone
                }
                if ($n === 0 && !isset($selHere[$v])) {
                    $row['note'] = self::why_empty($facet, (string) $v, $rows, $fails, $sel, $species, $en);
                }
                $values[] = $row;
            }

            // A group earns its place only if it can still split the list:
            // two live values, or one that not every product carries. «رطب»
            // inside the wet aisle, or needs that are all empty for a kitten,
            // are noise.
            if (empty($selHere)) {
                $liveVals = array_filter($values, static fn($v) => $v['count'] > 0);
                if (empty($liveVals)) {
                    continue;
                }
                if (count($liveVals) === 1) {
                    $pool = 0;
                    foreach ($base as $pid) {
                        $miss = $fails[$pid];
                        if (empty($miss) || $miss === [$facet]) {
                            $pool++;
                        }
                    }
                    if ((int) reset($liveVals)['count'] >= $pool) {
                        continue;
                    }
                }
            }

            [$gar, $gen] = self::group_label($facet);
            $groups[] = [
                'key'      => $facet,
                'label'    => $en ? $gen : $gar,
                'icon'     => self::group_icon($facet, $species),
                'multi'    => true,
                'selected' => count($selHere),
                'search'   => $facet === 'brand' && count($values) > 8,
                'values'   => $values,
            ];
        }

        // ── Price: the window's own histogram, from everything but the price itself.
        $pool = [];
        foreach ($base as $pid) {
            $miss = $fails[$pid];
            if ((empty($miss) || $miss === ['price']) && $prices[$pid] > 0) {
                $pool[] = $prices[$pid];
            }
        }
        $priceFacet = self::price_facet($pool, $pmin, $pmax, $en);

        // ── Relax: what removing one selection brings back.
        $relax = [];
        foreach ($sel as $facet => $vals) {
            foreach ($vals as $v => $_) {
                $rest = $vals;
                unset($rest[$v]);
                $n = 0;
                foreach ($base as $pid) {
                    $miss = $fails[$pid];
                    if (empty($miss)) {
                        $n++;
                        continue;
                    }
                    if ($miss !== [$facet]) {
                        continue;
                    }
                    if (empty($rest) || !empty(array_intersect_key($rows[$pid][$facet] ?? [], $rest))) {
                        $n++;
                    }
                }
                [$ar, $enL] = self::value_meta($facet, (string) $v, $species);
                $relax[] = ['group' => $facet, 'value' => (string) $v, 'label' => $en ? $enL : $ar, 'count' => $n];
            }
        }
        if ($hasPrice) {
            $n = 0;
            foreach ($fails as $miss) {
                if (empty($miss) || $miss === ['price']) {
                    $n++;
                }
            }
            $relax[] = ['group' => 'price', 'value' => '', 'label' => $en ? 'Price' : 'السعر', 'count' => $n];
        }

        // What the gate is holding back, and the one tap that opens it.
        $locked = null;
        if ($foodGated && $edibleInBase > 0) {
            $foodCount = 0;
            foreach ($groups as $g) {
                if ($g['key'] === 'dept') {
                    foreach ($g['values'] as $v) {
                        if ($v['key'] === 'food') {
                            $foodCount = (int) $v['count'];
                        }
                    }
                }
            }
            if ($foodCount > 0) {
                $names = [];
                foreach (['life', 'flavor', 'texture'] as $k) {
                    $names[] = self::group_label($k)[$en ? 1 : 0];
                }
                $locked = [
                    'groups' => self::FOOD_FACETS,
                    'label'  => implode(' · ', $names),
                    'hint'   => $en ? 'Show up when you pick food' : 'تظهر عند اختيار الطعام',
                    'unlock' => ['group' => 'dept', 'value' => 'food', 'count' => $foodCount],
                ];
            }
        }

        return [
            'ids'    => $matched,
            'meta'   => $meta,
            'facets' => [
                'v'          => 2,
                'species'    => $context !== '' ? $context : null,
                'speak_as'   => $speakAs !== '' ? $speakAs : null,
                'base_total' => count($base),
                'groups'     => $groups,
                'price'      => $priceFacet,
                'promoted'   => self::promoted($groups, $foodGated),
                'relax'      => $relax,
                'locked'     => $locked,
            ],
        ];
    }

    /**
     * Why a value in this scope has nothing with your picks: the ONE other
     * pick that, removed, would bring it back («غير متوفر مع قطط صغيرة»).
     */
    private static function why_empty(string $facet, string $value, array $rows, array $fails, array $sel, string $species, bool $en): string
    {
        foreach ($sel as $other => $vals) {
            if ($other === $facet) {
                continue;
            }
            foreach ($fails as $pid => $miss) {
                if (!isset($rows[$pid][$facet][$value])) {
                    continue;
                }
                $rest = array_diff($miss, [$facet, $other]);
                if (empty($rest)) {
                    $names = [];
                    foreach (array_keys($vals) as $v) {
                        $names[] = self::value_meta($other, (string) $v, $species)[$en ? 1 : 0];
                    }
                    $joined = implode($en ? ' / ' : ' / ', $names);
                    return $en ? "Not available with {$joined}" : "غير متوفر مع {$joined}";
                }
            }
        }
        return $en ? 'Not available with your choices' : 'غير متوفر مع اختياراتك';
    }

    /** Nice round edges for a riyal scale. */
    private static function nice(float $v): float
    {
        $steps = [5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 100, 125, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000, 3000, 5000];
        foreach ($steps as $s) {
            if ($v <= $s) {
                return (float) $s;
            }
        }
        return (float) (ceil($v / 1000) * 1000);
    }

    /**
     * Histogram + quantile buckets of the prices in THIS window — so the
     * scale is 5 → 190 ﷼ in kitten food, not 1.9 → 3,910 for the store.
     */
    private static function price_facet(array $pool, ?float $pmin, ?float $pmax, bool $en): ?array
    {
        if (count($pool) < 4) {
            return ($pmin !== null || $pmax !== null)
                ? ['min' => 0, 'max' => 0, 'histogram' => [], 'buckets' => [], 'selected' => ['min' => $pmin, 'max' => $pmax]]
                : null;
        }
        sort($pool);
        $n   = count($pool);
        $q   = static fn(float $p) => $pool[(int) min($n - 1, max(0, floor($p * ($n - 1))))];
        $lo  = floor($pool[0]);
        $hi  = ceil($q(0.97));
        if ($hi <= $lo) {
            $hi = ceil($pool[$n - 1]);
        }
        if ($hi <= $lo) {
            return null;
        }

        $bins = 16;
        $w    = ($hi - $lo) / $bins;
        $hist = array_fill(0, $bins, 0);
        foreach ($pool as $v) {
            $i = (int) floor(($v - $lo) / $w);
            $hist[max(0, min($bins - 1, $i))]++;
        }
        $histogram = [];
        for ($i = 0; $i < $bins; $i++) {
            $histogram[] = ['from' => round($lo + $i * $w, 2), 'to' => round($lo + ($i + 1) * $w, 2), 'count' => $hist[$i]];
        }

        // Four buckets at rounded quartiles; merged when two land on one edge.
        $edges = [];
        foreach ([0.25, 0.5, 0.75] as $p) {
            $e = self::nice($q($p));
            if (($edges ? end($edges) : 0) < $e && $e < $pool[$n - 1]) {
                $edges[] = $e;
            }
        }
        $buckets = [];
        $prev    = null;
        foreach (array_merge($edges, [null]) as $edge) {
            $c = 0;
            foreach ($pool as $v) {
                if (($prev === null || $v >= $prev) && ($edge === null || $v < $edge)) {
                    $c++;
                }
            }
            $fmt = static fn($x) => (string) (int) round((float) $x);
            if ($prev === null) {
                $label = $en ? 'Under ' . $fmt($edge) : 'أقل من ' . $fmt($edge);
            } elseif ($edge === null) {
                $label = $fmt($prev) . '+';
            } else {
                $label = $fmt($prev) . ' – ' . $fmt($edge);
            }
            $buckets[] = ['min' => $prev, 'max' => $edge, 'label' => $label, 'count' => $c];
            $prev = $edge;
        }

        return [
            'min'       => (float) $lo,
            'max'       => (float) ceil($pool[$n - 1]),
            'histogram' => $histogram,
            'buckets'   => $buckets,
            'selected'  => ['min' => $pmin, 'max' => $pmax],
        ];
    }

    /**
     * The handful of values worth a chip above the list: every life stage,
     * the three strongest flavours, the carton, a live sale.
     */
    private static function promoted(array $groups, bool $foodGated = false): array
    {
        $by = [];
        foreach ($groups as $g) {
            $by[$g['key']] = $g;
        }
        $out  = [];
        $take = static function (string $facet, int $limit) use (&$out, $by) {
            if (empty($by[$facet])) {
                return;
            }
            $vals = array_filter($by[$facet]['values'], static fn($v) => $v['count'] > 0 || $v['selected']);
            // A chosen age speaks for the group: the other ages are not a
            // tap anyone wants next to it.
            if ($facet === 'life' && !empty(array_filter($vals, static fn($v) => $v['selected']))) {
                $vals = array_filter($vals, static fn($v) => $v['selected']);
            }
            if ($facet === 'flavor') {
                usort($vals, static fn($a, $b) => $b['count'] <=> $a['count']);
            }
            foreach (array_slice(array_values($vals), 0, $limit) as $v) {
                $out[] = ['group' => $facet, 'value' => $v['key'], 'label' => $v['label'], 'icon' => $v['icon'], 'count' => $v['count'], 'selected' => $v['selected']];
            }
        };
        if ($foodGated) {
            $take('brand', 3); // no ages or flavours to offer yet: the brands people reach for
        }
        $take('life', 3);
        $take('texture', 2);
        $take('flavor', 3);
        $take('pack', 1);
        if (!empty($by['offer'])) {
            foreach ($by['offer']['values'] as $v) {
                if ($v['key'] === 'sale' && ($v['count'] > 0 || $v['selected'])) {
                    $out[] = ['group' => 'offer', 'value' => 'sale', 'label' => $v['label'], 'icon' => $v['icon'], 'count' => $v['count'], 'selected' => $v['selected']];
                }
            }
        }
        return array_slice($out, 0, 8);
    }
}
