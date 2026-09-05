<?php
/**
 * Zooboxi_Loyalty_Tiers — the five levels, and the perks that are REAL.
 *
 * Everything else a loyalty program usually promises is theatre unless the checkout
 * actually honours it, so Phase 1 implements exactly three mechanical benefits:
 *   • `star`+ : the free-shipping threshold drops (200 → 150)
 *   • `gold`+ : the express fee is waived, always
 *   • `amb`   : free delivery with no minimum at all, on every tier
 *
 * All three are delivered through TWO seams, and nothing in this module ever reads a
 * fee or a threshold directly:
 *   • `zooboxi_free_shipping_min` — the delivery engine, the three shipping methods,
 *     the smart-shipment summary and the v2 cart/meta all read it.
 *   • `zooboxi_express_fee` — the fulfilment resolver, the delivery engine (×2), the
 *     smart-shipment summary, the express method and the v2 cart/meta read it.
 *
 * NEVER assume a fee's value. `zooboxi_express_fee` currently sits at 0 for a trial
 * and WILL become a paid tier again (owner, 2026-09-05); the express reward is only
 * meaningful because it goes through the filter rather than through a hardcoded 0.
 *
 * The remaining perks (priority support, samples, WhatsApp line) are honest TEXT: they
 * ship as `perks[]` with `active` flags and no code pretends to enforce them.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Tiers
{
    /** Order of the ladder — index doubles as the rank used by every comparison. */
    public const ORDER = ['new', 'friend', 'star', 'gold', 'amb'];

    /** Thresholds (completed orders in a rolling 365 days) — overridable per store. */
    public const DEFAULT_MINS = ['new' => 0, 'friend' => 2, 'star' => 4, 'gold' => 8, 'amb' => 14];

    /** Names + the palette the web account page already uses, so both surfaces match. */
    private const IDENTITY = [
        'new'    => ['بداية الرحلة', 'Start',      '🐣', '#8fb9a8', '#6fa08d'],
        'friend' => ['صديق',         'Friend',     '🐾', '#5fb3b2', '#429d9c'],
        'star'   => ['مميّز',        'Star',       '⭐', '#e8a765', '#d48644'],
        'gold'   => ['ذهبي',         'Gold',       '🏅', '#e0b341', '#c99320'],
        'amb'    => ['سفير',         'Ambassador', '👑', '#e07a63', '#d46856'],
    ];

    /** Per-request memos — both filters are hit once per shipping package. */
    private static array $min_memo = [];
    private static array $express_memo = [];

    /* ══════════════════════════════════════════════════════════════
       DEFINITION
       ══════════════════════════════════════════════════════════════ */

    /** The ladder, lowest first: key, min, names, icon, colours. */
    public static function ladder(): array
    {
        $mins = Zooboxi_Loyalty::opt_json('tiers', self::DEFAULT_MINS);

        $out = [];
        foreach (self::ORDER as $key) {
            [$ar, $en, $icon, $c1, $c2] = self::IDENTITY[$key];
            $out[] = [
                'key'     => $key,
                'min'     => isset($mins[$key]) ? max(0, (int) $mins[$key]) : self::DEFAULT_MINS[$key],
                'name'    => $ar,
                'name_en' => $en,
                'icon'    => $icon,
                'c1'      => $c1,
                'c2'      => $c2,
            ];
        }

        // A mis-typed threshold must never invert the ladder.
        usort($out, static fn ($a, $b) => $a['min'] <=> $b['min']);
        return $out;
    }

    public static function rank(string $key): int
    {
        $i = array_search($key, self::ORDER, true);
        return $i === false ? 0 : (int) $i;
    }

    /** Is `$key` at least `$floor` on the ladder? */
    public static function at_least(string $key, string $floor): bool
    {
        return self::rank($key) >= self::rank($floor);
    }

    /** Which tier does this many 12-month orders buy? */
    public static function key_for_orders(int $orders): string
    {
        $key = 'new';
        foreach (self::ladder() as $tier) {
            if ($orders >= (int) $tier['min']) {
                $key = (string) $tier['key'];
            }
        }
        return $key;
    }

    public static function definition(string $key): array
    {
        foreach (self::ladder() as $tier) {
            if ($tier['key'] === $key) {
                return $tier;
            }
        }
        return self::ladder()[0];
    }

    /** Localised tier name (used by the reward `min_tier` copy). */
    public static function name(string $key): string
    {
        $def = self::definition($key);
        return Zooboxi_Loyalty::pick((string) $def['name'], (string) $def['name_en']);
    }

    /* ══════════════════════════════════════════════════════════════
       THE MEASURE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Completed orders in the last 365 days.
     *
     * HPOS-safe by construction: wc_get_orders() is the only order query used, never
     * a posts table. `return => ids` keeps it cheap even for a heavy customer.
     */
    public static function count_completed_12m(int $user_id): int
    {
        if ($user_id <= 0 || !function_exists('wc_get_orders')) {
            return 0;
        }

        try {
            $ids = wc_get_orders([
                'customer_id'    => $user_id,
                'status'         => ['completed'],
                'date_completed' => '>' . (time() - 365 * DAY_IN_SECONDS),
                'limit'          => 200,
                'return'         => 'ids',
            ]);
        } catch (\Throwable $e) {
            return 0;
        }

        return is_array($ids) ? count($ids) : 0;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    /** The tier block of `/loyalty/summary`. */
    public static function dto(int $user_id): array
    {
        $state  = Zooboxi_Loyalty_Members::tier_state($user_id);
        $orders = (int) $state['orders_12m'];
        $key    = (string) $state['key'];

        $ladder  = self::ladder();
        $current = $ladder[0];
        $next    = null;

        foreach ($ladder as $i => $tier) {
            if ($tier['key'] === $key) {
                $current = $tier;
                $next    = $ladder[$i + 1] ?? null;
            }
        }

        $span     = $next ? max(1, (int) $next['min'] - (int) $current['min']) : 1;
        $done     = $next ? max(0, $orders - (int) $current['min']) : $span;
        $progress = (int) round(min(100, max(0, $done / $span * 100)));

        return [
            'key'        => (string) $current['key'],
            'name'       => (string) $current['name'],
            'name_en'    => (string) $current['name_en'],
            'icon'       => (string) $current['icon'],
            'c1'         => (string) $current['c1'],
            'c2'         => (string) $current['c2'],
            'orders_12m' => $orders,
            'min'        => (int) $current['min'],
            'next'       => $next ? [
                'key'           => (string) $next['key'],
                'name'          => (string) $next['name'],
                'name_en'       => (string) $next['name_en'],
                'icon'          => (string) $next['icon'],
                'min'           => (int) $next['min'],
                'orders_needed' => max(0, (int) $next['min'] - $orders),
            ] : null,
            'progress'   => $progress,
            'perks'      => self::perks($key),
        ];
    }

    /**
     * The perk list, each flagged `active` for THIS tier.
     *
     * The threshold copy is built from the LIVE option (never a literal 200/150), and
     * the express perk deliberately carries no number: the fee is a moving target.
     */
    public static function perks(string $key): array
    {
        $star_min = Zooboxi_Loyalty::opt_float('star_free_min');
        // The RAW option on purpose — this is the only place in the plugin that must not
        // go through the filter. The sentence is «من 150 بدل 200»: reading the filtered
        // value would print "150 instead of 150" for the very customer it describes, and
        // would re-enter this class's own filter while building its own copy.
        $base_min = (float) get_option('zooboxi_free_shipping_min', 200);

        $perks = [
            [
                'key'       => 'free_min_150',
                'text'      => Zooboxi_Loyalty::pick(
                    sprintf('الشحن المجاني من %s ﷼ بدل %s', self::num($star_min), self::num($base_min)),
                    sprintf('Free shipping from %s SAR instead of %s', self::num($star_min), self::num($base_min))
                ),
                'active'    => self::at_least($key, 'star'),
                'from_tier' => 'star',
            ],
            [
                'key'       => 'express_free_always',
                'text'      => Zooboxi_Loyalty::pick('توصيل سريع مجاني دائماً', 'Free express delivery, always'),
                'active'    => self::at_least($key, 'gold'),
                'from_tier' => 'gold',
            ],
            [
                'key'       => 'free_delivery_always',
                'text'      => Zooboxi_Loyalty::pick('توصيل مجاني بلا حد أدنى', 'Free delivery, no minimum'),
                'active'    => self::at_least($key, 'amb'),
                'from_tier' => 'amb',
            ],
            [
                'key'       => 'priority_support',
                'text'      => Zooboxi_Loyalty::pick('أولوية في الدعم', 'Priority support'),
                'active'    => self::at_least($key, 'gold'),
                'from_tier' => 'gold',
            ],
            [
                'key'       => 'samples',
                'text'      => Zooboxi_Loyalty::pick('عيّنات جديدة قبل الجميع', 'New samples before everyone'),
                'active'    => self::at_least($key, 'amb'),
                'from_tier' => 'amb',
            ],
            [
                'key'       => 'whatsapp',
                'text'      => Zooboxi_Loyalty::pick('خط واتساب مباشر', 'Direct WhatsApp line'),
                'active'    => self::at_least($key, 'amb'),
                'from_tier' => 'amb',
            ],
        ];

        // The app prints «من مستوى ذهبي», never «من مستوى gold»: hand it the name in
        // the request's language next to the key it keys on.
        foreach ($perks as &$perk) {
            $perk['from_tier_name'] = self::name((string) $perk['from_tier']);
        }
        unset($perk);

        return $perks;
    }

    private static function num(float $v): string
    {
        return rtrim(rtrim(number_format($v, 2, '.', ''), '0'), '.');
    }

    /* ══════════════════════════════════════════════════════════════
       FILTERS — the two seams the whole store already reads
       ══════════════════════════════════════════════════════════════ */

    public static function register_filters(): void
    {
        add_filter('zooboxi_free_shipping_min', [__CLASS__, 'filter_free_shipping_min'], 10, 1);
        add_filter('zooboxi_express_fee', [__CLASS__, 'filter_express_fee'], 10, 1);
        add_filter('zooboxi_account_tiers', [__CLASS__, 'filter_account_tiers'], 10, 1);
        // Priority 100: after the GPS injection (10) and the smart-shipment split (20),
        // so every package that reaches WooCommerce's rate cache carries our key.
        add_filter('woocommerce_cart_shipping_packages', [__CLASS__, 'filter_shipping_packages'], 100, 1);
    }

    /**
     * Drop both per-request memos. Called whenever a claim or a tier changes INSIDE a
     * request (claim → recalculate totals → the same filter must now answer differently).
     */
    public static function forget_memo(): void
    {
        self::$min_memo     = [];
        self::$express_memo = [];
    }

    /**
     * WooCommerce caches shipping rates in the session keyed by a hash of the package.
     * A claimed free-delivery reward changes what the rate SHOULD be without changing
     * anything in the package, so the stale rate would be served until the basket
     * changed. Stamping the claims and the tier onto the package makes the hash move
     * with them — no store-wide cache flush needed.
     */
    public static function filter_shipping_packages($packages)
    {
        if (!is_array($packages) || !Zooboxi_Loyalty::is_enabled()) {
            return $packages;
        }
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return $packages;
        }
        try {
            $claims = [];
            foreach (Zooboxi_Loyalty_Rewards::session_claims($user_id) as $grant) {
                $claims[] = (int) $grant['id'];
            }
            sort($claims);
            $stamp = ['claims' => $claims, 'tier' => Zooboxi_Loyalty_Members::tier_key($user_id)];
            foreach ($packages as $i => $package) {
                if (is_array($package)) {
                    $packages[$i]['zb_loyalty'] = $stamp;
                }
            }
        } catch (\Throwable $e) {
            // A stamp we cannot compute must never break shipping.
        }
        return $packages;
    }

    /**
     * Lower (or zero) the free-shipping threshold for this customer.
     *
     * Order of authority: a claimed `free_delivery` reward wins over everything, then
     * `amb` (no minimum), then `star`+ (the lower threshold). A guest, or a store with
     * the module off, never reaches this function and sees the raw option.
     */
    public static function filter_free_shipping_min($min)
    {
        $min = (float) $min;
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $min;
        }

        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return $min;
        }

        $memo_key = $user_id . '|' . $min;
        if (isset(self::$min_memo[$memo_key])) {
            return self::$min_memo[$memo_key];
        }

        $result = $min;
        try {
            if (Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'free_delivery')) {
                $result = 0.0;
            } else {
                $tier = Zooboxi_Loyalty_Members::tier_key($user_id);
                if (self::at_least($tier, 'amb')) {
                    $result = 0.0;
                } elseif (self::at_least($tier, 'star')) {
                    $result = min($min, Zooboxi_Loyalty::opt_float('star_free_min'));
                }
            }
        } catch (\Throwable $e) {
            // A missing table or a cold session must never break a shipping quote.
            $result = $min;
        }

        return self::$min_memo[$memo_key] = $result;
    }

    /**
     * Waive the express fee for this customer.
     *
     * A claimed `express_free` reward waives it for the next order; a claimed
     * `free_delivery` reward waives every tier's fee (express included); `gold`+ has it
     * permanently. The base value is whatever the option says — the trial zero of today
     * and the paid fee of tomorrow both flow through unchanged for everyone else.
     */
    public static function filter_express_fee($fee)
    {
        $fee = (float) $fee;
        if (!Zooboxi_Loyalty::is_enabled() || $fee <= 0) {
            return $fee;
        }

        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return $fee;
        }

        $memo_key = $user_id . '|' . $fee;
        if (isset(self::$express_memo[$memo_key])) {
            return self::$express_memo[$memo_key];
        }

        $result = $fee;
        try {
            if (Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'express_free')
                || Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'free_delivery')
                || self::at_least(Zooboxi_Loyalty_Members::tier_key($user_id), 'gold')) {
                $result = 0.0;
            }
        } catch (\Throwable $e) {
            $result = $fee;
        }

        return self::$express_memo[$memo_key] = $result;
    }

    /** Why is delivery free right now? `null` | `'tier'` | `'reward'` (for the cart DTO). */
    public static function free_delivery_reason(int $user_id): ?string
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return null;
        }
        if (Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'free_delivery')) {
            return 'reward';
        }
        return self::at_least(Zooboxi_Loyalty_Members::tier_key($user_id), 'amb') ? 'tier' : null;
    }

    /** Why is express free right now? `null` | `'tier'` | `'reward'`. */
    public static function express_free_reason(int $user_id): ?string
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return null;
        }
        if (Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'express_free')
            || Zooboxi_Loyalty_Rewards::has_claim_of_kind($user_id, 'free_delivery')) {
            return 'reward';
        }
        return self::at_least(Zooboxi_Loyalty_Members::tier_key($user_id), 'gold') ? 'tier' : null;
    }

    /**
     * Teach the WEBSITE's account page the same ladder.
     *
     * The theme reads `zooboxi_account_tiers` for its badge; without this the customer
     * would see one level in the app and a different one on the web. Shape is exactly
     * what the theme expects (min/key/name/icon/c1/c2) — nothing else changes there.
     */
    public static function filter_account_tiers($tiers)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($tiers)) {
            return $tiers;
        }

        $out = [];
        foreach (self::ladder() as $tier) {
            $out[] = [
                'min'  => (int) $tier['min'],
                'key'  => (string) $tier['key'],
                'name' => (string) $tier['name'],
                'icon' => (string) $tier['icon'],
                'c1'   => (string) $tier['c1'],
                'c2'   => (string) $tier['c2'],
            ];
        }
        return $out;
    }
}
