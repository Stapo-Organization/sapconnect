<?php
/**
 * The engine — outbox, gate, delivery, log.
 *
 * Every notification the store wants to send is first a ROW. A transactional
 * row is delivered in the same request; anything else waits for the
 * five-minute tick, which hands it to the gatekeeper and only then to FCM.
 * That one detour is what makes "hold it until 09:00" and "you already had
 * one today" possible at all — and it is what makes every send visible in
 * admin with a reason, instead of a line in a PHP error log nobody reads.
 *
 * Rules the engine keeps regardless of what calls it:
 *   - a row is inserted once (idempotency key) — a hook that fires twice
 *     cannot send twice;
 *   - the same (source, source_id) is never queued twice for one person while
 *     the first is still waiting;
 *   - a person in the holdout arm is recorded, never reached;
 *   - a token FCM has declared dead is deleted on the spot;
 *   - nothing here may break the thing that triggered it.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Engine
{
    const SCHEMA_VERSION = 1;
    const OPTION_SCHEMA  = 'zooboxi_push_engine_schema';
    /** The engine kill switch — stops the outbox, leaves transactional alone. */
    const OPTION_ENABLED = 'zooboxi_push_engine_enabled';
    const CRON           = 'zooboxi_push_tick';
    const LOCK           = 'zooboxi_push_tick_lock';

    const S_PENDING   = 'pending';
    const S_SENT      = 'sent';
    const S_SKIPPED   = 'skipped';
    const S_CONTROL   = 'control';
    const S_FAILED    = 'failed';
    const S_CANCELLED = 'cancelled';

    /** How many rows one tick may deliver, and how long it may run. */
    const BATCH  = 300;
    const BUDGET = 45;

    const MAX_ATTEMPTS = 3;

    /** @var string|null */
    private static $tick_token = null;

    public static function outbox(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_outbox';
    }

    public static function log(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_log';
    }

    public static function engine_enabled(): bool
    {
        return get_option(self::OPTION_ENABLED, 'yes') === 'yes';
    }

    public static function boot(): void
    {
        add_action(self::CRON, [self::class, 'tick']);
        add_action('init', [self::class, 'schedule'], 30);
        // Buying is the exit for a reminder to buy: a reorder nudge still
        // waiting in the outbox when the order lands is cancelled, not sent.
        add_action('woocommerce_order_status_processing', [self::class, 'on_order_placed'], 20, 2);
        add_action('woocommerce_order_status_completed', [self::class, 'on_order_placed'], 20, 2);
        add_action('woocommerce_checkout_order_processed', [self::class, 'on_order_placed'], 20, 1);
    }

    public static function schedule(): void
    {
        if (!wp_next_scheduled(self::CRON)) {
            wp_schedule_event(time() + 60, 'zooboxi_5_minutes', self::CRON);
        }
    }

    /* ══════════════════════════════════════════════════════════════
       SCHEMA
       ══════════════════════════════════════════════════════════════ */

    public static function maybe_install(): void
    {
        if ((int) get_option(self::OPTION_SCHEMA, 0) === self::SCHEMA_VERSION) {
            return;
        }
        global $wpdb;
        $collate = $wpdb->get_charset_collate();
        $outbox  = self::outbox();
        $log     = self::log();

        // All DATETIMEs are UTC (gmdate), compared with UTC_TIMESTAMP() —
        // never current_time('mysql'), whose offset moves with WP settings.
        $sql_outbox = "CREATE TABLE {$outbox} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            idem_key VARCHAR(191) NOT NULL,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            topic VARCHAR(16) NOT NULL DEFAULT 'orders',
            tier VARCHAR(16) NOT NULL DEFAULT 'marketing',
            source VARCHAR(40) NOT NULL DEFAULT '',
            source_id VARCHAR(64) NOT NULL DEFAULT '',
            route VARCHAR(191) NOT NULL DEFAULT '',
            title_ar TEXT NULL,
            body_ar TEXT NULL,
            title_en TEXT NULL,
            body_en TEXT NULL,
            data LONGTEXT NULL,
            collapse_key VARCHAR(64) NOT NULL DEFAULT '',
            ttl_s INT UNSIGNED NOT NULL DEFAULT 0,
            level VARCHAR(16) NOT NULL DEFAULT 'active',
            relevance DECIMAL(3,2) NOT NULL DEFAULT 0.50,
            thread_id VARCHAR(64) NOT NULL DEFAULT '',
            text_hash CHAR(32) NOT NULL DEFAULT '',
            counts TINYINT(1) NOT NULL DEFAULT 1,
            not_before DATETIME NULL,
            expires_at DATETIME NULL,
            status VARCHAR(12) NOT NULL DEFAULT 'pending',
            reason VARCHAR(32) NOT NULL DEFAULT '',
            attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            next_attempt_at DATETIME NULL,
            lock_token VARCHAR(36) NULL,
            locked_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            sent_at DATETIME NULL,
            opened_at DATETIME NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY idem (idem_key),
            KEY due (status, not_before, next_attempt_at),
            KEY person_sent (user_id, status, sent_at),
            KEY guest_sent (guest_id, status, sent_at),
            KEY src (source, source_id)
        ) {$collate};";

        $sql_log = "CREATE TABLE {$log} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            outbox_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            device_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            platform VARCHAR(12) NOT NULL DEFAULT '',
            topic VARCHAR(16) NOT NULL DEFAULT '',
            tier VARCHAR(16) NOT NULL DEFAULT '',
            source VARCHAR(40) NOT NULL DEFAULT '',
            source_id VARCHAR(64) NOT NULL DEFAULT '',
            status VARCHAR(12) NOT NULL DEFAULT '',
            reason VARCHAR(32) NOT NULL DEFAULT '',
            fcm_name VARCHAR(191) NOT NULL DEFAULT '',
            sent_at DATETIME NULL,
            opened_at DATETIME NULL,
            PRIMARY KEY  (id),
            KEY outbox (outbox_id),
            KEY user_sent (user_id, sent_at)
        ) {$collate};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql_outbox);
        dbDelta($sql_log);
        update_option(self::OPTION_SCHEMA, self::SCHEMA_VERSION, false);
    }

    /* ══════════════════════════════════════════════════════════════
       SUBMIT
       ══════════════════════════════════════════════════════════════ */

    /**
     * Queue one notification for one person.
     *
     * @param array $msg {
     *   int    user_id       Customer, or 0 with a guest_id.
     *   string guest_id      The app install id for a guest.
     *   string topic         One of Zooboxi_Push::TOPICS.
     *   string tier          transactional | service | marketing.
     *   array  copy          ['ar' => [title, body], 'en' => [title, body]] — en optional.
     *   string route         The app deep link ("/orders/32579").
     *   array  data          Extra data-payload keys (all cast to string).
     *   string collapse_key  Newer replaces older on the device (≤64 bytes).
     *   int    ttl_s         Seconds the message stays deliverable (0 = tier default).
     *   string level         passive | active | time-sensitive (iOS interruption level).
     *   float  relevance     0..1, ordering inside the iOS summary.
     *   string thread_id     Groups notifications on iOS.
     *   string source        Which journey/trigger ("order_status", "reorder").
     *   string source_id     Its object ("32579", product id).
     *   string key           Idempotency key; defaults to source:source_id:person:day.
     *   int    not_before    Unix; earliest delivery (windows may push it later).
     *   int    expires_at    Unix; after this the row is dropped as expired.
     *   bool   counts        Whether it counts toward caps (default true for non-transactional).
     * }
     * @return array{id:int,status:string,reason:string}
     */
    public static function submit(array $msg): array
    {
        try {
            self::maybe_install();
            global $wpdb;

            $user_id  = max(0, (int) ($msg['user_id'] ?? 0));
            $guest_id = substr((string) ($msg['guest_id'] ?? ''), 0, 64);
            if ($user_id <= 0 && $guest_id === '') {
                return ['id' => 0, 'status' => self::S_SKIPPED, 'reason' => Zooboxi_Push_Gate::R_NO_DEVICE];
            }
            $topic = (string) ($msg['topic'] ?? 'orders');
            if (!in_array($topic, Zooboxi_Push::TOPICS, true)) {
                $topic = 'orders';
            }
            $tier = Zooboxi_Push_Gate::normalise_tier((string) ($msg['tier'] ?? ''));
            $copy = (array) ($msg['copy'] ?? []);
            $ar   = (array) ($copy['ar'] ?? []);
            $en   = (array) ($copy['en'] ?? $ar);
            $title_ar = trim((string) ($ar[0] ?? ''));
            $body_ar  = trim((string) ($ar[1] ?? ''));
            if ($title_ar === '' && $body_ar === '') {
                return ['id' => 0, 'status' => self::S_SKIPPED, 'reason' => 'empty'];
            }

            $source    = substr((string) ($msg['source'] ?? ''), 0, 40);
            $source_id = substr((string) ($msg['source_id'] ?? ''), 0, 64);
            $person    = $user_id > 0 ? 'u' . $user_id : 'g' . $guest_id;
            $key       = (string) ($msg['key'] ?? '');
            if ($key === '') {
                $key = $source . ':' . $source_id . ':' . $person . ':' . gmdate('Y-m-d');
            }
            $key = substr($key, 0, 191);

            $not_before = (int) ($msg['not_before'] ?? 0);
            $expires    = (int) ($msg['expires_at'] ?? 0);
            $ttl        = (int) ($msg['ttl_s'] ?? 0);
            if ($ttl <= 0) {
                $ttl = $tier === Zooboxi_Push_Gate::TIER_TRANSACTIONAL ? 6 * HOUR_IN_SECONDS : DAY_IN_SECONDS;
            }
            if ($expires <= 0 && $tier !== Zooboxi_Push_Gate::TIER_TRANSACTIONAL) {
                // A marketing message that could not go out for three days is
                // about something that is no longer true.
                $expires = time() + 3 * DAY_IN_SECONDS;
            }

            // One (source, object) per person in flight at a time.
            if ($tier !== Zooboxi_Push_Gate::TIER_TRANSACTIONAL && $source !== '') {
                $pending = (int) $wpdb->get_var($wpdb->prepare(
                    'SELECT id FROM ' . self::outbox()
                    . ' WHERE status = %s AND source = %s AND source_id = %s AND user_id = %d AND guest_id = %s LIMIT 1',
                    self::S_PENDING, $source, $source_id, $user_id, $user_id > 0 ? '' : $guest_id
                ));
                if ($pending > 0) {
                    return ['id' => $pending, 'status' => self::S_PENDING, 'reason' => 'already_pending'];
                }
            }

            $level = (string) ($msg['level'] ?? 'active');
            if (!in_array($level, ['passive', 'active', 'time-sensitive'], true)) {
                $level = 'active';
            }
            // Marketing is never allowed to break through Focus — Apple's rule
            // and ours.
            if ($tier === Zooboxi_Push_Gate::TIER_MARKETING && $level === 'time-sensitive') {
                $level = 'active';
            }

            $row = [
                'idem_key'     => $key,
                'user_id'      => $user_id,
                'guest_id'     => $user_id > 0 ? '' : $guest_id,
                'topic'        => $topic,
                'tier'         => $tier,
                'source'       => $source,
                'source_id'    => $source_id,
                'route'        => substr((string) ($msg['route'] ?? ''), 0, 191),
                'title_ar'     => $title_ar,
                'body_ar'      => $body_ar,
                'title_en'     => trim((string) ($en[0] ?? $title_ar)),
                'body_en'      => trim((string) ($en[1] ?? $body_ar)),
                'data'         => wp_json_encode(array_map('strval', (array) ($msg['data'] ?? []))),
                'collapse_key' => substr((string) ($msg['collapse_key'] ?? ''), 0, 64),
                'ttl_s'        => $ttl,
                'level'        => $level,
                'relevance'    => max(0, min(1, (float) ($msg['relevance'] ?? 0.5))),
                'thread_id'    => substr((string) ($msg['thread_id'] ?? ''), 0, 64),
                'text_hash'    => md5($title_ar . '|' . $body_ar),
                'counts'       => (isset($msg['counts']) ? (bool) $msg['counts'] : $tier !== Zooboxi_Push_Gate::TIER_TRANSACTIONAL) ? 1 : 0,
                'not_before'   => $not_before > 0 ? gmdate('Y-m-d H:i:s', $not_before) : null,
                'expires_at'   => $expires > 0 ? gmdate('Y-m-d H:i:s', $expires) : null,
                'status'       => self::S_PENDING,
                'created_at'   => gmdate('Y-m-d H:i:s'),
            ];

            $prev_suppress = $wpdb->suppress_errors(true);
            $inserted = $wpdb->query(self::insert_ignore_sql($row));
            $wpdb->suppress_errors($prev_suppress);
            if (!$inserted) {
                // Duplicate key: the same fact already produced a row.
                $existing = (int) $wpdb->get_var($wpdb->prepare(
                    'SELECT id FROM ' . self::outbox() . ' WHERE idem_key = %s', $key
                ));
                return ['id' => $existing, 'status' => 'duplicate', 'reason' => ''];
            }
            $id = (int) $wpdb->insert_id;

            if ($tier === Zooboxi_Push_Gate::TIER_TRANSACTIONAL) {
                $fresh = self::row($id);
                $status = $fresh ? self::dispatch($fresh, time()) : self::S_FAILED;
                return ['id' => $id, 'status' => $status, 'reason' => (string) (self::row($id)['reason'] ?? '')];
            }
            return ['id' => $id, 'status' => self::S_PENDING, 'reason' => ''];
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] submit failed: ' . $e->getMessage());
            return ['id' => 0, 'status' => self::S_FAILED, 'reason' => 'exception'];
        }
    }

    private static function insert_ignore_sql(array $row): string
    {
        global $wpdb;
        $cols = [];
        $vals = [];
        foreach ($row as $col => $val) {
            $cols[] = '`' . $col . '`';
            if ($val === null) {
                $vals[] = 'NULL';
            } elseif (is_int($val)) {
                $vals[] = (string) $val;
            } elseif (is_float($val)) {
                $vals[] = sprintf('%.2F', $val);
            } else {
                $vals[] = $wpdb->prepare('%s', $val);
            }
        }
        return 'INSERT IGNORE INTO ' . self::outbox() . ' (' . implode(',', $cols) . ') VALUES (' . implode(',', $vals) . ')';
    }

    public static function row(int $id): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::outbox() . ' WHERE id = %d', $id), ARRAY_A);
        return $row ?: null;
    }

    /* ══════════════════════════════════════════════════════════════
       DISPATCH — one row through the gate and out to the phones
       ══════════════════════════════════════════════════════════════ */

    /** @return string The row's status after this attempt. */
    public static function dispatch(array $row, int $now): string
    {
        global $wpdb;
        $id   = (int) $row['id'];
        $tier = Zooboxi_Push_Gate::normalise_tier((string) $row['tier']);
        $transactional = $tier === Zooboxi_Push_Gate::TIER_TRANSACTIONAL;

        if (!Zooboxi_Push::is_enabled()) {
            return self::finish($id, self::S_SKIPPED, Zooboxi_Push_Gate::R_ENGINE_OFF);
        }
        if (!$transactional && !self::engine_enabled()) {
            return self::finish($id, self::S_SKIPPED, Zooboxi_Push_Gate::R_ENGINE_OFF);
        }

        $user_id  = (int) $row['user_id'];
        $guest_id = (string) $row['guest_id'];
        $devices  = Zooboxi_Push::devices_for($user_id, $guest_id);
        if (!$devices) {
            return self::finish($id, self::S_SKIPPED, Zooboxi_Push_Gate::R_NO_DEVICE);
        }
        $topic   = (string) $row['topic'];
        $wanting = array_values(array_filter($devices, static function ($d) use ($topic) {
            $prefs = Zooboxi_Push::prefs_of($d);
            return !empty($prefs[$topic]);
        }));
        if (!$wanting) {
            return self::finish($id, self::S_SKIPPED, Zooboxi_Push_Gate::R_TOPIC_OFF);
        }

        if (!$transactional) {
            $control = $user_id > 0 && class_exists('Zooboxi_Loyalty_Members') && class_exists('Zooboxi_Loyalty')
                && Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty_Members::is_holdout($user_id);
            $decision = Zooboxi_Push_Gate::decide(
                [
                    'tier'       => $tier,
                    'topic'      => $topic,
                    'text_hash'  => (string) $row['text_hash'],
                    'expires_at' => self::ts($row['expires_at'] ?? null),
                ],
                self::history($user_id, $guest_id, $now - 8 * DAY_IN_SECONDS),
                $control,
                $now
            );
            if ($decision['action'] === 'defer') {
                $wpdb->update(self::outbox(), [
                    'not_before' => gmdate('Y-m-d H:i:s', (int) $decision['not_before']),
                    'reason'     => (string) $decision['reason'],
                    'lock_token' => null,
                    'locked_at'  => null,
                ], ['id' => $id]);
                return self::S_PENDING;
            }
            if ($decision['action'] === 'skip') {
                $status = $decision['reason'] === Zooboxi_Push_Gate::R_CONTROL ? self::S_CONTROL : self::S_SKIPPED;
                if ($status === self::S_CONTROL) {
                    // Recorded as if sent: the conversion window starts now for
                    // the holdout too, or the lift read is meaningless.
                    self::log_row($row, null, self::S_CONTROL, '', '', $now);
                }
                return self::finish($id, $status, (string) $decision['reason']);
            }
        }

        // ── Deliver ──────────────────────────────────────────────────
        $data = json_decode((string) ($row['data'] ?? ''), true);
        $data = is_array($data) ? $data : [];
        $data['topic'] = $topic;
        $data['msg']   = (string) $id;

        $ttl = (int) $row['ttl_s'];
        $expires = self::ts($row['expires_at'] ?? null);
        if ($expires > 0) {
            $ttl = max(60, min($ttl, $expires - $now));
        }
        $opts = [
            'collapse_key' => (string) $row['collapse_key'],
            'ttl_s'        => $ttl,
            'level'        => (string) $row['level'],
            'relevance'    => (float) $row['relevance'],
            'thread_id'    => (string) $row['thread_id'],
        ];

        $sent = 0;
        $dead = 0;
        foreach ($wanting as $device) {
            $en = str_starts_with((string) ($device['locale'] ?? 'ar'), 'en');
            $title = (string) ($en ? $row['title_en'] : $row['title_ar']);
            $body  = (string) ($en ? $row['body_en'] : $row['body_ar']);
            if ($title === '' && $body === '') {
                $title = (string) $row['title_ar'];
                $body  = (string) $row['body_ar'];
            }
            $ok = Zooboxi_Push::send_raw((string) $device['token'], $title, $body, (string) $row['route'], $data, $opts);
            if ($ok) {
                $sent++;
                self::log_row($row, $device, self::S_SENT, '', Zooboxi_Push::last_message_name(), $now);
            } else {
                $dead += Zooboxi_Push::last_token_dead() ? 1 : 0;
                self::log_row($row, $device, self::S_FAILED, Zooboxi_Push::last_error_code(), '', $now);
            }
        }

        if ($sent > 0) {
            $wpdb->update(self::outbox(), [
                'status'     => self::S_SENT,
                'reason'     => '',
                'sent_at'    => gmdate('Y-m-d H:i:s', $now),
                'lock_token' => null,
                'locked_at'  => null,
            ], ['id' => $id]);
            do_action('zooboxi_push_sent', $row, $sent);
            return self::S_SENT;
        }

        // Nothing went out. A dead token is not worth retrying; a transport
        // hiccup is, a little.
        $attempts = (int) $row['attempts'] + 1;
        if ($dead >= count($wanting) || $attempts >= self::MAX_ATTEMPTS) {
            return self::finish($id, self::S_FAILED, $dead > 0 ? 'token_dead' : 'fcm_error', $attempts);
        }
        $wpdb->update(self::outbox(), [
            'attempts'        => $attempts,
            'reason'          => 'retry',
            'next_attempt_at' => gmdate('Y-m-d H:i:s', $now + 60 * (2 ** $attempts)),
            'lock_token'      => null,
            'locked_at'       => null,
        ], ['id' => $id]);
        return self::S_PENDING;
    }

    private static function finish(int $id, string $status, string $reason, ?int $attempts = null): string
    {
        global $wpdb;
        $set = ['status' => $status, 'reason' => substr($reason, 0, 32), 'lock_token' => null, 'locked_at' => null];
        if ($attempts !== null) {
            $set['attempts'] = $attempts;
        }
        $wpdb->update(self::outbox(), $set, ['id' => $id]);
        return $status;
    }

    private static function log_row(array $row, ?array $device, string $status, string $reason, string $fcm_name, int $now): void
    {
        global $wpdb;
        $wpdb->insert(self::log(), [
            'outbox_id' => (int) $row['id'],
            'device_id' => $device ? (int) $device['id'] : 0,
            'user_id'   => (int) $row['user_id'],
            'guest_id'  => (string) $row['guest_id'],
            'platform'  => $device ? (string) ($device['platform'] ?? '') : '',
            'topic'     => (string) $row['topic'],
            'tier'      => (string) $row['tier'],
            'source'    => (string) $row['source'],
            'source_id' => (string) $row['source_id'],
            'status'    => $status,
            'reason'    => substr($reason, 0, 32),
            'fcm_name'  => substr($fcm_name, 0, 191),
            'sent_at'   => gmdate('Y-m-d H:i:s', $now),
        ]);
    }

    /**
     * What this person has received (sent rows only) since [$since] — the
     * gate's memory. Transactional rows are included and ignored by the gate.
     */
    public static function history(int $user_id, string $guest_id, int $since): array
    {
        global $wpdb;
        $where = $user_id > 0
            ? $wpdb->prepare('user_id = %d', $user_id)
            : $wpdb->prepare('guest_id = %s AND user_id = 0', $guest_id);
        $rows = $wpdb->get_results(
            'SELECT tier, sent_at, text_hash FROM ' . self::outbox()
            . ' WHERE ' . $where . $wpdb->prepare(' AND status = %s AND counts = 1 AND sent_at >= %s', self::S_SENT, gmdate('Y-m-d H:i:s', $since)),
            ARRAY_A
        ) ?: [];
        foreach ($rows as &$r) {
            $r['sent_at'] = self::ts($r['sent_at']);
        }
        return $rows;
    }

    /* ══════════════════════════════════════════════════════════════
       THE TICK — every five minutes
       ══════════════════════════════════════════════════════════════ */

    /** @return array{claimed:int,sent:int,pending:int,skipped:int,failed:int} */
    public static function tick(): array
    {
        $stats = ['claimed' => 0, 'sent' => 0, 'pending' => 0, 'skipped' => 0, 'failed' => 0];
        if (get_transient(self::LOCK)) {
            return $stats;
        }
        set_transient(self::LOCK, 1, 2 * MINUTE_IN_SECONDS);
        $started = time();

        try {
            self::maybe_install();
            global $wpdb;
            $now = time();
            $utc = gmdate('Y-m-d H:i:s', $now);

            // Expired rows go quietly.
            $wpdb->query($wpdb->prepare(
                'UPDATE ' . self::outbox() . " SET status = %s, reason = %s WHERE status = %s AND expires_at IS NOT NULL AND expires_at <= %s",
                self::S_SKIPPED, Zooboxi_Push_Gate::R_EXPIRED, self::S_PENDING, $utc
            ));

            // Other sweeps that want the five-minute heartbeat (late orders…).
            do_action('zooboxi_push_tick', $now);

            $token = wp_generate_uuid4();
            $wpdb->query($wpdb->prepare(
                'UPDATE ' . self::outbox() . ' SET lock_token = %s, locked_at = %s'
                . ' WHERE status = %s'
                . ' AND (not_before IS NULL OR not_before <= %s)'
                . ' AND (next_attempt_at IS NULL OR next_attempt_at <= %s)'
                . ' AND (lock_token IS NULL OR locked_at < %s)'
                . ' ORDER BY id ASC LIMIT %d',
                $token, $utc, self::S_PENDING, $utc, $utc, gmdate('Y-m-d H:i:s', $now - 5 * MINUTE_IN_SECONDS), self::BATCH
            ));
            $rows = $wpdb->get_results(
                $wpdb->prepare('SELECT * FROM ' . self::outbox() . ' WHERE lock_token = %s ORDER BY id ASC', $token),
                ARRAY_A
            ) ?: [];
            $stats['claimed'] = count($rows);

            foreach ($rows as $row) {
                if (time() - $started > self::BUDGET) {
                    break;
                }
                try {
                    $status = self::dispatch($row, time());
                } catch (\Throwable $e) {
                    error_log('[Zooboxi push] dispatch #' . $row['id'] . ' failed: ' . $e->getMessage());
                    $status = self::finish((int) $row['id'], self::S_FAILED, 'exception');
                }
                if (isset($stats[$status])) {
                    $stats[$status]++;
                } elseif ($status === self::S_CONTROL) {
                    $stats['skipped']++;
                }
            }
            // Whatever the budget left behind is released for the next tick.
            $wpdb->query($wpdb->prepare(
                'UPDATE ' . self::outbox() . ' SET lock_token = NULL, locked_at = NULL WHERE lock_token = %s', $token
            ));

            update_option('zooboxi_push_tick_ran_at', $now, false);
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] tick failed: ' . $e->getMessage());
        } finally {
            delete_transient(self::LOCK);
        }
        return $stats;
    }

    /* ══════════════════════════════════════════════════════════════
       EXITS, OPENS, CANCELS
       ══════════════════════════════════════════════════════════════ */

    /** An order landed: the reminders to order are moot. */
    public static function on_order_placed($order_id, $order = null): void
    {
        try {
            if (!($order instanceof \WC_Order)) {
                $order = wc_get_order((int) $order_id);
            }
            if (!($order instanceof \WC_Order)) {
                return;
            }
            self::cancel_pending((int) $order->get_customer_id(), (string) $order->get_meta('_zb_guest_id'), ['reorder', 'winback', 'cart']);
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] exit-on-order failed: ' . $e->getMessage());
        }
    }

    /** Cancels this person's waiting rows from the given sources (or all non-transactional). */
    public static function cancel_pending(int $user_id, string $guest_id = '', array $sources = []): int
    {
        global $wpdb;
        if ($user_id <= 0 && $guest_id === '') {
            return 0;
        }
        $where = $user_id > 0
            ? $wpdb->prepare('user_id = %d', $user_id)
            : $wpdb->prepare('guest_id = %s AND user_id = 0', $guest_id);
        $sql = 'UPDATE ' . self::outbox() . $wpdb->prepare(
            " SET status = %s, reason = %s, lock_token = NULL WHERE status = %s AND tier <> %s AND ",
            self::S_CANCELLED, 'converted', self::S_PENDING, Zooboxi_Push_Gate::TIER_TRANSACTIONAL
        ) . $where;
        if ($sources) {
            $sql .= ' AND source IN (' . implode(',', array_map(fn ($s) => $wpdb->prepare('%s', $s), $sources)) . ')';
        }
        return (int) $wpdb->query($sql);
    }

    /**
     * The phone says a notification was tapped. Marks the row and forwards a
     * `push_open` event so the warehouse can join it to what happened next.
     */
    public static function mark_opened(int $outbox_id, int $user_id, string $guest_id): bool
    {
        global $wpdb;
        $row = self::row($outbox_id);
        if ($row === null) {
            return false;
        }
        $mine = ((int) $row['user_id'] > 0 && (int) $row['user_id'] === $user_id)
            || ((int) $row['user_id'] === 0 && $guest_id !== '' && (string) $row['guest_id'] === $guest_id);
        if (!$mine) {
            return false;
        }
        $utc = gmdate('Y-m-d H:i:s');
        if (empty($row['opened_at'])) {
            $wpdb->update(self::outbox(), ['opened_at' => $utc], ['id' => $outbox_id]);
            $wpdb->query($wpdb->prepare(
                'UPDATE ' . self::log() . ' SET opened_at = %s WHERE outbox_id = %d AND opened_at IS NULL', $utc, $outbox_id
            ));
        }
        if (class_exists('Zooboxi_Intelligence')) {
            $input = [
                'event_type' => 'push_open',
                'anon_id'    => $guest_id !== '' ? $guest_id : null,
                'zone'       => 'push:' . (string) $row['source'],
                'payload'    => [
                    'msg'       => $outbox_id,
                    'topic'     => (string) $row['topic'],
                    'tier'      => (string) $row['tier'],
                    'source'    => (string) $row['source'],
                    'source_id' => (string) $row['source_id'],
                ],
            ];
            if ($user_id > 0) {
                $input['customer_ref'] = 'wp_' . $user_id;
            }
            Zooboxi_Intelligence::forward_event($input);
        }
        return true;
    }

    /* ══════════════════════════════════════════════════════════════
       NUMBERS FOR ADMIN
       ══════════════════════════════════════════════════════════════ */

    /**
     * The last [$days] days: rows by status/reason, opens, and per-source
     * sent/opened. Everything an owner needs to see the engine is alive
     * and not shouting.
     */
    public static function stats(int $days = 7): array
    {
        self::maybe_install();
        global $wpdb;
        $since = gmdate('Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS);
        $outbox = self::outbox();

        $by_status = $wpdb->get_results($wpdb->prepare(
            "SELECT status, reason, COUNT(*) AS n FROM {$outbox} WHERE created_at >= %s GROUP BY status, reason ORDER BY n DESC", $since
        ), ARRAY_A) ?: [];
        $opened = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$outbox} WHERE status = 'sent' AND sent_at >= %s AND opened_at IS NOT NULL", $since
        ));
        $sent = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$outbox} WHERE status = 'sent' AND sent_at >= %s", $since
        ));
        $by_source = $wpdb->get_results($wpdb->prepare(
            "SELECT source, tier, SUM(status = 'sent') AS sent, SUM(status = 'sent' AND opened_at IS NOT NULL) AS opened,
                    SUM(status = 'skipped') AS skipped, SUM(status = 'control') AS control, SUM(status = 'pending') AS pending
             FROM {$outbox} WHERE created_at >= %s GROUP BY source, tier ORDER BY sent DESC", $since
        ), ARRAY_A) ?: [];
        $pending = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$outbox} WHERE status = 'pending'");

        return [
            'days'       => $days,
            'sent'       => $sent,
            'opened'     => $opened,
            'pending'    => $pending,
            'by_status'  => $by_status,
            'by_source'  => $by_source,
            'tick_at'    => (int) get_option('zooboxi_push_tick_ran_at', 0),
            'next_tick'  => (int) wp_next_scheduled(self::CRON),
        ];
    }

    /** A UTC DATETIME string → unix, or 0. */
    public static function ts($value): int
    {
        if ($value === null || $value === '' || $value === '0000-00-00 00:00:00') {
            return 0;
        }
        $t = strtotime((string) $value . ' UTC');
        return $t === false ? 0 : $t;
    }
}
