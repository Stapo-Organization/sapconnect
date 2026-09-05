<?php
/**
 * Zooboxi_Loyalty_Rewards — the catalogue, the grants, and the gift line.
 *
 * THE RULE THAT SHAPES EVERYTHING: no public discount. A reward is a GIFT (a real
 * cart line priced at zero) or a SERVICE (a waived delivery fee), never a percentage
 * off — so the wholesale price the whole group depends on is never touched.
 *
 * A gift is deliberately a normal cart line, not a coupon:
 *   • stock decrements the way it does for a sale, so we can never gift air;
 *   • it appears on the picking list and travels the existing SAP path untouched;
 *   • the «🎁 هدية · » prefix makes it self-explanatory to the branch and to SAP.
 * Its price is forced to zero on `woocommerce_before_calculate_totals` and its quantity
 * is pinned at one — a customer cannot turn one gift into ten by editing the stepper.
 *
 * A claim lives in the WooCommerce SESSION, not in the grant alone: the basket is where
 * the customer decides, and abandoning the basket must return the grant unharmed.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Rewards
{
    public const KINDS = ['gift_product', 'express_free', 'free_delivery', 'paws'];

    /** Kinds that waive a fee rather than adding a line. */
    public const SERVICE_KINDS = ['express_free', 'free_delivery'];

    public const STATES = ['pending', 'active', 'claimed', 'redeemed', 'expired', 'cancelled'];

    /** Per-request memo of the resolved session claims: user_id => grant rows. */
    private static array $claims_memo = [];

    /** Set while an order is being settled, so emptying the cart does not un-claim. */
    private static bool $settling = false;

    /* ══════════════════════════════════════════════════════════════
       CATALOGUE
       ══════════════════════════════════════════════════════════════ */

    /** @return array<int,array> reward rows, owner-sorted */
    public static function catalog(bool $active_only = true): array
    {
        global $wpdb;
        $sql = 'SELECT * FROM ' . Zooboxi_Loyalty_Schema::rewards();
        if ($active_only) {
            $sql .= ' WHERE is_active = 1';
        }
        $sql .= ' ORDER BY sort ASC, id ASC';

        $rows = $wpdb->get_results($sql, ARRAY_A);
        return is_array($rows) ? $rows : [];
    }

    public static function reward(int $id): ?array
    {
        if ($id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::rewards() . ' WHERE id = %d LIMIT 1',
            $id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** Look a reward up by its stable key (`express_free`, `small_gift`, …). */
    public static function reward_by_key(string $key): ?array
    {
        if ($key === '') {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::rewards() . ' WHERE reward_key = %s LIMIT 1',
            $key
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** The product behind a gift reward (variation wins), or null. */
    public static function reward_product(array $reward): ?\WC_Product
    {
        $id = (int) ($reward['variation_id'] ?? 0) ?: (int) ($reward['product_id'] ?? 0);
        if ($id <= 0 || !function_exists('wc_get_product')) {
            return null;
        }
        $product = wc_get_product($id);
        return $product instanceof \WC_Product ? $product : null;
    }

    /**
     * Can this member redeem this reward right now, and if not, why?
     *
     * @return array{ok:bool,code:string,ar:string,en:string}
     */
    public static function redeemability(array $reward, int $user_id): array
    {
        $ok = static fn () => ['ok' => true, 'code' => '', 'ar' => '', 'en' => ''];
        $no = static fn (string $code, string $ar, string $en) => ['ok' => false, 'code' => $code, 'ar' => $ar, 'en' => $en];

        if ((int) $reward['is_active'] !== 1) {
            return $no('reward_unavailable', 'هذه المكافأة غير متاحة حالياً', 'This reward is not available right now.');
        }
        if ((int) $reward['paws_cost'] <= 0) {
            return $no('not_redeemable', 'تُمنح هذه المكافأة ولا تُستبدل بالبصمات', 'This reward is granted, not bought with paws.');
        }
        if ((string) $reward['kind'] === 'gift_product' && self::reward_product($reward) === null) {
            return $no('reward_unavailable', 'لم يُربط منتج بهذه الهدية بعد', 'No product is attached to this gift yet.');
        }

        $min_tier = (string) $reward['min_tier'];
        if ($min_tier !== '' && !Zooboxi_Loyalty_Tiers::at_least(Zooboxi_Loyalty_Members::tier_key($user_id), $min_tier)) {
            $name = Zooboxi_Loyalty_Tiers::name($min_tier);
            return $no(
                'tier_required',
                sprintf('هذه المكافأة لمستوى %s فأعلى', $name),
                sprintf('This reward needs the %s level or above.', $name)
            );
        }

        $cap = $reward['monthly_cap'] === null ? null : (int) $reward['monthly_cap'];
        if ($cap !== null && $cap > 0 && self::granted_this_month((int) $reward['id']) >= $cap) {
            return $no('reward_unavailable', 'نفد عدد هذه المكافأة لهذا الشهر', 'This reward is sold out for this month.');
        }

        if (Zooboxi_Loyalty_Ledger::balance($user_id) < (int) $reward['paws_cost']) {
            return $no('insufficient_paws', 'بصماتك لا تكفي بعد', 'You do not have enough paws yet.');
        }

        return $ok();
    }

    /** How many grants of this reward were issued in the current calendar month? */
    public static function granted_this_month(int $reward_id): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::grants()
            . " WHERE reward_id = %d AND state <> 'cancelled' AND created_at >= %s",
            $reward_id,
            gmdate('Y-m-01 00:00:00')
        ));
    }

    /* ══════════════════════════════════════════════════════════════
       GRANTS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Issue a grant.
     *
     * `$activates_on_order` parks it as `pending`: the prize of a scratch card is real
     * only once that order is delivered. Everything else starts `active` with its clock
     * already running.
     *
     * @return int grant id, 0 on failure
     */
    public static function grant(int $user_id, int $reward_id, string $source, int $source_ref = 0, ?int $activates_on_order = null): int
    {
        if ($user_id <= 0 || $reward_id <= 0) {
            return 0;
        }
        $reward = self::reward($reward_id);
        if ($reward === null) {
            return 0;
        }

        Zooboxi_Loyalty_Members::ensure($user_id);

        $now     = Zooboxi_Loyalty::now();
        $pending = $activates_on_order !== null && $activates_on_order > 0;

        global $wpdb;
        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::grants(), [
            'user_id'            => $user_id,
            'reward_id'          => $reward_id,
            'source'             => mb_substr($source, 0, 16),
            'source_ref'         => max(0, $source_ref),
            'state'              => $pending ? 'pending' : 'active',
            'activates_on_order' => $pending ? $activates_on_order : null,
            'expires_at'         => $pending ? null : self::expiry_from($reward, $now),
            'created_at'         => $now,
            'updated_at'         => $now,
        ], ['%d', '%d', '%s', '%d', '%s', '%d', '%s', '%s', '%s']);

        return $ok ? (int) $wpdb->insert_id : 0;
    }

    private static function expiry_from(array $reward, string $now): string
    {
        $days = max(1, (int) $reward['validity_days']);
        return gmdate('Y-m-d H:i:s', strtotime($now . ' UTC') + $days * DAY_IN_SECONDS);
    }

    public static function find_grant(int $grant_id, int $user_id = 0): ?array
    {
        if ($grant_id <= 0) {
            return null;
        }
        global $wpdb;
        $sql = 'SELECT * FROM ' . Zooboxi_Loyalty_Schema::grants() . ' WHERE id = %d';
        $args = [$grant_id];
        if ($user_id > 0) {
            $sql .= ' AND user_id = %d';
            $args[] = $user_id;
        }
        $row = $wpdb->get_row($wpdb->prepare($sql . ' LIMIT 1', $args), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** @param string[] $states */
    public static function grants_for(int $user_id, array $states = ['pending', 'active', 'claimed'], int $limit = 50): array
    {
        if ($user_id <= 0 || empty($states)) {
            return [];
        }
        global $wpdb;
        $placeholders = implode(',', array_fill(0, count($states), '%s'));
        $args         = array_merge([$user_id], $states, [$limit]);

        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::grants()
            . ' WHERE user_id = %d AND state IN (' . $placeholders . ') ORDER BY id DESC LIMIT %d',
            $args
        ), ARRAY_A);

        return is_array($rows) ? $rows : [];
    }

    public static function set_state(int $grant_id, string $state, array $extra = []): bool
    {
        if ($grant_id <= 0 || !in_array($state, self::STATES, true)) {
            return false;
        }
        global $wpdb;
        $data = array_merge($extra, ['state' => $state, 'updated_at' => Zooboxi_Loyalty::now()]);
        return (bool) $wpdb->update(Zooboxi_Loyalty_Schema::grants(), $data, ['id' => $grant_id]);
    }

    /** `pending` → `active`, starting the validity clock (a scratch prize settling). */
    public static function activate(int $grant_id): bool
    {
        $grant = self::find_grant($grant_id);
        if ($grant === null || $grant['state'] !== 'pending') {
            return false;
        }
        $reward = self::reward((int) $grant['reward_id']);
        if ($reward === null) {
            return false;
        }
        return self::set_state($grant_id, 'active', [
            'expires_at' => self::expiry_from($reward, Zooboxi_Loyalty::now()),
        ]);
    }

    /** Every grant still waiting on an order that will never complete. */
    public static function cancel_pending_for_order(int $order_id): int
    {
        if ($order_id <= 0) {
            return 0;
        }
        global $wpdb;
        return (int) $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::grants()
            . " SET state = 'cancelled', updated_at = %s WHERE activates_on_order = %d AND state = 'pending'",
            Zooboxi_Loyalty::now(),
            $order_id
        ));
    }

    /**
     * Redeem a catalogue reward for paws.
     *
     * @return array{code:string,grant_id:int,ar:string,en:string}
     */
    public static function redeem(int $user_id, int $reward_id): array
    {
        $reward = self::reward($reward_id);
        if ($reward === null) {
            return ['code' => 'reward_unavailable', 'grant_id' => 0, 'ar' => 'هذه المكافأة غير موجودة', 'en' => 'That reward does not exist.'];
        }

        $check = self::redeemability($reward, $user_id);
        if (!$check['ok']) {
            return ['code' => $check['code'], 'grant_id' => 0, 'ar' => $check['ar'], 'en' => $check['en']];
        }

        $grant_id = self::grant($user_id, $reward_id, 'redeem', 0, null);
        if ($grant_id <= 0) {
            return ['code' => 'reward_unavailable', 'grant_id' => 0, 'ar' => 'تعذّر الاستبدال، حاول لاحقاً', 'en' => 'The redemption failed, please try again.'];
        }

        // Charge only AFTER the grant exists — a customer must never lose paws to a
        // grant that was not written.
        $cost    = (int) $reward['paws_cost'];
        $written = Zooboxi_Loyalty_Ledger::add(
            $user_id,
            -$cost,
            'redeem',
            'grant',
            $grant_id,
            Zooboxi_Loyalty::pick((string) $reward['title_ar'], (string) $reward['title_en'])
        );
        if ($written <= 0) {
            self::set_state($grant_id, 'cancelled');
            return ['code' => 'reward_unavailable', 'grant_id' => 0, 'ar' => 'تعذّر خصم البصمات', 'en' => 'The paws could not be deducted.'];
        }

        return ['code' => '', 'grant_id' => $grant_id, 'ar' => '', 'en' => ''];
    }

    /** Time-out grants past their expiry. Returns how many were closed. */
    public static function expire_grants(): int
    {
        global $wpdb;
        return (int) $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Loyalty_Schema::grants()
            . " SET state = 'expired', updated_at = %s"
            . " WHERE state IN ('active','claimed') AND expires_at IS NOT NULL AND expires_at < %s",
            Zooboxi_Loyalty::now(),
            Zooboxi_Loyalty::now()
        ));
    }

    /* ══════════════════════════════════════════════════════════════
       CLAIMS — the basket side
       ══════════════════════════════════════════════════════════════ */

    private static function session()
    {
        if (!Zooboxi_Loyalty::wc_ready() || !WC()->session) {
            return null;
        }
        return WC()->session;
    }

    /** Raw grant ids currently claimed into the basket. */
    private static function session_ids(): array
    {
        $session = self::session();
        if ($session === null) {
            return [];
        }
        $ids = $session->get(Zooboxi_Loyalty::SESSION_CLAIMS, []);
        return is_array($ids) ? array_values(array_unique(array_map('intval', $ids))) : [];
    }

    private static function write_session_ids(array $ids): void
    {
        $session = self::session();
        if ($session === null) {
            return;
        }
        $session->set(Zooboxi_Loyalty::SESSION_CLAIMS, array_values(array_unique(array_map('intval', $ids))));
        self::$claims_memo = [];
        // The fee filters memoise per request; a claim written mid-request (claim →
        // calculate_totals) must be visible to the very next filter call.
        Zooboxi_Loyalty_Tiers::forget_memo();
    }

    /** Is there a WooCommerce session to hold claims at all? */
    public static function has_session(): bool
    {
        return self::session() !== null;
    }

    /**
     * The grants actually claimed into THIS basket, revalidated.
     *
     * A grant that expired, was cancelled, or belongs to someone else is silently
     * dropped from the session on read — the basket can never quote a dead reward.
     *
     * @return array<int,array> grant rows
     */
    public static function session_claims(int $user_id): array
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return [];
        }
        if (isset(self::$claims_memo[$user_id])) {
            return self::$claims_memo[$user_id];
        }

        $ids = self::session_ids();
        if (empty($ids)) {
            return self::$claims_memo[$user_id] = [];
        }

        $live  = [];
        $keep  = [];
        $now   = Zooboxi_Loyalty::now();

        foreach ($ids as $id) {
            $grant = self::find_grant($id, $user_id);
            if ($grant === null || $grant['state'] !== 'claimed') {
                continue;
            }
            if (!empty($grant['expires_at']) && $grant['expires_at'] < $now) {
                self::set_state((int) $grant['id'], 'expired');
                continue;
            }
            $live[] = $grant;
            $keep[] = (int) $grant['id'];
        }

        if ($keep !== $ids) {
            self::write_session_ids($keep);
        }

        return self::$claims_memo[$user_id] = $live;
    }

    /** Is a claim of this reward kind live in the basket? (drives both fee filters) */
    public static function has_claim_of_kind(int $user_id, string $kind): bool
    {
        foreach (self::session_claims($user_id) as $grant) {
            $reward = self::reward((int) $grant['reward_id']);
            if ($reward !== null && (string) $reward['kind'] === $kind) {
                return true;
            }
        }
        return false;
    }

    /** Backwards-compatible shorthand used by the free-shipping filter. */
    public static function has_free_delivery_claim(int $user_id): bool
    {
        return self::has_claim_of_kind($user_id, 'free_delivery');
    }

    /**
     * Claim a grant into the basket.
     *
     * @return array{code:string,ar:string,en:string,notice_ar:string,notice_en:string}
     */
    public static function claim(int $user_id, int $grant_id): array
    {
        $fail = static fn (string $code, string $ar, string $en) => [
            'code' => $code, 'ar' => $ar, 'en' => $en, 'notice_ar' => '', 'notice_en' => '',
        ];

        $grant = self::find_grant($grant_id, $user_id);
        if ($grant === null) {
            return $fail('grant_not_active', 'هذه المكافأة غير موجودة', 'That reward is not available.');
        }
        if ($grant['state'] === 'claimed') {
            return $fail('already_claimed', 'هذه المكافأة مضافة لسلتك بالفعل', 'That reward is already in your cart.');
        }
        if ($grant['state'] !== 'active') {
            return $fail('grant_not_active', 'هذه المكافأة غير جاهزة للاستخدام', 'That reward is not ready to use.');
        }
        if (!empty($grant['expires_at']) && $grant['expires_at'] < Zooboxi_Loyalty::now()) {
            self::set_state($grant_id, 'expired');
            return $fail('grant_not_active', 'انتهت صلاحية هذه المكافأة', 'That reward has expired.');
        }

        $reward = self::reward((int) $grant['reward_id']);
        if ($reward === null) {
            return $fail('grant_not_active', 'هذه المكافأة غير متاحة', 'That reward is unavailable.');
        }

        $notice_ar = '';
        $notice_en = '';

        if ((string) $reward['kind'] === 'gift_product') {
            $product = self::reward_product($reward);
            if ($product === null || !$product->is_purchasable()) {
                return $fail('gift_unavailable', 'الهدية غير متاحة حالياً', 'The gift is unavailable right now.');
            }
            if (!self::gift_is_reachable($product)) {
                return $fail('gift_unavailable', 'الهدية غير متاحة في موقعك حالياً', 'The gift cannot reach your location right now.');
            }
            if (!self::add_gift_line($product, $grant_id)) {
                return $fail('gift_unavailable', 'تعذّر إضافة الهدية للسلة', 'The gift could not be added to your cart.');
            }
        } elseif ((string) $reward['kind'] === 'express_free' && !self::cart_has_express()) {
            // Honest about the limit: the waiver is real, it just has nothing to waive
            // unless this basket can actually go express.
            $notice_ar = 'تنطبق هذه المكافأة على التوصيل السريع فقط، وسلتك الحالية لا تصل بالتوصيل السريع.';
            $notice_en = 'This reward only applies to express delivery, and this basket cannot go express.';
        }

        self::set_state($grant_id, 'claimed', ['claimed_at' => Zooboxi_Loyalty::now()]);

        $ids   = self::session_ids();
        $ids[] = $grant_id;
        self::write_session_ids($ids);

        return ['code' => '', 'ar' => '', 'en' => '', 'notice_ar' => $notice_ar, 'notice_en' => $notice_en];
    }

    /** Release a claim: the grant returns to `active` and any gift line leaves the cart. */
    public static function unclaim(int $user_id, int $grant_id, bool $remove_line = true): array
    {
        $grant = self::find_grant($grant_id, $user_id);
        if ($grant === null) {
            return ['code' => 'grant_not_active', 'ar' => 'هذه المكافأة غير موجودة', 'en' => 'That reward is not available.'];
        }

        if ($remove_line) {
            self::remove_gift_line($grant_id);
        }

        if ($grant['state'] === 'claimed') {
            $expired = !empty($grant['expires_at']) && $grant['expires_at'] < Zooboxi_Loyalty::now();
            self::set_state($grant_id, $expired ? 'expired' : 'active', ['claimed_at' => null]);
        }

        self::write_session_ids(array_values(array_diff(self::session_ids(), [$grant_id])));

        return ['code' => '', 'ar' => '', 'en' => ''];
    }

    /* ══════════════════════════════════════════════════════════════
       THE GIFT LINE
       ══════════════════════════════════════════════════════════════ */

    /** Can this gift actually reach the customer? (same resolver the cart uses) */
    private static function gift_is_reachable(\WC_Product $product): bool
    {
        if (!class_exists('Zooboxi_Fulfillment')) {
            return true;
        }
        [$lat, $lng] = self::customer_latlng();
        if (!$lat || !$lng) {
            // No pin yet — do not block the reward on a location we were never given.
            return true;
        }
        try {
            $pid  = $product instanceof \WC_Product_Variation ? (int) $product->get_parent_id() : (int) $product->get_id();
            $plan = Zooboxi_Fulfillment::resolve($pid, 1, (float) $lat, (float) $lng);
            return (int) ($plan['reachable_total'] ?? 0) >= 1;
        } catch (\Throwable $e) {
            return true;
        }
    }

    /** Does this basket have an express shipment at all? (express_free has a scope) */
    private static function cart_has_express(): bool
    {
        if (!class_exists('Zooboxi_Smart_Shipments') || !Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return true;
        }
        [$lat, $lng] = self::customer_latlng();
        if (!$lat || !$lng) {
            return true;
        }
        try {
            $groups = Zooboxi_Smart_Shipments::build_tier_groups(WC()->cart->get_cart(), (float) $lat, (float) $lng);
            return isset($groups[Zooboxi_Delivery_Engine::TYPE_EXPRESS]);
        } catch (\Throwable $e) {
            return true;
        }
    }

    /** The customer's coordinates — the app's seeded jar first, then the WC session. */
    public static function customer_latlng(): array
    {
        if (class_exists('Zooboxi_V2_Bootstrap')) {
            [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
            if ($lat && $lng) {
                return [(float) $lat, (float) $lng];
            }
        }
        $session = self::session();
        if ($session !== null) {
            $lat = (float) $session->get('zooboxi_customer_lat', 0);
            $lng = (float) $session->get('zooboxi_customer_lng', 0);
            if ($lat && $lng) {
                return [$lat, $lng];
            }
        }
        return [0.0, 0.0];
    }

    /** Add the zero-price line. Quantity is always one — a gift is a gift. */
    private static function add_gift_line(\WC_Product $product, int $grant_id): bool
    {
        if (!Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return false;
        }
        if (self::find_gift_key($grant_id) !== '') {
            return true; // idempotent: the line is already there
        }

        $variation_id = $product instanceof \WC_Product_Variation ? (int) $product->get_id() : 0;
        $product_id   = $variation_id ? (int) $product->get_parent_id() : (int) $product->get_id();
        $variation    = $variation_id ? (array) $product->get_variation_attributes() : [];

        try {
            $key = WC()->cart->add_to_cart(
                $product_id,
                1,
                $variation_id,
                $variation,
                [Zooboxi_Loyalty::CART_GRANT_KEY => $grant_id]
            );
        } catch (\Throwable $e) {
            return false;
        }

        return (bool) $key;
    }

    /** The cart key of a gift line, '' when it is not in the basket. */
    public static function find_gift_key(int $grant_id): string
    {
        if (!Zooboxi_Loyalty::wc_ready() || !WC()->cart) {
            return '';
        }
        foreach (WC()->cart->get_cart() as $key => $item) {
            if ((int) ($item[Zooboxi_Loyalty::CART_GRANT_KEY] ?? 0) === $grant_id) {
                return (string) $key;
            }
        }
        return '';
    }

    private static function remove_gift_line(int $grant_id): void
    {
        $key = self::find_gift_key($grant_id);
        if ($key === '' || !WC()->cart) {
            return;
        }
        // Guard the removal hook against re-entering unclaim() for the same grant.
        self::$settling = true;
        WC()->cart->remove_cart_item($key);
        self::$settling = false;
    }

    /** Grant id carried by a cart line, 0 when the line is a normal purchase. */
    public static function line_grant_id(array $item): int
    {
        return (int) ($item[Zooboxi_Loyalty::CART_GRANT_KEY] ?? 0);
    }

    /** The visible name a gift wears everywhere: cart, order, picking list, SAP. */
    public static function gift_name(string $product_name): string
    {
        $prefix = '🎁 هدية · ';
        return strpos($product_name, $prefix) === 0 ? $product_name : $prefix . $product_name;
    }

    /* ══════════════════════════════════════════════════════════════
       SETTLEMENT (checkout)
       ══════════════════════════════════════════════════════════════ */

    public static function is_settling(): bool
    {
        return self::$settling;
    }

    /**
     * Turn every claim in the session into a redemption bound to this order, then
     * clear the basket's claim list. Called from `woocommerce_checkout_order_processed`.
     *
     * @return int number of grants redeemed
     */
    public static function settle_for_order(\WC_Order $order): int
    {
        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0) {
            return 0;
        }

        self::$settling = true;
        $count = 0;

        foreach (self::session_claims($user_id) as $grant) {
            $ok = self::set_state((int) $grant['id'], 'redeemed', [
                'redeemed_order_id' => (int) $order->get_id(),
            ]);
            if ($ok) {
                $count++;
            }
        }

        self::write_session_ids([]);
        self::$settling = false;

        return $count;
    }

    /** An order that never made it: its redeemed grants go back to the customer. */
    public static function restore_for_order(int $order_id): int
    {
        if ($order_id <= 0) {
            return 0;
        }
        global $wpdb;

        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::grants()
            . " WHERE redeemed_order_id = %d AND state = 'redeemed'",
            $order_id
        ), ARRAY_A);

        $now      = Zooboxi_Loyalty::now();
        $restored = 0;
        foreach ((array) $rows as $grant) {
            $expired = !empty($grant['expires_at']) && $grant['expires_at'] < $now;
            if (self::set_state((int) $grant['id'], $expired ? 'expired' : 'active', ['redeemed_order_id' => null, 'claimed_at' => null])) {
                $restored++;
            }
        }
        return $restored;
    }

    /* ══════════════════════════════════════════════════════════════
       DTOs
       ══════════════════════════════════════════════════════════════ */

    public static function reward_dto(array $reward, int $user_id = 0): array
    {
        $product = null;
        if ((string) $reward['kind'] === 'gift_product' && class_exists('Zooboxi_Product_DTO')) {
            $wc = self::reward_product($reward);
            if ($wc !== null) {
                $product = Zooboxi_Product_DTO::card($wc);
            }
        }

        $check = $user_id > 0
            ? self::redeemability($reward, $user_id)
            : ['ok' => false, 'code' => 'unauthorized', 'ar' => '', 'en' => ''];

        return [
            'id'            => (int) $reward['id'],
            'key'           => (string) $reward['reward_key'],
            'kind'          => (string) $reward['kind'],
            'title'         => Zooboxi_Loyalty::pick((string) $reward['title_ar'], (string) $reward['title_en']),
            'title_en'      => (string) $reward['title_en'],
            'description'   => Zooboxi_Loyalty::pick((string) $reward['desc_ar'], (string) $reward['desc_en']),
            'product'       => $product,
            'paws_cost'     => (int) $reward['paws_cost'],
            'value_sar'     => (float) $reward['value_sar'],
            'validity_days' => (int) $reward['validity_days'],
            'min_tier'      => (string) $reward['min_tier'],
            'redeemable'    => (bool) $check['ok'],
            'reason_ar'     => (string) $check['ar'],
            'reason_en'     => (string) $check['en'],
        ];
    }

    public static function grant_dto(array $grant, int $user_id = 0): array
    {
        $reward = self::reward((int) $grant['reward_id']);

        $activates = null;
        if (!empty($grant['activates_on_order'])) {
            $order = function_exists('wc_get_order') ? wc_get_order((int) $grant['activates_on_order']) : null;
            $activates = [
                'id'     => (int) $grant['activates_on_order'],
                'number' => $order instanceof \WC_Order ? (string) $order->get_order_number() : (string) $grant['activates_on_order'],
            ];
        }

        return [
            'id'                 => (int) $grant['id'],
            'reward'             => $reward ? self::reward_dto($reward, $user_id) : null,
            'source'             => (string) $grant['source'],
            'state'              => (string) $grant['state'],
            'expires_at'         => Zooboxi_Loyalty::iso($grant['expires_at'] ?? null),
            'activates_on_order' => $activates,
            'claimed'            => (string) $grant['state'] === 'claimed',
        ];
    }

    /** @return array<int,array> */
    public static function grant_dtos(array $grants, int $user_id = 0): array
    {
        $out = [];
        foreach ($grants as $grant) {
            $out[] = self::grant_dto($grant, $user_id);
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       CART BLOCK (the app's cart DTO)
       ══════════════════════════════════════════════════════════════ */

    /**
     * `loyalty` on the cart DTO: what this basket will earn, what is claimed into it,
     * and WHY delivery/express is free (so the app can label its own badge honestly).
     */
    public static function cart_block($cart): array
    {
        $user_id = get_current_user_id();

        $paws_to_earn = 0;
        $rate         = Zooboxi_Loyalty::opt_float('points_per_riyal');
        if ($rate > 0 && $cart instanceof \WC_Cart) {
            $base = 0.0;
            foreach ($cart->get_cart() as $item) {
                if (self::line_grant_id($item) > 0) {
                    continue; // a gift never earns
                }
                $base += (float) ($item['line_total'] ?? 0);
            }
            $paws_to_earn = (int) floor($base * $rate);
        }

        return [
            'paws_to_earn'         => $paws_to_earn,
            'holdout'              => $user_id > 0 ? Zooboxi_Loyalty_Members::is_holdout($user_id) : false,
            'claims'               => $user_id > 0 ? self::grant_dtos(self::session_claims($user_id), $user_id) : [],
            'free_delivery_reason' => Zooboxi_Loyalty_Tiers::free_delivery_reason($user_id),
            'express_free_reason'  => Zooboxi_Loyalty_Tiers::express_free_reason($user_id),
            // Which subscriptions this basket delivers (Phase 2) — empty for a plain basket.
            'subscription_ids'     => ($user_id > 0 && class_exists('Zooboxi_Loyalty_Subscriptions'))
                ? Zooboxi_Loyalty_Subscriptions::cart_ids($user_id)
                : [],
        ];
    }
}
