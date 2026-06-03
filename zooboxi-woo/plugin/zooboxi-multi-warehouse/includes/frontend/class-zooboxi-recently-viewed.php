<?php
/**
 * Recently Viewed Products Tracker
 * Stores last 12 viewed products in a cookie for quick display.
 */
class Zooboxi_Recently_Viewed
{
    private const COOKIE_NAME = 'zooboxi_recently_viewed';
    private const MAX_ITEMS   = 12;

    public function __construct()
    {
        add_action('woocommerce_before_single_product', [$this, 'track_view'], 5);
    }

    /**
     * Track product view on single product page.
     */
    public function track_view(): void
    {
        if (!is_product()) return;

        $productId = get_the_ID();
        if (!$productId) return;

        $ids = $this->get_ids();

        // Remove if already exists (move to front)
        $ids = array_diff($ids, [$productId]);

        // Add to front
        array_unshift($ids, $productId);

        // Keep only max items
        $ids = array_slice($ids, 0, self::MAX_ITEMS);

        // Save cookie (30 days)
        $this->set_ids($ids);
    }

    /**
     * Get recently viewed product IDs (excluding current product).
     */
    public static function get_ids(int $limit = 8): array
    {
        if (isset($_COOKIE[self::COOKIE_NAME])) {
            $decoded = json_decode(stripslashes($_COOKIE[self::COOKIE_NAME]), true);
            if (is_array($decoded)) {
                // Exclude current product
                $currentId = get_the_ID();
                $decoded = array_diff($decoded, [$currentId]);
                return array_slice(array_map('intval', $decoded), 0, $limit);
            }
        }
        return [];
    }

    /**
     * Render recently viewed products section.
     */
    public static function render(): void
    {
        $ids = self::get_ids(6);
        if (empty($ids)) return;

        $products = wc_get_products([
            'status' => 'publish',
            'include' => $ids,
            'limit' => 6,
        ]);

        if (empty($products)) return;

        // Sort by view order
        $orderMap = array_flip($ids);
        usort($products, function ($a, $b) use ($orderMap) {
            return ($orderMap[$a->get_id()] ?? 999) <=> ($orderMap[$b->get_id()] ?? 999);
        });

        echo '<section class="zooboxi-recently-viewed">';
        echo '<h2 class="zooboxi-section-title">' . esc_html__('شاهدتَ مؤخراً', 'zooboxi') . '</h2>';
        echo '<div class="zooboxi-product-grid">';

        foreach ($products as $product) {
            self::render_product_card($product);
        }

        echo '</div></section>';
    }

    private static function render_product_card(\WC_Product $product): void
    {
        $image = wp_get_attachment_image_url($product->get_image_id(), 'woocommerce_thumbnail');
        $price = $product->get_price_html();
        $link  = $product->get_permalink();
        $title = $product->get_name();

        echo '<div class="zooboxi-product-card">';
        echo '<a href="' . esc_url($link) . '" class="zooboxi-product-card__image">';
        if ($image) {
            echo '<img src="' . esc_url($image) . '" alt="' . esc_attr($title) . '" loading="lazy">';
        }
        echo '</a>';
        echo '<div class="zooboxi-product-card__info">';
        echo '<a href="' . esc_url($link) . '" class="zooboxi-product-card__title">' . esc_html($title) . '</a>';
        echo '<div class="zooboxi-product-card__price">' . wp_kses_post($price) . '</div>';
        echo '</div>';
        echo '</div>';
    }

    private function set_ids(array $ids): void
    {
        $value = wp_json_encode($ids);
        setcookie(self::COOKIE_NAME, $value, [
            'expires'  => time() + 30 * DAY_IN_SECONDS,
            'path'     => COOKIEPATH ?: '/',
            'secure'   => is_ssl(),
            'httponly' => false,
            'samesite' => 'Lax',
        ]);
        $_COOKIE[self::COOKIE_NAME] = $value;
    }
}
