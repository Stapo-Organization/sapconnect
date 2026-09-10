<?php
/**
 * Journeys — multi-step conversations with one customer, driven by time.
 *
 * A journey is a short list of steps. A customer enters it once for a
 * given reason (the entry key), sleeps until the step's wake time, and the
 * five-minute tick runs the step: it looks at the world as it is *now*, may
 * queue one notification through the engine, and either sets the next wake
 * or ends. Buying ends the journeys that were asking for a purchase.
 *
 * Steps are plain PHP closures, not a graph editor: six journeys with two
 * or three steps each are read faster as code than as JSON, and each step
 * can ask the store anything (has a pet? sealed scratch card? still in the
 * cart?) without a rules language. Every step is written to be re-run
 * safely — the engine's idempotency key makes a double tick harmless.
 *
 * Journeys here (source name in the outbox in brackets):
 *   welcome          [welcome]    a new install with no order yet
 *   post_first_order [post_first] the ten days after the first delivery
 *   winback          [winback]    silence past the customer's own rhythm
 *   supply           [reorder]    the food gauge: −4 days, then −1 day
 *   cart             [cart]       a basket left behind
 *   rating           [rating]     a delivery just made
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Journeys
{
    const ACTIVE = 'active';
    const DONE   = 'done';
    const EXITED = 'exited';

    /** The journeys that end when the customer orders. */
    const EXIT_ON_ORDER = ['welcome', 'post_first_order', 'winback', 'cart'];

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_journey_runs';
    }

    public static function install(string $collate): string
    {
        return 'CREATE TABLE ' . self::table() . " (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            journey VARCHAR(24) NOT NULL,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            entry_key VARCHAR(80) NOT NULL DEFAULT '',
            step SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            status VARCHAR(8) NOT NULL DEFAULT 'active',
            wake_at DATETIME NULL,
            context LONGTEXT NULL,
            reason VARCHAR(32) NOT NULL DEFAULT '',
            lock_token VARCHAR(36) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY  (id),
            UNIQUE KEY entry (journey, user_id, guest_id, entry_key),
            KEY due (status, wake_at),
            KEY person (user_id, guest_id, status)
        ) {$collate};";
    }

    public static function boot(): void
    {
        add_action('zooboxi_push_tick', [self::class, 'tick'], 20);
        add_action('zooboxi_push_daily', [self::class, 'daily'], 10);
        add_action('woocommerce_order_status_completed', [self::class, 'on_completed'], 30, 2);
        add_action('woocommerce_checkout_order_processed', [self::class, 'on_order_placed'], 30, 1);
        add_action('woocommerce_order_status_processing', [self::class, 'on_order_placed'], 30, 2);
        add_action('zooboxi_push_device_registered', [self::class, 'on_device_registered'], 10, 3);
    }

    /** Which journeys the owner has switched on (all, by default). */
    public static function enabled(string $journey): bool
    {
        $raw = get_option('zooboxi_push_journeys', []);
        $raw = is_array($raw) ? $raw : [];
        return ($raw[$journey] ?? 'yes') !== 'no';
    }

    public static function all(): array
    {
        return [
            'welcome'          => ['name' => 'رحلة الترحيب',        'source' => 'welcome',    'tier' => Zooboxi_Push_Gate::TIER_MARKETING, 'topic' => 'offers'],
            'post_first_order' => ['name' => 'بعد أول طلب',          'source' => 'post_first', 'tier' => Zooboxi_Push_Gate::TIER_MARKETING, 'topic' => 'family'],
            'winback'          => ['name' => 'الاستعادة',             'source' => 'winback',    'tier' => Zooboxi_Push_Gate::TIER_MARKETING, 'topic' => 'reorder'],
            'supply'           => ['name' => 'الطعام قبل أن يخلص',   'source' => 'reorder',    'tier' => Zooboxi_Push_Gate::TIER_MARKETING, 'topic' => 'reorder'],
            'cart'             => ['name' => 'السلة المنسية',         'source' => 'cart',       'tier' => Zooboxi_Push_Gate::TIER_SERVICE,   'topic' => 'offers'],
            'rating'           => ['name' => 'قيّم توصيلتك',          'source' => 'rating',     'tier' => Zooboxi_Push_Gate::TIER_SERVICE,   'topic' => 'orders'],
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       ENROL / EXIT
       ══════════════════════════════════════════════════════════════ */

    /**
     * Put one person into a journey. A second call with the same entry key
     * is a no-op; a finished run with the same key is not restarted.
     */
    public static function enroll(string $journey, int $user_id, string $guest_id, string $entry_key, array $context, int $wake_at): int
    {
        if (!isset(self::all()[$journey]) || !self::enabled($journey)) {
            return 0;
        }
        if ($user_id <= 0 && $guest_id === '') {
            return 0;
        }
        global $wpdb;
        $prev = $wpdb->suppress_errors(true);
        $ok   = $wpdb->query($wpdb->prepare(
            'INSERT IGNORE INTO ' . self::table()
            . ' (journey, user_id, guest_id, entry_key, step, status, wake_at, context, created_at, updated_at)'
            . ' VALUES (%s, %d, %s, %s, 0, %s, %s, %s, %s, %s)',
            $journey, $user_id, $user_id > 0 ? '' : substr($guest_id, 0, 64), substr($entry_key, 0, 80),
            self::ACTIVE, gmdate('Y-m-d H:i:s', $wake_at), wp_json_encode($context), gmdate('Y-m-d H:i:s'), gmdate('Y-m-d H:i:s')
        ));
        $wpdb->suppress_errors($prev);
        return $ok ? (int) $wpdb->insert_id : 0;
    }

    public static function has_active(string $journey, int $user_id, string $guest_id): bool
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . self::table() . ' WHERE journey = %s AND status = %s AND user_id = %d AND guest_id = %s',
            $journey, self::ACTIVE, $user_id, $user_id > 0 ? '' : $guest_id
        )) > 0;
    }

    /** The most recent run of a journey for a person, any status. */
    public static function last_run(string $journey, int $user_id, string $guest_id): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE journey = %s AND user_id = %d AND guest_id = %s ORDER BY id DESC LIMIT 1',
            $journey, $user_id, $user_id > 0 ? '' : $guest_id
        ), ARRAY_A);
        return $row ?: null;
    }

    private static function finish(int $id, string $status, string $reason = ''): void
    {
        global $wpdb;
        $wpdb->update(self::table(), [
            'status' => $status, 'reason' => substr($reason, 0, 32), 'wake_at' => null,
            'lock_token' => null, 'updated_at' => gmdate('Y-m-d H:i:s'),
        ], ['id' => $id]);
    }

    private static function advance(int $id, int $step, int $wake_at, array $context): void
    {
        global $wpdb;
        $wpdb->update(self::table(), [
            'step' => $step, 'wake_at' => gmdate('Y-m-d H:i:s', $wake_at), 'context' => wp_json_encode($context),
            'lock_token' => null, 'updated_at' => gmdate('Y-m-d H:i:s'),
        ], ['id' => $id]);
    }

    /** An order was placed: the journeys that asked for one are over. */
    public static function on_order_placed($order_id, $order = null): void
    {
        try {
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order((int) $order_id);
            }
            if (!($order instanceof \WC_Order)) {
                return;
            }
            self::exit_for_person((int) $order->get_customer_id(), (string) $order->get_meta('_zb_guest_id'), self::EXIT_ON_ORDER, 'converted');
            // The food reminder ends only when *that* product was bought.
            $pids = [];
            foreach ($order->get_items() as $item) {
                if ($item instanceof \WC_Order_Item_Product) {
                    $pids[] = (int) $item->get_product_id();
                    $pids[] = (int) $item->get_variation_id();
                }
            }
            $pids = array_values(array_unique(array_filter($pids)));
            if ($pids && (int) $order->get_customer_id() > 0) {
                global $wpdb;
                $runs = $wpdb->get_results($wpdb->prepare(
                    'SELECT id, context FROM ' . self::table() . ' WHERE journey = %s AND status = %s AND user_id = %d',
                    'supply', self::ACTIVE, (int) $order->get_customer_id()
                ), ARRAY_A) ?: [];
                foreach ($runs as $run) {
                    $ctx = json_decode((string) $run['context'], true) ?: [];
                    if (in_array((int) ($ctx['product_id'] ?? 0), $pids, true)) {
                        self::finish((int) $run['id'], self::EXITED, 'converted');
                    }
                }
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] journey exit failed: ' . $e->getMessage());
        }
    }

    public static function exit_for_person(int $user_id, string $guest_id, array $journeys, string $reason): int
    {
        if ($user_id <= 0 && $guest_id === '') {
            return 0;
        }
        global $wpdb;
        $where = $user_id > 0
            ? $wpdb->prepare('user_id = %d', $user_id)
            : $wpdb->prepare('user_id = 0 AND guest_id = %s', $guest_id);
        $in = implode(',', array_map(fn ($j) => $wpdb->prepare('%s', $j), $journeys));
        return (int) $wpdb->query(
            'UPDATE ' . self::table() . $wpdb->prepare(
                ' SET status = %s, reason = %s, wake_at = NULL, updated_at = %s WHERE status = %s AND ',
                self::EXITED, $reason, gmdate('Y-m-d H:i:s'), self::ACTIVE
            ) . $where . ' AND journey IN (' . $in . ')'
        );
    }

    /* ══════════════════════════════════════════════════════════════
       ENTRY POINTS
       ══════════════════════════════════════════════════════════════ */

    /** A phone registered: someone new may have arrived. */
    public static function on_device_registered(int $user_id, string $guest_id, bool $is_new): void
    {
        try {
            if (!$is_new) {
                return;
            }
            if ($user_id > 0 && self::completed_count($user_id) > 0) {
                return;
            }
            [$lat, $lng] = class_exists('Zooboxi_V2_Bootstrap') ? Zooboxi_V2_Bootstrap::latlng() : [0.0, 0.0];
            self::enroll('welcome', $user_id, $guest_id, 'welcome', ['lat' => $lat, 'lng' => $lng], time() + DAY_IN_SECONDS);
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] welcome enrol failed: ' . $e->getMessage());
        }
    }

    /** A delivery was made: rating, and — if it was the first — the follow-up. */
    public static function on_completed($order_id, $order = null): void
    {
        try {
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order((int) $order_id);
            }
            if (!($order instanceof \WC_Order)) {
                return;
            }
            $uid   = (int) $order->get_customer_id();
            $guest = (string) $order->get_meta('_zb_guest_id');
            $express = (string) $order->get_meta('_zooboxi_delivery_type') === 'express';
            $now = time();

            // Rating: 90 minutes after an express delivery, 18:00 the next
            // day for a parcel — when the box has actually been opened.
            $wake = $express
                ? $now + 90 * MINUTE_IN_SECONDS
                : (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz())->modify('+1 day')->setTime(18, 0)->getTimestamp();
            self::enroll('rating', $uid, $guest, 'rating:' . $order->get_id(), ['order_id' => $order->get_id(), 'express' => $express], $wake);

            if ($uid > 0 && self::completed_count($uid) === 1) {
                self::enroll('post_first_order', $uid, '', 'first:' . $order->get_id(), ['order_id' => $order->get_id()], $now + 2 * DAY_IN_SECONDS);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] completed-order enrol failed: ' . $e->getMessage());
        }
    }

    /** Once a day: whose food is running out, and who has gone quiet. */
    public static function daily(): void
    {
        self::enrol_supply();
        self::enrol_winback();
    }

    /**
     * The food gauge, as a journey: −4 days «يكفي 4 أيام», then −1 day
     * «يخلص بكرة» unless the product was bought in between. One product
     * per person — the soonest — and never more than once a fortnight
     * for the same product.
     */
    private static function enrol_supply(): void
    {
        if (!self::enabled('supply') || !class_exists('Zooboxi_Loyalty_Supply') || !Zooboxi_Loyalty_Supply::enabled()) {
            return;
        }
        global $wpdb;
        $batch  = 300;
        $offset = (int) get_option('zooboxi_push_supply_cursor', 0);
        $users  = $wpdb->get_col($wpdb->prepare(
            'SELECT DISTINCT user_id FROM ' . Zooboxi_Push::table() . ' WHERE user_id > 0 AND enabled = 1 ORDER BY user_id LIMIT %d OFFSET %d',
            $batch, $offset
        ));
        update_option('zooboxi_push_supply_cursor', count($users) < $batch ? 0 : $offset + $batch, false);

        foreach ((array) $users as $uid) {
            $uid = (int) $uid;
            try {
                $pick = self::soonest_supply($uid, 4);
                if ($pick === null) {
                    continue;
                }
                $pid = (int) $pick['product_id'];
                $last = (int) get_user_meta($uid, '_zb_push_reorder_' . $pid, true);
                if ($last > 0 && $last > time() - 14 * DAY_IN_SECONDS) {
                    continue;
                }
                $runs_out = (int) ($pick['runs_out_ts'] ?? 0);
                $key = 'supply:' . $pid . ':' . ($runs_out > 0 ? gmdate('Y-m-d', $runs_out) : gmdate('Y-m-d'));
                self::enroll('supply', $uid, '', $key, [
                    'product_id'  => $pid,
                    'pet_id'      => (int) ($pick['pet_id'] ?? 0),
                    'runs_out_ts' => $runs_out,
                    'express'     => Zooboxi_Push_Events::last_order_was_express($uid),
                ], time());
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] supply enrol failed for ' . $uid . ': ' . $e->getMessage());
            }
        }
    }

    /** The single soonest supply line inside [$within] days, or null. */
    public static function soonest_supply(int $uid, int $within): ?array
    {
        $rows = Zooboxi_Loyalty_Supply::items($uid);
        $pick = null;
        $pick_days = null;
        foreach ($rows as $row) {
            $state = Zooboxi_Loyalty_Supply::state_of($row);
            if (!in_array($state['status'], ['soon', 'due'], true) || $state['days_left'] > $within) {
                continue;
            }
            if ($pick === null || $state['days_left'] < $pick_days) {
                $pick = $row + ['days_left' => (int) $state['days_left']];
                $pick_days = (int) $state['days_left'];
            }
        }
        return $pick;
    }

    /**
     * Win-back: ten days past the customer's own expected date with no
     * order — three rungs (+10, +45, +90 days), then silence. Never twice
     * inside 120 days, never for the holdout.
     */
    private static function enrol_winback(): void
    {
        if (!self::enabled('winback') || !class_exists('Zooboxi_Loyalty_Members') || !class_exists('Zooboxi_Loyalty_Schema')) {
            return;
        }
        global $wpdb;
        $members = $wpdb->get_col($wpdb->prepare(
            'SELECT user_id FROM ' . Zooboxi_Loyalty_Schema::members()
            . ' WHERE holdout = 0 AND last_earn_at IS NOT NULL AND last_earn_at <= %s ORDER BY last_earn_at ASC LIMIT 200',
            gmdate('Y-m-d H:i:s', time() - 20 * DAY_IN_SECONDS)
        )) ?: [];
        foreach ($members as $uid) {
            $uid = (int) $uid;
            try {
                if (self::has_active('winback', $uid, '')) {
                    continue;
                }
                $last = self::last_run('winback', $uid, '');
                if ($last && Zooboxi_Push_Engine::ts($last['created_at']) > time() - 120 * DAY_IN_SECONDS) {
                    continue;
                }
                $expected = self::expected_next_order($uid);
                if ($expected === null || time() < $expected + 10 * DAY_IN_SECONDS) {
                    continue;
                }
                $last_order = self::last_order_ts($uid);
                if ($last_order > 0 && self::ordered_since($uid, $last_order + 60)) {
                    continue; // something newer exists (pending/processing)
                }
                self::enroll('winback', $uid, '', 'winback:' . gmdate('Y-m', $expected), [
                    'expected' => $expected,
                    'product'  => self::last_product_name($uid),
                    'pet'      => class_exists('Zooboxi_Loyalty_Pets') ? Zooboxi_Loyalty_Pets::first_name($uid, '', '') : '',
                ], time());
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] winback enrol failed for ' . $uid . ': ' . $e->getMessage());
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════
       THE TICK — run every step that is due
       ══════════════════════════════════════════════════════════════ */

    public static function tick(int $now = 0): int
    {
        $now = $now > 0 ? $now : time();
        global $wpdb;
        $utc   = gmdate('Y-m-d H:i:s', $now);
        $token = wp_generate_uuid4();
        $wpdb->query($wpdb->prepare(
            'UPDATE ' . self::table() . ' SET lock_token = %s WHERE status = %s AND wake_at IS NOT NULL AND wake_at <= %s AND lock_token IS NULL ORDER BY wake_at ASC LIMIT 200',
            $token, self::ACTIVE, $utc
        ));
        $runs = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . self::table() . ' WHERE lock_token = %s', $token), ARRAY_A) ?: [];
        $n = 0;
        foreach ($runs as $run) {
            try {
                self::run_step($run, $now);
                $n++;
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] journey step failed #' . $run['id'] . ': ' . $e->getMessage());
                self::finish((int) $run['id'], self::EXITED, 'exception');
            }
        }
        $wpdb->query($wpdb->prepare('UPDATE ' . self::table() . ' SET lock_token = NULL WHERE lock_token = %s', $token));
        return $n;
    }

    private static function run_step(array $run, int $now): void
    {
        $journey = (string) $run['journey'];
        $def     = self::all()[$journey] ?? null;
        if ($def === null || !self::enabled($journey)) {
            self::finish((int) $run['id'], self::EXITED, 'disabled');
            return;
        }
        $ctx  = json_decode((string) $run['context'], true) ?: [];
        $step = (int) $run['step'];
        $uid  = (int) $run['user_id'];
        $gid  = (string) $run['guest_id'];

        $method = 'step_' . $journey;
        /** @var array{message?:array|null,next?:int|null,exit?:string|null} $out */
        $out = self::$method($step, $uid, $gid, $ctx, $now);

        if (!empty($out['message'])) {
            $msg = $out['message'] + [
                'user_id'  => $uid,
                'guest_id' => $gid,
                'topic'    => $def['topic'],
                'tier'     => $def['tier'],
                'source'   => $def['source'],
                'key'      => $def['source'] . ':' . $run['id'] . ':' . $step,
            ];
            Zooboxi_Push_Engine::submit($msg);
        }
        if (!empty($out['exit'])) {
            self::finish((int) $run['id'], self::EXITED, (string) $out['exit']);
            return;
        }
        if (!empty($out['next'])) {
            self::advance((int) $run['id'], $step + 1, (int) $out['next'], $out['context'] ?? $ctx);
            return;
        }
        self::finish((int) $run['id'], self::DONE);
    }

    /* ══════════════════════════════════════════════════════════════
       THE STEPS
       ══════════════════════════════════════════════════════════════ */

    /** +24 h: no pet → «عرّفنا على صديقك»; +3 d: no order → first-order nudge; +7 d: last word. */
    private static function step_welcome(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        if ($uid > 0 && self::completed_count($uid) > 0) {
            return ['exit' => 'converted'];
        }
        switch ($step) {
            case 0:
                $has_pet = $uid > 0 && class_exists('Zooboxi_Loyalty_Pets') && Zooboxi_Loyalty_Pets::count($uid) > 0;
                $msg = ($uid > 0 && !$has_pet) ? [
                    'copy'  => [
                        'ar' => ['عرّفنا على صديقك', 'أضف حيوانك — نحسب له طعامه ونذكّرك قبل أن يخلص.'],
                        'en' => ['Tell us about your pet', 'Add your pet — we work out their food and remind you before it runs out.'],
                    ],
                    'route' => '/pets/new', 'thread_id' => 'family', 'level' => 'passive', 'relevance' => 0.5,
                ] : null;
                return ['message' => $msg, 'next' => $now + 2 * DAY_IN_SECONDS];
            case 1:
                $express = self::in_express_zone((float) ($ctx['lat'] ?? 0), (float) ($ctx['lng'] ?? 0));
                $msg = $express ? [
                    'copy'  => [
                        'ar' => ['أول طلب يوصلك خلال ساعتين', 'إكسبريس يخدم عنوانك — اطلب اليوم وتعرّف على السرعة.'],
                        'en' => ['Your first order arrives within two hours', 'Express serves your address — try it today.'],
                    ],
                    'route' => '/home',
                ] : [
                    'copy'  => [
                        'ar' => ['هدية الترحيب بانتظارك', 'في محفظتك هدية على أول طلب — لا تفوّتها.'],
                        'en' => ['Your welcome gift is waiting', 'A gift on your first order is sitting in your wallet.'],
                    ],
                    'route' => '/family',
                ];
                return ['message' => $msg + ['thread_id' => 'welcome', 'relevance' => 0.6], 'next' => $now + 4 * DAY_IN_SECONDS];
            default:
                return ['message' => [
                    'copy'  => [
                        'ar' => ['كل ما يحتاجه صديقك في مكان واحد', 'طعام، رمل، ألعاب — بسعر الجملة وتوصيل سريع. متى ما احتجتنا.'],
                        'en' => ['Everything your pet needs, in one place', 'Food, litter, toys — wholesale prices and fast delivery, whenever you need us.'],
                    ],
                    'route' => '/categories', 'level' => 'passive', 'relevance' => 0.4,
                ]];
        }
    }

    /** +2 d: a sealed scratch card; +10 d: no second order → buy again. */
    private static function step_post_first_order(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        if ($uid <= 0) {
            return ['exit' => 'guest'];
        }
        if (self::ordered_since($uid, Zooboxi_Push_Engine::ts(self::last_run('post_first_order', $uid, '')['created_at'] ?? null))) {
            return ['exit' => 'converted'];
        }
        if ($step === 0) {
            $card = self::sealed_scratch($uid);
            $msg = $card !== null ? [
                'copy'  => [
                    'ar' => ['بطاقة الخدش بانتظارك', 'الجائزة تنطبق على طلبك القادم — افتحها الآن.'],
                    'en' => ['Your scratch card is waiting', 'The prize applies to your next order — open it now.'],
                ],
                'route' => '/family/scratch/' . $card, 'thread_id' => 'family', 'relevance' => 0.7,
            ] : null;
            return ['message' => $msg, 'next' => $now + 8 * DAY_IN_SECONDS];
        }
        $product = self::last_product_name($uid);
        return ['message' => [
            'copy'  => [
                'ar' => ['اطلب مجددًا بضغطة', $product !== '' ? $product . ' وما اشتريته معه — جاهز لإعادة الطلب.' : 'مشترياتك السابقة جاهزة لإعادة الطلب بنفس الكميات.'],
                'en' => ['Reorder in one tap', $product !== '' ? $product . ' and what you bought with it — ready to reorder.' : 'Your past purchases are ready to reorder.'],
            ],
            'route' => '/buy-again', 'relevance' => 0.6,
        ]];
    }

    /** +10 d: their usual product; +45 d: the bigger gift; +90 d: the last word. */
    private static function step_winback(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        $last = self::last_order_ts($uid);
        if ($last > 0 && self::ordered_since($uid, $last + 60)) {
            return ['exit' => 'converted'];
        }
        $pet = (string) ($ctx['pet'] ?? '');
        $product = (string) ($ctx['product'] ?? '');
        switch ($step) {
            case 0:
                return ['message' => [
                    'copy' => [
                        'ar' => [$pet !== '' ? $pet . ' عادةً يحتاج طعامه الآن' : 'حان وقت التموين المعتاد', $product !== '' ? $product . ' — نجهّزه لك بنفس الكمية؟' : 'مشترياتك السابقة جاهزة بضغطة واحدة.'],
                        'en' => [$pet !== '' ? $pet . ' usually needs food about now' : 'Time for the usual restock', $product !== '' ? $product . ' — shall we get it ready in the same quantity?' : 'Your past purchases are one tap away.'],
                    ],
                    'route' => '/buy-again', 'relevance' => 0.7,
                ], 'next' => $now + 35 * DAY_IN_SECONDS];
            case 1:
                return ['message' => [
                    'copy' => [
                        'ar' => [$pet !== '' ? 'نشتاق لـ' . $pet : 'اشتقنا لك', 'هدية أكبر من المعتاد على طلبك القادم — بانتظارك في عائلة زوبوكسي.'],
                        'en' => [$pet !== '' ? 'We miss ' . $pet : 'We miss you', 'A bigger-than-usual gift on your next order is waiting in Zooboxi Family.'],
                    ],
                    'route' => '/family', 'relevance' => 0.7,
                ], 'next' => $now + 45 * DAY_IN_SECONDS];
            default:
                return ['message' => [
                    'copy' => [
                        'ar' => ['آخر رسالة منا', 'لن نزعجك بعدها — ونحن هنا متى ما احتاج ' . ($pet !== '' ? $pet : 'صديقك') . ' شيئًا.'],
                        'en' => ['Our last message', 'We will not bother you again — and we are here whenever ' . ($pet !== '' ? $pet : 'your pet') . ' needs something.'],
                    ],
                    'route' => '/home', 'level' => 'passive', 'relevance' => 0.3,
                ]];
        }
    }

    /** −4 d: «يكفي 4 أيام»; −1 d: «يخلص بكرة». */
    private static function step_supply(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        $pid = (int) ($ctx['product_id'] ?? 0);
        $product = $pid > 0 ? wc_get_product($pid) : null;
        if (!$product) {
            return ['exit' => 'gone'];
        }
        if (self::bought_since($uid, $pid, Zooboxi_Push_Engine::ts(self::last_run('supply', $uid, '')['created_at'] ?? null))) {
            return ['exit' => 'converted'];
        }
        $pet = '';
        if ((int) ($ctx['pet_id'] ?? 0) > 0 && class_exists('Zooboxi_Loyalty_Pets')) {
            $p = Zooboxi_Loyalty_Pets::find((int) $ctx['pet_id'], $uid);
            $pet = $p ? (string) $p['name'] : '';
        }
        $name    = wp_strip_all_tags($product->get_name());
        $express = !empty($ctx['express']);
        $runs_out = (int) ($ctx['runs_out_ts'] ?? 0);
        $days = $runs_out > 0 ? max(0, (int) ceil(($runs_out - $now) / DAY_IN_SECONDS)) : 4;

        if ($step === 0) {
            $next = $runs_out > 0 ? $runs_out - DAY_IN_SECONDS : 0;
            return ['message' => [
                'copy' => [
                    'ar' => [
                        $days > 0 ? ($pet !== '' ? 'طعام ' . $pet . ' يكفي ' . $days . ' أيام' : 'يخلص خلال ' . $days . ' أيام: ' . $name) : ($pet !== '' ? 'خلص طعام ' . $pet : 'خلص: ' . $name),
                        'اطلبه في وقته واكسب +20% بصمات' . ($express ? ' — إكسبريس يوصله خلال ساعتين.' : '.'),
                    ],
                    'en' => [
                        $days > 0 ? ($pet !== '' ? $pet . "'s food lasts " . $days . ' more days' : 'Running out in ' . $days . ' days: ' . $name) : ($pet !== '' ? $pet . "'s food has run out" : 'Run out: ' . $name),
                        'Order it on time and earn +20% paws' . ($express ? ' — Express brings it within two hours.' : '.'),
                    ],
                ],
                'route' => '/family/supply', 'data' => ['product_id' => (string) $pid], 'collapse_key' => 'supply-' . $pid,
                'thread_id' => 'family', 'relevance' => 0.8, 'express' => $express,
            ], 'next' => ($next > $now + 6 * HOUR_IN_SECONDS) ? $next : 0];
        }
        return ['message' => [
            'copy' => [
                'ar' => [$pet !== '' ? 'طعام ' . $pet . ' يخلص بكرة' : 'يخلص بكرة: ' . $name, $express ? 'اطلبه الآن إكسبريس ويوصلك خلال ساعتين.' : 'اطلبه الآن قبل أن ينفد.'],
                'en' => [$pet !== '' ? $pet . "'s food runs out tomorrow" : 'Runs out tomorrow: ' . $name, $express ? 'Order it on Express now and it arrives within two hours.' : 'Order it now before it runs out.'],
            ],
            'route' => '/family/supply', 'data' => ['product_id' => (string) $pid], 'collapse_key' => 'supply-' . $pid,
            'thread_id' => 'family', 'relevance' => 0.9, 'express' => $express, 'sto' => false,
        ]];
    }

    /** The basket left behind: one reminder; a second a day later only for a real basket. */
    private static function step_cart(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        if (!class_exists('Zooboxi_Push_Cart')) {
            return ['exit' => 'gone'];
        }
        $snap = Zooboxi_Push_Cart::snapshot($uid, $gid);
        if ($snap === null || (int) $snap['count'] <= 0 || (string) $snap['items_hash'] !== (string) ($ctx['hash'] ?? '')) {
            return ['exit' => 'changed'];
        }
        // Touched in the last twenty minutes: still shopping, not abandoning.
        if (Zooboxi_Push_Engine::ts($snap['updated_at']) > $now - 20 * MINUTE_IN_SECONDS) {
            return ['next' => $now + 30 * MINUTE_IN_SECONDS];
        }
        if ($uid > 0 && self::ordered_since($uid, Zooboxi_Push_Engine::ts($snap['updated_at']) - 60)) {
            return ['exit' => 'converted'];
        }
        $first   = (string) $snap['first_name'];
        $count   = (int) $snap['count'];
        $total   = (float) $snap['total'];
        $express = !empty($snap['express']);
        $price   = number_format($total, 0) . ' ﷼';

        if ($step === 0) {
            $second = !$express && $total >= 100 ? $now + DAY_IN_SECONDS : 0;
            return ['message' => [
                'copy' => [
                    'ar' => [$first !== '' ? $first . ' لا يزال في سلتك' : 'سلتك بانتظارك', $express ? 'اطلبه الآن ويوصلك خلال ساعتين.' : ($count > 1 ? $count . ' منتجات بـ ' . $price . ' — أكمل طلبك بضغطة.' : 'أكمل طلبك بضغطة.')],
                    'en' => [$first !== '' ? $first . ' is still in your basket' : 'Your basket is waiting', $express ? 'Order now and it arrives within two hours.' : ($count > 1 ? $count . ' items for ' . $price . ' — finish in one tap.' : 'Finish your order in one tap.')],
                ],
                'route' => '/cart', 'collapse_key' => 'cart', 'thread_id' => 'cart', 'relevance' => 0.8,
                'expires_at' => $express ? Zooboxi_Push_Cart::express_close_after($snap, $now) : $now + 12 * HOUR_IN_SECONDS,
            ], 'next' => $second];
        }
        return ['message' => [
            'copy' => [
                'ar' => ['سلتك محفوظة', $count . ' منتجات بـ ' . $price . ' — بانتظارك متى ما رجعت.'],
                'en' => ['Your basket is saved', $count . ' items for ' . $price . ' — waiting whenever you are back.'],
            ],
            'route' => '/cart', 'collapse_key' => 'cart', 'thread_id' => 'cart', 'level' => 'passive', 'relevance' => 0.5,
        ]];
    }

    /** «كيف كانت توصيلة اليوم؟» — once, only if the order is still delivered and unrated. */
    private static function step_rating(int $step, int $uid, string $gid, array $ctx, int $now): array
    {
        $order = wc_get_order((int) ($ctx['order_id'] ?? 0));
        if (!($order instanceof \WC_Order) || $order->get_status() !== 'completed') {
            return ['exit' => 'not_completed'];
        }
        if ((string) $order->get_meta('_zb_rating') !== '') {
            return ['exit' => 'rated'];
        }
        $express = !empty($ctx['express']);
        return ['message' => [
            'copy' => [
                'ar' => [$express ? 'كيف كانت توصيلة اليوم؟' : 'وصلك طلبك — كيف كان؟', 'تقييمك بضغطة يحسّن الطلب القادم.'],
                'en' => [$express ? 'How was today\'s delivery?' : 'Your order arrived — how was it?', 'One tap to rate; it makes the next one better.'],
            ],
            'route' => '/orders/' . $order->get_id() . '?rate=1', 'collapse_key' => 'order-' . $order->get_id(),
            'thread_id' => 'order-' . $order->get_id(), 'relevance' => 0.6,
            'expires_at' => $now + 2 * DAY_IN_SECONDS,
        ]];
    }

    /* ══════════════════════════════════════════════════════════════
       LOOKUPS
       ══════════════════════════════════════════════════════════════ */

    public static function completed_count(int $uid): int
    {
        if ($uid <= 0 || !function_exists('wc_get_orders')) {
            return 0;
        }
        return count(wc_get_orders(['customer_id' => $uid, 'status' => ['completed'], 'limit' => 2, 'return' => 'ids']));
    }

    /** Any order (not cancelled/failed) created after [$since]. */
    public static function ordered_since(int $uid, int $since, bool $completed_only = false): bool
    {
        if ($uid <= 0 || $since <= 0 || !function_exists('wc_get_orders')) {
            return false;
        }
        $ids = wc_get_orders([
            'customer_id'  => $uid,
            'status'       => $completed_only ? ['completed'] : ['pending', 'on-hold', 'processing', 'zb-ready', 'zb-out-for-delivery', 'completed'],
            'date_created' => '>' . $since,
            'limit'        => 1,
            'return'       => 'ids',
        ]);
        return !empty($ids);
    }

    public static function last_order_ts(int $uid): int
    {
        $orders = wc_get_orders(['customer_id' => $uid, 'status' => ['completed'], 'limit' => 1, 'orderby' => 'date', 'order' => 'DESC']);
        $o = $orders[0] ?? null;
        return $o instanceof \WC_Order && $o->get_date_created() ? $o->get_date_created()->getTimestamp() : 0;
    }

    /** Has this product been in any live order since [$since]? */
    public static function bought_since(int $uid, int $pid, int $since): bool
    {
        if ($uid <= 0 || $pid <= 0) {
            return false;
        }
        $orders = wc_get_orders([
            'customer_id'  => $uid,
            'status'       => ['pending', 'on-hold', 'processing', 'zb-ready', 'zb-out-for-delivery', 'completed'],
            'date_created' => '>' . max(0, $since),
            'limit'        => 10,
        ]);
        foreach ((array) $orders as $o) {
            if (!($o instanceof \WC_Order)) {
                continue;
            }
            foreach ($o->get_items() as $item) {
                if ($item instanceof \WC_Order_Item_Product
                    && ((int) $item->get_product_id() === $pid || (int) $item->get_variation_id() === $pid)) {
                    return true;
                }
            }
        }
        return false;
    }

    /** The first line of the last completed order, for copy. */
    public static function last_product_name(int $uid): string
    {
        $orders = wc_get_orders(['customer_id' => $uid, 'status' => ['completed'], 'limit' => 1, 'orderby' => 'date', 'order' => 'DESC']);
        $o = $orders[0] ?? null;
        if (!($o instanceof \WC_Order)) {
            return '';
        }
        foreach ($o->get_items() as $item) {
            if ($item instanceof \WC_Order_Item_Product && (string) $item->get_meta(class_exists('Zooboxi_Loyalty') ? Zooboxi_Loyalty::ORDER_GRANT_META : '_zb_grant') === '') {
                return wp_strip_all_tags($item->get_name());
            }
        }
        return '';
    }

    /** last completed order + the customer's own median gap (or 30 days). */
    public static function expected_next_order(int $uid): ?int
    {
        $orders = wc_get_orders(['customer_id' => $uid, 'status' => ['completed'], 'limit' => 8, 'orderby' => 'date', 'order' => 'DESC']);
        $times = [];
        foreach ((array) $orders as $o) {
            if ($o instanceof \WC_Order && $o->get_date_created()) {
                $times[] = (int) $o->get_date_created()->getTimestamp();
            }
        }
        if (empty($times)) {
            return null;
        }
        rsort($times);
        $gap = 30 * DAY_IN_SECONDS;
        if (count($times) >= 2) {
            $gaps = [];
            for ($i = 0; $i < count($times) - 1; $i++) {
                $gaps[] = $times[$i] - $times[$i + 1];
            }
            sort($gaps);
            $gap = $gaps[intdiv(count($gaps), 2)];
        }
        return $times[0] + $gap;
    }

    private static function sealed_scratch(int $uid): ?int
    {
        if (!class_exists('Zooboxi_Loyalty_Scratch')) {
            return null;
        }
        foreach (Zooboxi_Loyalty_Scratch::recent_for_user($uid, 5) as $card) {
            if ((string) ($card['state'] ?? '') === 'sealed') {
                return (int) $card['id'];
            }
        }
        return null;
    }

    private static function in_express_zone(float $lat, float $lng): bool
    {
        if ($lat == 0.0 && $lng == 0.0 || !class_exists('Zooboxi_Warehouse_Manager')) {
            return false;
        }
        try {
            foreach (Zooboxi_Warehouse_Manager::get_active() as $wh) {
                if (!empty($wh['is_express_enabled']) && Zooboxi_Warehouse_Manager::is_within_express_zone($wh, $lat, $lng)) {
                    return true;
                }
            }
        } catch (\Throwable $e) {
            return false;
        }
        return false;
    }
}
