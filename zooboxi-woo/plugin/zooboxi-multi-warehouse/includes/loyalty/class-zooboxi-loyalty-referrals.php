<?php
/**
 * Zooboxi_Loyalty_Referrals — «ادعُ صديقاً».
 *
 * The referral code was minted with the membership in Phase 1; this class spends it.
 *
 * TRUST MODEL: every account is one verified phone (OTP), so "a different person" is
 * already mostly guaranteed. What the program still checks is the cheap fraud — the
 * same household inviting itself: the referee's first-order shipping address or phone
 * matching the referrer's puts the referral in `review` instead of paying. The reward
 * itself is paid only after the referee's first order is DELIVERED and the return
 * window (`referral_hold_days`) has passed, and never more than `referral_cap` times a
 * month per referrer.
 *
 * Two doors in:
 *   · the app: `POST /loyalty/referral/apply {code}`
 *   · the web: `?ref=CODE` → cookie → applied on `user_register`
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Referrals
{
    public const COOKIE = 'zb_ref';

    public static function enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('referral_enabled', 'yes') === 'yes';
    }

    public static function reward_paws(): int
    {
        return max(0, Zooboxi_Loyalty::opt_int('referral_paws', 300));
    }

    public static function cap(): int
    {
        return max(0, Zooboxi_Loyalty::opt_int('referral_cap', 10));
    }

    /* ══════════════════════════════════════════════════════════════
       WEB CAPTURE
       ══════════════════════════════════════════════════════════════ */

    public static function register_hooks(): void
    {
        add_action('init', [__CLASS__, 'capture_query'], 5);
        add_action('user_register', [__CLASS__, 'apply_cookie'], 30);
    }

    /** `?ref=CODE` on any page → a 30-day cookie. */
    public static function capture_query(): void
    {
        if (empty($_GET['ref']) || headers_sent() || !self::enabled()) {
            return;
        }
        $code = self::clean_code((string) wp_unslash($_GET['ref']));
        if ($code === '') {
            return;
        }
        setcookie(self::COOKIE, $code, [
            'expires'  => time() + 30 * DAY_IN_SECONDS,
            'path'     => '/',
            'secure'   => is_ssl(),
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
        $_COOKIE[self::COOKIE] = $code;
    }

    /** A new account with the cookie set → apply, quietly. */
    public static function apply_cookie($user_id): void
    {
        try {
            $code = isset($_COOKIE[self::COOKIE]) ? self::clean_code((string) wp_unslash($_COOKIE[self::COOKIE])) : '';
            if ($code === '' || (int) $user_id <= 0) {
                return;
            }
            self::apply((int) $user_id, $code);
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] referral cookie apply failed: ' . $e->getMessage());
        }
    }

    public static function clean_code(string $code): string
    {
        $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $code));
        return (strlen($code) >= 5 && strlen($code) <= 12) ? $code : '';
    }

    /* ══════════════════════════════════════════════════════════════
       APPLY
       ══════════════════════════════════════════════════════════════ */

    public static function referrer_by_code(string $code): int
    {
        $code = self::clean_code($code);
        if ($code === '') {
            return 0;
        }
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT user_id FROM ' . Zooboxi_Loyalty_Schema::members() . ' WHERE referral_code = %s LIMIT 1',
            $code
        ));
    }

    public static function for_referee(int $referee_id): ?array
    {
        if ($referee_id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::referrals() . ' WHERE referee_id = %d LIMIT 1',
            $referee_id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** Referrals created by this referrer in the current calendar month. */
    public static function month_count(int $referrer_id): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::referrals()
            . " WHERE referrer_id = %d AND state <> 'rejected' AND created_at >= %s",
            $referrer_id,
            gmdate('Y-m-01 00:00:00')
        ));
    }

    /** Has this customer ever ordered? (any status but cancelled/failed) */
    private static function has_orders(int $user_id): bool
    {
        if (!function_exists('wc_get_orders')) {
            return false;
        }
        $ids = wc_get_orders([
            'customer_id' => $user_id,
            'status'      => ['pending', 'on-hold', 'processing', 'completed', 'zb-ready', 'refunded'],
            'limit'       => 1,
            'return'      => 'ids',
        ]);
        return is_array($ids) && !empty($ids);
    }

    /**
     * Bind a new customer to the code's owner and hand them the welcome.
     *
     * @return array{row:?array,code:string,ar:string,en:string,grant_id:int,paws:int}
     */
    public static function apply(int $referee_id, string $code): array
    {
        $no = static fn (string $c, string $ar, string $en) => ['row' => null, 'code' => $c, 'ar' => $ar, 'en' => $en, 'grant_id' => 0, 'paws' => 0];

        if ($referee_id <= 0 || !self::enabled()) {
            return $no('referral_disabled', 'الدعوات غير متاحة حالياً', 'Referrals are not available right now.');
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        $referrer_id = self::referrer_by_code($code);
        if ($referrer_id <= 0) {
            return $no('referral_invalid', 'كود الدعوة غير صحيح', 'That invitation code is not valid.');
        }
        if ($referrer_id === $referee_id) {
            return $no('referral_self', 'لا يمكنك دعوة نفسك 🙂', 'You cannot invite yourself.');
        }
        if (self::for_referee($referee_id) !== null) {
            return $no('referral_used', 'سبق أن استخدمت كود دعوة', 'You have already used an invitation code.');
        }
        if (self::has_orders($referee_id)) {
            return $no('referral_not_new', 'كود الدعوة للعملاء الجدد قبل أول طلب', 'Invitation codes are for new customers, before their first order.');
        }
        if (self::cap() > 0 && self::month_count($referrer_id) >= self::cap()) {
            return $no('referral_cap', 'وصل صاحب الكود إلى حدّ الدعوات لهذا الشهر', 'The code\'s owner has reached this month\'s invitation limit.');
        }

        Zooboxi_Loyalty_Members::ensure($referee_id);
        $now = Zooboxi_Loyalty::now();

        global $wpdb;
        $prev_show     = $wpdb->hide_errors();
        $prev_suppress = $wpdb->suppress_errors(true);
        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::referrals(), [
            'referrer_id' => $referrer_id,
            'referee_id'  => $referee_id,
            'code'        => self::clean_code($code),
            'state'       => 'pending',
            'created_at'  => $now,
            'updated_at'  => $now,
        ], ['%d', '%d', '%s', '%s', '%s', '%s']);
        $wpdb->suppress_errors($prev_suppress);
        if ($prev_show) {
            $wpdb->show_errors();
        }
        if (!$ok) {
            return $no('referral_used', 'سبق أن استخدمت كود دعوة', 'You have already used an invitation code.');
        }
        $id = (int) $wpdb->insert_id;

        // The referee's welcome: the gift when the owner attached one, else paws.
        $grant_id = 0;
        $paws     = 0;
        $reward   = Zooboxi_Loyalty_Rewards::reward_by_key('referral_welcome');
        if ($reward !== null && (int) $reward['is_active'] === 1 && Zooboxi_Loyalty_Rewards::reward_product($reward) !== null) {
            $grant_id = Zooboxi_Loyalty_Rewards::grant($referee_id, (int) $reward['id'], 'referral', $id, null);
        } else {
            $paws = max(0, Zooboxi_Loyalty::opt_int('referral_welcome_paws', 100));
            if ($paws > 0) {
                Zooboxi_Loyalty_Ledger::add(
                    $referee_id,
                    $paws,
                    'welcome',
                    'referral',
                    $id,
                    Zooboxi_Loyalty::pick('هدية الترحيب — بدعوة من صديق', 'Welcome — invited by a friend')
                );
            }
        }

        return ['row' => self::find($id), 'code' => '', 'ar' => '', 'en' => '', 'grant_id' => $grant_id, 'paws' => $paws];
    }

    public static function find(int $id): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::referrals() . ' WHERE id = %d LIMIT 1',
            $id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /* ══════════════════════════════════════════════════════════════
       QUALIFY (the referee's first delivered order)
       ══════════════════════════════════════════════════════════════ */

    public static function on_order_completed(\WC_Order $order): void
    {
        $referee_id = (int) $order->get_customer_id();
        if ($referee_id <= 0 || !self::enabled()) {
            return;
        }
        $row = self::for_referee($referee_id);
        if ($row === null || (string) $row['state'] !== 'pending') {
            return;
        }

        $flags = self::fraud_flags($order, (int) $row['referrer_id']);
        $state = empty($flags) ? 'qualified' : 'review';

        global $wpdb;
        $wpdb->update(Zooboxi_Loyalty_Schema::referrals(), [
            'state'          => $state,
            'first_order_id' => (int) $order->get_id(),
            'qualified_at'   => Zooboxi_Loyalty::now(),
            'flags'          => mb_substr(implode(',', $flags), 0, 200),
            'updated_at'     => Zooboxi_Loyalty::now(),
        ], ['id' => (int) $row['id'], 'state' => 'pending']);
    }

    /** Same household? Compare the referee's shipping address and phone with the referrer's. */
    private static function fraud_flags(\WC_Order $order, int $referrer_id): array
    {
        $flags = [];
        try {
            $addr  = self::norm($order->get_shipping_address_1() . ' ' . $order->get_shipping_city());
            $phone = preg_replace('/\D+/', '', (string) $order->get_billing_phone());
            $phone = substr($phone, -9);

            $ref_phone = substr(preg_replace('/\D+/', '', (string) get_user_meta($referrer_id, 'billing_phone', true)), -9);
            if ($phone !== '' && $ref_phone !== '' && $phone === $ref_phone) {
                $flags[] = 'same_phone';
            }

            $ref_orders = wc_get_orders(['customer_id' => $referrer_id, 'limit' => 5, 'orderby' => 'date', 'order' => 'DESC']);
            foreach ((array) $ref_orders as $o) {
                if (!($o instanceof \WC_Order)) {
                    continue;
                }
                $ra = self::norm($o->get_shipping_address_1() . ' ' . $o->get_shipping_city());
                if ($addr !== '' && $ra !== '' && $addr === $ra) {
                    $flags[] = 'same_address';
                    break;
                }
            }
        } catch (\Throwable $e) {
            // Failing to check is not evidence of fraud.
        }
        return array_values(array_unique($flags));
    }

    private static function norm(string $s): string
    {
        $s = mb_strtolower(trim($s));
        return preg_replace('/[\s\-_,\.]+/u', ' ', $s);
    }

    /* ══════════════════════════════════════════════════════════════
       DAILY — pay what has cleared the hold
       ══════════════════════════════════════════════════════════════ */

    public static function reward_due(): int
    {
        if (!self::enabled()) {
            return 0;
        }
        $hold = max(0, Zooboxi_Loyalty::opt_int('referral_hold_days', 7));
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::referrals()
            . " WHERE state = 'qualified' AND qualified_at <= %s ORDER BY qualified_at ASC LIMIT 200",
            gmdate('Y-m-d H:i:s', time() - $hold * DAY_IN_SECONDS)
        ), ARRAY_A);

        $paid = 0;
        foreach ((array) $rows as $row) {
            if (self::pay((int) $row['id'])) {
                $paid++;
            }
        }
        return $paid;
    }

    /** Pay the referrer for one referral (also the admin's "approve"). */
    public static function pay(int $id): bool
    {
        $row = self::find($id);
        if ($row === null || !in_array((string) $row['state'], ['qualified', 'review'], true)) {
            return false;
        }
        // The first order must still stand.
        $order = !empty($row['first_order_id']) ? wc_get_order((int) $row['first_order_id']) : null;
        if ($order instanceof \WC_Order && in_array($order->get_status(), ['cancelled', 'refunded', 'failed'], true)) {
            return self::reject($id);
        }

        global $wpdb;
        $claimed = (int) $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::referrals()
            . " SET state = 'rewarded', rewarded_at = %s, updated_at = %s WHERE id = %d AND state IN ('qualified','review')",
            Zooboxi_Loyalty::now(),
            Zooboxi_Loyalty::now(),
            $id
        ));
        if ($claimed <= 0) {
            return false;
        }

        $referrer_id = (int) $row['referrer_id'];
        $paws        = self::reward_paws();
        if ($paws > 0) {
            Zooboxi_Loyalty_Ledger::add(
                $referrer_id,
                $paws,
                'referral',
                'referral',
                $id,
                Zooboxi_Loyalty::pick('صديقك أتمّ أول طلب — شكراً للدعوة', 'Your friend completed a first order — thanks for the invite')
            );
        }
        if (class_exists('Zooboxi_Loyalty_Missions')) {
            Zooboxi_Loyalty_Missions::progress_kind($referrer_id, 'growth', 1);
        }
        if (class_exists('Zooboxi_Loyalty_Mail')) {
            Zooboxi_Loyalty_Mail::send($referrer_id, 'referral_rewarded', 'ref:' . $id, [
                'subject_ar' => 'صديقك انضم إلى عائلة زوبوكسي 🎉',
                'subject_en' => 'Your friend joined the Zooboxi Family 🎉',
                'lines_ar'   => [sprintf('أتمّ صديقك أول طلب له، وأضفنا %d بصمة إلى محفظتك.', $paws), 'ادعُ المزيد — لكل صديق مكافأة.'],
                'lines_en'   => [sprintf('Your friend completed a first order and %d paws landed in your wallet.', $paws), 'Invite more — every friend earns you a reward.'],
                'cta_ar'     => 'افتح المحفظة',
                'cta_en'     => 'Open my wallet',
                'cta_url'    => home_url('/my-account/'),
            ]);
        }
        return true;
    }

    public static function reject(int $id): bool
    {
        global $wpdb;
        return (bool) $wpdb->update(Zooboxi_Loyalty_Schema::referrals(), [
            'state'      => 'rejected',
            'updated_at' => Zooboxi_Loyalty::now(),
        ], ['id' => $id]);
    }

    /** Referrals waiting for a human (the admin list). */
    public static function in_review(int $limit = 50): array
    {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::referrals() . " WHERE state = 'review' ORDER BY qualified_at ASC LIMIT %d",
            $limit
        ), ARRAY_A);
        return is_array($rows) ? $rows : [];
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function share_url(string $code): string
    {
        return add_query_arg('ref', rawurlencode($code), home_url('/'));
    }

    /** The light block on `/loyalty/summary`. */
    public static function summary_block(int $user_id): ?array
    {
        if (!self::enabled()) {
            return null;
        }
        $member = Zooboxi_Loyalty_Members::get($user_id);
        $code   = $member ? (string) ($member['referral_code'] ?? '') : '';
        if ($code === '') {
            return null;
        }
        global $wpdb;
        $rewarded = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::referrals() . " WHERE referrer_id = %d AND state = 'rewarded'",
            $user_id
        ));
        return [
            'code'        => $code,
            'url'         => self::share_url($code),
            'reward_paws' => self::reward_paws(),
            'rewarded'    => $rewarded,
        ];
    }

    /** The full referral screen. */
    public static function overview(int $user_id): array
    {
        $member = Zooboxi_Loyalty_Members::ensure($user_id);
        $code   = $member ? (string) ($member['referral_code'] ?? '') : '';
        $paws   = self::reward_paws();

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::referrals() . ' WHERE referrer_id = %d ORDER BY id DESC LIMIT 50',
            $user_id
        ), ARRAY_A);

        $stats = ['invited' => 0, 'qualified' => 0, 'rewarded' => 0];
        $items = [];
        foreach ((array) $rows as $row) {
            $stats['invited']++;
            if (in_array((string) $row['state'], ['qualified', 'review'], true)) {
                $stats['qualified']++;
            } elseif ((string) $row['state'] === 'rewarded') {
                $stats['rewarded']++;
            }
            $user  = get_user_by('id', (int) $row['referee_id']);
            $name  = $user ? trim((string) ($user->first_name ?: $user->display_name)) : '';
            $items[] = [
                'name'       => self::mask($name),
                'state'      => (string) $row['state'],
                'created_at' => Zooboxi_Loyalty::iso((string) $row['created_at']),
            ];
        }

        $applied = self::for_referee($user_id);
        $welcome = Zooboxi_Loyalty_Rewards::reward_by_key('referral_welcome');
        $welcome_text = ($welcome !== null && (int) $welcome['is_active'] === 1 && Zooboxi_Loyalty_Rewards::reward_product($welcome) !== null)
            ? Zooboxi_Loyalty::pick((string) $welcome['title_ar'], (string) $welcome['title_en'])
            : sprintf(Zooboxi_Loyalty::pick('%d بصمة ترحيب', '%d welcome paws'), max(0, Zooboxi_Loyalty::opt_int('referral_welcome_paws', 100)));

        return [
            'code'        => $code,
            'url'         => $code !== '' ? self::share_url($code) : '',
            'share_text'  => $code !== '' ? sprintf(
                Zooboxi_Loyalty::pick(
                    'جرّب زوبوكسي لمستلزمات حيوانك — استخدم كود الدعوة %1$s وخذ %2$s مع أول طلب: %3$s',
                    'Try Zooboxi for your pet — use invitation code %1$s and get %2$s with your first order: %3$s'
                ),
                $code,
                $welcome_text,
                self::share_url($code)
            ) : '',
            'reward_paws' => $paws,
            'welcome'     => $welcome_text,
            'cap'         => self::cap(),
            'this_month'  => self::month_count($user_id),
            'stats'       => $stats,
            'items'       => $items,
            'applied'     => $applied !== null ? ['code' => (string) $applied['code'], 'state' => (string) $applied['state']] : null,
            'enabled'     => self::enabled(),
        ];
    }

    /** «محمد» → «م…» — the referrer never sees who exactly signed up. */
    private static function mask(string $name): string
    {
        $name = trim($name);
        if ($name === '') {
            return Zooboxi_Loyalty::pick('صديق', 'A friend');
        }
        return mb_substr($name, 0, 1) . '…';
    }
}
