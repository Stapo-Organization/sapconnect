<?php
/**
 * Zooboxi_V2_Bootstrap — the request pipeline + route table for the `zooboxi/v2`
 * mobile API.
 *
 * THE LINCHPIN: 44 existing classes read the customer's location from the WooCommerce
 * session, falling back to seven `zooboxi_*` cookies. The app has no cookie jar, so it
 * sends the same values as `X-ZB-*` headers and this bootstrap writes them into the
 * in-request `$_COOKIE` superglobal BEFORE any plugin logic runs. Every stock filter,
 * badge, delivery promise, shipping method and cart cap therefore becomes location-aware
 * with ZERO changes to those classes — the app becomes the cookie jar.
 *
 * Everything here is additive: no web-store code path reaches this file (all hooks are
 * either REST-only or guarded by is_v2_request()).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Bootstrap
{
    public const NS = 'zooboxi/v2';

    /** Cache-Control max-age per surface (seconds). */
    public const TTL_HOME       = 300;
    public const TTL_CATEGORIES = 3600;
    public const TTL_LISTING    = 120;
    public const TTL_PDP        = 60;
    public const TTL_META       = 300;

    /** The request currently being dispatched (for ETag / lang / headers). */
    private static ?\WP_REST_Request $request = null;

    /** Resolved bearer user id for this request (-1 = not resolved yet). */
    private static int $token_user = -1;

    /** True once the location headers have been written into $_COOKIE. */
    private static bool $seeded = false;

    /** Set when a Polylang translation was missing and Arabic was served instead. */
    private static bool $lang_fallback = false;

    /** Memo for is_v2_request(). */
    private static ?bool $is_v2 = null;

    /* ══════════════════════════════════════════════════════════════
       BOOT
       ══════════════════════════════════════════════════════════════ */

    public function __construct()
    {
        // Seed as early as possible (plugins_loaded) so nothing can read a cold cookie jar.
        if (self::is_v2_request()) {
            self::seed_location();
        }

        // Priority 99: after WordPress's cookie and application-password resolvers, so
        // the bearer token is the last word on who a /zooboxi/v2/ request belongs to.
        add_filter('determine_current_user', [__CLASS__, 'authenticate'], 99);
        add_filter('rest_pre_dispatch', [__CLASS__, 'pre_dispatch'], 5, 3);
        add_action('rest_api_init', [__CLASS__, 'register_routes']);

        // Lazy schema install (scp deploys never fire activation hooks).
        add_action('admin_init', ['Zooboxi_App_Tokens', 'maybe_install']);

        // Order timeline stamps + the status mirror the Laravel side was missing.
        add_action('woocommerce_order_status_changed', [__CLASS__, 'on_order_status_changed'], 20, 4);
    }

    /* ══════════════════════════════════════════════════════════════
       REQUEST DETECTION
       ══════════════════════════════════════════════════════════════ */

    /** Is the CURRENT HTTP request addressed at /zooboxi/v2/*? (URI sniff — runs before REST boots.) */
    public static function is_v2_request(): bool
    {
        if (self::$is_v2 !== null) {
            return self::$is_v2;
        }

        $needle = '/' . self::NS;

        // ?rest_route=/zooboxi/v2/...
        if (isset($_GET['rest_route'])) {
            $route = (string) wp_unslash($_GET['rest_route']);
            if (strpos($route, $needle) === 0) {
                return self::$is_v2 = true;
            }
        }

        // /wp-json/zooboxi/v2/...
        $uri = isset($_SERVER['REQUEST_URI']) ? (string) wp_unslash($_SERVER['REQUEST_URI']) : '';
        if ($uri !== '') {
            $prefix = function_exists('rest_get_url_prefix') ? rest_get_url_prefix() : 'wp-json';
            if (strpos($uri, '/' . $prefix . $needle . '/') !== false
                || substr($uri, -strlen('/' . $prefix . $needle)) === '/' . $prefix . $needle) {
                return self::$is_v2 = true;
            }
        }

        return self::$is_v2 = false;
    }

    /* ══════════════════════════════════════════════════════════════
       AUTH — Bearer zbat_… → user id
       ══════════════════════════════════════════════════════════════ */

    /**
     * For v2 requests the ONLY accepted credential is our bearer token: browser
     * cookies are deliberately ignored so the API can never be driven by a stray
     * session. Non-v2 requests pass through untouched.
     *
     * @param int|false $user_id
     * @return int|false
     */
    public static function authenticate($user_id)
    {
        if (!self::is_v2_request()) {
            return $user_id;
        }
        return self::token_user() ?: 0;
    }

    /** Resolve (once) the user behind the Authorization header. 0 = guest. */
    public static function token_user(): int
    {
        if (self::$token_user !== -1) {
            return self::$token_user;
        }
        self::$token_user = 0;

        $raw = self::bearer_token();
        if ($raw !== '' && class_exists('Zooboxi_App_Tokens')) {
            // The first authenticated request after an scp deploy may arrive before
            // rest_api_init has created the table; one option read makes that safe.
            Zooboxi_App_Tokens::maybe_install();
            self::$token_user = Zooboxi_App_Tokens::verify($raw);
        }
        return self::$token_user;
    }

    /** The raw bearer token from the request, '' when absent. */
    public static function bearer_token(): string
    {
        $header = '';
        foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $key) {
            if (!empty($_SERVER[$key])) {
                $header = (string) wp_unslash($_SERVER[$key]);
                break;
            }
        }
        if ($header === '' && function_exists('getallheaders')) {
            $all = getallheaders();
            if (is_array($all)) {
                foreach ($all as $name => $value) {
                    if (strtolower((string) $name) === 'authorization') {
                        $header = (string) $value;
                        break;
                    }
                }
            }
        }
        if ($header === '' || stripos($header, 'bearer ') !== 0) {
            return '';
        }
        return trim(substr($header, 7));
    }

    /* ══════════════════════════════════════════════════════════════
       PRE-DISPATCH — seed location, capture request, switch language
       ══════════════════════════════════════════════════════════════ */

    /**
     * @param mixed            $result
     * @param \WP_REST_Server  $server
     * @param \WP_REST_Request $request
     * @return mixed
     */
    public static function pre_dispatch($result, $server, $request)
    {
        if (!($request instanceof \WP_REST_Request)) {
            return $result;
        }
        if (strpos(ltrim((string) $request->get_route(), '/'), self::NS) !== 0) {
            return $result;
        }

        self::$request = $request;
        self::seed_location($request);
        self::apply_language($request);

        return $result;
    }

    public static function request(): ?\WP_REST_Request
    {
        return self::$request;
    }

    /* ══════════════════════════════════════════════════════════════
       LOCATION SEEDING (the app is the cookie jar)
       ══════════════════════════════════════════════════════════════ */

    /**
     * Map X-ZB-* headers onto the exact cookie names the plugin reads. Idempotent —
     * a header always wins over an inbound cookie, and an absent header leaves the
     * existing value alone.
     */
    public static function seed_location(?\WP_REST_Request $request = null): void
    {
        // Header name (normalised) => cookie name.
        $map = [
            'X-ZB-Lat'           => 'zooboxi_lat',
            'X-ZB-Lng'           => 'zooboxi_lng',
            'X-ZB-City'          => 'zooboxi_city',
            'X-ZB-District'      => 'zooboxi_district',
            'X-ZB-Delivery-Type' => 'zooboxi_delivery_type',
            'X-ZB-Branch'        => 'zooboxi_branch',
            'X-ZB-Express'       => 'zooboxi_express',
        ];

        foreach ($map as $header => $cookie) {
            $value = self::read_header($header, $request);
            if ($value === null) {
                continue;
            }
            // The app percent-encodes Arabic values (dart:io cannot send
            // non-Latin-1 header bytes) — undo that before sanitizing.
            if (strpos($value, '%') !== false && preg_match('/%[0-9A-Fa-f]{2}/', $value)) {
                $value = rawurldecode($value);
            }
            $value = sanitize_text_field($value);
            if ($value === '') {
                unset($_COOKIE[$cookie]);
                continue;
            }
            if ($cookie === 'zooboxi_lat' || $cookie === 'zooboxi_lng') {
                // Only accept a real coordinate; a junk header must not poison the jar.
                if (!is_numeric($value)) {
                    continue;
                }
                $value = (string) (float) $value;
            }
            $_COOKIE[$cookie] = $value;
        }

        self::$seeded = true;
    }

    public static function seeded(): bool
    {
        return self::$seeded;
    }

    /** Read a request header from the REST request or straight off $_SERVER. */
    private static function read_header(string $name, ?\WP_REST_Request $request = null): ?string
    {
        if ($request instanceof \WP_REST_Request) {
            $v = $request->get_header($name);
            if ($v !== null && $v !== '') {
                return (string) $v;
            }
        }
        $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
        if (isset($_SERVER[$key])) {
            return (string) wp_unslash($_SERVER[$key]);
        }
        return null;
    }

    /** Customer coordinates for this request (from the seeded jar). */
    public static function latlng(): array
    {
        $lat = isset($_COOKIE['zooboxi_lat']) ? (float) $_COOKIE['zooboxi_lat'] : 0.0;
        $lng = isset($_COOKIE['zooboxi_lng']) ? (float) $_COOKIE['zooboxi_lng'] : 0.0;
        return [$lat, $lng];
    }

    /** Customer city for this request ('' when unknown). */
    public static function city(): string
    {
        return isset($_COOKIE['zooboxi_city']) ? sanitize_text_field((string) $_COOKIE['zooboxi_city']) : '';
    }

    /** The device / guest identifier (X-ZB-Guest), '' when absent or malformed. */
    public static function guest_id(?\WP_REST_Request $request = null): string
    {
        $raw = self::read_header('X-ZB-Guest', $request ?: self::$request);
        if ($raw === null) {
            return '';
        }
        $raw = trim($raw);
        return preg_match('/^[A-Za-z0-9._\-]{8,64}$/', $raw) ? $raw : '';
    }

    /**
     * Mirror the seeded location into the WooCommerce session. Must run AFTER the
     * session exists (wc_load_cart) and BEFORE cap_cart_to_reachable (priority 20),
     * because every reader checks the session first and the cookies second.
     */
    public static function mirror_location_to_session(): void
    {
        if (!function_exists('WC') || !WC()->session) {
            return;
        }
        [$lat, $lng] = self::latlng();
        $session = WC()->session;

        if ($lat && $lng) {
            $session->set('zooboxi_customer_lat', $lat);
            $session->set('zooboxi_customer_lng', $lng);
        }
        $city = self::city();
        if ($city !== '') {
            $session->set('zooboxi_customer_city', $city);
        }
        if (isset($_COOKIE['zooboxi_district'])) {
            $session->set('zooboxi_customer_district', sanitize_text_field((string) $_COOKIE['zooboxi_district']));
        }
        if (isset($_COOKIE['zooboxi_delivery_type'])) {
            $session->set('zooboxi_delivery_type', sanitize_text_field((string) $_COOKIE['zooboxi_delivery_type']));
        }
    }

    /* ══════════════════════════════════════════════════════════════
       LANGUAGE (Polylang-aware, Arabic-first with an explicit fallback flag)
       ══════════════════════════════════════════════════════════════ */

    public static function apply_language(\WP_REST_Request $request): void
    {
        self::$lang_fallback = false;
        if (self::lang($request) === 'en') {
            switch_to_locale('en_US');
        }
    }

    /** 'ar' (default) or 'en'. */
    public static function lang(?\WP_REST_Request $request = null): string
    {
        $request = $request ?: self::$request;
        $raw = $request instanceof \WP_REST_Request ? (string) $request->get_param('lang') : '';
        return strtolower(trim($raw)) === 'en' ? 'en' : 'ar';
    }

    public static function lang_fallback(): bool
    {
        return self::$lang_fallback;
    }

    /** Translate a post id to the requested language; falls back to the original. */
    public static function map_post(int $id): int
    {
        if ($id <= 0 || self::lang() !== 'en' || !function_exists('pll_get_post')) {
            return $id;
        }
        $translated = pll_get_post($id, 'en');
        if ($translated && (int) $translated !== $id && get_post_status((int) $translated) === 'publish') {
            return (int) $translated;
        }
        self::$lang_fallback = true;
        return $id;
    }

    /** Translate a term id to the requested language; falls back to the original. */
    public static function map_term(int $id): int
    {
        if ($id <= 0 || self::lang() !== 'en' || !function_exists('pll_get_term')) {
            return $id;
        }
        $translated = pll_get_term($id, 'en');
        if ($translated && (int) $translated !== $id) {
            return (int) $translated;
        }
        self::$lang_fallback = true;
        return $id;
    }

    /** Pick the language-appropriate string of an ar/en pair. */
    public static function pick(string $ar, string $en): string
    {
        if (self::lang() === 'en') {
            return $en !== '' ? $en : $ar;
        }
        return $ar !== '' ? $ar : $en;
    }

    /* ══════════════════════════════════════════════════════════════
       RESPONSE ENVELOPE + CACHING
       ══════════════════════════════════════════════════════════════ */

    /**
     * Success envelope.
     *
     * @param mixed    $data
     * @param int|null $max_age Public cache TTL in seconds; null → private, no-store.
     */
    public static function ok($data, ?int $max_age = null): \WP_REST_Response
    {
        $body = [
            'ok'    => true,
            'data'  => $data,
            'error' => null,
        ];

        if ($max_age === null) {
            $response = new \WP_REST_Response($body, 200);
            $response->header('Cache-Control', 'private, no-store, max-age=0');
            return $response;
        }

        // Cacheable GET → strong ETag over the payload + the two dimensions it varies by.
        // `private`: these payloads vary by X-ZB-* location headers, which shared caches
        // (Cloudflare sits in front of this store) do not key on — a public entry could
        // serve one city's stock/promises to another. The app's own ETag cache is enough.
        $etag = '"' . md5(wp_json_encode($body) . '|' . self::lang() . '|' . self::city()) . '"';
        $inm  = self::$request instanceof \WP_REST_Request ? (string) self::$request->get_header('if_none_match') : '';

        if ($inm !== '' && self::etag_matches($inm, $etag)) {
            $response = new \WP_REST_Response(null, 304);
            $response->header('ETag', $etag);
            $response->header('Cache-Control', 'private, max-age=' . $max_age);
            return $response;
        }

        $response = new \WP_REST_Response($body, 200);
        $response->header('ETag', $etag);
        $response->header('Cache-Control', 'private, max-age=' . $max_age);
        return $response;
    }

    /** Error envelope. `$data` carries optional machine-readable context. */
    public static function fail(string $code, string $message_ar, string $message_en, int $status = 400, $data = null): \WP_REST_Response
    {
        $response = new \WP_REST_Response([
            'ok'    => false,
            'data'  => $data,
            'error' => [
                'code'       => $code,
                'message_ar' => $message_ar,
                'message_en' => $message_en,
                'message'    => self::pick($message_ar, $message_en),
            ],
        ], $status);
        $response->header('Cache-Control', 'private, no-store, max-age=0');
        return $response;
    }

    /** 401 envelope used by every bearer-only route. */
    public static function unauthorized(): \WP_REST_Response
    {
        return self::fail(
            'unauthorized',
            __('يرجى تسجيل الدخول أولاً', 'zooboxi'),
            'Please sign in first.',
            401
        );
    }

    /** Handles the `W/"…"` weak form and comma-separated lists. */
    private static function etag_matches(string $header, string $etag): bool
    {
        foreach (explode(',', $header) as $candidate) {
            $candidate = trim($candidate);
            if ($candidate === '*') {
                return true;
            }
            if (stripos($candidate, 'W/') === 0) {
                $candidate = trim(substr($candidate, 2));
            }
            if ($candidate === $etag) {
                return true;
            }
        }
        return false;
    }

    /* ══════════════════════════════════════════════════════════════
       ROUTES
       ══════════════════════════════════════════════════════════════ */

    public static function register_routes(): void
    {
        // Cheap lazy install: one option read per REST boot.
        Zooboxi_App_Tokens::maybe_install();

        $auth     = new Zooboxi_V2_Auth_Controller();
        $location = new Zooboxi_V2_Location_Controller();
        $catalog  = new Zooboxi_V2_Catalog_Controller();
        $cart     = new Zooboxi_V2_Cart_Controller();
        $checkout = new Zooboxi_V2_Checkout_Controller();
        $orders   = new Zooboxi_V2_Orders_Controller();
        $account  = new Zooboxi_V2_Account_Controller();
        $events   = new Zooboxi_V2_Events_Controller();
        $meta     = new Zooboxi_V2_Meta_Controller();

        $auth->register_routes();
        $location->register_routes();
        $catalog->register_routes();
        $cart->register_routes();
        $checkout->register_routes();
        $orders->register_routes();
        $account->register_routes();
        $events->register_routes();
        $meta->register_routes();
    }

    /**
     * Thin `register_rest_route` wrapper: every v2 route is publicly dispatchable and
     * enforces authorisation INSIDE the callback, so the app always receives our
     * envelope (never WordPress's bare rest_forbidden shape).
     */
    public static function route(string $path, string $methods, callable $callback, array $args = []): void
    {
        register_rest_route(self::NS, $path, [
            'methods'             => $methods,
            'callback'            => $callback,
            'permission_callback' => '__return_true',
            'args'                => $args,
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       ORDER STATUS → timeline stamps + Laravel mirror
       ══════════════════════════════════════════════════════════════ */

    /**
     * Additive hook: records `_zb_status_{status}_at` (fuels the app's order timeline)
     * and pushes the new delivery/payment status to sapconnect — the gap the original
     * one-shot push_order() left open. Never allowed to break an order transition.
     */
    public static function on_order_status_changed($order_id, $from, $to, $order = null): void
    {
        try {
            $order_id = (int) $order_id;
            $to       = sanitize_key((string) $to);
            if ($order_id <= 0 || $to === '') {
                return;
            }
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order($order_id);
            }
            if ($order instanceof \WC_Order) {
                $order->update_meta_data('_zb_status_' . $to . '_at', current_time('mysql'));
                // save_meta_data() only, never save(): this runs inside WooCommerce's own
                // status transition and must not re-write the order record underneath it.
                $order->save_meta_data();

                // The app's buy-again cache must hear about new/changed orders (the web
                // rail's own zbhome_buyagain_* buster lives in Zooboxi_Homepage).
                $customer_id = (int) $order->get_customer_id();
                if ($customer_id > 0) {
                    delete_transient('zb_v2_buyagain_' . $customer_id);
                }
            }

            if (class_exists('Zooboxi_Sync_Engine')) {
                (new Zooboxi_Sync_Engine())->push_order_status($order_id, $to);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi v2] order status hook failed: ' . $e->getMessage());
        }
    }
}
