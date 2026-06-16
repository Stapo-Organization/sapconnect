<?php

/**
 * Zooboxi_Brand_Sync — pulls the owner-published brand boutique pages from
 * sapconnect (GET /api/woo/brands) and caches them keyed by SAP brand code. Mirrors
 * Zooboxi_Campaigns: hourly cron + manual "sync now", keep-previous on failure.
 *
 * The cached set is the gate for Zooboxi_Brand_Page: a brand only gets its themed
 * /brand/<slug>/ page once it appears here (i.e. the owner published its banner).
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Brand_Sync
{
    private string $api_base;
    private string $api_token;

    private const CACHE_KEY = 'zooboxi_brands_cache';
    private const SYNCED_OPT = 'zooboxi_brands_synced_at';

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = get_option('zooboxi_api_token', '');

        add_action('zooboxi_sync_brands', [$this, 'sync_brands']);
        if (!wp_next_scheduled('zooboxi_sync_brands')) {
            wp_schedule_event(time() + 300, 'hourly', 'zooboxi_sync_brands');
        }

        // Manual "sync now" (admin) — also handy right after publishing a brand.
        add_action('wp_ajax_zooboxi_sync_brands', [$this, 'ajax_sync']);
    }

    /** Pull the published brands and cache them keyed by code. */
    public function sync_brands(): array
    {
        $res = wp_remote_get($this->api_base . '/brands', [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Accept' => 'application/json'],
            'timeout' => 30,
        ]);
        if (is_wp_error($res)) {
            return []; // keep the previous transient on network failure
        }

        $body = json_decode(wp_remote_retrieve_body($res), true);
        $data = is_array($body) && isset($body['data']) && is_array($body['data']) ? $body['data'] : [];

        $by_code = [];
        foreach ($data as $b) {
            if (!empty($b['code'])) {
                $by_code[(string) $b['code']] = $b;
            }
        }

        // A SUCCESSFUL pull replaces the cache (so unpublished brands drop out).
        set_transient(self::CACHE_KEY, $by_code, 30 * MINUTE_IN_SECONDS);
        update_option(self::SYNCED_OPT, current_time('mysql'), false);
        return $by_code;
    }

    public function ajax_sync(): void
    {
        if (!current_user_can('manage_woocommerce')) {
            wp_die('', '', ['response' => 403]);
        }
        $data = $this->sync_brands();
        wp_send_json(['count' => count($data), 'synced_at' => get_option(self::SYNCED_OPT)]);
    }

    /** All published brands keyed by code (cached; warms on cold miss). */
    public static function all(): array
    {
        $cached = get_transient(self::CACHE_KEY);
        if ($cached === false) {
            $cached = (new self())->sync_brands();
        }
        return is_array($cached) ? $cached : [];
    }

    /** One published brand payload by SAP code, or null if not published. */
    public static function get(string $code): ?array
    {
        $all = self::all();
        return $all[$code] ?? null;
    }
}
