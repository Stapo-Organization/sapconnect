<?php
/**
 * Zooboxi_Homepage — the dynamic store homepage.
 *
 * Registers the [zooboxi_home] master shortcode that renders the cacheable SHELL
 * (hero, animal nav, global intelligence rails, brands, categories, trust) plus
 * empty placeholder containers that the front-end JS hydrates per-customer from
 * GET /zooboxi/v1/home-feed (welcome, delivery promise, recently-viewed,
 * buy-again, recommended-for-you, trending-in-your-city, gentle login invite).
 *
 * The golden rule: nothing customer-specific is baked into the shell HTML, so the
 * page stays fully page-cacheable; personalization lives only in the no-store feed.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Homepage
{
    /** Banner asset already uploaded on the store (used when campaigns are off). */
    private const STATIC_HERO = '/wp-content/uploads/zooboxi-assets/fb1cd0a0-555f-45da-a682-fd525f75699f.jpg';

    public function __construct()
    {
        add_shortcode('zooboxi_home', [$this, 'render']);
        add_action('wp_enqueue_scripts', [$this, 'enqueue']);

        // Bust a customer's buy-again cache whenever one of their orders changes.
        add_action('woocommerce_order_status_changed', [$this, 'bust_buyagain_cache'], 10, 1);

        // Arabic loop button text + aria-label (the store is Arabic-only; WC ships English defaults).
        add_filter('woocommerce_product_add_to_cart_text', [$this, 'loop_button_text'], 20, 2);
        add_filter('woocommerce_loop_add_to_cart_args', [$this, 'loop_button_aria'], 20, 2);
    }

    /** Localize the loop add-to-cart accessibility label to Arabic. */
    public function loop_button_aria($args, $product)
    {
        if (is_array($args) && isset($args['attributes']) && is_array($args['attributes']) && ($product instanceof WC_Product)) {
            $args['attributes']['aria-label'] = sprintf(
                __('أضف %s إلى السلة', 'zooboxi'),
                wp_strip_all_tags($product->get_name())
            );
        }
        return $args;
    }

    /** Localize the shop-loop add-to-cart button text to Arabic. */
    public function loop_button_text($text, $product)
    {
        if (!($product instanceof WC_Product)) {
            return $text;
        }
        if ($product->is_type('variable') || $product->is_type('grouped')) {
            return __('اختر الخيارات', 'zooboxi');
        }
        if (!$product->is_in_stock()) {
            return __('غير متوفر', 'zooboxi');
        }
        if (!$product->is_purchasable()) {
            return __('عرض المنتج', 'zooboxi');
        }
        return __('أضف للسلة', 'zooboxi');
    }

    public function enqueue(): void
    {
        if (!is_front_page() && !is_home()) {
            return;
        }
        // filemtime versions so each deploy busts the browser cache automatically.
        $css_ver = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/css/zooboxi-home.css') ?: ZOOBOXI_VERSION;
        $js_ver  = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/js/zooboxi-home.js') ?: ZOOBOXI_VERSION;

        wp_enqueue_style(
            'zooboxi-home',
            ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-home.css',
            ['zooboxi-public'],
            $css_ver
        );
        wp_enqueue_script(
            'zooboxi-home',
            ZOOBOXI_PLUGIN_URL . 'public/js/zooboxi-home.js',
            ['jquery'],
            $js_ver,
            true
        );
        wp_localize_script('zooboxi-home', 'zbHome', [
            'feedUrl'    => rest_url('zooboxi/v1/home-feed'),
            'ajaxUrl'    => admin_url('admin-ajax.php'),
            // REST cookie nonce so logged-in users authenticate on /home-feed. Page
            // caches bypass logged-in requests, so this stays fresh for them; guests
            // don't need it (the nonce check is skipped when not logged in).
            'restNonce'  => wp_create_nonce('wp_rest'),
            'isLoggedIn' => is_user_logged_in() ? 1 : 0,
            'i18n'       => [
                'locate' => __('📍 حدّد موقعك لمعرفة سرعة التوصيل', 'zooboxi'),
            ],
        ]);
    }

    public function bust_buyagain_cache(int $order_id): void
    {
        $order = wc_get_order($order_id);
        if (!$order) {
            return;
        }
        $uid = $order->get_customer_id();
        if ($uid) {
            delete_transient('zbhome_buyagain_' . $uid);
        }
    }

    /* ── Master shortcode ────────────────────────────── */

    public function render($atts): string
    {
        if (get_option('zooboxi_home_enabled', 'yes') !== 'yes') {
            return '';
        }

        ob_start();
        echo '<div class="zb-home">';

        // 1) Hero — dynamic campaign carousel if live, else the static banner.
        echo $this->section_hero();

        // 2) Delivery promise (hydrated): strip when located, invite chip otherwise.
        echo '<div id="zb-home-promise" class="zb-home-slot zb-home-slot--thin" data-zb-feed="promise"></div>';

        // 3) Animal quick-nav (shell).
        echo $this->section_animals();

        // 4) Welcome (hydrated, logged-in only).
        echo '<div id="zb-home-welcome" class="zb-home-slot" data-zb-feed="welcome"></div>';

        // 5) Buy-again (logged-in) OR gentle login invite (guest) — hydrated.
        echo '<div id="zb-home-buyagain" class="zb-home-slot" data-zb-feed="buyagain" data-zb-feed-fallback="login">'
            . $this->skeleton_rail(__('اطلبها مجدداً', 'zooboxi')) . '</div>';

        // 6) "مختار لك" — recently-viewed + recommendations merged (hydrated).
        echo '<div id="zb-home-foryou" class="zb-home-slot" data-zb-feed="foryou"></div>';

        // Brands slider — placed above the in-city rail (owner preference).
        echo '<div class="zb-home-brands">' . do_shortcode('[zooboxi_brands_slider]') . '</div>';

        // 7) In-city / fast-delivery picks (hydrated).
        echo '<div id="zb-home-incity" class="zb-home-slot" data-zb-feed="incity"></div>';

        // 8) Ad banner (campaign shop_top creative if live, else on-brand promo).
        echo $this->section_banner('a');

        // 9) Most wanted — trending + bestsellers merged & deduped (shell).
        echo $this->section_most_wanted();

        // 10) New arrivals (shell, deduped).
        echo $this->section_new();

        // 11) Ad banner.
        echo $this->section_banner('b');

        // 12) Clearance (shell, channel-safe, deduped).
        echo $this->section_clearance();

        // 14) Category pills (shell).
        echo $this->section_categories();

        // 15) Trust / identity (shell).
        echo $this->section_features();

        echo '</div>';
        return ob_get_clean();
    }

    /* ── Shell sections ──────────────────────────────── */

    private function section_hero(): string
    {
        // Smart slider: manual banners + live campaigns + auto on-brand fill slides.
        if (class_exists('Zooboxi_Hero_Slider')) {
            $slider = Zooboxi_Hero_Slider::render();
            if ($slider !== '') {
                return '<div class="zb-home-hero zb-home-hero--slider">' . $slider . '</div>';
            }
        }
        $campaign = trim(do_shortcode('[zooboxi_hero]'));
        if ($campaign !== '') {
            return '<div class="zb-home-hero zb-home-hero--campaign">' . $campaign . '</div>';
        }
        return '<div class="zb-home-hero zb-home-hero--static">'
            . '<div class="zb-home-hero__frame">'
            . '<img class="zb-home-hero__img" src="' . esc_url(self::STATIC_HERO) . '" alt="Zooboxi" fetchpriority="high">'
            . '</div></div>';
    }

    private function section_animals(): string
    {
        $cats = [
            ['قطط', '/product-category/قطط/', '/wp-content/uploads/zooboxi-assets/97125602-5f94-42eb-96da-186b483e1289.webp'],
            ['كلاب', '/product-category/كلاب/', '/wp-content/uploads/zooboxi-assets/2f1e50b9-1fbf-4dcb-aa2b-14ebe0cec716.webp'],
            ['حيوانات صغيرة', '/product-category/حيوانات-صغيرة/', '/wp-content/uploads/zooboxi-assets/30a11991-15ae-4b19-9f1c-56d6994424a4.webp'],
            ['طيور', '/product-category/طيور/', '/wp-content/uploads/zooboxi-assets/307a4def-f718-4d79-ba2e-925454fa8faa.webp'],
        ];
        $out = '<nav class="zbx-animals-nav" aria-label="' . esc_attr__('تصفّح حسب الحيوان', 'zooboxi') . '">';
        foreach ($cats as [$name, $url, $img]) {
            $out .= '<a href="' . esc_url($url) . '" class="zbx-animal-card">'
                . '<span class="zbx-animal-card__img-wrap"><img src="' . esc_url($img) . '" alt="' . esc_attr($name) . '" loading="lazy"></span>'
                . '<span class="zbx-animal-card__name">' . esc_html($name) . '</span></a>';
        }
        $out .= '</nav>';
        return $out;
    }

    /** Merged "most wanted" rail = bestsellers + trending, ranked & deduped. */
    private function section_most_wanted(): string
    {
        return $this->cached_rail('mostwanted', [
            Zooboxi_Product_Rail::q_bestsellers(24),
            Zooboxi_Product_Rail::q_trending(24),
            Zooboxi_Product_Rail::q_top_ranked(24),
            Zooboxi_Product_Rail::q_newest(24),
        ], [
            'title' => __('الأكثر طلباً ورواجاً', 'zooboxi'),
            'icon'  => '🔥',
            'zone'  => 'home:mostwanted',
        ]);
    }

    private function section_new(): string
    {
        return $this->cached_rail('new', [
            Zooboxi_Product_Rail::q_new(24),
            Zooboxi_Product_Rail::q_newest(24),
        ], [
            'title' => __('وصل حديثاً', 'zooboxi'),
            'icon'  => '✨',
            'zone'  => 'home:new',
        ]);
    }

    private function section_clearance(): string
    {
        if (get_option('zooboxi_clearance_collection', 'yes') !== 'yes') {
            return '';
        }
        return $this->cached_rail('clearance', [
            Zooboxi_Product_Rail::q_clearance(24),
        ], [
            'title'      => __('عروض التصفية', 'zooboxi'),
            'subtitle'   => __('كميات محدودة', 'zooboxi'),
            'icon'       => '🏷️',
            'zone'       => 'home:clearance',
            'class'      => 'zb-rail--clearance',
            'badge_mode' => 'clearance',
        ]);
    }

    /**
     * Inline ad banner between rails. Uses a live campaign 'shop_top' creative when
     * present; otherwise an on-brand promo strip (never empty, never a fake offer).
     */
    private function section_banner(string $slot): string
    {
        if (get_option('zooboxi_campaigns_enabled', 'no') === 'yes') {
            $cached = get_transient('zooboxi_campaigns_cache');
            if (is_array($cached)) {
                $now = current_time('timestamp');
                foreach ($cached as $c) {
                    $zones = $c['zones'] ?? [];
                    if (!is_array($zones) || !in_array('shop_top', $zones, true)) { continue; }
                    if (!empty($c['ends_at']) && strtotime($c['ends_at']) < $now) { continue; }
                    $img = $c['creatives']['A']['wide'] ?? ($c['creatives']['A']['hero'] ?? null);
                    if (!$img) { continue; }
                    $cid = (int) ($c['id'] ?? 0);
                    $wid = (int) ($c['woo_product_id'] ?? 0);
                    $link = $wid > 0 ? (get_permalink($wid) ?: wc_get_page_permalink('shop')) : wc_get_page_permalink('shop');
                    return '<a class="zb-home-banner zb-camp" href="' . esc_url($link) . '" data-zb-campaign="' . $cid
                        . '" data-zb-zone="' . esc_attr('campaign:' . $cid . ':shop_top') . '" data-zb-variant="A" data-zb-item="' . esc_attr((string) ($c['item_code'] ?? '')) . '">'
                        . '<img src="' . esc_url($img) . '" alt="' . esc_attr((string) ($c['headline_ar'] ?? '')) . '" loading="lazy"></a>';
                }
            }
        }

        // Static on-brand promo strips (alternate by slot).
        $shop = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/');
        $strips = [
            'a' => ['theme' => 'teal',  'icon' => '🚀', 'title' => __('توصيل خلال ساعتين لكل أنحاء مدينتك', 'zooboxi'), 'sub' => __('من أقرب مستودع — لكل مستلزمات حيوانك الأليف', 'zooboxi'), 'cta' => __('تسوّق الآن', 'zooboxi')],
            'b' => ['theme' => 'coral', 'icon' => '💯', 'title' => __('منتجات أصلية 100% مستوردة مباشرة', 'zooboxi'), 'sub' => __('أفضل الماركات العالمية بين يديك', 'zooboxi'), 'cta' => __('اكتشف الماركات', 'zooboxi')],
        ];
        $s = $strips[$slot] ?? $strips['a'];
        return '<a class="zb-home-banner zb-home-banner--promo zb-home-banner--' . esc_attr($s['theme']) . '" href="' . esc_url($shop) . '">'
            . '<span class="zb-home-banner__icon" aria-hidden="true">' . esc_html($s['icon']) . '</span>'
            . '<span class="zb-home-banner__txt"><span class="zb-home-banner__title">' . esc_html($s['title']) . '</span>'
            . '<span class="zb-home-banner__sub">' . esc_html($s['sub']) . '</span></span>'
            . '<span class="zb-home-banner__cta">' . esc_html($s['cta']) . '</span></a>';
    }

    private function section_categories(): string
    {
        $pills = [
            ['🍽️ طعام القطط', '/product-category/قطط/طعام/'],
            ['🥩 طعام الكلاب', '/product-category/كلاب/طعام/'],
            ['🧸 مستلزمات القطط', '/product-category/مستلزمات-القطط/'],
            ['🦴 مستلزمات الكلاب', '/product-category/مستلزمات-الكلاب/'],
            ['🥫 الطعام الرطب', '/product-category/قطط/الطعام-الرطب/'],
            ['🍖 المكافآت والفيتامينات', '/product-category/المكافآت-والفيتامينات/'],
            ['🎾 ألعاب وكاتنيب', '/product-category/العاب-وكاتنيب/'],
            ['🌾 طعام الطيور', '/product-category/طيور/طعام-ومكافات-الطيور/'],
            ['🏠 بيوت وأقفاص', '/product-category/وسادات-وبيوت-واقفاص/'],
            ['🎗️ مشدات وصدريات', '/product-category/مشدات-وصدريات/'],
            ['📿 أطواق', '/product-category/اطواق/'],
            ['🪵 أثاث وخداشات', '/product-category/اثاث-وخداشات/'],
        ];
        $out = '<div class="zbx-categories-grid"><h2 class="zb-rail__title zb-rail__title--center">'
            . esc_html__('تصفّح الأقسام', 'zooboxi') . '</h2><div class="zbx-cats">';
        foreach ($pills as [$label, $url]) {
            $out .= '<a href="' . esc_url($url) . '" class="zbx-cat-pill">' . esc_html($label) . '</a>';
        }
        $out .= '</div></div>';
        return $out;
    }

    private function section_features(): string
    {
        $items = [
            ['🚀', __('توصيل سريع', 'zooboxi'), __('توصيل خلال ساعتين من أقرب مستودع في مدينتك', 'zooboxi')],
            ['💯', __('منتجات أصلية', 'zooboxi'), __('جميع منتجاتنا أصلية 100% ومستوردة مباشرة من المصنع', 'zooboxi')],
            ['🔄', __('إرجاع سهل', 'zooboxi'), __('سياسة إرجاع مرنة خلال 14 يوم من تاريخ الشراء', 'zooboxi')],
            ['🏬', __('استلام من الفرع', 'zooboxi'), __('استلم طلبك مجاناً من أقرب فرع لموقعك', 'zooboxi')],
        ];
        $out = '<div class="zbx-features-section">';
        foreach ($items as [$icon, $title, $desc]) {
            $out .= '<div class="zbx-feature"><div class="zbx-feature__icon" aria-hidden="true">' . esc_html($icon) . '</div>'
                . '<h3>' . esc_html($title) . '</h3><p>' . esc_html($desc) . '</p></div>';
        }
        $out .= '</div>';
        return $out;
    }

    /* ── Helpers ─────────────────────────────────────── */

    /**
     * Render a global rail with its resolved product-ID list cached in a transient
     * (1h, mirroring the hourly intelligence snapshot sync), so repeated front-page
     * loads run a cheap post__in query instead of a meta-sorted scan over 4k+ products.
     */
    /** Products already shown in earlier shell rails this request (cross-rail dedup). */
    private array $shell_used = [];

    private function cached_rail(string $key, array $queries, array $render_args): string
    {
        $tkey = 'zbhome_ids_' . $key . '_' . get_locale();
        $ids  = get_transient($tkey);
        if ($ids === false) {
            $ids = [];
            foreach ($queries as $qa) {
                $ids = $this->resolve_ids($qa);
                if (!empty($ids)) {
                    break;
                }
            }
            set_transient($tkey, $ids, HOUR_IN_SECONDS);
        }
        // Drop anything already shown in an earlier shell rail, then cap at 12.
        if (!empty($this->shell_used)) {
            $ids = array_values(array_diff($ids, $this->shell_used));
        }
        if (empty($ids)) {
            return '';
        }
        $ids = array_slice($ids, 0, 12);
        $this->shell_used = array_merge($this->shell_used, $ids);
        return Zooboxi_Product_Rail::render(array_merge($render_args, ['ids' => $ids]));
    }

    private function resolve_ids(array $query_args): array
    {
        $query_args['fields']        = 'ids';
        $query_args['no_found_rows'] = true;
        $q = new WP_Query($query_args);
        $ids = is_array($q->posts) ? array_map('intval', $q->posts) : [];
        wp_reset_postdata();
        return $ids;
    }

    /** Skeleton placeholder shown until the JS swaps in the hydrated rail. */
    private function skeleton_rail(string $title): string
    {
        $cards = '';
        for ($i = 0; $i < 6; $i++) {
            $cards .= '<div class="zb-skel zb-skel-card"></div>';
        }
        return '<div class="zb-rail zb-rail--skel" aria-hidden="true">'
            . '<div class="zb-rail__head"><div class="zb-skel zb-skel-title"></div></div>'
            . '<div class="zb-rail__scroller"><div class="zb-skel-track">' . $cards . '</div></div>'
            . '</div>';
    }
}
