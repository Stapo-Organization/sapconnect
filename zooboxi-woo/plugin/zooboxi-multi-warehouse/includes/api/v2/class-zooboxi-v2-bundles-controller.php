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
                $gift = sprintf('%d × %s', max(1, (int) ($c['qty'] ?? 1)), (string) ($c['name'] ?? ''));
                break;
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
