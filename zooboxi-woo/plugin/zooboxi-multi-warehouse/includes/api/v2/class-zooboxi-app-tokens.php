<?php
/**
 * Zooboxi_App_Tokens — long-lived bearer tokens for the customer mobile app.
 *
 * The raw token (`zbat_<base64url(32 random bytes)>`) is returned to the device exactly
 * once, at OTP-verify time; only its SHA-256 hash is ever stored. Verification is a
 * single indexed lookup on that hash — no reversible secret lives in the database.
 *
 * The table is created lazily (dbDelta on a cheap option-version check) because the
 * plugin is deployed by scp: activation hooks never fire on this store.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_App_Tokens
{
    /** Table name (without the WP prefix). */
    public const TABLE = 'zooboxi_app_tokens';

    /** Bump when the schema below changes. */
    public const DB_VERSION = 1;

    /** Option holding the installed schema version. */
    private const DB_OPTION = 'zooboxi_v2_db_version';

    /** Raw-token prefix (kept out of the hash so it stays greppable in logs-free code). */
    private const PREFIX = 'zbat_';

    /** Token lifetime, refreshed (slid) on use at most once per day. */
    private const TTL_DAYS = 365;

    /* ── Schema ────────────────────────────────────── */

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE;
    }

    /**
     * Create/upgrade the table when the stored version is behind. Cheap no-op on
     * every request after the first (one option read).
     */
    public static function maybe_install(): void
    {
        if ((int) get_option(self::DB_OPTION, 0) >= self::DB_VERSION) {
            return;
        }
        self::install();
    }

    public static function install(): void
    {
        global $wpdb;

        $table   = self::table();
        $charset = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE {$table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            token_hash CHAR(64) NOT NULL,
            device_name VARCHAR(120) NOT NULL DEFAULT '',
            platform VARCHAR(20) NOT NULL DEFAULT '',
            created_at DATETIME NOT NULL,
            last_used_at DATETIME NULL DEFAULT NULL,
            expires_at DATETIME NULL DEFAULT NULL,
            revoked TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY token_hash (token_hash),
            KEY user_id (user_id)
        ) {$charset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);

        update_option(self::DB_OPTION, self::DB_VERSION, false);
    }

    /* ── Issue / verify / revoke ───────────────────── */

    /**
     * Mint a token for a user. Returns the RAW token — the only time it exists in clear.
     *
     * @return string '' on failure.
     */
    public static function issue(int $user_id, string $platform = '', string $device_name = ''): string
    {
        if ($user_id <= 0) {
            return '';
        }
        self::maybe_install();

        global $wpdb;

        try {
            $raw = self::PREFIX . self::base64url(random_bytes(32));
        } catch (\Throwable $e) {
            return '';
        }

        $now = current_time('mysql', true);
        $ok  = $wpdb->insert(
            self::table(),
            [
                'user_id'      => $user_id,
                'token_hash'   => self::hash($raw),
                'device_name'  => mb_substr(sanitize_text_field($device_name), 0, 120),
                'platform'     => mb_substr(sanitize_key($platform), 0, 20),
                'created_at'   => $now,
                'last_used_at' => $now,
                'expires_at'   => gmdate('Y-m-d H:i:s', time() + self::TTL_DAYS * DAY_IN_SECONDS),
                'revoked'      => 0,
            ],
            ['%d', '%s', '%s', '%s', '%s', '%s', '%s', '%d']
        );

        return $ok ? $raw : '';
    }

    /**
     * Resolve a raw bearer token to a user id. Slides the expiry (and stamps
     * last_used_at) at most once per day so an active device never gets logged out.
     *
     * @return int 0 when the token is unknown / revoked / expired.
     */
    public static function verify(string $raw): int
    {
        $raw = trim($raw);
        if ($raw === '' || strpos($raw, self::PREFIX) !== 0) {
            return 0;
        }

        global $wpdb;
        $table = self::table();

        // The table may not exist yet on a fresh deploy — a missing table simply
        // yields null here (wpdb suppresses the error to the log), never a fatal.
        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT id, user_id, revoked, expires_at, last_used_at FROM {$table} WHERE token_hash = %s LIMIT 1",
                self::hash($raw)
            ),
            ARRAY_A
        );

        if (!$row || (int) $row['revoked'] === 1) {
            return 0;
        }
        if (!empty($row['expires_at']) && strtotime($row['expires_at'] . ' UTC') < time()) {
            return 0;
        }

        $user_id = (int) $row['user_id'];
        if ($user_id <= 0 || !get_userdata($user_id)) {
            return 0;
        }

        // Slide at most once a day (keeps the write volume near zero).
        $last = !empty($row['last_used_at']) ? strtotime($row['last_used_at'] . ' UTC') : 0;
        if ((time() - $last) > DAY_IN_SECONDS) {
            $wpdb->update(
                $table,
                [
                    'last_used_at' => current_time('mysql', true),
                    'expires_at'   => gmdate('Y-m-d H:i:s', time() + self::TTL_DAYS * DAY_IN_SECONDS),
                ],
                ['id' => (int) $row['id']],
                ['%s', '%s'],
                ['%d']
            );
        }

        return $user_id;
    }

    /** Revoke one raw token. */
    public static function revoke(string $raw): bool
    {
        $raw = trim($raw);
        if ($raw === '') {
            return false;
        }
        global $wpdb;
        return (bool) $wpdb->update(
            self::table(),
            ['revoked' => 1],
            ['token_hash' => self::hash($raw)],
            ['%d'],
            ['%s']
        );
    }

    /** Revoke every token of a user (used when an account is disabled). */
    public static function revoke_all(int $user_id): void
    {
        if ($user_id <= 0) {
            return;
        }
        global $wpdb;
        $wpdb->update(self::table(), ['revoked' => 1], ['user_id' => $user_id], ['%d'], ['%d']);
    }

    /* ── Helpers ───────────────────────────────────── */

    private static function hash(string $raw): string
    {
        return hash('sha256', $raw);
    }

    private static function base64url(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }
}
