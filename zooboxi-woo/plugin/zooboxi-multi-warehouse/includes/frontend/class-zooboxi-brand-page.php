<?php

/**
 * Zooboxi_Brand_Page — the per-brand boutique page at /brand/<slug>/.
 *
 * For a brand the owner has PUBLISHED (present in Zooboxi_Brand_Sync::all()), it
 * takes over the product_brand archive with a template themed entirely in that
 * brand's identity (colors/fonts from the sapconnect kit) and an AI hero + promo
 * tiles, brand story, in-brand category nav, a curated picks rail, and the full
 * brand catalog (the native WooCommerce loop — pagination/sort/badges intact).
 *
 * Brands that are NOT published keep the default WooCommerce archive (so the pilot
 * goes live one brand at a time). Channel-safe: visibility only, no prices touched.
 *
 * Mapping: the product_brand term description carries "Brand code: NNN" → the SAP
 * brand code used to look up the kit/banners.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Brand_Page
{
    /** Per-request resolve cache: term_id => ['term','code','payload'] | false. */
    private static array $resolved = [];

    public function __construct()
    {
        add_filter('template_include', [$this, 'maybe_take_over'], 999);
        add_action('wp_enqueue_scripts', [$this, 'enqueue']);
        add_filter('body_class', [$this, 'body_class']);
        add_action('wp_head', [$this, 'print_brand_vars'], 99);

        // In-brand category filter (category tiles → /brand/<slug>/?zb_cat=<slug>).
        add_action('pre_get_posts', [$this, 'filter_in_brand_category']);
    }

    /* ── Resolution & gate ─────────────────────────────── */

    /** The published-brand payload for the current archive (cached), or null. */
    public static function resolve(): ?array
    {
        if (!is_tax('product_brand')) {
            return null;
        }
        $term = get_queried_object();
        if (!($term instanceof WP_Term)) {
            return null;
        }
        if (array_key_exists($term->term_id, self::$resolved)) {
            return self::$resolved[$term->term_id] ?: null;
        }

        $code = self::code_from_term($term);
        $payload = ($code && class_exists('Zooboxi_Brand_Sync')) ? Zooboxi_Brand_Sync::get($code) : null;

        $resolved = $payload ? ['term' => $term, 'code' => $code, 'payload' => $payload] : false;
        self::$resolved[$term->term_id] = $resolved;
        return $resolved ?: null;
    }

    /** Parse the SAP brand code from the term description ("Brand code: 176"). */
    private static function code_from_term(WP_Term $term): ?string
    {
        if (preg_match('/(\d+)/', (string) $term->description, $m)) {
            return $m[1];
        }
        return null;
    }

    public function maybe_take_over($template)
    {
        if (!self::resolve()) {
            return $template; // unpublished brand → default WooCommerce archive
        }
        $custom = ZOOBOXI_PLUGIN_DIR . 'includes/frontend/brand-archive.php';
        return is_file($custom) ? $custom : $template;
    }

    /* ── Assets & theming ──────────────────────────────── */

    public function enqueue(): void
    {
        $r = self::resolve();
        if (!$r) {
            return;
        }
        $kit = $r['payload']['kit'] ?? [];

        // Reuse the homepage rail/card styling so the curated rail looks identical.
        $home_css_ver = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/css/zooboxi-home.css') ?: ZOOBOXI_VERSION;
        wp_enqueue_style('zooboxi-home', ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-home.css', ['zooboxi-public'], $home_css_ver);

        $css_ver = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/css/zooboxi-brand.css') ?: ZOOBOXI_VERSION;
        $js_ver  = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/js/zooboxi-brand.js') ?: ZOOBOXI_VERSION;

        wp_enqueue_style('zooboxi-brand', ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-brand.css', ['zooboxi-public', 'zooboxi-home'], $css_ver);
        wp_enqueue_script('zooboxi-brand', ZOOBOXI_PLUGIN_URL . 'public/js/zooboxi-brand.js', ['jquery'], $js_ver, true);

        $fonts = $this->google_fonts_url($kit);
        if ($fonts) {
            wp_enqueue_style('zooboxi-brand-fonts', $fonts, [], null);
        }
    }

    public function body_class($classes)
    {
        if (self::resolve()) {
            $classes[] = 'zb-has-brand-page';
        }
        return $classes;
    }

    /** Scoped CSS variables = the brand's identity, applied to the whole page. */
    public function print_brand_vars(): void
    {
        $r = self::resolve();
        if (!$r) {
            return;
        }
        $kit = $r['payload']['kit'] ?? [];
        $accent      = $this->safe_color($kit['accent'] ?? '', '#0d9488');
        $accent_dark = $this->safe_color($kit['accent_dark'] ?? '', '#0a5560');
        $gold        = $this->safe_color($kit['gold'] ?? '', '#F4BE2C');
        $head        = $this->css_font($kit['headline_font'] ?? 'Tajawal');
        $body        = $this->css_font($kit['body_font'] ?? 'Tajawal');

        echo '<style id="zb-brand-vars">body.zb-has-brand-page{'
            . '--zb-accent:' . $accent . ';'
            . '--zb-accent-dark:' . $accent_dark . ';'
            . '--zb-gold:' . $gold . ';'
            . '--zb-head-font:' . $head . ',"Tajawal",sans-serif;'
            . '--zb-body-font:' . $body . ',"Tajawal",sans-serif;'
            . '}</style>';
    }

    /* ── Section rendering (called by brand-archive.php) ── */

    /** Full boutique header: hero + story + tiles + categories + curated rail. */
    public static function render_sections(): string
    {
        $r = self::resolve();
        if (!$r) {
            return '';
        }
        $self = new self();
        $term = $r['term'];
        $payload = $r['payload'];

        return '<div class="zb-brand">'
            . $self->section_hero($payload, $term)
            . $self->section_story($payload)
            . $self->section_tiles($payload)
            . $self->section_categories($term)
            . $self->section_featured($payload, $term)
            . '</div>';
    }

    private function section_hero(array $payload, WP_Term $term): string
    {
        $kit  = $payload['kit'] ?? [];
        $name = $payload['name'] ?? $term->name;
        $hero = $payload['hero_url'] ?? '';
        $logo = $this->brand_logo($term, $payload);
        $tag  = $kit['tagline_ar'] ?? '';

        if ($hero) {
            return '<section class="zb-brand-hero zb-brand-hero--img zb-brand-track" '
                . 'data-zb-zone="' . esc_attr('brand:' . $term->slug . ':hero') . '">'
                . '<img class="zb-brand-hero__img" src="' . esc_url($hero) . '" alt="' . esc_attr($name) . '" fetchpriority="high">'
                . '</section>';
        }

        // CSS hero fallback — themed by the brand's own colors (never a broken state).
        $inner = $logo
            ? '<img class="zb-brand-hero__logo" src="' . esc_url($logo) . '" alt="' . esc_attr($name) . '">'
            : '<h1 class="zb-brand-hero__name">' . esc_html($name) . '</h1>';
        $sub = $tag ? '<p class="zb-brand-hero__tag">' . esc_html($tag) . '</p>' : '';

        return '<section class="zb-brand-hero zb-brand-hero--css"><div class="zb-brand-hero__inner">'
            . $inner . $sub . '</div></section>';
    }

    private function section_story(array $payload): string
    {
        $kit = $payload['kit'] ?? [];
        $lead = trim((string) ($kit['audience_ar'] ?? ''));

        $meta = [];
        if (!empty($kit['country'])) {
            $meta[] = '<span class="zb-brand-story__chip">🌍 ' . esc_html($kit['country']) . '</span>';
        }
        if (!empty($kit['founded'])) {
            $meta[] = '<span class="zb-brand-story__chip">🗓 ' . esc_html__('منذ', 'zooboxi') . ' ' . esc_html($kit['founded']) . '</span>';
        }
        if (!empty($kit['mood_ar'])) {
            $meta[] = '<span class="zb-brand-story__chip">' . esc_html($kit['mood_ar']) . '</span>';
        }

        if ($lead === '' && empty($meta)) {
            return '';
        }

        return '<section class="zb-brand-story">'
            . ($lead !== '' ? '<p class="zb-brand-story__lead">' . esc_html($lead) . '</p>' : '')
            . (!empty($meta) ? '<div class="zb-brand-story__chips">' . implode('', $meta) . '</div>' : '')
            . '</section>';
    }

    private function section_tiles(array $payload): string
    {
        $tiles = $payload['tiles'] ?? [];
        if (empty($tiles) || !is_array($tiles)) {
            return '';
        }
        $shop = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/');

        $cards = '';
        $i = 0;
        foreach ($tiles as $t) {
            $img = $t['url'] ?? '';
            if (!$img) {
                continue;
            }
            $i++;
            $label = (string) ($t['headline_ar'] ?? '');
            $cards .= '<a class="zb-brand-tile zb-brand-track" href="' . esc_url($shop) . '" '
                . 'data-zb-zone="' . esc_attr('brand:tile' . $i) . '" aria-label="' . esc_attr($label) . '">'
                . '<img src="' . esc_url($img) . '" loading="lazy" alt="' . esc_attr($label) . '">'
                . ($label !== '' ? '<span class="zb-brand-tile__cap">' . esc_html($label) . '</span>' : '')
                . '</a>';
        }
        if ($cards === '') {
            return '';
        }
        return '<section class="zb-brand-tiles zb-brand-tiles--' . (int) min($i, 3) . '">' . $cards . '</section>';
    }

    private function section_categories(WP_Term $term): string
    {
        $cats = $this->brand_categories($term);
        if (empty($cats)) {
            return '';
        }
        $base = get_term_link($term);
        if (is_wp_error($base)) {
            return '';
        }
        $active = isset($_GET['zb_cat']) ? sanitize_title(wp_unslash($_GET['zb_cat'])) : '';

        $pills = '<a class="zb-brand-cat' . ($active === '' ? ' is-active' : '') . '" href="' . esc_url($base) . '">'
            . esc_html__('الكل', 'zooboxi') . '</a>';
        foreach ($cats as $c) {
            $url = add_query_arg('zb_cat', $c['slug'], $base);
            $is = $active === $c['slug'] ? ' is-active' : '';
            $pills .= '<a class="zb-brand-cat' . $is . '" href="' . esc_url($url) . '">'
                . esc_html($c['name']) . ' <span>' . (int) $c['count'] . '</span></a>';
        }

        return '<section class="zb-brand-cats">'
            . '<h2 class="zb-brand-h2">' . esc_html__('تصفّح أقسام العلامة', 'zooboxi') . '</h2>'
            . '<div class="zb-brand-cats__row">' . $pills . '</div></section>';
    }

    /** Curated picks rail: brand-scoped bestsellers (reuses Zooboxi_Product_Rail). */
    private function section_featured(array $payload, WP_Term $term): string
    {
        if (!class_exists('Zooboxi_Product_Rail')) {
            return '';
        }
        // Don't duplicate the rail when the catalog is already category-filtered.
        if (!empty($_GET['zb_cat'])) {
            return '';
        }
        $slug = $term->slug;
        $name = $payload['name'] ?? $term->name;

        return Zooboxi_Product_Rail::render_with_fallback(
            [
                'title'   => sprintf(__('مختارات %s', 'zooboxi'), $name),
                'icon'    => '⭐',
                'zone'    => 'brand:' . $slug . ':featured',
                'columns' => 6,
                'class'   => 'zb-brand-rail',
            ],
            [
                $this->brand_query(Zooboxi_Product_Rail::q_bestsellers(12), $slug),
                $this->brand_query(Zooboxi_Product_Rail::q_top_ranked(12), $slug),
                $this->brand_query(Zooboxi_Product_Rail::q_newest(12), $slug),
            ]
        );
    }

    /* ── In-brand category filter on the main query ────── */

    public function filter_in_brand_category(WP_Query $q): void
    {
        if (is_admin() || !$q->is_main_query()) {
            return;
        }
        if (!$q->is_tax('product_brand')) {
            return;
        }
        $cat = isset($_GET['zb_cat']) ? sanitize_title(wp_unslash($_GET['zb_cat'])) : '';
        if ($cat === '') {
            return;
        }
        $tax = (array) $q->get('tax_query');
        $tax[] = ['taxonomy' => 'product_cat', 'field' => 'slug', 'terms' => $cat];
        $q->set('tax_query', $tax);
    }

    /* ── Helpers ───────────────────────────────────────── */

    /** Merge a product_brand constraint into a Zooboxi_Product_Rail query. */
    private function brand_query(array $base, string $slug): array
    {
        $tax = isset($base['tax_query']) && is_array($base['tax_query']) ? $base['tax_query'] : [];
        $tax[] = ['taxonomy' => 'product_brand', 'field' => 'slug', 'terms' => $slug];
        $base['tax_query'] = $tax;
        return $base;
    }

    /** Brand logo: prefer the store term thumbnail; fall back to the backend kit. */
    private function brand_logo(WP_Term $term, array $payload): string
    {
        $thumb_id = (int) get_term_meta($term->term_id, 'thumbnail_id', true);
        if ($thumb_id) {
            $url = wp_get_attachment_image_url($thumb_id, 'full');
            if ($url) {
                return $url;
            }
        }
        return (string) ($payload['logo_url'] ?? '');
    }

    /**
     * The useful sub-categories within a brand: tally product_cat by name across the
     * brand's products, drop brand-container categories (those covering ~all of the
     * brand's products are not a useful filter), keep the top narrowing ones.
     */
    private function brand_categories(WP_Term $term): array
    {
        $tkey = 'zb_brand_cats_' . $term->slug;
        $cached = get_transient($tkey);
        if (is_array($cached)) {
            return $cached;
        }

        $ids = get_posts([
            'post_type'      => 'product',
            'post_status'    => 'publish',
            'fields'         => 'ids',
            'posts_per_page' => 150,
            'no_found_rows'  => true,
            'tax_query'      => [[
                'taxonomy' => 'product_brand',
                'field'    => 'slug',
                'terms'    => $term->slug,
            ]],
        ]);
        if (empty($ids)) {
            set_transient($tkey, [], 6 * HOUR_IN_SECONDS);
            return [];
        }
        $total = count($ids);

        $terms = wp_get_object_terms($ids, 'product_cat', ['fields' => 'all_with_object_id']);
        if (is_wp_error($terms)) {
            return [];
        }

        // The per-brand grouping categories (e.g. the Arabic "ابلاوز") live under the
        // "العلامات التجارية" (Brands) container → exclude that whole subtree so only
        // real product categories (food type, species, health) remain.
        $brand_root = get_term_by('name', 'العلامات التجارية', 'product_cat');
        $brand_root_id = $brand_root ? (int) $brand_root->term_id : 0;

        $deny = ['العلامات التجارية', 'Brands', 'Uncategorized', 'غير مصنف'];
        $tally = [];
        foreach ($terms as $t) {
            $name = $t->name;
            if (in_array($name, $deny, true) || strcasecmp($name, $term->name) === 0) {
                continue;
            }
            if ($brand_root_id && ($t->parent === $brand_root_id || in_array($brand_root_id, get_ancestors($t->term_id, 'product_cat'), true))) {
                continue; // a brand-grouping category, not a real product category
            }
            if (!isset($tally[$name])) {
                $tally[$name] = ['name' => $name, 'slug' => $t->slug, 'count' => 0];
            }
            // Prefer the canonical (shortest-slug) term for a given display name.
            if (strlen($t->slug) < strlen($tally[$name]['slug'])) {
                $tally[$name]['slug'] = $t->slug;
            }
            $tally[$name]['count']++;
        }

        // Drop container categories (≈ all products → not a narrowing filter) + singletons.
        $cats = array_values(array_filter($tally, function ($c) use ($total) {
            return $c['count'] >= 2 && $c['count'] < $total;
        }));
        usort($cats, fn ($a, $b) => $b['count'] <=> $a['count']);
        $cats = array_slice($cats, 0, 8);

        set_transient($tkey, $cats, 6 * HOUR_IN_SECONDS);
        return $cats;
    }

    /** Build a Google Fonts URL for the brand's headline + body families. */
    private function google_fonts_url(array $kit): string
    {
        $fams = [];
        foreach ([$kit['headline_font'] ?? '', $kit['body_font'] ?? ''] as $f) {
            $f = trim((string) $f);
            if ($f !== '' && !in_array($f, $fams, true)) {
                $fams[] = $f;
            }
        }
        if (empty($fams)) {
            return '';
        }
        $parts = [];
        foreach ($fams as $f) {
            $parts[] = 'family=' . str_replace(' ', '+', $f) . ':wght@400;500;600;700';
        }
        return 'https://fonts.googleapis.com/css2?' . implode('&', $parts) . '&display=swap';
    }

    /** Only allow a safe CSS color token (hex / rgb / named) to reach the style block. */
    private function safe_color(string $c, string $fallback): string
    {
        $c = trim($c);
        if (preg_match('/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/', $c)) {
            return $c;
        }
        if (preg_match('/^rgba?\([0-9,\s.]+\)$/', $c)) {
            return $c;
        }
        if (preg_match('/^[a-zA-Z]{3,20}$/', $c)) {
            return $c;
        }
        return $fallback;
    }

    /** Quote a font family for CSS, stripping anything unexpected. */
    private function css_font(string $f): string
    {
        $f = trim(preg_replace('/[^a-zA-Z0-9 \-]/', '', $f));
        return $f !== '' ? '"' . $f . '"' : '"Tajawal"';
    }
}
