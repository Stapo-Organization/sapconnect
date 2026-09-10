<?php
/**
 * The basket left behind, and the express shelf about to close.
 *
 * Every cart answer the app receives leaves a one-row snapshot per person:
 * what is in it, how much, which shelf, and where the phone was. The tick
 * looks for snapshots that have gone quiet — 45 minutes on express (the
 * branch is open now, and recovery falls off a cliff after three hours),
 * two hours on the store — and starts the `cart` journey, which re-checks
 * the basket before every word it says. An emptied cart deletes its row.
 *
 * The same rows tell us who has an express basket when their branch is an
 * hour from closing: one service push, expiring at closing time, so it can
 * never arrive after the shutter is down.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Cart
{
    const EXPRESS_IDLE_MIN = 45;
    const STORE_IDLE_MIN   = 120;
    /** Minutes before closing that «يغلق خلال ساعة» goes out (window start/end). */
    const CLOSING_FROM = 65;
    const CLOSING_TO   = 50;

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_carts';
    }

    public static function install(string $collate): string
    {
        return 'CREATE TABLE ' . self::table() . " (
            person VARCHAR(80) NOT NULL,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            shelf VARCHAR(12) NOT NULL DEFAULT '',
            express TINYINT(1) NOT NULL DEFAULT 0,
            items_hash CHAR(32) NOT NULL DEFAULT '',
            count INT UNSIGNED NOT NULL DEFAULT 0,
            total DECIMAL(10,2) NOT NULL DEFAULT 0,
            first_name VARCHAR(191) NOT NULL DEFAULT '',
            first_pid BIGINT UNSIGNED NOT NULL DEFAULT 0,
            lat DECIMAL(9,6) NOT NULL DEFAULT 0,
            lng DECIMAL(9,6) NOT NULL DEFAULT 0,
            reminded_hash CHAR(32) NOT NULL DEFAULT '',
            closing_day DATE NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY  (person),
            KEY idle (count, updated_at),
            KEY express_idle (express, count, updated_at)
        ) {$collate};";
    }

    public static function boot(): void
    {
        add_action('zooboxi_v2_cart_dto', [self::class, 'capture'], 10, 4);
        add_action('zooboxi_push_tick', [self::class, 'sweep'], 30);
    }

    /** Called with every cart DTO the v2 API returns. */
    public static function capture(array $dto, string $shelf, float $lat, float $lng): void
    {
        try {
            $user_id  = get_current_user_id();
            $guest_id = class_exists('Zooboxi_V2_Bootstrap') ? Zooboxi_V2_Bootstrap::guest_id() : '';
            $person   = Zooboxi_Push_STO::person($user_id, $guest_id);
            if ($person === '') {
                return;
            }
            global $wpdb;
            $items = is_array($dto['items'] ?? null) ? $dto['items'] : [];
            if (!$items) {
                $wpdb->delete(self::table(), ['person' => $person]);
                return;
            }
            $sig   = [];
            $count = 0;
            $first = null;
            foreach ($items as $it) {
                if (!is_array($it)) {
                    continue;
                }
                $pid = (int) ($it['variation_id'] ?? 0) ?: (int) ($it['product_id'] ?? 0);
                $qty = (int) ($it['qty'] ?? $it['quantity'] ?? 1);
                $sig[] = $pid . 'x' . $qty;
                $count += max(1, $qty);
                if ($first === null) {
                    $first = ['pid' => (int) ($it['product_id'] ?? $pid), 'name' => wp_strip_all_tags((string) ($it['name'] ?? $it['title'] ?? ''))];
                }
            }
            sort($sig);
            $express = $shelf === 'express' || (string) ($dto['basket']['effective_shelf'] ?? '') === 'express';
            $row = [
                'person'     => $person,
                'user_id'    => $user_id,
                'guest_id'   => $user_id > 0 ? '' : substr($guest_id, 0, 64),
                'shelf'      => substr($shelf, 0, 12),
                'express'    => $express ? 1 : 0,
                'items_hash' => md5(implode(',', $sig)),
                'count'      => $count,
                'total'      => (float) ($dto['totals']['total'] ?? 0),
                'first_name' => mb_substr((string) ($first['name'] ?? ''), 0, 191),
                'first_pid'  => (int) ($first['pid'] ?? 0),
                'lat'        => $lat,
                'lng'        => $lng,
                'updated_at' => gmdate('Y-m-d H:i:s'),
            ];
            $cols = implode(',', array_map(fn ($c) => '`' . $c . '`', array_keys($row)));
            $vals = implode(',', array_map(fn ($v) => is_int($v) ? (string) $v : (is_float($v) ? sprintf('%.6F', $v) : $wpdb->prepare('%s', $v)), $row));
            $upd  = implode(',', array_map(fn ($c) => '`' . $c . '` = VALUES(`' . $c . '`)', array_diff(array_keys($row), ['person'])));
            $wpdb->query('INSERT INTO ' . self::table() . " ({$cols}) VALUES ({$vals}) ON DUPLICATE KEY UPDATE {$upd}");
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] cart capture failed: ' . $e->getMessage());
        }
    }

    public static function snapshot(int $user_id, string $guest_id): ?array
    {
        global $wpdb;
        $person = Zooboxi_Push_STO::person($user_id, $guest_id);
        if ($person === '') {
            return null;
        }
        $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table() . ' WHERE person = %s', $person), ARRAY_A);
        return $row ?: null;
    }

    /** Every five minutes: quiet baskets → the cart journey; closing branches → one push. */
    public static function sweep(int $now = 0): void
    {
        $now = $now > 0 ? $now : time();
        global $wpdb;
        try {
            if (Zooboxi_Push_Journeys::enabled('cart')) {
                $rows = $wpdb->get_results($wpdb->prepare(
                    'SELECT * FROM ' . self::table() . ' WHERE count > 0 AND reminded_hash <> items_hash AND updated_at <= %s AND updated_at >= %s LIMIT 200',
                    gmdate('Y-m-d H:i:s', $now - self::EXPRESS_IDLE_MIN * MINUTE_IN_SECONDS),
                    gmdate('Y-m-d H:i:s', $now - 3 * DAY_IN_SECONDS)
                ), ARRAY_A) ?: [];
                foreach ($rows as $r) {
                    $idle = $now - Zooboxi_Push_Engine::ts($r['updated_at']);
                    $need = (!empty($r['express']) ? self::EXPRESS_IDLE_MIN : self::STORE_IDLE_MIN) * MINUTE_IN_SECONDS;
                    if ($idle < $need) {
                        continue;
                    }
                    // Express: only while the branch can still deliver it today.
                    if (!empty($r['express']) && !self::express_open_now($r, $now, 30)) {
                        continue;
                    }
                    $wpdb->update(self::table(), ['reminded_hash' => $r['items_hash']], ['person' => $r['person']]);
                    Zooboxi_Push_Journeys::enroll('cart', (int) $r['user_id'], (string) $r['guest_id'], 'cart:' . $r['items_hash'], ['hash' => $r['items_hash']], $now);
                }
            }
            self::closing_soon($now);
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] cart sweep failed: ' . $e->getMessage());
        }
    }

    /** «إكسبريس يغلق خلال ساعة» to express baskets in a branch's last hour. */
    private static function closing_soon(int $now): void
    {
        if (get_option('zooboxi_push_closing_soon', 'yes') !== 'yes') {
            return;
        }
        global $wpdb;
        $today = (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz())->format('Y-m-d');
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE express = 1 AND count > 0 AND (closing_day IS NULL OR closing_day <> %s) AND updated_at >= %s LIMIT 200',
            $today, gmdate('Y-m-d H:i:s', $now - DAY_IN_SECONDS)
        ), ARRAY_A) ?: [];
        foreach ($rows as $r) {
            $close = self::express_close_at($r, $now);
            if ($close === null) {
                continue;
            }
            $left = $close - $now;
            if ($left > self::CLOSING_FROM * MINUTE_IN_SECONDS || $left < self::CLOSING_TO * MINUTE_IN_SECONDS) {
                continue;
            }
            $wpdb->update(self::table(), ['closing_day' => $today], ['person' => $r['person']]);
            $first = (string) $r['first_name'];
            Zooboxi_Push_Engine::submit([
                'user_id'      => (int) $r['user_id'],
                'guest_id'     => (string) $r['guest_id'],
                'topic'        => 'offers',
                'tier'         => Zooboxi_Push_Gate::TIER_SERVICE,
                'copy'         => [
                    'ar' => ['إكسبريس يغلق خلال ساعة', $first !== '' ? $first . ' في سلتك — أرسل طلبك الآن ويوصلك الليلة.' : 'سلتك جاهزة — أرسلها الآن وتوصلك الليلة.'],
                    'en' => ['Express closes in an hour', $first !== '' ? $first . ' is in your basket — order now and it arrives tonight.' : 'Your basket is ready — order now and it arrives tonight.'],
                ],
                'route'        => '/cart',
                'collapse_key' => 'cart',
                'thread_id'    => 'cart',
                'relevance'    => 0.9,
                'source'       => 'closing_soon',
                'source_id'    => $today,
                'key'          => 'closing:' . $r['person'] . ':' . $today,
                'expires_at'   => $close,
                'sto'          => false,
            ]);
        }
    }

    /** The express branch serving this snapshot's point, if any. */
    private static function branch_for(array $row): ?array
    {
        $lat = (float) ($row['lat'] ?? 0);
        $lng = (float) ($row['lng'] ?? 0);
        if (($lat == 0.0 && $lng == 0.0) || !class_exists('Zooboxi_Warehouse_Manager')) {
            return null;
        }
        $best = null;
        $best_km = null;
        foreach (Zooboxi_Warehouse_Manager::get_active() as $wh) {
            if (empty($wh['is_express_enabled']) || empty($wh['latitude']) || empty($wh['longitude'])) {
                continue;
            }
            if (!Zooboxi_Warehouse_Manager::is_within_express_zone($wh, $lat, $lng)) {
                continue;
            }
            $km = class_exists('Zooboxi_Geo_Helper')
                ? Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude'])
                : 0.0;
            if ($best_km === null || $km < $best_km) {
                $best_km = $km;
                $best = $wh;
            }
        }
        return $best;
    }

    /** Today's closing instant for the snapshot's branch; null when unknown or closed today. */
    public static function express_close_at(array $row, int $now): ?int
    {
        $wh = self::branch_for($row);
        if ($wh === null) {
            return null;
        }
        $raw = $wh['express_working_hours'] ?? null;
        $hours = is_string($raw) ? json_decode($raw, true) : $raw;
        if (!is_array($hours)) {
            return null;
        }
        $local = (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz());
        $today = $hours[strtolower($local->format('l'))] ?? null;
        if (!is_array($today) || !empty($today['closed'])) {
            return null;
        }
        if (!preg_match('/^(\d{1,2}):(\d{2})/', (string) ($today['close'] ?? ''), $m)) {
            return null;
        }
        $close = $local->setTime((int) $m[1], (int) $m[2])->getTimestamp();
        // A branch that closes after midnight ("01:00") closes tomorrow.
        if (preg_match('/^(\d{1,2}):(\d{2})/', (string) ($today['open'] ?? ''), $o)) {
            $open = $local->setTime((int) $o[1], (int) $o[2])->getTimestamp();
            if ($close <= $open) {
                $close += DAY_IN_SECONDS;
            }
        }
        return $close;
    }

    /** Is the branch open now and still open [$margin] minutes from now? */
    public static function express_open_now(array $row, int $now, int $margin): bool
    {
        $close = self::express_close_at($row, $now);
        if ($close === null) {
            return false;
        }
        $wh = self::branch_for($row);
        $raw = $wh['express_working_hours'] ?? null;
        $hours = is_string($raw) ? json_decode($raw, true) : $raw;
        $local = (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz());
        $today = is_array($hours) ? ($hours[strtolower($local->format('l'))] ?? null) : null;
        if (is_array($today) && preg_match('/^(\d{1,2}):(\d{2})/', (string) ($today['open'] ?? ''), $o)) {
            if ($now < $local->setTime((int) $o[1], (int) $o[2])->getTimestamp()) {
                return false;
            }
        }
        return $close - $now >= $margin * MINUTE_IN_SECONDS;
    }

    /** For the cart push's expiry: closing time when known, else half a day. */
    public static function express_close_after(array $row, int $now): int
    {
        return self::express_close_at($row, $now) ?? ($now + 12 * HOUR_IN_SECONDS);
    }
}
