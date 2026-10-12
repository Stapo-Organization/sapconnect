<?php
/**
 * Server-side conversions — the paid order, told to the ad platforms from the
 * server so iOS privacy limits and ad blockers do not hide it.
 *
 * One order → one send per configured platform, once (guarded by order meta),
 * queued through Action Scheduler so the checkout never waits. The event id is
 * `zb_purchase_{order_id}` on every platform and on the browser pixel, which is
 * how a web order counted twice collapses back to one.
 */

if (!defined('ABSPATH')) exit;

final class Zooboxi_Marketing_Conversions
{
    public const HOOK      = 'zooboxi_mkt_send_conversion';
    public const LOG_OPT   = 'zooboxi_mkt_log';
    public const LOG_LIMIT = 40;

    public static function register_hooks(): void
    {
        // Paid: card payments settle here (MyFatoorah calls payment_complete()).
        add_action('woocommerce_payment_complete', [__CLASS__, 'on_paid'], 20, 1);
        // COD and any manual move: processing is the store's "accepted" state.
        add_action('woocommerce_order_status_processing', [__CLASS__, 'on_paid'], 20, 1);
        add_action('woocommerce_order_status_completed', [__CLASS__, 'on_paid'], 20, 1);
        add_action(self::HOOK, [__CLASS__, 'send'], 10, 2);
    }

    public static function on_paid($order_id): void
    {
        try {
            if (!Zooboxi_Marketing::is_enabled()) return;
            $order = wc_get_order($order_id);
            if (!$order instanceof \WC_Order) return;
            if ($order->get_meta('_zb_conv_queued')) return;
            if (!self::any_configured()) return;

            $order->update_meta_data('_zb_conv_queued', time());
            $order->save();

            if (function_exists('as_enqueue_async_action')) {
                as_enqueue_async_action(self::HOOK, [(int) $order_id, false], 'zooboxi');
            } else {
                self::send((int) $order_id, false);
            }
        } catch (\Throwable $e) {
            error_log('[zooboxi-marketing] on_paid: ' . $e->getMessage());
        }
    }

    public static function any_configured(): bool
    {
        return (Zooboxi_Marketing::opt('meta_pixel_id') !== '' && Zooboxi_Marketing::opt('meta_capi_token') !== '')
            || (Zooboxi_Marketing::opt('tiktok_pixel_id') !== '' && Zooboxi_Marketing::opt('tiktok_token') !== '')
            || (Zooboxi_Marketing::opt('snap_pixel_id') !== '' && Zooboxi_Marketing::opt('snap_token') !== '');
    }

    /**
     * Builds and posts the order to every configured platform.
     * `$test` forces the platforms' test modes and never marks the order as sent.
     */
    public static function send(int $order_id, bool $test = false): array
    {
        $order = wc_get_order($order_id);
        if (!$order instanceof \WC_Order) return [];
        if (!$test && $order->get_meta('_zb_conv_sent')) return [];

        $payload = self::payload($order);
        $results = [];

        if (Zooboxi_Marketing::opt('meta_pixel_id') !== '' && Zooboxi_Marketing::opt('meta_capi_token') !== '') {
            $results['meta'] = self::send_meta($payload, $test);
        }
        if (Zooboxi_Marketing::opt('tiktok_pixel_id') !== '' && Zooboxi_Marketing::opt('tiktok_token') !== '') {
            $results['tiktok'] = self::send_tiktok($payload, $test);
        }
        if (Zooboxi_Marketing::opt('snap_pixel_id') !== '' && Zooboxi_Marketing::opt('snap_token') !== '') {
            $results['snap'] = self::send_snap($payload, $test);
        }

        foreach ($results as $platform => $r) {
            self::log($order_id, $platform, $r, $test);
        }
        if (!$test && $results) {
            $order->update_meta_data('_zb_conv_sent', time());
            $order->update_meta_data('_zb_conv_result', array_map(fn($r) => $r['ok'] ? 'ok' : 'fail', $results));
            $order->save();
        }
        return $results;
    }

    /* ── The one payload every platform is fed from ──────────────── */

    public static function payload(\WC_Order $order): array
    {
        $attr = $order->get_meta('_zb_attr');
        $attr = is_array($attr) ? $attr : [];
        $uid  = (int) $order->get_customer_id();
        $n    = Zooboxi_Marketing::orders_count_including($order);

        $contents = [];
        foreach ($order->get_items() as $item) {
            if (!$item instanceof \WC_Order_Item_Product) continue;
            $product = $item->get_product();
            $qty = max(1, (int) $item->get_quantity());
            $contents[] = [
                'id'       => $product ? (string) ($product->get_sku() ?: $product->get_id()) : (string) $item->get_product_id(),
                'quantity' => $qty,
                'price'    => round((float) $item->get_total() / $qty, 2),
            ];
        }

        return [
            'order_id'    => (int) $order->get_id(),
            'event_id'    => 'zb_purchase_' . $order->get_id(),
            'event_time'  => $order->get_date_created() ? $order->get_date_created()->getTimestamp() : time(),
            'value'       => round((float) $order->get_total(), 2),
            'currency'    => 'SAR',
            'first_order' => $n === 1,
            'orders_count'=> $n,
            'channel'     => ($attr['channel'] ?? ($order->get_meta('_zooboxi_source') === 'app' ? 'app' : 'web')),
            'express'     => $order->get_meta('_zooboxi_delivery_type') === 'express',
            'contents'    => $contents,
            'url'         => $attr['last']['url'] ?? home_url('/checkout/order-received/'),
            'em'          => self::sha(strtolower(trim((string) $order->get_billing_email()))),
            'ph'          => self::sha(self::phone_e164((string) $order->get_billing_phone())),
            'external_id' => $uid > 0 ? self::sha('wp_' . $uid) : null,
            'fn'          => self::sha(mb_strtolower(trim((string) $order->get_billing_first_name()))),
            'ln'          => self::sha(mb_strtolower(trim((string) $order->get_billing_last_name()))),
            'ct'          => self::sha(mb_strtolower(preg_replace('/\s+/', '', (string) $order->get_billing_city()))),
            'country'     => self::sha('sa'),
            'client_ip'   => $attr['client_ip'] ?? '',
            'user_agent'  => $attr['user_agent'] ?? '',
            'fbp'         => $attr['_fbp'] ?? null,
            'fbc'         => $attr['_fbc'] ?? null,
            'ttp'         => $attr['_ttp'] ?? null,
            'ttclid'      => $attr['last']['ttclid'] ?? null,
            'sccid'       => $attr['last']['ScCid'] ?? null,
            'scid'        => $attr['_scid'] ?? null,
        ];
    }

    private static function sha(string $v): ?string
    {
        return $v === '' ? null : hash('sha256', $v);
    }

    /** 05xxxxxxxx → 9665xxxxxxxx; anything already international is kept as digits. */
    public static function phone_e164(string $phone): string
    {
        $d = preg_replace('/\D+/', '', $phone);
        if ($d === '') return '';
        if (strpos($d, '00') === 0) $d = substr($d, 2);
        if (strlen($d) === 10 && $d[0] === '0') return '966' . substr($d, 1);
        if (strlen($d) === 9 && $d[0] === '5') return '966' . $d;
        return $d;
    }

    /* ── Meta ─────────────────────────────────────────────────────── */

    private static function send_meta(array $p, bool $test): array
    {
        $pixel = Zooboxi_Marketing::opt('meta_pixel_id');
        $token = Zooboxi_Marketing::opt('meta_capi_token');
        $user  = array_filter([
            'em'                => $p['em'] ? [$p['em']] : null,
            'ph'                => $p['ph'] ? [$p['ph']] : null,
            'fn'                => $p['fn'] ? [$p['fn']] : null,
            'ln'                => $p['ln'] ? [$p['ln']] : null,
            'ct'                => $p['ct'] ? [$p['ct']] : null,
            'country'           => [$p['country']],
            'external_id'       => $p['external_id'] ? [$p['external_id']] : null,
            'client_ip_address' => $p['client_ip'] ?: null,
            'client_user_agent' => $p['user_agent'] ?: null,
            'fbp'               => $p['fbp'],
            'fbc'               => $p['fbc'],
        ]);
        $custom = [
            'currency'     => $p['currency'],
            'value'        => $p['value'],
            'order_id'     => (string) $p['order_id'],
            'content_type' => 'product',
            'contents'     => array_map(fn($c) => ['id' => $c['id'], 'quantity' => $c['quantity'], 'item_price' => $c['price']], $p['contents']),
            'num_items'    => array_sum(array_column($p['contents'], 'quantity')),
            'delivery'     => $p['express'] ? 'express' : 'standard',
            'orders_count' => $p['orders_count'],
        ];
        $base = [
            'event_time'       => $p['event_time'],
            'action_source'    => $p['channel'] === 'app' ? 'other' : 'website',
            'event_source_url' => $p['url'],
            'user_data'        => $user,
            'custom_data'      => $custom,
        ];
        $events = [ $base + ['event_name' => 'Purchase', 'event_id' => $p['event_id']] ];
        if ($p['first_order']) {
            $events[] = $base + ['event_name' => 'FirstOrder', 'event_id' => 'zb_first_' . $p['order_id']];
        }
        $body = ['data' => $events];
        $code = $test ? Zooboxi_Marketing::opt('meta_test_code') : '';
        if ($code !== '') $body['test_event_code'] = $code;

        return self::post(
            'https://graph.facebook.com/v21.0/' . rawurlencode($pixel) . '/events?access_token=' . rawurlencode($token),
            $body,
            []
        );
    }

    /* ── TikTok ───────────────────────────────────────────────────── */

    private static function send_tiktok(array $p, bool $test): array
    {
        $user = array_filter([
            'email'       => $p['em'] ? [$p['em']] : null,
            'phone'       => $p['ph'] ? [$p['ph']] : null,
            'external_id' => $p['external_id'] ? [$p['external_id']] : null,
            'ip'          => $p['client_ip'] ?: null,
            'user_agent'  => $p['user_agent'] ?: null,
            'ttclid'      => $p['ttclid'],
            'ttp'         => $p['ttp'],
        ]);
        $props = [
            'currency'     => $p['currency'],
            'value'        => $p['value'],
            'content_type' => 'product',
            'contents'     => array_map(fn($c) => ['content_id' => $c['id'], 'quantity' => $c['quantity'], 'price' => $c['price']], $p['contents']),
            'order_id'     => (string) $p['order_id'],
        ];
        $base = [
            'event_time' => $p['event_time'],
            'user'       => $user,
            'properties' => $props,
            'page'       => ['url' => $p['url']],
        ];
        $data = [ $base + ['event' => 'CompletePayment', 'event_id' => $p['event_id']] ];
        if ($p['first_order']) {
            $data[] = $base + ['event' => 'FirstOrder', 'event_id' => 'zb_first_' . $p['order_id']];
        }
        $body = [
            'event_source'    => 'web',
            'event_source_id' => Zooboxi_Marketing::opt('tiktok_pixel_id'),
            'data'            => $data,
        ];
        $code = $test ? Zooboxi_Marketing::opt('tiktok_test_code') : '';
        if ($code !== '') $body['test_event_code'] = $code;

        return self::post(
            'https://business-api.tiktok.com/open_api/v1.3/event/track/',
            $body,
            ['Access-Token' => Zooboxi_Marketing::opt('tiktok_token')]
        );
    }

    /* ── Snap ─────────────────────────────────────────────────────── */

    private static function send_snap(array $p, bool $test): array
    {
        $user = array_filter([
            'em'                => $p['em'] ? [$p['em']] : null,
            'ph'                => $p['ph'] ? [$p['ph']] : null,
            'external_id'       => $p['external_id'] ? [$p['external_id']] : null,
            'client_ip_address' => $p['client_ip'] ?: null,
            'client_user_agent' => $p['user_agent'] ?: null,
            'sc_click_id'       => $p['sccid'],
            'sc_cookie1'        => $p['scid'],
        ]);
        $custom = [
            'currency'    => $p['currency'],
            'value'       => $p['value'],
            'order_id'    => (string) $p['order_id'],
            'content_ids' => array_column($p['contents'], 'id'),
            'num_items'   => array_sum(array_column($p['contents'], 'quantity')),
        ];
        $base = [
            'event_time'       => $p['event_time'] * 1000,
            'action_source'    => $p['channel'] === 'app' ? 'MOBILE_APP' : 'WEB',
            'event_source_url' => $p['url'],
            'user_data'        => $user,
            'custom_data'      => $custom,
        ];
        $data = [ $base + ['event_name' => 'PURCHASE', 'event_id' => $p['event_id']] ];
        if ($p['first_order']) {
            $data[] = $base + ['event_name' => 'CUSTOM_EVENT_1', 'event_id' => 'zb_first_' . $p['order_id']];
        }
        $url = 'https://tr.snapchat.com/v3/' . rawurlencode(Zooboxi_Marketing::opt('snap_pixel_id')) . '/events';
        if ($test) $url .= '/validate';
        return self::post($url, ['data' => $data], ['Authorization' => 'Bearer ' . Zooboxi_Marketing::opt('snap_token')]);
    }

    /* ── Transport + log ──────────────────────────────────────────── */

    private static function post(string $url, array $body, array $headers): array
    {
        $res = wp_remote_post($url, [
            'headers' => $headers + ['Content-Type' => 'application/json'],
            'body'    => wp_json_encode($body),
            'timeout' => 8,
        ]);
        if (is_wp_error($res)) {
            return ['ok' => false, 'status' => 0, 'message' => $res->get_error_message()];
        }
        $status = (int) wp_remote_retrieve_response_code($res);
        $raw    = (string) wp_remote_retrieve_body($res);
        $json   = json_decode($raw, true);
        $ok     = $status >= 200 && $status < 300;
        // TikTok answers 200 with its own code; 0 is success.
        if ($ok && is_array($json) && isset($json['code']) && (int) $json['code'] !== 0) {
            $ok = false;
        }
        $msg = '';
        if (is_array($json)) {
            $msg = (string) ($json['message'] ?? $json['error']['message'] ?? ($json['events_received'] ?? '') );
            if ($msg === '' && isset($json['status'])) $msg = (string) $json['status'];
        }
        return ['ok' => $ok, 'status' => $status, 'message' => mb_substr($msg !== '' ? $msg : $raw, 0, 200)];
    }

    private static function log(int $order_id, string $platform, array $r, bool $test): void
    {
        $log = get_option(self::LOG_OPT, []);
        if (!is_array($log)) $log = [];
        array_unshift($log, [
            't' => time(), 'order' => $order_id, 'platform' => $platform,
            'ok' => (bool) $r['ok'], 'status' => (int) $r['status'], 'msg' => (string) $r['message'], 'test' => $test,
        ]);
        update_option(self::LOG_OPT, array_slice($log, 0, self::LOG_LIMIT), false);
    }

    public static function recent_log(): array
    {
        $log = get_option(self::LOG_OPT, []);
        return is_array($log) ? $log : [];
    }
}
