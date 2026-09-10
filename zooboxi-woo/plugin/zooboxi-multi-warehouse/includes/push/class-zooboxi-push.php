<?php
/**
 * Push notifications — the device registry and the sender.
 *
 * The store sends its own push. Every trigger a customer cares about already
 * lives here — an order changing status, a gift granted, a bundle going live —
 * so relaying them through sapconnect would only add a hop that can fail
 * between the fact and the phone.
 *
 * Transport is FCM HTTP v1: a service-account JSON, an RS256 JWT exchanged for
 * an access token (cached), and one POST per device. The legacy server key is
 * deliberately not used — Google turned it off in 2024.
 *
 * Nothing here is allowed to break the thing that triggered it. A store that
 * cannot send a notification still has to take the order.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push
{
    /** Bumped when the table changes. */
    const SCHEMA_VERSION = 1;

    const OPTION_SCHEMA  = 'zooboxi_push_schema';
    const OPTION_ACCOUNT = 'zooboxi_fcm_service_account';
    const OPTION_ENABLED = 'zooboxi_push_enabled';

    /** OAuth tokens live an hour; we re-mint five minutes early. */
    const TOKEN_TTL = 3300;

    /**
     * What a customer can switch off, and what each is for.
     *
     * `orders` is transactional and defaults on; it is still listed because a
     * notification the customer cannot turn off is a notification they turn
     * off at the OS level, and then we lose the delivery ones too.
     */
    const TOPICS = ['orders', 'offers', 'reorder', 'family'];

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_devices';
    }

    public static function is_enabled(): bool
    {
        return get_option(self::OPTION_ENABLED, 'yes') === 'yes' && self::project_id() !== '';
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
        $table   = self::table();
        $collate = $wpdb->get_charset_collate();

        // `token` is the identity: FCM issues one per app install, and a
        // re-installed app must replace its old row rather than accumulate.
        $sql = "CREATE TABLE {$table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            token VARCHAR(255) NOT NULL,
            user_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            guest_id VARCHAR(64) NOT NULL DEFAULT '',
            platform VARCHAR(12) NOT NULL DEFAULT 'ios',
            app_version VARCHAR(24) NOT NULL DEFAULT '',
            locale VARCHAR(8) NOT NULL DEFAULT 'ar',
            prefs LONGTEXT NULL,
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            fail_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_seen_at DATETIME NULL,
            PRIMARY KEY (id),
            UNIQUE KEY token (token),
            KEY user_id (user_id),
            KEY guest_id (guest_id)
        ) {$collate};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
        update_option(self::OPTION_SCHEMA, self::SCHEMA_VERSION, false);
    }

    /* ══════════════════════════════════════════════════════════════
       DEVICES
       ══════════════════════════════════════════════════════════════ */

    /**
     * Records the device that is holding this token right now.
     *
     * A phone that signs in must carry its token over to the account, and a
     * phone that signs out must stop receiving that customer's orders — both
     * are the same UPDATE on the same unique token.
     */
    public static function register(array $device): bool
    {
        self::maybe_install();
        global $wpdb;

        $token = trim((string) ($device['token'] ?? ''));
        if ($token === '' || strlen($token) > 255) {
            return false;
        }

        $now  = current_time('mysql');
        $row  = [
            'token'        => $token,
            'user_id'      => max(0, (int) ($device['user_id'] ?? 0)),
            'guest_id'     => substr((string) ($device['guest_id'] ?? ''), 0, 64),
            'platform'     => in_array($device['platform'] ?? '', ['ios', 'android'], true)
                ? $device['platform'] : 'ios',
            'app_version'  => substr((string) ($device['app_version'] ?? ''), 0, 24),
            'locale'       => substr((string) ($device['locale'] ?? 'ar'), 0, 8),
            'enabled'      => 1,
            'fail_count'   => 0,
            'updated_at'   => $now,
            'last_seen_at' => $now,
        ];

        $existing = self::find($token);
        if ($existing === null) {
            $row['prefs']      = wp_json_encode(self::default_prefs());
            $row['created_at'] = $now;
            return (bool) $wpdb->insert(self::table(), $row);
        }

        // Preferences belong to the customer, not to the registration — a
        // token refresh must never silently switch offers back on.
        return $wpdb->update(self::table(), $row, ['token' => $token]) !== false;
    }

    public static function unregister(string $token): void
    {
        if ($token === '') {
            return;
        }
        global $wpdb;
        $wpdb->delete(self::table(), ['token' => $token]);
    }

    public static function find(string $token): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row(
            $wpdb->prepare('SELECT * FROM ' . self::table() . ' WHERE token = %s LIMIT 1', $token),
            ARRAY_A
        );
        return $row ?: null;
    }

    /** Every live device for a customer, or for a guest install. */
    public static function devices_for(int $user_id, string $guest_id = ''): array
    {
        self::maybe_install();
        global $wpdb;

        if ($user_id > 0) {
            return $wpdb->get_results(
                $wpdb->prepare(
                    'SELECT * FROM ' . self::table() . ' WHERE user_id = %d AND enabled = 1',
                    $user_id
                ),
                ARRAY_A
            ) ?: [];
        }
        if ($guest_id !== '') {
            return $wpdb->get_results(
                $wpdb->prepare(
                    'SELECT * FROM ' . self::table() . ' WHERE guest_id = %s AND user_id = 0 AND enabled = 1',
                    $guest_id
                ),
                ARRAY_A
            ) ?: [];
        }
        return [];
    }

    /* ══════════════════════════════════════════════════════════════
       PREFERENCES
       ══════════════════════════════════════════════════════════════ */

    public static function default_prefs(): array
    {
        return array_fill_keys(self::TOPICS, true);
    }

    public static function prefs_of(array $device): array
    {
        $stored = json_decode((string) ($device['prefs'] ?? ''), true);
        $prefs  = self::default_prefs();
        if (is_array($stored)) {
            foreach (self::TOPICS as $topic) {
                if (array_key_exists($topic, $stored)) {
                    $prefs[$topic] = (bool) $stored[$topic];
                }
            }
        }
        return $prefs;
    }

    /**
     * Writes preferences for every device this person owns — the switch is
     * about the customer, not about the handset they happened to flip it on.
     */
    public static function set_prefs(int $user_id, string $guest_id, array $prefs): array
    {
        $current = self::default_prefs();
        foreach (self::TOPICS as $topic) {
            if (array_key_exists($topic, $prefs)) {
                $current[$topic] = (bool) $prefs[$topic];
            }
        }

        global $wpdb;
        $json = wp_json_encode($current);
        if ($user_id > 0) {
            $wpdb->update(self::table(), ['prefs' => $json, 'updated_at' => current_time('mysql')], ['user_id' => $user_id]);
        } elseif ($guest_id !== '') {
            $wpdb->update(self::table(), ['prefs' => $json, 'updated_at' => current_time('mysql')], ['guest_id' => $guest_id]);
        }
        return $current;
    }

    /* ══════════════════════════════════════════════════════════════
       SENDING
       ══════════════════════════════════════════════════════════════ */

    /**
     * Sends one notification to every device a customer has that still wants
     * [$topic]. Returns how many were accepted by FCM.
     *
     * [$route] is the app's own deep link ("/orders/32579") and travels in the
     * data payload: tapping a notification must land on the thing it is about,
     * not on the home screen.
     */
    public static function send_to_user(
        int $user_id,
        string $topic,
        string $title,
        string $body,
        string $route = '',
        array $extra = []
    ): int {
        if (!self::is_enabled() || $user_id <= 0) {
            return 0;
        }
        return self::send_to_devices(self::devices_for($user_id), $topic, $title, $body, $route, $extra);
    }

    public static function send_to_devices(
        array $devices,
        string $topic,
        string $title,
        string $body,
        string $route = '',
        array $extra = []
    ): int {
        if (!self::is_enabled() || !$devices) {
            return 0;
        }
        $sent = 0;
        foreach ($devices as $device) {
            $prefs = self::prefs_of($device);
            if (empty($prefs[$topic])) {
                continue;
            }
            if (self::send_raw((string) $device['token'], $title, $body, $route, $extra + ['topic' => $topic])) {
                $sent++;
            }
        }
        return $sent;
    }

    /**
     * One message, one token, FCM HTTP v1.
     *
     * A token the server rejects as gone (UNREGISTERED / INVALID_ARGUMENT) is
     * deleted on the spot: an install that was removed keeps answering 404
     * forever otherwise, and every send after it pays for the round trip.
     */
    public static function send_raw(
        string $token,
        string $title,
        string $body,
        string $route = '',
        array $data = [],
        array $opts = []
    ): bool {
        self::$last_message_name = '';
        self::$last_token_dead   = false;
        self::$last_error_code   = '';

        $project = self::project_id();
        $access  = self::access_token();
        if ($project === '' || $access === '') {
            self::$last_error_code = 'no_credentials';
            return false;
        }

        // Delivery options, all optional — see Zooboxi_Push_Engine::submit().
        $collapse  = substr((string) ($opts['collapse_key'] ?? ''), 0, 64);
        $ttl       = max(0, (int) ($opts['ttl_s'] ?? 0));
        $level     = (string) ($opts['level'] ?? 'active');
        if (!in_array($level, ['passive', 'active', 'time-sensitive'], true)) {
            $level = 'active';
        }
        $relevance = max(0.0, min(1.0, (float) ($opts['relevance'] ?? 0.5)));
        $thread    = substr((string) ($opts['thread_id'] ?? ''), 0, 64);

        $aps = [
            // The customer reads Arabic; the alert must too.
            'alert'              => ['title' => $title, 'body' => $body],
            'interruption-level' => $level,
            'relevance-score'    => $relevance,
        ];
        // A passive notification does not light the screen or make a sound —
        // right for "a bundle you might like", wrong for "your courier is here".
        if ($level !== 'passive') {
            $aps['sound'] = 'default';
        }
        if ($thread !== '') {
            $aps['thread-id'] = $thread;
        }

        $apns_headers = [
            // Marketing rides the power-aware priority; anything the customer
            // is waiting for goes out immediately.
            'apns-priority' => $level === 'passive' ? '5' : '10',
            'apns-push-type' => 'alert',
        ];
        $android = [
            'priority'     => $level === 'passive' ? 'normal' : 'high',
            'notification' => $level === 'passive' ? [] : ['sound' => 'default'],
        ];
        if ($collapse !== '') {
            // A newer status replaces the older one on the device instead of
            // stacking beneath it.
            $apns_headers['apns-collapse-id'] = $collapse;
            $android['collapse_key'] = $collapse;
        }
        if ($ttl > 0) {
            // «مندوبك عند بابك» delivered three hours late is a lie.
            $apns_headers['apns-expiration'] = (string) (time() + $ttl);
            $android['ttl'] = $ttl . 's';
        }

        $payload = [
            'message' => [
                'token'        => $token,
                'notification' => ['title' => $title, 'body' => $body],
                'data'         => array_map('strval', $data + ['route' => $route]),
                'apns'         => [
                    'headers' => $apns_headers,
                    'payload' => ['aps' => $aps],
                ],
                'android' => array_filter($android, static fn ($v) => $v !== []),
            ],
        ];

        $response = wp_remote_post(
            'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send',
            [
                'timeout' => 8,
                'headers' => [
                    'Authorization' => 'Bearer ' . $access,
                    'Content-Type'  => 'application/json; charset=utf-8',
                ],
                'body'    => wp_json_encode($payload),
            ]
        );

        if (is_wp_error($response)) {
            self::$last_error_code = 'transport';
            error_log('[Zooboxi push] send failed: ' . $response->get_error_message());
            return false;
        }

        $code = (int) wp_remote_retrieve_response_code($response);
        $raw  = (string) wp_remote_retrieve_body($response);
        if ($code >= 200 && $code < 300) {
            self::$last_message_name = (string) (json_decode($raw, true)['name'] ?? '');
            return true;
        }

        $status = (string) (json_decode($raw, true)['error']['status'] ?? '');
        self::$last_error_code = $status !== '' ? $status : ('http_' . $code);
        if ($code === 404 || $status === 'UNREGISTERED' || $status === 'INVALID_ARGUMENT' || $status === 'SENDER_ID_MISMATCH') {
            self::$last_token_dead = true;
            self::unregister($token);
        }
        error_log('[Zooboxi push] FCM ' . $code . ': ' . substr($raw, 0, 300));
        return false;
    }

    /** @var string FCM's name for the last accepted message ("projects/…/messages/…"). */
    private static $last_message_name = '';
    /** @var bool Whether the last failure was a token FCM declared dead. */
    private static $last_token_dead = false;
    /** @var string The last failure's FCM status or an internal code. */
    private static $last_error_code = '';

    public static function last_message_name(): string
    {
        return self::$last_message_name;
    }

    public static function last_token_dead(): bool
    {
        return self::$last_token_dead;
    }

    public static function last_error_code(): string
    {
        return self::$last_error_code;
    }

    /* ══════════════════════════════════════════════════════════════
       LIVE ACTIVITIES (iOS lock screen + Dynamic Island)
       ══════════════════════════════════════════════════════════════ */

    /**
     * Push a new content state into a running iOS Live Activity.
     *
     * The app starts the activity and hands the store two tokens: its FCM
     * device token (who) and the activity's own push token (which). FCM v1
     * carries the second in `apns.live_activity_token`; APNs then updates the
     * lock screen without waking the app — the only way the courier keeps
     * moving on a phone in a pocket.
     *
     * [$state] must mirror the Swift `ContentState` field for field; a key the
     * extension does not declare fails silently on the device.
     */
    public static function send_live_activity(
        string $device_token,
        string $activity_token,
        array $state,
        string $event = 'update',
        ?string $alert_title = null,
        ?string $alert_body = null
    ): bool {
        $project = self::project_id();
        $access  = self::access_token();
        if ($project === '' || $access === '' || $device_token === '' || $activity_token === '') {
            return false;
        }

        $aps = [
            'timestamp'     => time(),
            'event'         => $event === 'end' ? 'end' : 'update',
            'content-state' => (object) $state,
            // A state older than fifteen minutes is shown greyed: better than a
            // confident "8 minutes" from an hour ago.
            'stale-date'    => time() + 15 * MINUTE_IN_SECONDS,
        ];
        if ($event === 'end') {
            // Keep the final frame on the lock screen for a little while, then go.
            $aps['dismissal-date'] = time() + 30 * MINUTE_IN_SECONDS;
        }
        if ($alert_title !== null && $alert_body !== null) {
            $aps['alert'] = ['title' => $alert_title, 'body' => $alert_body];
        }

        $payload = [
            'message' => [
                'token' => $device_token,
                'apns'  => [
                    'live_activity_token' => $activity_token,
                    'headers' => [
                        'apns-priority'  => '10',
                        'apns-push-type' => 'liveactivity',
                    ],
                    'payload' => ['aps' => $aps],
                ],
            ],
        ];

        $response = wp_remote_post(
            'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send',
            [
                'timeout' => 8,
                'headers' => [
                    'Authorization' => 'Bearer ' . $access,
                    'Content-Type'  => 'application/json; charset=utf-8',
                ],
                'body'    => wp_json_encode($payload),
            ]
        );

        if (is_wp_error($response)) {
            error_log('[Zooboxi push] live activity send failed: ' . $response->get_error_message());
            return false;
        }
        $code = (int) wp_remote_retrieve_response_code($response);
        if ($code >= 200 && $code < 300) {
            return true;
        }
        error_log('[Zooboxi push] live activity FCM ' . $code . ': ' . substr((string) wp_remote_retrieve_body($response), 0, 300));
        return false;
    }

    /* ══════════════════════════════════════════════════════════════
       CREDENTIALS
       ══════════════════════════════════════════════════════════════ */

    /** The service account JSON, as stored in options. */
    public static function service_account(): array
    {
        $raw = (string) get_option(self::OPTION_ACCOUNT, '');
        if ($raw === '') {
            return [];
        }
        $account = json_decode($raw, true);
        return is_array($account) ? $account : [];
    }

    public static function project_id(): string
    {
        return (string) (self::service_account()['project_id'] ?? '');
    }

    /**
     * An OAuth access token for the messaging scope, minted from the service
     * account and cached until five minutes before it expires.
     */
    public static function access_token(): string
    {
        $cached = get_transient('zooboxi_fcm_access_token');
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $account = self::service_account();
        $email   = (string) ($account['client_email'] ?? '');
        $key     = (string) ($account['private_key'] ?? '');
        if ($email === '' || $key === '') {
            return '';
        }

        $now    = time();
        $claims = [
            'iss'   => $email,
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud'   => 'https://oauth2.googleapis.com/token',
            'exp'   => $now + 3600,
            'iat'   => $now,
        ];

        $jwt = self::sign_jwt($claims, $key);
        if ($jwt === '') {
            return '';
        }

        $response = wp_remote_post('https://oauth2.googleapis.com/token', [
            'timeout' => 8,
            'body'    => [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ],
        ]);
        if (is_wp_error($response)) {
            error_log('[Zooboxi push] token exchange failed: ' . $response->get_error_message());
            return '';
        }

        $body   = json_decode((string) wp_remote_retrieve_body($response), true);
        $access = (string) ($body['access_token'] ?? '');
        if ($access === '') {
            error_log('[Zooboxi push] token exchange rejected: ' . substr((string) wp_remote_retrieve_body($response), 0, 300));
            return '';
        }

        set_transient('zooboxi_fcm_access_token', $access, self::TOKEN_TTL);
        return $access;
    }

    /** RS256, with OpenSSL — the only signing this store needs. */
    private static function sign_jwt(array $claims, string $private_key): string
    {
        if (!function_exists('openssl_sign')) {
            error_log('[Zooboxi push] OpenSSL is missing; FCM v1 cannot sign.');
            return '';
        }
        $segments = [
            self::b64(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
            self::b64(wp_json_encode($claims)),
        ];
        $input     = implode('.', $segments);
        $signature = '';
        if (!openssl_sign($input, $signature, $private_key, 'sha256WithRSAEncryption')) {
            error_log('[Zooboxi push] JWT signing failed — check the service account key.');
            return '';
        }
        return $input . '.' . self::b64($signature);
    }

    private static function b64(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
