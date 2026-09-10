<?php
/**
 * Family moments and the weekly bundle digest.
 *
 * The `family` topic finally has senders: a gift granted, a birthday, a tier
 * about to slip, a mission one step from done. Each is a fact the loyalty
 * program already computes; this file only turns the fact into one push,
 * through the gate, never more than once for the same fact. The `offers`
 * topic gets its one honest recurring message: on Thursday evening, the
 * bundles that appeared this week for the animals this customer owns — a
 * digest, never one push per bundle.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Moments
{
    public static function boot(): void
    {
        add_action('zooboxi_loyalty_granted', [self::class, 'on_granted'], 10, 4);
        add_action('zooboxi_push_daily', [self::class, 'daily'], 20);
        add_action('zooboxi_push_tick', [self::class, 'bundles_digest'], 40);
    }

    private static function on(string $key): bool
    {
        return get_option('zooboxi_push_' . $key, 'yes') === 'yes';
    }

    /* ══════════════════════════════════════════════════════════════
       A GIFT LANDED
       ══════════════════════════════════════════════════════════════ */

    public static function on_granted(int $grant_id, int $user_id, array $reward, string $source): void
    {
        try {
            if ($user_id <= 0 || !self::on('moments') || !class_exists('Zooboxi_Push_Engine')) {
                return;
            }
            // Scratch prizes announce themselves on the card; a pending grant
            // (activates on delivery) is announced when it activates, by the
            // completed-order push. Only a gift that is usable right now.
            if (in_array($source, ['scratch', 'redeem'], true)) {
                return;
            }
            $name_ar = (string) ($reward['title_ar'] ?? '');
            $name_en = (string) ($reward['title_en'] ?? $name_ar);
            if ($source === 'birthday') {
                $pet = class_exists('Zooboxi_Loyalty_Pets') ? Zooboxi_Loyalty_Pets::first_name($user_id, 'صديقك', 'your pet') : 'صديقك';
                $copy = [
                    'ar' => ['عيد ميلاد ' . $pet . ' 🎂', 'هدية باسمه في محفظتك — أضفها لطلبك القادم.'],
                    'en' => [$pet . "'s birthday 🎂", 'A gift in their name is in your wallet — add it to your next order.'],
                ];
            } else {
                $copy = [
                    'ar' => ['هديتك جاهزة', ($name_ar !== '' ? $name_ar . ' — ' : '') . 'في محفظتك، تنطبق على طلبك القادم.'],
                    'en' => ['Your gift is ready', ($name_en !== '' ? $name_en . ' — ' : '') . 'in your wallet, for your next order.'],
                ];
            }
            Zooboxi_Push_Engine::submit([
                'user_id'      => $user_id,
                'topic'        => 'family',
                'tier'         => Zooboxi_Push_Gate::TIER_MARKETING,
                'copy'         => $copy,
                'route'        => '/family/rewards',
                'thread_id'    => 'family',
                'relevance'    => 0.7,
                'source'       => $source === 'birthday' ? 'birthday' : 'gift',
                'source_id'    => (string) $grant_id,
                'key'          => 'gift:' . $grant_id,
                'expires_at'   => time() + 3 * DAY_IN_SECONDS,
            ]);
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] gift moment failed: ' . $e->getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       DAILY — tier at risk, a mission one step away
       ══════════════════════════════════════════════════════════════ */

    public static function daily(): void
    {
        if (!self::on('moments') || !class_exists('Zooboxi_Loyalty_Members') || !class_exists('Zooboxi_Loyalty')) {
            return;
        }
        global $wpdb;
        $batch  = 300;
        $offset = (int) get_option('zooboxi_push_moments_cursor', 0);
        $users  = $wpdb->get_col($wpdb->prepare(
            'SELECT DISTINCT user_id FROM ' . Zooboxi_Push::table() . ' WHERE user_id > 0 AND enabled = 1 ORDER BY user_id LIMIT %d OFFSET %d',
            $batch, $offset
        ));
        update_option('zooboxi_push_moments_cursor', count($users) < $batch ? 0 : $offset + $batch, false);

        foreach ((array) $users as $uid) {
            $uid = (int) $uid;
            try {
                self::tier_risk($uid);
                self::mission_close($uid);
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] moments failed for ' . $uid . ': ' . $e->getMessage());
            }
        }
    }

    private static function tier_risk(int $uid): void
    {
        if (!class_exists('Zooboxi_Loyalty_Moments')) {
            return;
        }
        $risk = Zooboxi_Loyalty_Moments::tier_risk($uid);
        if (!is_array($risk)) {
            return;
        }
        $days = (int) ($risk['in_days'] ?? 0);
        if ($days <= 0 || $days > 7) {
            return;
        }
        $to_key = (string) ($risk['would_drop_to'] ?? '');
        $to = '';
        if ($to_key !== '' && class_exists('Zooboxi_Loyalty_Tiers')) {
            $def = Zooboxi_Loyalty_Tiers::definition($to_key);
            $to  = (string) ($def['name_ar'] ?? $def['name'] ?? $to_key);
        }
        Zooboxi_Push_Engine::submit([
            'user_id'   => $uid,
            'topic'     => 'family',
            'tier'      => Zooboxi_Push_Gate::TIER_MARKETING,
            'copy'      => [
                'ar' => ['طلب واحد يحفظ مستواك', 'خلال ' . $days . ' أيام يهبط مستواك' . ($to !== '' ? ' إلى ' . $to : '') . ' ما لم تطلب.'],
                'en' => ['One order keeps your tier', 'In ' . $days . ' days your tier drops' . ($to !== '' ? ' to ' . $to : '') . ' unless you order.'],
            ],
            'route'     => '/family',
            'thread_id' => 'family',
            'relevance' => 0.7,
            'source'    => 'tier_risk',
            'source_id' => gmdate('Y-m'),
            'key'       => 'tier_risk:' . $uid . ':' . gmdate('Y-m'),
            'expires_at' => time() + 3 * DAY_IN_SECONDS,
        ]);
    }

    private static function mission_close(int $uid): void
    {
        if (!class_exists('Zooboxi_Loyalty_Missions') || !class_exists('Zooboxi_Loyalty_Schema')) {
            return;
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::missions()
            . " WHERE user_id = %d AND state = 'active' AND target >= 2 AND progress >= CEIL(target * 0.75) AND progress < target ORDER BY id DESC LIMIT 1",
            $uid
        ), ARRAY_A) ?: [];
        foreach ($rows as $m) {
            $left  = max(1, (int) $m['target'] - (int) $m['progress']);
            $title = (string) ($m['title_ar'] ?? '');
            Zooboxi_Push_Engine::submit([
                'user_id'   => $uid,
                'topic'     => 'family',
                'tier'      => Zooboxi_Push_Gate::TIER_MARKETING,
                'copy'      => [
                    'ar' => ['مهمة على بُعد خطوة', ($title !== '' ? $title . ' — ' : '') . 'بقي ' . $left . ' لتكتمل وتأخذ مكافأتها.'],
                    'en' => ['One step from a mission', ($title !== '' ? $title . ' — ' : '') . $left . ' to go for the reward.'],
                ],
                'route'     => '/family',
                'thread_id' => 'family',
                'level'     => 'passive',
                'relevance' => 0.5,
                'source'    => 'mission',
                'source_id' => (string) $m['id'],
                'key'       => 'mission:' . $m['id'],
                'expires_at' => time() + 5 * DAY_IN_SECONDS,
            ]);
        }
    }

    /* ══════════════════════════════════════════════════════════════
       THURSDAY 19:00 — this week's bundles for your animals
       ══════════════════════════════════════════════════════════════ */

    public static function bundles_digest(int $now = 0): void
    {
        if (!self::on('bundles_digest') || !class_exists('Zooboxi_Push_Engine')) {
            return;
        }
        $now   = $now > 0 ? $now : time();
        $local = (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz());
        // Thursday, from 19:00; once per ISO week.
        if ((int) $local->format('N') !== 4 || (int) $local->format('G') < 19) {
            return;
        }
        $week = $local->format('o-\WW');
        if ((string) get_option('zooboxi_push_bundles_week', '') === $week) {
            return;
        }
        update_option('zooboxi_push_bundles_week', $week, false);

        try {
            global $wpdb;
            // Bundles published in the last seven days, by species.
            $since = gmdate('Y-m-d H:i:s', $now - 7 * DAY_IN_SECONDS);
            $rows  = $wpdb->get_results($wpdb->prepare(
                "SELECT p.ID, COALESCE(s.meta_value, 'mixed') AS species FROM {$wpdb->posts} p
                 JOIN {$wpdb->postmeta} b ON b.post_id = p.ID AND b.meta_key = '_zb_bundle_id'
                 LEFT JOIN {$wpdb->postmeta} s ON s.post_id = p.ID AND s.meta_key = '_zb_bundle_species'
                 WHERE p.post_type = 'product' AND p.post_status = 'publish' AND p.post_date_gmt >= %s",
                $since
            ), ARRAY_A) ?: [];
            if (!$rows) {
                return;
            }
            $by_species = [];
            foreach ($rows as $r) {
                $by_species[(string) $r['species']] = ($by_species[(string) $r['species']] ?? 0) + 1;
            }
            $mixed = (int) ($by_species['mixed'] ?? 0);

            $users = $wpdb->get_col('SELECT DISTINCT user_id FROM ' . Zooboxi_Push::table() . ' WHERE user_id > 0 AND enabled = 1 LIMIT 5000') ?: [];
            $labels = ['cat' => ['للقطط', 'for cats'], 'dog' => ['للكلاب', 'for dogs'], 'bird' => ['للطيور', 'for birds'], 'small' => ['للحيوانات الصغيرة', 'for small pets']];
            foreach ($users as $uid) {
                $uid = (int) $uid;
                $species = class_exists('Zooboxi_Loyalty_Pets') ? Zooboxi_Loyalty_Pets::species_of($uid) : [];
                $n = $mixed;
                $main = '';
                foreach ($species as $sp) {
                    $c = (int) ($by_species[$sp] ?? 0);
                    if ($c > 0 && $main === '') {
                        $main = $sp;
                    }
                    $n += $c;
                }
                if ($n <= 0) {
                    continue;
                }
                $lbl = $labels[$main] ?? ['', ''];
                Zooboxi_Push_Engine::submit([
                    'user_id'   => $uid,
                    'topic'     => 'offers',
                    'tier'      => Zooboxi_Push_Gate::TIER_MARKETING,
                    'copy'      => [
                        'ar' => [$n === 1 ? 'بكج جديد ' . $lbl[0] : $n . ' بكجات جديدة ' . $lbl[0], 'توفير حقيقي على ما تشتريه أصلًا — هذا الأسبوع.'],
                        'en' => [$n === 1 ? 'A new bundle ' . $lbl[1] : $n . ' new bundles ' . $lbl[1], 'Real savings on what you already buy — this week.'],
                    ],
                    'route'     => '/bundles',
                    'thread_id' => 'offers',
                    'level'     => 'passive',
                    'relevance' => 0.5,
                    'source'    => 'bundles',
                    'source_id' => $week,
                    'key'       => 'bundles:' . $uid . ':' . $week,
                    'expires_at' => $now + 2 * DAY_IN_SECONDS,
                    'sto'       => false,
                ]);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] bundles digest failed: ' . $e->getMessage());
        }
    }
}
