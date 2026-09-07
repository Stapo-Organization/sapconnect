<?php
/**
 * Keep a half-translated language out of the storefront.
 *
 * Polylang filters every product query by language, so a language with no
 * translated products gets a real storefront that sells nothing: `/en/shop-2/`
 * rendered an empty grid — no products, not even a "no results" line — while
 * Arabic held 4,339. The switcher on the homepage led straight to it and Yoast
 * published the whole branch to Google.
 *
 * Nothing is deleted here and no translation is lost. A language simply stops
 * being offered — dropped from the switcher, kept out of the sitemap, and
 * marked noindex — until it has stock behind it. Add it to
 * `zooboxi_public_languages` and the storefront returns exactly as it was.
 *
 * The mobile app is unaffected: it talks to `/wp-json/zooboxi/v2` with its own
 * `lang` parameter and never walks Polylang's URL prefixes.
 */

if (!defined('ABSPATH')) exit;

class Zooboxi_Language_Visibility
{
    private const OPTION    = 'zooboxi_public_languages';
    private const CACHE_KEY = 'zooboxi_hidden_language_posts';
    private const CACHE_TTL = 6 * HOUR_IN_SECONDS;

    public static function hooks(): void
    {
        if (!function_exists('pll_current_language')) {
            return;
        }

        // Polylang skips the `pll_the_languages` filter when a caller asks for
        // the raw array — which is exactly how the theme's switcher asks — so
        // the switcher is filtered where it is built, through `keep_public()`.
        add_filter('pll_rel_hreflang_attributes', [self::class, 'filter_hreflang']);
        add_filter('wpseo_robots_array', [self::class, 'noindex_hidden'], 20);
        add_filter('wpseo_exclude_from_sitemap_by_post_ids', [self::class, 'excluded_post_ids']);

        add_action('update_option_' . self::OPTION, [self::class, 'flush']);
    }

    public static function flush(): void
    {
        delete_transient(self::CACHE_KEY);
    }

    /** Language slugs the storefront is allowed to show. */
    public static function public_languages(): array
    {
        $langs = get_option(self::OPTION, ['ar']);

        return is_array($langs) && $langs ? array_map('strval', $langs) : ['ar'];
    }

    private static function is_public(string $slug): bool
    {
        return $slug === '' || in_array($slug, self::public_languages(), true);
    }

    /**
     * Drop hidden languages from a switcher list so nothing links into them.
     *
     * Takes Polylang's raw `pll_the_languages(['raw' => 1])` rows; the theme
     * calls this before rendering the header and drawer switchers.
     */
    public static function keep_public($items)
    {
        if (!is_array($items)) {
            return $items;
        }

        foreach ($items as $key => $item) {
            $slug = (string) ($item['slug'] ?? '');
            if (!self::is_public($slug)) {
                unset($items[$key]);
            }
        }

        return $items;
    }

    /**
     * Stop advertising a hidden language to search engines.
     *
     * An `hreflang` alternate is an invitation: it tells Google the page exists
     * in that language and asks it to be crawled. Hiding the switcher while
     * leaving the alternate in place would only make the empty storefront
     * harder for a person to reach than for a crawler.
     */
    public static function filter_hreflang($hreflangs)
    {
        if (!is_array($hreflangs)) {
            return $hreflangs;
        }

        foreach ($hreflangs as $locale => $url) {
            $slug = strtolower(substr((string) $locale, 0, 2));
            if (!self::is_public($slug)) {
                unset($hreflangs[$locale]);
            }
        }

        return $hreflangs;
    }

    /** A page in a hidden language is not a search destination. */
    public static function noindex_hidden(array $robots): array
    {
        if (is_admin()) {
            return $robots;
        }

        $current = (string) pll_current_language('slug');
        if ($current !== '' && !self::is_public($current)) {
            $robots['index'] = 'noindex';
        }

        return $robots;
    }

    public static function excluded_post_ids($ids)
    {
        $ids = is_array($ids) ? $ids : [];

        return array_values(array_unique(array_merge($ids, self::hidden_post_ids())));
    }

    /**
     * Every published post, page and product that lives in a hidden language.
     *
     * @return int[]
     */
    public static function hidden_post_ids(): array
    {
        $cached = get_transient(self::CACHE_KEY);
        if (is_array($cached)) {
            return $cached;
        }

        global $wpdb;

        $public = self::public_languages();
        $in     = implode("','", array_map('esc_sql', $public));

        $ids = $wpdb->get_col("
            SELECT p.ID
            FROM {$wpdb->posts} p
            JOIN {$wpdb->term_relationships} tr ON tr.object_id = p.ID
            JOIN {$wpdb->term_taxonomy} tt
                 ON tt.term_taxonomy_id = tr.term_taxonomy_id AND tt.taxonomy = 'language'
            JOIN {$wpdb->terms} t ON t.term_id = tt.term_id
            WHERE p.post_status = 'publish'
              AND t.slug NOT IN ('{$in}')
        ");

        $ids = array_map('intval', (array) $ids);
        set_transient(self::CACHE_KEY, $ids, self::CACHE_TTL);

        return $ids;
    }
}
