<?php
defined('ABSPATH') || exit;
get_header();
$zv_wc_page = function_exists('is_cart') && (is_cart() || is_checkout() || is_account_page());
while (have_posts()) :
    the_post(); ?>
    <div class="zv-wrap <?php echo $zv_wc_page ? 'zv-wcpage' : 'zv-page'; ?>">
        <?php if (!(function_exists('is_checkout') && is_checkout() && !empty(get_query_var('order-received')))) : ?>
            <h1 class="zv-page__title"><?php the_title(); ?></h1>
        <?php endif; ?>
        <div class="<?php echo $zv_wc_page ? 'zv-wc' : 'zv-prose zv-page__body'; ?>"><?php the_content(); ?></div>
    </div>
<?php endwhile;
get_footer();
