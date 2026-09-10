<?php
/**
 * `/push/*` — the app's end of the device registry.
 *
 * Three things the phone needs: to say "this is my token", to say "stop", and
 * to read and write what it wants to hear about. Preferences are answered on
 * every register, so the settings screen paints the truth on first open
 * instead of a guess it corrects a moment later.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Push_Controller
{
    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/push/register', 'POST', [$this, 'register_device']);
        Zooboxi_V2_Bootstrap::route('/push/unregister', 'POST', [$this, 'unregister_device']);
        Zooboxi_V2_Bootstrap::route('/push/preferences', 'GET', [$this, 'preferences']);
        Zooboxi_V2_Bootstrap::route('/push/preferences', 'PUT,PATCH,POST', [$this, 'save_preferences']);
        Zooboxi_V2_Bootstrap::route('/push/live-activity', 'POST', [$this, 'live_activity_start']);
        Zooboxi_V2_Bootstrap::route('/push/live-activity/end', 'POST', [$this, 'live_activity_end']);
        Zooboxi_V2_Bootstrap::route('/push/opened', 'POST', [$this, 'opened']);
        Zooboxi_V2_Bootstrap::route('/push/inbox', 'GET', [$this, 'inbox']);
        Zooboxi_V2_Bootstrap::route('/push/inbox/read', 'POST', [$this, 'inbox_read']);
        Zooboxi_V2_Bootstrap::route('/push/waitlist', 'GET', [$this, 'waitlist_status']);
        Zooboxi_V2_Bootstrap::route('/push/waitlist', 'POST', [$this, 'waitlist_add']);
        Zooboxi_V2_Bootstrap::route('/push/waitlist/remove', 'POST', [$this, 'waitlist_remove']);
    }

    /** The last thirty days of what this person was told — and would have been. */
    public function inbox(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!class_exists('Zooboxi_Push_Engine')) {
            return Zooboxi_V2_Bootstrap::ok(['items' => [], 'unread' => 0]);
        }
        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Push_Engine::inbox_for(
            get_current_user_id(),
            Zooboxi_V2_Bootstrap::guest_id($request),
            Zooboxi_V2_Bootstrap::lang($request),
            max(1, min(60, (int) ($request->get_param('limit') ?: 30)))
        ));
    }

    public function inbox_read(\WP_REST_Request $request): \WP_REST_Response
    {
        $ids = (array) ($request->get_param('ids') ?? []);
        $n   = class_exists('Zooboxi_Push_Engine')
            ? Zooboxi_Push_Engine::mark_read(get_current_user_id(), Zooboxi_V2_Bootstrap::guest_id($request), $ids)
            : 0;
        return Zooboxi_V2_Bootstrap::ok(['read' => $n]);
    }

    /** «نبّهني» — restock / price for one product. */
    public function waitlist_status(\WP_REST_Request $request): \WP_REST_Response
    {
        $pid = absint($request->get_param('product_id'));
        if ($pid <= 0 || !class_exists('Zooboxi_Push_Waitlist')) {
            return Zooboxi_V2_Bootstrap::ok(['restock' => false, 'price' => false]);
        }
        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Push_Waitlist::status(get_current_user_id(), Zooboxi_V2_Bootstrap::guest_id($request), $pid));
    }

    public function waitlist_add(\WP_REST_Request $request): \WP_REST_Response
    {
        $pid  = absint($request->get_param('product_id'));
        $kind = (string) ($request->get_param('kind') ?: 'restock');
        $uid  = get_current_user_id();
        $gid  = Zooboxi_V2_Bootstrap::guest_id($request);
        if ($pid <= 0 || !class_exists('Zooboxi_Push_Waitlist')) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('منتج غير معروف', 'zooboxi'), 'Unknown product.', 404);
        }
        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        $ok = Zooboxi_Push_Waitlist::subscribe($uid, $gid, $pid, $kind, (float) $lat, (float) $lng);
        if (!$ok) {
            return Zooboxi_V2_Bootstrap::fail('waitlist_failed', __('تعذّر التسجيل', 'zooboxi'), 'Could not subscribe.', 400);
        }
        return Zooboxi_V2_Bootstrap::ok(Zooboxi_Push_Waitlist::status($uid, $gid, $pid));
    }

    public function waitlist_remove(\WP_REST_Request $request): \WP_REST_Response
    {
        $pid  = absint($request->get_param('product_id'));
        $kind = (string) ($request->get_param('kind') ?: '');
        $uid  = get_current_user_id();
        $gid  = Zooboxi_V2_Bootstrap::guest_id($request);
        if ($pid > 0 && class_exists('Zooboxi_Push_Waitlist')) {
            Zooboxi_Push_Waitlist::unsubscribe($uid, $gid, $pid, $kind);
        }
        return Zooboxi_V2_Bootstrap::ok(class_exists('Zooboxi_Push_Waitlist') ? Zooboxi_Push_Waitlist::status($uid, $gid, $pid) : ['restock' => false, 'price' => false]);
    }

    /**
     * The phone tapped a notification. `msg` is the outbox id the store put
     * in the data payload; only the person it was sent to may mark it.
     */
    public function opened(\WP_REST_Request $request): \WP_REST_Response
    {
        $msg = absint($request->get_param('msg'));
        $ok  = false;
        if ($msg > 0 && class_exists('Zooboxi_Push_Engine')) {
            $ok = Zooboxi_Push_Engine::mark_opened(
                $msg,
                get_current_user_id(),
                Zooboxi_V2_Bootstrap::guest_id($request)
            );
        }
        return Zooboxi_V2_Bootstrap::ok(['opened' => $ok]);
    }

    public function register_device(\WP_REST_Request $request): \WP_REST_Response
    {
        $token = trim((string) $request->get_param('token'));
        if ($token === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'push_token_required',
                'رمز الجهاز مفقود',
                'A device token is required',
                422
            );
        }

        $user_id  = get_current_user_id();
        $guest_id = Zooboxi_V2_Bootstrap::guest_id($request);

        Zooboxi_Push::register([
            'token'       => $token,
            'user_id'     => $user_id,
            'guest_id'    => $guest_id,
            'platform'    => (string) $request->get_param('platform'),
            'app_version' => (string) $request->get_param('app_version'),
            'locale'      => (string) $request->get_param('locale'),
        ]);

        $device = Zooboxi_Push::find($token);
        return Zooboxi_V2_Bootstrap::ok([
            'registered'  => $device !== null,
            'preferences' => $device ? Zooboxi_Push::prefs_of($device) : Zooboxi_Push::default_prefs(),
        ]);
    }

    /**
     * The app has put this order on the lock screen. Remember which activity
     * and which phone, so the store can keep it moving once the app is gone.
     */
    public function live_activity_start(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->owned_order($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }

        $activity = trim((string) $request->get_param('activity_token'));
        $device   = trim((string) $request->get_param('device_token'));
        if ($activity === '' || $device === '') {
            return Zooboxi_V2_Bootstrap::fail('push_token_required', __('رمز النشاط مطلوب', 'zooboxi'), 'Activity and device tokens are required.', 422);
        }

        $order->update_meta_data('_zb_la_token', $activity);
        $order->update_meta_data('_zb_la_device', $device);
        $order->save_meta_data();

        return Zooboxi_V2_Bootstrap::ok(['registered' => true]);
    }

    public function live_activity_end(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->owned_order($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }
        $order->delete_meta_data('_zb_la_token');
        $order->delete_meta_data('_zb_la_device');
        $order->save_meta_data();

        return Zooboxi_V2_Bootstrap::ok(['registered' => false]);
    }

    /** The order named in the request, only if it belongs to whoever is asking. */
    private function owned_order(\WP_REST_Request $request): ?\WC_Order
    {
        $order = wc_get_order(absint($request->get_param('order_id')));
        if (!$order instanceof \WC_Order) {
            return null;
        }
        $uid = get_current_user_id();
        if ($uid > 0) {
            return (int) $order->get_customer_id() === $uid ? $order : null;
        }
        // A guest order is claimed by the device id it was placed from.
        $guest = Zooboxi_V2_Bootstrap::guest_id($request);
        return $guest !== '' && (string) $order->get_meta('_zb_guest_id') === $guest ? $order : null;
    }

    public function unregister_device(\WP_REST_Request $request): \WP_REST_Response
    {
        Zooboxi_Push::unregister(trim((string) $request->get_param('token')));
        return Zooboxi_V2_Bootstrap::ok(['registered' => false]);
    }

    public function preferences(\WP_REST_Request $request): \WP_REST_Response
    {
        return Zooboxi_V2_Bootstrap::ok([
            'preferences' => $this->current_prefs($request),
        ]);
    }

    public function save_preferences(\WP_REST_Request $request): \WP_REST_Response
    {
        $incoming = $request->get_param('preferences');
        if (!is_array($incoming)) {
            $incoming = [];
            foreach (Zooboxi_Push::TOPICS as $topic) {
                if ($request->get_param($topic) !== null) {
                    $incoming[$topic] = filter_var($request->get_param($topic), FILTER_VALIDATE_BOOLEAN);
                }
            }
        }

        $user_id  = get_current_user_id();
        $guest_id = Zooboxi_V2_Bootstrap::guest_id($request);
        if ($user_id <= 0 && $guest_id === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'push_unknown_device',
                'لم نتعرّف على هذا الجهاز',
                'This device is not registered',
                400
            );
        }

        $saved = Zooboxi_Push::set_prefs($user_id, $guest_id, $incoming);
        return Zooboxi_V2_Bootstrap::ok(['preferences' => $saved]);
    }

    /**
     * What this phone currently wants. A device the store has never seen gets
     * the defaults rather than an error: the settings screen must render for
     * someone who has not yet granted the OS permission.
     */
    private function current_prefs(\WP_REST_Request $request): array
    {
        $token = trim((string) $request->get_param('token'));
        if ($token !== '') {
            $device = Zooboxi_Push::find($token);
            if ($device !== null) {
                return Zooboxi_Push::prefs_of($device);
            }
        }
        $devices = Zooboxi_Push::devices_for(get_current_user_id(), Zooboxi_V2_Bootstrap::guest_id($request));
        return $devices ? Zooboxi_Push::prefs_of($devices[0]) : Zooboxi_Push::default_prefs();
    }
}
