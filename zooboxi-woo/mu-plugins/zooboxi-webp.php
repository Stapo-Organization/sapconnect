<?php
/**
 * Plugin Name: Zooboxi — WebP twins for storefront images
 * Description: Keeps a WebP copy beside each uploaded PNG/JPEG the storefront shows (<file>.png.webp), made with GD. The storefront swaps an image to its twin only when the twin exists and is not older than the original; images without one are queued and converted by WP-Cron in small batches. Originals are never touched, so the app, feeds and emails keep their URLs.
 */

defined('ABSPATH') || exit;

const ZOOBOXI_WEBP_QUEUE = 'zooboxi_webp_queue';
const ZOOBOXI_WEBP_HOOK  = 'zooboxi_webp_convert_queue';

/** Uploads base URL and dir, once per request. */
function zooboxi_webp_uploads(): array
{
    static $u = null;
    if ($u === null) {
        $d = wp_get_upload_dir();
        $u = [set_url_scheme((string) $d['baseurl'], 'https'), (string) $d['basedir']];
    }
    return $u;
}

/** Twins waiting to be made in this request (saved on shutdown). */
function zooboxi_webp_pending(?string $path = null): array
{
    static $pending = [];
    if ($path !== null) {
        $pending[$path] = true;
    }
    return $pending;
}

/**
 * The WebP twin of an uploads image URL when it is ready; otherwise the URL unchanged
 * (and the image is queued). Query strings such as bundle «?v=» cache-busters are kept.
 */
function zooboxi_webp_url(string $url): string
{
    [$base, $dir] = zooboxi_webp_uploads();
    $parts = explode('?', $url, 2);
    $clean = set_url_scheme($parts[0], 'https');
    if (strpos($clean, $base . '/') !== 0 || !preg_match('/\.(png|jpe?g)$/i', $clean)) {
        return $url;
    }
    $rel  = rawurldecode(substr($clean, strlen($base)));
    if (strpos($rel, '..') !== false) {
        return $url;
    }
    $path = $dir . $rel;
    $twin = $path . '.webp';
    $src_m = @filemtime($path);
    if ($src_m === false) {
        return $url;
    }
    $twin_m = @filemtime($twin);
    if ($twin_m !== false && $twin_m >= $src_m) {
        return $parts[0] . '.webp' . (isset($parts[1]) ? '?' . $parts[1] : '');
    }
    zooboxi_webp_pending($path);
    return $url;
}

/** Make one twin with GD. Keeps transparency; writes atomically. */
function zooboxi_webp_convert(string $path, int $quality = 80): bool
{
    if (!function_exists('imagewebp') || !is_file($path)) {
        return false;
    }
    $info = @getimagesize($path);
    if (!$info || $info[0] * $info[1] > 25000000) {
        return false;
    }
    $img = $info[2] === IMAGETYPE_PNG ? @imagecreatefrompng($path) : ($info[2] === IMAGETYPE_JPEG ? @imagecreatefromjpeg($path) : false);
    if (!$img) {
        return false;
    }
    if (!imageistruecolor($img)) {
        imagepalettetotruecolor($img);
    }
    imagealphablending($img, false);
    imagesavealpha($img, true);
    $tmp = $path . '.webp.tmp' . getmypid();
    $ok = @imagewebp($img, $tmp, $quality);
    if (!$ok || !is_file($tmp) || filesize($tmp) === 0) {
        @unlink($tmp);
        return false;
    }
    // A twin that comes out bigger than its original is no saving: keep a marker-sized twin out.
    if (filesize($tmp) >= filesize($path)) {
        @unlink($tmp);
        @touch($path . '.webp.skip');
        return false;
    }
    return @rename($tmp, $path . '.webp');
}

// Queue what this request could not serve as WebP; a cron batch converts it shortly.
add_action('shutdown', static function () {
    $new = array_keys(zooboxi_webp_pending());
    if (!$new) {
        return;
    }
    $new = array_values(array_filter($new, static fn($p) => !is_file($p . '.webp.skip')));
    if (!$new) {
        return;
    }
    $queue = (array) get_option(ZOOBOXI_WEBP_QUEUE, []);
    $merged = array_values(array_unique(array_merge($queue, $new)));
    if (count($merged) !== count($queue)) {
        update_option(ZOOBOXI_WEBP_QUEUE, array_slice($merged, -5000), false);
        if (!wp_next_scheduled(ZOOBOXI_WEBP_HOOK)) {
            wp_schedule_single_event(time() + 60, ZOOBOXI_WEBP_HOOK);
        }
    }
});

add_action(ZOOBOXI_WEBP_HOOK, static function () {
    $queue = (array) get_option(ZOOBOXI_WEBP_QUEUE, []);
    if (!$queue) {
        return;
    }
    $batch = array_slice($queue, 0, 150);
    $start = microtime(true);
    $done = 0;
    foreach ($batch as $path) {
        if (microtime(true) - $start > 40) {
            break;
        }
        zooboxi_webp_convert((string) $path);
        $done++;
    }
    $rest = array_slice($queue, $done);
    update_option(ZOOBOXI_WEBP_QUEUE, $rest, false);
    if ($rest) {
        wp_schedule_single_event(time() + 60, ZOOBOXI_WEBP_HOOK);
    }
});
