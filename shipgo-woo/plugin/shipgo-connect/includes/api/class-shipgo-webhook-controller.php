<?php
defined('ABSPATH') || exit;

/**
 * Receives ShipGo status callbacks at POST /wp-json/shipgo/v1/order-status.
 * Trust is established by an HMAC-SHA256 signature over "<timestamp>.<rawBody>"
 * (the per-connection webhook secret), a ±300s replay window, and event-id dedupe.
 */
class ShipGo_Webhook_Controller {

    const REPLAY_WINDOW = 300;            // seconds
    const SEEN_OPTION   = 'shipgo_seen_events';
    const SEEN_KEEP     = 200;

    public static function register_routes(): void {
        register_rest_route('shipgo/v1', '/order-status', [
            'methods'             => 'POST',
            'permission_callback' => [__CLASS__, 'verify'],
            'callback'            => [__CLASS__, 'handle'],
        ]);
    }

    /** Constant-time HMAC verification over the RAW body + replay-window check. */
    public static function verify(WP_REST_Request $request) {
        $secret = ShipGo_Settings::webhook_secret();
        if ($secret === '') {
            return new WP_Error('shipgo_no_secret', 'Webhook not configured', ['status' => 503]);
        }
        $ts  = (string) $request->get_header('x-shipgo-timestamp');
        $sig = (string) $request->get_header('x-shipgo-signature');
        $sig = preg_replace('/^sha256=/', '', $sig);
        if ($ts === '' || $sig === '') {
            return new WP_Error('shipgo_unsigned', 'Missing signature', ['status' => 401]);
        }
        if (abs(time() - (int) $ts) > self::REPLAY_WINDOW) {
            return new WP_Error('shipgo_stale', 'Stale timestamp', ['status' => 401]);
        }
        $expected = hash_hmac('sha256', $ts . '.' . $request->get_body(), $secret);
        if (!hash_equals($expected, $sig)) {
            return new WP_Error('shipgo_bad_sig', 'Bad signature', ['status' => 401]);
        }
        return true;
    }

    public static function handle(WP_REST_Request $request) {
        $data = json_decode($request->get_body(), true);
        if (!is_array($data)) {
            return new WP_REST_Response(['ok' => false, 'error' => 'bad body'], 400);
        }

        $eventId = (string) ($data['event_id'] ?? '');
        if ($eventId && self::already_processed($eventId)) {
            return new WP_REST_Response(['ok' => true, 'duplicate' => true], 200);
        }

        $order = self::resolve_order($data);
        if (!$order) {
            // 200 so ShipGo doesn't retry forever for an order this store doesn't have
            return new WP_REST_Response(['ok' => true, 'matched' => false], 200);
        }

        $shipgo = (string) ($data['shipgo_status'] ?? $data['event_type'] ?? '');
        self::apply($order, $shipgo, $data);

        if ($eventId) {
            self::mark_processed($eventId);
        }
        return new WP_REST_Response(['ok' => true], 200);
    }

    private static function resolve_order(array $data): ?WC_Order {
        // primary: the ShipGo order code we stored on push
        $code = (string) ($data['order_code'] ?? '');
        if ($code !== '') {
            $orders = wc_get_orders(['limit' => 1, 'meta_key' => ShipGo_Statuses::META_CODE, 'meta_value' => $code]);
            if (!empty($orders)) {
                return $orders[0];
            }
        }
        // fallback: external_ref = the WC order id
        $ext = $data['external_ref'] ?? '';
        if ($ext !== '') {
            $o = wc_get_order((int) $ext);
            if ($o instanceof WC_Order) {
                return $o;
            }
        }
        return null;
    }

    private static function apply(WC_Order $order, string $shipgo, array $data): void {
        $order->update_meta_data(ShipGo_Statuses::META_STATUS, $shipgo);
        if (!empty($data['tracking_number'])) {
            $order->update_meta_data(ShipGo_Statuses::META_TRACKING, sanitize_text_field((string) $data['tracking_number']));
        }
        if (!empty($data['awb'])) {
            $order->update_meta_data(ShipGo_Statuses::META_AWB, sanitize_text_field((string) $data['awb']));
        }
        if (!empty($data['carrier_name'])) {
            $order->update_meta_data(ShipGo_Statuses::META_CARRIER, sanitize_text_field((string) $data['carrier_name']));
        }

        $label = ShipGo_Statuses::label_ar($shipgo);
        $note  = sprintf(__('تحديث ShipGo: %s', 'shipgo'), $label);
        if (!empty($data['tracking_number'])) {
            $note .= ' — ' . sprintf(__('رقم التتبّع: %s', 'shipgo'), $data['tracking_number']);
        }
        $order->add_order_note($note, true /* customer note for dispatched/delivered */ && in_array($shipgo, ['dispatched', 'delivered'], true));

        $target = ShipGo_Statuses::wc_status_for($shipgo);
        $order->save();
        if ($target && $order->get_status() !== $target) {
            $order->update_status($target, sprintf(__('ShipGo: %s', 'shipgo'), $label));
        }
    }

    private static function already_processed(string $id): bool {
        $seen = get_option(self::SEEN_OPTION, []);
        return is_array($seen) && in_array($id, $seen, true);
    }

    private static function mark_processed(string $id): void {
        $seen = get_option(self::SEEN_OPTION, []);
        if (!is_array($seen)) {
            $seen = [];
        }
        $seen[] = $id;
        if (count($seen) > self::SEEN_KEEP) {
            $seen = array_slice($seen, -self::SEEN_KEEP);
        }
        update_option(self::SEEN_OPTION, $seen, false);
    }
}
