<?php
/**
 * Zooboxi_Loyalty_Ledger — the append-only book of «بصمات» / Paws.
 *
 * THE ONE INVARIANT: nothing here ever updates or deletes a row. A mistake is
 * corrected by writing its opposite (`reverse`), never by editing history — which is
 * what makes the balance auditable and what makes double-payment structurally
 * impossible: UNIQUE (user_id, reason, ref_type, ref_id) means the same reason for
 * the same reference can only be written once, no matter how many times WooCommerce
 * replays a status transition.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Ledger
{
    public const REASONS = [
        'order_earn', 'profile_complete', 'pet_added', 'mission',
        'scratch', 'redeem', 'reverse', 'expire', 'adjust', 'welcome',
        // Phase 2 «العادة»
        'on_time', 'sub_bonus', 'referral', 'birthday',
    ];

    /* ══════════════════════════════════════════════════════════════
       WRITE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Append one entry. Returns the new row id, or 0 when the entry already existed
     * (the idempotent no-op) or the input was refused.
     *
     * `$delta` may be negative; a spend is just a negative entry.
     */
    public static function add(int $user_id, int $delta, string $reason, string $ref_type = '', int $ref_id = 0, string $note = ''): int
    {
        if ($user_id <= 0 || $delta === 0 || !in_array($reason, self::REASONS, true)) {
            return 0;
        }

        Zooboxi_Loyalty_Schema::maybe_install();
        Zooboxi_Loyalty_Members::ensure($user_id);

        global $wpdb;

        $balance_before = self::balance($user_id);

        // Suppress wpdb's own error printing for THIS insert only: a duplicate key is
        // the expected outcome of a replayed hook, not a fault worth screaming about.
        $prev_show      = $wpdb->hide_errors();
        $prev_suppress  = $wpdb->suppress_errors(true);

        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::ledger(), [
            'user_id'       => $user_id,
            'delta'         => $delta,
            'balance_after' => $balance_before + $delta,
            'reason'        => $reason,
            'ref_type'      => mb_substr($ref_type, 0, 24),
            'ref_id'        => max(0, $ref_id),
            'note'          => mb_substr($note, 0, 200),
            'created_at'    => Zooboxi_Loyalty::now(),
        ], ['%d', '%d', '%d', '%s', '%s', '%d', '%s', '%s']);

        $error = (string) $wpdb->last_error;
        $wpdb->suppress_errors($prev_suppress);
        if ($prev_show) {
            $wpdb->show_errors();
        }

        if (!$ok) {
            // Duplicate entry = the work was already done. Anything else is real.
            if ($error !== '' && stripos($error, 'duplicate') === false) {
                error_log('[Zooboxi Loyalty] ledger insert failed: ' . $error);
            }
            return 0;
        }

        $id = (int) $wpdb->insert_id;
        self::sync_balance($user_id, $delta > 0);
        return $id;
    }

    /**
     * Recompute the mirrored balance on the member row from the book itself, so a
     * lost update can never leave the two out of step.
     */
    public static function sync_balance(int $user_id, bool $touch_earn = false): int
    {
        global $wpdb;

        $balance = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COALESCE(SUM(delta), 0) FROM ' . Zooboxi_Loyalty_Schema::ledger() . ' WHERE user_id = %d',
            $user_id
        ));

        $data   = ['paws_balance' => $balance];
        $format = ['%d'];
        if ($touch_earn) {
            $data['last_earn_at'] = Zooboxi_Loyalty::now();
            $format[]             = '%s';
        }

        $wpdb->update(Zooboxi_Loyalty_Schema::members(), $data, ['user_id' => $user_id], $format, ['%d']);
        Zooboxi_Loyalty_Members::forget($user_id);

        return $balance;
    }

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    /** The member's balance — from the mirror column, which sync_balance() keeps true. */
    public static function balance(int $user_id): int
    {
        $row = Zooboxi_Loyalty_Members::get($user_id);
        return $row ? (int) $row['paws_balance'] : 0;
    }

    /** Does an entry with this exact signature already exist? */
    public static function has_entry(int $user_id, string $reason, string $ref_type, int $ref_id): bool
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT id FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . ' WHERE user_id = %d AND reason = %s AND ref_type = %s AND ref_id = %d LIMIT 1',
            $user_id,
            $reason,
            $ref_type,
            $ref_id
        )) > 0;
    }

    /** The delta of one specific entry (0 when absent) — used to size a reversal. */
    public static function entry_delta(int $user_id, string $reason, string $ref_type, int $ref_id): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT delta FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . ' WHERE user_id = %d AND reason = %s AND ref_type = %s AND ref_id = %d LIMIT 1',
            $user_id,
            $reason,
            $ref_type,
            $ref_id
        ));
    }

    /**
     * One page of the book, newest first.
     *
     * @return array{items:array<int,array>,page:int,has_more:bool}
     */
    public static function page(int $user_id, int $page = 1, int $per_page = 25): array
    {
        $page     = max(1, $page);
        $per_page = max(1, min(100, $per_page));
        $offset   = ($page - 1) * $per_page;

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT id, delta, balance_after, reason, ref_type, ref_id, note, created_at FROM '
            . Zooboxi_Loyalty_Schema::ledger()
            . ' WHERE user_id = %d ORDER BY id DESC LIMIT %d OFFSET %d',
            $user_id,
            $per_page + 1,
            $offset
        ), ARRAY_A);

        $rows     = is_array($rows) ? $rows : [];
        $has_more = count($rows) > $per_page;
        $rows     = array_slice($rows, 0, $per_page);

        $items = [];
        foreach ($rows as $r) {
            $items[] = [
                'id'            => (int) $r['id'],
                'delta'         => (int) $r['delta'],
                'balance_after' => (int) $r['balance_after'],
                'reason'        => (string) $r['reason'],
                'reason_label'  => self::reason_label((string) $r['reason']),
                'ref_type'      => (string) $r['ref_type'],
                'ref_id'        => (int) $r['ref_id'],
                'note'          => (string) $r['note'],
                'created_at'    => Zooboxi_Loyalty::iso((string) $r['created_at']),
            ];
        }

        return ['items' => $items, 'page' => $page, 'has_more' => $has_more];
    }

    /** Human label for a ledger reason, in the request's language. */
    public static function reason_label(string $reason): string
    {
        $map = [
            'order_earn'       => ['بصمات طلب', 'Order earn'],
            'profile_complete' => ['اكتمال ملف عائلتك', 'Profile completed'],
            'pet_added'        => ['إضافة حيوان', 'Pet added'],
            'mission'          => ['مهمة الشهر', 'Monthly mission'],
            'scratch'          => ['اخدش واربح', 'Scratch card'],
            'redeem'           => ['استبدال مكافأة', 'Reward redeemed'],
            'reverse'          => ['عكس قيد', 'Reversal'],
            'expire'           => ['انتهاء صلاحية', 'Expired'],
            'adjust'           => ['تعديل يدوي', 'Manual adjustment'],
            'welcome'          => ['هدية الترحيب', 'Welcome bonus'],
            'on_time'          => ['طلب في وقته +20%', 'On-time order +20%'],
            'sub_bonus'        => ['توصيلة اشتراك', 'Subscription delivery'],
            'referral'         => ['دعوة صديق', 'Friend referral'],
            'birthday'         => ['عيد ميلاد', 'Birthday'],
        ];
        return isset($map[$reason]) ? Zooboxi_Loyalty::pick($map[$reason][0], $map[$reason][1]) : $reason;
    }

    /* ══════════════════════════════════════════════════════════════
       ORDER EARN / REVERSE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Paws for a delivered order.
     *
     * The base is the sum of line totals AFTER discount and WITHOUT tax, shipping, or
     * gift lines — a gift can never earn paws that buy the next gift.
     */
    public static function order_paws(\WC_Order $order): int
    {
        $rate = Zooboxi_Loyalty::opt_float('points_per_riyal');
        if ($rate <= 0) {
            return 0;
        }

        $base = 0.0;
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                continue; // a gift line is not a purchase
            }
            $base += (float) $item->get_total();
        }

        return (int) floor($base * $rate);
    }

    /** Award the order's paws exactly once. Returns the amount actually written. */
    public static function earn_for_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0) {
            return 0;
        }
        $paws = self::order_paws($order);
        if ($paws <= 0) {
            return 0;
        }
        $written = self::add($user_id, $paws, 'order_earn', 'order', (int) $order->get_id());
        return $written > 0 ? $paws : 0;
    }

    /**
     * Undo an order's earn with an opposite entry (never a delete). No-op when the
     * order never earned, or when it was already reversed.
     */
    public static function reverse_for_order(\WC_Order $order): int
    {
        $user_id  = (int) $order->get_customer_id();
        $order_id = (int) $order->get_id();
        if ($user_id <= 0) {
            return 0;
        }

        $earned = self::entry_delta($user_id, 'order_earn', 'order', $order_id);
        if ($earned <= 0) {
            return 0;
        }
        $written = self::add(
            $user_id,
            -$earned,
            'reverse',
            'order',
            $order_id,
            Zooboxi_Loyalty::pick('عكس بصمات طلب ملغى', 'Reversed: order cancelled')
        );
        return $written > 0 ? $earned : 0;
    }

    /* ══════════════════════════════════════════════════════════════
       EXPIRY
       ══════════════════════════════════════════════════════════════ */

    /**
     * Zero out the balance of every member who has not earned for `expiry_months`.
     *
     * One `expire` entry per member per calendar month (the ref is the period), so a
     * cron that runs twice in a day cannot write the same expiry twice.
     *
     * @return array{paws:int,members:int}
     */
    public static function expire_dormant(): array
    {
        $months = max(1, Zooboxi_Loyalty::opt_int('expiry_months'));
        $cutoff = gmdate('Y-m-d H:i:s', strtotime('-' . $months . ' months'));
        $period = (int) gmdate('Ym');

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT user_id, paws_balance FROM ' . Zooboxi_Loyalty_Schema::members()
            . ' WHERE paws_balance > 0 AND (last_earn_at IS NULL OR last_earn_at < %s) LIMIT 500',
            $cutoff
        ), ARRAY_A);

        $paws    = 0;
        $members = 0;
        foreach ((array) $rows as $row) {
            $user_id = (int) $row['user_id'];
            $balance = (int) $row['paws_balance'];
            if ($balance <= 0) {
                continue;
            }
            $written = self::add(
                $user_id,
                -$balance,
                'expire',
                'period',
                $period,
                Zooboxi_Loyalty::pick('انتهت صلاحية البصمات بعد خمول', 'Paws expired after dormancy')
            );
            if ($written > 0) {
                $paws += $balance;
                $members++;
            }
        }

        return ['paws' => $paws, 'members' => $members];
    }

    /* ══════════════════════════════════════════════════════════════
       METRICS (admin)
       ══════════════════════════════════════════════════════════════ */

    /**
     * Paws issued / spent / expired within a UTC date range.
     *
     * @return array{issued:int,spent:int,expired:int}
     */
    public static function totals_between(string $from_utc, string $to_utc): array
    {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT reason, COALESCE(SUM(delta), 0) AS total FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . ' WHERE created_at >= %s AND created_at < %s GROUP BY reason',
            $from_utc,
            $to_utc
        ), ARRAY_A);

        $out = ['issued' => 0, 'spent' => 0, 'expired' => 0];
        foreach ((array) $rows as $r) {
            $reason = (string) $r['reason'];
            $total  = (int) $r['total'];
            if ($reason === 'expire') {
                $out['expired'] += abs($total);
            } elseif ($total > 0) {
                $out['issued'] += $total;
            } else {
                $out['spent'] += abs($total);
            }
        }
        return $out;
    }
}
