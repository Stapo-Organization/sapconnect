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

        return Zooboxi_V2_Bootstrap::ok([
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
