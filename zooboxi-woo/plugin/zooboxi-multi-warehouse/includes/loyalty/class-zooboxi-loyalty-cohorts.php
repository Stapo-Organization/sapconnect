<?php
/**
 * Zooboxi_Loyalty_Cohorts — «لوحة الأفواج»: does the program actually move anything?
 *
 * Three honest reads, all from WooCommerce's own analytics tables so the numbers
 * agree with the Analytics screens the owner already trusts:
 *
 *   1. ARMS. Customers who ordered in the window, split into players (members who
 *      see the game), the holdout (members drawn into the control group: paws and
 *      tiers, but no scratch cards or missions) and non-members. The players-minus-
 *      holdout gap is the effect of the GAME; the members-minus-none gap is mostly
 *      selection (people who open the app buy more anyway) and is labelled so.
 *   2. JOIN COHORTS. For every join month: did the member order again within 30/60/90
 *      days? Only matured cohorts count toward a rate, so a month that is ten days
 *      old does not read as "0 % retention".
 *   3. BEFORE / AFTER. The same-length window before launch against the one after.
 *
 * Everything is cached for six hours per window; the admin button forces a rebuild.
 * `wc_order_stats.customer_id` is the analytics customer id, NOT the user id — the
 * join through `wc_customer_lookup` is what makes the member match correct.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Cohorts
{
    public const WINDOWS = [30, 90, 180, 365];

    /** Below this many customers in an arm, a comparison is flagged as a small sample. */
    public const SMALL = 30;

    private static function stats(): string
    {
        return Zooboxi_Loyalty::stats_table();
    }

    private static function lookup(): string
    {
        global $wpdb;
        $table = $wpdb->prefix . 'wc_customer_lookup';
        return Zooboxi_Loyalty_Schema::table_exists($table) ? $table : '';
    }

    /** Order meta lives in a different table under HPOS. @return array{table:string,id:string} */
    private static function meta(): array
    {
        global $wpdb;
        $hpos = class_exists('\Automattic\WooCommerce\Utilities\OrderUtil')
            && \Automattic\WooCommerce\Utilities\OrderUtil::custom_orders_table_usage_is_enabled();
        if ($hpos && Zooboxi_Loyalty_Schema::table_exists($wpdb->prefix . 'wc_orders_meta')) {
            return ['table' => $wpdb->prefix . 'wc_orders_meta', 'id' => 'order_id'];
        }
        return ['table' => $wpdb->postmeta, 'id' => 'post_id'];
    }

    private static function statuses(): array
    {
        return ['wc-completed', 'wc-processing'];
    }

    private static function in(): string
    {
        return implode(',', array_fill(0, count(self::statuses()), '%s'));
    }

    /** Launch date: the owner's, else the first member's join. */
    public static function launched_at(): string
    {
        $set = (string) get_option('zooboxi_loyalty_launched_at', '');
        if ($set !== '' && strtotime($set)) {
            return gmdate('Y-m-d 00:00:00', strtotime($set));
        }
        global $wpdb;
        $first = (string) $wpdb->get_var('SELECT MIN(joined_at) FROM ' . Zooboxi_Loyalty_Schema::members());
        return $first !== '' ? $first : gmdate('Y-m-d 00:00:00');
    }

    /* ══════════════════════════════════════════════════════════════
       REPORT
       ══════════════════════════════════════════════════════════════ */

    public static function report(int $days = 90, bool $force = false): array
    {
        $days = in_array($days, self::WINDOWS, true) ? $days : 90;
        $key  = 'zb_loyalty_cohorts_' . $days;
        if (!$force) {
            $cached = get_transient($key);
            if (is_array($cached) && ($cached['_v'] ?? 0) === 1) {
                return $cached;
            }
        }

        $stats  = self::stats();
        $lookup = self::lookup();
        if ($stats === '' || $lookup === '') {
            return ['_v' => 1, 'available' => false, 'reason' => 'wc_order_stats / wc_customer_lookup missing'];
        }

        $out = [
            '_v'          => 1,
            'available'   => true,
            'computed_at' => Zooboxi_Loyalty::now(),
            'window_days' => $days,
            'launched_at' => self::launched_at(),
            'arms'        => self::arms($days),
            'cohorts'     => self::join_cohorts(),
            'launch'      => self::before_after($days),
            'weekly'      => self::weekly(12),
        ];
        $out['lift'] = self::lift($out['arms']);

        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }

    /* ── 1. arms ────────────────────────────────────────────────── */

    private static function arms(int $days): array
    {
        global $wpdb;
        $stats   = self::stats();
        $lookup  = self::lookup();
        $members = Zooboxi_Loyalty_Schema::members();
        $meta    = self::meta();
        $in      = self::in();
        $cutoff  = gmdate('Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS);
        $recent  = gmdate('Y-m-d H:i:s', time() - 30 * DAY_IN_SECONDS);

        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT arm, COUNT(*) AS customers, SUM(orders) AS orders, SUM(revenue) AS revenue,'
            . ' SUM(orders >= 2) AS repeaters, SUM(last_at >= %s) AS active_30, SUM(app_orders) AS app_orders'
            . ' FROM ('
            . '  SELECT c.user_id,'
            . "   CASE WHEN m.id IS NULL THEN 'none' WHEN m.holdout = 1 THEN 'holdout' ELSE 'players' END AS arm,"
            . '   COUNT(s.order_id) AS orders, COALESCE(SUM(s.total_sales), 0) AS revenue, MAX(s.date_created_gmt) AS last_at,'
            . '   SUM(CASE WHEN a.meta_value IS NULL THEN 0 ELSE 1 END) AS app_orders'
            . "  FROM {$stats} s"
            . "  INNER JOIN {$lookup} c ON c.customer_id = s.customer_id AND c.user_id > 0"
            . "  LEFT JOIN {$members} m ON m.user_id = c.user_id"
            . "  LEFT JOIN {$meta['table']} a ON a.{$meta['id']} = s.order_id AND a.meta_key = %s"
            . "  WHERE s.status IN ({$in}) AND s.date_created_gmt >= %s"
            . '  GROUP BY c.user_id, arm'
            . ' ) t GROUP BY arm',
            array_merge([$recent, Zooboxi_Loyalty::APP_ORDER_META], self::statuses(), [$cutoff])
        ), ARRAY_A);

        $arms = [];
        foreach (['players', 'holdout', 'none'] as $arm) {
            $arms[$arm] = [
                'customers' => 0, 'orders' => 0, 'revenue' => 0.0, 'aov' => 0.0, 'orders_per_customer' => 0.0,
                'repeat_rate' => 0.0, 'active_30_rate' => 0.0, 'app_share' => 0.0,
                'cost_sar' => 0.0, 'cost_per_customer' => 0.0, 'cost_pct' => null,
            ];
        }
        foreach ((array) $rows as $row) {
            $arm = (string) $row['arm'];
            if (!isset($arms[$arm])) {
                continue;
            }
            $customers = (int) $row['customers'];
            $orders    = (int) $row['orders'];
            $revenue   = (float) $row['revenue'];
            $arms[$arm] = array_merge($arms[$arm], [
                'customers'           => $customers,
                'orders'              => $orders,
                'revenue'             => round($revenue, 2),
                'aov'                 => $orders > 0 ? round($revenue / $orders, 2) : 0.0,
                'orders_per_customer' => $customers > 0 ? round($orders / $customers, 2) : 0.0,
                'repeat_rate'         => $customers > 0 ? round((int) $row['repeaters'] / $customers * 100, 1) : 0.0,
                'active_30_rate'      => $customers > 0 ? round((int) $row['active_30'] / $customers * 100, 1) : 0.0,
                'app_share'           => $orders > 0 ? round((int) $row['app_orders'] / $orders * 100, 1) : 0.0,
            ]);
        }

        // Program cost by arm (members only — non-members cost nothing by definition).
        $paw_value = Zooboxi_Loyalty::opt_float('paw_value_sar');
        $issued = $wpdb->get_results($wpdb->prepare(
            "SELECT CASE WHEN m.holdout = 1 THEN 'holdout' ELSE 'players' END AS arm, COALESCE(SUM(l.delta), 0) AS paws"
            . ' FROM ' . Zooboxi_Loyalty_Schema::ledger() . ' l'
            . " INNER JOIN {$members} m ON m.user_id = l.user_id"
            . " WHERE l.delta > 0 AND l.reason <> 'reverse' AND l.created_at >= %s GROUP BY arm",
            $cutoff
        ), ARRAY_A);
        $redeemed = $wpdb->get_results($wpdb->prepare(
            "SELECT CASE WHEN m.holdout = 1 THEN 'holdout' ELSE 'players' END AS arm, COALESCE(SUM(r.cost_sar), 0) AS cost"
            . ' FROM ' . Zooboxi_Loyalty_Schema::grants() . ' g'
            . ' INNER JOIN ' . Zooboxi_Loyalty_Schema::rewards() . ' r ON r.id = g.reward_id'
            . " INNER JOIN {$members} m ON m.user_id = g.user_id"
            . " WHERE g.state = 'redeemed' AND g.updated_at >= %s GROUP BY arm",
            $cutoff
        ), ARRAY_A);
        $cost = ['players' => 0.0, 'holdout' => 0.0];
        foreach ((array) $issued as $row) {
            $cost[(string) $row['arm']] += (float) $row['paws'] * $paw_value;
        }
        foreach ((array) $redeemed as $row) {
            $cost[(string) $row['arm']] += (float) $row['cost'];
        }
        foreach ($cost as $arm => $sar) {
            $arms[$arm]['cost_sar']          = round($sar, 2);
            $arms[$arm]['cost_per_customer'] = $arms[$arm]['customers'] > 0 ? round($sar / $arms[$arm]['customers'], 2) : 0.0;
            $arms[$arm]['cost_pct']          = $arms[$arm]['revenue'] > 0 ? round($sar / $arms[$arm]['revenue'] * 100, 2) : null;
        }

        return $arms;
    }

    /** Players minus holdout, with the sample-size caveat spelled out. */
    private static function lift(array $arms): array
    {
        $p = $arms['players'];
        $h = $arms['holdout'];
        $small = $p['customers'] < self::SMALL || $h['customers'] < self::SMALL;
        $pct = static function (float $a, float $b): ?float {
            return $b > 0 ? round(($a - $b) / $b * 100, 1) : null;
        };
        return [
            'small_sample'        => $small,
            'n_players'           => $p['customers'],
            'n_holdout'           => $h['customers'],
            'orders_per_customer' => ['players' => $p['orders_per_customer'], 'holdout' => $h['orders_per_customer'], 'lift_pct' => $pct((float) $p['orders_per_customer'], (float) $h['orders_per_customer'])],
            'repeat_rate'         => ['players' => $p['repeat_rate'], 'holdout' => $h['repeat_rate'], 'lift_pts' => $h['customers'] > 0 ? round($p['repeat_rate'] - $h['repeat_rate'], 1) : null],
            'aov'                 => ['players' => $p['aov'], 'holdout' => $h['aov'], 'lift_pct' => $pct((float) $p['aov'], (float) $h['aov'])],
            'active_30_rate'      => ['players' => $p['active_30_rate'], 'holdout' => $h['active_30_rate'], 'lift_pts' => $h['customers'] > 0 ? round($p['active_30_rate'] - $h['active_30_rate'], 1) : null],
        ];
    }

    /* ── 2. join cohorts ────────────────────────────────────────── */

    private static function join_cohorts(): array
    {
        global $wpdb;
        $stats   = self::stats();
        $lookup  = self::lookup();
        $members = Zooboxi_Loyalty_Schema::members();
        $in      = self::in();

        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT m.user_id, m.joined_at, m.holdout,'
            . ' COUNT(s.order_id) AS orders_after, COALESCE(SUM(s.total_sales), 0) AS rev_after, MIN(s.date_created_gmt) AS first_after'
            . " FROM {$members} m"
            . " LEFT JOIN {$lookup} c ON c.user_id = m.user_id"
            . " LEFT JOIN {$stats} s ON s.customer_id = c.customer_id AND s.status IN ({$in}) AND s.date_created_gmt > m.joined_at"
            . ' GROUP BY m.user_id, m.joined_at, m.holdout',
            self::statuses()
        ), ARRAY_A);

        $now     = time();
        $cohorts = [];
        foreach ((array) $rows as $row) {
            $joined = (int) strtotime((string) $row['joined_at'] . ' UTC');
            if ($joined <= 0) {
                continue;
            }
            $month = gmdate('Y-m', $joined);
            $arm   = (int) $row['holdout'] === 1 ? 'holdout' : 'players';
            if (!isset($cohorts[$month][$arm])) {
                $cohorts[$month][$arm] = [
                    'members' => 0, 'orders' => 0, 'revenue' => 0.0,
                    'matured' => ['30' => 0, '60' => 0, '90' => 0],
                    'ordered' => ['30' => 0, '60' => 0, '90' => 0],
                ];
            }
            $c = &$cohorts[$month][$arm];
            $c['members']++;
            $c['orders']  += (int) $row['orders_after'];
            $c['revenue'] += (float) $row['rev_after'];
            $first = !empty($row['first_after']) ? (int) strtotime((string) $row['first_after'] . ' UTC') : 0;
            foreach ([30, 60, 90] as $n) {
                if ($joined + $n * DAY_IN_SECONDS <= $now) {
                    $c['matured'][(string) $n]++;
                    if ($first > 0 && $first <= $joined + $n * DAY_IN_SECONDS) {
                        $c['ordered'][(string) $n]++;
                    }
                }
            }
            unset($c);
        }
        krsort($cohorts);

        $out = [];
        foreach ($cohorts as $month => $arms) {
            foreach ($arms as $arm => $c) {
                $rates = [];
                foreach ([30, 60, 90] as $n) {
                    $m = (int) $c['matured'][(string) $n];
                    $rates[(string) $n] = $m > 0 ? round((int) $c['ordered'][(string) $n] / $m * 100, 1) : null;
                }
                $out[] = [
                    'month'              => $month,
                    'arm'                => $arm,
                    'members'            => (int) $c['members'],
                    'orders_per_member'  => $c['members'] > 0 ? round($c['orders'] / $c['members'], 2) : 0.0,
                    'revenue_per_member' => $c['members'] > 0 ? round($c['revenue'] / $c['members'], 2) : 0.0,
                    'retention'          => $rates,
                    'matured'            => $c['matured'],
                ];
            }
        }
        return $out;
    }

    /* ── 3. before / after launch ───────────────────────────────── */

    private static function window_stats(string $from, string $to): array
    {
        global $wpdb;
        $stats = self::stats();
        $in    = self::in();
        $args  = array_merge(self::statuses(), [$from, $to]);

        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT COUNT(*) AS orders, COUNT(DISTINCT customer_id) AS customers,'
            . ' COALESCE(SUM(total_sales), 0) AS revenue, COALESCE(AVG(total_sales), 0) AS aov'
            . " FROM {$stats} WHERE status IN ({$in}) AND date_created_gmt >= %s AND date_created_gmt < %s AND customer_id > 0",
            $args
        ), ARRAY_A);
        $repeaters = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM (SELECT customer_id FROM {$stats} WHERE status IN ({$in}) AND date_created_gmt >= %s AND date_created_gmt < %s AND customer_id > 0"
            . ' GROUP BY customer_id HAVING COUNT(*) >= 2) r',
            $args
        ));
        $customers = (int) ($row['customers'] ?? 0);
        $orders    = (int) ($row['orders'] ?? 0);
        return [
            'from'                => $from,
            'to'                  => $to,
            'orders'              => $orders,
            'customers'           => $customers,
            'revenue'             => round((float) ($row['revenue'] ?? 0), 2),
            'aov'                 => round((float) ($row['aov'] ?? 0), 2),
            'orders_per_customer' => $customers > 0 ? round($orders / $customers, 2) : 0.0,
            'repeat_rate'         => $customers > 0 ? round($repeaters / $customers * 100, 1) : 0.0,
        ];
    }

    private static function before_after(int $days): array
    {
        $launch = self::launched_at();
        $ts     = (int) strtotime($launch . ' UTC');
        $now    = time();
        $after_days = max(1, min($days, (int) ceil(($now - $ts) / DAY_IN_SECONDS)));
        $after  = self::window_stats(gmdate('Y-m-d H:i:s', $ts), gmdate('Y-m-d H:i:s', $now));
        $before = self::window_stats(gmdate('Y-m-d H:i:s', $ts - $after_days * DAY_IN_SECONDS), gmdate('Y-m-d H:i:s', $ts));
        return ['days' => $after_days, 'before' => $before, 'after' => $after];
    }

    /* ── 4. weekly trend ────────────────────────────────────────── */

    private static function weekly(int $weeks): array
    {
        global $wpdb;
        $stats  = self::stats();
        $in     = self::in();
        $cutoff = gmdate('Y-m-d H:i:s', strtotime('monday this week', time()) - ($weeks - 1) * WEEK_IN_SECONDS);

        $orders = $wpdb->get_results($wpdb->prepare(
            "SELECT YEARWEEK(date_created_gmt, 3) AS yw, COUNT(*) AS orders, COALESCE(SUM(total_sales), 0) AS revenue"
            . " FROM {$stats} WHERE status IN ({$in}) AND date_created_gmt >= %s GROUP BY yw ORDER BY yw",
            array_merge(self::statuses(), [$cutoff])
        ), ARRAY_A);
        $joins = $wpdb->get_results($wpdb->prepare(
            'SELECT YEARWEEK(joined_at, 3) AS yw, COUNT(*) AS members FROM ' . Zooboxi_Loyalty_Schema::members()
            . ' WHERE joined_at >= %s GROUP BY yw',
            $cutoff
        ), ARRAY_A);

        $by = [];
        foreach ((array) $orders as $row) {
            $by[(string) $row['yw']] = ['orders' => (int) $row['orders'], 'revenue' => round((float) $row['revenue'], 2), 'members' => 0];
        }
        foreach ((array) $joins as $row) {
            $by[(string) $row['yw']] = ($by[(string) $row['yw']] ?? ['orders' => 0, 'revenue' => 0.0, 'members' => 0]);
            $by[(string) $row['yw']]['members'] = (int) $row['members'];
        }
        ksort($by);

        $out = [];
        foreach ($by as $yw => $v) {
            $year = (int) substr($yw, 0, 4);
            $week = (int) substr($yw, 4);
            $monday = strtotime(sprintf('%04dW%02d', $year, $week));
            $out[] = ['week' => $monday ? gmdate('Y-m-d', $monday) : $yw] + $v;
        }
        return $out;
    }
}
