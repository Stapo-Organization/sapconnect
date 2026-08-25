<?php
/**
 * Zooboxi_Hero_Slider — the smart homepage hero carousel.
 *
 * Builds an ordered list of slides from THREE sources and renders one autoplaying,
 * swipeable carousel (cache-safe: same for every visitor → stays in the page shell):
 *
 *   1) MANUAL   — owner-uploaded banners (option `zooboxi_hero_slides`), managed from
 *                 the "🖼️ السلايدر" admin page (image + mobile image + link + text + CTA).
 *   2) CAMPAIGN — live owner-approved campaigns targeting the hero zone (read from the
 *                 `zooboxi_campaigns_cache` transient that Zooboxi_Campaigns maintains).
 *                 Keeps data-zb-* attributes so the existing beacon tracks them.
 *   3) AUTO     — on-brand gradient panels generated from store data (express promise,
 *                 clearance, bestsellers, a featured brand). Used to FILL so the hero is
 *                 never empty / never looks broken even with zero campaign creatives.
 *
 * Front render is a pure static method used by Zooboxi_Homepage::section_hero().
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Hero_Slider
{
    private const OPTION   = 'zooboxi_hero_slides';
    private const MAX_AUTO = 4;        // hard cap on slides we'll show
    private const MENU     = 'zooboxi-hero';

    public function __construct()
    {
        add_action('admin_menu', [$this, 'admin_menu'], 30);
    }

    /* ════════════════════════ FRONT RENDER ════════════════════════ */

    public static function render(): string
    {
        // Lead with the responsive, full-width brand HTML hero (crisp at any size).
        // Owner manual banners still take priority if present.
        $slides = self::manual_slides();
        $bh = self::brandhtml_slide();
        if ($bh) {
            $slides[] = $bh;
        }
        // Only fall back to the AI/auto slides when the HTML hero isn't available.
        if (empty($slides)) {
            $slides = self::campaign_slides();
            $identity = self::identity_slide();
            if ($identity) {
                $slides[] = $identity;
            }
        }
        // Fill with on-brand auto slides up to the cap so the hero is never empty.
        if (count($slides) < self::MAX_AUTO) {
            foreach (self::auto_slides() as $a) {
                $slides[] = $a;
                if (count($slides) >= self::MAX_AUTO) {
                    break;
                }
            }
        }
        $slides = array_slice($slides, 0, self::MAX_AUTO);
        if (empty($slides)) {
            return '';
        }

        $multi = count($slides) > 1;
        ob_start();
        echo '<div class="zb-hero' . ($multi ? '' : ' zb-hero--single') . '" data-zb-autoplay="6000" role="region" aria-roledescription="carousel" aria-label="' . esc_attr__('عروض المتجر', 'zooboxi') . '">';
        echo '<div class="zb-hero__viewport"><div class="zb-hero__track">';
        foreach ($slides as $i => $s) {
            echo self::slide_html($s, $i);
        }
        echo '</div></div>';

        if ($multi) {
            echo '<button type="button" class="zb-hero__arrow zb-hero__arrow--prev" aria-label="' . esc_attr__('السابق', 'zooboxi') . '">‹</button>';
            echo '<button type="button" class="zb-hero__arrow zb-hero__arrow--next" aria-label="' . esc_attr__('التالي', 'zooboxi') . '">›</button>';
            echo '<div class="zb-hero__dots" role="tablist">';
            foreach ($slides as $i => $s) {
                echo '<button type="button" class="zb-hero__dot' . ($i === 0 ? ' is-active' : '') . '" data-zb-go="' . $i . '" aria-label="' . esc_attr(sprintf(__('شريحة %d', 'zooboxi'), $i + 1)) . '"></button>';
            }
            echo '</div>';
        }
        echo '</div>';
        return ob_get_clean();
    }

    private static function slide_html(array $s, int $i): string
    {
        $href  = !empty($s['link']) ? $s['link'] : '#';
        $track = '';
        if (!empty($s['track']['campaign'])) {
            $track = ' data-zb-campaign="' . (int) $s['track']['campaign'] . '"'
                . ' data-zb-zone="' . esc_attr($s['track']['zone'] ?? '') . '"'
                . ' data-zb-variant="' . esc_attr($s['track']['variant'] ?? 'A') . '"'
                . ' data-zb-item="' . esc_attr($s['track']['item'] ?? '') . '"';
        }

        $cls = 'zb-hero__slide' . ($i === 0 ? ' is-active' : '');
        $kind = $s['kind'] ?? 'image';

        // Responsive, full-width brand HTML hero (ported from the brand-kit hero-banner;
        // a fixed 1600×600 stage scaled to the container by JS → crisp at any width).
        if ($kind === 'brandhtml') {
            return self::brandhtml_html($s, $i);
        }

        // Signature brand-identity slide: logo + headline + CTA + a floating product
        // collage from focus brands + a brand-trust strip.
        if ($kind === 'identity') {
            $o  = '<a class="' . $cls . ' zb-hero__slide--identity" href="' . esc_url($href) . '" role="group" aria-roledescription="' . esc_attr__('شريحة', 'zooboxi') . '">';
            $o .= '<span class="zb-hero__id-art" aria-hidden="true">';
            foreach (array_slice($s['products'] ?? [], 0, 5) as $k => $p) {
                $o .= '<span class="zb-hero__id-prod zb-hero__id-prod--' . ($k + 1) . '"><img src="' . esc_url($p) . '" alt="" loading="lazy"></span>';
            }
            $o .= '</span>';
            $o .= '<span class="zb-hero__id-copy">';
            if (!empty($s['logo'])) {
                $o .= '<span class="zb-hero__id-logo"><img src="' . esc_url($s['logo']) . '" alt="Zooboxi"' . ($i === 0 ? ' fetchpriority="high"' : '') . '></span>';
            }
            $o .= '<span class="zb-hero__id-title">' . esc_html($s['headline'] ?? '') . '</span>';
            $o .= '<span class="zb-hero__id-sub">' . esc_html($s['subheadline'] ?? '') . '</span>';
            $o .= '<span class="zb-hero__cta">' . esc_html($s['cta_label'] ?? '') . '</span>';
            if (!empty($s['brands'])) {
                $o .= '<span class="zb-hero__id-brands">';
                foreach ($s['brands'] as $b) {
                    $o .= '<span class="zb-hero__id-brand"><img src="' . esc_url($b) . '" alt="" loading="lazy"></span>';
                }
                $o .= '</span>';
            }
            $o .= '</span></a>';
            return $o;
        }

        if ($kind === 'auto') {
            $cls .= ' zb-hero__slide--auto zb-hero__slide--' . esc_attr($s['theme'] ?? 'teal');
        }

        $out  = '<a class="' . $cls . '" href="' . esc_url($href) . '"' . $track . ' role="group" aria-roledescription="' . esc_attr__('شريحة', 'zooboxi') . '">';

        // Visual layer
        if ($kind === 'image' && !empty($s['image'])) {
            $mob = !empty($s['image_mobile']) ? $s['image_mobile'] : $s['image'];
            $out .= '<picture class="zb-hero__media">';
            $out .= '<source media="(max-width: 768px)" srcset="' . esc_url($mob) . '">';
            $out .= '<img src="' . esc_url($s['image']) . '" alt="' . esc_attr($s['headline'] ?? 'Zooboxi') . '"' . ($i === 0 ? ' fetchpriority="high"' : ' loading="lazy"') . '>';
            $out .= '</picture>';
        } elseif ($kind === 'auto' && !empty($s['logo'])) {
            $out .= '<span class="zb-hero__brandlogo"><img src="' . esc_url($s['logo']) . '" alt="' . esc_attr($s['headline'] ?? '') . '" loading="lazy"></span>';
        }

        // Text overlay (skip empty)
        $hl = $s['headline'] ?? '';
        $sub = $s['subheadline'] ?? '';
        $cta = $s['cta_label'] ?? '';
        if ($hl !== '' || $sub !== '' || $cta !== '') {
            $out .= '<span class="zb-hero__overlay">';
            if ($hl !== '')  { $out .= '<span class="zb-hero__headline">' . esc_html($hl) . '</span>'; }
            if ($sub !== '') { $out .= '<span class="zb-hero__sub">' . esc_html($sub) . '</span>'; }
            if ($cta !== '') { $out .= '<span class="zb-hero__cta">' . esc_html($cta) . '</span>'; }
            $out .= '</span>';
        }
        $out .= '</a>';
        return $out;
    }

    /* ════════════════════════ SLIDE SOURCES ════════════════════════ */

    /** Owner-uploaded banners, active + within optional date window, ordered. */
    private static function manual_slides(): array
    {
        $raw = get_option(self::OPTION, []);
        if (!is_array($raw) || empty($raw)) {
            return [];
        }
        $now = current_time('timestamp');
        $out = [];
        foreach ($raw as $r) {
            if (empty($r['active']) || empty($r['image'])) {
                continue;
            }
            if (!empty($r['start']) && strtotime($r['start']) > $now) { continue; }
            if (!empty($r['end'])   && strtotime($r['end'])   < $now) { continue; }
            $out[] = [
                'kind'         => 'image',
                'image'        => $r['image'],
                'image_mobile' => $r['image_mobile'] ?? '',
                'link'         => $r['link'] ?? '',
                'headline'     => $r['headline'] ?? '',
                'subheadline'  => $r['subheadline'] ?? '',
                'cta_label'    => $r['cta_label'] ?? '',
                'order'        => isset($r['order']) ? (int) $r['order'] : 0,
            ];
        }
        usort($out, fn($a, $b) => $a['order'] <=> $b['order']);
        return $out;
    }

    /** Live hero-zone campaigns (read the cache transient Zooboxi_Campaigns maintains). */
    private static function campaign_slides(): array
    {
        if (get_option('zooboxi_campaigns_enabled', 'no') !== 'yes' || get_option('zb_zone_hero', 'no') !== 'yes') {
            return [];
        }
        $cached = get_transient('zooboxi_campaigns_cache');
        // Self-heal: if the cache is cold (expired / flushed), pull the live set now so the
        // hero banner never silently disappears between the hourly sync cron runs.
        if ((!is_array($cached) || empty($cached)) && class_exists('Zooboxi_Campaigns')) {
            $cached = (new Zooboxi_Campaigns())->sync_campaigns();
        }
        if (!is_array($cached) || empty($cached)) {
            return [];
        }
        $now = current_time('timestamp');
        $out = [];
        foreach ($cached as $c) {
            $zones = $c['zones'] ?? [];
            if (!is_array($zones) || !in_array('hero', $zones, true)) { continue; }
            if (!empty($c['ends_at']) && strtotime($c['ends_at']) < $now) { continue; }
            $img = $c['creatives']['A']['hero'] ?? ($c['creatives']['A']['wide'] ?? null);
            if (!$img) { continue; }
            // Square card for mobile (the wide hero is too short on phones).
            $mob = $c['creatives']['A']['card'] ?? $img;
            $cid = (int) ($c['id'] ?? 0);
            $link = '';
            $wid = (int) ($c['woo_product_id'] ?? 0);
            if ($wid > 0) { $link = get_permalink($wid) ?: ''; }
            if ($link === '') { $link = wc_get_page_permalink('shop'); }
            $out[] = [
                'kind'         => 'image',
                'image'        => $img,
                'image_mobile' => $mob,
                'link'         => $link,
                // The AI banner already contains the headline/CTA → no overlay.
                'headline'    => '',
                'subheadline' => '',
                'cta_label'   => '',
                'track'       => ['campaign' => $cid, 'zone' => 'campaign:' . $cid . ':hero', 'variant' => 'A', 'item' => (string) ($c['item_code'] ?? '')],
            ];
        }
        return $out;
    }

    /** On-brand gradient panels from store data — guarantees a full, attractive hero. */
    private static function auto_slides(): array
    {
        $shop = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/');
        $slides = [];

        // 1) Express delivery promise (always available).
        $slides[] = [
            'kind' => 'auto', 'theme' => 'teal',
            'headline' => __('توصيل خلال ساعتين 🚀', 'zooboxi'),
            'subheadline' => __('من أقرب مستودع لك في مدينتك — لكل مستلزمات حيوانك', 'zooboxi'),
            'cta_label' => __('تسوّق الآن', 'zooboxi'),
            'link' => $shop,
        ];

        // 2) Clearance (only if there are clearance products).
        if (self::has_clearance()) {
            $slides[] = [
                'kind' => 'auto', 'theme' => 'coral',
                'headline' => __('عروض التصفية 🏷️', 'zooboxi'),
                'subheadline' => __('أسعار مخفّضة على منتجات مختارة — كميات محدودة', 'zooboxi'),
                'cta_label' => __('اكتشف العروض', 'zooboxi'),
                'link' => $shop,
            ];
        }

        // 3) Featured brand (a top brand that has a logo).
        $brand = self::featured_brand();
        if ($brand) {
            $slides[] = [
                'kind' => 'auto', 'theme' => 'mixed',
                'logo' => $brand['logo'],
                'headline' => sprintf(__('ماركة %s', 'zooboxi'), $brand['name']),
                'subheadline' => __('منتجات أصلية 100% مستوردة مباشرة', 'zooboxi'),
                'cta_label' => __('تسوّق الماركة', 'zooboxi'),
                'link' => $brand['link'],
            ];
        }

        // 4) Bestsellers.
        $slides[] = [
            'kind' => 'auto', 'theme' => 'teal',
            'headline' => __('الأكثر مبيعاً 🔥', 'zooboxi'),
            'subheadline' => __('اكتشف مفضّلات عملائنا الأكثر طلباً', 'zooboxi'),
            'cta_label' => __('تصفّح', 'zooboxi'),
            'link' => $shop,
        ];

        return $slides;
    }

    /**
     * Signature brand-identity slide — real product images from focus brands
     * (Applaws / Kit Cat / Acana / Felyn Go / Josera) + their brand logos + the
     * Zooboxi wordmark. Built dynamically (cached 6h) so imagery stays valid.
     */
    private static function identity_slide(): ?array
    {
        $focus = [
            1513 => 'Applaws',
            1489 => 'Kit Cat',
            1537 => 'Acana',
            1493 => 'Felyn Go',
            1522 => 'Josera',
        ];

        $imgs = get_transient('zbhero_identity_imgs');
        if (!is_array($imgs)) {
            $imgs = [];
            foreach (array_keys($focus) as $tid) {
                $q = new WP_Query([
                    'post_type' => 'product', 'post_status' => 'publish', 'posts_per_page' => 1,
                    'fields' => 'ids', 'no_found_rows' => true, 'orderby' => 'rand',
                    'tax_query' => [['taxonomy' => 'product_brand', 'field' => 'term_id', 'terms' => $tid]],
                    'meta_query' => [
                        ['key' => '_stock_status', 'value' => 'instock'],
                        ['key' => '_thumbnail_id', 'compare' => 'EXISTS'],
                    ],
                ]);
                foreach ($q->posts as $pid) {
                    $u = wp_get_attachment_image_url(get_post_thumbnail_id($pid), 'woocommerce_thumbnail');
                    if ($u) { $imgs[] = $u; }
                }
                wp_reset_postdata();
            }
            set_transient('zbhero_identity_imgs', $imgs, 6 * HOUR_IN_SECONDS);
        }
        if (count($imgs) < 3) {
            return null; // not enough imagery yet → let the auto slides lead
        }

        $brand_logos = [];
        foreach (array_keys($focus) as $tid) {
            $lg = get_term_meta($tid, 'thumbnail_id', true);
            if ($lg) {
                $u = wp_get_attachment_image_url((int) $lg, 'medium');
                if ($u) { $brand_logos[] = $u; }
            }
        }

        $upload = wp_get_upload_dir();
        return [
            'kind'        => 'identity',
            'logo'        => $upload['baseurl'] . '/zooboxi-assets/ceb32bf7-abc5-4b15-b88f-9002f9eb27c9-200x.png',
            'products'    => array_slice($imgs, 0, 5),
            'brands'      => $brand_logos,
            'headline'    => __('كل ما يحتاجه أليفك', 'zooboxi'),
            'subheadline' => __('يوصلك خلال ساعتين ⚡ من أقرب مستودع في مدينتك', 'zooboxi'),
            'cta_label'   => __('تسوّق الآن', 'zooboxi'),
            'link'        => function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/'),
        ];
    }

    /** The responsive brand HTML hero (assets uploaded to /uploads/zooboxi-assets/brandhero). */
    private static function brandhtml_slide(): ?array
    {
        $base = '/wp-content/uploads/zooboxi-assets/brandhero';
        // Mobile gets the gpt-image 3:2 banner (fits phones); else the scaled HTML.
        $mobile = '';
        $cached = get_transient('zooboxi_campaigns_cache');
        if (is_array($cached)) {
            foreach ($cached as $c) {
                if (is_array($c['zones'] ?? null) && in_array('hero', $c['zones'], true)) {
                    $mobile = (string) ($c['creatives']['A']['hero'] ?? '');
                    break;
                }
            }
        }
        return [
            'kind'   => 'brandhtml',
            'base'   => $base,
            'mobile' => $mobile,
            'link'   => function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/'),
        ];
    }

    /** Render the brand HTML hero markup (fixed 1600×600 stage; JS scales it to width). */
    private static function brandhtml_html(array $s, int $i): string
    {
        $base   = esc_url($s['base']);
        $href   = esc_url($s['link'] ?? '#');
        $mobile = (string) ($s['mobile'] ?? '');
        $cls    = 'zb-hero__slide zb-hero__slide--bh' . ($i === 0 ? ' is-active' : '');

        $arrow  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M13 6l-6 6 6 6M7 12h11"/></svg>';
        $bolt   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2.5 4.5 13.5H11l-1 8 8.5-11.5H12l1-7.5Z"/></svg>';
        $shield = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 5.8v5.1c0 4.4 3 7.5 7 9 4-1.5 7-4.6 7-9V5.8L12 3Z"/><path d="m9 11.8 2 2 4-4"/></svg>';
        $truck  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 6.5h11v9.5h-11zM13.5 9.5h3.6L21 12.6V16h-7.5"/><circle cx="6.5" cy="18" r="1.8"/><circle cx="17" cy="18" r="1.8"/></svg>';
        $paw    = '<svg viewBox="0 0 24 24"><g fill="#429D9C"><ellipse cx="6" cy="9.5" rx="1.9" ry="2.5"/><ellipse cx="10.5" cy="6.6" rx="2" ry="2.7"/><ellipse cx="15.5" cy="7.4" rx="1.9" ry="2.5"/><ellipse cx="19" cy="11" rx="1.7" ry="2.2"/><path d="M12.2 12.4c-3 0-5.2 2.2-5.2 4.6 0 1.9 1.7 3 3.4 2.2.95-.45 2.7-.45 3.6 0 1.7.8 3.4-.3 3.4-2.2 0-2.4-2.2-4.6-5.2-4.6Z"/></g></svg>';

        $fp = $i === 0 ? ' fetchpriority="high"' : ' loading="lazy"';
        $mob = $mobile !== '' ? '<img class="zb-bh-mobile" src="' . esc_url($mobile) . '" alt="Zooboxi"' . $fp . '>' : '';

        return '<a class="' . $cls . '" href="' . $href . '" role="group" aria-label="Zooboxi">'
            . $mob
            . '<span class="zb-bh-wrap"><span class="zb-bh" dir="rtl">'
            . '<span class="zb-bh-blob zb-bh-coral"></span><span class="zb-bh-blob zb-bh-amber"></span>'
            . '<span class="zb-bh-dot" style="width:16px;height:16px;background:#F4BE2C;top:78px;left:58px"></span>'
            . '<span class="zb-bh-dot" style="width:11px;height:11px;background:#D46856;top:150px;left:770px"></span>'
            . '<span class="zb-bh-dot" style="width:13px;height:13px;background:#429D9C;bottom:86px;left:38px"></span>'
            . '<span class="zb-bh-dot" style="width:14px;height:14px;background:#7CC6C2;top:300px;left:18px"></span>'
            . '<span class="zb-bh-paw" style="width:58px;height:58px;top:38px;left:372px;transform:rotate(20deg)">' . $paw . '</span>'
            . '<span class="zb-bh-paw" style="width:44px;height:44px;bottom:54px;left:300px;transform:rotate(-12deg)">' . $paw . '</span>'
            . '<span class="zb-bh-collage"><span class="zb-bh-stage"></span>'
            . '<img class="zb-bh-p zb-bh-pouch" src="' . $base . '/applaws-pouch.png" alt="">'
            . '<img class="zb-bh-p zb-bh-bird" src="' . $base . '/versele-birdfood.png" alt="">'
            . '<img class="zb-bh-p zb-bh-bowls" src="' . $base . '/mpb-bowls.png" alt="">'
            . '<img class="zb-bh-p zb-bh-cups" src="' . $base . '/inaba-cups.png" alt="">'
            . '<img class="zb-bh-p zb-bh-can" src="' . $base . '/drclauders-can.png" alt="">'
            . '<img class="zb-bh-p zb-bh-toy" src="' . $base . '/smartykat-toy.png" alt="">'
            . '<img class="zb-bh-p zb-bh-anchor" src="' . $base . '/core-catfood.png" alt="">'
            . '</span>'
            . '<span class="zb-bh-txt">'
            . '<img class="zb-bh-logo" src="' . $base . '/logo.png" alt="Zooboxi">'
            . '<span class="zb-bh-pills"><span class="zb-bh-pill coral">🎉 ' . esc_html__('افتتاح متجرنا الجديد', 'zooboxi') . '</span>'
            . '<span class="zb-bh-pill teal">📍 ' . esc_html__('التوصيل السريع الآن في الرياض', 'zooboxi') . '</span></span>'
            . '<span class="zb-bh-h1">' . esc_html__('كل ما يحتاجه أليفك…', 'zooboxi') . '<br><span class="hl">' . esc_html__('يوصلك خلال ساعتين', 'zooboxi') . '</span> 🐾</span>'
            . '<span class="zb-bh-sub">' . esc_html__('قطط · كلاب · طيور · حيوانات صغيرة — منتجات أصلية ١٠٠٪ من أفضل البراندات، وتوصيل خلال ساعتين داخل الرياض.', 'zooboxi') . '</span>'
            . '<span class="zb-bh-cta">' . esc_html__('تسوّق الآن', 'zooboxi') . ' ' . $arrow . '</span>'
            . '<span class="zb-bh-chips">'
            . '<span class="zb-bh-chip c1">' . $bolt . ' ' . esc_html__('توصيل ساعتين · الرياض', 'zooboxi') . '</span>'
            . '<span class="zb-bh-chip c2">' . $shield . ' ' . esc_html__('أصلي ١٠٠٪', 'zooboxi') . '</span>'
            . '<span class="zb-bh-chip c3">' . $truck . ' ' . esc_html__('شحن لكل السعودية', 'zooboxi') . '</span>'
            . '</span>'
            . '</span>'
            . '</span></span></a>';
    }

    private static function has_clearance(): bool
    {
        $t = get_transient('zbhome_ids_clearance_' . get_locale());
        if (is_array($t)) {
            return !empty($t);
        }
        $q = new WP_Query([
            'post_type' => 'product', 'post_status' => 'publish', 'posts_per_page' => 1,
            'fields' => 'ids', 'no_found_rows' => true,
            'meta_query' => [['key' => '_zb_clearance', 'value' => '1']],
        ]);
        $has = !empty($q->posts);
        wp_reset_postdata();
        return $has;
    }

    /** Highest-product-count brand that has an uploaded logo. */
    private static function featured_brand(): ?array
    {
        $cache = get_transient('zbhero_featured_brand');
        if (is_array($cache)) {
            return $cache ?: null;
        }
        $terms = get_terms(['taxonomy' => 'product_brand', 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => 12]);
        $found = null;
        if (!is_wp_error($terms)) {
            foreach ($terms as $t) {
                $logo_id = get_term_meta($t->term_id, 'thumbnail_id', true);
                if ($logo_id) {
                    $url = wp_get_attachment_image_url((int) $logo_id, 'medium');
                    if ($url) {
                        $found = ['name' => $t->name, 'logo' => $url, 'link' => get_term_link($t)];
                        break;
                    }
                }
            }
        }
        set_transient('zbhero_featured_brand', $found ?: [], 6 * HOUR_IN_SECONDS);
        return $found;
    }

    /* ════════════════════════ ADMIN PANEL ════════════════════════ */

    public function admin_menu(): void
    {
        add_submenu_page(
            'zooboxi',
            __('سلايدر الصفحة الرئيسية', 'zooboxi'),
            __('🖼️ السلايدر', 'zooboxi'),
            'manage_woocommerce',
            self::MENU,
            [$this, 'render_admin']
        );
    }

    public function render_admin(): void
    {
        if (!current_user_can('manage_woocommerce')) {
            return;
        }
        $saved = false;
        if (isset($_POST['zbhero_save']) && check_admin_referer('zbhero_settings')) {
            $slides = [];
            $rows = isset($_POST['slide']) && is_array($_POST['slide']) ? $_POST['slide'] : [];
            foreach ($rows as $r) {
                $image = esc_url_raw($r['image'] ?? '');
                if ($image === '') { continue; } // skip empty rows
                $slides[] = [
                    'image'        => $image,
                    'image_mobile' => esc_url_raw($r['image_mobile'] ?? ''),
                    'link'         => esc_url_raw($r['link'] ?? ''),
                    'headline'     => sanitize_text_field($r['headline'] ?? ''),
                    'subheadline'  => sanitize_text_field($r['subheadline'] ?? ''),
                    'cta_label'    => sanitize_text_field($r['cta_label'] ?? ''),
                    'order'        => (int) ($r['order'] ?? 0),
                    'active'       => !empty($r['active']) ? 1 : 0,
                ];
            }
            update_option(self::OPTION, $slides);
            delete_transient('zbhero_featured_brand');
            $saved = true;
        }

        $slides = get_option(self::OPTION, []);
        if (!is_array($slides)) { $slides = []; }
        // Always render a few blank rows for adding new slides.
        $rows = $slides;
        for ($i = count($rows); $i < max(3, count($slides) + 1); $i++) {
            $rows[] = ['image' => '', 'active' => 1];
        }

        wp_enqueue_media();
        ?>
        <div class="wrap">
            <h1>🖼️ <?php esc_html_e('سلايدر الصفحة الرئيسية', 'zooboxi'); ?></h1>
            <p style="max-width:760px;color:#555">
                <?php esc_html_e('ارفع بانرات إعلانية تظهر في أعلى الصفحة الرئيسية. الشرائح اليدوية تظهر أولاً، ثم الحملات المعتمدة، ثم شرائح تلقائية ذكية تملأ الفراغ — فلا يكون السلايدر فارغاً أبداً.', 'zooboxi'); ?>
            </p>
            <?php if ($saved): ?><div class="notice notice-success"><p>✓ <?php esc_html_e('تم الحفظ', 'zooboxi'); ?></p></div><?php endif; ?>

            <form method="post">
                <?php wp_nonce_field('zbhero_settings'); ?>
                <div id="zbhero-rows">
                    <?php foreach ($rows as $idx => $s): ?>
                        <?php echo self::admin_row((int) $idx, $s); ?>
                    <?php endforeach; ?>
                </div>
                <p><button type="button" class="button" id="zbhero-add">＋ <?php esc_html_e('إضافة شريحة', 'zooboxi'); ?></button></p>
                <p><button type="submit" name="zbhero_save" value="1" class="button button-primary button-large"><?php esc_html_e('حفظ الشرائح', 'zooboxi'); ?></button></p>
            </form>
        </div>

        <template id="zbhero-tpl"><?php echo self::admin_row(99999, ['image' => '', 'active' => 1]); ?></template>
        <style>
            .zbhero-row{background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:16px;margin:0 0 14px;display:grid;grid-template-columns:160px 1fr;gap:16px}
            .zbhero-thumb{width:160px;height:90px;border-radius:8px;background:#f0f0f1 center/cover no-repeat;border:1px dashed #c3c4c7;display:flex;align-items:center;justify-content:center;color:#888;font-size:12px;text-align:center;cursor:pointer;overflow:hidden}
            .zbhero-thumb img{width:100%;height:100%;object-fit:cover}
            .zbhero-fields{display:grid;grid-template-columns:1fr 1fr;gap:10px}
            .zbhero-fields label{display:block;font-size:12px;font-weight:600;color:#3c434a;margin-bottom:3px}
            .zbhero-fields input[type=text],.zbhero-fields input[type=url],.zbhero-fields input[type=number]{width:100%}
            .zbhero-fields .full{grid-column:1/-1}
            .zbhero-row .row-tools{grid-column:1/-1;display:flex;justify-content:space-between;align-items:center;border-top:1px solid #f0f0f1;padding-top:10px}
        </style>
        <script>
        (function(){
            var wrap = document.getElementById('zbhero-rows');
            var tpl  = document.getElementById('zbhero-tpl').innerHTML;
            var seq  = <?php echo (int) (count($rows) + 1); ?>;
            function bindRow(row){
                var thumb = row.querySelector('.zbhero-thumb');
                var input = row.querySelector('.zbhero-img-input');
                var mobInput = row.querySelector('.zbhero-mob-input');
                row.querySelectorAll('[data-pick]').forEach(function(btn){
                    btn.addEventListener('click', function(e){
                        e.preventDefault();
                        var target = btn.getAttribute('data-pick') === 'mobile' ? mobInput : input;
                        var frame = wp.media({title:'اختر صورة', multiple:false, library:{type:'image'}});
                        frame.on('select', function(){
                            var a = frame.state().get('selection').first().toJSON();
                            target.value = a.url;
                            if (btn.getAttribute('data-pick') !== 'mobile' && thumb) {
                                thumb.style.backgroundImage = "url('"+a.url+"')";
                                thumb.textContent = '';
                            }
                        });
                        frame.open();
                    });
                });
                var del = row.querySelector('.zbhero-del');
                if (del) del.addEventListener('click', function(e){ e.preventDefault(); row.remove(); });
            }
            wrap.querySelectorAll('.zbhero-row').forEach(bindRow);
            document.getElementById('zbhero-add').addEventListener('click', function(){
                var html = tpl.replace(/99999/g, String(seq++));
                var div = document.createElement('div'); div.innerHTML = html.trim();
                var row = div.firstElementChild; wrap.appendChild(row); bindRow(row);
            });
        })();
        </script>
        <?php
    }

    private static function admin_row(int $i, array $s): string
    {
        $g = fn($k, $d = '') => esc_attr($s[$k] ?? $d);
        $img = $s['image'] ?? '';
        ob_start();
        ?>
        <div class="zbhero-row">
            <div class="zbhero-thumb" data-pick="desktop" style="<?php echo $img ? 'background-image:url(\'' . esc_url($img) . '\')' : ''; ?>"><?php echo $img ? '' : esc_html__('اختر صورة الديسكتوب', 'zooboxi'); ?></div>
            <div class="zbhero-fields">
                <input type="hidden" class="zbhero-img-input" name="slide[<?php echo $i; ?>][image]" value="<?php echo esc_attr($img); ?>">
                <input type="hidden" class="zbhero-mob-input" name="slide[<?php echo $i; ?>][image_mobile]" value="<?php echo $g('image_mobile'); ?>">
                <div class="full"><label><?php esc_html_e('العنوان الرئيسي', 'zooboxi'); ?></label><input type="text" name="slide[<?php echo $i; ?>][headline]" value="<?php echo $g('headline'); ?>"></div>
                <div class="full"><label><?php esc_html_e('السطر الفرعي', 'zooboxi'); ?></label><input type="text" name="slide[<?php echo $i; ?>][subheadline]" value="<?php echo $g('subheadline'); ?>"></div>
                <div><label><?php esc_html_e('نص الزر (CTA)', 'zooboxi'); ?></label><input type="text" name="slide[<?php echo $i; ?>][cta_label]" value="<?php echo $g('cta_label'); ?>"></div>
                <div><label><?php esc_html_e('الترتيب', 'zooboxi'); ?></label><input type="number" name="slide[<?php echo $i; ?>][order]" value="<?php echo $g('order', '0'); ?>"></div>
                <div class="full"><label><?php esc_html_e('الرابط عند الضغط', 'zooboxi'); ?></label><input type="url" name="slide[<?php echo $i; ?>][link]" value="<?php echo $g('link'); ?>" placeholder="https://store.zooboxi.com/..."></div>
                <div class="row-tools">
                    <label style="font-size:13px"><input type="checkbox" name="slide[<?php echo $i; ?>][active]" value="1" <?php checked(!empty($s['active'])); ?>> <?php esc_html_e('مفعّلة', 'zooboxi'); ?></label>
                    <span>
                        <button type="button" class="button-link" data-pick="mobile"><?php esc_html_e('📱 صورة الجوال (اختياري)', 'zooboxi'); ?></button>
                        &nbsp;|&nbsp;
                        <button type="button" class="button-link zbhero-del" style="color:#b32d2e"><?php esc_html_e('حذف', 'zooboxi'); ?></button>
                    </span>
                </div>
            </div>
        </div>
        <?php
        return ob_get_clean();
    }
}
