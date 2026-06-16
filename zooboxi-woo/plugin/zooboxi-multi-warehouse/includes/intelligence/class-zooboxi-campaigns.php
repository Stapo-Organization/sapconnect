<?php

/**
 * Zooboxi_Campaigns — on-site ad banners driven by owner-approved campaigns from
 * sapconnect (GET /campaigns/active). Pulls + caches the live set, renders banner
 * zones via WooCommerce hooks/shortcodes, and tracks impressions/clicks through
 * the existing event spine (zone + ab_variant + payload.campaign_id).
 *
 * Channel-safe by construction: Phase 1 campaigns are visibility-only — banners
 * are pure links to products/collections; no price is ever touched here.
 *
 * Master toggle: option `zooboxi_campaigns_enabled` (default 'no').
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Campaigns
{
    private string $api_base;
    private string $api_token;

    private const CACHE_KEY = 'zooboxi_campaigns_cache';
    private const SYNCED_OPT = 'zooboxi_campaigns_synced_at';

    /** zone => [option flag, creative size key] */
    private const ZONES = [
        'hero'          => ['zb_zone_hero', 'hero'],
        'shop_top'      => ['zb_zone_shop_top', 'wide'],
        'product_strip' => ['zb_zone_product_strip', 'strip'],
    ];

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = get_option('zooboxi_api_token', '');

        // Hourly refresh of the live campaign set.
        add_action('zooboxi_sync_campaigns', [$this, 'sync_campaigns']);
        if (!wp_next_scheduled('zooboxi_sync_campaigns')) {
            wp_schedule_event(time() + 300, 'hourly', 'zooboxi_sync_campaigns');
        }

        // Manual "sync now" (admin).
        add_action('wp_ajax_zooboxi_sync_campaigns', [$this, 'ajax_sync']);

        // The hero zone is owner-placed via shortcode.
        add_shortcode('zooboxi_hero', [$this, 'hero_shortcode']);

        if (!$this->enabled()) {
            return;
        }

        // Auto zones.
        if ($this->zone_on('shop_top')) {
            add_action('woocommerce_before_shop_loop', [$this, 'render_shop_top'], 5);
        }
        if ($this->zone_on('product_strip')) {
            add_action('woocommerce_single_product_summary', [$this, 'render_product_strip'], 25);
        }

        // Impression/click beacon for banners.
        add_action('wp_footer', [$this, 'tracker_script']);
    }

    private function enabled(): bool
    {
        return get_option('zooboxi_campaigns_enabled', 'no') === 'yes';
    }

    private function zone_on(string $zone): bool
    {
        [$flag] = self::ZONES[$zone] ?? [null];
        return $flag ? get_option($flag, 'no') === 'yes' : false;
    }

    /* ── API + cache ─────────────────────────────── */

    public function sync_campaigns(): array
    {
        $res = wp_remote_get($this->api_base . '/campaigns/active', [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Accept' => 'application/json'],
            'timeout' => 30,
        ]);
        if (is_wp_error($res)) {
            return []; // keep the previous transient on network failure (never blank the store)
        }
        $body = json_decode(wp_remote_retrieve_body($res), true);
        $data = is_array($body) && isset($body['data']) && is_array($body['data']) ? $body['data'] : [];

        // A SUCCESSFUL pull replaces the cache (so removed/rejected campaigns drop).
        set_transient(self::CACHE_KEY, $data, 20 * MINUTE_IN_SECONDS);
        update_option(self::SYNCED_OPT, current_time('mysql'), false);
        return $data;
    }

    public function ajax_sync(): void
    {
        if (!current_user_can('manage_woocommerce')) {
            wp_die('', '', ['response' => 403]);
        }
        $data = $this->sync_campaigns();
        wp_send_json(['count' => count($data), 'synced_at' => get_option(self::SYNCED_OPT)]);
    }

    private function all_campaigns(): array
    {
        $cached = get_transient(self::CACHE_KEY);
        if ($cached === false) {
            $cached = $this->sync_campaigns();
        }
        return is_array($cached) ? $cached : [];
    }

    /** Live campaigns targeting a zone, freshest first, expiry re-checked at render. */
    private function campaigns_for_zone(string $zone): array
    {
        $now = current_time('timestamp');
        $out = [];
        foreach ($this->all_campaigns() as $c) {
            $zones = $c['zones'] ?? [];
            if (!is_array($zones) || !in_array($zone, $zones, true)) {
                continue;
            }
            // Render-time expiry guard regardless of cache freshness.
            if (!empty($c['ends_at']) && strtotime($c['ends_at']) < $now) {
                continue;
            }
            $out[] = $c;
        }
        return $out;
    }

    /* ── Rendering ───────────────────────────────── */

    public function hero_shortcode(): string
    {
        if (!$this->enabled() || !$this->zone_on('hero')) {
            return '';
        }
        $list = $this->campaigns_for_zone('hero');
        if (empty($list)) {
            return '';
        }
        // Rotate the hero daily for variety.
        $pick = $list[(int) date('j') % count($list)];
        return $this->render_banner($pick, 'hero', 'hero');
    }

    public function render_shop_top(): void
    {
        $list = $this->campaigns_for_zone('shop_top');
        if (!empty($list)) {
            echo $this->render_banner($list[0], 'shop_top', 'wide'); // phpcs:ignore WordPress.Security.EscapeOutput
        }
    }

    public function render_product_strip(): void
    {
        $list = $this->campaigns_for_zone('product_strip');
        if (!empty($list)) {
            echo $this->render_banner($list[0], 'product_strip', 'strip'); // phpcs:ignore WordPress.Security.EscapeOutput
        }
    }

    private function render_banner(array $c, string $zone, string $sizeKey): string
    {
        $variant = 'A'; // Phase 1: A/B disabled
        $creatives = $c['creatives'][$variant] ?? [];
        $img = $creatives[$sizeKey] ?? ($creatives['hero'] ?? null);
        if (!$img) {
            return '';
        }

        $link = $this->campaign_link($c);
        $cid = (int) ($c['id'] ?? 0);
        $item = (string) ($c['item_code'] ?? '');
        $headline = (string) ($c['headline_ar'] ?? '');

        $this->print_styles_once();

        return sprintf(
            '<a class="zb-camp zb-camp--%1$s" href="%2$s" data-zb-campaign="%3$d" data-zb-zone="%4$s" data-zb-variant="%5$s" data-zb-item="%6$s" aria-label="%7$s">'
            . '<img class="zb-camp__img" src="%8$s" alt="%7$s" loading="lazy"%9$s></a>',
            esc_attr($zone),
            esc_url($link),
            $cid,
            esc_attr('campaign:' . $cid . ':' . $zone),
            esc_attr($variant),
            esc_attr($item),
            esc_attr($headline),
            esc_url($img),
            $zone === 'hero' ? ' fetchpriority="high"' : ''
        );
    }

    private function campaign_link(array $c): string
    {
        $wooId = (int) ($c['woo_product_id'] ?? 0);
        if ($wooId > 0) {
            $url = get_permalink($wooId);
            if ($url) {
                return $url;
            }
        }
        return function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/');
    }

    private function print_styles_once(): void
    {
        static $done = false;
        if ($done) {
            return;
        }
        $done = true;
        echo '<style>'
            . '.zb-camp{display:block;margin:0 0 16px;border-radius:16px;overflow:hidden;line-height:0;box-shadow:0 8px 24px rgba(15,23,42,.10)}'
            . '.zb-camp__img{width:100%;height:auto;display:block;object-fit:cover}'
            . '.zb-camp--product_strip{margin-block:12px}'
            . '</style>';
    }

    /* ── Attribution beacon (impression + click) ──── */

    public function tracker_script(): void
    {
        if (is_admin()) {
            return;
        }
        $ajax = admin_url('admin-ajax.php');
        ?>
        <script>
        (function () {
            var ZB_AJAX = <?php echo wp_json_encode($ajax); ?>;
            function anon() {
                try {
                    var k = 'zb_anon', v = localStorage.getItem(k);
                    if (!v) { v = (Date.now().toString(36) + Math.random().toString(36).slice(2, 10)); localStorage.setItem(k, v); }
                    return v;
                } catch (e) { return ''; }
            }
            function track(type, el) {
                try {
                    var body = new FormData();
                    body.append('action', 'zooboxi_track');
                    body.append('event_type', type);
                    body.append('anon_id', anon());
                    body.append('zone', el.getAttribute('data-zb-zone') || '');
                    body.append('ab_variant', el.getAttribute('data-zb-variant') || 'A');
                    body.append('item_code', el.getAttribute('data-zb-item') || '');
                    body.append('payload', JSON.stringify({ campaign_id: parseInt(el.getAttribute('data-zb-campaign') || '0', 10) }));
                    if (type === 'impression' && navigator.sendBeacon) { navigator.sendBeacon(ZB_AJAX, body); }
                    else { fetch(ZB_AJAX, { method: 'POST', body: body, keepalive: true }); }
                } catch (e) {}
            }
            var seen = {};
            var banners = document.querySelectorAll('.zb-camp[data-zb-campaign]');
            if (!banners.length) return;
            if ('IntersectionObserver' in window) {
                var io = new IntersectionObserver(function (entries) {
                    entries.forEach(function (en) {
                        var el = en.target, id = el.getAttribute('data-zb-zone');
                        if (en.isIntersecting && en.intersectionRatio >= 0.5 && !seen[id]) {
                            seen[id] = 1; track('impression', el); io.unobserve(el);
                        }
                    });
                }, { threshold: [0.5] });
                banners.forEach(function (b) { io.observe(b); });
            }
            banners.forEach(function (b) {
                b.addEventListener('click', function () { track('click', b); });
            });
        })();
        </script>
        <?php
    }
}
