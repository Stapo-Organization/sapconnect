<?php
/**
 * Pictures go out as WebP wherever the twin is ready (mu-plugin «zooboxi-webp»). The page's HTML
 * is rewritten on its way out — only src / srcset / data-src of uploads PNG/JPEG, never meta tags
 * or JSON-LD, so link previews and Google keep the original files.
 */

defined('ABSPATH') || exit;

add_action('template_redirect', static function () {
    if (!function_exists('zooboxi_webp_url') || is_admin() || is_feed() || is_robots() || wp_doing_ajax()) {
        return;
    }
    ob_start('zv_webp_rewrite');
}, 1);

function zv_webp_rewrite(string $html): string
{
    if ($html === '' || stripos($html, '/wp-content/uploads/') === false) {
        return $html;
    }
    $out = preg_replace_callback(
        '/\s(src|srcset|data-src|data-srcset)=(["\'])([^"\']*\/wp-content\/uploads\/[^"\']*)\2/i',
        static function (array $m): string {
            $val = preg_replace_callback(
                '#https?://[^\s,"\']+/wp-content/uploads/[^\s,"\']+?\.(?:png|jpe?g)(?:\?[^\s,"\']*)?(?=[\s,]|$)#i',
                static fn(array $u): string => zooboxi_webp_url($u[0]),
                $m[3]
            );
            return ' ' . $m[1] . '=' . $m[2] . ($val ?? $m[3]) . $m[2];
        },
        $html
    );
    return $out ?? $html;
}
