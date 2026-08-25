<?php
/**
 * Zooboxi — Account experience (data engine + wiring)
 *
 * Everything the customer profile shows is derived from real order history.
 * No invented numbers: spend, item counts and savings all come from the
 * order records themselves, and the only "reward" we advertise is the
 * free-shipping threshold the store genuinely enforces
 * (zooboxi_free_shipping_min, honoured by the delivery engine).
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

/* ═══════════════════════════════════════════════════════════════════
   1. DATA ENGINE
   ═══════════════════════════════════════════════════════════════════ */

/** Order statuses that represent a real, counted purchase. */
function zooboxi_account_valid_statuses(): array
{
    return apply_filters('zooboxi_account_valid_statuses', ['processing', 'on-hold', 'completed', 'zb-ready']);
}

/** Statuses that mean the order is still on its way to the customer. */
function zooboxi_account_open_statuses(): array
{
    return apply_filters('zooboxi_account_open_statuses', ['pending', 'processing', 'on-hold', 'zb-ready']);
}

/** The store's real free-shipping threshold. */
function zooboxi_free_shipping_min(): float
{
    return (float) get_option('zooboxi_free_shipping_min', 200);
}

/**
 * Everything the profile needs, in one cached pass over the customer's orders.
 *
 * Cached for 10 minutes and busted whenever one of their orders changes, so a
 * customer who just ordered sees their new numbers immediately.
 */
function zooboxi_account_stats(int $user_id = 0): array
{
    $user_id = $user_id ?: get_current_user_id();
    if (!$user_id) {
        return zooboxi_account_stats_empty();
    }

    $key    = 'zbx_acct_' . $user_id;
    $cached = get_transient($key);
    if (is_array($cached) && ($cached['_v'] ?? 0) === 4) {
        return $cached;
    }

    $stats = zooboxi_account_stats_empty();

    $orders = wc_get_orders([
        'customer_id' => $user_id,
        'limit'       => 100,
        'orderby'     => 'date',
        'order'       => 'DESC',
        'status'      => array_merge(zooboxi_account_valid_statuses(), ['pending', 'cancelled', 'refunded']),
    ]);

    $free_min   = zooboxi_free_shipping_min();
    $valid      = zooboxi_account_valid_statuses();
    $open       = zooboxi_account_open_statuses();
    $products   = [];   // product_id => ['qty'=>, 'orders'=>, 'dates'=>[], 'last'=>, 'name'=>]
    $brands     = [];   // term_id => qty
    $months     = [];   // Y-m => spend

    foreach ($orders as $order) {
        if (!$order instanceof WC_Order) {
            continue;
        }
        $status  = $order->get_status();
        $created = $order->get_date_created();
        $ts      = $created ? $created->getTimestamp() : 0;

        // The newest still-moving order drives the live tracker.
        if (in_array($status, $open, true) && !$stats['active_order_id']) {
            $stats['active_order_id'] = $order->get_id();
        }

        if (!in_array($status, $valid, true)) {
            continue;
        }

        $total = (float) $order->get_total();
        $stats['orders_count']++;
        $stats['total_spent'] += $total;

        if ($ts) {
            $stats['last_order_ts'] = max($stats['last_order_ts'], $ts);
            $stats['first_order_ts'] = $stats['first_order_ts'] ? min($stats['first_order_ts'], $ts) : $ts;
            $months[gmdate('Y-m', $ts)] = ($months[gmdate('Y-m', $ts)] ?? 0) + $total;
        }

        // Real savings only: recorded discounts, plus waived delivery fees.
        $stats['savings'] += (float) $order->get_total_discount();
        if ((float) $order->get_shipping_total() <= 0 && (float) $order->get_subtotal() >= $free_min) {
            $stats['free_shipping_count']++;
        }

        foreach ($order->get_items() as $item) {
            if (!$item instanceof WC_Order_Item_Product) {
                continue;
            }
            $qty = (int) $item->get_quantity();
            $stats['items_count'] += $qty;

            $pid = $item->get_variation_id() ?: $item->get_product_id();
            if (!$pid) {
                continue;
            }
            if (!isset($products[$pid])) {
                $products[$pid] = ['qty' => 0, 'orders' => 0, 'dates' => [], 'name' => $item->get_name()];
            }
            $products[$pid]['qty'] += $qty;
            $products[$pid]['orders']++;
            if ($ts) {
                $products[$pid]['dates'][] = $ts;
            }

            $terms = get_the_terms($item->get_product_id(), 'product_brand');
            if (is_array($terms)) {
                foreach ($terms as $t) {
                    $brands[$t->term_id] = ($brands[$t->term_id] ?? 0) + $qty;
                }
            }
        }
    }

    // ── most-loved products (drives "اطلب مرة أخرى") ──
    uasort($products, static function ($a, $b) {
        return ($b['orders'] <=> $a['orders']) ?: ($b['qty'] <=> $a['qty']);
    });
    $stats['products'] = $products;

    // ── repeat-purchase rhythm: which staples are probably running out ──
    $due = [];
    foreach ($products as $pid => $p) {
        if (count($p['dates']) < 2) {
            continue;
        }
        $dates = $p['dates'];
        rsort($dates);
        $gaps = [];
        for ($i = 0; $i < count($dates) - 1; $i++) {
            $gap = ($dates[$i] - $dates[$i + 1]) / DAY_IN_SECONDS;
            if ($gap >= 3) {          // ignore split shipments of one basket
                $gaps[] = $gap;
            }
        }
        if (!$gaps) {
            continue;
        }
        $avg   = array_sum($gaps) / count($gaps);
        $since = (time() - $dates[0]) / DAY_IN_SECONDS;
        if ($avg > 0 && $since >= $avg * 0.8) {
            $due[$pid] = [
                'avg_days'   => (int) round($avg),
                'since_days' => (int) round($since),
                'ratio'      => $since / $avg,
            ];
        }
    }
    uasort($due, static fn($a, $b) => $b['ratio'] <=> $a['ratio']);
    $stats['due_products'] = $due;

    arsort($brands);
    $stats['top_brand_id'] = $brands ? (int) array_key_first($brands) : 0;

    // ── spend over the last 6 months, for the sparkline ──
    for ($i = 5; $i >= 0; $i--) {
        $m = gmdate('Y-m', strtotime("-{$i} months"));
        $stats['spend_months'][$m] = (float) ($months[$m] ?? 0);
    }

    $stats['avg_order'] = $stats['orders_count'] ? $stats['total_spent'] / $stats['orders_count'] : 0.0;
    $stats['tier']      = zooboxi_account_tier($stats['orders_count']);

    set_transient($key, $stats, 10 * MINUTE_IN_SECONDS);
    return $stats;
}

function zooboxi_account_stats_empty(): array
{
    return [
        '_v'                  => 4,
        'orders_count'        => 0,
        'total_spent'         => 0.0,
        'items_count'         => 0,
        'savings'             => 0.0,
        'free_shipping_count' => 0,
        'avg_order'           => 0.0,
        'first_order_ts'      => 0,
        'last_order_ts'       => 0,
        'active_order_id'     => 0,
        'products'            => [],
        'due_products'        => [],
        'spend_months'        => [],
        'top_brand_id'        => 0,
        'tier'                => zooboxi_account_tier(0),
    ];
}

/** Bust the cache the moment anything about the customer's orders changes. */
function zooboxi_account_flush_stats($order_id, $order = null): void
{
    $order = $order instanceof WC_Order ? $order : wc_get_order($order_id);
    if ($order && ($uid = $order->get_customer_id())) {
        delete_transient('zbx_acct_' . $uid);
    }
}
add_action('woocommerce_order_status_changed', function ($id, $from, $to, $order) {
    zooboxi_account_flush_stats($id, $order);
}, 10, 4);
add_action('woocommerce_new_order', 'zooboxi_account_flush_stats', 10, 2);
add_action('woocommerce_update_order', 'zooboxi_account_flush_stats', 10, 2);

/**
 * Recognition levels.
 *
 * These are status badges, NOT a promise of discounts — nothing here grants a
 * benefit the store hasn't actually configured. Filter `zooboxi_account_tiers`
 * to attach real perks later.
 */
function zooboxi_account_tiers(): array
{
    return apply_filters('zooboxi_account_tiers', [
        ['min' => 0,  'key' => 'new',   'name' => 'بداية الرحلة',  'icon' => '🐣', 'c1' => '#8fb9a8', 'c2' => '#6fa08d'],
        ['min' => 1,  'key' => 'friend', 'name' => 'صديق زوبوكسي', 'icon' => '🐾', 'c1' => '#5fb3b2', 'c2' => '#429d9c'],
        ['min' => 5,  'key' => 'star',  'name' => 'عميل مميّز',    'icon' => '⭐', 'c1' => '#e8a765', 'c2' => '#d48644'],
        ['min' => 12, 'key' => 'gold',  'name' => 'عميل ذهبي',     'icon' => '🏅', 'c1' => '#e0b341', 'c2' => '#c99320'],
        ['min' => 25, 'key' => 'amb',   'name' => 'سفير زوبوكسي',  'icon' => '👑', 'c1' => '#e07a63', 'c2' => '#d46856'],
    ]);
}

function zooboxi_account_tier(int $orders): array
{
    $tiers   = zooboxi_account_tiers();
    $current = $tiers[0];
    $next    = null;

    foreach ($tiers as $i => $t) {
        if ($orders >= $t['min']) {
            $current = $t;
            $next    = $tiers[$i + 1] ?? null;
        }
    }

    $span     = $next ? max(1, $next['min'] - $current['min']) : 1;
    $done     = $next ? max(0, $orders - $current['min']) : $span;
    $progress = $next ? min(100, (int) round($done / $span * 100)) : 100;

    return [
        'key'      => $current['key'],
        'name'     => $current['name'],
        'icon'     => $current['icon'],
        'c1'       => $current['c1'],
        'c2'       => $current['c2'],
        'next'     => $next ? $next['name'] : '',
        'next_icon' => $next ? $next['icon'] : '',
        'remaining' => $next ? max(0, $next['min'] - $orders) : 0,
        'progress' => $progress,
    ];
}

/* ── Arabic order vocabulary ─────────────────────────────────────── */

function zooboxi_status_ar(string $status): string
{
    $status = str_replace('wc-', '', $status);
    $map = [
        'pending'    => 'بانتظار الدفع',
        'processing' => 'قيد التجهيز',
        'zb-ready'   => 'جاهز للتسليم',
        'on-hold'    => 'قيد المراجعة',
        'completed'  => 'تم التسليم',
        'cancelled'  => 'ملغي',
        'refunded'   => 'مسترجع',
        'failed'     => 'فشل الدفع',
        'draft'      => 'مسودة',
    ];
    return $map[$status] ?? wc_get_order_status_name($status);
}

/** Colour family per status, so a pill reads correctly at a glance. */
function zooboxi_status_tone(string $status): string
{
    $status = str_replace('wc-', '', $status);
    $tones = [
        'completed'  => 'ok',
        'zb-ready'   => 'go',
        'processing' => 'work',
        'pending'    => 'wait',
        'on-hold'    => 'wait',
        'cancelled'  => 'dead',
        'failed'     => 'dead',
        'refunded'   => 'dead',
    ];
    return $tones[$status] ?? 'work';
}

function zooboxi_delivery_type_ar(string $type): array
{
    $map = [
        'express'  => ['⚡', 'توصيل سريع', 'خلال ساعتين'],
        'standard' => ['🚚', 'توصيل عادي', 'خلال 24 ساعة'],
        'shipping' => ['📦', 'شحن عادي', '4–5 أيام عمل'],
    ];
    return $map[$type] ?? ['📍', 'توصيل', ''];
}

/**
 * The journey of one order as a 4-step timeline.
 * Cancelled/refunded orders short-circuit to a single honest state.
 */
function zooboxi_order_timeline(WC_Order $order): array
{
    $status = $order->get_status();

    if (in_array($status, ['cancelled', 'refunded', 'failed'], true)) {
        return ['dead' => true, 'label' => zooboxi_status_ar($status), 'steps' => []];
    }

    $order_of = ['pending' => 0, 'processing' => 1, 'zb-ready' => 2, 'on-hold' => 1, 'completed' => 3];
    $at       = $order_of[$status] ?? 1;

    $steps = [
        ['icon' => '🧾', 'title' => 'تم استلام الطلب', 'note' => 'وصلنا طلبك بنجاح'],
        ['icon' => '📦', 'title' => 'قيد التجهيز',     'note' => 'نجهّز أصنافك من المستودع'],
        ['icon' => '🛵', 'title' => 'جاهز للتسليم',    'note' => 'الطلب في طريقه إليك'],
        ['icon' => '🏠', 'title' => 'تم التسليم',      'note' => 'وصل الطلب — نتمنى يعجبكم'],
    ];

    foreach ($steps as $i => &$s) {
        $s['state'] = $i < $at ? 'done' : ($i === $at ? 'now' : 'next');
    }
    unset($s);

    return ['dead' => false, 'label' => zooboxi_status_ar($status), 'steps' => $steps, 'at' => $at];
}

/**
 * Arabic dates from a timestamp.
 *
 * The site locale is en_US, so date_i18n() would return English month names —
 * we spell them out ourselves. (zooboxi_date_ar() takes a WC_DateTime and is
 * used on the thank-you page; this one takes a plain timestamp.)
 */
function zooboxi_date_ar_ts(int $ts, bool $with_day = true): string
{
    if (!$ts) {
        return '';
    }
    static $months = [
        1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل', 5 => 'مايو', 6 => 'يونيو',
        7 => 'يوليو', 8 => 'أغسطس', 9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر',
    ];
    $tz = wp_timezone();
    $d  = (new DateTimeImmutable('@' . $ts))->setTimezone($tz);
    $m  = $months[(int) $d->format('n')] ?? '';
    return $with_day
        ? (int) $d->format('j') . ' ' . $m . ' ' . $d->format('Y')
        : $m . ' ' . $d->format('Y');
}

/** "قبل 3 أيام" — relative time that stays readable in Arabic. */
function zooboxi_ago_ar(int $ts): string
{
    if (!$ts) {
        return '';
    }
    $s = time() - $ts;
    if ($s < 90) {
        return 'الآن';
    }
    $m = (int) round($s / 60);
    if ($m < 60) {
        return 'قبل ' . $m . ' دقيقة';
    }
    $h = (int) round($m / 60);
    if ($h < 24) {
        return $h === 1 ? 'قبل ساعة' : ($h === 2 ? 'قبل ساعتين' : 'قبل ' . $h . ' ساعات');
    }
    $d = (int) round($h / 24);
    if ($d < 30) {
        return $d === 1 ? 'أمس' : ($d === 2 ? 'قبل يومين' : 'قبل ' . $d . ' يوم');
    }
    $mo = (int) round($d / 30);
    if ($mo < 12) {
        return $mo === 1 ? 'قبل شهر' : ($mo === 2 ? 'قبل شهرين' : 'قبل ' . $mo . ' أشهر');
    }
    $y = (int) round($mo / 12);
    return $y === 1 ? 'قبل سنة' : 'قبل ' . $y . ' سنوات';
}

/** Arabic plural for a count of items. */
function zooboxi_count_ar(int $n, string $one, string $two, string $few, string $many): string
{
    if ($n === 1) {
        return $one;
    }
    if ($n === 2) {
        return $two;
    }
    if ($n <= 10) {
        return $n . ' ' . $few;
    }
    return $n . ' ' . $many;
}

/** Initials for the avatar — works for phone-only accounts with no gravatar. */
function zooboxi_account_initials(WP_User $user): string
{
    $name = trim($user->first_name . ' ' . $user->last_name);
    if ($name === '') {
        $name = trim((string) get_user_meta($user->ID, 'billing_first_name', true));
    }
    if ($name === '') {
        $name = $user->display_name;
    }
    $name = trim(preg_replace('/^zb[_-]?\d+$/u', '', $name));
    if ($name === '') {
        return '🐾';
    }
    $parts = preg_split('/\s+/u', $name);
    $out   = mb_substr($parts[0], 0, 1, 'UTF-8');
    if (isset($parts[1])) {
        $out .= mb_substr($parts[1], 0, 1, 'UTF-8');
    }
    return $out;
}

/** A name we can greet with, never an internal "zb_5xxxxxxxx" login. */
function zooboxi_account_display_name(WP_User $user): string
{
    $candidates = [
        trim($user->first_name . ' ' . $user->last_name),
        (string) get_user_meta($user->ID, 'billing_first_name', true),
        $user->display_name,
    ];
    foreach ($candidates as $c) {
        $c = trim($c);
        if ($c !== '' && !preg_match('/^zb[_-]?\d+/u', $c)) {
            return $c;
        }
    }
    return 'صديقنا';
}

/** Internal placeholder addresses must never be shown as the customer's email. */
function zooboxi_is_internal_email(string $email): bool
{
    return $email !== '' && str_ends_with(strtolower($email), '@zooboxi.local');
}

/* ═══════════════════════════════════════════════════════════════════
   2. NAVIGATION — Arabic, icon-led, physical-goods only
   ═══════════════════════════════════════════════════════════════════ */

add_filter('woocommerce_account_menu_items', function ($items) {
    // The store sells physical pet supplies — a downloads tab is dead weight.
    unset($items['downloads']);

    $ordered = [
        'dashboard'       => 'لوحتي',
        'orders'          => 'طلباتي',
        'my-products'     => 'مشترياتي',
        'edit-address'    => 'عناويني',
        'edit-account'    => 'بياناتي',
        'customer-logout' => 'تسجيل الخروج',
    ];

    $out = [];
    foreach ($ordered as $key => $label) {
        if ($key === 'my-products' || isset($items[$key])) {
            $out[$key] = $label;
        }
    }
    // keep anything a plugin added that we didn't explicitly order
    foreach ($items as $k => $v) {
        if (!isset($out[$k])) {
            $out[$k] = $v;
        }
    }
    return $out;
}, 20);

add_filter('woocommerce_account_menu_item_classes', function ($classes, $endpoint) {
    $classes[] = 'zbx-nav-item';
    $classes[] = 'zbx-nav--' . $endpoint;
    return $classes;
}, 10, 2);

/** Icon per tab, used by the nav template. */
function zooboxi_account_menu_icon(string $endpoint): string
{
    $icons = [
        'dashboard'       => '🏠',
        'orders'          => '🧾',
        'my-products'     => '🛍️',
        'wishlist'        => '💚',
        'edit-address'    => '📍',
        'edit-account'    => '👤',
        'customer-logout' => '↩️',
        'downloads'       => '⬇️',
    ];
    return $icons[$endpoint] ?? '•';
}

/* ── the extra "مشترياتي" endpoint ───────────────────────────────── */

/**
 * WC_Query::add_endpoints() reads woocommerce_get_query_vars on init and
 * registers the rewrite for us — we only have to flush once afterwards.
 */
add_filter('woocommerce_get_query_vars', function ($vars) {
    $vars['my-products'] = 'my-products';
    return $vars;
});

add_action('init', function () {
    if (get_option('zbx_account_rewrites') !== '5') {
        flush_rewrite_rules(false);
        update_option('zbx_account_rewrites', '5');
    }
}, 20);

add_filter('woocommerce_endpoint_my-products_title', fn() => 'مشترياتي');

add_action('woocommerce_account_my-products_endpoint', function () {
    wc_get_template('myaccount/my-products.php');
});

/* Arabic page/endpoint titles for the built-in tabs too. */
foreach ([
    'orders'       => 'طلباتي',
    'edit-address' => 'عناويني',
    'edit-account' => 'بياناتي',
    'view-order'   => 'تفاصيل الطلب',
    'order-received' => 'تم استلام طلبك',
] as $ep => $title) {
    add_filter("woocommerce_endpoint_{$ep}_title", fn() => $title, 20);
}

/* ═══════════════════════════════════════════════════════════════════
   3. FORM FIXES
   ═══════════════════════════════════════════════════════════════════ */

/**
 * Phone-login customers carry a synthetic zb_…@zooboxi.local address.
 * We show them an empty, optional-looking field; if they leave it empty we
 * quietly keep the internal one so WooCommerce's required-email check passes.
 */
add_action('template_redirect', function () {
    if (empty($_POST['save_account_details']) || !is_user_logged_in()) {
        return;
    }
    if (isset($_POST['account_email']) && trim((string) $_POST['account_email']) === '') {
        $user = wp_get_current_user();
        if (zooboxi_is_internal_email($user->user_email)) {
            $_POST['account_email'] = $user->user_email;
        }
    }
}, 5);

/** Arabic labels + helpful placeholders on the account-details form. */
add_filter('gettext', function ($translated, $original, $domain) {
    if ($domain !== 'woocommerce') {
        return $translated;
    }
    // gettext fires long before the query is parsed; asking is_account_page()
    // that early throws a _doing_it_wrong notice, so we resolve it once, lazily.
    static $on = null;
    if ($on === null) {
        if (!did_action('wp')) {
            return $translated;
        }
        $on = function_exists('is_account_page') && is_account_page();
    }
    if (!$on) {
        return $translated;
    }

    static $map = null;
    if ($map !== null) {
        return $map[$original] ?? $translated;
    }
    $map = [
        'First name'                  => 'الاسم الأول',
        'Last name'                   => 'اسم العائلة',
        'Display name'                => 'الاسم الظاهر',
        'Email address'               => 'البريد الإلكتروني',
        'Password change'             => 'تغيير كلمة المرور',
        'Current password (leave blank to leave unchanged)' => 'كلمة المرور الحالية (اتركها فارغة لعدم التغيير)',
        'New password (leave blank to leave unchanged)'     => 'كلمة المرور الجديدة (اتركها فارغة لعدم التغيير)',
        'Confirm new password'        => 'تأكيد كلمة المرور الجديدة',
        'Save changes'                => 'حفظ التعديلات',
        'Billing address'             => 'عنوان التوصيل',
        'Shipping address'            => 'عنوان الشحن',
        'Save address'                => 'حفظ العنوان',
        'Add address'                 => 'إضافة عنوان',
        'Edit address'                => 'تعديل العنوان',
        'You have not set up this type of address yet.' => 'لم تضف هذا العنوان بعد.',
        'Company name'                => 'اسم الشركة',
        'Country / Region'            => 'الدولة',
        'Street address'              => 'العنوان',
        'Town / City'                 => 'المدينة',
        'Postcode / ZIP'              => 'الرمز البريدي',
        'Phone'                       => 'رقم الجوال',
        'State / County'              => 'المنطقة',
        'House number and street name' => 'اسم الشارع ورقم المبنى',
        'Apartment, suite, unit, etc.' => 'الحي / تفاصيل إضافية',
        'Username'                    => 'اسم المستخدم أو رقم الجوال',
        'Password'                    => 'كلمة المرور',
        'Remember me'                 => 'تذكّرني',
        'Lost your password?'         => 'نسيت كلمة المرور؟',
        'Log in'                      => 'تسجيل الدخول',
        'Register'                    => 'حساب جديد',
        'Order'                       => 'الطلب',
        'Date'                        => 'التاريخ',
        'Status'                      => 'الحالة',
        'Total'                       => 'الإجمالي',
        'Actions'                     => 'إجراءات',
        'View'                        => 'عرض',
        'Pay'                         => 'ادفع الآن',
        'Cancel'                      => 'إلغاء',
        // order-details table
        'Product'                     => 'المنتج',
        'Quantity'                    => 'الكمية',
        'Price'                       => 'السعر',
        'Subtotal'                    => 'المجموع قبل الضريبة',
        'Shipping'                    => 'التوصيل',
        'Payment method'              => 'طريقة الدفع',
        'Payment method:'             => 'طريقة الدفع:',
        'Order details'               => 'تفاصيل الطلب',
        'Order updates'               => 'تحديثات الطلب',
        'Note'                        => 'ملاحظة',
        'Free!'                       => 'مجاني',
        'Email'                       => 'البريد الإلكتروني',
        'Order again'                 => 'أعد الطلب',
        'No order has been made yet.' => 'لا توجد طلبات بعد.',
        'Browse products'             => 'تصفّح المنتجات',
        'Make a payment'              => 'إتمام الدفع',
        'Account details'             => 'بياناتي',
        'Addresses'                   => 'عناويني',
        'Orders'                      => 'طلباتي',
        'Dashboard'                   => 'لوحتي',
        'Log out'                     => 'تسجيل الخروج',
        'The following addresses will be used on the checkout page by default.' => 'هذه العناوين تُستخدم تلقائياً عند إتمام الطلب.',
    ];
    return $map[$original] ?? $translated;
}, 20, 3);

/**
 * Product thumbnails inside the order-details table.
 *
 * Guarded to account pages so order emails and admin screens keep the plain
 * text name.
 */
add_filter('woocommerce_order_item_name', function ($name, $item) {
    if (!is_account_page() || is_admin() || !$item instanceof WC_Order_Item_Product) {
        return $name;
    }
    $product = $item->get_product();
    if (!$product) {
        return $name;
    }
    return '<span class="zbx-oi-thumb">' . $product->get_image('woocommerce_gallery_thumbnail') . '</span>' . $name;
}, 10, 2);

/** "×2" instead of a bare strong tag, so quantity reads clearly in Arabic. */
add_filter('woocommerce_order_item_quantity_html', function ($html, $item) {
    if (!is_account_page()) {
        return $html;
    }
    $qty = (int) $item->get_quantity();
    // dir=ltr + isolation, or bidi reorders "×2" into "2×" beside Arabic text
    return $qty > 1 ? ' <strong class="product-quantity" dir="ltr">×' . $qty . '</strong>' : '';
}, 10, 2);

/* ═══════════════════════════════════════════════════════════════════
   4. ASSETS
   ═══════════════════════════════════════════════════════════════════ */

add_action('wp_enqueue_scripts', function () {
    if (!function_exists('is_account_page') || !is_account_page()) {
        return;
    }
    $dir = get_stylesheet_directory();
    $uri = get_stylesheet_directory_uri();

    $css = $dir . '/css/zbx-account.css';
    if (file_exists($css)) {
        wp_enqueue_style('zooboxi-account', $uri . '/css/zbx-account.css', ['zooboxi-child'], (string) filemtime($css));
    }

    $f = $dir . '/js/zbx-account.js';
    if (file_exists($f)) {
        wp_enqueue_script('zooboxi-account', $uri . '/js/zbx-account.js', ['jquery'], (string) filemtime($f), true);
        wp_localize_script('zooboxi-account', 'zbxAccount', [
            'ajax'  => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce('zbx-account'),
            'cart'  => wc_get_cart_url(),
        ]);
    }
}, 20);

/* ── one-tap reorder of a whole past order ───────────────────────── */

add_action('wp_ajax_zbx_reorder', function () {
    check_ajax_referer('zbx-account', 'nonce');

    $order = wc_get_order(absint($_POST['order_id'] ?? 0));
    if (!$order || (int) $order->get_customer_id() !== get_current_user_id()) {
        wp_send_json_error(['message' => 'تعذّر العثور على الطلب'], 404);
    }

    $added = 0;
    $gone  = [];
    foreach ($order->get_items() as $item) {
        if (!$item instanceof WC_Order_Item_Product) {
            continue;
        }
        $product = $item->get_product();
        if (!$product || !$product->is_purchasable() || !$product->is_in_stock()) {
            $gone[] = $item->get_name();
            continue;
        }
        $ok = WC()->cart->add_to_cart(
            $item->get_product_id(),
            max(1, (int) $item->get_quantity()),
            $item->get_variation_id() ?: 0
        );
        if ($ok) {
            $added++;
        } else {
            $gone[] = $item->get_name();
        }
    }

    if (!$added) {
        wp_send_json_error(['message' => 'أصناف هذا الطلب غير متوفرة حالياً'], 409);
    }

    wp_send_json_success([
        'added'   => $added,
        'missing' => $gone,
        'message' => $added . (count($gone) ? ' من الأصناف أُضيفت للسلة' : ' أصناف أُضيفت للسلة'),
    ]);
});
