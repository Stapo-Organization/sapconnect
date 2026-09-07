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

        $ids = Zooboxi_Bundles::ranked_ids($uid, $lat, $lng, 40);
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

    /** Bolt the bundle-specific keys onto a standard product card. */
    public static function extend(array $card): array
    {
        $id = (int) ($card['id'] ?? 0);

        $raw = get_post_meta($id, '_zb_bundle_components', true);
        $components = is_string($raw) && $raw !== '' ? json_decode($raw, true) : [];
        $components = is_array($components) ? $components : [];

        $gift = null;
        foreach ($components as $c) {
            if (($c['role'] ?? '') === 'gift') {
                $qty = max(1, (int) ($c['qty'] ?? 1));
                $name = (string) ($c['name'] ?? '');
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

        $card['bundle'] = [
            'free_label'  => (string) get_post_meta($id, '_zb_bundle_free_label', true),
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
}
