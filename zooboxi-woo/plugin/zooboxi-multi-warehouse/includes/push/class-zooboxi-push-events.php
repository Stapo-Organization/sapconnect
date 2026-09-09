<?php
/**
 * What the store actually tells a customer about.
 *
 * One rule decides everything in this file: a notification must be worth the
 * interruption. An order moving through its stages is; a status the customer
 * cannot act on or feel (a payment record being reconciled) is not. So the
 * list of statuses that speak is a short, explicit allow-list, not "every
 * transition WooCommerce emits".
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Events
{
    public static function boot(): void
    {
        // Priority 20: after the v2 bootstrap has stamped its timeline meta, so
        // a customer opening the app from the notification sees the same state
        // the notification described.
        add_action('woocommerce_order_status_changed', [self::class, 'on_order_status'], 20, 4);
        // The courier's own milestones, between the order statuses: assigned,
        // and at the door. (Pickup and delivery already ARE order statuses.)
        add_action('zooboxi_mrsool_status_changed', [self::class, 'on_mrsool_status'], 10, 4);
        // The iOS lock screen follows both.
        add_action('woocommerce_order_status_changed', [self::class, 'live_activity_on_status'], 30, 4);
        add_action('zooboxi_mrsool_status_changed', [self::class, 'live_activity_on_mrsool'], 20, 4);
        // Once a day: whose food is about to run out.
        if (class_exists('Zooboxi_Loyalty')) {
            add_action(Zooboxi_Loyalty::CRON_DAILY, [self::class, 'on_daily_reorder'], 20);
        }
    }

    /**
     * The statuses a person is waiting to hear, in their own words.
     *
     * `zb-ready` and `zb-out-for-delivery` are the store's own express states;
     * the rest are WooCommerce's. Anything absent from this map is silent.
     */
    private static function copy(string $status, \WC_Order $order): ?array
    {
        $number = $order->get_order_number();

        switch ($status) {
            case 'processing':
                return [
                    'ar' => ['استلمنا طلبك', 'طلبك رقم ' . $number . ' قيد التجهيز الآن.'],
                    'en' => ['Order received', 'Order ' . $number . ' is being prepared.'],
                ];
            case 'zb-ready':
                return [
                    'ar' => ['طلبك جاهز', 'جهّزنا طلبك ' . $number . ' وهو بانتظار المندوب.'],
                    'en' => ['Your order is ready', 'Order ' . $number . ' is packed and waiting for the driver.'],
                ];
            case 'zb-out-for-delivery':
                return [
                    'ar' => ['طلبك في الطريق إليك', 'المندوب انطلق بطلبك ' . $number . '.'],
                    'en' => ['On its way', 'Your order ' . $number . ' is out for delivery.'],
                ];
            case 'completed':
                return [
                    'ar' => ['وصل طلبك', 'تم تسليم طلبك ' . $number . ' — نتمنى أن ينال إعجاب صديقك.'],
                    'en' => ['Delivered', 'Order ' . $number . ' has been delivered.'],
                ];
            case 'cancelled':
                return [
                    'ar' => ['أُلغي طلبك', 'أُلغي طلبك ' . $number . '. إذا لم يكن هذا طلبك، تواصل معنا.'],
                    'en' => ['Order cancelled', 'Order ' . $number . ' was cancelled.'],
                ];
            default:
                return null;
        }
    }

    public static function on_order_status($order_id, $from, $to, $order = null): void
    {
        try {
            if (!class_exists('Zooboxi_Push') || !Zooboxi_Push::is_enabled()) {
                return;
            }
            $to = sanitize_key((string) $to);
            if ($to === '' || $to === (string) $from) {
                return;
            }
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order((int) $order_id);
            }
            if (!($order instanceof \WC_Order)) {
                return;
            }

            $copy = self::copy($to, $order);
            if ($copy === null) {
                return;
            }

            $customer_id = (int) $order->get_customer_id();
            // A guest checkout still has a phone in its hand: the app registers
            // its device id even before there is an account, and the order
            // carries the one it was placed from.
            $guest_id = (string) $order->get_meta('_zb_guest_id');
            $devices  = Zooboxi_Push::devices_for($customer_id, $guest_id);
            if (!$devices) {
                return;
            }

            $route = '/orders/' . $order->get_id();
            foreach ($devices as $device) {
                $locale = str_starts_with((string) ($device['locale'] ?? 'ar'), 'en') ? 'en' : 'ar';
                [$title, $body] = $copy[$locale];
                Zooboxi_Push::send_to_devices(
                    [$device],
                    'orders',
                    $title,
                    $body,
                    $route,
                    ['order_id' => (string) $order->get_id(), 'status' => $to]
                );
            }
        } catch (\Throwable $e) {
            // An order transition is never allowed to fail because a phone
            // could not be reached.
            error_log('[Zooboxi push] order status notification failed: ' . $e->getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       THE COURIER'S OWN MILESTONES
       ══════════════════════════════════════════════════════════════ */

    /**
     * Two moments the order status does not carry: a rider took the job, and
     * the rider is at the door. Everything else the courier does is already an
     * order status (out for delivery, completed) and is pushed from there.
     */
    public static function on_mrsool_status($order, string $status, string $previous, string $courier = ''): void
    {
        try {
            if (!($order instanceof \WC_Order) || !class_exists('Zooboxi_Push') || !Zooboxi_Push::is_enabled()) {
                return;
            }
            $copy = self::mrsool_copy($status, $order, $courier);
            if ($copy === null) {
                return;
            }
            // Mrsool can re-announce a status; the customer should not be told
            // twice — unless it is genuinely a different rider this time.
            $flag = '_zb_push_mrsool_' . strtolower($status) . ($courier !== '' ? '_' . substr(md5($courier), 0, 8) : '');
            if ((string) $order->get_meta($flag) !== '') {
                return;
            }
            $order->update_meta_data($flag, current_time('mysql'));
            $order->save_meta_data();

            $devices = Zooboxi_Push::devices_for((int) $order->get_customer_id(), (string) $order->get_meta('_zb_guest_id'));
            $route   = '/orders/' . $order->get_id();
            foreach ($devices as $device) {
                $locale = str_starts_with((string) ($device['locale'] ?? 'ar'), 'en') ? 'en' : 'ar';
                [$title, $body] = $copy[$locale];
                Zooboxi_Push::send_to_devices(
                    [$device],
                    'orders',
                    $title,
                    $body,
                    $route,
                    ['order_id' => (string) $order->get_id(), 'mrsool_status' => $status]
                );
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] mrsool notification failed: ' . $e->getMessage());
        }
    }

    private static function mrsool_copy(string $status, \WC_Order $order, string $courier): ?array
    {
        $number = $order->get_order_number();
        $name   = trim($courier) !== '' ? trim($courier) : null;

        switch ($status) {
            case 'COURIER_ASSIGNED':
                return [
                    'ar' => [
                        $name ? 'مندوبك ' . $name . ' في الطريق للفرع' : 'تم تعيين مندوبك',
                        'طلبك ' . $number . ' سيكون معه خلال دقائق.',
                    ],
                    'en' => [
                        $name ? $name . ' is your courier' : 'A courier took your order',
                        'Order ' . $number . ' will be with them in minutes.',
                    ],
                ];
            case 'DROPOFF_ARRIVED':
                return [
                    'ar' => ['مندوبك عند بابك', 'طلبك ' . $number . ' وصل — المندوب بانتظارك.'],
                    'en' => ['Your courier is at the door', 'Order ' . $number . ' is here.'],
                ];
            default:
                return null;
        }
    }

    /* ══════════════════════════════════════════════════════════════
       THE LOCK SCREEN (iOS Live Activity)
       ══════════════════════════════════════════════════════════════ */

    public static function live_activity_on_status($order_id, $from, $to, $order = null): void
    {
        try {
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order((int) $order_id);
            }
            if (!($order instanceof \WC_Order)) {
                return;
            }
            $to = sanitize_key((string) $to);
            $ending = in_array($to, ['completed', 'cancelled', 'refunded', 'failed'], true);
            self::live_activity_push($order, $ending ? 'end' : 'update');
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] live activity (status) failed: ' . $e->getMessage());
        }
    }

    public static function live_activity_on_mrsool($order, string $status, string $previous, string $courier = ''): void
    {
        try {
            if ($order instanceof \WC_Order) {
                $ending = in_array($status, ['DELIVERED', 'PARTIALLY_DELIVERED', 'RETURN', 'CANCELED', 'EXPIRED'], true);
                self::live_activity_push($order, $ending ? 'end' : 'update');
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] live activity (mrsool) failed: ' . $e->getMessage());
        }
    }

    /**
     * The state the lock screen shows, built from what the store knows. The
     * app fills in the minutes while it is open; from here the courier's name
     * and phase are the honest maximum.
     */
    private static function live_activity_push(\WC_Order $order, string $event): void
    {
        if (!class_exists('Zooboxi_Push') || !Zooboxi_Push::is_enabled()) {
            return;
        }
        $activity = (string) $order->get_meta('_zb_la_token');
        if ($activity === '') {
            return;
        }

        $state = self::live_activity_state($order);

        // The phone that started the activity first; if its FCM token has
        // rotated since, every iOS device this customer still holds. One of
        // them owns the activity token and will take the update.
        $candidates = [];
        $stored = (string) $order->get_meta('_zb_la_device');
        if ($stored !== '') {
            $candidates[] = $stored;
        }
        foreach (Zooboxi_Push::devices_for((int) $order->get_customer_id(), (string) $order->get_meta('_zb_guest_id')) as $device) {
            if (($device['platform'] ?? '') === 'ios' && !in_array($device['token'], $candidates, true)) {
                $candidates[] = (string) $device['token'];
            }
        }

        $sent = false;
        foreach ($candidates as $token) {
            if (Zooboxi_Push::send_live_activity($token, $activity, $state, $event)) {
                $sent = true;
                break;
            }
        }

        if ($event === 'end') {
            // Whatever happened, this activity is over; forget the tokens.
            $order->delete_meta_data('_zb_la_token');
            $order->delete_meta_data('_zb_la_device');
            $order->save_meta_data();
        }
        if (!$sent) {
            error_log('[Zooboxi push] live activity not delivered for #' . $order->get_id());
        }
    }

    /**
     * Mirrors the Swift `ZooboxiOrderAttributes.ContentState` exactly. Keys the
     * extension does not declare are dropped by iOS without a word, so this is
     * the one place the two sides have to agree.
     */
    public static function live_activity_state(\WC_Order $order): array
    {
        $status = (string) $order->get_meta('_mrsool_status');
        $wc     = (string) $order->get_status();

        [$phase, $progress] = self::phase_of($wc, $status);
        $courier = (string) $order->get_meta('_mrsool_courier_name');

        return [
            // The plugin's own ContentState requires this field; without it the
            // app can no longer enumerate (and so end) its own activity.
            'appGroupId' => 'group.com.zooboxi.app',
            'phase'      => $phase,
            'headline'   => self::headline_for($phase, $status, $courier, 'ar'),
            'headlineEn' => self::headline_for($phase, $status, $courier, 'en'),
            'courier'    => $courier,
            'progress'   => $progress,
            'etaMinutes' => 0,
            'updatedAt'  => time(),
        ];
    }

    /** @return array{0:string,1:float} */
    private static function phase_of(string $wc, string $mrsool): array
    {
        if (in_array($wc, ['completed'], true) || in_array($mrsool, ['DELIVERED', 'PARTIALLY_DELIVERED'], true)) {
            return ['delivered', 1.0];
        }
        if (in_array($wc, ['cancelled', 'refunded', 'failed'], true) || in_array($mrsool, ['RETURN', 'CANCELED', 'EXPIRED'], true)) {
            return ['failed', 1.0];
        }
        return match ($mrsool) {
            'COURIER_PENDING'                                            => ['searching', 0.4],
            'COURIER_ASSIGNED', 'COURIER_REASSIGNED', 'PICKUP_ARRIVED', 'COLLECTING' => ['assigned', 0.6],
            'CONFIRMED_PICKUP', 'WAITING_FOR_DELIVERY', 'DELIVERING'    => ['in_transit', 0.85],
            'DROPOFF_ARRIVED'                                            => ['in_transit', 0.95],
            default => $wc === 'zb-ready' ? ['ready', 0.3] : ['preparing', 0.15],
        };
    }

    private static function headline_for(string $phase, string $status, string $courier, string $lang): string
    {
        $ar = $lang === 'ar';
        if ($status === 'DROPOFF_ARRIVED') {
            return $ar ? 'مندوبك عند بابك' : 'Your courier is at the door';
        }
        return match ($phase) {
            'preparing'  => $ar ? 'جارٍ تجهيز طلبك' : 'Preparing your order',
            'ready'      => $ar ? 'طلبك جاهز للتوصيل' : 'Your order is ready to go',
            'searching'  => $ar ? 'جارٍ تحديد مندوب توصيل لطلبك' : 'Finding a courier for your order',
            'assigned'   => $ar ? 'مندوبك في طريقه للفرع' : 'Your courier is heading to the branch',
            'in_transit' => $ar ? 'مندوبك في الطريق إليك' : 'Your courier is on the way to you',
            'delivered'  => $ar ? 'تم تسليم طلبك' : 'Your order was delivered',
            'failed'     => $ar ? 'تعذّر التوصيل' : 'Delivery could not be completed',
            default      => '',
        };
    }

    /* ══════════════════════════════════════════════════════════════
       ONCE A DAY — whose food is running out
       ══════════════════════════════════════════════════════════════ */

    /**
     * The one message a pet store can send that no grocery app can: «طعام
     * أوريو يخلص بعد ثلاثة أيام». Sent to people who carry a phone with the
     * app on it, about a line the food gauge says is inside its window, at most
     * once a week per product — a reminder that repeats daily is a nag.
     */
    public static function on_daily_reorder(): int
    {
        if (!class_exists('Zooboxi_Push') || !Zooboxi_Push::is_enabled()
            || !class_exists('Zooboxi_Loyalty_Supply') || !Zooboxi_Loyalty_Supply::enabled()) {
            return 0;
        }

        global $wpdb;

        // A slice of the audience per run, advancing a cursor, so a store with
        // thousands of phones never spends a whole cron tick — or hits
        // max_execution_time halfway through and repeats the first half daily.
        $batch  = 300;
        $offset = (int) get_option('zooboxi_push_reorder_cursor', 0);
        $users  = $wpdb->get_col($wpdb->prepare(
            'SELECT DISTINCT user_id FROM ' . Zooboxi_Push::table()
            . ' WHERE user_id > 0 AND enabled = 1 ORDER BY user_id LIMIT %d OFFSET %d',
            $batch,
            $offset
        ));
        update_option('zooboxi_push_reorder_cursor', count($users) < $batch ? 0 : $offset + $batch, false);

        $sent = 0;
        foreach ((array) $users as $uid) {
            $uid = (int) $uid;
            try {
                $sent += self::reorder_nudge_for($uid);
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] reorder nudge failed for user ' . $uid . ': ' . $e->getMessage());
            }
        }
        return $sent;
    }

    private static function reorder_nudge_for(int $uid): int
    {
        $rows = Zooboxi_Loyalty_Supply::items($uid);
        if (!$rows) {
            return 0;
        }

        // The single soonest line. One message, not a list.
        $pick = null;
        $pick_state = null;
        foreach ($rows as $row) {
            $state = Zooboxi_Loyalty_Supply::state_of($row);
            if (!in_array($state['status'], ['soon', 'due'], true) || $state['days_left'] > 3) {
                continue;
            }
            if ($pick === null || $state['days_left'] < $pick_state['days_left']) {
                $pick = $row;
                $pick_state = $state;
            }
        }
        if ($pick === null) {
            return 0;
        }

        $pid  = (int) $pick['product_id'];
        $flag = '_zb_push_reorder_' . $pid;
        $last = (int) get_user_meta($uid, $flag, true);
        if ($last > 0 && $last > time() - 7 * DAY_IN_SECONDS) {
            return 0;
        }

        $product = wc_get_product($pid);
        if (!$product) {
            return 0;
        }
        $pet = null;
        if ((int) ($pick['pet_id'] ?? 0) > 0 && class_exists('Zooboxi_Loyalty_Pets')) {
            $pet = Zooboxi_Loyalty_Pets::find((int) $pick['pet_id'], $uid);
        }
        $who   = $pet ? (string) $pet['name'] : '';
        $days  = max(0, (int) $pick_state['days_left']);
        $name  = wp_strip_all_tags($product->get_name());

        // Promise two hours only to someone the branch has actually reached
        // before: their last order was express. Everyone else is told to
        // order, not told a delivery time the store may not be able to keep.
        $express = self::last_order_was_express($uid);

        $copy = [
            'ar' => [
                $days > 0
                    ? ($who !== '' ? 'طعام ' . $who . ' يكفي ' . $days . ' أيام' : 'يخلص خلال ' . $days . ' أيام: ' . $name)
                    : ($who !== '' ? 'خلص طعام ' . $who : 'خلص: ' . $name),
                $express ? 'اطلبه الآن إكسبريس ويوصلك خلال ساعتين.' : 'اطلبه الآن من زوبوكسي قبل أن ينفد.',
            ],
            'en' => [
                $days > 0
                    ? ($who !== '' ? $who . "'s food lasts " . $days . ' more days' : 'Running out in ' . $days . ' days: ' . $name)
                    : ($who !== '' ? $who . "'s food has run out" : 'Run out: ' . $name),
                $express ? 'Order it now on Express and it arrives within two hours.' : 'Order it now on Zooboxi before it runs out.',
            ],
        ];

        $sent = 0;
        foreach (Zooboxi_Push::devices_for($uid) as $device) {
            $locale = str_starts_with((string) ($device['locale'] ?? 'ar'), 'en') ? 'en' : 'ar';
            [$title, $body] = $copy[$locale];
            $sent += Zooboxi_Push::send_to_devices(
                [$device],
                'reorder',
                $title,
                $body,
                '/family/supply',
                ['product_id' => (string) $pid]
            );
        }
        if ($sent > 0) {
            update_user_meta($uid, $flag, time());
        }
        return $sent;
    }

    /** Whether this customer's most recent order rode the two-hour shelf. */
    private static function last_order_was_express(int $uid): bool
    {
        $orders = wc_get_orders([
            'customer_id' => $uid,
            'limit'       => 1,
            'orderby'     => 'date',
            'order'       => 'DESC',
            'status'      => ['completed', 'processing', 'zb-ready', 'zb-out-for-delivery'],
        ]);
        $last = $orders[0] ?? null;
        return $last instanceof \WC_Order && (string) $last->get_meta('_zooboxi_delivery_type') === 'express';
    }
}
