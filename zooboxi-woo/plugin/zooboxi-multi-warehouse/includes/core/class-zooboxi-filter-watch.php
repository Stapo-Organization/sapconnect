<?php
/**
 * ════════════════════════════════════════════════════════════════════
 * Zooboxi_Filter_Watch — «نبّهني إذا وصل…»
 *
 * The waitlist watches one product. This watches a question: «بط · قطط
 * صغيرة · رطب» that has no answer today. The app's empty state offers it
 * with the words of the picks; a row here is that person, those picks,
 * and where they stood when they asked.
 *
 * Every hour, after the facet index is rebuilt, each open watch is asked
 * again through the same index the listing reads. When something in stock
 * matches — and a store that serves them can reach it — they get one
 * service push that opens the very same list. A watch is answered once;
 * one that is still unanswered after sixty days lapses quietly.
 *
 * Loaded by Zooboxi_Facet_Index::hooks(), so it deploys with the index.
 * ════════════════════════════════════════════════════════════════════
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Filter_Watch
{
    public const SCHEMA        = 1;
    public const OPTION_SCHEMA = 'zooboxi_filter_watch_schema';
    public const LIFETIME      = 60 * DAY_IN_SECONDS;

    /** Listing params a watch keeps: the scope plus the picks. */
    private const SCOPE_PARAMS = ['category', 'brand', 'q', 'min_price', 'max_price'];

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_filter_watch';
    }

    public static function hooks(): void
    {
        add_action('rest_api_init', [self::class, 'routes']);
        // Right after the hourly rebuild, so the answer reads fresh stock.
        add_action(Zooboxi_Facet_Index::CRON, [self::class, 'check'], 20);
    }

    public static function maybe_install(): void
    {
        if ((int) get_option(self::OPTION_SCHEMA, 0) === self::SCHEMA) {
            return;
        }
        global $wpdb;
        $wpdb->query('CREATE TABLE IF NOT EXISTS ' . self::table() . " (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            sig CHAR(32) NOT NULL,
            params TEXT NOT NULL,
            label VARCHAR(160) NOT NULL DEFAULT '',
            lat DECIMAL(9,6) NOT NULL DEFAULT 0,
            lng DECIMAL(9,6) NOT NULL DEFAULT 0,
            express TINYINT UNSIGNED NOT NULL DEFAULT 0,
            lang VARCHAR(4) NOT NULL DEFAULT 'ar',
            created_at DATETIME NOT NULL,
            notified_at DATETIME NULL,
            PRIMARY KEY (id),
            UNIQUE KEY person_sig (user_id, guest_id, sig),
            KEY open_rows (notified_at, created_at)
        ) " . $wpdb->get_charset_collate());
        update_option(self::OPTION_SCHEMA, self::SCHEMA, false);
    }

    /* ══════════════════════════════════════════════════════════════
       THE QUESTION
       ══════════════════════════════════════════════════════════════ */

    /**
     * The listing params that define the question, normalised so the same
     * picks in another order are the same watch.
     *
     * @param array<string,mixed> $raw
     * @return array<string,string>
     */
    public static function params_of(array $raw): array
    {
        $out = [];
        foreach (self::SCOPE_PARAMS as $k) {
            $v = isset($raw[$k]) ? trim((string) $raw[$k]) : '';
            if ($v !== '') {
                $out[$k] = in_array($k, ['min_price', 'max_price'], true) ? (string) (float) $v : sanitize_text_field($v);
            }
        }
        foreach (Zooboxi_Facet_Index::FACETS as $facet) {
            $v = isset($raw['f_' . $facet]) ? (string) $raw['f_' . $facet] : '';
            $vals = array_values(array_unique(array_filter(array_map(
                static fn($x) => $facet === 'brand' ? rawurldecode(sanitize_title(rawurldecode(trim($x)))) : sanitize_key($x),
                explode(',', $v)
            ))));
            if (!empty($vals)) {
                sort($vals);
                $out['f_' . $facet] = implode(',', array_slice($vals, 0, 20));
            }
        }
        ksort($out);
        return $out;
    }

    /** A watch needs a pick to wait for — «كل المنتجات» with nothing picked is not a question. */
    public static function is_question(array $params): bool
    {
        foreach ($params as $k => $_) {
            if (strpos($k, 'f_') === 0 || $k === 'min_price' || $k === 'max_price') {
                return true;
            }
        }
        return false;
    }

    public static function sig(array $params): string
    {
        return md5((string) wp_json_encode($params));
    }

    /* ══════════════════════════════════════════════════════════════
       REST — /push/filter-watch
       ══════════════════════════════════════════════════════════════ */

    public static function routes(): void
    {
        if (!class_exists('Zooboxi_V2_Bootstrap')) {
            return;
        }
        Zooboxi_V2_Bootstrap::route('/push/filter-watch', 'GET', [self::class, 'rest_status']);
        Zooboxi_V2_Bootstrap::route('/push/filter-watch', 'POST', [self::class, 'rest_add']);
        Zooboxi_V2_Bootstrap::route('/push/filter-watch/remove', 'POST', [self::class, 'rest_remove']);
    }

    /** @return array{0:int,1:string} */
    private static function person(\WP_REST_Request $request): array
    {
        $uid = get_current_user_id();
        return [$uid, $uid > 0 ? '' : substr(Zooboxi_V2_Bootstrap::guest_id($request), 0, 64)];
    }

    private static function state(int $uid, string $gid, string $sig): array
    {
        self::maybe_install();
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT id, notified_at FROM ' . self::table() . ' WHERE user_id = %d AND guest_id = %s AND sig = %s',
            $uid, $gid, $sig
        ), ARRAY_A);
        return ['watching' => $row !== null && $row['notified_at'] === null, 'sig' => $sig];
    }

    public static function rest_status(\WP_REST_Request $request): \WP_REST_Response
    {
        [$uid, $gid] = self::person($request);
        return Zooboxi_V2_Bootstrap::ok(self::state($uid, $gid, self::sig(self::params_of($request->get_params()))));
    }

    public static function rest_add(\WP_REST_Request $request): \WP_REST_Response
    {
        [$uid, $gid] = self::person($request);
        $params = self::params_of($request->get_params());
        if (($uid <= 0 && $gid === '') || !self::is_question($params)) {
            return Zooboxi_V2_Bootstrap::fail('watch_failed', 'تعذّر التسجيل', 'Could not subscribe.', 400);
        }
        self::maybe_install();
        global $wpdb;
        $lat = (float) ($request->get_header('x_zb_lat') ?? 0);
        $lng = (float) ($request->get_header('x_zb_lng') ?? 0);
        if ($lat == 0.0 && $lng == 0.0) {
            [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        }
        $label   = mb_substr(sanitize_text_field((string) $request->get_param('label')), 0, 150);
        $express = class_exists('Zooboxi_Price_Book') && Zooboxi_Price_Book::is_express() ? 1 : 0;
        $sig     = self::sig($params);
        $wpdb->query($wpdb->prepare(
            'INSERT INTO ' . self::table() . ' (user_id, guest_id, sig, params, label, lat, lng, express, lang, created_at)'
            . ' VALUES (%d, %s, %s, %s, %s, %f, %f, %d, %s, %s)'
            . ' ON DUPLICATE KEY UPDATE label = VALUES(label), lat = VALUES(lat), lng = VALUES(lng), express = VALUES(express),'
            . ' lang = VALUES(lang), created_at = VALUES(created_at), notified_at = NULL',
            $uid, $gid, $sig, (string) wp_json_encode($params), $label, (float) $lat, (float) $lng, $express,
            Zooboxi_V2_Bootstrap::lang($request) === 'en' ? 'en' : 'ar', gmdate('Y-m-d H:i:s')
        ));
        return Zooboxi_V2_Bootstrap::ok(self::state($uid, $gid, $sig));
    }

    public static function rest_remove(\WP_REST_Request $request): \WP_REST_Response
    {
        [$uid, $gid] = self::person($request);
        $sig = self::sig(self::params_of($request->get_params()));
        self::maybe_install();
        global $wpdb;
        $wpdb->delete(self::table(), ['user_id' => $uid, 'guest_id' => $gid, 'sig' => $sig]);
        return Zooboxi_V2_Bootstrap::ok(self::state($uid, $gid, $sig));
    }

    /* ══════════════════════════════════════════════════════════════
       THE ANSWER — hourly
       ══════════════════════════════════════════════════════════════ */

    public static function check(): int
    {
        if (!class_exists('Zooboxi_Push_Engine') || get_option('zooboxi_push_waitlist', 'yes') !== 'yes') {
            return 0;
        }
        self::maybe_install();
        global $wpdb;
        $table = self::table();
        $wpdb->query($wpdb->prepare("DELETE FROM {$table} WHERE notified_at IS NULL AND created_at < %s", gmdate('Y-m-d H:i:s', time() - self::LIFETIME)));
        $rows = $wpdb->get_results("SELECT * FROM {$table} WHERE notified_at IS NULL ORDER BY id ASC LIMIT 300", ARRAY_A) ?: [];

        $sent    = 0;
        $answers = []; // one index read per distinct question
        foreach ($rows as $r) {
            try {
                $params = json_decode((string) $r['params'], true);
                if (!is_array($params)) {
                    continue;
                }
                $key = $r['sig'] . '|' . (int) $r['express'];
                $answers[$key] ??= self::matches($params, (bool) $r['express']);
                $ids = $answers[$key];
                if (empty($ids)) {
                    continue;
                }
                $reach = self::reachable($ids, (float) $r['lat'], (float) $r['lng']);
                if ($reach === 0) {
                    continue;
                }
                // Every sampled product reachable: the whole answer is theirs.
                if ($reach >= min(12, count($ids))) {
                    $reach = count($ids);
                }
                $label = trim((string) $r['label']);
                $route = '/listing?' . http_build_query($params + ['title' => $label !== '' ? $label : 'زوبكسي'], '', '&', PHP_QUERY_RFC3986);
                $res = Zooboxi_Push_Engine::submit([
                    'user_id'      => (int) $r['user_id'],
                    'guest_id'     => (string) $r['guest_id'],
                    'topic'        => 'offers',
                    'tier'         => Zooboxi_Push_Gate::TIER_SERVICE,
                    'copy'         => [
                        'ar' => [$label !== '' ? 'وصل: ' . $label : 'وصل ما طلبته', self::count_ar($reach) . ' تطابق اختياراتك الآن — قبل أن تنفد.'],
                        'en' => [$label !== '' ? 'In stock: ' . $label : 'What you asked for is here', $reach . ' ' . ($reach === 1 ? 'product matches' : 'products match') . ' your picks now.'],
                    ],
                    'route'        => $route,
                    'data'         => ['watch' => (string) $r['id']],
                    'collapse_key' => 'fwatch-' . $r['id'],
                    'thread_id'    => 'waitlist',
                    'relevance'    => 0.85,
                    'source'       => 'filter_watch',
                    'source_id'    => (string) $r['id'],
                    'expires_at'   => time() + 2 * DAY_IN_SECONDS,
                ]);
                if (($res['id'] ?? 0) > 0) {
                    $wpdb->update($table, ['notified_at' => gmdate('Y-m-d H:i:s')], ['id' => (int) $r['id']]);
                    $sent++;
                }
            } catch (\Throwable $e) {
                error_log('[zooboxi] filter watch failed: ' . $e->getMessage());
            }
        }
        return $sent;
    }

    /** «3 منتجات» with the Arabic number agreement the app uses. */
    private static function count_ar(int $n): string
    {
        if ($n === 1) return 'منتج واحد';
        if ($n === 2) return 'منتجان';
        if ($n >= 3 && $n <= 10) return $n . ' منتجات';
        return $n . ' منتجًا';
    }

    /**
     * In-stock products that answer the question, through the same index
     * and the same scope rules as the listing (minus the shelf's branch
     * clause: reachability is checked per person).
     *
     * @return int[]
     */
    public static function matches(array $params, bool $express): array
    {
        $tax = ['relation' => 'AND', [
            'taxonomy' => 'product_visibility',
            'field'    => 'name',
            'terms'    => 'exclude-from-catalog',
            'operator' => 'NOT IN',
        ]];
        $category = self::category((string) ($params['category'] ?? ''));
        if (($params['category'] ?? '') !== '' && !$category) {
            return []; // the department is gone
        }
        if ($category) {
            $tax[] = ['taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => (int) $category->term_id, 'include_children' => true];
        }
        $brand = sanitize_title((string) ($params['brand'] ?? ''));
        if ($brand !== '') {
            $tax[] = ['taxonomy' => taxonomy_exists('product_brand') ? 'product_brand' : 'pa_brand', 'field' => 'slug', 'terms' => [$brand]];
        }
        $args = [
            'post_type'        => 'product',
            'post_status'      => 'publish',
            'fields'           => 'ids',
            'posts_per_page'   => -1,
            'no_found_rows'    => true,
            'tax_query'        => $tax,
            'suppress_filters' => true,
        ];
        if (($params['q'] ?? '') !== '') {
            $args['s'] = (string) $params['q'];
        }
        $base = array_map('intval', (new WP_Query($args))->posts);
        if (empty($base)) {
            return [];
        }

        $selected = [];
        foreach (Zooboxi_Facet_Index::FACETS as $facet) {
            if (!empty($params['f_' . $facet])) {
                $selected[$facet] = explode(',', (string) $params['f_' . $facet]);
            }
        }
        $price = [
            'min' => isset($params['min_price']) ? (float) $params['min_price'] : null,
            'max' => isset($params['max_price']) ? (float) $params['max_price'] : null,
        ];
        $res = Zooboxi_Facet_Index::search($base, $selected, $price, '', $express, 'ar');
        return array_values(array_filter($res['ids'], static fn($id) => (int) ($res['meta'][$id]['instock'] ?? 0) === 1));
    }

    /** How many of [$ids] a store that serves this point can bring (all of them when the point is unknown). */
    private static function reachable(array $ids, float $lat, float $lng): int
    {
        if (($lat == 0.0 && $lng == 0.0) || !class_exists('Zooboxi_Fulfillment')) {
            return count($ids);
        }
        $n = 0;
        foreach (array_slice($ids, 0, 12) as $pid) {
            $res = Zooboxi_Fulfillment::resolve((int) $pid, 1, $lat, $lng);
            if ((int) ($res['reachable_total'] ?? 0) > 0) {
                $n++;
            }
        }
        return $n;
    }

    private static function category(string $raw)
    {
        if ($raw === '') {
            return null;
        }
        if (ctype_digit($raw)) {
            $t = get_term(absint($raw), 'product_cat');
            return ($t && !is_wp_error($t)) ? $t : null;
        }
        foreach (array_unique([$raw, sanitize_title($raw), rawurldecode($raw), sanitize_title(rawurldecode($raw))]) as $c) {
            if ($c === '') {
                continue;
            }
            $t = get_term_by('slug', $c, 'product_cat');
            if ($t && !is_wp_error($t)) {
                return $t;
            }
        }
        return null;
    }
}
