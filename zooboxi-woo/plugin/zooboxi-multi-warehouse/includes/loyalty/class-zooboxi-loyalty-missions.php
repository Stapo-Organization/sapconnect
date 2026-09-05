<?php
/**
 * Zooboxi_Loyalty_Missions — «مهمات الشهر»: five templates, four seats.
 *
 * WHY LAZY ASSIGNMENT: nobody needs a mission until they look. Cutting a monthly job
 * over the whole customer base would burn hours of CPU to write rows most people never
 * open, so the month's missions are minted on the first read of `/loyalty/summary` or
 * `/loyalty/missions` (or the first completed order of the month). The UNIQUE key on
 * (user, period, template) makes a racing double-read a no-op rather than a duplicate.
 *
 * The templates are ordered by how much the ANSWER is worth to us, not by how easy they
 * are: the profile mission first (it makes every later recommendation better), then the
 * first app order, then frequency, then the two discovery missions.
 *
 * Missions are app-only and skip the holdout group — they are the measured variable.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Missions
{
    /** How many of the eligible templates a customer carries at once. */
    public const SEATS = 4;

    /** Template order = priority order. Rewards here are the shipped defaults. */
    public const TEMPLATES = [
        'profile'          => ['kind' => 'profile',   'paws' => 100, 'target' => 1],
        'first_app_order'  => ['kind' => 'welcome',   'paws' => 150, 'target' => 1, 'reward_key' => 'welcome_gift'],
        'on_time'          => ['kind' => 'regular',   'paws' => 100, 'target' => 1],
        'frequency'        => ['kind' => 'frequency', 'paws' => 300, 'target' => 2],
        'weigh_in'         => ['kind' => 'care',      'paws' => 50,  'target' => 1],
        'try_new_brand'    => ['kind' => 'trial',     'paws' => 150, 'target' => 1],
        'refer_friend'     => ['kind' => 'growth',    'paws' => 100, 'target' => 1],
        'species_category' => ['kind' => 'category',  'paws' => 150, 'target' => 1],
    ];

    /** Minted by the win-back sweep only — never by the monthly assignment. */
    public const WINBACK_TEMPLATE = ['kind' => 'winback', 'paws' => 200, 'target' => 1, 'reward_key' => 'winback_gift'];

    /* ══════════════════════════════════════════════════════════════
       CONFIG
       ══════════════════════════════════════════════════════════════ */

    /** Owner overrides per template: enabled, reward kind/value, frequency target. */
    public static function config(string $template_key): array
    {
        $all      = Zooboxi_Loyalty::opt_json('missions', []);
        $defaults = self::TEMPLATES[$template_key] ?? [];
        $row      = is_array($all[$template_key] ?? null) ? $all[$template_key] : [];

        return [
            'enabled'     => !isset($row['enabled']) || (bool) $row['enabled'],
            'reward_kind' => isset($row['reward_kind']) && $row['reward_kind'] === 'reward' ? 'reward' : 'paws',
            'reward_paws' => isset($row['reward_paws']) ? max(0, (int) $row['reward_paws']) : (int) ($defaults['paws'] ?? 0),
            'reward_id'   => isset($row['reward_id']) ? max(0, (int) $row['reward_id']) : 0,
            'reward_key'  => isset($row['reward_key']) ? (string) $row['reward_key'] : (string) ($defaults['reward_key'] ?? ''),
            // null = "let the template decide"; a number is an explicit owner override.
            'target'      => isset($row['target']) && (int) $row['target'] > 0 ? max(1, (int) $row['target']) : null,
            'default_target' => (int) ($defaults['target'] ?? 1),
        ];
    }

    /** Resolve a template's reward to a concrete (kind, paws, reward_id) triple. */
    private static function resolve_reward(string $template_key): array
    {
        $cfg    = self::config($template_key);
        $reward = null;

        if ($cfg['reward_id'] > 0) {
            $reward = Zooboxi_Loyalty_Rewards::reward($cfg['reward_id']);
        } elseif ($cfg['reward_kind'] === 'reward' || $cfg['reward_key'] !== '') {
            $reward = Zooboxi_Loyalty_Rewards::reward_by_key($cfg['reward_key']);
        }

        // A reward the owner never attached silently degrades to paws — the customer
        // must always be paid something for finishing a mission.
        if ($reward !== null && (int) $reward['is_active'] === 1) {
            return ['kind' => 'reward', 'paws' => 0, 'reward_id' => (int) $reward['id']];
        }
        return ['kind' => 'paws', 'paws' => (int) $cfg['reward_paws'], 'reward_id' => 0];
    }

    /* ══════════════════════════════════════════════════════════════
       ASSIGNMENT
       ══════════════════════════════════════════════════════════════ */

    /**
     * The customer's missions for the current period, minting them on first sight.
     *
     * @return array<int,array> mission rows
     */
    public static function for_user(int $user_id): array
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled() || Zooboxi_Loyalty::opt('missions_enabled') !== 'yes') {
            return [];
        }
        if (Zooboxi_Loyalty_Members::is_holdout($user_id)) {
            return [];
        }

        $period = Zooboxi_Loyalty::period();
        $rows   = self::rows($user_id, $period);

        if (empty($rows)) {
            self::assign($user_id, $period);
            $rows = self::rows($user_id, $period);
        }

        return $rows;
    }

    /** @return array<int,array> */
    public static function rows(int $user_id, string $period): array
    {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::missions()
            . ' WHERE user_id = %d AND period = %s ORDER BY id ASC',
            $user_id,
            $period
        ), ARRAY_A);
        return is_array($rows) ? $rows : [];
    }

    /**
     * Mint this period's missions.
     *
     * Guarded by a short transient lock so two simultaneous app reads do not both walk
     * the (expensive) eligibility queries.
     */
    public static function assign(int $user_id, string $period): int
    {
        $lock = 'zb_loy_assign_' . $user_id . '_' . $period;
        if (get_transient($lock)) {
            return 0;
        }
        set_transient($lock, 1, 60);

        try {
            Zooboxi_Loyalty_Schema::maybe_install();
            self::expire_previous($user_id, $period);

            $history = self::history($user_id);
            $pet     = Zooboxi_Loyalty_Pets::first_name($user_id);
            $written = 0;

            foreach (array_keys(self::TEMPLATES) as $template_key) {
                if ($written >= self::SEATS) {
                    break;
                }
                if (!self::config($template_key)['enabled']) {
                    continue;
                }

                $built = self::build($template_key, $user_id, $history, $pet);
                if ($built === null) {
                    continue; // not eligible this month
                }
                if (self::insert($user_id, $period, $template_key, $built)) {
                    $written++;
                }
            }

            return $written;
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] mission assignment failed: ' . $e->getMessage());
            return 0;
        } finally {
            delete_transient($lock);
        }
    }

    /** Last month's open missions close when the new month opens. */
    private static function expire_previous(int $user_id, string $period): void
    {
        global $wpdb;
        $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::missions()
            . " SET state = 'expired' WHERE user_id = %d AND period <> %s AND state IN ('active','completed')",
            $user_id,
            $period
        ));
    }

    private static function insert(int $user_id, string $period, string $template_key, array $built): bool
    {
        global $wpdb;

        $prev_show     = $wpdb->hide_errors();
        $prev_suppress = $wpdb->suppress_errors(true);

        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::missions(), [
            'user_id'          => $user_id,
            'period'           => $period,
            'template_key'     => $template_key,
            'kind'             => (string) $built['kind'],
            'title_ar'         => (string) $built['title_ar'],
            'title_en'         => (string) $built['title_en'],
            'body_ar'          => (string) $built['body_ar'],
            'body_en'          => (string) $built['body_en'],
            'target'           => max(1, (int) $built['target']),
            'progress'         => 0,
            'params'           => wp_json_encode($built['params'] ?? []),
            'reward_kind'      => (string) $built['reward']['kind'],
            'reward_paws'      => (int) $built['reward']['paws'],
            'reward_reward_id' => $built['reward']['reward_id'] ?: null,
            'state'            => 'active',
            'created_at'       => Zooboxi_Loyalty::now(),
        ]);

        $wpdb->suppress_errors($prev_suppress);
        if ($prev_show) {
            $wpdb->show_errors();
        }

        return (bool) $ok;
    }

    /* ══════════════════════════════════════════════════════════════
       TEMPLATES
       ══════════════════════════════════════════════════════════════ */

    /** Build one template for this customer, or null when they are not eligible. */
    private static function build(string $template_key, int $user_id, array $history, string $pet): ?array
    {
        $reward = self::resolve_reward($template_key);
        $cfg    = self::config($template_key);

        switch ($template_key) {
            case 'profile':
                if (Zooboxi_Loyalty_Pets::profile_is_complete($user_id)) {
                    return null;
                }
                return [
                    'kind'     => 'profile',
                    'title_ar' => 'أكمل ملف عائلتك',
                    'title_en' => 'Complete your family profile',
                    'body_ar'  => sprintf('أضف وزن %s وتاريخ ميلاده لنقترح عليك بدقة.', $pet),
                    'body_en'  => 'Add your pet\'s weight and birth date so our suggestions actually fit.',
                    'target'   => 1,
                    'params'   => [],
                    'reward'   => $reward,
                ];

            case 'on_time':
                // Only when the gauge has something to be on time FOR.
                if (!class_exists('Zooboxi_Loyalty_Supply') || empty(Zooboxi_Loyalty_Supply::items($user_id))) {
                    return null;
                }
                return [
                    'kind'     => 'regular',
                    'title_ar' => 'اطلب في وقتك',
                    'title_en' => 'Order on time',
                    'body_ar'  => sprintf('اطلب أكل %s قبل أن ينفد — داخل نافذة العدّاد — واكسب بصمات إضافية.', $pet),
                    'body_en'  => 'Reorder before the food runs out — inside the gauge window — and earn bonus paws.',
                    'target'   => 1,
                    'params'   => [],
                    'reward'   => $reward,
                ];

            case 'refer_friend':
                if (!class_exists('Zooboxi_Loyalty_Referrals') || !Zooboxi_Loyalty_Referrals::enabled()) {
                    return null;
                }
                return [
                    'kind'     => 'growth',
                    'title_ar' => 'ادعُ صديقاً',
                    'title_en' => 'Invite a friend',
                    'body_ar'  => sprintf('شارك كودك مع صديق — عند اكتمال أول طلب له تكسب %d بصمة، وهذه المهمة فوقها.', Zooboxi_Loyalty_Referrals::reward_paws()),
                    'body_en'  => sprintf('Share your code with a friend — their first delivered order earns you %d paws, and this mission on top.', Zooboxi_Loyalty_Referrals::reward_paws()),
                    'target'   => 1,
                    'params'   => [],
                    'reward'   => $reward,
                ];

            case 'first_app_order':
                if ((int) ($history['app_orders'] ?? 0) > 0) {
                    return null;
                }
                return [
                    'kind'     => 'welcome',
                    'title_ar' => 'أول طلب من التطبيق',
                    'title_en' => 'Your first order from the app',
                    'body_ar'  => 'اطلب مرة واحدة من التطبيق واستلم مكافأة الترحيب.',
                    'body_en'  => 'Place one order from the app and collect your welcome reward.',
                    'target'   => 1,
                    'params'   => [],
                    'reward'   => $reward,
                ];

            case 'frequency':
                // Adaptive by default — ask a light customer for 2 and a regular for 3,
                // so the mission is a stretch rather than a formality either way.
                $target = (float) ($history['monthly_avg'] ?? 0) < 2 ? 2 : 3;
                if ($cfg['target'] !== null) {
                    $target = (int) $cfg['target']; // an explicit owner target wins
                }
                return [
                    'kind'     => 'frequency',
                    'title_ar' => sprintf('%d طلبات هذا الشهر', $target),
                    'title_en' => sprintf('%d orders this month', $target),
                    'body_ar'  => 'اجمع بصمات إضافية عند إكمال طلبات الشهر.',
                    'body_en'  => 'Earn bonus paws when you finish the month\'s orders.',
                    'target'   => $target,
                    'params'   => [],
                    'reward'   => $reward,
                ];

            case 'weigh_in':
                // A fresh weight is a correct feeding plan — only for the species that have one.
                if (!class_exists('Zooboxi_Loyalty_Care') || !Zooboxi_Loyalty_Care::enabled()) {
                    return null;
                }
                $weighable = Zooboxi_Loyalty_Care::weighable_pet($user_id);
                if ($weighable === null || Zooboxi_Loyalty_Care::logged_this_period($user_id)) {
                    return null;
                }
                $who = trim((string) $weighable['name']) !== '' ? (string) $weighable['name'] : $pet;
                return [
                    'kind'     => 'care',
                    'title_ar' => sprintf('سجّل وزن %s', $who),
                    'title_en' => sprintf('Log %s\'s weight', $who),
                    'body_ar'  => 'وزن محدّث يعني كمية أكل أدق وعدّاداً أصدق. إدخال واحد هذا الشهر يكفي.',
                    'body_en'  => 'A fresh weight means a more accurate feeding plan and an honest gauge. One entry this month is enough.',
                    'target'   => 1,
                    'params'   => ['pet_id' => (int) $weighable['id']],
                    'reward'   => $reward,
                ];

            case 'try_new_brand':
                $brands = self::suggest_brands($history);
                if (empty($brands)) {
                    return null;
                }
                return [
                    'kind'     => 'trial',
                    'title_ar' => 'جرّب ماركة جديدة',
                    'title_en' => 'Try a new brand',
                    'body_ar'  => sprintf('اطلب صنفاً من ماركة لم يجرّبها %s من قبل.', $pet),
                    'body_en'  => 'Order something from a brand your pet has not tried yet.',
                    'target'   => 1,
                    'params'   => ['brand_ids' => $brands],
                    'reward'   => $reward,
                ];

            case 'species_category':
                $category = self::species_category($user_id, $history);
                if ($category <= 0) {
                    return null;
                }
                $term  = get_term($category, 'product_cat');
                $label = ($term && !is_wp_error($term)) ? $term->name : '';
                return [
                    'kind'     => 'category',
                    'title_ar' => $label !== '' ? sprintf('جرّب %s', $label) : 'جرّب تصنيفاً جديداً',
                    'title_en' => $label !== '' ? sprintf('Try %s', $label) : 'Try a new category',
                    'body_ar'  => sprintf('صنف واحد من هذا القسم يكفي — نظن أنه يناسب %s.', $pet),
                    'body_en'  => 'One item from this section is enough — we think it suits your pet.',
                    'target'   => 1,
                    'params'   => ['category_id' => $category],
                    'reward'   => $reward,
                ];
        }

        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       HISTORY (one bounded pass, cached)
       ══════════════════════════════════════════════════════════════ */

    /**
     * What we know about this customer's last 12 months: brands and categories bought,
     * how many orders came from the app, and their monthly order rhythm.
     *
     * Cached for six hours — the assignment reads it once a month, but the mission
     * screen and the progress hook both benefit from the same answer.
     */
    public static function history(int $user_id): array
    {
        $key    = 'zb_loy_hist_' . $user_id;
        $cached = get_transient($key);
        if (is_array($cached) && ($cached['_v'] ?? 0) === 1) {
            return $cached;
        }

        $out = [
            '_v'           => 1,
            'brands'       => [],
            'categories'   => [],
            'app_orders'   => 0,
            'orders'       => 0,
            'monthly_avg'  => 0.0,
        ];

        if (!function_exists('wc_get_orders')) {
            return $out;
        }

        try {
            $orders = wc_get_orders([
                'customer_id' => $user_id,
                'status'      => ['completed', 'processing', 'zb-ready'],
                'date_created' => '>' . (time() - 365 * DAY_IN_SECONDS),
                'limit'       => 60,
                'orderby'     => 'date',
                'order'       => 'DESC',
            ]);
        } catch (\Throwable $e) {
            return $out;
        }

        $months = [];
        foreach ((array) $orders as $order) {
            if (!($order instanceof \WC_Order)) {
                continue;
            }
            $out['orders']++;
            if (Zooboxi_Loyalty_Scratch::is_app_order($order)) {
                $out['app_orders']++;
            }
            $created = $order->get_date_created();
            if ($created) {
                $months[$created->date('Y-m')] = true;
            }

            foreach ($order->get_items() as $item) {
                if (!($item instanceof \WC_Order_Item_Product)) {
                    continue;
                }
                $pid = (int) $item->get_product_id();
                if ($pid <= 0) {
                    continue;
                }
                foreach ((array) wp_get_post_terms($pid, 'product_brand', ['fields' => 'ids']) as $tid) {
                    $out['brands'][(int) $tid] = true;
                }
                foreach ((array) wp_get_post_terms($pid, 'product_cat', ['fields' => 'ids']) as $tid) {
                    $out['categories'][(int) $tid] = true;
                }
            }
        }

        $out['brands']      = array_keys($out['brands']);
        $out['categories']  = array_keys($out['categories']);
        // Rhythm over the six months we can actually see, not over a year of silence.
        $out['monthly_avg'] = $out['orders'] > 0 ? round($out['orders'] / max(1, min(12, count($months) ?: 1)), 2) : 0.0;

        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }

    public static function flush_history(int $user_id): void
    {
        delete_transient('zb_loy_hist_' . $user_id);
    }

    /**
     * Up to three brands worth trying: the biggest brands this customer has NOT bought
     * from in a year.
     *
     * (Phase 2 replaces this with the association graph from `/api/woo/recommendations`;
     * catalogue weight is the honest cold-start proxy and costs one term query.)
     */
    private static function suggest_brands(array $history): array
    {
        if (!taxonomy_exists('product_brand')) {
            return [];
        }
        $terms = get_terms([
            'taxonomy'   => 'product_brand',
            'hide_empty' => true,
            'orderby'    => 'count',
            'order'      => 'DESC',
            'number'     => 24,
            'fields'     => 'ids',
            'exclude'    => array_map('intval', $history['brands'] ?? []),
        ]);
        if (is_wp_error($terms) || !is_array($terms)) {
            return [];
        }
        return array_slice(array_map('intval', $terms), 0, 3);
    }

    /** The category configured for one of this customer's species, if unbought. */
    private static function species_category(int $user_id, array $history): int
    {
        $map = Zooboxi_Loyalty::opt_json('species_categories', []);
        if (empty($map)) {
            return 0;
        }
        $bought = array_map('intval', $history['categories'] ?? []);

        foreach (Zooboxi_Loyalty_Pets::species_of($user_id) as $species) {
            $slug = (string) ($map[$species] ?? '');
            if ($slug === '') {
                continue;
            }
            $term = is_numeric($slug)
                ? get_term((int) $slug, 'product_cat')
                : get_term_by('slug', $slug, 'product_cat');
            if (!$term || is_wp_error($term)) {
                continue;
            }
            if (!in_array((int) $term->term_id, $bought, true)) {
                return (int) $term->term_id;
            }
        }
        return 0;
    }

    /* ══════════════════════════════════════════════════════════════
       PROGRESS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Advance this month's missions against a delivered order.
     *
     * Runs inside the order-completed hook, so it must be cheap and total: a template
     * that cannot be evaluated simply does not advance.
     */
    public static function progress_from_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return 0;
        }

        $period = Zooboxi_Loyalty::period();
        $rows   = self::rows($user_id, $period);
        if (empty($rows)) {
            self::assign($user_id, $period);
            $rows = self::rows($user_id, $period);
        }
        if (empty($rows)) {
            return 0;
        }

        // The order's own brand/category/app facts, computed once for all missions.
        $brands     = [];
        $categories = [];
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                continue; // a gift cannot complete a mission
            }
            $pid = (int) $item->get_product_id();
            if ($pid <= 0) {
                continue;
            }
            foreach ((array) wp_get_post_terms($pid, 'product_brand', ['fields' => 'ids']) as $tid) {
                $brands[(int) $tid] = true;
            }
            foreach ((array) wp_get_post_terms($pid, 'product_cat', ['fields' => 'ids']) as $tid) {
                $categories[(int) $tid] = true;
            }
        }

        $is_app  = Zooboxi_Loyalty_Scratch::is_app_order($order);
        $history = self::history($user_id);
        $touched = 0;

        foreach ($rows as $row) {
            if ((string) $row['state'] !== 'active') {
                continue;
            }
            $params = json_decode((string) $row['params'], true);
            $params = is_array($params) ? $params : [];
            $step   = 0;

            switch ((string) $row['kind']) {
                case 'frequency':
                    $step = 1;
                    break;

                case 'welcome':
                    $step = $is_app ? 1 : 0;
                    break;

                case 'regular':
                    // Stamped at checkout by the supply gauge — the window they ordered IN.
                    $step = class_exists('Zooboxi_Loyalty_Supply') && !empty(Zooboxi_Loyalty_Supply::stamped_ids($order)) ? 1 : 0;
                    break;

                case 'winback':
                    $step = 1; // any delivered order brings them back
                    break;

                case 'trial':
                    // Suggested brands first; otherwise ANY brand new to this customer.
                    $wanted = array_map('intval', $params['brand_ids'] ?? []);
                    $known  = array_map('intval', $history['brands'] ?? []);
                    foreach (array_keys($brands) as $bid) {
                        if ((!empty($wanted) && in_array($bid, $wanted, true))
                            || (empty($wanted) && !in_array($bid, $known, true))) {
                            $step = 1;
                            break;
                        }
                    }
                    break;

                case 'category':
                    $wanted = (int) ($params['category_id'] ?? 0);
                    if ($wanted > 0 && isset($categories[$wanted])) {
                        $step = 1;
                    }
                    break;
            }

            if ($step > 0 && self::advance((int) $row['id'], $user_id, $step)) {
                $touched++;
            }
        }

        // The order changed what we know — the next assignment must see it.
        self::flush_history($user_id);

        return $touched;
    }

    /** Advance every active mission of one kind (the referral payout uses it for `growth`). */
    public static function progress_kind(int $user_id, string $kind, int $step = 1): void
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        foreach (self::rows($user_id, Zooboxi_Loyalty::period()) as $row) {
            if ((string) $row['kind'] === $kind && (string) $row['state'] === 'active') {
                self::advance((int) $row['id'], $user_id, $step);
            }
        }
    }

    /**
     * «نشتاق لـ{pet}» — the win-back mission, minted by the daily sweep for one member.
     * Lives in the current period next to the monthly four; UNIQUE on the template key
     * means one per month at most.
     */
    public static function mint_winback(int $user_id, string $pet): bool
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled() || Zooboxi_Loyalty::opt('missions_enabled') !== 'yes') {
            return false;
        }
        if (Zooboxi_Loyalty_Members::is_holdout($user_id)) {
            return false;
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        $tpl    = self::WINBACK_TEMPLATE;
        $reward = ['kind' => 'paws', 'paws' => max(0, Zooboxi_Loyalty::opt_int('winback_paws', (int) $tpl['paws'])), 'reward_id' => 0];
        $gift   = Zooboxi_Loyalty_Rewards::reward_by_key((string) $tpl['reward_key']);
        if ($gift !== null && (int) $gift['is_active'] === 1 && Zooboxi_Loyalty_Rewards::reward_product($gift) !== null) {
            $reward = ['kind' => 'reward', 'paws' => 0, 'reward_id' => (int) $gift['id']];
        }

        return self::insert($user_id, Zooboxi_Loyalty::period(), 'winback', [
            'kind'     => 'winback',
            'title_ar' => sprintf('نشتاق لـ%s', $pet),
            'title_en' => sprintf('We miss %s', $pet),
            'body_ar'  => 'مرّ وقت من آخر طلب — طلبك القادم يكمل هذه المهمة وهديتها أكبر من المعتاد.',
            'body_en'  => 'It has been a while — your next order completes this mission, and its gift is bigger than usual.',
            'target'   => 1,
            'params'   => [],
            'reward'   => $reward,
        ]);
    }

    /** The profile mission completes the moment a pet becomes complete. */
    public static function progress_profile(int $user_id): void
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty_Pets::profile_is_complete($user_id)) {
            return;
        }
        foreach (self::rows($user_id, Zooboxi_Loyalty::period()) as $row) {
            if ((string) $row['kind'] === 'profile' && (string) $row['state'] === 'active') {
                self::advance((int) $row['id'], $user_id, (int) $row['target']);
            }
        }
    }

    /** Add progress and, when the target is reached, complete + pay in one step. */
    public static function advance(int $mission_id, int $user_id, int $step): bool
    {
        global $wpdb;

        $updated = (int) $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::missions()
            . " SET progress = LEAST(target, progress + %d) WHERE id = %d AND user_id = %d AND state = 'active'",
            max(1, $step),
            $mission_id,
            $user_id
        ));
        if ($updated <= 0) {
            return false;
        }

        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::missions() . ' WHERE id = %d LIMIT 1',
            $mission_id
        ), ARRAY_A);

        if (is_array($row) && (int) $row['progress'] >= (int) $row['target']) {
            self::complete($row);
        }
        return true;
    }

    /**
     * Mark done and pay immediately.
     *
     * The state moves `active` → `completed` → `rewarded` in one call; the conditional
     * UPDATE on `state = 'completed'` is the lock that stops a double payout.
     */
    public static function complete(array $row): bool
    {
        global $wpdb;

        $claimed = (int) $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::missions()
            . " SET state = 'completed', completed_at = %s WHERE id = %d AND state = 'active'",
            Zooboxi_Loyalty::now(),
            (int) $row['id']
        ));
        if ($claimed <= 0) {
            return false; // someone else already completed it
        }

        $user_id = (int) $row['user_id'];

        if ((string) $row['reward_kind'] === 'reward' && !empty($row['reward_reward_id'])) {
            Zooboxi_Loyalty_Rewards::grant($user_id, (int) $row['reward_reward_id'], 'mission', (int) $row['id'], null);
        } elseif ((int) $row['reward_paws'] > 0) {
            Zooboxi_Loyalty_Ledger::add(
                $user_id,
                (int) $row['reward_paws'],
                'mission',
                'mission',
                (int) $row['id'],
                Zooboxi_Loyalty::pick((string) $row['title_ar'], (string) $row['title_en'])
            );
        }

        $wpdb->update(
            Zooboxi_Loyalty_Schema::missions(),
            ['state' => 'rewarded'],
            ['id' => (int) $row['id']],
            ['%s'],
            ['%d']
        );

        return true;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function dto(array $row, int $user_id = 0, bool $with_products = true): array
    {
        $params = json_decode((string) $row['params'], true);
        $params = is_array($params) ? $params : [];

        $reward = ['kind' => 'paws', 'paws' => (int) $row['reward_paws']];
        if ((string) $row['reward_kind'] === 'reward' && !empty($row['reward_reward_id'])) {
            $catalog = Zooboxi_Loyalty_Rewards::reward((int) $row['reward_reward_id']);
            $reward  = [
                'kind'   => 'reward',
                'reward' => $catalog ? Zooboxi_Loyalty_Rewards::reward_dto($catalog, $user_id) : null,
            ];
        }

        return [
            'id'                 => (int) $row['id'],
            'key'                => (string) $row['template_key'],
            'kind'               => (string) $row['kind'],
            'title'              => Zooboxi_Loyalty::pick((string) $row['title_ar'], (string) $row['title_en']),
            'body'               => Zooboxi_Loyalty::pick((string) $row['body_ar'], (string) $row['body_en']),
            'target'             => (int) $row['target'],
            'progress'           => (int) $row['progress'],
            'state'              => (string) $row['state'],
            'reward'             => $reward,
            'suggested_products' => $with_products ? self::suggested_products($row, $params) : [],
            'completed_at'       => Zooboxi_Loyalty::iso($row['completed_at'] ?? null),
        ];
    }

    /** @return array<int,array> */
    public static function dtos(array $rows, int $user_id = 0, bool $with_products = true): array
    {
        $out = [];
        foreach ($rows as $row) {
            $out[] = self::dto($row, $user_id, $with_products);
        }
        return $out;
    }

    /** Up to six cards that would complete a discovery mission. */
    private static function suggested_products(array $row, array $params): array
    {
        $kind = (string) $row['kind'];
        if (!in_array($kind, ['trial', 'category'], true) || !class_exists('Zooboxi_Product_DTO')) {
            return [];
        }

        $args = [
            'status'  => 'publish',
            'limit'   => 6,
            'return'  => 'ids',
            'orderby' => 'popularity',
        ];

        if ($kind === 'trial') {
            $brands = array_map('intval', $params['brand_ids'] ?? []);
            if (empty($brands)) {
                return [];
            }
            $args['product_brand'] = self::term_slugs($brands, 'product_brand');
        } else {
            $category = (int) ($params['category_id'] ?? 0);
            if ($category <= 0) {
                return [];
            }
            $args['category'] = self::term_slugs([$category], 'product_cat');
        }
        if (empty($args['product_brand']) && empty($args['category'])) {
            return [];
        }

        try {
            $ids = wc_get_products($args);
        } catch (\Throwable $e) {
            return [];
        }

        return Zooboxi_Product_DTO::cards(is_array($ids) ? $ids : []);
    }

    /** wc_get_products() takes slugs, not ids, for taxonomy filters. */
    private static function term_slugs(array $ids, string $taxonomy): array
    {
        $out = [];
        foreach ($ids as $id) {
            $term = get_term((int) $id, $taxonomy);
            if ($term && !is_wp_error($term)) {
                $out[] = $term->slug;
            }
        }
        return $out;
    }
}
