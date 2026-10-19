<?php
defined('ABSPATH') || exit;
do_action('woocommerce_cart_is_empty');
?>
<div class="zv-empty zv-empty--page">
    <?php echo zv_sleeper('cat-sleep.webp', 200); // phpcs:ignore ?>
    <strong><?php zv_e('سلتك فاضية', 'Your cart is empty'); ?></strong>
    <span><?php zv_e('أليفك ينتظر شيئاً لذيذاً — ابدأ من هنا', 'Your pet is waiting — start here'); ?></span>
    <div class="zv-empty__pets">
        <?php foreach (Zv_Catalog::menu() as $pet) : ?>
            <a class="zv-chipbtn" href="<?php echo esc_url($pet['url']); ?>"><?php echo esc_html($pet['name']); ?></a>
        <?php endforeach; ?>
    </div>
</div>
