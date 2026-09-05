<?php
/**
 * Zooboxi_Loyalty_Supply — «عدّاد الأكل»: when does each pet's food run out?
 *
 * THE THESIS OF THE WHOLE PROGRAM lives here: the app knows the customer's pet and
 * knows when its food runs out, and makes reordering easier than any alternative. The
 * currency and the games sit on top of this.
 *
 * HOW THE FORECAST WORKS (spec §2):
 *   1. Every consumable the customer bought in the last year is a line: last purchase,
 *      quantity, pack size, the pet it feeds.
 *   2. A PRIOR comes from a feeding table (grams/day by species and food kind) and the
 *      pack size — "a 2 kg bag at 48 g/day lasts 41 days".
 *   3. The customer's OWN history corrects it: the gaps between their purchases of the
 *      same product, and every «خلص» tap, are observations. The estimate is a simple
 *      Bayesian blend — the prior counts as one observation, so two real gaps already
 *      outweigh it. With no prior at all, the observations stand alone; with nothing at
 *      all, thirty days.
 *   4. Projection: last purchase + qty × cycle. A «خلص» after the last purchase says
 *      "now"; «عندي كفاية» pushes the date out.
 *
 * Everything is cached per customer for fifteen minutes (`zb_supply_{uid}`) and busted
 * on every order status change, supply event and pet save. Days-left is computed at
 * read time from the cached run-out timestamp, so the cache never shows a stale "6
 * days" at midnight.
 *
 * The on-time bonus (+20%) is stamped on the order at checkout — the customer must be
 * rewarded for the window they ordered IN, not for the window the order is delivered in.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Supply
{
    private const TTL         = 900;   // 15 min
    private const ORDER_SCAN  = 40;
    private const MAX_ITEMS   = 12;
    private const MIN_CYCLE   = 2.0;   // days per unit
    private const MAX_CYCLE   = 180.0;
    private const FALLBACK    = 30.0;

    public const KINDS = ['dry', 'wet', 'litter', 'treat', 'other', 'hardware'];

    /** Order meta: JSON list of product ids that were inside their on-time window. */
    public const ON_TIME_META = '_zb_on_time_products';

    /** Shipped defaults — the owner edits these as JSON in the admin «العادة» tab. */
    public const DEFAULT_FEEDING = [
        'cat'     => [
            'dry'    => ['per_kg' => 12, 'default_kg' => 4],
            'wet'    => ['per_kg' => 30, 'default_kg' => 4],
            'litter' => ['flat' => 500],
            'treat'  => ['flat' => 3],
        ],
        'dog'     => [
            'dry'    => ['per_kg' => 25, 'default_kg' => 12, 'tiers' => [[10, 30], [25, 25], [999, 20]]],
            'wet'    => ['per_kg' => 40, 'default_kg' => 12],
            'treat'  => ['flat' => 8],
        ],
        'bird'    => ['dry' => ['flat' => 30], 'treat' => ['flat' => 5]],
        'small'   => ['dry' => ['flat' => 60], 'litter' => ['flat' => 250], 'treat' => ['flat' => 5]],
        'fish'    => ['dry' => ['flat' => 1]],
        'reptile' => ['dry' => ['flat' => 5]],
    ];

    /** Category ids whose descendants are "food" / "treats" (the live store's tree). */
    public const DEFAULT_FOOD_CATS  = [108, 115, 247, 8649, 8773, 8671];
    public const DEFAULT_TREAT_CATS = [132, 174, 8685, 8805];
    public const DEFAULT_SPECIES_ROOTS = ['cat' => 107, 'dog' => 114, 'bird' => 202, 'small' => 194];

    /** Per-request memos. */
    private static array $rows_memo    = [];
    private static array $ancestors    = [];
    private static array $product_kind = [];

    /* ══════════════════════════════════════════════════════════════
       CONFIG
       ══════════════════════════════════════════════════════════════ */

    public static function enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('supply_enabled', 'yes') === 'yes';
    }

    public static function window(): array
    {
        return [
            'before' => max(0, Zooboxi_Loyalty::opt_int('on_time_before', 7)),
            'after'  => max(0, Zooboxi_Loyalty::opt_int('on_time_after', 3)),
        ];
    }

    public static function feeding_table(): array
    {
        $table = Zooboxi_Loyalty::opt_json('feeding_table', []);
        return empty($table) ? self::DEFAULT_FEEDING : $table;
    }

    private static function id_list(string $key, array $default): array
    {
        $raw = Zooboxi_Loyalty::opt($key, '');
        if (is_array($raw)) {
            return array_map('intval', $raw);
        }
        $raw = trim((string) $raw);
        if ($raw === '') {
            return $default;
        }
        $out = [];
        foreach (preg_split('/[\s,]+/', $raw) as $part) {
            if (is_numeric($part) && (int) $part > 0) {
                $out[] = (int) $part;
            }
        }
        return $out ?: $default;
    }

    public static function food_cats(): array
    {
        return self::id_list('supply_food_cats', self::DEFAULT_FOOD_CATS);
    }

    public static function treat_cats(): array
    {
        return self::id_list('supply_treat_cats', self::DEFAULT_TREAT_CATS);
    }

    /** @return array<string,int> species => root category id */
    public static function species_roots(): array
    {
        $map = Zooboxi_Loyalty::opt_json('species_roots', []);
        $out = [];
        foreach ($map as $species => $id) {
            if ((int) $id > 0) {
                $out[(string) $species] = (int) $id;
            }
        }
        return $out ?: self::DEFAULT_SPECIES_ROOTS;
    }

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    /**
     * The customer's supply lines, soonest run-out first.
     *
     * @return array<int,array> internal rows (see build())
     */
    public static function items(int $user_id, bool $fresh = false): array
    {
        if ($user_id <= 0 || !self::enabled()) {
            return [];
        }
        if (!$fresh && isset(self::$rows_memo[$user_id])) {
            return self::$rows_memo[$user_id];
        }

        $key = 'zb_supply_' . $user_id;
        if (!$fresh) {
            $cached = get_transient($key);
            if (is_array($cached) && ($cached['_v'] ?? 0) === 2) {
                return self::$rows_memo[$user_id] = $cached['rows'];
            }
        }

        try {
            $rows = self::build($user_id);
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] supply build failed: ' . $e->getMessage());
            $rows = [];
        }

        set_transient($key, ['_v' => 2, 'rows' => $rows], self::TTL);
        return self::$rows_memo[$user_id] = $rows;
    }

    public static function flush(int $user_id): void
    {
        unset(self::$rows_memo[$user_id]);
        delete_transient('zb_supply_' . $user_id);
    }

    /** One line by product (+ variation), or null. */
    public static function find(int $user_id, int $product_id, int $variation_id = 0): ?array
    {
        foreach (self::items($user_id) as $row) {
            if ((int) $row['product_id'] === $product_id
                && ($variation_id <= 0 || (int) $row['variation_id'] === $variation_id)) {
                return $row;
            }
        }
        return null;
    }

    /** Lines whose window is open right now (drives the on-time stamp). */
    public static function on_time_ids(int $user_id): array
    {
        $out = [];
        foreach (self::items($user_id) as $row) {
            $state = self::state_of($row);
            if ($state['on_time']) {
                $out[(int) $row['product_id']] = true;
            }
        }
        return array_keys($out);
    }

    /* ══════════════════════════════════════════════════════════════
       BUILD
       ══════════════════════════════════════════════════════════════ */

    private static function build(int $user_id): array
    {
        if (!function_exists('wc_get_orders')) {
            return [];
        }

        $orders = wc_get_orders([
            'customer_id'  => $user_id,
            'status'       => ['completed', 'processing', 'zb-ready'],
            'date_created' => '>' . (time() - 365 * DAY_IN_SECONDS),
            'limit'        => self::ORDER_SCAN,
            'orderby'      => 'date',
            'order'        => 'DESC',
        ]);

        /** @var array<string,array> $lines key "pid:vid" => data */
        $lines = [];
        foreach ((array) $orders as $order) {
            if (!($order instanceof \WC_Order)) {
                continue;
            }
            $created = $order->get_date_created();
            $ts      = $created ? (int) $created->getTimestamp() : 0;
            if ($ts <= 0) {
                continue;
            }
            foreach ($order->get_items() as $item) {
                if (!($item instanceof \WC_Order_Item_Product)) {
                    continue;
                }
                if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                    continue; // a gift is not a purchase rhythm
                }
                $pid = (int) $item->get_product_id();
                $vid = (int) $item->get_variation_id();
                if ($pid <= 0 || get_post_status($pid) !== 'publish') {
                    continue;
                }
                $key = $pid . ':' . $vid;
                if (!isset($lines[$key])) {
                    $lines[$key] = [
                        'product_id'   => $pid,
                        'variation_id' => $vid,
                        'name'         => (string) $item->get_name(),
                        'purchases'    => [],
                    ];
                }
                $lines[$key]['purchases'][] = ['ts' => $ts, 'qty' => max(1, (int) $item->get_quantity())];
            }
        }
        if (empty($lines)) {
            return [];
        }

        $events = self::events($user_id);
        $pets   = Zooboxi_Loyalty_Pets::all($user_id);
        $now    = time();
        $rows   = [];

        foreach ($lines as $line) {
            $pid  = (int) $line['product_id'];
            $vid  = (int) $line['variation_id'];
            $kind = self::kind_of($pid, $line['name']);

            usort($line['purchases'], static fn ($a, $b) => $a['ts'] <=> $b['ts']);
            $purchases = $line['purchases'];
            $n_buys    = count($purchases);

            if ($kind === 'hardware') {
                continue; // a bowl, a leash, a bed — never runs out
            }
            if ($kind === 'other' && $n_buys < 2) {
                continue; // not a consumable we can say anything about
            }

            $product = wc_get_product($vid > 0 ? $vid : $pid);
            if (!($product instanceof \WC_Product)) {
                continue;
            }
            $parent = $vid > 0 ? wc_get_product($pid) : $product;
            $pack   = self::pack_kg($product, $parent instanceof \WC_Product ? $parent : null);

            $species = self::species_of_product($pid);
            $pet     = self::pick_pet($pets, $species);
            if ($species === '' && $pet !== null) {
                $species = (string) $pet['species'];
            }

            $prior = self::prior_days($species, $kind, $pack, $pet);

            // Observations: gaps between consecutive purchases, per unit bought.
            $observed = [];
            for ($i = 1; $i < $n_buys; $i++) {
                $gap = ($purchases[$i]['ts'] - $purchases[$i - 1]['ts']) / DAY_IN_SECONDS;
                $per = $gap / max(1, $purchases[$i - 1]['qty']);
                if ($per >= 1) {
                    $observed[] = $per;
                }
            }

            // «خلص» taps: the real run-out for the purchase they follow.
            $last       = $purchases[$n_buys - 1];
            $out_after  = 0;
            $snooze_to  = 0;
            foreach ($events[$pid] ?? [] as $event) {
                if ($vid > 0 && (int) $event['variation_id'] > 0 && (int) $event['variation_id'] !== $vid) {
                    continue;
                }
                $ets = (int) $event['ts'];
                if ($event['kind'] === 'snooze') {
                    if ($ets >= $last['ts'] && (int) $event['until_ts'] > $snooze_to) {
                        $snooze_to = (int) $event['until_ts'];
                    }
                    continue;
                }
                // out: which purchase did it follow?
                $before = null;
                foreach ($purchases as $p) {
                    if ($p['ts'] <= $ets) {
                        $before = $p;
                    }
                }
                if ($before !== null) {
                    $per = (($ets - $before['ts']) / DAY_IN_SECONDS) / max(1, $before['qty']);
                    if ($per >= 1) {
                        $observed[] = $per;
                    }
                }
                if ($ets >= $last['ts'] && $ets > $out_after) {
                    $out_after = $ets;
                }
            }

            [$cycle, $confidence] = self::blend($prior, $observed);

            $runs_out = $last['ts'] + (int) round($last['qty'] * $cycle * DAY_IN_SECONDS);
            if ($out_after > 0) {
                $runs_out = $out_after;
            }
            if ($snooze_to > $runs_out) {
                $runs_out = $snooze_to;
            }

            // A line that ran out long ago and was never reordered is not "overdue" —
            // the customer moved on (or buys it elsewhere). Nagging about it would make
            // the gauge cry wolf, so it drops once it is more than twice its own supply
            // (and at least a month) past its date. Win-back handles real silence.
            $stale_after = max($kind === 'treat' ? 14.0 : 30.0, 2.0 * $last['qty'] * $cycle) * DAY_IN_SECONDS;
            if ($now - $runs_out > $stale_after) {
                continue;
            }

            $rows[] = [
                'product_id'   => $pid,
                'variation_id' => $vid,
                'kind'         => $kind,
                'species'      => $species,
                'pet_id'       => $pet !== null ? (int) $pet['id'] : 0,
                'qty_last'     => (int) $last['qty'],
                'last_ts'      => (int) $last['ts'],
                'buys'         => $n_buys,
                'pack_kg'      => $pack,
                'cycle_days'   => round($cycle, 1),
                'runs_out_ts'  => (int) $runs_out,
                'confidence'   => $confidence,
                'built_at'     => $now,
            ];
        }

        // Food and litter lead — they are the thesis; treats trail, because a
        // 14 g pouch running out is not the reason to open the app.
        $rank = static fn (string $kind): int => match ($kind) {
            'dry', 'wet', 'litter' => 0,
            'other' => 1,
            default => 2,
        };
        usort($rows, static function ($a, $b) use ($rank) {
            $r = $rank((string) $a['kind']) <=> $rank((string) $b['kind']);
            return $r !== 0 ? $r : ($a['runs_out_ts'] <=> $b['runs_out_ts']);
        });
        return array_slice($rows, 0, self::MAX_ITEMS);
    }

    /**
     * The blend: the prior is worth exactly one observation.
     *
     * @return array{0:float,1:string} [cycle days per unit, confidence]
     */
    private static function blend(?float $prior, array $observed): array
    {
        $n = count($observed);
        if ($prior !== null && $n > 0) {
            $cycle = ($prior + array_sum($observed)) / (1 + $n);
        } elseif ($prior !== null) {
            $cycle = $prior;
        } elseif ($n > 0) {
            $cycle = array_sum($observed) / $n;
        } else {
            $cycle = self::FALLBACK;
        }

        $confidence = 'low';
        if ($n >= 2) {
            $confidence = 'high';
        } elseif ($n === 1 || $prior !== null) {
            $confidence = 'medium';
        }

        return [max(self::MIN_CYCLE, min(self::MAX_CYCLE, $cycle)), $confidence];
    }

    /** Days one unit lasts according to the feeding table, or null when unknown. */
    private static function prior_days(string $species, string $kind, ?float $pack_kg, ?array $pet): ?float
    {
        if ($pack_kg === null || $pack_kg <= 0 || $species === '' || $kind === 'other') {
            return null;
        }
        $table = self::feeding_table();
        $spec  = $table[$species][$kind] ?? null;
        if (!is_array($spec)) {
            return null;
        }

        $grams = 0.0;
        if (isset($spec['flat'])) {
            $grams = (float) $spec['flat'];
        } elseif (isset($spec['per_kg'])) {
            $weight = $pet !== null && $pet['weight_kg'] !== null && (float) $pet['weight_kg'] > 0
                ? (float) $pet['weight_kg']
                : (float) ($spec['default_kg'] ?? 4);
            $per_kg = (float) $spec['per_kg'];
            if (!empty($spec['tiers']) && is_array($spec['tiers'])) {
                foreach ($spec['tiers'] as $tier) {
                    if (is_array($tier) && count($tier) === 2 && $weight <= (float) $tier[0]) {
                        $per_kg = (float) $tier[1];
                        break;
                    }
                }
            }
            $grams = $weight * $per_kg;
        }
        if ($grams <= 0) {
            return null;
        }
        return ($pack_kg * 1000.0) / $grams;
    }

    /** The pet this product most likely feeds: species match first, else the first pet. */
    private static function pick_pet(array $pets, string $species): ?array
    {
        if (empty($pets)) {
            return null;
        }
        if ($species !== '') {
            foreach ($pets as $pet) {
                if ((string) $pet['species'] === $species) {
                    return $pet;
                }
            }
        }
        return $pets[0];
    }

    /** The customer's supply events of the last year, grouped by product. */
    private static function events(int $user_id): array
    {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT product_id, variation_id, kind, until, created_at FROM ' . Zooboxi_Loyalty_Schema::supply_events()
            . ' WHERE user_id = %d AND created_at >= %s ORDER BY created_at ASC',
            $user_id,
            gmdate('Y-m-d H:i:s', time() - 365 * DAY_IN_SECONDS)
        ), ARRAY_A);

        $out = [];
        foreach ((array) $rows as $row) {
            $out[(int) $row['product_id']][] = [
                'variation_id' => (int) $row['variation_id'],
                'kind'         => (string) $row['kind'],
                'ts'           => (int) strtotime((string) $row['created_at'] . ' UTC'),
                'until_ts'     => !empty($row['until']) ? (int) strtotime((string) $row['until'] . ' 23:59:59 UTC') : 0,
            ];
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       CLASSIFICATION
       ══════════════════════════════════════════════════════════════ */

    /** Every ancestor-or-self category id of a product (memoised). */
    private static function category_lineage(int $product_id): array
    {
        if (isset(self::$ancestors[$product_id])) {
            return self::$ancestors[$product_id];
        }
        $ids = [];
        foreach ((array) wp_get_post_terms($product_id, 'product_cat', ['fields' => 'ids']) as $tid) {
            $tid = (int) $tid;
            if ($tid <= 0) {
                continue;
            }
            $ids[$tid] = true;
            foreach ((array) get_ancestors($tid, 'product_cat', 'taxonomy') as $aid) {
                $ids[(int) $aid] = true;
            }
        }
        return self::$ancestors[$product_id] = array_keys($ids);
    }

    private static function category_names(int $product_id): string
    {
        $names = [];
        foreach ((array) wp_get_post_terms($product_id, 'product_cat', ['fields' => 'names']) as $name) {
            $names[] = (string) $name;
        }
        return implode(' ', $names);
    }

    /** dry | wet | litter | treat | other */
    public static function kind_of(int $product_id, string $name = ''): string
    {
        if (isset(self::$product_kind[$product_id])) {
            return self::$product_kind[$product_id];
        }
        if ($name === '') {
            $name = (string) get_the_title($product_id);
        }
        $title   = mb_strtolower($name);
        $text    = $title . ' ' . mb_strtolower(self::category_names($product_id));
        $lineage = self::category_lineage($product_id);
        $in_food = !empty(array_intersect($lineage, self::food_cats()));
        $in_treat = !empty(array_intersect($lineage, self::treat_cats()));

        // Hardware is never a consumable, whatever aisle it sits in: a feeding bowl
        // lives under «أدوات الطعام» and would otherwise read as food.
        if (preg_match('/(وعاء|صحن|صحون|حوض|صندوق|لعبة|العاب|ألعاب|مشد|مقود|قلادة|طوق|سرير|كوخ|خداشة|فرشاة|مشط|شامبو|حامل|قفص|ناقل|حقيبة|ملابس|مجرفة|bowl|feeder|toy|leash|collar|harness|bed|scratcher|brush|comb|shampoo|cage|carrier|litter box|\d+\s*(?:مل|ml)\b|لتر|liter|litre)/u', $title)) {
            return self::$product_kind[$product_id] = 'hardware';
        }

        $kind = 'other';
        if (preg_match('/(رطب|معلب|معلبات|باوتش|pouch|صلصة|مرق|جيلي|jelly|gravy|\bwet\b|مهروس)/u', $title)) {
            $kind = 'wet';
        } elseif (preg_match('/(رمل|تراب|litter|sand)/u', $title)) {
            $kind = 'litter';
        } elseif ($in_treat || preg_match('/(مكافآت|مكافات|مكافأة|treat|سناك|snack|بسكويت|biscuit|churu|تشورو|أعواد|اعواد|عيدان)/u', $text)) {
            $kind = 'treat';
        } elseif ($in_food || preg_match('/(طعام جاف|دراي|\bdry\b|غذاء كامل|complete food|\bfood\b|طعام|غذاء)/u', $title)) {
            $kind = 'dry';
        }

        return self::$product_kind[$product_id] = $kind;
    }

    /** cat | dog | bird | small | '' — from the category tree's animal roots. */
    public static function species_of_product(int $product_id): string
    {
        $lineage = self::category_lineage($product_id);
        foreach (self::species_roots() as $species => $root) {
            if (in_array($root, $lineage, true)) {
                return (string) $species;
            }
        }
        return '';
    }

    /* ══════════════════════════════════════════════════════════════
       PACK SIZE
       ══════════════════════════════════════════════════════════════ */

    /**
     * How many kilograms one unit holds — from the variation's attributes, then the
     * product name, then WooCommerce's weight field. Null when nothing readable
     * (liquids, toys, accessories).
     */
    public static function pack_kg(\WC_Product $product, ?\WC_Product $parent = null): ?float
    {
        $names = [];
        $multiplier = 1.0;

        // 1) variation attributes: "2-5-كغ", "400-غ", "كرتون-24-حبة", "حبة"
        if ($product->is_type('variation')) {
            foreach ($product->get_attributes() as $value) {
                $value = rawurldecode((string) $value);
                $m     = self::carton_multiplier($value);
                if ($m > 1) {
                    $multiplier = $m;
                    continue;
                }
                $names[] = str_replace('-', ' ', preg_replace('/(\d+)-(\d+)/u', '$1.$2', $value));
            }
        }

        // 2) the names (variation first — it is the more specific one)
        $names[] = (string) $product->get_name();
        if ($parent !== null) {
            $names[] = (string) $parent->get_name();
        }

        $kg = null;
        foreach ($names as $name) {
            $kg = self::parse_kg($name);
            if ($kg !== null) {
                break;
            }
        }

        // 3) WooCommerce weight: grams when it looks like grams, kilos otherwise.
        if ($kg === null) {
            $raw = (float) $product->get_weight();
            if ($raw <= 0 && $parent !== null) {
                $raw = (float) $parent->get_weight();
            }
            if ($raw > 0) {
                $kg = $raw >= 100 ? $raw / 1000.0 : $raw;
            }
        }

        if ($kg === null || $kg <= 0) {
            return null;
        }
        return round($kg * $multiplier, 3);
    }

    /** "كرتون-24-حبة" → 24; anything else → 1. */
    private static function carton_multiplier(string $value): float
    {
        $value = self::latin_digits($value);
        if (preg_match('/(كرتون|carton|box|علبة)\D*(\d+)/u', $value, $m)) {
            return max(1, (int) $m[2]);
        }
        return 1.0;
    }

    /** Read a weight out of free text: kg first, then grams, then "12x85g" packs. */
    public static function parse_kg(string $text): ?float
    {
        $text = self::latin_digits(mb_strtolower($text));
        $text = str_replace(['٫', ','], '.', $text);

        // 12 x 85 g  → 1.02 kg
        if (preg_match('/(\d+)\s*[x×\*]\s*(\d+(?:\.\d+)?)\s*(?:غ|جم|جرام|غرام|g|gm|gr)(?![a-z\p{Arabic}])/u', $text, $m)) {
            return ((int) $m[1] * (float) $m[2]) / 1000.0;
        }
        if (preg_match('/(\d+(?:\.\d+)?)\s*(?:كغ|كجم|كيلوجرام|كيلو|kg|kgs)(?![a-z\p{Arabic}])/u', $text, $m)) {
            return (float) $m[1];
        }
        if (preg_match('/(\d+(?:\.\d+)?)\s*(?:غ|جم|جرام|غرام|g|gm|gr)(?![a-z\p{Arabic}])/u', $text, $m)) {
            return (float) $m[1] / 1000.0;
        }
        return null;
    }

    private static function latin_digits(string $s): string
    {
        return strtr($s, ['٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9']);
    }

    /* ══════════════════════════════════════════════════════════════
       EVENTS — «خلص» and «عندي كفاية»
       ══════════════════════════════════════════════════════════════ */

    public static function mark_out(int $user_id, int $product_id, int $variation_id = 0): ?array
    {
        return self::record($user_id, $product_id, $variation_id, 'out', null);
    }

    public static function snooze(int $user_id, int $product_id, int $variation_id = 0, int $days = 7): ?array
    {
        $days  = max(1, min(60, $days));
        $until = gmdate('Y-m-d', time() + $days * DAY_IN_SECONDS);
        return self::record($user_id, $product_id, $variation_id, 'snooze', $until);
    }

    private static function record(int $user_id, int $product_id, int $variation_id, string $kind, ?string $until): ?array
    {
        if ($user_id <= 0 || $product_id <= 0 || !self::enabled()) {
            return null;
        }
        if (self::find($user_id, $product_id, $variation_id) === null) {
            return null; // not one of their supply lines
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        global $wpdb;
        $wpdb->insert(Zooboxi_Loyalty_Schema::supply_events(), [
            'user_id'      => $user_id,
            'product_id'   => $product_id,
            'variation_id' => max(0, $variation_id),
            'kind'         => $kind,
            'until'        => $until,
            'created_at'   => Zooboxi_Loyalty::now(),
        ], ['%d', '%d', '%d', '%s', '%s', '%s']);

        self::flush($user_id);
        self::items($user_id, true);
        return self::find($user_id, $product_id, $variation_id);
    }

    /* ══════════════════════════════════════════════════════════════
       ON-TIME (+20%)
       ══════════════════════════════════════════════════════════════ */

    /** At checkout: remember which lines were ordered inside their window. */
    public static function stamp_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0 || !self::enabled()) {
            return 0;
        }
        $open = self::on_time_ids($user_id);
        if (empty($open)) {
            return 0;
        }
        $hit = [];
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                continue;
            }
            $pid = (int) $item->get_product_id();
            if (in_array($pid, $open, true)) {
                $hit[$pid] = true;
            }
        }
        if (empty($hit)) {
            return 0;
        }
        $order->update_meta_data(self::ON_TIME_META, wp_json_encode(array_keys($hit)));
        $order->save_meta_data();
        return count($hit);
    }

    /** @return int[] product ids stamped on this order */
    public static function stamped_ids(\WC_Order $order): array
    {
        $raw = (string) $order->get_meta(self::ON_TIME_META);
        if ($raw === '') {
            return [];
        }
        $ids = json_decode($raw, true);
        return is_array($ids) ? array_values(array_filter(array_map('intval', $ids))) : [];
    }

    /** On delivery: pay the bonus for the stamped lines, exactly once. */
    public static function settle_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        $ids     = self::stamped_ids($order);
        if ($user_id <= 0 || empty($ids)) {
            return 0;
        }
        $pct  = max(0, Zooboxi_Loyalty::opt_float('on_time_pct', 20));
        $rate = Zooboxi_Loyalty::opt_float('points_per_riyal');
        if ($pct <= 0 || $rate <= 0) {
            return 0;
        }
        $base = 0.0;
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                continue;
            }
            if (in_array((int) $item->get_product_id(), $ids, true)) {
                $base += (float) $item->get_total();
            }
        }
        $bonus = (int) floor($base * $rate * $pct / 100);
        if ($bonus <= 0) {
            return 0;
        }
        $written = Zooboxi_Loyalty_Ledger::add(
            $user_id,
            $bonus,
            'on_time',
            'order',
            (int) $order->get_id(),
            Zooboxi_Loyalty::pick('طلبت في وقتك — بصمات إضافية', 'Ordered on time — bonus paws')
        );
        return $written > 0 ? $bonus : 0;
    }

    /** Cancelled after delivery: the bonus goes back out. */
    public static function reverse_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        $id      = (int) $order->get_id();
        $paid    = Zooboxi_Loyalty_Ledger::entry_delta($user_id, 'on_time', 'order', $id);
        if ($user_id <= 0 || $paid <= 0) {
            return 0;
        }
        $written = Zooboxi_Loyalty_Ledger::add(
            $user_id,
            -$paid,
            'reverse',
            'on_time',
            $id,
            Zooboxi_Loyalty::pick('عكس بصمات «في وقته»', 'Reversed: on-time bonus')
        );
        return $written > 0 ? $paid : 0;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    /** Live state of a cached row: days left, status, window. */
    public static function state_of(array $row): array
    {
        $window    = self::window();
        $days_left = (int) ceil(((int) $row['runs_out_ts'] - time()) / DAY_IN_SECONDS);

        if ($days_left > $window['before']) {
            $status = 'ok';
        } elseif ($days_left > 0) {
            $status = 'soon';
        } elseif ($days_left >= -$window['after']) {
            $status = 'due';
        } else {
            $status = 'overdue';
        }

        return [
            'days_left' => $days_left,
            'status'    => $status,
            'on_time'   => $days_left <= $window['before'] && $days_left >= -$window['after'],
        ];
    }

    public static function dto(array $row, int $user_id = 0): array
    {
        $state = self::state_of($row);
        $card  = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::card((int) $row['product_id']) : null;

        $pet = null;
        if ((int) $row['pet_id'] > 0 && $user_id > 0) {
            $p = Zooboxi_Loyalty_Pets::find((int) $row['pet_id'], $user_id);
            if ($p !== null) {
                $pet = ['id' => (int) $p['id'], 'name' => (string) $p['name'], 'species' => (string) $p['species']];
            }
        }

        $sub_id = null;
        if ($user_id > 0 && class_exists('Zooboxi_Loyalty_Subscriptions')) {
            $sub    = Zooboxi_Loyalty_Subscriptions::find_line($user_id, (int) $row['product_id'], (int) $row['variation_id']);
            $sub_id = $sub !== null && $sub['state'] !== 'cancelled' ? (int) $sub['id'] : null;
        }

        return [
            'product'         => $card,
            'variation_id'    => (int) $row['variation_id'],
            'kind'            => (string) $row['kind'],
            'pet'             => $pet,
            'qty_last'        => (int) $row['qty_last'],
            'last_ordered_at' => gmdate('Y-m-d\TH:i:s\Z', (int) $row['last_ts']),
            'cycle_days'      => (float) $row['cycle_days'],
            'days_left'       => $state['days_left'],
            'runs_out_at'     => gmdate('Y-m-d\TH:i:s\Z', (int) $row['runs_out_ts']),
            'status'          => $state['status'],
            'confidence'      => (string) $row['confidence'],
            'on_time'         => $state['on_time'],
            'pack_kg'         => $row['pack_kg'] === null ? null : (float) $row['pack_kg'],
            'buys'            => (int) $row['buys'],
            'subscription_id' => $sub_id,
        ];
    }

    /** @return array<int,array> */
    public static function dtos(array $rows, int $user_id = 0): array
    {
        $out = [];
        foreach ($rows as $row) {
            $dto = self::dto($row, $user_id);
            if ($dto['product'] !== null) {
                $out[] = $dto;
            }
        }
        return $out;
    }

    /** The summary block: the three soonest, plus counts. */
    public static function summary_block(int $user_id): array
    {
        $rows = self::items($user_id);
        $due  = 0;
        foreach ($rows as $row) {
            $state = self::state_of($row);
            if ($state['status'] !== 'ok') {
                $due++;
            }
        }
        return [
            'items'     => self::dtos(array_slice($rows, 0, 3), $user_id),
            'due_count' => $due,
            'total'     => count($rows),
            'window'    => self::window(),
        ];
    }
}
