<?php
/**
 * Zooboxi_Loyalty_Members — membership, the holdout draw, and the tier cache.
 *
 * A member row is created on the FIRST touch (a completed order, opening the family
 * hub, adding a pet) — never in bulk, so the program's own numbers stay honest about
 * when each customer actually joined.
 *
 * THE HOLDOUT: 10% of members are drawn once, deterministically, and never play
 * (no scratch cards, no missions). They still earn paws and hold a tier, so the
 * difference we measure is the GAME, not the currency. The draw uses a stored salt
 * so it is stable across deploys and impossible to reverse-engineer from a user id.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Members
{
    /** Per-request memo: user_id => row array. */
    private static array $cache = [];

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    /** The member row, or null when this customer has never touched the program. */
    public static function get(int $user_id): ?array
    {
        if ($user_id <= 0) {
            return null;
        }
        if (array_key_exists($user_id, self::$cache)) {
            return self::$cache[$user_id];
        }

        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::members() . ' WHERE user_id = %d LIMIT 1',
            $user_id
        ), ARRAY_A);

        return self::$cache[$user_id] = (is_array($row) ? $row : null);
    }

    /** Drop the memo (after any write). */
    public static function forget(int $user_id): void
    {
        unset(self::$cache[$user_id]);
    }

    /* ══════════════════════════════════════════════════════════════
       ENSURE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Create the member row if it does not exist yet, then return it.
     *
     * Idempotent under concurrency: the UNIQUE key on user_id turns a racing second
     * insert into a duplicate error we swallow and re-read.
     */
    public static function ensure(int $user_id): ?array
    {
        if ($user_id <= 0) {
            return null;
        }
        $row = self::get($user_id);
        if ($row !== null) {
            return $row;
        }

        Zooboxi_Loyalty_Schema::maybe_install();

        global $wpdb;
        $wpdb->insert(Zooboxi_Loyalty_Schema::members(), [
            'user_id'          => $user_id,
            'joined_at'        => Zooboxi_Loyalty::now(),
            'holdout'          => self::draw_holdout($user_id) ? 1 : 0,
            'tier_key'         => 'new',
            'tier_orders_12m'  => 0,
            'tier_computed_at' => null,
            'paws_balance'     => 0,
            'referral_code'    => self::mint_referral_code($user_id),
        ], ['%d', '%s', '%d', '%s', '%d', '%s', '%d', '%s']);

        self::forget($user_id);
        return self::get($user_id);
    }

    /** Is this member in the control group? (false for non-members — they cannot play anyway.) */
    public static function is_holdout(int $user_id): bool
    {
        $row = self::get($user_id);
        return $row !== null && (int) $row['holdout'] === 1;
    }

    /**
     * The one-time draw: `crc32(user_id . salt) % 100 < holdout_pct`.
     *
     * The salt is generated once and stored, so the same customer lands on the same
     * side of the line forever — moving people between arms would destroy the read.
     */
    public static function draw_holdout(int $user_id): bool
    {
        $pct = max(0, min(100, Zooboxi_Loyalty::opt_int('holdout_pct')));
        if ($pct <= 0) {
            return false;
        }
        return (crc32($user_id . self::salt()) % 100) < $pct;
    }

    private static function salt(): string
    {
        $salt = (string) get_option('zooboxi_loyalty_holdout_salt', '');
        if ($salt === '') {
            $salt = wp_generate_password(24, false, false);
            update_option('zooboxi_loyalty_holdout_salt', $salt, false);
        }
        return $salt;
    }

    /** A short, unambiguous referral code (Phase 2 uses it; Phase 1 only mints it). */
    private static function mint_referral_code(int $user_id): string
    {
        // No 0/O/1/I — these codes get read aloud and typed by hand.
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $seed     = strtoupper(substr(hash('sha256', 'zb-ref|' . $user_id . '|' . self::salt()), 0, 16));

        $code = 'ZB';
        for ($i = 0; $i < 5; $i++) {
            $code .= $alphabet[hexdec($seed[$i * 2] . $seed[$i * 2 + 1]) % strlen($alphabet)];
        }
        return $code;
    }

    /* ══════════════════════════════════════════════════════════════
       TIER CACHE
       ══════════════════════════════════════════════════════════════ */

    /**
     * The member's tier key, from the cached column when fresh.
     *
     * The count behind it (completed orders in a rolling 365 days) is a real order
     * query, so it is computed at most once a day per member and invalidated the
     * moment one of their orders changes status.
     */
    public static function tier_key(int $user_id): string
    {
        $state = self::tier_state($user_id);
        return (string) $state['key'];
    }

    /** @return array{key:string,orders_12m:int} */
    public static function tier_state(int $user_id): array
    {
        if ($user_id <= 0) {
            return ['key' => 'new', 'orders_12m' => 0];
        }

        $row = self::get($user_id);
        if ($row === null) {
            // Not a member yet — the tier is still real (it reads history), it is
            // just not worth writing a row for a customer who never touched us.
            $orders = Zooboxi_Loyalty_Tiers::count_completed_12m($user_id);
            return ['key' => Zooboxi_Loyalty_Tiers::key_for_orders($orders), 'orders_12m' => $orders];
        }

        $computed = (string) ($row['tier_computed_at'] ?? '');
        $fresh    = $computed !== '' && (time() - (int) strtotime($computed . ' UTC')) < DAY_IN_SECONDS;

        if ($fresh) {
            return [
                'key'        => (string) $row['tier_key'],
                'orders_12m' => (int) $row['tier_orders_12m'],
            ];
        }

        return self::recompute_tier($user_id);
    }

    /** Force a recount and write it back to the member row. */
    public static function recompute_tier(int $user_id): array
    {
        $orders = Zooboxi_Loyalty_Tiers::count_completed_12m($user_id);
        $key    = Zooboxi_Loyalty_Tiers::key_for_orders($orders);

        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::members(),
            [
                'tier_key'         => $key,
                'tier_orders_12m'  => $orders,
                'tier_computed_at' => Zooboxi_Loyalty::now(),
            ],
            ['user_id' => $user_id],
            ['%s', '%d', '%s'],
            ['%d']
        );
        self::forget($user_id);
        if (class_exists('Zooboxi_Loyalty_Tiers')) {
            Zooboxi_Loyalty_Tiers::forget_memo();
        }

        return ['key' => $key, 'orders_12m' => $orders];
    }

    /** Mark the cached tier stale (called on every order status transition). */
    public static function invalidate_tier(int $user_id): void
    {
        if ($user_id <= 0) {
            return;
        }
        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::members(),
            ['tier_computed_at' => null],
            ['user_id' => $user_id],
            ['%s'],
            ['%d']
        );
        self::forget($user_id);
    }

    /* ══════════════════════════════════════════════════════════════
       PROFILE COMPLETION
       ══════════════════════════════════════════════════════════════ */

    /** Stamp (once) the moment this member first had a complete pet profile. */
    public static function mark_profile_complete(int $user_id): bool
    {
        $row = self::ensure($user_id);
        if ($row === null || !empty($row['profile_completed_at'])) {
            return false;
        }
        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::members(),
            ['profile_completed_at' => Zooboxi_Loyalty::now()],
            ['user_id' => $user_id],
            ['%s'],
            ['%d']
        );
        self::forget($user_id);
        return true;
    }

    /** The member DTO the app shows at the top of the family hub. */
    public static function dto(int $user_id): array
    {
        $row = self::get($user_id);
        return [
            'joined_at'     => $row ? Zooboxi_Loyalty::iso((string) $row['joined_at']) : null,
            'holdout'       => $row ? ((int) $row['holdout'] === 1) : false,
            'referral_code' => $row ? (string) ($row['referral_code'] ?? '') : '',
        ];
    }
}
