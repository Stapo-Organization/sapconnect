<?php
/**
 * «نبّهني» — back in stock, and a price that dropped.
 *
 * The two highest-converting automated messages in retail are the two the
 * customer asked for by name. A row here is that request: this person,
 * this product, restock or price, and where they were standing when they
 * asked — because "back in stock" only counts if a branch that actually
 * serves them has it. Wishlisting a product asks for both on their behalf.
 *
 * Restock is checked after every stock sync, price after every price sync;
 * both are service-tier pushes, one per product per thirty days, and the
 * restock one expires after a day because the shelf may be empty again.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Waitlist
{
    const KIND_RESTOCK = 'restock';
    const KIND_PRICE   = 'price';
    const COOLDOWN     = 30 * DAY_IN_SECONDS;
    const DROP_RATIO   = 0.90;

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_waitlist';
    }

    public static function install(string $collate): string
    {
        return 'CREATE TABLE ' . self::table() . " (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            product_id BIGINT UNSIGNED NOT NULL,
            kind VARCHAR(8) NOT NULL DEFAULT 'restock',
            ref_price DECIMAL(10,2) NOT NULL DEFAULT 0,
            lat DECIMAL(9,6) NOT NULL DEFAULT 0,
            lng DECIMAL(9,6) NOT NULL DEFAULT 0,
            source VARCHAR(12) NOT NULL DEFAULT 'button',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            notified_at DATETIME NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY person_product (user_id, guest_id, product_id, kind),
            KEY kind_product (kind, product_id)
        ) {$collate};";
    }

    public static function boot(): void
    {
        add_action('zooboxi_sync_stock', [self::class, 'check_restock'], 40);
        add_action('zooboxi_sync_prices', [self::class, 'check_prices'], 40);
    }

    /* ══════════════════════════════════════════════════════════════
       SUBSCRIBE
       ══════════════════════════════════════════════════════════════ */

    public static function subscribe(int $user_id, string $guest_id, int $product_id, string $kind, float $lat = 0.0, float $lng = 0.0, string $source = 'button'): bool
    {
        if (($user_id <= 0 && $guest_id === '') || $product_id <= 0 || !in_array($kind, [self::KIND_RESTOCK, self::KIND_PRICE], true)) {
            return false;
        }
        $product = wc_get_product($product_id);
        if (!$product) {
            return false;
        }
        global $wpdb;
        $ref = (float) wc_get_price_to_display($product);
        $wpdb->query($wpdb->prepare(
            'INSERT INTO ' . self::table() . ' (user_id, guest_id, product_id, kind, ref_price, lat, lng, source, created_at)'
            . ' VALUES (%d, %s, %d, %s, %f, %f, %f, %s, %s)'
            . ' ON DUPLICATE KEY UPDATE ref_price = IF(kind = %s, LEAST(ref_price, VALUES(ref_price)), ref_price), lat = VALUES(lat), lng = VALUES(lng), notified_at = NULL',
            $user_id, $user_id > 0 ? '' : substr($guest_id, 0, 64), $product_id, $kind, $ref, $lat, $lng, substr($source, 0, 12), gmdate('Y-m-d H:i:s'),
            self::KIND_PRICE
        ));
        return true;
    }

    public static function unsubscribe(int $user_id, string $guest_id, int $product_id, string $kind = ''): int
    {
        global $wpdb;
        $where = ['product_id' => $product_id, 'user_id' => $user_id, 'guest_id' => $user_id > 0 ? '' : $guest_id];
        if ($kind !== '') {
            $where['kind'] = $kind;
        }
        return (int) $wpdb->delete(self::table(), $where);
    }

    /** @return array{restock:bool,price:bool} */
    public static function status(int $user_id, string $guest_id, int $product_id): array
    {
        global $wpdb;
        $kinds = $wpdb->get_col($wpdb->prepare(
            'SELECT kind FROM ' . self::table() . ' WHERE product_id = %d AND user_id = %d AND guest_id = %s',
            $product_id, $user_id, $user_id > 0 ? '' : $guest_id
        )) ?: [];
        return ['restock' => in_array(self::KIND_RESTOCK, $kinds, true), 'price' => in_array(self::KIND_PRICE, $kinds, true)];
    }

    /** The wishlist heart asks on the customer's behalf. */
    public static function on_wishlisted(int $user_id, int $product_id, bool $added): void
    {
        try {
            if ($user_id <= 0) {
                return;
            }
            if (!$added) {
                self::unsubscribe($user_id, '', $product_id);
                return;
            }
            [$lat, $lng] = class_exists('Zooboxi_V2_Bootstrap') ? Zooboxi_V2_Bootstrap::latlng() : [0.0, 0.0];
            self::subscribe($user_id, '', $product_id, self::KIND_PRICE, $lat, $lng, 'wishlist');
            $product = wc_get_product($product_id);
            if ($product && !$product->is_in_stock()) {
                self::subscribe($user_id, '', $product_id, self::KIND_RESTOCK, $lat, $lng, 'wishlist');
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] wishlist waitlist failed: ' . $e->getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       CHECKS — after each sync
       ══════════════════════════════════════════════════════════════ */

    public static function check_restock(): int
    {
        if (!class_exists('Zooboxi_Push_Engine') || get_option('zooboxi_push_waitlist', 'yes') !== 'yes') {
            return 0;
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE kind = %s AND (notified_at IS NULL OR notified_at <= %s) ORDER BY id ASC LIMIT 400',
            self::KIND_RESTOCK, gmdate('Y-m-d H:i:s', time() - self::COOLDOWN)
        ), ARRAY_A) ?: [];
        $sent = 0;
        $cache = [];
        foreach ($rows as $r) {
            try {
                $pid = (int) $r['product_id'];
                $product = $cache[$pid] ??= wc_get_product($pid);
                if (!$product || !$product->is_in_stock()) {
                    continue;
                }
                $lat = (float) $r['lat'];
                $lng = (float) $r['lng'];
                if (($lat != 0.0 || $lng != 0.0) && class_exists('Zooboxi_Fulfillment')) {
                    $res = Zooboxi_Fulfillment::resolve($pid, 1, $lat, $lng);
                    if ((int) ($res['reachable_total'] ?? 0) <= 0) {
                        continue;
                    }
                }
                $name = wp_strip_all_tags($product->get_name());
                $r2 = Zooboxi_Push_Engine::submit([
                    'user_id'      => (int) $r['user_id'],
                    'guest_id'     => (string) $r['guest_id'],
                    'topic'        => 'offers',
                    'tier'         => Zooboxi_Push_Gate::TIER_SERVICE,
                    'copy'         => [
                        'ar' => ['رجع ' . $name, 'متوفر الآن لفرعك — الكمية محدودة.'],
                        'en' => [$name . ' is back', 'In stock again for your branch — limited quantity.'],
                    ],
                    'route'        => '/product/' . $pid,
                    'data'         => ['product_id' => (string) $pid],
                    'collapse_key' => 'restock-' . $pid,
                    'thread_id'    => 'waitlist',
                    'relevance'    => 0.9,
                    'source'       => 'restock',
                    'source_id'    => (string) $pid,
                    'expires_at'   => time() + DAY_IN_SECONDS,
                    'sto'          => false,
                ]);
                if ($r2['id'] > 0) {
                    $wpdb->update(self::table(), ['notified_at' => gmdate('Y-m-d H:i:s')], ['id' => (int) $r['id']]);
                    $sent++;
                }
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] restock check failed: ' . $e->getMessage());
            }
        }
        return $sent;
    }

    public static function check_prices(): int
    {
        if (!class_exists('Zooboxi_Push_Engine') || get_option('zooboxi_push_waitlist', 'yes') !== 'yes') {
            return 0;
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE kind = %s AND (notified_at IS NULL OR notified_at <= %s) ORDER BY id ASC LIMIT 400',
            self::KIND_PRICE, gmdate('Y-m-d H:i:s', time() - self::COOLDOWN)
        ), ARRAY_A) ?: [];
        $sent = 0;
        $cache = [];
        foreach ($rows as $r) {
            try {
                $pid = (int) $r['product_id'];
                $product = $cache[$pid] ??= wc_get_product($pid);
                if (!$product || !$product->is_in_stock()) {
                    continue;
                }
                $ref = (float) $r['ref_price'];
                $now_price = (float) wc_get_price_to_display($product);
                if ($ref <= 0 || $now_price <= 0 || $now_price > $ref * self::DROP_RATIO) {
                    continue;
                }
                $name = wp_strip_all_tags($product->get_name());
                $r2 = Zooboxi_Push_Engine::submit([
                    'user_id'      => (int) $r['user_id'],
                    'guest_id'     => (string) $r['guest_id'],
                    'topic'        => 'offers',
                    'tier'         => Zooboxi_Push_Gate::TIER_SERVICE,
                    'copy'         => [
                        'ar' => ['صار بـ ' . number_format($now_price, 0) . ' ﷼ بدل ' . number_format($ref, 0), $name . ' — من مفضلتك، لفترة محدودة.'],
                        'en' => ['Now ' . number_format($now_price, 0) . ' SAR, was ' . number_format($ref, 0), $name . ' — from your wishlist, for a limited time.'],
                    ],
                    'route'        => '/product/' . $pid,
                    'data'         => ['product_id' => (string) $pid],
                    'collapse_key' => 'price-' . $pid,
                    'thread_id'    => 'waitlist',
                    'relevance'    => 0.8,
                    'source'       => 'price_drop',
                    'source_id'    => (string) $pid,
                    'expires_at'   => time() + 2 * DAY_IN_SECONDS,
                ]);
                if ($r2['id'] > 0) {
                    $wpdb->update(self::table(), ['notified_at' => gmdate('Y-m-d H:i:s'), 'ref_price' => $now_price], ['id' => (int) $r['id']]);
                    $sent++;
                }
            } catch (\Throwable $e) {
                error_log('[Zooboxi push] price check failed: ' . $e->getMessage());
            }
        }
        return $sent;
    }
}
