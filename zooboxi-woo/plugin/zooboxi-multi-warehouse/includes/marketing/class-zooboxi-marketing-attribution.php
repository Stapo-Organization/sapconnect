<?php
/**
 * Attribution — which ad brought this person.
 *
 * Landing with ?utm_* / fbclid / ttclid / ScCid / gclid writes a 30-day
 * last-touch cookie and a 90-day first-touch cookie that is never overwritten.
 * At registration both land on the user; at checkout both land on the order,
 * together with the platform cookies the conversion APIs match on (_fbp, _fbc,
 * _ttp, _scid). App orders carry no cookies — the MMP is their attribution.
 */

if (!defined('ABSPATH')) exit;

final class Zooboxi_Marketing_Attribution
{
    public const COOKIE_LAST  = 'zb_attr';
    public const COOKIE_FIRST = 'zb_attr_first';

    private const KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid', 'ttclid', 'ScCid', 'gclid', 'gbraid', 'wbraid'];

    public static function register_hooks(): void
    {
        add_action('init', [__CLASS__, 'capture_query'], 6);
        add_action('user_register', [__CLASS__, 'apply_to_user'], 40);
        add_action('woocommerce_checkout_order_processed', [__CLASS__, 'apply_to_order'], 40, 1);
        add_action('woocommerce_new_order', [__CLASS__, 'apply_to_order'], 40, 1);
    }

    public static function capture_query(): void
    {
        if (headers_sent() || is_admin() || (defined('REST_REQUEST') && REST_REQUEST)) return;
        $touch = [];
        foreach (self::KEYS as $k) {
            if (!empty($_GET[$k])) {
                $v = substr(sanitize_text_field(wp_unslash((string) $_GET[$k])), 0, 200);
                if ($v !== '') $touch[$k] = $v;
            }
        }
        if (!$touch) return;
        $touch['at']  = time();
        $touch['url'] = substr(esc_url_raw(home_url(add_query_arg([]))), 0, 300);
        if (!empty($_SERVER['HTTP_REFERER'])) {
            $touch['ref'] = substr(esc_url_raw(wp_unslash($_SERVER['HTTP_REFERER'])), 0, 300);
        }
        // Meta's own convention for fbc when the browser pixel has not set it yet.
        if (!empty($touch['fbclid']) && empty($_COOKIE['_fbc'])) {
            $touch['fbc'] = 'fb.1.' . (time() * 1000) . '.' . $touch['fbclid'];
        }
        self::set_cookie(self::COOKIE_LAST, $touch, 30 * DAY_IN_SECONDS);
        if (empty($_COOKIE[self::COOKIE_FIRST])) {
            self::set_cookie(self::COOKIE_FIRST, $touch, 90 * DAY_IN_SECONDS);
        }
    }

    private static function set_cookie(string $name, array $value, int $ttl): void
    {
        $json = wp_json_encode($value);
        setcookie($name, $json, [
            'expires'  => time() + $ttl,
            'path'     => '/',
            'secure'   => is_ssl(),
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
        $_COOKIE[$name] = $json;
    }

    private static function read_cookie(string $name): array
    {
        if (empty($_COOKIE[$name])) return [];
        $raw = wp_unslash((string) $_COOKIE[$name]);
        $data = json_decode($raw, true);
        return is_array($data) ? array_map('sanitize_text_field', array_filter($data, 'is_scalar')) : [];
    }

    /** Everything the browser knows right now: touches + platform cookies + client. */
    public static function snapshot(): array
    {
        $snap = [
            'last'  => self::read_cookie(self::COOKIE_LAST),
            'first' => self::read_cookie(self::COOKIE_FIRST),
        ];
        foreach (['_fbp', '_fbc', '_ttp', '_scid', '_ga'] as $c) {
            if (!empty($_COOKIE[$c])) $snap[$c] = substr(sanitize_text_field(wp_unslash((string) $_COOKIE[$c])), 0, 200);
        }
        if (empty($snap['_fbc']) && !empty($snap['last']['fbc'])) $snap['_fbc'] = $snap['last']['fbc'];
        return $snap;
    }

    public static function apply_to_user($user_id): void
    {
        try {
            $first = self::read_cookie(self::COOKIE_FIRST);
            $last  = self::read_cookie(self::COOKIE_LAST);
            if ($first) update_user_meta((int) $user_id, '_zb_attr_first', $first);
            if ($last)  update_user_meta((int) $user_id, '_zb_attr_signup', $last);
        } catch (\Throwable $e) {
            error_log('[zooboxi-marketing] attribution user: ' . $e->getMessage());
        }
    }

    public static function apply_to_order($order_id): void
    {
        try {
            $order = wc_get_order($order_id);
            if (!$order instanceof \WC_Order) return;
            if ($order->get_meta('_zb_attr_captured')) return;

            $snap = self::snapshot();
            $uid  = (int) $order->get_customer_id();
            if (empty($snap['first']) && $uid > 0) {
                $stored = get_user_meta($uid, '_zb_attr_first', true);
                if (is_array($stored)) $snap['first'] = $stored;
            }
            $snap['client_ip'] = self::client_ip();
            $snap['user_agent'] = substr(sanitize_text_field(wp_unslash($_SERVER['HTTP_USER_AGENT'] ?? '')), 0, 300);
            $snap['channel'] = $order->get_meta('_zooboxi_source') === 'app' ? 'app' : 'web';

            $order->update_meta_data('_zb_attr', $snap);
            $order->update_meta_data('_zb_attr_captured', 1);
            $src = $snap['last']['utm_source'] ?? ($snap['first']['utm_source'] ?? '');
            if ($src !== '') $order->update_meta_data('_zb_utm_source', $src);
            $order->save();
        } catch (\Throwable $e) {
            error_log('[zooboxi-marketing] attribution order: ' . $e->getMessage());
        }
    }

    public static function client_ip(): string
    {
        foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'] as $k) {
            if (!empty($_SERVER[$k])) {
                $ip = trim(explode(',', (string) $_SERVER[$k])[0]);
                if (filter_var($ip, FILTER_VALIDATE_IP)) return $ip;
            }
        }
        return '';
    }
}
