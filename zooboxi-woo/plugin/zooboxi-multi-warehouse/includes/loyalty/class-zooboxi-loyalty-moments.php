<?php
/**
 * Zooboxi_Loyalty_Moments — the calendar side of the program.
 *
 *   · the pet's birthday (a yearly gift, in its name)
 *   · win-back («نشتاق لمشمش») when a customer goes quiet past their own rhythm
 *   · the soft tier drop ("one order keeps your Gold")
 *   · `nudges[]` — everything above plus the supply gauge and subscriptions, as ONE
 *     dated list the app can show and, on iOS, schedule as local notifications.
 *
 * The daily jobs are bounded (LIMIT) and idempotent (grants/ledger/notices keys), so a
 * cron that runs twice, or once a week after an outage, does the right thing.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Moments
{
    /* ══════════════════════════════════════════════════════════════
       BIRTHDAY
       ══════════════════════════════════════════════════════════════ */

    public static function birthday_enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('birthday_enabled', 'yes') === 'yes';
    }

    /** Has this pet been given its gift in the last 300 days? */
    private static function birthday_given(int $user_id, int $pet_id): bool
    {
        global $wpdb;
        $since = gmdate('Y-m-d H:i:s', time() - 300 * DAY_IN_SECONDS);
        $grant = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::grants()
            . " WHERE user_id = %d AND source = 'birthday' AND source_ref = %d AND created_at >= %s",
            $user_id,
            $pet_id,
            $since
        ));
        if ($grant > 0) {
            return true;
        }
        $paws = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . " WHERE user_id = %d AND reason = 'birthday' AND ref_type = 'pet' AND ref_id = %d AND created_at >= %s",
            $user_id,
            $pet_id,
            $since
        ));
        return $paws > 0;
    }

    /** The daily sweep: every pet with a birthday inside the next week. */
    public static function birthday_daily(): int
    {
        if (!self::birthday_enabled()) {
            return 0;
        }
        global $wpdb;
        // MM-DD of today..today+7 (wrapping the year is handled by listing both).
        $days = [];
        for ($i = 0; $i <= 7; $i++) {
            $days[] = gmdate('m-d', time() + $i * DAY_IN_SECONDS);
        }
        $in   = implode(',', array_fill(0, count($days), '%s'));
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::pets()
            . " WHERE deleted_at IS NULL AND birth_date IS NOT NULL AND DATE_FORMAT(birth_date, '%%m-%%d') IN ({$in}) LIMIT 300",
            $days
        ), ARRAY_A);

        $min_tier = (string) Zooboxi_Loyalty::opt('birthday_min_tier', 'friend');
        $given    = 0;
        foreach ((array) $rows as $pet) {
            $user_id = (int) $pet['user_id'];
            $pet_id  = (int) $pet['id'];
            if ($user_id <= 0 || self::birthday_given($user_id, $pet_id)) {
                continue;
            }
            if ($min_tier !== '' && $min_tier !== 'new'
                && !Zooboxi_Loyalty_Tiers::at_least(Zooboxi_Loyalty_Members::tier_key($user_id), $min_tier)) {
                continue;
            }
            if (self::give_birthday($user_id, $pet)) {
                $given++;
            }
        }
        return $given;
    }

    private static function give_birthday(int $user_id, array $pet): bool
    {
        Zooboxi_Loyalty_Members::ensure($user_id);
        $pet_id = (int) $pet['id'];
        $name   = (string) $pet['name'];

        $reward = Zooboxi_Loyalty_Rewards::reward_by_key('birthday_gift');
        $gift   = false;
        if ($reward !== null && (int) $reward['is_active'] === 1 && Zooboxi_Loyalty_Rewards::reward_product($reward) !== null) {
            $gift = Zooboxi_Loyalty_Rewards::grant($user_id, (int) $reward['id'], 'birthday', $pet_id, null) > 0;
        } else {
            $paws = max(0, Zooboxi_Loyalty::opt_int('birthday_paws', 100));
            if ($paws <= 0) {
                return false;
            }
            $gift = Zooboxi_Loyalty_Ledger::add(
                $user_id,
                $paws,
                'birthday',
                'pet',
                $pet_id,
                sprintf(Zooboxi_Loyalty::pick('عيد ميلاد %s 🎂', '%s\'s birthday 🎂'), $name)
            ) > 0;
        }
        if (!$gift) {
            return false;
        }

        if (class_exists('Zooboxi_Loyalty_Mail')) {
            Zooboxi_Loyalty_Mail::send($user_id, 'birthday', 'pet:' . $pet_id . ':' . gmdate('Y'), [
                'subject_ar' => sprintf('عيد ميلاد %s قرّب 🎂', $name),
                'subject_en' => sprintf('%s\'s birthday is coming up 🎂', $name),
                'lines_ar'   => [
                    sprintf('هذا الأسبوع عيد ميلاد %s — وضعنا هدية باسمه في محفظتك.', $name),
                    'أضفها لطلبك القادم من التطبيق قبل انتهاء صلاحيتها.',
                ],
                'lines_en'   => [
                    sprintf('It is %s\'s birthday week — a gift in their name is waiting in your wallet.', $name),
                    'Add it to your next order from the app before it expires.',
                ],
                'cta_ar'     => 'افتح الهدية',
                'cta_en'     => 'Open the gift',
                'cta_url'    => home_url('/my-account/'),
            ]);
        }
        return true;
    }

    /** The summary's `moments.birthday`: the nearest birthday inside ±14 days, with what it holds. */
    public static function birthday_block(int $user_id): ?array
    {
        $best = null;
        foreach (Zooboxi_Loyalty_Pets::all($user_id) as $pet) {
            $birth = (string) ($pet['birth_date'] ?? '');
            if ($birth === '' || $birth === '0000-00-00') {
                continue;
            }
            $days = Zooboxi_Loyalty_Pets::birthday_in_days($birth);
            if ($days === null) {
                continue;
            }
            // Just passed (up to 14 days ago) still counts as "this year's".
            $signed = $days > 351 ? $days - 365 : $days;
            if ($signed > 7 || $signed < -14) {
                continue;
            }
            if ($best === null || abs($signed) < abs($best['days'])) {
                $best = ['pet' => $pet, 'days' => $signed];
            }
        }
        if ($best === null) {
            return null;
        }

        $pet_id = (int) $best['pet']['id'];
        global $wpdb;
        $grant = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::grants()
            . " WHERE user_id = %d AND source = 'birthday' AND source_ref = %d AND state IN ('active','claimed') ORDER BY id DESC LIMIT 1",
            $user_id,
            $pet_id
        ), ARRAY_A);
        $paws = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COALESCE(SUM(delta),0) FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . " WHERE user_id = %d AND reason = 'birthday' AND ref_type = 'pet' AND ref_id = %d AND created_at >= %s",
            $user_id,
            $pet_id,
            gmdate('Y-m-d H:i:s', time() - 30 * DAY_IN_SECONDS)
        ));

        return [
            'pet'      => Zooboxi_Loyalty_Pets::dto($best['pet']),
            'days'     => (int) $best['days'],
            'grant'    => is_array($grant) ? Zooboxi_Loyalty_Rewards::grant_dto($grant, $user_id) : null,
            'grant_id' => is_array($grant) ? (int) $grant['id'] : null,
            'paws'     => $paws > 0 ? $paws : null,
            'eligible' => self::birthday_enabled(),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       WIN-BACK
       ══════════════════════════════════════════════════════════════ */

    public static function winback_enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('winback_enabled', 'yes') === 'yes'
            && Zooboxi_Loyalty::opt('missions_enabled') === 'yes';
    }

    /**
     * Members whose last earn is older than `winback_days`, not checked in 90 days, not
     * in the control group: does today sit 45 days past their own expected next order?
     */
    public static function winback_daily(): int
    {
        if (!self::winback_enabled()) {
            return 0;
        }
        $days = max(7, Zooboxi_Loyalty::opt_int('winback_days', 45));
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT user_id, last_earn_at FROM ' . Zooboxi_Loyalty_Schema::members()
            . ' WHERE holdout = 0 AND last_earn_at IS NOT NULL AND last_earn_at <= %s'
            . ' AND (winback_at IS NULL OR winback_at <= %s) ORDER BY last_earn_at ASC LIMIT 200',
            gmdate('Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS),
            gmdate('Y-m-d H:i:s', time() - 90 * DAY_IN_SECONDS)
        ), ARRAY_A);

        $minted = 0;
        foreach ((array) $rows as $row) {
            $user_id = (int) $row['user_id'];
            // Stamp first: whatever the verdict, do not look at this member again for 90 days.
            $wpdb->update(Zooboxi_Loyalty_Schema::members(), ['winback_at' => Zooboxi_Loyalty::now()], ['user_id' => $user_id], ['%s'], ['%d']);
            Zooboxi_Loyalty_Members::forget($user_id);

            $expected = self::expected_next_order($user_id);
            if ($expected === null || time() < $expected + $days * DAY_IN_SECONDS) {
                continue;
            }
            if (self::mint_winback($user_id)) {
                $minted++;
            }
        }
        return $minted;
    }

    /** last completed order + the customer's own median gap (or 30 days). */
    private static function expected_next_order(int $user_id): ?int
    {
        if (!function_exists('wc_get_orders')) {
            return null;
        }
        $orders = wc_get_orders([
            'customer_id' => $user_id,
            'status'      => ['completed'],
            'limit'       => 8,
            'orderby'     => 'date',
            'order'       => 'DESC',
        ]);
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

    private static function mint_winback(int $user_id): bool
    {
        if (!class_exists('Zooboxi_Loyalty_Missions')) {
            return false;
        }
        $pet = Zooboxi_Loyalty_Pets::first_name($user_id);
        $ok  = Zooboxi_Loyalty_Missions::mint_winback($user_id, $pet);
        if ($ok && class_exists('Zooboxi_Loyalty_Mail')) {
            Zooboxi_Loyalty_Mail::send($user_id, 'winback', 'wb:' . gmdate('Y-m'), [
                'subject_ar' => sprintf('نشتاق لـ%s 🐾', $pet),
                'subject_en' => sprintf('We miss %s 🐾', $pet),
                'lines_ar'   => [
                    sprintf('مرّ وقت من آخر طلب لـ%s. وضعنا لك مهمة بهدية أقوى من المعتاد — تكتمل بطلبك القادم.', $pet),
                    'افتح التطبيق: عائلة زوبوكسي ← مهمات الشهر.',
                ],
                'lines_en'   => [
                    sprintf('It has been a while since %s\'s last order. There is a mission waiting with a bigger gift than usual — it completes with your next order.', $pet),
                    'Open the app: Zooboxi Family → monthly missions.',
                ],
                'cta_ar'     => 'اطلب الآن',
                'cta_en'     => 'Order now',
                'cta_url'    => home_url('/'),
            ]);
        }
        return $ok;
    }

    /* ══════════════════════════════════════════════════════════════
       TIER AT RISK
       ══════════════════════════════════════════════════════════════ */

    /**
     * Will an order leave the 365-day window within 30 days and pull the tier down?
     * Cached six hours per member; busted with the tier cache.
     */
    public static function tier_risk(int $user_id): ?array
    {
        if ($user_id <= 0 || !function_exists('wc_get_orders')) {
            return null;
        }
        $key    = 'zb_tier_risk_' . $user_id;
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached['risk'] ?? null;
        }

        $risk = null;
        try {
            $state  = Zooboxi_Loyalty_Members::tier_state($user_id);
            $key_now = (string) $state['key'];
            $def     = Zooboxi_Loyalty_Tiers::definition($key_now);
            $min     = (int) ($def['min'] ?? 0);
            $count   = (int) $state['orders_12m'];

            if ($min > 0 && $count >= $min) {
                $orders = wc_get_orders([
                    'customer_id'    => $user_id,
                    'status'         => ['completed'],
                    'date_completed' => '>' . (time() - 365 * DAY_IN_SECONDS),
                    'limit'          => 200,
                    'orderby'        => 'date_completed',
                    'order'          => 'ASC',
                ]);
                $horizon  = time() - 335 * DAY_IN_SECONDS; // leaves the window within 30 days
                $dropping = 0;
                $first    = 0;
                foreach ((array) $orders as $o) {
                    if (!($o instanceof \WC_Order)) {
                        continue;
                    }
                    $done = $o->get_date_completed() ?: $o->get_date_created();
                    $ts   = $done ? (int) $done->getTimestamp() : 0;
                    if ($ts > 0 && $ts <= $horizon) {
                        $dropping++;
                        if ($first === 0) {
                            $first = $ts;
                        }
                    }
                }
                if ($dropping > 0 && $count - $dropping < $min) {
                    $risk = [
                        'in_days'         => max(0, (int) floor(($first + 365 * DAY_IN_SECONDS - time()) / DAY_IN_SECONDS)),
                        'orders_dropping' => $dropping,
                        'would_drop_to'   => Zooboxi_Loyalty_Tiers::key_for_orders($count - $dropping),
                        'would_drop_to_name' => Zooboxi_Loyalty_Tiers::name(Zooboxi_Loyalty_Tiers::key_for_orders($count - $dropping)),
                    ];
                }
            }
        } catch (\Throwable $e) {
            $risk = null;
        }

        set_transient($key, ['risk' => $risk], 6 * HOUR_IN_SECONDS);
        return $risk;
    }

    public static function flush_tier_risk(int $user_id): void
    {
        delete_transient('zb_tier_risk_' . $user_id);
    }

    /* ══════════════════════════════════════════════════════════════
       NUDGES — the app's dated list
       ══════════════════════════════════════════════════════════════ */

    /**
     * Everything worth telling this customer, as dated items. Past items are shown
     * now; future ones become local notifications on the phone.
     *
     * @return array<int,array>
     */
    public static function nudges(int $user_id, array $supply_rows, array $subscriptions, ?array $birthday, ?array $tier_risk, array $missions): array
    {
        $out  = [];
        $now  = time();
        $pets = [];
        foreach (Zooboxi_Loyalty_Pets::all($user_id) as $p) {
            $pets[(int) $p['id']] = (string) $p['name'];
        }
        $someone = Zooboxi_Loyalty::pick('حيوانك', 'your pet');

        // Birthday — a week before.
        if ($birthday !== null) {
            $name = (string) ($birthday['pet']['name'] ?? $someone);
            $out[] = [
                'kind'   => 'birthday',
                'title'  => sprintf(Zooboxi_Loyalty::pick('عيد ميلاد %s 🎂', '%s\'s birthday 🎂'), $name),
                'body'   => !empty($birthday['grant_id'])
                    ? Zooboxi_Loyalty::pick('هدية باسمه في محفظتك — أضفها لطلبك القادم.', 'A gift in their name is in your wallet — add it to your next order.')
                    : Zooboxi_Loyalty::pick('هذا الأسبوع عيد ميلاده — ما رأيك بهدية صغيرة؟', 'It is their birthday week — how about a small treat?'),
                'at'     => gmdate('Y-m-d\TH:i:s\Z', $now),
                'route'  => '/family',
                'pet_id' => (int) ($birthday['pet']['id'] ?? 0),
            ];
        }

        // Supply: 5 days before, 2 days before, and when it ran out.
        foreach (array_slice($supply_rows, 0, 6) as $row) {
            $state = Zooboxi_Loyalty_Supply::state_of($row);
            $name  = $pets[(int) $row['pet_id']] ?? $someone;
            $title = (string) get_the_title((int) $row['product_id']);
            $runs  = (int) $row['runs_out_ts'];
            $pid   = (int) $row['product_id'];

            if ($state['status'] === 'ok') {
                foreach ([5, 2] as $ahead) {
                    $at = $runs - $ahead * DAY_IN_SECONDS;
                    if ($at > $now) {
                        $out[] = [
                            'kind'       => 'supply',
                            'title'      => sprintf(Zooboxi_Loyalty::pick('أكل %s يكفي %d أيام', '%s\'s food lasts %d more days'), $name, $ahead),
                            'body'       => sprintf(Zooboxi_Loyalty::pick('%s — اطلب الآن في وقته واكسب بصمات إضافية.', '%s — order now, on time, and earn bonus paws.'), $title),
                            'at'         => gmdate('Y-m-d\TH:i:s\Z', $at),
                            'route'      => '/family/supply',
                            'product_id' => $pid,
                            'pet_id'     => (int) $row['pet_id'],
                        ];
                    }
                }
            } else {
                $out[] = [
                    'kind'       => 'supply',
                    'title'      => $state['days_left'] > 0
                        ? sprintf(Zooboxi_Loyalty::pick('أكل %s يكفي %d أيام', '%s\'s food lasts %d more days'), $name, $state['days_left'])
                        : sprintf(Zooboxi_Loyalty::pick('حان وقت إعادة طلب أكل %s', 'Time to reorder %s\'s food'), $name),
                    'body'       => sprintf(Zooboxi_Loyalty::pick('%s — «اطلب الآن» يبني السلة بنفس الكمية.', '%s — "Order now" rebuilds the basket with the same quantity.'), $title),
                    'at'         => gmdate('Y-m-d\TH:i:s\Z', min($now, $runs)),
                    'route'      => '/family/supply',
                    'product_id' => $pid,
                    'pet_id'     => (int) $row['pet_id'],
                ];
            }
        }

        // Subscriptions: 3 days before each delivery.
        $ahead = max(0, Zooboxi_Loyalty::opt_int('sub_reminder_days', 3));
        foreach ($subscriptions as $sub) {
            if ((string) $sub['state'] !== 'active' || empty($sub['next_at'])) {
                continue;
            }
            $next  = (int) strtotime((string) $sub['next_at'] . ' 09:00:00 UTC');
            $at    = $next - $ahead * DAY_IN_SECONDS;
            $name  = $pets[(int) ($sub['pet_id'] ?? 0)] ?? $someone;
            $title = (string) get_the_title((int) $sub['product_id']);
            $out[] = [
                'kind'            => 'subscription',
                'title'           => sprintf(Zooboxi_Loyalty::pick('توصيلة %s بعد %d أيام', '%s\'s delivery in %d days'), $name, $ahead),
                'body'            => sprintf(Zooboxi_Loyalty::pick('%s × %d — اطلب بضغطة، التوصيل مجاني.', '%s × %d — one tap, free delivery.'), $title, (int) $sub['qty']),
                'at'              => gmdate('Y-m-d\TH:i:s\Z', min(max($at, $now - DAY_IN_SECONDS), $next)),
                'route'           => '/family/subscriptions',
                'subscription_id' => (int) $sub['id'],
                'product_id'      => (int) $sub['product_id'],
            ];
        }

        // Tier at risk: now, once.
        if ($tier_risk !== null) {
            $out[] = [
                'kind'  => 'tier_risk',
                'title' => Zooboxi_Loyalty::pick('طلب واحد يحفظ مستواك', 'One order keeps your level'),
                'body'  => sprintf(
                    Zooboxi_Loyalty::pick('خلال %d يوماً يهبط مستواك إلى %s ما لم تطلب.', 'In %d days your level drops to %s unless you order.'),
                    (int) $tier_risk['in_days'],
                    (string) ($tier_risk['would_drop_to_name'] ?? $tier_risk['would_drop_to'])
                ),
                'at'    => gmdate('Y-m-d\TH:i:s\Z', $now),
                'route' => '/family',
            ];
        }

        // Win-back mission: now.
        foreach ($missions as $m) {
            if ((string) $m['kind'] === 'winback' && (string) $m['state'] === 'active') {
                $out[] = [
                    'kind'  => 'winback',
                    'title' => (string) Zooboxi_Loyalty::pick((string) $m['title_ar'], (string) $m['title_en']),
                    'body'  => (string) Zooboxi_Loyalty::pick((string) $m['body_ar'], (string) $m['body_en']),
                    'at'    => gmdate('Y-m-d\TH:i:s\Z', $now),
                    'route' => '/family',
                ];
                break;
            }
        }

        usort($out, static fn ($a, $b) => strcmp($a['at'], $b['at']));
        return array_slice($out, 0, 12);
    }

    /* ══════════════════════════════════════════════════════════════
       DAILY ENTRY
       ══════════════════════════════════════════════════════════════ */

    /** Everything Phase 2 does once a day. Each step is isolated; one failing never stops the next. */
    public static function run_daily(): array
    {
        $out = ['sub_reminders' => 0, 'referrals_paid' => 0, 'birthdays' => 0, 'winbacks' => 0];
        foreach ([
            'sub_reminders'  => static fn () => class_exists('Zooboxi_Loyalty_Subscriptions') ? Zooboxi_Loyalty_Subscriptions::remind_due() : 0,
            'referrals_paid' => static fn () => class_exists('Zooboxi_Loyalty_Referrals') ? Zooboxi_Loyalty_Referrals::reward_due() : 0,
            'birthdays'      => static fn () => self::birthday_daily(),
            'winbacks'       => static fn () => self::winback_daily(),
        ] as $key => $job) {
            try {
                $out[$key] = (int) $job();
            } catch (\Throwable $e) {
                error_log('[Zooboxi Loyalty] daily ' . $key . ' failed: ' . $e->getMessage());
            }
        }
        update_option('zooboxi_loyalty_habit_ran_at', Zooboxi_Loyalty::now(), false);
        return $out;
    }
}
