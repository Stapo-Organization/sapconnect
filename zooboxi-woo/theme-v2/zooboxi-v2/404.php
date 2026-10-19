<?php
defined('ABSPATH') || exit;
status_header(404);
get_header(); ?>
<div class="zv-wrap zv-page">
    <div class="zv-empty zv-empty--page">
        <img src="<?php echo esc_url(zv_img('dog-peek.webp')); ?>" alt="" width="240" height="160">
        <strong><?php zv_e('الصفحة اللي تدورها راحت تلعب', 'This page wandered off'); ?></strong>
        <span><?php zv_e('جرّب البحث، أو ابدأ من أحد الأقسام:', 'Try a search, or start from a department:'); ?></span>
        <div class="zv-empty__pets">
            <?php foreach (Zv_Catalog::menu() as $pet) : ?><a class="zv-chipbtn" href="<?php echo esc_url($pet['url']); ?>"><?php echo esc_html($pet['name']); ?></a><?php endforeach; ?>
        </div>
        <a class="zv-btn zv-btn--primary" href="<?php echo esc_url(home_url('/')); ?>"><?php zv_e('الرئيسية', 'Home'); ?></a>
    </div>
</div>
<?php get_footer();
