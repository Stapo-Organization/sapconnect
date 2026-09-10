<?php
/**
 * Send-time optimisation — each customer's own hour.
 *
 * Every time the app comes to the foreground (`app_open`) or a notification
 * is tapped (`push_open`) the local hour gets a point, decayed nightly so
 * last month's habit fades behind this month's. A marketing message with no
 * fixed time is then queued for the customer's strongest hour inside the
 * marketing window — the hour they already look at their phone, rather than
 * the hour a cron happened to run. Someone we know too little about (fewer
 * than five signals) gets the store-wide hour, and a store that knows
 * nothing yet gets 18:30 Riyadh, which is where Saudi delivery apps peak.
 *
 * This is the same shape Braze and Iterable describe for their "intelligent
 * timing": a per-user engagement histogram, a segment/global fallback, a
 * clamp to the allowed window, computed ahead of time and never at send.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_STO
{
    /** Signals below this count are noise; fall back to the store-wide hour. */
    const MIN_SIGNALS = 5;
    /** Nightly multiplier on every bucket — a 30-day half-life, roughly. */
    const DECAY = 0.977;
    /** Minutes past midnight when nothing is known: 18:30. */
    const DEFAULT_MINUTE = 18 * 60 + 30;

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_hours';
    }

    public static function person(int $user_id, string $guest_id): string
    {
        return $user_id > 0 ? 'u' . $user_id : ($guest_id !== '' ? 'g' . substr($guest_id, 0, 64) : '');
    }

    public static function install(string $collate): string
    {
        return 'CREATE TABLE ' . self::table() . " (
            person VARCHAR(80) NOT NULL,
            hour TINYINT UNSIGNED NOT NULL DEFAULT 0,
            score FLOAT NOT NULL DEFAULT 0,
            n INT UNSIGNED NOT NULL DEFAULT 0,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY  (person, hour),
            KEY person_score (person, score)
        ) {$collate};";
    }

    /** One signal: this person was looking at their phone at [$ts]. */
    public static function observe(int $user_id, string $guest_id, int $ts, float $weight = 1.0): void
    {
        $person = self::person($user_id, $guest_id);
        if ($person === '') {
            return;
        }
        try {
            global $wpdb;
            $hour = (int) (new \DateTimeImmutable('@' . $ts))->setTimezone(Zooboxi_Push_Gate::tz())->format('G');
            $wpdb->query($wpdb->prepare(
                'INSERT INTO ' . self::table() . ' (person, hour, score, n, updated_at) VALUES (%s, %d, %f, 1, %s)'
                . ' ON DUPLICATE KEY UPDATE score = score + VALUES(score), n = n + 1, updated_at = VALUES(updated_at)',
                $person, $hour, $weight, gmdate('Y-m-d H:i:s')
            ));
        } catch (\Throwable $e) {
            error_log('[Zooboxi push] sto observe failed: ' . $e->getMessage());
        }
    }

    /**
     * The minute of the day (0–1439, local) this person is most likely to
     * look at their phone; null when we should use the store-wide hour.
     */
    public static function best_minute(int $user_id, string $guest_id): ?int
    {
        $person = self::person($user_id, $guest_id);
        if ($person === '') {
            return null;
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT hour, score, n FROM ' . self::table() . ' WHERE person = %s ORDER BY score DESC', $person
        ), ARRAY_A) ?: [];
        $signals = 0;
        foreach ($rows as $r) {
            $signals += (int) $r['n'];
        }
        if ($signals < self::MIN_SIGNALS || !$rows) {
            return null;
        }
        // Send at the half hour so a habit of "around nine" lands at 09:30,
        // inside the hour rather than at its very first minute.
        return ((int) $rows[0]['hour']) * 60 + 30;
    }

    /** The store-wide strongest hour (cached an hour), else the default. */
    public static function global_minute(): int
    {
        $cached = get_transient('zooboxi_push_sto_global');
        if (is_numeric($cached)) {
            return (int) $cached;
        }
        global $wpdb;
        $row = $wpdb->get_row('SELECT hour, SUM(score) s, SUM(n) n FROM ' . self::table() . ' GROUP BY hour ORDER BY s DESC LIMIT 1', ARRAY_A);
        $minute = ($row && (int) $row['n'] >= self::MIN_SIGNALS * 4) ? ((int) $row['hour']) * 60 + 30 : self::DEFAULT_MINUTE;
        set_transient('zooboxi_push_sto_global', $minute, HOUR_IN_SECONDS);
        return $minute;
    }

    /**
     * When to send a marketing message to this person: their hour today if
     * it is still ahead, otherwise tomorrow — clamped into the marketing
     * window, so a night owl's 23:00 becomes the window's edge rather than
     * a notification at eleven at night.
     */
    public static function next_slot(int $user_id, string $guest_id, int $now): int
    {
        $minute = self::best_minute($user_id, $guest_id) ?? self::global_minute();
        $tz     = Zooboxi_Push_Gate::tz();
        $start  = (string) Zooboxi_Push_Gate::opt('marketing_start');
        $end    = (string) Zooboxi_Push_Gate::opt('marketing_end');

        $local = (new \DateTimeImmutable('@' . $now))->setTimezone($tz);
        $at    = $local->setTime(intdiv($minute, 60), $minute % 60)->getTimestamp();
        // Anything less than ten minutes ahead is "now" — give the tick a
        // moment, but do not push it to tomorrow.
        if ($at < $now + 10 * MINUTE_IN_SECONDS) {
            // Missed today's slot by a little? Send now; by a lot, tomorrow.
            $at = ($now - $at < 3 * HOUR_IN_SECONDS) ? $now : $at + DAY_IN_SECONDS;
        }
        // Inside the marketing window, or at its next opening.
        return Zooboxi_Push_Gate::next_open($at, $start, $end, $tz);
    }

    /** Nightly: yesterday's habit counts a little less than today's. */
    public static function decay(): void
    {
        global $wpdb;
        $wpdb->query($wpdb->prepare('UPDATE ' . self::table() . ' SET score = score * %f', self::DECAY));
        // Buckets that have faded to nothing are noise; drop them.
        $wpdb->query('DELETE FROM ' . self::table() . ' WHERE score < 0.05');
        delete_transient('zooboxi_push_sto_global');
    }
}
