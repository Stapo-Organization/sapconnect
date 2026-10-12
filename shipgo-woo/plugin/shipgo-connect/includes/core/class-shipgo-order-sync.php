<?php
defined('ABSPATH') || exit;

/**
 * Captures WooCommerce orders and pushes them to ShipGo. Checkout never blocks:
 * capture only SCHEDULES an async WP-Cron event; the push (and any retry with
 * backoff) runs in the background. Idempotent — once an order has a ShipGo order
 * code it is not re-pushed, and the server dedupes on (store, external_id) too.
 */
class ShipGo_Order_Sync {

    const MAX_ATTEMPTS = 6;
    const BACKOFF = [60, 300, 1800, 7200, 21600];   // seconds between retries

    private static ?ShipGo_Order_Sync $instance = null;
    /** @var array<int,bool> order ids to push at the end of the current request */
    private $shutdown_ids = [];
    private $shutdown_hooked = false;

    public static function instance(): ShipGo_Order_Sync {
        return self::$instance ??= new self();
    }

    public function register_hooks(): void {
        // classic checkout + Store-API (blocks) checkout — a diverged checkout may use either
        add_action('woocommerce_checkout_order_processed', [$this, 'on_new_order'], 20, 1);
        add_action('woocommerce_store_api_checkout_order_processed', [$this, 'on_new_order_object'], 20, 1);
        // backstop for admin-created / REST-created orders
        add_action('woocommerce_new_order', [$this, 'on_new_order'], 20, 1);
        // the async worker (WP-Cron retry path)
        add_action('shipgo_push_order', [$this, 'push'], 10, 1);
    }

    public function on_new_order($order_id): void {
        $this->schedule((int) $order_id);
    }

    public function on_new_order_object($order): void {
        if ($order instanceof WC_Order) {
            $this->schedule($order->get_id());
        }
    }

    /** Queue an async push (deduped — never schedule twice for the same order). */
    private function schedule(int $order_id): void {
        if (!$order_id || !ShipGo_Settings::is_enabled()) {
            return;
        }
        $order = wc_get_order($order_id);
        if (!$order || $order->get_meta(ShipGo_Statuses::META_CODE)) {
            return; // unknown, or already pushed
        }
        // WP-Cron retry backstop
        if (!wp_next_scheduled('shipgo_push_order', [$order_id])) {
            wp_schedule_single_event(time() + 5, 'shipgo_push_order', [$order_id]);
        }
        // Immediate push at request shutdown — fires even when WP-Cron is disabled,
        // AFTER the customer's response is released (no checkout delay).
        $this->shutdown_ids[$order_id] = true;
        if (!$this->shutdown_hooked) {
            $this->shutdown_hooked = true;
            add_action('shutdown', [$this, 'run_shutdown_pushes'], 99);
        }
    }

    /** Push the orders queued this request, after releasing the client connection. */
    public function run_shutdown_pushes(): void {
        if (empty($this->shutdown_ids)) {
            return;
        }
        if (function_exists('fastcgi_finish_request')) {
            @fastcgi_finish_request();   // free the customer's connection before the HTTP call
        }
        $ids = array_keys($this->shutdown_ids);
        $this->shutdown_ids = [];
        foreach ($ids as $oid) {
            try { $this->push((int) $oid); } catch (\Throwable $e) { /* the WP-Cron event will retry */ }
        }
    }

    /** The async worker: build the payload, POST it, persist the result, retry on failure. */
    public function push($order_id): void {
        $order = wc_get_order((int) $order_id);
        if (!$order || !ShipGo_Settings::is_enabled()) {
            return;
        }
        if ($order->get_meta(ShipGo_Statuses::META_CODE)) {
            return; // already synced
        }

        $payload = ShipGo_Payload::for_order($order);
        $res = ShipGo_Client::post('/v1/channel/orders', $payload, 'zb-' . $order->get_id());

        if ($res['ok'] && is_array($res['data'])) {
            $d = $res['data'];
            $order->update_meta_data(ShipGo_Statuses::META_CODE, $d['order_code'] ?? '');
            $order->update_meta_data(ShipGo_Statuses::META_STATUS, $d['status'] ?? 'created');
            $order->update_meta_data(ShipGo_Statuses::META_SYNCED, current_time('mysql'));
            $order->delete_meta_data(ShipGo_Statuses::META_ATTEMPTS);
            $unmatched = $d['unmatched'] ?? [];
            $sandbox = !empty($d['is_sandbox']);
            $note = sprintf(
                /* translators: 1: order code, 2: mode */
                __('أُرسل الطلب إلى ShipGo (%1$s)%2$s.', 'shipgo'),
                $d['order_code'] ?? '—',
                $sandbox ? ' — ' . __('وضع المراقبة', 'shipgo') : ''
            );
            if (!empty($unmatched)) {
                $skus = implode('، ', array_map(static fn($u) => $u['sku'] ?? '', $unmatched));
                $note .= ' ' . sprintf(__('أصناف غير مطابقة: %s', 'shipgo'), $skus);
            }
            $order->add_order_note($note);
            $order->save();
            return;
        }

        // failure → backoff retry
        $attempts = (int) $order->get_meta(ShipGo_Statuses::META_ATTEMPTS) + 1;
        $order->update_meta_data(ShipGo_Statuses::META_ATTEMPTS, $attempts);
        $order->add_order_note(sprintf(__('تعذّر إرسال الطلب إلى ShipGo (محاولة %1$d): %2$s', 'shipgo'), $attempts, $res['error'] ?? 'خطأ'));
        $order->save();

        if ($attempts < self::MAX_ATTEMPTS) {
            $delay = self::BACKOFF[min($attempts - 1, count(self::BACKOFF) - 1)];
            wp_schedule_single_event(time() + $delay, 'shipgo_push_order', [$order->get_id()]);
        }
    }

    /** Manual re-push from the admin metabox (clears the synced flag first). */
    public function repush(int $order_id): array {
        $order = wc_get_order($order_id);
        if (!$order) {
            return ['ok' => false, 'error' => 'الطلب غير موجود'];
        }
        $order->delete_meta_data(ShipGo_Statuses::META_CODE);
        $order->save();
        $this->push($order_id);
        $order = wc_get_order($order_id);
        return ['ok' => (bool) $order->get_meta(ShipGo_Statuses::META_CODE), 'code' => $order->get_meta(ShipGo_Statuses::META_CODE)];
    }
}
