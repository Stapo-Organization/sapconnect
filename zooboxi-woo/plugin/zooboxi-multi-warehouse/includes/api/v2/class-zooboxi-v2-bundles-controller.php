<?php
/**
 * zooboxi/v2 — «البكجات» for the customer app.
 *
 * GET /bundles — live bundles as product cards, ranked for THIS viewer
 * (their pets' species, their food gauge, their reachable delivery tier),
 * each card extended with the bundle keys the app renders: the free-units
 * label, the component count, and the gift line if there is one.
 */
class Zooboxi_V2_Bundles_Controller
{
    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/bundles', 'GET', [$this, 'index']);
    }

    public function index(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!class_exists('Zooboxi_Bundles')) {
            return Zooboxi_V2_Bootstrap::ok(['bundles' => []], null);
        }

        $uid = get_current_user_id();
        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        $lat = (float) ($request->get_param('lat') ?: $lat);
        $lng = (float) ($request->get_param('lng') ?: $lng);

        $ids = Zooboxi_Bundles::ranked_ids($uid, $lat, $lng, 40, self::shelf());
        $cards = [];
        foreach (Zooboxi_Product_DTO::cards($ids) as $card) {
            $cards[] = self::extend($card);
        }

        // Per-viewer ordering → never cacheable.
        return Zooboxi_V2_Bootstrap::ok(['bundles' => $cards], null);
    }

    /**
     * Stamp an artwork URL with the version of the file behind it.
     *
     * A re-rendered bundle card is sideloaded over a freed filename, so the
     * new picture arrives at the URL the OLD one had — and every client that
     * caches by URL keeps showing the old one. The attachment's own modified
     * stamp makes a changed picture a changed URL, which is the only thing a
     * cache anywhere down the line will believe.
     */
    private static function versioned(string $url, int $attachmentId): string
    {
        if ($attachmentId <= 0) {
            return $url;
        }
        $stamp = (int) get_post_modified_time('U', true, $attachmentId);
        if ($stamp <= 0) {
            return $url;
        }

        return $url . (str_contains($url, '?') ? '&' : '?') . 'v=' . $stamp;
    }

    /**
     * A bundle's name in English, composed from its parts.
     *
     * The generator writes name_ar only (three patterns, see sapconnect's
     * BundleGenerator), so English is rebuilt from the same ingredients: the
     * template, the free label and the components' own English names. Null
     * when a part has no English — the caller then keeps the Arabic title.
     */
    public static function english_name(int $id): ?string
    {
        $raw = get_post_meta($id, '_zb_bundle_components', true);
        $components = is_string($raw) && $raw !== '' ? json_decode($raw, true) : [];
        if (!is_array($components) || $components === []) {
            return null;
        }
        $template = (string) get_post_meta($id, '_zb_bundle_template', true);
        $label    = (string) get_post_meta($id, '_zb_bundle_free_label', true);
        $anchor   = null;
        $gift     = null;
        foreach ($components as $c) {
            $role = (string) ($c['role'] ?? 'member');
            if ($role === 'anchor' && $anchor === null) {
                $anchor = $c;
            } elseif ($role === 'gift' && $gift === null) {
                $gift = $c;
            }
        }
        $anchor = $anchor ?? $components[0];
        $anchor_en = self::component_name($anchor, false);
        if ($anchor_en === null) {
            return null;
        }

        $deal = preg_match('/^(\d+)\+(\d+)$/', $label, $m) ? sprintf('%d + %d free', (int) $m[1], (int) $m[2]) : '';
        switch ($template) {
            case 'stacking':
                return $deal !== '' ? $deal . ' · ' . $anchor_en : $anchor_en;

            case 'variety':
                $anchor_pid = (int) ($anchor['product_id'] ?? 0);
                $brand   = Zooboxi_Product_DTO::brand((int) wp_get_post_parent_id($anchor_pid) ?: $anchor_pid);
                $species = match ((string) get_post_meta($id, '_zb_bundle_species', true)) {
                    'cat' => 'for cats', 'dog' => 'for dogs', 'bird' => 'for birds', 'small_pet' => 'for small pets', default => '',
                };
                $mix = trim(($brand['name'] ?? '') . ' mix ' . $species);
                return $deal !== '' ? $deal . ' · ' . $mix : $mix;

            default:
                if ($gift === null) {
                    return $anchor_en;
                }
                $gift_en = self::component_name($gift, false);
                if ($gift_en === null) {
                    return null;
                }
                $qty   = max(1, (int) ($gift['qty'] ?? 1));
                $words = preg_split('/\s+/', $gift_en) ?: [];
                $short = count($words) > 6 ? implode(' ', array_slice($words, 0, 6)) : $gift_en;
                return sprintf('%s + %s%s gift', $anchor_en, $qty > 1 ? $qty . ' × ' : '', $short);
        }
    }

    /**
     * One component's name in English — its product's `_zooboxi_name_en`.
     * With $fallback the Arabic component name is returned instead of null.
     */
    private static function component_name(array $c, bool $fallback = true): ?string
    {
        $pid = (int) ($c['product_id'] ?? 0);
        // A component may point at a pack variation; the name lives on its parent.
        $parent = $pid ? (int) wp_get_post_parent_id($pid) : 0;
        $en  = $pid ? trim((string) get_post_meta($parent ?: $pid, '_zooboxi_name_en', true)) : '';
        if ($en !== '') {
            return $en;
        }
        if (!$fallback) {
            return null;
        }
        Zooboxi_V2_Bootstrap::note_fallback();
        return (string) ($c['name'] ?? '');
    }

    /** Bolt the bundle-specific keys onto a standard product card. */
    public static function extend(array $card): array
    {
        $id = (int) ($card['id'] ?? 0);

        $raw = get_post_meta($id, '_zb_bundle_components', true);
        $components = is_string($raw) && $raw !== '' ? json_decode($raw, true) : [];
        $components = is_array($components) ? $components : [];

        $en   = Zooboxi_V2_Bootstrap::lang() === 'en';
        $gift = null;
        foreach ($components as $c) {
            if (($c['role'] ?? '') === 'gift') {
                $qty = max(1, (int) ($c['qty'] ?? 1));
                $name = $en ? self::component_name($c) : (string) ($c['name'] ?? '');
                $gift = $qty > 1 ? "{$qty} × {$name}" : $name;
                break;
            }
        }

        // The composed artwork IS the pitch, and the card shows it big — the
        // 600px `woocommerce_single` rendition goes soft on a 3× screen, so a
        // bundle card gets the full-size original, stamped with the version
        // the file is actually on.
        $product = wc_get_product($id);
        if ($product instanceof \WC_Product) {
            $full = Zooboxi_Product_DTO::image_url($product, 'full');
            if ($full) {
                $card['image'] = self::versioned($full, (int) $product->get_image_id());
            }
        }

        $free_label = (string) get_post_meta($id, '_zb_bundle_free_label', true);
        if ($en && $free_label === 'هدية') {
            $free_label = 'Gift';
        }

        $card['bundle'] = [
            'free_label'  => $free_label,
            'template'    => (string) get_post_meta($id, '_zb_bundle_template', true),
            'species'     => (string) get_post_meta($id, '_zb_bundle_species', true),
            'stock_class' => (string) get_post_meta($id, '_zb_bundle_class', true),
            'items_count' => count($components),
            'pieces'      => array_sum(array_map(
                static fn($c) => max(1, (int) ($c['qty'] ?? 1)),
                $components
            )),
            'gift_line'   => $gift,
        ];

        return $card;
    }

    /**
     * The storefront this request is browsing, as the cart rule spells it:
     * 'express' | 'all', and '' for anything unscoped (no location, an app
     * build from before the tabs, the kill-switch off) — where nothing is
     * filtered, because a rule that cannot be evaluated must not hide stock.
     */
    private static function shelf(): string
    {
        if (!class_exists('Zooboxi_Cart_Shelf') || !class_exists('Zooboxi_V2_Scope')
            || !Zooboxi_V2_Scope::is_enabled()) {
            return '';
        }
        // The TAB, as the add-to-cart guard reads it — the same call, so the
        // rail can never offer what the basket is about to refuse.
        return Zooboxi_Cart_Shelf::requested();
    }

}
