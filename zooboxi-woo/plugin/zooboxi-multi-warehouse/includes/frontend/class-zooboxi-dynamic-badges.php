<?php
/**
 * Zooboxi Dynamic Badges — data-driven, auto-refreshing product badges.
 *
 * Card (shop loop): ONE top-priority badge as an overlay on the image — the existing
 * delivery-speed badge is left untouched. Single product page: ALL applicable badges.
 *
 * Every badge is derived from live intelligence meta (refreshed hourly by the snapshot
 * sync) + per-branch stock (5-min stock sync) + the customer's detected express branch,
 * so it updates automatically with no manual curation. Channel-safe: no price badges.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Dynamic_Badges
{
    private const LOW_STOCK_THRESHOLD = 5; // "بقي X فقط في فرعك"
    private const NEW_ARRIVAL_DAYS = 45;

    /** Default "show on top X%" per ranked badge (admin-tunable via options). */
    private const PCT_DEFAULTS = ['hot' => 30, 'back' => 100, 'trend' => 25, 'new' => 10];

    /** Per-request memo of the percentile score cutoffs (also cached in a transient). */
    private static $cutoffs_cache = null;

    /**
     * Badge icons — curated, professional emoji keyed by badge.
     * Safe to use as native Unicode now that the plugin disables WordPress's
     * wp-emoji script site-wide (see Zooboxi_Plugin::disable_wp_emojis), so these
     * render through the device's own emoji font (Apple/Google) — no twemoji <img>.
     */
    private const ICONS = [
        'low'   => '⏳', // بقي X قطع فقط — ندرة/وقت ينفد
        'back'  => '🔄', // سريع النفاد — متوفّر الآن (عاد للمخزون)
        'hot'   => '🔥', // الأكثر طلباً
        'trend' => '📈', // رائج الآن
        'new'   => '✨', // وصل حديثاً
    ];

    public function __construct()
    {
        if (get_option('zooboxi_dynamic_badges', 'yes') !== 'yes') {
            return; // badges disabled from the settings page
        }
        // Card: one overlay badge above the image (kept separate from the delivery badge).
        add_action('woocommerce_before_shop_loop_item_title', [$this, 'render_card_badge'], 8);
        // Single product: full badge row under the title.
        add_action('woocommerce_single_product_summary', [$this, 'render_product_badges'], 6);
        add_action('wp_head', [$this, 'styles']);
    }

    /**
     * Ordered list of applicable badges for a product (+ this customer's context),
     * highest priority first. Each: ['key','icon','label','class'].
     */
    /** Admin-tunable low-stock threshold for the "بقي X قطع" badge. */
    private function threshold(): int
    {
        return max(1, (int) get_option('zooboxi_low_stock_threshold', self::LOW_STOCK_THRESHOLD));
    }

    public function compute_badges(int $product_id): array
    {
        $product = wc_get_product($product_id);
        if (!$product) {
            return [];
        }
        $badges = [];

        // 1) ⏳ Genuine scarcity — uses the SAME customer-filtered stock that caps the
        //    add-to-cart quantity, so the badge can NEVER contradict the cart limit.
        //    Variable parents are skipped here (stock is per-variation) and handled live
        //    via JS on the product page when an option is chosen.
        if (!$product->is_type('variable') && $product->managing_stock() && $product->get_backorders() === 'no') {
            $left = $product->get_stock_quantity(); // filtered to the customer's reachable stock
            if ($left !== null && $left > 0 && $left <= $this->threshold()) {
                $badges[] = [
                    'key' => 'low', 'icon' => self::ICONS['low'], 'class' => 'zb-b-urgent',
                    'label' => sprintf(_n('بقي قطعة واحدة فقط', 'بقي %d قطع فقط', $left, 'zooboxi'), $left),
                ];
            }
        }

        $health = (string) get_post_meta($product_id, '_zb_health', true);
        $isHero = (int) get_post_meta($product_id, '_zb_is_hero', true) === 1;
        $abc = (string) get_post_meta($product_id, '_zb_abc', true);
        $demand = (string) get_post_meta($product_id, '_zb_demand', true);

        // Percentile gating: each ranked badge shows only on the top-X% of its eligible
        // products (by intelligence score), so badges stay meaningful instead of blanketing
        // the catalogue. X is tunable per badge from the settings page. The scarcity badge
        // above is intentionally exempt — it's a factual stock count, not a ranking.
        $cut = $this->cutoffs();
        $score = $this->rank_score($product_id);

        // 2) ↩️ Proven seller that runs out a lot, available right now.
        if ($health === 'starved' && $this->within_top($score, $cut['back'])) {
            $badges[] = ['key' => 'back', 'icon' => self::ICONS['back'], 'class' => 'zb-b-back', 'label' => __('سريع النفاد — متوفّر الآن', 'zooboxi')];
        }

        // 3) 🔥 Bestseller.
        if (($isHero || $abc === 'A') && $this->within_top($score, $cut['hot'])) {
            $badges[] = ['key' => 'hot', 'icon' => self::ICONS['hot'], 'class' => 'zb-b-hot', 'label' => __('الأكثر طلباً', 'zooboxi')];
        }

        // 4) 📈 Trending (fast mover that isn't a top hero).
        if (!$isHero && $demand === 'fast' && $this->within_top($score, $cut['trend'])) {
            $badges[] = ['key' => 'trend', 'icon' => self::ICONS['trend'], 'class' => 'zb-b-trend', 'label' => __('رائج الآن', 'zooboxi')];
        }

        // 5) 🆕 New arrival.
        if ($this->is_new_arrival($product_id) && $this->within_top($score, $cut['new'])) {
            $badges[] = ['key' => 'new', 'icon' => self::ICONS['new'], 'class' => 'zb-b-new', 'label' => __('وصل حديثاً', 'zooboxi')];
        }

        return $badges;
    }

    public function render_card_badge(): void
    {
        global $product;
        if (!$product) {
            return;
        }
        $badges = $this->compute_badges($product->get_id());
        if (empty($badges)) {
            return;
        }
        $b = $badges[0]; // top priority only on the card
        printf(
            '<span class="zb-badge %s zb-badge-card"><span class="zb-badge-ic">%s</span>%s</span>',
            esc_attr($b['class']),
            esc_html($b['icon']),
            esc_html($b['label'])
        );
    }

    public function render_product_badges(): void
    {
        global $product;
        if (!$product) {
            return;
        }
        $badges = $this->compute_badges($product->get_id());
        $isVariable = $product->is_type('variable');

        // Keep an (even empty) row for variable products so the JS can inject the
        // per-variation scarcity badge once an option is selected.
        if (empty($badges) && !$isVariable) {
            return;
        }

        echo '<div class="zb-badges-row">';
        foreach ($badges as $b) {
            printf(
                '<span class="zb-badge %s"><span class="zb-badge-ic">%s</span>%s</span>',
                esc_attr($b['class']),
                esc_html($b['icon']),
                esc_html($b['label'])
            );
        }
        echo '</div>';

        if ($isVariable) {
            $this->variation_scarcity_script();
        }
    }

    /**
     * For variable products, show "بقي X قطع فقط" for the SELECTED variation, live.
     * Uses WooCommerce's own variation.max_qty (the customer-filtered purchasable max),
     * so it always matches the quantity the cart will allow — per option, dynamically.
     */
    private function variation_scarcity_script(): void
    {
        $threshold = $this->threshold();
        ?>
        <script>
        (function ($) {
            if (!$) { return; }
            var T = <?php echo $threshold; ?>;
            var IC = <?php echo wp_json_encode(self::ICONS['low']); ?>; // scarcity emoji
            $(document.body).on('found_variation', '.variations_form', function (e, variation) {
                $('.zb-var-badge').remove();
                var max = parseInt(variation.max_qty, 10);
                if (variation.is_in_stock && max > 0 && max <= T) {
                    var label = (max === 1) ? 'بقي قطعة واحدة فقط' : ('بقي ' + max + ' قطع فقط');
                    $('.zb-badges-row').prepend(
                        '<span class="zb-badge zb-b-urgent zb-var-badge"><span class="zb-badge-ic">' + IC + '</span>' + label + '</span>'
                    );
                }
            }).on('reset_data', '.variations_form', function () {
                $('.zb-var-badge').remove();
            });
        })(window.jQuery);
        </script>
        <?php
    }

    /* ── Signals ─────────────────────────────────── */

    private function is_new_arrival(int $product_id): bool
    {
        $created = get_post_time('U', true, $product_id);
        if (!$created) {
            return false;
        }
        $days = max(1, (int) get_option('zooboxi_new_days', self::NEW_ARRIVAL_DAYS));
        return (time() - (int) $created) <= $days * DAY_IN_SECONDS;
    }

    /* ── Percentile gating ───────────────────────── */

    private function rank_score(int $product_id): ?float
    {
        $v = get_post_meta($product_id, '_zb_rank_score', true);
        return ($v === '' || $v === null) ? null : (float) $v;
    }

    /** A product passes the gate if there's no cap, or its score clears the cutoff. */
    private function within_top(?float $score, ?float $cutoff): bool
    {
        if ($cutoff === null) {
            return true;            // 100% (or no eligible data) → no cap
        }
        if ($score === null) {
            return false;           // unscored product can't be in the top X%
        }
        return $score >= $cutoff;
    }

    /**
     * Score cutoffs per ranked badge — the rank_score value at the top-X% boundary
     * among each badge's eligible products. Memoised per request and cached for an
     * hour (the intelligence meta refreshes hourly; settings save clears it early).
     *
     * @return array{hot:?float,back:?float,trend:?float,new:?float}
     */
    private function cutoffs(): array
    {
        if (self::$cutoffs_cache !== null) {
            return self::$cutoffs_cache;
        }
        $cached = get_transient('zooboxi_badge_cutoffs');
        if (is_array($cached)) {
            return self::$cutoffs_cache = $cached;
        }

        global $wpdb;
        $pm = $wpdb->postmeta;
        $days  = max(1, (int) get_option('zooboxi_new_days', self::NEW_ARRIVAL_DAYS));
        $since = gmdate('Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS);

        // Eligibility predicates (mirror compute_badges). `p` is the posts row.
        $heroOrA = "(EXISTS(SELECT 1 FROM {$pm} m WHERE m.post_id=p.ID AND m.meta_key='_zb_is_hero' AND m.meta_value='1')"
                 . " OR EXISTS(SELECT 1 FROM {$pm} m WHERE m.post_id=p.ID AND m.meta_key='_zb_abc' AND m.meta_value='A'))";
        $starved = "EXISTS(SELECT 1 FROM {$pm} m WHERE m.post_id=p.ID AND m.meta_key='_zb_health' AND m.meta_value='starved')";
        $fastNotHero = "EXISTS(SELECT 1 FROM {$pm} m WHERE m.post_id=p.ID AND m.meta_key='_zb_demand' AND m.meta_value='fast')"
                 . " AND NOT EXISTS(SELECT 1 FROM {$pm} h WHERE h.post_id=p.ID AND h.meta_key='_zb_is_hero' AND h.meta_value='1')";
        $newWindow = $wpdb->prepare('p.post_date_gmt >= %s', $since);

        $out = [
            'hot'   => $this->score_cutoff($heroOrA,     $this->pct('hot')),
            'back'  => $this->score_cutoff($starved,     $this->pct('back')),
            'trend' => $this->score_cutoff($fastNotHero, $this->pct('trend')),
            'new'   => $this->score_cutoff($newWindow,   $this->pct('new')),
        ];

        set_transient('zooboxi_badge_cutoffs', $out, HOUR_IN_SECONDS);
        return self::$cutoffs_cache = $out;
    }

    /** Admin-tuned "top X%" for a badge, clamped to 1..100. */
    private function pct(string $badge): int
    {
        $v = (int) get_option('zooboxi_badge_pct_' . $badge, self::PCT_DEFAULTS[$badge] ?? 100);
        return min(100, max(1, $v));
    }

    /**
     * rank_score value at the top-$pct% boundary among published parent products
     * matching $whereEligible. Returns null when $pct is 100 (no cap) or no rows match.
     * $whereEligible is composed of hardcoded fragments / $wpdb->prepare()d clauses only.
     */
    private function score_cutoff(string $whereEligible, int $pct): ?float
    {
        if ($pct >= 100) {
            return null; // show on all eligible products
        }
        global $wpdb;
        $base = "FROM {$wpdb->posts} p"
              . " JOIN {$wpdb->postmeta} rs ON rs.post_id=p.ID AND rs.meta_key='_zb_rank_score'"
              . " WHERE p.post_type='product' AND p.post_status='publish' AND ({$whereEligible})";

        $total = (int) $wpdb->get_var("SELECT COUNT(*) {$base}");
        if ($total <= 0) {
            return null;
        }
        $n = max(1, (int) floor($total * $pct / 100));
        $val = $wpdb->get_var(
            "SELECT CAST(rs.meta_value AS DECIMAL(20,6)) AS s {$base} ORDER BY s DESC LIMIT 1 OFFSET " . ($n - 1)
        );
        return $val === null ? null : (float) $val;
    }

    /* ── Styles ──────────────────────────────────── */

    public function styles(): void
    {
        if (is_admin()) {
            return;
        }
        ?>
        <style id="zb-dynamic-badges">
        .zb-badge{display:inline-flex;align-items:center;gap:4px;font-size:10.5px;font-weight:700;
            line-height:1;padding:4px 8px;border-radius:999px;white-space:nowrap;letter-spacing:.1px;
            border:1px solid transparent;box-shadow:0 2px 6px rgba(15,23,42,.14)}
        .zb-badge .zb-badge-ic{display:inline-flex;align-items:center;flex-shrink:0;
            font-size:12.5px;line-height:1;
            font-family:"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif}
        .zb-badge-card{position:absolute;top:10px;inset-inline-start:10px;z-index:5}
        ul.products li.product{position:relative}
        .zb-badges-row{display:flex;flex-wrap:wrap;gap:8px;margin:6px 0 14px}
        /* Soft tinted pills + dark same-hue text. The light (near-white) background
           keeps the full-color emoji legible on any badge — no color clash. */
        .zb-b-urgent{background:#fdeaea;color:#b91c1c;border-color:rgba(185,28,28,.16)} /* بقي X — إلحاح */
        .zb-b-back{background:#e9f1fe;color:#1d4ed8;border-color:rgba(29,78,216,.16)}   /* عاد للتوفّر */
        .zb-b-hot{background:#fdefe3;color:#c2410c;border-color:rgba(194,65,12,.16)}    /* الأكثر طلباً */
        .zb-b-trend{background:#f6eafc;color:#7e22ce;border-color:rgba(126,34,206,.16)} /* رائج */
        .zb-b-new{background:#e8f6ee;color:#166534;border-color:rgba(22,101,52,.16)}    /* جديد */
        </style>
        <?php
    }
}
