<?php
/**
 * Core: theme setup, language, icons, money.
 */

defined('ABSPATH') || exit;

add_action('after_setup_theme', static function () {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', ['search-form', 'gallery', 'caption', 'style', 'script']);
    add_theme_support('woocommerce', [
        'thumbnail_image_width' => 300,
        'single_image_width'    => 600,
        'product_grid'          => ['default_columns' => 4, 'min_columns' => 2, 'max_columns' => 5],
    ]);
    add_theme_support('responsive-embeds');
});

/** Pages read better without WordPress's admin bar pushing the sticky header. */
add_filter('show_admin_bar', static fn($show) => $show && current_user_can('manage_woocommerce'));

/* ══════════════════════════════════════════════════════════════
   LANGUAGE
   The store is Arabic; Polylang serves a thin English mirror.
   ══════════════════════════════════════════════════════════════ */

function zv_lang(): string
{
    static $lang = null;
    if ($lang === null) {
        $lang = (function_exists('pll_current_language') && pll_current_language() === 'en') ? 'en' : 'ar';
    }
    return $lang;
}

/** One string, both languages, chosen at render time. */
function zv_t(string $ar, string $en = ''): string
{
    return zv_lang() === 'en' && $en !== '' ? $en : $ar;
}

function zv_e(string $ar, string $en = ''): void
{
    echo esc_html(zv_t($ar, $en));
}

/** Arabic plural for counted nouns: 1 منتج / 2 منتجان / 3-10 منتجات / 11+ منتجاً. */
function zv_count(int $n, string $one, string $two, string $few, string $many): string
{
    if ($n === 1) {
        return $one;
    }
    if ($n === 2) {
        return $two;
    }
    $mod = $n % 100;
    $word = ($mod >= 3 && $mod <= 10) ? $few : $many;
    return number_format_i18n($n) . ' ' . $word;
}

/* ══════════════════════════════════════════════════════════════
   MONEY
   ﷼ (U+FDFC) is drawn as the official riyal sign by the bundled
   ZbRiyal face; anywhere that face is missing it still reads ﷼.
   ══════════════════════════════════════════════════════════════ */

add_filter('woocommerce_currency_symbol', static function ($symbol, $currency) {
    return $currency === 'SAR' ? '﷼' : $symbol;
}, 20, 2);

/** Saudi number format: 1,234.50 (display only — WooCommerce stores the raw decimal). */
add_filter('wc_get_price_decimal_separator', static fn() => '.', 20);
add_filter('wc_get_price_thousand_separator', static fn() => ',', 20);

function zv_num(float $amount): string
{
    return number_format($amount, 2, '.', ',');
}

/**
 * Whether the plugin measures free-delivery thresholds on shelf prices (VAT included).
 * Plugins that have Zooboxi_Delivery_Engine::threshold_total() do; older ones compared
 * the pre-VAT subtotal, so 150 before VAT was 172.50 on the shelf.
 */
function zv_free_inclusive(): bool
{
    return (bool) apply_filters('zooboxi_free_threshold_inclusive', method_exists('Zooboxi_Delivery_Engine', 'threshold_total'));
}

/** A free-delivery threshold as the customer will meet it, in shelf prices. */
function zv_free_display(float $min): float
{
    return zv_free_inclusive() ? $min : round($min * 1.15, 2);
}

/** A price as one unbreakable unit: the figure and the riyal sign. */
function zv_money(float $amount, string $class = ''): string
{
    return '<span class="zv-money' . ($class ? ' ' . esc_attr($class) : '') . '"><bdi>' . esc_html(zv_num($amount)) . '</bdi>&nbsp;<span class="zv-sar" aria-label="' . esc_attr(zv_t('ريال', 'SAR')) . '">﷼</span></span>';
}

/* ══════════════════════════════════════════════════════════════
   ICONS — one stroke family (24 grid, 1.9 stroke, round caps)
   ══════════════════════════════════════════════════════════════ */

function zv_icon(string $name, int $size = 20, string $class = ''): string
{
    static $paths = [
        'search'   => '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.6-3.6"/>',
        'user'     => '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
        'heart'    => '<path d="M12 20s-7-4.4-9-9a4.8 4.8 0 0 1 9-3 4.8 4.8 0 0 1 9 3c-2 4.6-9 9-9 9z"/>',
        'bag'      => '<path d="M5 8h14l-1 12H6L5 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
        'pin'      => '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
        'bolt'     => '<path d="M13 3 5 13h6l-1 8 8-10h-6l1-8z"/>',
        'truck'    => '<path d="M3 7h11v9H3zM14 10h4l3 3v3h-7"/><circle cx="7" cy="18" r="1.6"/><circle cx="17" cy="18" r="1.6"/>',
        'box'      => '<path d="M3 8l9-5 9 5v8l-9 5-9-5V8z"/><path d="M3 8l9 5 9-5M12 13v8"/>',
        'store'    => '<path d="M4 10h16v10H4zM3 10l2-6h14l2 6"/><path d="M10 20v-5h4v5"/>',
        'down'     => '<path d="m6 9 6 6 6-6"/>',
        'up'       => '<path d="m6 15 6-6 6 6"/>',
        'left'     => '<path d="m15 6-6 6 6 6"/>',
        'right'    => '<path d="m9 6 6 6-6 6"/>',
        'back'     => '<path d="M5 12h14m-6-6 6 6-6 6"/>',
        'more'     => '<path d="M19 12H5m6-6-6 6 6 6"/>',
        'plus'     => '<path d="M12 5v14M5 12h14"/>',
        'minus'    => '<path d="M5 12h14"/>',
        'close'    => '<path d="M6 6l12 12M18 6 6 18"/>',
        'menu'     => '<path d="M4 7h16M4 12h16M4 17h16"/>',
        'filter'   => '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M18 18h2"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="16" cy="18" r="2"/>',
        'sort'     => '<path d="M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4"/>',
        'check'    => '<path d="m5 12 4.5 4.5L19 7"/>',
        'shield'   => '<path d="M12 3 5 6v6c0 4.4 3 7.6 7 9 4-1.4 7-4.6 7-9V6l-7-3z"/><path d="m9 12 2 2 4-4"/>',
        'return'   => '<path d="M4 9h11a5 5 0 0 1 0 10H8"/><path d="M8 5 4 9l4 4"/>',
        'card'     => '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M3 10h18"/>',
        'grid'     => '<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>',
        'home'     => '<path d="M4 11 12 4l8 7v9h-5v-6H9v6H4z"/>',
        'trash'    => '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
        'gift'     => '<path d="M4 11h16v9H4zM3 7h18v4H3zM12 7v13"/><path d="M12 7c-2-3-6-3-6-1s4 1 6 1zm0 0c2-3 6-3 6-1s-4 1-6 1z"/>',
        'clock'    => '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
        'mail'     => '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
        'scan'     => '<path d="M4 7V5h3M17 5h3v2M20 17v2h-3M7 19H4v-2M8 9v6M11 9v6M14 9v6M17 9v6"/>',
        'locate'   => '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/><circle cx="12" cy="12" r="7"/>',
        'sparkle'  => '<path d="M12 3c.6 4.2 2.8 6.4 7 7-4.2.6-6.4 2.8-7 7-.6-4.2-2.8-6.4-7-7 4.2-.6 6.4-2.8 7-7z"/>',
        'info'     => '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>',
        'tag'      => '<path d="M3 12V4h8l10 10-8 8L3 12z"/><circle cx="7.5" cy="8.5" r="1.5"/>',
        'whatsapp' => '<path d="M4 20l1.3-4A8 8 0 1 1 8 18.7L4 20z"/><path d="M9 9.5c0 3 2.5 5.5 5.5 5.5l1-1.5-2-1-1 .8a4 4 0 0 1-1.8-1.8l.8-1-1-2L9 9.5z"/>',
        // departments
        'bowl'     => '<path d="M3 12h18c0 4.2-4 7-9 7s-9-2.8-9-7z"/><path d="M8.5 9.2h.01M12 8h.01M15.5 9.2h.01"/>',
        'litter'   => '<path d="M7.5 4h9l2.5 4v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V8l2.5-4z"/><path d="M5 8h14M9.5 13h.01M12 15.5h.01M14.5 13h.01"/>',
        'litterbox'=> '<path d="M3 10h18l-2 8.5H5L3 10z"/><path d="M7 10c1.2-2 2.8-3 5-3s3.8 1 5 3"/>',
        'bone'     => '<path d="M17 10c.7-.7 1.7 0 2.5 0a2.5 2.5 0 1 0 0-5 .5.5 0 0 1-.5-.5 2.5 2.5 0 1 0-5 0c0 .8.7 1.8 0 2.5l-7 7c-.7.7-1.7 0-2.5 0a2.5 2.5 0 0 0 0 5c.3 0 .5.2.5.5a2.5 2.5 0 1 0 5 0c0-.8-.7-1.8 0-2.5z"/>',
        'health'   => '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7z"/><path d="M3.5 12h6l.5-1 2 4.5 2-7 1.5 3.5h5"/>',
        'brush'    => '<path d="m9 11.9 8.1-8.1a2.9 2.9 0 1 1 4 4L13 15.9"/><path d="M7 15c-1.7 0-3 1.3-3 3 0 1.3-2.5 1.5-2 2 1.1 1.1 2.5 2 4 2 2.2 0 4-1.8 4-4a3 3 0 0 0-3-3z"/>',
        'toy'      => '<circle cx="12" cy="12" r="8.5"/><path d="M4.2 9.6c4 1 8.6 4.3 10.6 10.2M19.8 14.4c-4-1-8.6-4.3-10.6-10.2"/>',
        'cage'     => '<path d="M5 20V10a7 7 0 0 1 14 0v10"/><path d="M3 20h18M9.5 20V5.4M14.5 20V5.4M12 3v0"/>',
        'globe'    => '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.6 3.5 5.4 3.5 8.5s-1.1 5.9-3.5 8.5c-2.4-2.6-3.5-5.4-3.5-8.5s1.1-5.9 3.5-8.5z"/>',
        'calendar' => '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    ];
    $p = $paths[$name] ?? $paths['info'];
    $fill = $name === 'bolt-solid' ? 'currentColor' : 'none';
    return '<svg class="zv-i' . ($class ? ' ' . esc_attr($class) : '') . '" width="' . $size . '" height="' . $size . '" viewBox="0 0 24 24" fill="' . $fill . '" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' . $p . '</svg>';
}

/** The express bolt is a solid mark — the one filled icon in the set. */
function zv_bolt(int $size = 14): string
{
    return '<svg class="zv-i zv-i--bolt" width="' . $size . '" height="' . $size . '" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false"><path d="M13 3 5 13h6l-1 8 8-10h-6l1-8z"/></svg>';
}

function zv_img(string $file): string
{
    return ZV_URI . '/assets/img/' . $file;
}

/** The brand mark, never cropped (owner's rule). */
function zv_logo(int $height = 56): string
{
    $w = (int) round($height * 440 / 378);
    return '<img class="zv-logo" src="' . esc_url(zv_img('logo-full.webp')) . '" width="' . $w . '" height="' . $height . '" alt="' . esc_attr(zv_t('زوبوكسي', 'Zooboxi')) . '">';
}

/** Characters that stand for each pet (generated once from the logo, owner-approved). */
function zv_species_art(string $species): string
{
    $map = ['cat' => 'cat-sit-up.webp', 'dog' => 'dog-sit-up.webp', 'bird' => 'budgie.webp', 'small' => 'hamster.webp'];
    return zv_img($map[$species] ?? 'cat-sit-up.webp');
}

/** «للقطط» — the pet as the object of «تسوّق», with its article. */
function zv_for_pet(string $species, string $name): string
{
    $ar = ['cat' => 'للقطط', 'dog' => 'للكلاب', 'bird' => 'للطيور', 'small' => 'للحيوانات الصغيرة'];
    return zv_lang() === 'en' ? 'for ' . $name : ($ar[$species] ?? 'لـ' . $name);
}

/** Soft pastel per pet, used behind its character. */
function zv_species_tint(string $species): string
{
    $map = ['cat' => 'peach', 'dog' => 'mint', 'bird' => 'butter', 'small' => 'lilac'];
    return $map[$species] ?? 'peach';
}

/** Customer-facing copy must never name a branch or a warehouse (owner's rule). */
function zv_clean_copy(string $text): string
{
    $text = preg_replace('/\s*[-–—·:]?\s*(فرع|مستودع)\s+[^\s،,.()]+(\s+[^\s،,.()]+)?/u', '', $text);
    return trim((string) $text);
}

/** Strip the decorative emoji the catalogue copy carries (🐱 … ✨). */
function zv_strip_emoji(string $text): string
{
    return trim((string) preg_replace('/[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}\x{200D}]/u', '', $text));
}
