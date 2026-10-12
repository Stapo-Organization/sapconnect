<?php
/**
 * Zooboxi Marketing — «التسويق».
 *
 * The measurement and offer seams the paid launch runs on:
 *   - attribution capture (utm_* / click ids → cookie → user + order meta),
 *   - server-side conversions (Meta CAPI, TikTok Events API, Snap CAPI),
 *   - browser pixels on the web store, de-duplicated against the server sends,
 *   - the first-order offer: إكسبريس delivery free on a customer's first order.
 *
 * Every send is fire-and-forget through Action Scheduler; nothing here can slow
 * a checkout down or fail one. Credentials live in options (never in code) and
 * an unconfigured platform is simply skipped.
 */

if (!defined('ABSPATH')) exit;

final class Zooboxi_Marketing
{
    public const OPT_PREFIX = 'zooboxi_mkt_';

    /** Order statuses that count as "this customer has ordered". */
    public const ORDERED_STATUSES = ['processing', 'completed', 'on-hold', 'zb-ready', 'zb-out-for-delivery'];

    private const DEFAULTS = [
        'enabled'              => 'yes',
        'pixels_enabled'       => 'yes',
        'first_express_free'   => 'no',
        'meta_pixel_id'        => '',
        'meta_capi_token'      => '',
        'meta_test_code'       => '',
        'tiktok_pixel_id'      => '',
        'tiktok_token'         => '',
        'tiktok_test_code'     => '',
        'snap_pixel_id'        => '',
        'snap_token'           => '',
        'ga4_id'               => '',
        'gads_conversion_id'   => '',
        'gads_conversion_label'=> '',
    ];

    /** @var array<string,int> per-request memo for the first-order test */
    private static array $prior_memo = [];

    public static function boot(): void
    {
        require_once __DIR__ . '/class-zooboxi-marketing-attribution.php';
        require_once __DIR__ . '/class-zooboxi-marketing-conversions.php';
        require_once __DIR__ . '/class-zooboxi-marketing-pixels.php';

        Zooboxi_Marketing_Attribution::register_hooks();
        Zooboxi_Marketing_Conversions::register_hooks();
        Zooboxi_Marketing_Pixels::register_hooks();

        // The first-order offer: priority 20, after the loyalty tier filter (10),
        // which returns early on a zero fee anyway.
        add_filter('zooboxi_express_fee', [__CLASS__, 'filter_express_fee'], 20, 1);
        // Make WooCommerce's rate cache move when the offer state moves (login mid-session).
        add_filter('woocommerce_cart_shipping_packages', [__CLASS__, 'filter_shipping_packages'], 110, 1);
        // The offer must not be defeated by the order's own creation: the count of
        // "prior" orders is taken before the new order exists (see prior_orders()).
        add_action('woocommerce_checkout_order_processed', [__CLASS__, 'stamp_first_order'], 15, 1);
    }

    /* ── Options ─────────────────────────────────────────────────── */

    public static function opt(string $key, $fallback = null)
    {
        $default = $fallback ?? (self::DEFAULTS[$key] ?? '');
        return get_option(self::OPT_PREFIX . $key, $default);
    }

    public static function defaults(): array
    {
        return self::DEFAULTS;
    }

    public static function is_enabled(): bool
    {
        return self::opt('enabled') === 'yes';
    }

    public static function first_express_free(): bool
    {
        return self::is_enabled() && self::opt('first_express_free') === 'yes';
    }

    /** The block the app reads from GET /meta. */
    public static function meta_block(): array
    {
        return [
            'first_express_free' => self::first_express_free(),
        ];
    }

    /* ── Orders ──────────────────────────────────────────────────── */

    /**
     * How many orders this customer has placed that count, excluding one id
     * (the order being created right now, so a checkout's own order is never
     * counted against its own offer).
     */
    public static function prior_orders(int $user_id, int $exclude_order_id = 0): int
    {
        if ($user_id <= 0 || !function_exists('wc_get_orders')) {
            return 0;
        }
        $memo_key = $user_id . '|' . $exclude_order_id;
        if (isset(self::$prior_memo[$memo_key])) {
            return self::$prior_memo[$memo_key];
        }
        $ids = wc_get_orders([
            'customer_id' => $user_id,
            'status'      => self::ORDERED_STATUSES,
            'limit'       => 3,
            'return'      => 'ids',
        ]);
        $count = 0;
        foreach ((array) $ids as $id) {
            if ((int) $id !== $exclude_order_id) $count++;
        }
        return self::$prior_memo[$memo_key] = $count;
    }

    /** Lifetime count *including* the given order — what the app's success screen reports. */
    public static function orders_count_including(\WC_Order $order): int
    {
        $uid = (int) $order->get_customer_id();
        if ($uid <= 0) return 1;
        $stamped = (int) $order->get_meta('_zb_orders_count');
        if ($stamped > 0) return $stamped;
        return self::prior_orders($uid, (int) $order->get_id()) + 1;
    }

    /** Stamps the ladder position on the order the moment it exists (1 = first order). */
    public static function stamp_first_order($order_id): void
    {
        try {
            $order = wc_get_order($order_id);
            if (!$order instanceof \WC_Order) return;
            $uid = (int) $order->get_customer_id();
            $n = $uid > 0 ? self::prior_orders($uid, (int) $order->get_id()) + 1 : 1;
            $order->update_meta_data('_zb_orders_count', $n);
            if ($n === 1 && self::first_express_free() && $order->get_meta('_zooboxi_delivery_type') === 'express') {
                $order->update_meta_data('_zb_first_express_free', 1);
            }
            $order->save();
        } catch (\Throwable $e) {
            error_log('[zooboxi-marketing] stamp_first_order: ' . $e->getMessage());
        }
    }

    /* ── The first-order offer ───────────────────────────────────── */

    public static function filter_express_fee($fee)
    {
        $fee = (float) $fee;
        if ($fee <= 0 || !self::first_express_free()) {
            return $fee;
        }
        $uid = get_current_user_id();
        if ($uid <= 0) {
            return $fee; // guests: the offer is a signed-in customer's, once.
        }
        try {
            return self::prior_orders($uid) === 0 ? 0.0 : $fee;
        } catch (\Throwable $e) {
            return $fee;
        }
    }

    public static function filter_shipping_packages($packages)
    {
        if (!is_array($packages) || !self::first_express_free()) {
            return $packages;
        }
        $uid = get_current_user_id();
        if ($uid <= 0) return $packages;
        try {
            $first = self::prior_orders($uid) === 0;
            foreach ($packages as $i => $package) {
                if (is_array($package)) {
                    $packages[$i]['zb_first_express'] = $first ? 1 : 0;
                }
            }
        } catch (\Throwable $e) {
            // leave the packages untouched
        }
        return $packages;
    }

    /** Why express is free for this signed-in customer right now, or null. */
    public static function free_express_reason(int $user_id): ?string
    {
        if ($user_id <= 0 || !self::first_express_free()) return null;
        return self::prior_orders($user_id) === 0 ? 'first_order' : null;
    }
}
