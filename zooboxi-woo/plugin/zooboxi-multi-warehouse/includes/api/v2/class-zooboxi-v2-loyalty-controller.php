<?php
/**
 * Zooboxi_V2_Loyalty_Controller — «عائلة زوبوكسي» over `zooboxi/v2`.
 *
 * EVERY route here is bearer-only and `private, no-store`: a loyalty balance, a pet's
 * birth date and a sealed prize are personal, and none of them may sit in a shared
 * cache. The 401 comes from Zooboxi_V2_Bootstrap::unauthorized() so the app gets the
 * same envelope it already knows how to react to (open the OTP sheet).
 *
 * The summary is the app's home screen for the program and is therefore the one route
 * with a query budget: member row, tier (cached), pets, missions, grants, scratch — six
 * reads, no order query unless the tier cache went stale.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Loyalty_Controller
{
    private const LEDGER_PER_PAGE = 25;

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/loyalty/summary', 'GET', [$this, 'summary']);
        Zooboxi_V2_Bootstrap::route('/loyalty/ledger', 'GET', [$this, 'ledger']);
        Zooboxi_V2_Bootstrap::route('/loyalty/rewards', 'GET', [$this, 'rewards']);
        Zooboxi_V2_Bootstrap::route('/loyalty/rewards/(?P<id>\d+)/redeem', 'POST', [$this, 'redeem']);
        Zooboxi_V2_Bootstrap::route('/loyalty/grants/(?P<id>\d+)/claim', 'POST', [$this, 'claim']);
        Zooboxi_V2_Bootstrap::route('/loyalty/grants/(?P<id>\d+)/claim', 'DELETE', [$this, 'unclaim']);
        Zooboxi_V2_Bootstrap::route('/loyalty/missions', 'GET', [$this, 'missions']);
        Zooboxi_V2_Bootstrap::route('/loyalty/scratch', 'GET', [$this, 'scratch']);
        Zooboxi_V2_Bootstrap::route('/loyalty/scratch/(?P<id>\d+)/reveal', 'POST', [$this, 'reveal']);

        Zooboxi_V2_Bootstrap::route('/pets', 'GET', [$this, 'pets']);
        Zooboxi_V2_Bootstrap::route('/pets', 'POST', [$this, 'create_pet']);
        Zooboxi_V2_Bootstrap::route('/pets/(?P<id>\d+)', 'PATCH,PUT', [$this, 'update_pet']);
        Zooboxi_V2_Bootstrap::route('/pets/(?P<id>\d+)', 'DELETE', [$this, 'delete_pet']);

        // ── Phase 2 «العادة» ──
        Zooboxi_V2_Bootstrap::route('/loyalty/supply', 'GET', [$this, 'supply']);
        Zooboxi_V2_Bootstrap::route('/loyalty/supply/(?P<id>\d+)/out', 'POST', [$this, 'supply_out']);
        Zooboxi_V2_Bootstrap::route('/loyalty/supply/(?P<id>\d+)/snooze', 'POST', [$this, 'supply_snooze']);

        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions', 'GET', [$this, 'subscriptions']);
        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions', 'POST', [$this, 'create_subscription']);
        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions/(?P<id>\d+)', 'PATCH,PUT', [$this, 'update_subscription']);
        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions/(?P<id>\d+)', 'DELETE', [$this, 'delete_subscription']);
        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions/(?P<id>\d+)/skip', 'POST', [$this, 'skip_subscription']);
        Zooboxi_V2_Bootstrap::route('/loyalty/subscriptions/(?P<id>\d+)/order-now', 'POST', [$this, 'order_now']);

        Zooboxi_V2_Bootstrap::route('/loyalty/referral', 'GET', [$this, 'referral']);
        Zooboxi_V2_Bootstrap::route('/loyalty/referral/apply', 'POST', [$this, 'apply_referral']);

        Zooboxi_V2_Bootstrap::route('/loyalty/stamps', 'GET', [$this, 'stamps']);
    }

    /* ══════════════════════════════════════════════════════════════
       GUARD
       ══════════════════════════════════════════════════════════════ */

    /**
     * Every route starts here: authenticate, make sure the tables exist (the first
     * request after an scp deploy may be this one), and register the member.
     *
     * @return int user id, or 0 when the caller must be refused
     */
    private function member(): int
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return 0;
        }
        Zooboxi_Loyalty_Schema::maybe_install();
        Zooboxi_Loyalty_Members::ensure($user_id);
        return $user_id;
    }

    private function disabled(): \WP_REST_Response
    {
        return Zooboxi_V2_Bootstrap::fail(
            'loyalty_disabled',
            __('برنامج عائلة زوبوكسي غير مفعّل حالياً', 'zooboxi'),
            'The Zooboxi Family program is not enabled right now.',
            503
        );
    }

    /* ══════════════════════════════════════════════════════════════
       GET /loyalty/summary
       ══════════════════════════════════════════════════════════════ */

    public function summary(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $holdout  = Zooboxi_Loyalty_Members::is_holdout($user_id);
        $missions = $holdout ? [] : Zooboxi_Loyalty_Missions::for_user($user_id);
        $grants   = Zooboxi_Loyalty_Rewards::grants_for($user_id, ['active', 'claimed']);
        $cards    = $holdout ? [] : Zooboxi_Loyalty_Scratch::recent_for_user($user_id);

        $active_missions = 0;
        $done_missions   = 0;
        foreach ($missions as $row) {
            if ((string) $row['state'] === 'active') {
                $active_missions++;
            } elseif (in_array((string) $row['state'], ['completed', 'rewarded'], true)) {
                $done_missions++;
            }
        }

        $sealed = [];
        foreach ($cards as $card) {
            if ((string) $card['state'] !== 'sealed') {
                continue;
            }
            $order    = wc_get_order((int) $card['order_id']);
            $sealed[] = [
                'id'           => (int) $card['id'],
                'order_id'     => (int) $card['order_id'],
                'order_number' => $order instanceof \WC_Order ? (string) $order->get_order_number() : (string) $card['order_id'],
            ];
        }

        $history = Zooboxi_Loyalty_Missions::history($user_id);
        $pending = $this->pending_orders($user_id);
        $habit   = $this->habit_blocks($user_id, $missions, $holdout);

        return Zooboxi_V2_Bootstrap::ok($habit + [
            'member' => Zooboxi_Loyalty_Members::dto($user_id),
            'paws'   => [
                'balance'    => Zooboxi_Loyalty_Ledger::balance($user_id),
                // Revealed prizes still waiting on a delivery. In-flight order paws are
                // listed per order below so the app can say WHICH order is on its way.
                'pending'    => $holdout ? 0 : Zooboxi_Loyalty_Scratch::pending_paws($user_id),
                'expires_at' => $this->paws_expiry($user_id),
            ],
            'pending_orders' => $pending,
            'tier'     => Zooboxi_Loyalty_Tiers::dto($user_id),
            'missions' => [
                'period'    => Zooboxi_Loyalty::period(),
                'active'    => $active_missions,
                'completed' => $done_missions,
                // The summary stays light: suggested products are fetched by /missions.
                'items'     => Zooboxi_Loyalty_Missions::dtos($missions, $user_id, false),
            ],
            'rewards' => [
                'active_count'   => count($grants),
                'sealed_scratch' => $sealed,
            ],
            'pets'     => Zooboxi_Loyalty_Pets::dtos($user_id),
            'counters' => [
                'orders_total' => (int) ($history['orders'] ?? 0),
                'orders_app'   => (int) ($history['app_orders'] ?? 0),
            ],
        ]);
    }

    /**
     * The Phase 2 blocks of the summary: the supply gauge, subscriptions, moments, the
     * referral card, brand stamps, and the dated nudge list. Each block is isolated so a
     * bug in one can never blank the hub.
     */
    private function habit_blocks(int $user_id, array $missions, bool $holdout): array
    {
        $out = [
            'supply'        => ['items' => [], 'due_count' => 0, 'total' => 0, 'window' => ['before' => 7, 'after' => 3]],
            'subscriptions' => ['active' => 0, 'next' => null],
            'moments'       => ['birthday' => null],
            'referral'      => null,
            'stamps'        => [],
            'nudges'        => [],
        ];
        $supply_rows = [];
        $subs        = [];
        $birthday    = null;

        try {
            if (class_exists('Zooboxi_Loyalty_Supply') && Zooboxi_Loyalty_Supply::enabled()) {
                $supply_rows   = Zooboxi_Loyalty_Supply::items($user_id);
                $out['supply'] = Zooboxi_Loyalty_Supply::summary_block($user_id);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary supply failed: ' . $e->getMessage());
        }
        try {
            if (class_exists('Zooboxi_Loyalty_Subscriptions') && Zooboxi_Loyalty_Subscriptions::enabled()) {
                $subs                 = Zooboxi_Loyalty_Subscriptions::all($user_id);
                $out['subscriptions'] = Zooboxi_Loyalty_Subscriptions::summary_block($user_id);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary subscriptions failed: ' . $e->getMessage());
        }
        try {
            if (class_exists('Zooboxi_Loyalty_Moments')) {
                $birthday                   = Zooboxi_Loyalty_Moments::birthday_block($user_id);
                $out['moments']['birthday'] = $birthday;
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary moments failed: ' . $e->getMessage());
        }
        try {
            if (class_exists('Zooboxi_Loyalty_Referrals')) {
                $out['referral'] = Zooboxi_Loyalty_Referrals::summary_block($user_id);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary referral failed: ' . $e->getMessage());
        }
        try {
            if (class_exists('Zooboxi_Loyalty_Stamps')) {
                $out['stamps'] = Zooboxi_Loyalty_Stamps::wallet($user_id);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary stamps failed: ' . $e->getMessage());
        }
        try {
            if (class_exists('Zooboxi_Loyalty_Moments')) {
                $risk          = Zooboxi_Loyalty_Moments::tier_risk($user_id);
                $out['nudges'] = Zooboxi_Loyalty_Moments::nudges($user_id, $supply_rows, $subs, $birthday, $risk, $holdout ? [] : $missions);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] summary nudges failed: ' . $e->getMessage());
        }
        return $out;
    }

    /**
     * Orders placed but not yet delivered, newest first, with the paws each will pay.
     *
     * The whole program settles on delivery; a customer who has just placed their
     * first order sees nothing land and needs to be told, per order, that it is on
     * its way — not left to wonder whether the program is broken.
     *
     * @return array<int,array{id:int,number:string,paws:int,is_app:bool,created_at:?string}>
     */
    private function pending_orders(int $user_id): array
    {
        if (!function_exists('wc_get_orders')) {
            return [];
        }
        try {
            $orders = wc_get_orders([
                'customer_id' => $user_id,
                'status'      => ['pending', 'on-hold', 'processing'],
                'limit'       => 5,
                'orderby'     => 'date',
                'order'       => 'DESC',
                'date_after'  => gmdate('Y-m-d', time() - 60 * DAY_IN_SECONDS),
            ]);
        } catch (\Throwable $e) {
            return [];
        }

        $out = [];
        foreach ($orders as $order) {
            if (!$order instanceof \WC_Order) {
                continue;
            }
            $created = $order->get_date_created();
            $out[] = [
                'id'         => (int) $order->get_id(),
                'number'     => (string) $order->get_order_number(),
                'paws'       => Zooboxi_Loyalty_Ledger::order_paws($order),
                'is_app'     => (string) $order->get_meta('_zooboxi_app_order') !== '',
                'created_at' => $created ? $created->date('c') : null,
            ];
        }
        return $out;
    }

    /** When the current balance would lapse if the customer never earned again. */
    private function paws_expiry(int $user_id): ?string
    {
        $row = Zooboxi_Loyalty_Members::get($user_id);
        if ($row === null || (int) $row['paws_balance'] <= 0) {
            return null;
        }
        $from = !empty($row['last_earn_at']) ? (string) $row['last_earn_at'] : (string) $row['joined_at'];
        $ts   = strtotime($from . ' UTC');
        if (!$ts) {
            return null;
        }
        $months = max(1, Zooboxi_Loyalty::opt_int('expiry_months'));
        return gmdate('Y-m-d\TH:i:s\Z', strtotime('+' . $months . ' months', $ts));
    }

    /* ══════════════════════════════════════════════════════════════
       GET /loyalty/ledger
       ══════════════════════════════════════════════════════════════ */

    public function ledger(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $page = max(1, (int) $request->get_param('page'));
        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Loyalty_Ledger::page($user_id, $page, self::LEDGER_PER_PAGE));
    }

    /* ══════════════════════════════════════════════════════════════
       GET /loyalty/rewards + redeem
       ══════════════════════════════════════════════════════════════ */

    public function rewards(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $catalog = [];
        foreach (Zooboxi_Loyalty_Rewards::catalog(true) as $reward) {
            $catalog[] = Zooboxi_Loyalty_Rewards::reward_dto($reward, $user_id);
        }

        $grants = Zooboxi_Loyalty_Rewards::grants_for($user_id, ['pending', 'active', 'claimed']);

        return Zooboxi_V2_Bootstrap::ok([
            'catalog'     => $catalog,
            'grants'      => Zooboxi_Loyalty_Rewards::grant_dtos($grants, $user_id),
            'paws_balance' => Zooboxi_Loyalty_Ledger::balance($user_id),
        ]);
    }

    public function redeem(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $reward_id = absint($request->get_param('id'));
        $result    = Zooboxi_Loyalty_Rewards::redeem($user_id, $reward_id);

        if ($result['code'] !== '') {
            $status = $result['code'] === 'tier_required' ? 403 : 409;
            return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], $status);
        }

        $grant = Zooboxi_Loyalty_Rewards::find_grant((int) $result['grant_id'], $user_id);

        return Zooboxi_V2_Bootstrap::ok([
            'grant'        => $grant ? Zooboxi_Loyalty_Rewards::grant_dto($grant, $user_id) : null,
            'paws_balance' => Zooboxi_Loyalty_Ledger::balance($user_id),
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       Claim / un-claim into the basket
       ══════════════════════════════════════════════════════════════ */

    public function claim(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }

        $grant_id = absint($request->get_param('id'));
        $result   = Zooboxi_Loyalty_Rewards::claim($user_id, $grant_id);

        if ($result['code'] !== '') {
            return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], 409);
        }

        WC()->cart->calculate_totals();
        $grant = Zooboxi_Loyalty_Rewards::find_grant($grant_id, $user_id);
        $dto   = $grant ? Zooboxi_Loyalty_Rewards::grant_dto($grant, $user_id) : null;

        if ($dto !== null && $result['notice_ar'] !== '') {
            $dto['notice_ar'] = $result['notice_ar'];
            $dto['notice_en'] = $result['notice_en'];
            $dto['notice']    = Zooboxi_V2_Bootstrap::pick($result['notice_ar'], $result['notice_en']);
        }

        return Zooboxi_V2_Bootstrap::ok([
            'cart'  => Zooboxi_V2_Cart_Controller::cart_dto(),
            'grant' => $dto,
        ]);
    }

    public function unclaim(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }

        $grant_id = absint($request->get_param('id'));
        $result   = Zooboxi_Loyalty_Rewards::unclaim($user_id, $grant_id);

        if ($result['code'] !== '') {
            return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], 409);
        }

        WC()->cart->calculate_totals();
        $grant = Zooboxi_Loyalty_Rewards::find_grant($grant_id, $user_id);

        return Zooboxi_V2_Bootstrap::ok([
            'cart'  => Zooboxi_V2_Cart_Controller::cart_dto(),
            'grant' => $grant ? Zooboxi_Loyalty_Rewards::grant_dto($grant, $user_id) : null,
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /loyalty/missions
       ══════════════════════════════════════════════════════════════ */

    public function missions(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $rows = Zooboxi_Loyalty_Missions::for_user($user_id);

        return Zooboxi_V2_Bootstrap::ok([
            'period' => Zooboxi_Loyalty::period(),
            'items'  => Zooboxi_Loyalty_Missions::dtos($rows, $user_id, true),
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       Scratch
       ══════════════════════════════════════════════════════════════ */

    public function scratch(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        if (Zooboxi_Loyalty_Members::is_holdout($user_id)) {
            return Zooboxi_V2_Bootstrap::ok(['cards' => []]);
        }

        $cards = Zooboxi_Loyalty_Scratch::recent_for_user($user_id);
        return Zooboxi_V2_Bootstrap::ok(['cards' => Zooboxi_Loyalty_Scratch::dtos($cards, $user_id)]);
    }

    public function reveal(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $card_id = absint($request->get_param('id'));
        $card    = Zooboxi_Loyalty_Scratch::reveal($card_id, $user_id);

        if ($card === null) {
            return Zooboxi_V2_Bootstrap::fail('scratch_not_found', __('البطاقة غير موجودة', 'zooboxi'), 'That card does not exist.', 404);
        }

        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Loyalty_Scratch::dto($card, $user_id));
    }

    /* ══════════════════════════════════════════════════════════════
       Pets
       ══════════════════════════════════════════════════════════════ */

    public function pets(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        return Zooboxi_V2_Bootstrap::ok([
            'pets' => Zooboxi_Loyalty_Pets::dtos($user_id),
            'max'  => Zooboxi_Loyalty_Pets::max(),
        ]);
    }

    public function create_pet(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $result = Zooboxi_Loyalty_Pets::create($user_id, $this->pet_input($request));
        $error  = $this->pet_error($result);
        if ($error !== null) {
            return $error;
        }

        return Zooboxi_V2_Bootstrap::ok([
            'pet'         => Zooboxi_Loyalty_Pets::dto($result['pet']),
            'pets'        => Zooboxi_Loyalty_Pets::dtos($user_id),
            'paws_earned' => (int) $result['paws'],
        ]);
    }

    public function update_pet(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $result = Zooboxi_Loyalty_Pets::update($user_id, absint($request->get_param('id')), $this->pet_input($request));
        $error  = $this->pet_error($result);
        if ($error !== null) {
            return $error;
        }

        return Zooboxi_V2_Bootstrap::ok([
            'pet'         => Zooboxi_Loyalty_Pets::dto($result['pet']),
            'pets'        => Zooboxi_Loyalty_Pets::dtos($user_id),
            'paws_earned' => (int) $result['paws'],
        ]);
    }

    public function delete_pet(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return $this->disabled();
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        if (!Zooboxi_Loyalty_Pets::delete($user_id, absint($request->get_param('id')))) {
            return Zooboxi_V2_Bootstrap::fail('pet_not_found', __('هذا الحيوان غير موجود', 'zooboxi'), 'That pet does not exist.', 404);
        }

        return Zooboxi_V2_Bootstrap::ok(['pets' => Zooboxi_Loyalty_Pets::dtos($user_id)]);
    }

    /* ══════════════════════════════════════════════════════════════
       Phase 2 — Supply gauge
       ══════════════════════════════════════════════════════════════ */

    private function guard(): array
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return [0, $this->disabled()];
        }
        $user_id = $this->member();
        if ($user_id <= 0) {
            return [0, Zooboxi_V2_Bootstrap::unauthorized()];
        }
        return [$user_id, null];
    }

    public function supply(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        if (!Zooboxi_Loyalty_Supply::enabled()) {
            return Zooboxi_V2_Bootstrap::ok(['items' => [], 'window' => Zooboxi_Loyalty_Supply::window(), 'on_time_pct' => 0, 'enabled' => false]);
        }
        $rows = Zooboxi_Loyalty_Supply::items($user_id, (bool) $request->get_param('fresh'));
        return Zooboxi_V2_Bootstrap::ok([
            'items'       => Zooboxi_Loyalty_Supply::dtos($rows, $user_id),
            'window'      => Zooboxi_Loyalty_Supply::window(),
            'on_time_pct' => Zooboxi_Loyalty::opt_int('on_time_pct'),
            'enabled'     => true,
        ]);
    }

    public function supply_out(\WP_REST_Request $request): \WP_REST_Response
    {
        return $this->supply_event($request, 'out');
    }

    public function supply_snooze(\WP_REST_Request $request): \WP_REST_Response
    {
        return $this->supply_event($request, 'snooze');
    }

    private function supply_event(\WP_REST_Request $request, string $kind): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        $product_id   = absint($request->get_param('id'));
        $variation_id = absint($request->get_param('variation_id'));
        $row = $kind === 'out'
            ? Zooboxi_Loyalty_Supply::mark_out($user_id, $product_id, $variation_id)
            : Zooboxi_Loyalty_Supply::snooze($user_id, $product_id, $variation_id, max(1, absint($request->get_param('days')) ?: 7));

        if ($row === null) {
            return Zooboxi_V2_Bootstrap::fail('supply_not_found', __('هذا المنتج ليس في عدّادك', 'zooboxi'), 'That product is not on your gauge.', 404);
        }
        return Zooboxi_V2_Bootstrap::ok(['item' => Zooboxi_Loyalty_Supply::dto($row, $user_id)]);
    }

    /* ══════════════════════════════════════════════════════════════
       Phase 2 — Subscriptions
       ══════════════════════════════════════════════════════════════ */

    private function subscriptions_payload(int $user_id, ?array $row = null): array
    {
        $out = [
            'items' => Zooboxi_Loyalty_Subscriptions::dtos($user_id),
            'max'   => Zooboxi_Loyalty_Subscriptions::max(),
            'perks' => Zooboxi_Loyalty_Subscriptions::perks(),
        ];
        if ($row !== null) {
            $out['subscription'] = Zooboxi_Loyalty_Subscriptions::dto($row, $user_id);
        }
        return $out;
    }

    private function subscription_error(array $result): \WP_REST_Response
    {
        $status = $result['code'] === 'subscription_not_found' ? 404 : ($result['code'] === 'subscription_invalid' ? 422 : 409);
        return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], $status);
    }

    public function subscriptions(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        return Zooboxi_V2_Bootstrap::ok($this->subscriptions_payload($user_id) + ['enabled' => Zooboxi_Loyalty_Subscriptions::enabled()]);
    }

    public function create_subscription(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        $input = [];
        foreach (['product_id', 'variation_id', 'qty', 'interval_days', 'next_at', 'pet_id'] as $key) {
            $value = $request->get_param($key);
            if ($value !== null) {
                $input[$key] = $value;
            }
        }
        $result = Zooboxi_Loyalty_Subscriptions::create($user_id, $input);
        if ($result['code'] !== '') {
            return $this->subscription_error($result);
        }
        return Zooboxi_V2_Bootstrap::ok($this->subscriptions_payload($user_id, $result['row']));
    }

    public function update_subscription(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        $input = [];
        foreach (['qty', 'interval_days', 'next_at', 'state', 'pet_id'] as $key) {
            $value = $request->get_param($key);
            if ($value !== null) {
                $input[$key] = $value;
            }
        }
        $result = Zooboxi_Loyalty_Subscriptions::update($user_id, absint($request->get_param('id')), $input);
        if ($result['code'] !== '') {
            return $this->subscription_error($result);
        }
        return Zooboxi_V2_Bootstrap::ok($this->subscriptions_payload($user_id, $result['row']));
    }

    public function skip_subscription(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        $result = Zooboxi_Loyalty_Subscriptions::skip($user_id, absint($request->get_param('id')));
        if ($result['code'] !== '') {
            return $this->subscription_error($result);
        }
        return Zooboxi_V2_Bootstrap::ok($this->subscriptions_payload($user_id, $result['row']));
    }

    public function delete_subscription(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        if (!Zooboxi_Loyalty_Subscriptions::cancel($user_id, absint($request->get_param('id')))) {
            return Zooboxi_V2_Bootstrap::fail('subscription_not_found', __('الاشتراك غير موجود', 'zooboxi'), 'That subscription does not exist.', 404);
        }
        return Zooboxi_V2_Bootstrap::ok($this->subscriptions_payload($user_id));
    }

    /** The one-tap basket: the subscription's line goes into the cart, flagged. */
    public function order_now(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request) || !Zooboxi_V2_Cart_Controller::session_ok()) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }
        $id     = absint($request->get_param('id'));
        $result = Zooboxi_Loyalty_Subscriptions::order_now($user_id, $id);
        if ($result['code'] !== '') {
            $status = $result['code'] === 'subscription_not_found' ? 404 : 409;
            return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], $status);
        }
        $row = Zooboxi_Loyalty_Subscriptions::find($id, $user_id);
        return Zooboxi_V2_Bootstrap::ok([
            'cart'         => Zooboxi_V2_Cart_Controller::cart_dto(),
            'subscription' => $row ? Zooboxi_Loyalty_Subscriptions::dto($row, $user_id) : null,
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       Phase 2 — Referral
       ══════════════════════════════════════════════════════════════ */

    public function referral(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Loyalty_Referrals::overview($user_id));
    }

    public function apply_referral(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        $result = Zooboxi_Loyalty_Referrals::apply($user_id, (string) $request->get_param('code'));
        if ($result['code'] !== '') {
            $status = $result['code'] === 'referral_invalid' ? 404 : 409;
            return Zooboxi_V2_Bootstrap::fail($result['code'], $result['ar'], $result['en'], $status);
        }
        $grant = $result['grant_id'] > 0 ? Zooboxi_Loyalty_Rewards::find_grant((int) $result['grant_id'], $user_id) : null;
        return Zooboxi_V2_Bootstrap::ok([
            'applied'      => ['code' => (string) $result['row']['code'], 'state' => (string) $result['row']['state']],
            'paws_earned'  => (int) $result['paws'],
            'paws_balance' => Zooboxi_Loyalty_Ledger::balance($user_id),
            'grant'        => $grant ? Zooboxi_Loyalty_Rewards::grant_dto($grant, $user_id) : null,
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       Phase 2 — Brand stamps
       ══════════════════════════════════════════════════════════════ */

    public function stamps(\WP_REST_Request $request): \WP_REST_Response
    {
        [$user_id, $refused] = $this->guard();
        if ($refused !== null) {
            return $refused;
        }
        return Zooboxi_V2_Bootstrap::ok(['items' => Zooboxi_Loyalty_Stamps::wallet($user_id)]);
    }

    /** Only the fields a pet actually has — never the whole request body. */
    private function pet_input(\WP_REST_Request $request): array
    {
        $out = [];
        foreach (['name', 'species', 'breed', 'sex', 'weight_kg', 'birth_date', 'neutered', 'avatar', 'notes', 'photo_id'] as $key) {
            $value = $request->get_param($key);
            if ($value !== null) {
                $out[$key] = $value;
            }
        }
        return $out;
    }

    /** Map the pets service's result codes onto the app's error envelope. */
    private function pet_error(array $result): ?\WP_REST_Response
    {
        switch ((string) $result['code']) {
            case '':
                return $result['pet'] === null
                    ? Zooboxi_V2_Bootstrap::fail('pet_not_found', __('هذا الحيوان غير موجود', 'zooboxi'), 'That pet does not exist.', 404)
                    : null;

            case 'pets_limit':
                return Zooboxi_V2_Bootstrap::fail(
                    'pets_limit',
                    sprintf(__('الحد الأقصى %d حيوانات', 'zooboxi'), Zooboxi_Loyalty_Pets::max()),
                    sprintf('You can keep up to %d pets.', Zooboxi_Loyalty_Pets::max()),
                    409
                );

            case 'pet_invalid':
                return Zooboxi_V2_Bootstrap::fail(
                    'pet_invalid',
                    __('راجع بيانات الحيوان', 'zooboxi'),
                    'Please check the pet details.',
                    422,
                    ['fields' => $result['errors']]
                );

            case 'pet_not_found':
                return Zooboxi_V2_Bootstrap::fail('pet_not_found', __('هذا الحيوان غير موجود', 'zooboxi'), 'That pet does not exist.', 404);

            default:
                return Zooboxi_V2_Bootstrap::fail('pet_failed', __('تعذّر حفظ بيانات الحيوان', 'zooboxi'), 'The pet could not be saved.', 500);
        }
    }
}
