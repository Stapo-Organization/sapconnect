<?php
/**
 * Zooboxi_Loyalty — «عائلة زوبوكسي» / Zooboxi Family, the module registrar.
 *
 * WHY A REGISTRAR: the web store must keep working byte-for-byte when this module is
 * off. Nothing here is loaded or hooked unless option `zooboxi_loyalty_enabled` is
 * 'yes', and every hook body re-checks its own preconditions (WooCommerce loaded,
 * a real customer id, the tables installed) so a half-deployed state degrades to
 * "no loyalty" instead of a fatal.
 *
 * The single vocabulary: the currency is «بصمات» / "Paws" (`paws`), the program is
 * «عائلة زوبوكسي» / "Zooboxi Family".
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty
{
    public const CRON_DAILY = 'zooboxi_loyalty_daily';

    /** WC session key holding the grant ids claimed into the current basket. */
    public const SESSION_CLAIMS = 'zb_loyalty_claims';

    /** Cart item data key + order item meta key for a gift line. */
    public const CART_GRANT_KEY = 'zb_grant_id';
    public const ORDER_GRANT_META = '_zb_gift_grant';

    /** Order meta stamped by the v2 checkout so scratch cards stay app-only. */
    public const APP_ORDER_META = '_zooboxi_app_order';

    /** Every setting, with the default the spec fixed. Reachable from the admin page. */
    public const DEFAULTS = [
        'enabled'            => 'yes',
        'points_per_riyal'   => 1,
        'paw_value_sar'      => 0.03,
        'expiry_months'      => 12,
        'holdout_pct'        => 10,
        'max_pets'           => 3,
        'budget_pct'         => 4,
        'star_free_min'      => 150,
        'scratch_enabled'    => 'yes',
        'missions_enabled'   => 'yes',
        'welcome_paws'       => 0,
        'profile_paws'       => 100,
        'pet_paws'           => 50,
    ];

    private static ?bool $enabled = null;

    public function __construct()
    {
        // The FIRST admin page view after an scp deploy creates the tables.
        add_action('admin_init', [__CLASS__, 'boot_schema']);

        // Daily housekeeping: paw expiry + grant expiry.
        add_action('init', [__CLASS__, 'schedule_cron'], 20);
        add_action(self::CRON_DAILY, [__CLASS__, 'run_daily']);

        // Order lifecycle, checkout, cart.
        Zooboxi_Loyalty_Hooks::register();

        // Tier perks: the free-shipping-minimum filter + the web account tiers.
        Zooboxi_Loyalty_Tiers::register_filters();

        if (defined('WP_CLI') && WP_CLI && class_exists('Zooboxi_Loyalty_CLI')) {
            Zooboxi_Loyalty_CLI::register();
        }
    }

    /* ══════════════════════════════════════════════════════════════
       STATE
       ══════════════════════════════════════════════════════════════ */

    /** Is the program live? Memoised — this is read on nearly every hook. */
    public static function is_enabled(): bool
    {
        if (self::$enabled === null) {
            self::$enabled = get_option('zooboxi_loyalty_enabled', self::DEFAULTS['enabled']) === 'yes';
        }
        return self::$enabled;
    }

    /**
     * Forget the memo. The admin screen saves and then re-renders inside ONE request,
     * so without this a freshly toggled switch would still read its old value.
     */
    public static function flush_state(): void
    {
        self::$enabled = null;
    }

    /** Read one `zooboxi_loyalty_{key}` option with its spec default. */
    public static function opt(string $key, $fallback = null)
    {
        $default = $fallback !== null ? $fallback : (self::DEFAULTS[$key] ?? '');
        return get_option('zooboxi_loyalty_' . $key, $default);
    }

    public static function opt_int(string $key, ?int $fallback = null): int
    {
        return (int) self::opt($key, $fallback);
    }

    public static function opt_float(string $key, ?float $fallback = null): float
    {
        return (float) self::opt($key, $fallback);
    }

    /** A JSON-encoded option decoded to an array; `$fallback` when absent or invalid. */
    public static function opt_json(string $key, array $fallback = []): array
    {
        $raw = get_option('zooboxi_loyalty_' . $key, '');
        if (is_array($raw)) {
            return $raw;
        }
        if (!is_string($raw) || trim($raw) === '') {
            return $fallback;
        }
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : $fallback;
    }

    /** Program identity, echoed to the app in `/meta`. */
    public static function meta_block(): array
    {
        return [
            'program_name_ar'  => 'عائلة زوبوكسي',
            'program_name_en'  => 'Zooboxi Family',
            'currency_ar'      => 'بصمات',
            'currency_en'      => 'Paws',
            'points_per_riyal' => self::opt_float('points_per_riyal'),
            'paw_value_sar'    => self::opt_float('paw_value_sar'),
            'max_pets'         => self::opt_int('max_pets'),
            'scratch_enabled'  => self::opt('scratch_enabled') === 'yes',
            'missions_enabled' => self::opt('missions_enabled') === 'yes',
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       BOOT HELPERS
       ══════════════════════════════════════════════════════════════ */

    public static function boot_schema(): void
    {
        if (!self::is_enabled()) {
            return;
        }
        Zooboxi_Loyalty_Schema::maybe_install();
    }

    public static function schedule_cron(): void
    {
        if (!self::is_enabled()) {
            return;
        }
        if (!wp_next_scheduled(self::CRON_DAILY)) {
            // 03:10 UTC-ish tomorrow: away from the stock sync bursts.
            wp_schedule_event(time() + HOUR_IN_SECONDS, 'daily', self::CRON_DAILY);
        }
    }

    /**
     * The daily job: expire dormant balances and time-out grants. Never allowed to
     * throw — a cron failure must not poison WP-Cron for the other jobs.
     *
     * @return array{paws_expired:int,members_expired:int,grants_expired:int}
     */
    public static function run_daily(): array
    {
        $out = ['paws_expired' => 0, 'members_expired' => 0, 'grants_expired' => 0];
        if (!self::is_enabled()) {
            return $out;
        }
        try {
            Zooboxi_Loyalty_Schema::maybe_install();
            $expired = Zooboxi_Loyalty_Ledger::expire_dormant();
            $out['paws_expired']    = (int) $expired['paws'];
            $out['members_expired'] = (int) $expired['members'];
            $out['grants_expired']  = Zooboxi_Loyalty_Rewards::expire_grants();
            update_option('zooboxi_loyalty_daily_ran_at', current_time('mysql', true), false);
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] daily job failed: ' . $e->getMessage());
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       SMALL SHARED HELPERS
       ══════════════════════════════════════════════════════════════ */

    /** UTC "now" in MySQL shape — the module's ONLY clock. */
    public static function now(): string
    {
        return current_time('mysql', true);
    }

    /** Current period key, e.g. "2026-09" (UTC). */
    public static function period(): string
    {
        return gmdate('Y-m');
    }

    /** ISO-8601 for a stored UTC DATETIME, null when empty. */
    public static function iso(?string $mysql_utc): ?string
    {
        if ($mysql_utc === null || $mysql_utc === '' || $mysql_utc === '0000-00-00 00:00:00') {
            return null;
        }
        $ts = strtotime($mysql_utc . ' UTC');
        return $ts ? gmdate('Y-m-d\TH:i:s\Z', $ts) : null;
    }

    /** Language-aware pick that also works outside a v2 request. */
    public static function pick(string $ar, string $en): string
    {
        if (class_exists('Zooboxi_V2_Bootstrap')) {
            return Zooboxi_V2_Bootstrap::pick($ar, $en);
        }
        return $ar !== '' ? $ar : $en;
    }

    /** Is WooCommerce far enough along to touch a cart/session? */
    public static function wc_ready(): bool
    {
        return function_exists('WC') && WC() !== null;
    }

    /* ══════════════════════════════════════════════════════════════
       MEASUREMENT — what the program costs and what it moved
       ══════════════════════════════════════════════════════════════ */

    /** WooCommerce Admin's analytics table, or '' when the store has none. */
    public static function stats_table(): string
    {
        global $wpdb;
        $table = $wpdb->prefix . 'wc_order_stats';
        return Zooboxi_Loyalty_Schema::table_exists($table) ? $table : '';
    }

    /** Statuses that count as a real sale in the analytics table. */
    private static function sale_statuses(): array
    {
        return ['wc-completed', 'wc-processing'];
    }

    /**
     * This month's program cost against this month's sales, and the budget ceiling.
     *
     * The paw side is valued at `paw_value_sar` (what a paw is expected to cost us when
     * it is finally spent), NOT at its face value — a paw issued is a liability, not a
     * payment.
     */
    public static function metrics(): array
    {
        global $wpdb;

        $month_start = gmdate('Y-m-01 00:00:00');
        $next_month  = gmdate('Y-m-d H:i:s', strtotime('first day of next month midnight', strtotime($month_start . ' UTC')));

        $paws = Zooboxi_Loyalty_Ledger::totals_between($month_start, $next_month);

        $members = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::members());
        $holdout = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::members() . ' WHERE holdout = 1');
        $pets    = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pets() . ' WHERE deleted_at IS NULL');

        $grant_rows = $wpdb->get_results(
            'SELECT state, COUNT(*) AS n FROM ' . Zooboxi_Loyalty_Schema::grants() . ' GROUP BY state',
            ARRAY_A
        );
        $grants = [];
        foreach ((array) $grant_rows as $row) {
            $grants[(string) $row['state']] = (int) $row['n'];
        }

        $cards_total    = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::scratch());
        $cards_revealed = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::scratch() . " WHERE state = 'revealed'");

        $missions_done = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::missions() . " WHERE state = 'rewarded' AND period = %s",
            self::period()
        ));

        // Cost: the SAR cost of everything actually redeemed this month, plus the
        // expected cost of the paws we issued this month.
        $redeemed_cost = (float) $wpdb->get_var($wpdb->prepare(
            'SELECT COALESCE(SUM(r.cost_sar), 0) FROM ' . Zooboxi_Loyalty_Schema::grants() . ' g'
            . ' INNER JOIN ' . Zooboxi_Loyalty_Schema::rewards() . ' r ON r.id = g.reward_id'
            . " WHERE g.state = 'redeemed' AND g.updated_at >= %s AND g.updated_at < %s",
            $month_start,
            $next_month
        ));

        $paw_cost = $paws['issued'] * self::opt_float('paw_value_sar');
        $cost     = $redeemed_cost + $paw_cost;

        $sales = 0.0;
        $table = self::stats_table();
        if ($table !== '') {
            $statuses = self::sale_statuses();
            $sales    = (float) $wpdb->get_var($wpdb->prepare(
                "SELECT COALESCE(SUM(total_sales), 0) FROM {$table}"
                . ' WHERE status IN (' . implode(',', array_fill(0, count($statuses), '%s')) . ')'
                . ' AND date_created_gmt >= %s AND date_created_gmt < %s',
                array_merge($statuses, [$month_start, $next_month])
            ));
        }

        return [
            'period'         => self::period(),
            'members'        => $members,
            'holdout'        => $holdout,
            'pets'           => $pets,
            'paws'           => $paws,
            'grants'         => $grants,
            'cards_total'    => $cards_total,
            'cards_revealed' => $cards_revealed,
            'missions_done'  => $missions_done,
            'cost_sar'       => round($cost, 2),
            'cost_rewards'   => round($redeemed_cost, 2),
            'cost_paws'      => round($paw_cost, 2),
            'sales_sar'      => round($sales, 2),
            'cost_pct'       => $sales > 0 ? round($cost / $sales * 100, 2) : null,
            'budget_pct'     => self::opt_float('budget_pct'),
            'stats_table'    => $table !== '',
        ];
    }

    /**
     * The "before" picture: 365 days of order behaviour, so the program can be judged
     * against what the store already did rather than against a feeling.
     *
     * Read from WooCommerce Admin's `wc_order_stats` (HPOS-neutral, and the only place
     * these aggregates are cheap). Cached six hours; `$force` refreshes it.
     */
    public static function baseline(bool $force = false): array
    {
        $key = 'zb_loyalty_baseline';
        if (!$force) {
            $cached = get_transient($key);
            if (is_array($cached)) {
                return $cached;
            }
        }

        $table = self::stats_table();
        if ($table === '') {
            return ['available' => false, 'reason' => 'wc_order_stats is not present on this store.'];
        }

        global $wpdb;
        $cutoff   = gmdate('Y-m-d H:i:s', time() - 365 * DAY_IN_SECONDS);
        $statuses = self::sale_statuses();
        $in       = implode(',', array_fill(0, count($statuses), '%s'));
        $where    = "WHERE status IN ({$in}) AND date_created_gmt >= %s AND customer_id > 0";
        $args     = array_merge($statuses, [$cutoff]);

        // 1) headline totals
        $totals = $wpdb->get_row($wpdb->prepare(
            "SELECT COUNT(*) AS orders, COUNT(DISTINCT customer_id) AS customers,"
            . " COALESCE(AVG(total_sales), 0) AS aov, COALESCE(SUM(total_sales), 0) AS revenue"
            . " FROM {$table} {$where}",
            $args
        ), ARRAY_A);

        // 2) how many orders each customer placed, bucketed
        $buckets = $wpdb->get_row($wpdb->prepare(
            "SELECT COUNT(*) AS customers,"
            . " SUM(c = 1) AS b1, SUM(c = 2) AS b2, SUM(c BETWEEN 3 AND 5) AS b35,"
            . " SUM(c >= 6) AS b6, SUM(c >= 2) AS repeaters"
            . " FROM (SELECT customer_id, COUNT(*) AS c FROM {$table} {$where} GROUP BY customer_id) t",
            $args
        ), ARRAY_A);

        // 3) did the first order lead to a second one within 90 days?
        $repurchase = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM ("
            . " SELECT customer_id, MIN(date_created_gmt) AS first_at FROM {$table} {$where} GROUP BY customer_id"
            . ') f WHERE EXISTS ('
            . " SELECT 1 FROM {$table} s2 WHERE s2.customer_id = f.customer_id AND s2.status IN ({$in})"
            . ' AND s2.date_created_gmt > f.first_at'
            . ' AND s2.date_created_gmt <= DATE_ADD(f.first_at, INTERVAL 90 DAY))',
            array_merge($args, $statuses)
        ));

        $customers = (int) ($buckets['customers'] ?? 0);

        $out = [
            'available'        => true,
            'computed_at'      => self::now(),
            'window_days'      => 365,
            'orders'           => (int) ($totals['orders'] ?? 0),
            'customers'        => $customers,
            'revenue_sar'      => round((float) ($totals['revenue'] ?? 0), 2),
            'avg_order_sar'    => round((float) ($totals['aov'] ?? 0), 2),
            'orders_per_customer' => $customers > 0 ? round(((int) ($totals['orders'] ?? 0)) / $customers, 2) : 0.0,
            'distribution'     => [
                'one'      => (int) ($buckets['b1'] ?? 0),
                'two'      => (int) ($buckets['b2'] ?? 0),
                'three_five' => (int) ($buckets['b35'] ?? 0),
                'six_plus' => (int) ($buckets['b6'] ?? 0),
            ],
            'repeat_customers' => (int) ($buckets['repeaters'] ?? 0),
            'repeat_rate'      => $customers > 0 ? round(((int) ($buckets['repeaters'] ?? 0)) / $customers * 100, 2) : 0.0,
            'repurchase_90d'   => $repurchase,
            'repurchase_90d_rate' => $customers > 0 ? round($repurchase / $customers * 100, 2) : 0.0,
        ];

        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }
}
