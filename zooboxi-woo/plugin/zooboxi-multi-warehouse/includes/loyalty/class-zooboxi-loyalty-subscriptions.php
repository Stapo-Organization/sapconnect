<?php
/**
 * Zooboxi_Loyalty_Subscriptions — «وصّل لي كل شهر»، the soft subscription.
 *
 * SOFT on purpose: no card is stored and no order is placed by itself. A subscription
 * is a promise the STORE keeps — a date, a reminder before it, and a one-tap basket —
 * while the customer keeps every decision. Phase 3 adds the automatic order once the
 * saved-card flow in MyFatoorah is approved; the schedule below is what it will drive.
 *
 * What the subscription buys the customer (all service, never a discount):
 *   · free delivery on the subscription's own basket (`free_delivery_reason: subscription`)
 *   · +10% paws on that delivered order
 *   · a gift with every third delivery
 *
 * The "subscription basket" is recognised by a WC session flag written by `order_now()`
 * and consumed at checkout — the same mechanism the reward claims use — so the free
 * delivery cannot be obtained by merely owning a subscription and buying anything.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Subscriptions
{
    public const SESSION_KEY = 'zb_sub_cart';
    public const ORDER_META  = '_zb_subscription_ids';

    public const MIN_INTERVAL = 7;
    public const MAX_INTERVAL = 120;
    public const MAX_QTY      = 10;

    private static array $memo = [];

    /* ══════════════════════════════════════════════════════════════
       CONFIG
       ══════════════════════════════════════════════════════════════ */

    public static function enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('subscriptions_enabled', 'yes') === 'yes';
    }

    public static function max(): int
    {
        return max(1, Zooboxi_Loyalty::opt_int('max_subscriptions', 6));
    }

    public static function perks(): array
    {
        return [
            'free_delivery' => true,
            'bonus_pct'     => max(0, Zooboxi_Loyalty::opt_int('sub_bonus_pct', 10)),
            'gift_every'    => max(0, Zooboxi_Loyalty::opt_int('sub_gift_every', 3)),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    /** All non-cancelled subscriptions, soonest first. */
    public static function all(int $user_id): array
    {
        if ($user_id <= 0) {
            return [];
        }
        if (isset(self::$memo[$user_id])) {
            return self::$memo[$user_id];
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::subscriptions()
            . " WHERE user_id = %d AND state <> 'cancelled' ORDER BY next_at ASC, id ASC",
            $user_id
        ), ARRAY_A);
        return self::$memo[$user_id] = (is_array($rows) ? $rows : []);
    }

    public static function forget(int $user_id): void
    {
        unset(self::$memo[$user_id]);
    }

    public static function find(int $id, int $user_id): ?array
    {
        if ($id <= 0 || $user_id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::subscriptions() . ' WHERE id = %d AND user_id = %d LIMIT 1',
            $id,
            $user_id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** The subscription for one product line, in any state (the UNIQUE key). */
    public static function find_line(int $user_id, int $product_id, int $variation_id = 0): ?array
    {
        if ($user_id <= 0 || $product_id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::subscriptions()
            . ' WHERE user_id = %d AND product_id = %d AND variation_id = %d LIMIT 1',
            $user_id,
            $product_id,
            max(0, $variation_id)
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** The next active delivery, or null. */
    public static function next(int $user_id): ?array
    {
        foreach (self::all($user_id) as $row) {
            if ((string) $row['state'] === 'active') {
                return $row;
            }
        }
        return null;
    }

    public static function active_count(int $user_id): int
    {
        $n = 0;
        foreach (self::all($user_id) as $row) {
            if ((string) $row['state'] === 'active') {
                $n++;
            }
        }
        return $n;
    }

    /* ══════════════════════════════════════════════════════════════
       WRITE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Create (or revive a cancelled) subscription.
     *
     * @return array{row:?array,code:string,ar:string,en:string}
     */
    public static function create(int $user_id, array $input): array
    {
        $no = static fn (string $code, string $ar, string $en) => ['row' => null, 'code' => $code, 'ar' => $ar, 'en' => $en];

        if ($user_id <= 0 || !self::enabled()) {
            return $no('subscriptions_disabled', 'الاشتراك غير متاح حالياً', 'Subscriptions are not available right now.');
        }
        Zooboxi_Loyalty_Schema::maybe_install();
        Zooboxi_Loyalty_Members::ensure($user_id);

        $product_id   = absint($input['product_id'] ?? 0);
        $variation_id = absint($input['variation_id'] ?? 0);
        $product      = $product_id > 0 ? wc_get_product($variation_id ?: $product_id) : null;
        if (!($product instanceof \WC_Product) || !$product->is_purchasable()) {
            return $no('subscription_invalid', 'هذا المنتج لا يمكن الاشتراك فيه', 'This product cannot be subscribed to.');
        }
        if ($variation_id <= 0 && $product->is_type('variable')) {
            return $no('subscription_invalid', 'اختر حجم العبوة أولاً', 'Pick the pack size first.');
        }

        $existing = self::find_line($user_id, $product_id, $variation_id);
        if ($existing !== null && (string) $existing['state'] !== 'cancelled') {
            return $no('subscription_exists', 'أنت مشترك في هذا المنتج بالفعل', 'You already subscribe to this product.');
        }
        if ($existing === null && self::active_count($user_id) >= self::max()) {
            return $no('subscription_limit', sprintf('الحد الأقصى %d اشتراكات', self::max()), sprintf('You can keep up to %d subscriptions.', self::max()));
        }

        $qty = max(1, min(self::MAX_QTY, absint($input['qty'] ?? 1)));

        // Defaults from the supply gauge when it knows this product.
        $interval = absint($input['interval_days'] ?? 0);
        $next_at  = self::clean_date((string) ($input['next_at'] ?? ''));
        $pet_id   = absint($input['pet_id'] ?? 0);

        $line = class_exists('Zooboxi_Loyalty_Supply') ? Zooboxi_Loyalty_Supply::find($user_id, $product_id, $variation_id) : null;
        if ($line !== null) {
            if ($interval <= 0) {
                $interval = (int) round($qty * (float) $line['cycle_days']);
            }
            if ($next_at === null) {
                $next_at = gmdate('Y-m-d', max(time() + DAY_IN_SECONDS, (int) $line['runs_out_ts'] - 2 * DAY_IN_SECONDS));
            }
            if ($pet_id <= 0) {
                $pet_id = (int) $line['pet_id'];
            }
        }
        if ($interval <= 0) {
            $interval = 30;
        }
        $interval = max(self::MIN_INTERVAL, min(self::MAX_INTERVAL, $interval));
        if ($next_at === null) {
            $next_at = gmdate('Y-m-d', time() + $interval * DAY_IN_SECONDS);
        }
        if ($pet_id > 0 && Zooboxi_Loyalty_Pets::find($pet_id, $user_id) === null) {
            $pet_id = 0;
        }

        $now  = Zooboxi_Loyalty::now();
        global $wpdb;

        if ($existing !== null) {
            $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), [
                'pet_id'        => $pet_id ?: null,
                'qty'           => $qty,
                'interval_days' => $interval,
                'next_at'       => $next_at,
                'state'         => 'active',
                'reminder_for'  => null,
                'updated_at'    => $now,
            ], ['id' => (int) $existing['id']]);
            $id = (int) $existing['id'];
        } else {
            $wpdb->insert(Zooboxi_Loyalty_Schema::subscriptions(), [
                'user_id'       => $user_id,
                'pet_id'        => $pet_id ?: null,
                'product_id'    => $product_id,
                'variation_id'  => $variation_id,
                'qty'           => $qty,
                'interval_days' => $interval,
                'next_at'       => $next_at,
                'state'         => 'active',
                'deliveries'    => 0,
                'created_at'    => $now,
                'updated_at'    => $now,
            ]);
            $id = (int) $wpdb->insert_id;
        }

        self::forget($user_id);
        if (class_exists('Zooboxi_Loyalty_Supply')) {
            Zooboxi_Loyalty_Supply::flush($user_id);
        }
        return ['row' => self::find($id, $user_id), 'code' => '', 'ar' => '', 'en' => ''];
    }

    /** Edit quantity, cadence, next date, or pause/resume. */
    public static function update(int $user_id, int $id, array $input): array
    {
        $row = self::find($id, $user_id);
        if ($row === null || (string) $row['state'] === 'cancelled') {
            return ['row' => null, 'code' => 'subscription_not_found', 'ar' => 'الاشتراك غير موجود', 'en' => 'That subscription does not exist.'];
        }

        $data = [];
        if (isset($input['qty'])) {
            $data['qty'] = max(1, min(self::MAX_QTY, absint($input['qty'])));
        }
        if (isset($input['interval_days'])) {
            $data['interval_days'] = max(self::MIN_INTERVAL, min(self::MAX_INTERVAL, absint($input['interval_days'])));
        }
        if (isset($input['next_at'])) {
            $next = self::clean_date((string) $input['next_at']);
            if ($next === null || $next < gmdate('Y-m-d')) {
                return ['row' => null, 'code' => 'subscription_invalid', 'ar' => 'التاريخ غير صالح', 'en' => 'That date is not valid.'];
            }
            $data['next_at']      = $next;
            $data['reminder_for'] = null;
        }
        if (isset($input['state']) && in_array((string) $input['state'], ['active', 'paused'], true)) {
            $data['state'] = (string) $input['state'];
        }
        if (isset($input['pet_id'])) {
            $pet_id         = absint($input['pet_id']);
            $data['pet_id'] = ($pet_id > 0 && Zooboxi_Loyalty_Pets::find($pet_id, $user_id) !== null) ? $pet_id : null;
        }
        if (empty($data)) {
            return ['row' => $row, 'code' => '', 'ar' => '', 'en' => ''];
        }
        $data['updated_at'] = Zooboxi_Loyalty::now();

        global $wpdb;
        $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), $data, ['id' => $id, 'user_id' => $user_id]);
        self::forget($user_id);
        return ['row' => self::find($id, $user_id), 'code' => '', 'ar' => '', 'en' => ''];
    }

    /** Skip one delivery: the next date moves by one interval. */
    public static function skip(int $user_id, int $id): array
    {
        $row = self::find($id, $user_id);
        if ($row === null || (string) $row['state'] === 'cancelled') {
            return ['row' => null, 'code' => 'subscription_not_found', 'ar' => 'الاشتراك غير موجود', 'en' => 'That subscription does not exist.'];
        }
        $base = max(time(), (int) strtotime((string) $row['next_at'] . ' 00:00:00 UTC'));
        $next = gmdate('Y-m-d', $base + max(self::MIN_INTERVAL, (int) $row['interval_days']) * DAY_IN_SECONDS);

        global $wpdb;
        $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), [
            'next_at'      => $next,
            'reminder_for' => null,
            'updated_at'   => Zooboxi_Loyalty::now(),
        ], ['id' => $id, 'user_id' => $user_id]);
        self::forget($user_id);
        return ['row' => self::find($id, $user_id), 'code' => '', 'ar' => '', 'en' => ''];
    }

    public static function cancel(int $user_id, int $id): bool
    {
        $row = self::find($id, $user_id);
        if ($row === null) {
            return false;
        }
        global $wpdb;
        $ok = (bool) $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), [
            'state'      => 'cancelled',
            'updated_at' => Zooboxi_Loyalty::now(),
        ], ['id' => $id, 'user_id' => $user_id]);
        self::forget($user_id);
        if (class_exists('Zooboxi_Loyalty_Supply')) {
            Zooboxi_Loyalty_Supply::flush($user_id);
        }
        return $ok;
    }

    private static function clean_date(string $value): ?string
    {
        $value = trim($value);
        if ($value === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
            return null;
        }
        return strtotime($value . ' 00:00:00 UTC') ? $value : null;
    }

    /* ══════════════════════════════════════════════════════════════
       THE ONE-TAP BASKET
       ══════════════════════════════════════════════════════════════ */

    /**
     * Put the subscription's line in the (already booted) WooCommerce cart and flag the
     * session, so the checkout that follows is a subscription delivery.
     *
     * @return array{code:string,ar:string,en:string}
     */
    public static function order_now(int $user_id, int $id): array
    {
        $row = self::find($id, $user_id);
        if ($row === null || (string) $row['state'] === 'cancelled') {
            return ['code' => 'subscription_not_found', 'ar' => 'الاشتراك غير موجود', 'en' => 'That subscription does not exist.'];
        }
        if (!Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return ['code' => 'cart_unavailable', 'ar' => 'السلة غير متاحة حالياً', 'en' => 'The cart is unavailable right now.'];
        }

        $product_id   = (int) $row['product_id'];
        $variation_id = (int) $row['variation_id'];
        $qty          = max(1, (int) $row['qty']);

        // Already in the basket? Top it up to the subscription quantity, never past it.
        $have_key = '';
        foreach (WC()->cart->get_cart() as $key => $item) {
            if ((int) ($item['product_id'] ?? 0) === $product_id
                && (int) ($item['variation_id'] ?? 0) === $variation_id
                && Zooboxi_Loyalty_Rewards::line_grant_id($item) <= 0) {
                $have_key = (string) $key;
                break;
            }
        }

        try {
            if ($have_key !== '') {
                $current = (int) (WC()->cart->get_cart()[$have_key]['quantity'] ?? 0);
                if ($current < $qty) {
                    WC()->cart->set_quantity($have_key, $qty, false);
                }
                $ok = true;
            } else {
                $variation = [];
                if ($variation_id > 0) {
                    $v = wc_get_product($variation_id);
                    if ($v instanceof \WC_Product_Variation) {
                        foreach ($v->get_variation_attributes() as $name => $value) {
                            $variation[$name] = (string) $value;
                        }
                    }
                }
                $ok = (bool) WC()->cart->add_to_cart($product_id, $qty, $variation_id, $variation);
            }
        } catch (\Throwable $e) {
            $ok = false;
        }
        if (!$ok) {
            return ['code' => 'add_failed', 'ar' => 'تعذّر إضافة المنتج للسلة', 'en' => 'The product could not be added to the cart.'];
        }

        self::flag_session($id);
        WC()->cart->calculate_totals();
        return ['code' => '', 'ar' => '', 'en' => ''];
    }

    private static function session()
    {
        if (!Zooboxi_Loyalty::wc_ready() || !WC()->session) {
            return null;
        }
        return WC()->session;
    }

    private static function flag_session(int $id): void
    {
        $session = self::session();
        if ($session === null) {
            return;
        }
        $ids   = $session->get(self::SESSION_KEY, []);
        $ids   = is_array($ids) ? array_map('intval', $ids) : [];
        $ids[] = $id;
        $session->set(self::SESSION_KEY, array_values(array_unique($ids)));
        Zooboxi_Loyalty_Tiers::forget_memo();
    }

    /** @return int[] subscription ids flagged into the current basket */
    public static function session_ids(): array
    {
        $session = self::session();
        if ($session === null) {
            return [];
        }
        $ids = $session->get(self::SESSION_KEY, []);
        return is_array($ids) ? array_values(array_unique(array_map('intval', $ids))) : [];
    }

    public static function clear_session(): void
    {
        $session = self::session();
        if ($session !== null) {
            $session->set(self::SESSION_KEY, []);
        }
    }

    /**
     * Is the current basket a subscription delivery? True only while a flagged
     * subscription's product is actually in the cart — drop the line and the perk goes.
     */
    public static function free_delivery_active(int $user_id): bool
    {
        if ($user_id <= 0 || !self::enabled()) {
            return false;
        }
        $ids = self::session_ids();
        if (empty($ids) || !Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return false;
        }
        foreach ($ids as $id) {
            $row = self::find($id, $user_id);
            if ($row === null || (string) $row['state'] === 'cancelled') {
                continue;
            }
            foreach (WC()->cart->get_cart() as $item) {
                if ((int) ($item['product_id'] ?? 0) === (int) $row['product_id']
                    && ((int) $row['variation_id'] <= 0 || (int) ($item['variation_id'] ?? 0) === (int) $row['variation_id'])) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Ids whose product is in the basket right now (for the cart DTO). */
    public static function cart_ids(int $user_id): array
    {
        if ($user_id <= 0 || !self::enabled() || !Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return [];
        }
        $out = [];
        foreach (self::session_ids() as $id) {
            $row = self::find($id, $user_id);
            if ($row === null || (string) $row['state'] === 'cancelled') {
                continue;
            }
            foreach (WC()->cart->get_cart() as $item) {
                if ((int) ($item['product_id'] ?? 0) === (int) $row['product_id']) {
                    $out[] = $id;
                    break;
                }
            }
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       ORDER LIFECYCLE
       ══════════════════════════════════════════════════════════════ */

    /** At checkout: bind the flagged subscriptions to the order that carries them. */
    public static function bind_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0 || !self::enabled()) {
            return 0;
        }
        $ids = self::session_ids();
        if (empty($ids)) {
            return 0;
        }

        $in_order = [];
        foreach ($order->get_items() as $item) {
            if ($item instanceof \WC_Order_Item_Product) {
                $in_order[(int) $item->get_product_id()] = true;
            }
        }

        $bound = [];
        global $wpdb;
        foreach ($ids as $id) {
            $row = self::find($id, $user_id);
            if ($row === null || (string) $row['state'] === 'cancelled' || !isset($in_order[(int) $row['product_id']])) {
                continue;
            }
            $bound[] = $id;
            $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), [
                'last_order_id' => (int) $order->get_id(),
                'updated_at'    => Zooboxi_Loyalty::now(),
            ], ['id' => $id]);
        }

        self::clear_session();
        self::forget($user_id);

        if (!empty($bound)) {
            $order->update_meta_data(self::ORDER_META, wp_json_encode($bound));
            $order->save_meta_data();
        }
        return count($bound);
    }

    /** @return int[] */
    public static function order_ids(\WC_Order $order): array
    {
        $raw = (string) $order->get_meta(self::ORDER_META);
        if ($raw === '') {
            return [];
        }
        $ids = json_decode($raw, true);
        return is_array($ids) ? array_values(array_filter(array_map('intval', $ids))) : [];
    }

    public static function is_subscription_order(\WC_Order $order): bool
    {
        return !empty(self::order_ids($order));
    }

    /**
     * On delivery: count the delivery, pay the bonus, move the date, maybe give the
     * gift. Any active subscription whose product was in the order (even a manual one)
     * has its clock reset — the customer restocked, that is what matters.
     */
    public static function settle_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0 || !self::enabled()) {
            return 0;
        }
        $bound = self::order_ids($order);
        $subs  = self::all($user_id);
        if (empty($subs)) {
            return 0;
        }

        $in_order = [];
        foreach ($order->get_items() as $item) {
            if ($item instanceof \WC_Order_Item_Product) {
                $in_order[(int) $item->get_product_id()] = true;
            }
        }

        $now     = Zooboxi_Loyalty::now();
        $perks   = self::perks();
        $touched = 0;
        global $wpdb;

        foreach ($subs as $row) {
            if ((string) $row['state'] === 'cancelled' || !isset($in_order[(int) $row['product_id']])) {
                continue;
            }
            $id       = (int) $row['id'];
            $is_bound = in_array($id, $bound, true);
            $next     = gmdate('Y-m-d', time() + max(self::MIN_INTERVAL, (int) $row['interval_days']) * DAY_IN_SECONDS);
            $data     = ['next_at' => $next, 'reminder_for' => null, 'updated_at' => $now];

            if ($is_bound) {
                // Deliveries count once per order: the ledger's UNIQUE key is the lock.
                $paid = Zooboxi_Loyalty_Ledger::has_entry($user_id, 'sub_bonus', 'order', (int) $order->get_id());
                if (!$paid) {
                    $data['deliveries'] = (int) $row['deliveries'] + 1;
                    $deliveries         = $data['deliveries'];

                    $bonus = (int) floor(Zooboxi_Loyalty_Ledger::order_paws($order) * $perks['bonus_pct'] / 100);
                    Zooboxi_Loyalty_Ledger::add(
                        $user_id,
                        max(1, $bonus),
                        'sub_bonus',
                        'order',
                        (int) $order->get_id(),
                        Zooboxi_Loyalty::pick('توصيلة اشتراك — بصمات إضافية', 'Subscription delivery — bonus paws')
                    );

                    if ($perks['gift_every'] > 0 && $deliveries % $perks['gift_every'] === 0) {
                        self::give_gift($user_id, $id, $deliveries);
                    }
                }
            }

            $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), $data, ['id' => $id]);
            $touched++;
        }

        self::forget($user_id);
        return $touched;
    }

    /** The every-Nth-delivery gift: the catalogue reward if attached, else paws. */
    private static function give_gift(int $user_id, int $sub_id, int $deliveries): void
    {
        $reward = Zooboxi_Loyalty_Rewards::reward_by_key('sub_gift');
        if ($reward !== null && (int) $reward['is_active'] === 1 && Zooboxi_Loyalty_Rewards::reward_product($reward) !== null) {
            Zooboxi_Loyalty_Rewards::grant($user_id, (int) $reward['id'], 'subscription', $sub_id, null);
            return;
        }
        Zooboxi_Loyalty_Ledger::add(
            $user_id,
            max(0, Zooboxi_Loyalty::opt_int('sub_gift_paws', 150)),
            'sub_bonus',
            'sub_gift',
            $sub_id * 1000 + $deliveries,
            Zooboxi_Loyalty::pick('هدية الاشتراك — التوصيلة رقم ' . $deliveries, 'Subscription gift — delivery #' . $deliveries)
        );
    }

    /** Cancelled after delivery: the bonus comes back out (the gift grant is restored elsewhere). */
    public static function reverse_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        $id      = (int) $order->get_id();
        $paid    = Zooboxi_Loyalty_Ledger::entry_delta($user_id, 'sub_bonus', 'order', $id);
        if ($user_id <= 0 || $paid <= 0) {
            return 0;
        }
        $written = Zooboxi_Loyalty_Ledger::add(
            $user_id,
            -$paid,
            'reverse',
            'sub_bonus',
            $id,
            Zooboxi_Loyalty::pick('عكس بصمات توصيلة اشتراك', 'Reversed: subscription bonus')
        );
        return $written > 0 ? $paid : 0;
    }

    /* ══════════════════════════════════════════════════════════════
       DAILY — the reminder
       ══════════════════════════════════════════════════════════════ */

    /**
     * Every active subscription due within `sub_reminder_days` that has not been
     * reminded for THIS date gets one notice. Returns how many were sent.
     */
    public static function remind_due(): int
    {
        if (!self::enabled()) {
            return 0;
        }
        $days  = max(0, Zooboxi_Loyalty::opt_int('sub_reminder_days', 3));
        $limit = gmdate('Y-m-d', time() + $days * DAY_IN_SECONDS);

        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::subscriptions()
            . " WHERE state = 'active' AND next_at IS NOT NULL AND next_at <= %s"
            . ' AND (reminder_for IS NULL OR reminder_for <> next_at) ORDER BY next_at ASC LIMIT 300',
            $limit
        ), ARRAY_A);

        $sent = 0;
        foreach ((array) $rows as $row) {
            $wpdb->update(Zooboxi_Loyalty_Schema::subscriptions(), [
                'reminder_for' => (string) $row['next_at'],
                'updated_at'   => Zooboxi_Loyalty::now(),
            ], ['id' => (int) $row['id']]);

            if (class_exists('Zooboxi_Loyalty_Mail')) {
                $product = wc_get_product((int) ($row['variation_id'] ?: $row['product_id']));
                $name    = $product instanceof \WC_Product ? (string) $product->get_name() : '';
                $pet     = Zooboxi_Loyalty_Pets::first_name((int) $row['user_id']);
                $when    = (string) $row['next_at'];
                Zooboxi_Loyalty_Mail::send((int) $row['user_id'], 'subscription', 'sub:' . $row['id'] . ':' . $when, [
                    'subject_ar' => sprintf('توصيلة %s قرّبت', $pet),
                    'subject_en' => sprintf('%s\'s delivery is coming up', $pet),
                    'lines_ar'   => [
                        sprintf('موعد توصيلة الاشتراك لـ%s يوم %s.', $pet, $when),
                        sprintf('المنتج: %s × %d.', $name, (int) $row['qty']),
                        'افتح التطبيق واطلب بضغطة واحدة — التوصيل مجاني على توصيلات الاشتراك، أو عدّل الموعد إن كان عندك كفاية.',
                    ],
                    'lines_en'   => [
                        sprintf('%s\'s subscription delivery is due on %s.', $pet, $when),
                        sprintf('Product: %s × %d.', $name, (int) $row['qty']),
                        'Open the app and order with one tap — delivery is free on subscription deliveries — or move the date if you still have enough.',
                    ],
                    'cta_ar'     => 'افتح اشتراكاتي',
                    'cta_en'     => 'Open my subscriptions',
                    'cta_url'    => home_url('/my-account/'),
                ]);
            }
            $sent++;
        }
        return $sent;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function dto(array $row, int $user_id = 0): array
    {
        $card = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::card((int) $row['product_id']) : null;

        $pet = null;
        if (!empty($row['pet_id']) && $user_id > 0) {
            $p = Zooboxi_Loyalty_Pets::find((int) $row['pet_id'], $user_id);
            if ($p !== null) {
                $pet = ['id' => (int) $p['id'], 'name' => (string) $p['name'], 'species' => (string) $p['species']];
            }
        }

        $next_ts = !empty($row['next_at']) ? (int) strtotime((string) $row['next_at'] . ' 00:00:00 UTC') : 0;
        $today   = (int) strtotime(gmdate('Y-m-d') . ' 00:00:00 UTC');
        $perks   = self::perks();
        $every   = (int) $perks['gift_every'];

        $variation_label = '';
        if ((int) $row['variation_id'] > 0) {
            $v = wc_get_product((int) $row['variation_id']);
            if ($v instanceof \WC_Product_Variation) {
                $variation_label = wp_strip_all_tags(wc_get_formatted_variation($v, true, false, false));
            }
        }

        return [
            'id'              => (int) $row['id'],
            'product'         => $card,
            'variation_id'    => (int) $row['variation_id'],
            'variation_label' => $variation_label,
            'qty'             => (int) $row['qty'],
            'interval_days'   => (int) $row['interval_days'],
            'next_at'         => $next_ts > 0 ? gmdate('Y-m-d', $next_ts) : null,
            'days_until'      => $next_ts > 0 ? (int) round(($next_ts - $today) / DAY_IN_SECONDS) : null,
            'state'           => (string) $row['state'],
            'deliveries'      => (int) $row['deliveries'],
            'next_gift_in'    => $every > 0 ? ($every - ((int) $row['deliveries'] % $every)) : null,
            'pet'             => $pet,
            'perks'           => $perks,
        ];
    }

    /** @return array<int,array> */
    public static function dtos(int $user_id): array
    {
        $out = [];
        foreach (self::all($user_id) as $row) {
            $dto = self::dto($row, $user_id);
            if ($dto['product'] !== null) {
                $out[] = $dto;
            }
        }
        return $out;
    }

    public static function summary_block(int $user_id): array
    {
        $next = self::next($user_id);
        return [
            'active' => self::active_count($user_id),
            'next'   => $next !== null ? self::dto($next, $user_id) : null,
        ];
    }
}
