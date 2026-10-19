<?php

/**
 * Zooboxi_V2_Brands_Controller — the per-customer side of the brands
 * («تفعيل البراندات» A + C). The brand pages themselves stay in the catalogue
 * controller, cacheable; everything here knows who is asking and is never
 * cached:
 *
 *   GET  /account/brands          followed brand slugs (+ their summaries)
 *   POST /account/brands/toggle   {slug, follow?} → follow / unfollow
 *   GET  /account/brands/new      new products from the followed brands
 *   GET  /cart/brand              the cart's substitutes, bigger packs and
 *                                 «أكمل من …» rail (Zooboxi_Brand_Activation::cart)
 *
 * The cart answer is its own call, not part of the cart DTO: the DTO answers
 * every tap on a stepper and checkout reads it too, while these lookups only
 * matter when the cart screen is looking.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Brands_Controller
{
    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/account/brands', 'GET', [$this, 'followed']);
        Zooboxi_V2_Bootstrap::route('/account/brands/toggle', 'POST', [$this, 'toggle']);
        Zooboxi_V2_Bootstrap::route('/account/brands/new', 'GET', [$this, 'fresh']);
        Zooboxi_V2_Bootstrap::route('/cart/brand', 'GET', [$this, 'cart']);
    }

    public function followed(\WP_REST_Request $request): \WP_REST_Response
    {
        $uid = get_current_user_id();
        if (!$uid) {
            return Zooboxi_V2_Bootstrap::ok(['following' => [], 'brands' => []], null);
        }
        $lang = Zooboxi_V2_Bootstrap::lang($request);
        $slugs = Zooboxi_Brand_Activation::followed($uid);
        $brands = [];
        foreach ($slugs as $slug) {
            $t = get_term_by('slug', $slug, 'product_brand');
            if ($t instanceof \WP_Term) {
                $brands[] = Zooboxi_Brand_Activation::summary($t, $lang);
            }
        }
        return Zooboxi_V2_Bootstrap::ok(['following' => $slugs, 'brands' => $brands], null);
    }

    public function toggle(\WP_REST_Request $request): \WP_REST_Response
    {
        $uid = get_current_user_id();
        if (!$uid) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        $slug = sanitize_title((string) $request->get_param('slug'));
        $term = $slug !== '' ? get_term_by('slug', $slug, 'product_brand') : null;
        if (!$term instanceof \WP_Term) {
            return Zooboxi_V2_Bootstrap::fail('brand_not_found', __('براند غير معروف', 'zooboxi'), 'Unknown brand.', 404);
        }
        $force = $request->get_param('follow');
        $on = Zooboxi_Brand_Activation::toggle($uid, (string) $term->slug, $force === null ? null : filter_var($force, FILTER_VALIDATE_BOOLEAN));
        return Zooboxi_V2_Bootstrap::ok([
            'slug'      => (string) $term->slug,
            'following' => $on,
            'slugs'     => Zooboxi_Brand_Activation::followed($uid),
        ], null);
    }

    public function fresh(\WP_REST_Request $request): \WP_REST_Response
    {
        $uid = get_current_user_id();
        if (!$uid) {
            return Zooboxi_V2_Bootstrap::ok(['products' => []], null);
        }
        $ids = Zooboxi_Brand_Activation::fresh_ids($uid, 10);
        return Zooboxi_V2_Bootstrap::ok(['products' => Zooboxi_Product_DTO::cards($ids)], null);
    }

    public function cart(\WP_REST_Request $request): \WP_REST_Response
    {
        $empty = ['lines' => (object) [], 'complete' => null];
        if (!class_exists('Zooboxi_V2_Cart_Controller') || !Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::ok($empty, null);
        }
        try {
            WC()->cart->calculate_totals();
            $shelf = class_exists('Zooboxi_Cart_Shelf') ? Zooboxi_Cart_Shelf::current() : '';
            $codes = ($shelf !== '' && class_exists('Zooboxi_Cart_Shelf')) ? Zooboxi_Cart_Shelf::codes_for($shelf) : [];
            $out = Zooboxi_Brand_Activation::cart(
                WC()->cart->get_cart(),
                $shelf,
                $codes,
                Zooboxi_V2_Bootstrap::lang($request)
            );
        } catch (\Throwable $e) {
            error_log('[Zooboxi v2] cart brand failed: ' . $e->getMessage());
            $out = $empty;
        }
        return Zooboxi_V2_Bootstrap::ok($out, null);
    }
}

add_action('rest_api_init', static function () {
    if (class_exists('Zooboxi_V2_Bootstrap') && class_exists('Zooboxi_Brand_Activation')) {
        (new Zooboxi_V2_Brands_Controller())->register_routes();
    }
}, 20);
