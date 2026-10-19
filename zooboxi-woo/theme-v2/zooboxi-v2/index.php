<?php
defined('ABSPATH') || exit;
get_header(); ?>
<div class="zv-wrap zv-page">
    <?php if (have_posts()) : ?>
        <h1 class="zv-page__title"><?php echo is_search() ? esc_html(sprintf(zv_t('نتائج البحث عن «%s»', 'Results for “%s”'), get_search_query(false))) : esc_html(get_the_archive_title() ?: get_bloginfo('name')); ?></h1>
        <div class="zv-posts">
            <?php while (have_posts()) : the_post(); ?>
                <article class="zv-post"><h2><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2><p><?php echo esc_html(wp_trim_words(get_the_excerpt(), 30)); ?></p></article>
            <?php endwhile; ?>
        </div>
        <?php the_posts_pagination(); ?>
    <?php else : ?>
        <div class="zv-empty zv-empty--page"><?php echo zv_sleeper('dog-sleep.webp'); // phpcs:ignore ?><strong><?php zv_e('ما لقينا شيء هنا', 'Nothing here'); ?></strong></div>
    <?php endif; ?>
</div>
<?php get_footer();
