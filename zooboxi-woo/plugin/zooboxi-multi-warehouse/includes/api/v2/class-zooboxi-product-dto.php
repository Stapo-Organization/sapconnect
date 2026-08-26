<?php
/**
 * Zooboxi_Product_DTO — the ONE serializer every v2 endpoint uses for a product.
 *
 * Field allowlists only: nothing is ever pass-through'd from post meta, so SAP costs,
 * wholesale price lists and internal intelligence scores can never leak to the app.
 * Prices are the retail WooCommerce prices and nothing else.
 *
 * Location awareness is free here: the bootstrap seeded the customer's coordinates into
 * $_COOKIE, so `$product->get_stock_quantity()` is already filtered to what the customer
 * can actually receive (Zooboxi_Plugin::filter_stock_for_customer).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Product_DTO
{
    /** Displayed stock is capped — an exact warehouse count is commercial information. */
    private const STOCK_DISPLAY_CAP = 99;

    /** Recommendations proxy cache. */
    private const RECS_TTL = 1800; // 30 minutes

    /**
     * Canonical emoji-swatch keyword map (moved here from the theme's quick-view so the
     * app and the web read ONE source). Matched case-insensitively as a substring of the
     * option label; first hit wins, so the order of the keys is meaningful.
     */
    public const SWATCH_EMOJI = [
        // Size
        'صغير' => '🐾', 'وسط' => '🐕', 'كبير' => '🦁', 'ضخم' => '🐘',
        'small' => '🐾', 'medium' => '🐕', 'large' => '🦁', 'xlarge' => '🐘',
        'xs' => '🐾', 's' => '🐾', 'm' => '🐕', 'l' => '🦁', 'xl' => '🐘', 'xxl' => '🐘',
        // Weight / quantity
        'جرام' => '⚖️', 'كيلو' => '⚖️', 'غ' => '⚖️', 'كجم' => '⚖️',
        'g' => '⚖️', 'kg' => '⚖️', 'lb' => '⚖️', 'oz' => '⚖️',
        // Count
        'حبة' => '📦', 'حبات' => '📦', 'قطعة' => '📦', 'عبوة' => '📦', 'علبة' => '📦',
        'pack' => '📦', 'pcs' => '📦', 'piece' => '📦', 'box' => '📦',
        // Flavor
        'دجاج' => '🍗', 'لحم' => '🥩', 'سمك' => '🐟', 'سلمون' => '🐟', 'تونة' => '🐟',
        'chicken' => '🍗', 'beef' => '🥩', 'fish' => '🐟', 'salmon' => '🐟', 'tuna' => '🐟',
        'lamb' => '🐑', 'turkey' => '🦃', 'duck' => '🦆', 'شريمب' => '🦐', 'shrimp' => '🦐',
        // Color
        'أحمر' => '🔴', 'أزرق' => '🔵', 'أخضر' => '🟢', 'أسود' => '⚫', 'أبيض' => '⚪',
        'أصفر' => '🟡', 'وردي' => '🩷', 'بنفسجي' => '🟣', 'برتقالي' => '🟠',
        'red' => '🔴', 'blue' => '🔵', 'green' => '🟢', 'black' => '⚫', 'white' => '⚪',
        'yellow' => '🟡', 'pink' => '🩷', 'purple' => '🟣', 'orange' => '🟠', 'brown' => '🟤',
        'grey' => '⬜', 'gray' => '⬜', 'رمادي' => '⬜',
    ];

    private const SWATCH_DEFAULT = '🏷️';

    /* ══════════════════════════════════════════════════════════════
       CARD
       ══════════════════════════════════════════════════════════════ */

    /**
     * The compact product shape used by every list, rail and search result.
     *
     * @param \WC_Product|int $product
     */
    public static function card($product): ?array
    {
        $product = self::resolve($product);
        if (!$product) {
            return null;
        }

        $id     = $product->get_id();
        $badges = self::badges($id);
        $prices = self::prices($product);

        return [
            'id'            => $id,
            'item_code'     => (string) get_post_meta($id, '_zooboxi_item_code', true),
            'sku'           => (string) $product->get_sku(),
            'name'          => wp_strip_all_tags($product->get_name()),
            'slug'          => $product->get_slug(),
            'brand'         => self::brand($id),
            'image'         => self::image_url($product, 'woocommerce_single'),
            'gallery_thumb' => self::image_url($product, 'woocommerce_thumbnail'),
            'price'         => $prices['price'],
            'regular_price' => $prices['regular_price'],
            'sale_price'    => $prices['sale_price'],
            'on_sale'       => $prices['on_sale'],
            'price_from'    => $prices['price_from'],
            'discount_pct'  => $prices['discount_pct'],
            'currency'      => 'SAR',
            'stock_status'  => $product->is_in_stock() ? 'instock' : 'outofstock',
            'stock_qty'     => self::stock_qty($product),
            'is_variable'   => $product->is_type('variable'),
            'badge'         => $badges[0] ?? null,
            'delivery_chip' => self::delivery_chip($id),
            'wishlisted'    => self::is_wishlisted($id),
        ];
    }

    /** Map a list of ids/products to cards, dropping anything unresolvable. */
    public static function cards(array $items): array
    {
        $out = [];
        foreach ($items as $item) {
            $card = self::card($item);
            if ($card !== null) {
                $out[] = $card;
            }
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       PDP
       ══════════════════════════════════════════════════════════════ */

    public static function pdp(int $id, int $variation_id = 0): ?array
    {
        $id      = Zooboxi_V2_Bootstrap::map_post($id);
        $product = self::resolve($id);
        if (!$product) {
            return null;
        }

        $card = self::card($product);
        if ($card === null) {
            return null;
        }

        // How many warehouse pieces one unit of the CHOSEN variation eats —
        // the delivery plan and warehouse counts below speak in those units.
        $units = ($variation_id > 0 && class_exists('Zooboxi_Units'))
            ? Zooboxi_Units::for_id($variation_id)
            : 1;

        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        $item_code   = (string) get_post_meta($id, '_zooboxi_item_code', true);
        $recs        = self::recommendations($item_code);

        $post = get_post($id);

        return $card + [
            'gallery'            => self::gallery($product),
            'description_html'   => $post ? wp_kses_post(do_shortcode(wpautop($post->post_content))) : '',
            'short_description'  => $product->get_short_description() !== ''
                ? wp_kses_post(wpautop($product->get_short_description()))
                : '',
            'brand_detail'       => self::brand_detail($id),
            'categories'         => self::categories($id),
            'attributes'         => self::flat_attributes($product),
            'variations'         => self::variations($product),
            'delivery'           => self::delivery_plan($id, $lat, $lng, 1, $units),
            'per_warehouse'      => self::per_warehouse($id, $lat, $lng, $units),
            'selected_units'     => $units,
            'badges'             => self::badges($id),
            'fbt'                => self::cards($recs['fbt']),
            'substitutes'        => self::cards($recs['substitutes']),
            'lang_fallback'      => Zooboxi_V2_Bootstrap::lang_fallback(),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       PIECES
       ══════════════════════════════════════════════════════════════ */

    /** @param \WC_Product|int $product */
    public static function resolve($product): ?\WC_Product
    {
        if ($product instanceof \WC_Product) {
            return $product;
        }
        $p = wc_get_product((int) $product);
        return $p instanceof \WC_Product ? $p : null;
    }

    /**
     * Retail prices only. Variable products report the FLOOR price plus a `price_from`
     * flag — the same "يبدأ من" rule the web card uses (theme/inc/zbx-card.php).
     */
    private static function prices(\WC_Product $product): array
    {
        $price_from = false;

        if ($product instanceof \WC_Product_Variable) {
            $min     = $product->get_variation_price('min', true);
            $max     = $product->get_variation_price('max', true);
            $regular = $product->get_variation_regular_price('min', true);
            $price   = $min === '' ? null : (float) $min;
            $regular = $regular === '' ? null : (float) $regular;
            $sale    = ($price !== null && $regular !== null && $price < $regular) ? $price : null;
            $price_from = ($min !== '' && $max !== '' && (float) $min !== (float) $max);
        } else {
            $raw_price   = $product->get_price();
            $raw_regular = $product->get_regular_price();
            $raw_sale    = $product->get_sale_price();
            $price   = ($raw_price === '' || $raw_price === null) ? null : (float) $raw_price;
            $regular = ($raw_regular === '' || $raw_regular === null) ? null : (float) $raw_regular;
            $sale    = ($raw_sale === '' || $raw_sale === null) ? null : (float) $raw_sale;
        }

        $on_sale = ($price !== null && $regular !== null && $price > 0 && $price < $regular);
        $off     = $on_sale ? (int) round((1 - $price / $regular) * 100) : 0;

        return [
            'price'         => $price,
            'regular_price' => $regular,
            'sale_price'    => $sale,
            'on_sale'       => $on_sale,
            'price_from'    => $price_from,
            // Mirrors the web card: sub-5% rounding noise is not an offer.
            'discount_pct'  => $off >= 5 ? $off : 0,
        ];
    }

    /** Location-aware quantity, capped for display. null when stock isn't managed. */
    private static function stock_qty(\WC_Product $product): ?int
    {
        $qty = $product->get_stock_quantity();
        if ($qty === null) {
            return null;
        }
        return min(self::STOCK_DISPLAY_CAP, max(0, (int) $qty));
    }

    /** Primary brand term ({name,slug}) or null. */
    public static function brand(int $product_id): ?array
    {
        $terms = get_the_terms($product_id, 'product_brand');
        if (empty($terms) || is_wp_error($terms)) {
            return null;
        }
        $term = $terms[0];
        return ['name' => $term->name, 'slug' => $term->slug];
    }

    /** Brand + SAP code + kit accent, when the boutique payload is published. */
    private static function brand_detail(int $product_id): ?array
    {
        $terms = get_the_terms($product_id, 'product_brand');
        if (empty($terms) || is_wp_error($terms)) {
            return null;
        }
        $term = $terms[0];
        $code = preg_match('/(\d+)/', (string) $term->description, $m) ? $m[1] : '';

        $out = ['name' => $term->name, 'slug' => $term->slug, 'code' => $code, 'accent' => null, 'logo' => null];

        if ($code !== '' && class_exists('Zooboxi_Brand_Sync')) {
            $payload = Zooboxi_Brand_Sync::get($code);
            if (is_array($payload)) {
                $kit = isset($payload['kit']) && is_array($payload['kit']) ? $payload['kit'] : [];
                $out['accent'] = self::safe_color((string) ($kit['accent'] ?? ''));
                $out['logo']   = !empty($payload['logo_url']) ? esc_url_raw((string) $payload['logo_url']) : null;
            }
        }

        return $out;
    }

    private static function categories(int $product_id): array
    {
        $terms = get_the_terms($product_id, 'product_cat');
        if (empty($terms) || is_wp_error($terms)) {
            return [];
        }
        $out = [];
        foreach ($terms as $t) {
            $out[] = ['id' => (int) $t->term_id, 'name' => $t->name, 'slug' => $t->slug];
        }
        return $out;
    }

    /* ── Images ─────────────────────────────────────── */

    /**
     * Resolve the best image URL. Mirrors the theme's fallback chain: WordPress
     * attachment → `_zooboxi_image_url` → the ppte.sa HD render keyed by SAP code.
     */
    public static function image_url(\WC_Product $product, string $size = 'woocommerce_thumbnail'): ?string
    {
        $attachment_id = $product->get_image_id();
        if ($attachment_id) {
            $url = wp_get_attachment_image_url((int) $attachment_id, $size);
            if ($url) {
                return $url;
            }
        }

        $id  = $product->get_id();
        $pid = $product instanceof \WC_Product_Variation ? $product->get_parent_id() : $id;

        $external = (string) get_post_meta($pid, '_zooboxi_image_url', true);
        if ($external !== '') {
            return esc_url_raw($external);
        }

        $code = (string) get_post_meta($pid, '_zooboxi_item_code', true);
        if ($code !== '') {
            return 'https://ppte.sa/imghd/' . rawurlencode(substr($code, 0, 4)) . '/' . rawurlencode($code) . '.png';
        }

        return null;
    }

    private static function gallery(\WC_Product $product): array
    {
        $urls = [];

        $main = self::image_url($product, 'woocommerce_single');
        if ($main) {
            $urls[] = $main;
        }
        foreach ($product->get_gallery_image_ids() as $gid) {
            $url = wp_get_attachment_image_url((int) $gid, 'woocommerce_single');
            if ($url && !in_array($url, $urls, true)) {
                $urls[] = $url;
            }
        }
        return $urls;
    }

    /* ── Badges ─────────────────────────────────────── */

    /**
     * All applicable intelligence badges, highest priority first — the SAME
     * Zooboxi_Dynamic_Badges::compute_badges() the web cards render.
     *
     * The instance is built WITHOUT its constructor on purpose: the constructor's only
     * job is registering the web loop hooks, and registering a second set of them from
     * a REST request would duplicate every badge on any rail rendered later.
     */
    public static function badges(int $product_id): array
    {
        static $engine = null;

        if ($engine === null) {
            if (!class_exists('Zooboxi_Dynamic_Badges') || get_option('zooboxi_dynamic_badges', 'yes') !== 'yes') {
                $engine = false;
            } else {
                try {
                    $ref    = new \ReflectionClass('Zooboxi_Dynamic_Badges');
                    $engine = $ref->newInstanceWithoutConstructor();
                } catch (\Throwable $e) {
                    $engine = false;
                }
            }
        }
        if ($engine === false) {
            return [];
        }

        $out = [];
        foreach ($engine->compute_badges($product_id) as $b) {
            $out[] = [
                'type'  => (string) ($b['key'] ?? ''),
                'label' => (string) ($b['label'] ?? ''),
                'icon'  => (string) ($b['icon'] ?? ''),
            ];
        }
        return $out;
    }

    /* ── Delivery ───────────────────────────────────── */

    /** The single fastest promise for a card — same source as Zooboxi_Delivery_Badge. */
    public static function delivery_chip(int $product_id): ?array
    {
        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        if (!$lat && !$lng) {
            return null; // no location → the app shows the "set your location" chip
        }

        $delivery = Zooboxi_Delivery_Engine::detect_product_delivery($product_id, $lat, $lng);
        $tier     = (string) ($delivery['type'] ?? Zooboxi_Delivery_Engine::TYPE_SHIPPING);

        return [
            'tier'  => $tier,
            'label' => self::chip_label($tier),
            'icon'  => self::tier_icon($tier),
        ];
    }

    private static function chip_label(string $tier): string
    {
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return __('توصيل خلال ساعتين', 'zooboxi');
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return __('توصيل خلال 24 ساعة', 'zooboxi');
            default:
                return __('شحن 4-5 أيام', 'zooboxi');
        }
    }

    private static function tier_icon(string $tier): string
    {
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return '⚡';
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return '🚚';
            default:
                return '📦';
        }
    }

    /**
     * The full, honest delivery plan for one unit — projected straight from
     * Zooboxi_Fulfillment (the single source of truth) plus its branded presentation.
     */
    public static function delivery_plan(int $product_id, float $lat, float $lng, int $qty = 1, int $units = 1): array
    {
        $units = max(1, $units);
        $plan  = Zooboxi_Fulfillment::resolve($product_id, max(1, $qty) * $units, $lat, $lng);
        $tiers = [];

        foreach ($plan['tiers'] as $t) {
            $tier = (string) $t['tier'];
            $pres = Zooboxi_Fulfillment::tier_presentation($tier);
            $tiers[] = [
                'tier'           => $tier,
                'warehouse_name' => (string) ($t['warehouse_name'] ?? ''),
                // Stock is stored in pieces; spoken here in the chosen unit —
                // a warehouse holding 140 pieces has 8 cartons of 17.
                'stock'          => min(self::STOCK_DISPLAY_CAP, Zooboxi_Units::units_from_pieces((int) ($t['stock'] ?? 0), $units)),
                'fee'            => (float) ($t['fee'] ?? 0),
                'label'          => (string) $pres['name'],
                'date_label'     => (string) $pres['date'],
                'relative_label' => (string) $pres['relative'],
                'color'          => (string) $pres['color'],
                'icon'           => (string) $pres['icon'],
            ];
        }

        return [
            'headline'        => Zooboxi_Fulfillment::headline($plan),
            'tiers'           => $tiers,
            'reachable_total' => min(self::STOCK_DISPLAY_CAP, Zooboxi_Units::units_from_pieces((int) $plan['reachable_total'], $units)),
            'fastest'         => (string) $plan['fastest'],
            'is_split'        => (bool) $plan['is_split'],
        ];
    }

    /**
     * Per-warehouse availability — REACHABLE warehouses only, in the chosen
     * variation's units. The full network stock map is deliberately never
     * serialized (it is commercial information).
     */
    private static function per_warehouse(int $product_id, float $lat, float $lng, int $units = 1): array
    {
        $units = max(1, $units);
        $plan  = Zooboxi_Fulfillment::resolve($product_id, 1, $lat, $lng);
        $out   = [];
        foreach ($plan['tiers'] as $t) {
            $out[] = [
                'warehouse_name' => (string) ($t['warehouse_name'] ?? ''),
                'tier'           => (string) $t['tier'],
                'stock'          => min(self::STOCK_DISPLAY_CAP, Zooboxi_Units::units_from_pieces((int) ($t['stock'] ?? 0), $units)),
            ];
        }
        return $out;
    }

    /* ── Variations ─────────────────────────────────── */

    /** Flat, human-readable attribute list for simple products. */
    private static function flat_attributes(\WC_Product $product): array
    {
        $out = [];
        foreach ($product->get_attributes() as $attribute) {
            if (!($attribute instanceof \WC_Product_Attribute) || $attribute->get_variation()) {
                continue;
            }
            $name  = wc_attribute_label($attribute->get_name(), $product);
            $value = $attribute->is_taxonomy()
                ? implode('، ', wp_list_pluck(get_terms(['taxonomy' => $attribute->get_name(), 'include' => $attribute->get_options(), 'hide_empty' => false]) ?: [], 'name'))
                : implode('، ', (array) $attribute->get_options());
            if ($value !== '') {
                $out[] = ['label' => $name, 'value' => $value];
            }
        }
        return $out;
    }

    /** Variation matrix (attribute groups + purchasable combinations). */
    private static function variations(\WC_Product $product): ?array
    {
        if (!($product instanceof \WC_Product_Variable)) {
            return null;
        }

        $attributes = [];
        foreach ($product->get_variation_attributes() as $taxonomy => $options) {
            $group = [
                'slug'    => sanitize_title($taxonomy),
                'name'    => $taxonomy,
                'label'   => wc_attribute_label($taxonomy, $product),
                'options' => [],
            ];
            foreach ((array) $options as $option) {
                $term  = taxonomy_exists($taxonomy) ? get_term_by('slug', $option, $taxonomy) : null;
                $label = ($term && !is_wp_error($term)) ? $term->name : (string) $option;
                $group['options'][] = [
                    'slug'  => (string) $option,
                    'label' => $label,
                    'emoji' => self::swatch_emoji($label),
                ];
            }
            $attributes[] = $group;
        }

        $list = [];
        foreach ($product->get_available_variations() as $v) {
            $variation_id = (int) ($v['variation_id'] ?? 0);
            if (!$variation_id) {
                continue;
            }
            $variation = wc_get_product($variation_id);

            // An honest ceiling: WooCommerce's own max is counted in the line's
            // units and knows nothing about packs, so a 17-piece carton showed
            // max 306 over a 99-piece pool. The pool divided by the pack size
            // is what a stepper may actually promise.
            $own_max = ($v['max_qty'] ?? '') === '' ? null : (int) $v['max_qty'];
            $units   = class_exists('Zooboxi_Units') ? Zooboxi_Units::for_id($variation_id) : 1;
            $pool    = $product->managing_stock() ? $product->get_stock_quantity() : null;
            if ($pool !== null && class_exists('Zooboxi_Units')) {
                $pool_max = Zooboxi_Units::units_from_pieces((int) $pool, $units);
                $own_max  = $own_max === null ? $pool_max : min($own_max, $pool_max);
            }

            $list[] = [
                'variation_id'  => $variation_id,
                'attributes'    => is_array($v['attributes'] ?? null) ? array_map('strval', $v['attributes']) : [],
                'price'         => isset($v['display_price']) ? (float) $v['display_price'] : null,
                'regular_price' => isset($v['display_regular_price']) ? (float) $v['display_regular_price'] : null,
                'image'         => $variation instanceof \WC_Product ? self::image_url($variation, 'woocommerce_single') : null,
                'in_stock'      => !empty($v['is_in_stock']),
                'max_qty'       => $own_max,
                'units'         => $units,
                'sku'           => (string) ($v['sku'] ?? ''),
            ];
        }

        return ['attributes' => $attributes, 'list' => $list];
    }

    /** Emoji for a variation option label (canonical map above). */
    public static function swatch_emoji(string $label): string
    {
        $lower = function_exists('mb_strtolower') ? mb_strtolower($label) : strtolower($label);
        foreach (self::SWATCH_EMOJI as $keyword => $icon) {
            $needle = function_exists('mb_strtolower') ? mb_strtolower((string) $keyword) : strtolower((string) $keyword);
            if ($needle === '') {
                continue;
            }
            // 1–2 char tokens (s, m, xl, kg…) only match as whole words — otherwise
            // "salmon" hits 's' and "500g" never reaches its weight emoji.
            if (mb_strlen($needle) <= 2) {
                if (preg_match('/(?<![\p{L}\p{N}])' . preg_quote($needle, '/') . '(?![\p{L}\p{N}])/u', $lower)) {
                    return $icon;
                }
                continue;
            }
            if (mb_strpos($lower, $needle) !== false) {
                return $icon;
            }
        }
        return self::SWATCH_DEFAULT;
    }

    /* ── Wishlist ───────────────────────────────────── */

    /**
     * Shares ONE list with the web store: the theme keeps favourites in the user meta
     * `_zbx_wishlist` (theme/inc/zbx-wishlist.php → const ZBX_WISHLIST_META). The literal
     * is used so the DTO still works if the theme file is not loaded in this context.
     */
    public const WISHLIST_META = '_zbx_wishlist';

    public static function wishlist_ids(int $user_id = 0): array
    {
        $user_id = $user_id ?: get_current_user_id();
        if (!$user_id) {
            return [];
        }
        $ids = get_user_meta($user_id, self::WISHLIST_META, true);
        if (!is_array($ids)) {
            return [];
        }
        return array_values(array_unique(array_filter(array_map('intval', $ids))));
    }

    private static function is_wishlisted(int $product_id): bool
    {
        static $ids = null;
        if ($ids === null) {
            $ids = self::wishlist_ids();
        }
        return in_array($product_id, $ids, true);
    }

    /* ── Recommendations proxy ──────────────────────── */

    /**
     * FBT + substitutes from the sapconnect intelligence API, cached per item code.
     * Failures degrade to empty arrays — the PDP must never break on a slow backend.
     *
     * @return array{fbt:int[],substitutes:int[]}
     */
    public static function recommendations(string $item_code): array
    {
        $empty = ['fbt' => [], 'substitutes' => []];
        if ($item_code === '') {
            return $empty;
        }

        $key    = 'zb_v2_recs_' . md5($item_code);
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached + $empty;
        }

        $token = (string) get_option('zooboxi_api_token', '');
        if ($token === '') {
            return $empty;
        }
        $base = rtrim((string) get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');

        $res = wp_remote_get($base . '/recommendations/' . rawurlencode($item_code), [
            'headers' => ['Authorization' => 'Bearer ' . $token, 'Accept' => 'application/json'],
            'timeout' => 8,
        ]);
        if (is_wp_error($res)) {
            return $empty;
        }
        $body = json_decode(wp_remote_retrieve_body($res), true);
        if (!is_array($body)) {
            return $empty;
        }

        $out = [
            'fbt'         => self::rec_ids($body['frequently_bought_together'] ?? []),
            'substitutes' => self::rec_ids($body['substitutes'] ?? []),
        ];
        set_transient($key, $out, self::RECS_TTL);
        return $out;
    }

    /** @return int[] */
    private static function rec_ids($rows): array
    {
        if (!is_array($rows)) {
            return [];
        }
        $ids = [];
        foreach ($rows as $r) {
            if (!is_array($r)) {
                continue;
            }
            $pid = !empty($r['woo_product_id']) ? (int) $r['woo_product_id'] : self::find_by_item_code((string) ($r['item_code'] ?? ''));
            if ($pid && get_post_status($pid) === 'publish' && !in_array($pid, $ids, true)) {
                $ids[] = $pid;
            }
        }
        return array_slice($ids, 0, 8);
    }

    public static function find_by_item_code(string $item_code): int
    {
        if ($item_code === '') {
            return 0;
        }
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s LIMIT 1",
            $item_code
        ));
        return $id ? (int) $id : 0;
    }

    /* ── Misc ───────────────────────────────────────── */

    private static function safe_color(string $value): ?string
    {
        $value = trim($value);
        return preg_match('/^#[0-9A-Fa-f]{3,8}$/', $value) ? $value : null;
    }
}
