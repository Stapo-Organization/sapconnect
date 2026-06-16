<?php
/**
 * Brand boutique archive template (loaded by Zooboxi_Brand_Page::maybe_take_over for
 * PUBLISHED brands only). Replicates WooCommerce's archive-product.php — so the
 * catalog keeps its native ordering, pagination, stock-sort and dynamic badges —
 * but injects the brand-themed boutique sections (hero, story, tiles, in-brand
 * categories, curated rail) above the grid. The whole page is themed via the CSS
 * variables printed by Zooboxi_Brand_Page::print_brand_vars().
 */

if (!defined('ABSPATH')) {
    exit;
}

get_header('shop');

/**
 * Astra/WooCommerce opens the content container here.
 *
 * @hooked woocommerce_output_content_wrapper - 10
 */
do_action('woocommerce_before_main_content');

// Themed boutique sections (brand identity carries the page; the default archive
// title is hidden via CSS on body.zb-has-brand-page).
echo Zooboxi_Brand_Page::render_sections(); // phpcs:ignore WordPress.Security.EscapeOutput

echo '<div class="zb-brand-catalog">';
echo '<h2 class="zb-brand-h2 zb-brand-catalog__title">' . esc_html__('كل منتجات العلامة', 'zooboxi') . '</h2>';

if (woocommerce_product_loop()) {

    /**
     * Result count + ordering toolbar (and any owner-enabled shop_top campaign).
     *
     * @hooked woocommerce_result_count - 20
     * @hooked woocommerce_catalog_ordering - 30
     */
    do_action('woocommerce_before_shop_loop');

    woocommerce_product_loop_start();

    if (wc_get_loop_prop('total')) {
        while (have_posts()) {
            the_post();

            /** @hooked WC_Structured_Data::generate_product_data() - 10 */
            do_action('woocommerce_shop_loop');

            wc_get_template_part('content', 'product');
        }
    }

    woocommerce_product_loop_end();

    /**
     * Pagination.
     *
     * @hooked woocommerce_pagination - 10
     */
    do_action('woocommerce_after_shop_loop');
} else {
    /** @hooked wc_no_products_found - 10 */
    do_action('woocommerce_no_products_found');
}

echo '</div>'; // .zb-brand-catalog

/**
 * Astra/WooCommerce closes the content container (+ sidebar).
 *
 * @hooked woocommerce_output_content_wrapper_end - 10
 */
do_action('woocommerce_after_main_content');

get_footer('shop');
