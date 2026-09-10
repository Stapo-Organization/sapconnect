<?php
/**
 * The gatekeeper — the one place that decides whether a non-transactional
 * notification may interrupt this person right now.
 *
 * Every rule here is pure: it takes the message, what has already been sent
 * to this person, and a clock, and answers `send`, `defer` (with when) or
 * `skip` (with why). Nothing in this file touches FCM or the database, so
 * the rules can be unit-tested with a fake clock and a fake history.
 *
 * The three tiers, and what the gate does with each:
 *   transactional — never enters the gate. An order status is the reason the
 *                   permission was granted; it is sent at once and counts
 *                   toward nothing.
 *   service       — something the customer started (a cart, a waitlist) or
 *                   is owed (a rating, a delay). Loose cap, quiet hours held.
 *   marketing     — everything the store initiates. One a day, three a
 *                   week, twenty hours apart, inside the marketing window.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Gate
{
    const TIER_TRANSACTIONAL = 'transactional';
    const TIER_SERVICE       = 'service';
    const TIER_MARKETING     = 'marketing';

    const TIERS = [self::TIER_TRANSACTIONAL, self::TIER_SERVICE, self::TIER_MARKETING];

    /** Skip / defer reason codes — stored on the outbox row, shown in admin. */
    const R_ENGINE_OFF   = 'engine_off';
    const R_NO_DEVICE    = 'no_device';
    const R_TOPIC_OFF    = 'topic_off';
    const R_CONTROL      = 'control';
    const R_QUIET        = 'quiet_hours';
    const R_WINDOW       = 'marketing_window';
    const R_FRIDAY       = 'friday_pause';
    const R_EXPIRED      = 'expired';
    const R_CAP_DAY      = 'cap_daily';
    const R_CAP_WEEK     = 'cap_weekly';
    const R_CAP_GAP      = 'cap_gap';
    const R_REPEAT       = 'repeat_text';

    /**
     * The knobs, with the defaults the plan fixed. Each is an option named
     * `zooboxi_push_{key}` so the admin screen can move it without a release.
     */
    public static function defaults(): array
    {
        return [
            'tz'                 => 'Asia/Riyadh',
            'quiet_start'        => '22:00',   // no non-transactional push from…
            'quiet_end'          => '08:00',   // …until (held, not dropped)
            'marketing_start'    => '09:00',   // marketing only inside this window
            'marketing_end'      => '21:30',
            'friday_pause_start' => '11:30',   // Jumu'ah — marketing holds
            'friday_pause_end'   => '13:15',
            'marketing_per_day'  => 1,
            'marketing_per_week' => 3,
            'marketing_gap_h'    => 20,
            'service_per_day'    => 2,
            'service_gap_h'      => 3,
            'total_per_day'      => 2,         // every non-transactional push together
            'total_per_week'     => 5,
            'repeat_days'        => 30,        // the same text never twice in this many days
        ];
    }

    public static function opt(string $key)
    {
        $defaults = self::defaults();
        $value    = get_option('zooboxi_push_' . $key, null);
        if ($value === null || $value === '') {
            return $defaults[$key] ?? null;
        }
        return is_int($defaults[$key] ?? null) ? (int) $value : (string) $value;
    }

    public static function tz(): \DateTimeZone
    {
        try {
            return new \DateTimeZone((string) self::opt('tz'));
        } catch (\Throwable $e) {
            return new \DateTimeZone('Asia/Riyadh');
        }
    }

    public static function normalise_tier(string $tier): string
    {
        return in_array($tier, self::TIERS, true) ? $tier : self::TIER_MARKETING;
    }

    /**
     * Decide.
     *
     * @param array $msg     The outbox row: tier, topic, text_hash, expires_at (unix|null).
     * @param array $history What this person has been sent — from
     *                       Zooboxi_Push_Engine::history(): each item
     *                       {tier, sent_at (unix), text_hash}. Only sent rows.
     * @param bool  $control Whether this person is in the holdout arm.
     * @param int   $now     The clock.
     * @param array $opts    Overrides for the knobs (tests); defaults from options.
     *
     * @return array{action:string,reason:string,not_before:int|null}
     *         action ∈ send | defer | skip
     */
    public static function decide(array $msg, array $history, bool $control, int $now, array $opts = []): array
    {
        $tier = self::normalise_tier((string) ($msg['tier'] ?? ''));
        $o    = array_merge(self::defaults(), array_filter([
            'tz' => self::opt('tz'),
            'quiet_start' => self::opt('quiet_start'), 'quiet_end' => self::opt('quiet_end'),
            'marketing_start' => self::opt('marketing_start'), 'marketing_end' => self::opt('marketing_end'),
            'friday_pause_start' => self::opt('friday_pause_start'), 'friday_pause_end' => self::opt('friday_pause_end'),
            'marketing_per_day' => self::opt('marketing_per_day'), 'marketing_per_week' => self::opt('marketing_per_week'),
            'marketing_gap_h' => self::opt('marketing_gap_h'), 'service_per_day' => self::opt('service_per_day'),
            'service_gap_h' => self::opt('service_gap_h'), 'total_per_day' => self::opt('total_per_day'),
            'total_per_week' => self::opt('total_per_week'), 'repeat_days' => self::opt('repeat_days'),
        ], fn ($v) => $v !== null), $opts);

        if ($tier === self::TIER_TRANSACTIONAL) {
            return self::send();
        }

        // The holdout never receives; it is *recorded* as if it had, so the
        // conversion window starts at the same instant for both arms.
        if ($control) {
            return self::skip(self::R_CONTROL);
        }

        $expires = (int) ($msg['expires_at'] ?? 0);
        if ($expires > 0 && $expires <= $now) {
            return self::skip(self::R_EXPIRED);
        }

        // ── Windows: hold, never drop ─────────────────────────────────
        $hold = self::window_block($tier, $now, $o, $msg);
        if ($hold !== null) {
            [$reason, $until] = $hold;
            if ($expires > 0 && $expires <= $until) {
                return self::skip(self::R_EXPIRED);
            }
            return self::defer($reason, $until);
        }

        // ── Caps: counted on this person's calendar days ──────────────
        $tz        = self::tz_of((string) $o['tz']);
        $day_start = self::day_start($now, $tz);
        $week_ago  = $now - 7 * DAY_IN_SECONDS;

        $today_all = 0; $week_all = 0;
        $today_tier = 0; $week_tier = 0; $last_tier = 0;
        $repeat_since = $now - max(0, (int) $o['repeat_days']) * DAY_IN_SECONDS;
        $hash = (string) ($msg['text_hash'] ?? '');

        foreach ($history as $h) {
            $t  = self::normalise_tier((string) ($h['tier'] ?? ''));
            $at = (int) ($h['sent_at'] ?? 0);
            if ($t === self::TIER_TRANSACTIONAL || $at <= 0) {
                continue;
            }
            if ($hash !== '' && (string) ($h['text_hash'] ?? '') === $hash && $at >= $repeat_since) {
                return self::skip(self::R_REPEAT);
            }
            if ($at >= $week_ago) {
                $week_all++;
                if ($t === $tier) { $week_tier++; }
            }
            if ($at >= $day_start) {
                $today_all++;
                if ($t === $tier) { $today_tier++; }
            }
            if ($t === $tier && $at > $last_tier) {
                $last_tier = $at;
            }
        }

        if ($today_all >= (int) $o['total_per_day']) {
            return self::skip(self::R_CAP_DAY);
        }
        if ($week_all >= (int) $o['total_per_week']) {
            return self::skip(self::R_CAP_WEEK);
        }
        if ($tier === self::TIER_MARKETING) {
            if ($today_tier >= (int) $o['marketing_per_day']) {
                return self::skip(self::R_CAP_DAY);
            }
            if ($week_tier >= (int) $o['marketing_per_week']) {
                return self::skip(self::R_CAP_WEEK);
            }
            if ($last_tier > 0 && $now - $last_tier < (int) $o['marketing_gap_h'] * HOUR_IN_SECONDS) {
                return self::skip(self::R_CAP_GAP);
            }
        } else {
            if ($today_tier >= (int) $o['service_per_day']) {
                return self::skip(self::R_CAP_DAY);
            }
            if ($last_tier > 0 && $now - $last_tier < (int) $o['service_gap_h'] * HOUR_IN_SECONDS) {
                return self::skip(self::R_CAP_GAP);
            }
        }

        return self::send();
    }

    /* ══════════════════════════════════════════════════════════════
       WINDOWS
       ══════════════════════════════════════════════════════════════ */

    /**
     * Is [$now] inside a window this tier may not send in? Returns
     * [reason, resume_at] or null. Deferred sends land on the *edge* of the
     * window, never inside the next one — so a marketing push held overnight
     * arrives at 09:00, not at 08:00 with the service tier.
     *
     * A filter lets a later phase add the adhan pause and the Ramadan mode
     * without touching this file: return [reason, until] to hold.
     *
     * @return array{0:string,1:int}|null
     */
    public static function window_block(string $tier, int $now, array $o, array $msg = []): ?array
    {
        $tz = self::tz_of((string) $o['tz']);

        // 0. A calendar that replaces the defaults (Ramadan): ['allow'] means
        //    inside its window — send; [reason, until] means hold; null means
        //    the mode is off and the defaults below apply.
        $override = apply_filters('zooboxi_push_window_override', null, $tier, $now, $o, $msg);
        if (is_array($override) && $override) {
            if ($override[0] === 'allow') {
                return null;
            }
            if (count($override) === 2 && (int) $override[1] > $now) {
                return [(string) $override[0], (int) $override[1]];
            }
        }

        // 1. Quiet hours — everyone but transactional.
        $quiet = self::span_containing($now, (string) $o['quiet_start'], (string) $o['quiet_end'], $tz);
        if ($quiet !== null) {
            $until = $quiet[1];
            if ($tier === self::TIER_MARKETING) {
                // Marketing also has to wait for its own window to open.
                $until = max($until, self::next_open($until, (string) $o['marketing_start'], (string) $o['marketing_end'], $tz));
            }
            return [self::R_QUIET, $until];
        }

        if ($tier === self::TIER_MARKETING) {
            // 2. Outside the marketing window.
            $open = self::next_open($now, (string) $o['marketing_start'], (string) $o['marketing_end'], $tz);
            if ($open > $now) {
                return [self::R_WINDOW, $open];
            }
            // 3. Jumu'ah pause.
            $local = (new \DateTimeImmutable('@' . $now))->setTimezone($tz);
            if ((int) $local->format('N') === 5) {
                $pause = self::span_containing($now, (string) $o['friday_pause_start'], (string) $o['friday_pause_end'], $tz);
                if ($pause !== null) {
                    return [self::R_FRIDAY, $pause[1]];
                }
            }
        }

        // 4. Anything a later phase adds (adhan, Ramadan): [reason, until] or null.
        $extra = apply_filters('zooboxi_push_window_block', null, $tier, $now, $o, $msg);
        if (is_array($extra) && count($extra) === 2 && (int) $extra[1] > $now) {
            return [(string) $extra[0], (int) $extra[1]];
        }

        return null;
    }

    /**
     * If [$now] falls inside the daily span start→end (which may cross
     * midnight), returns [span_start, span_end] as unix; else null.
     *
     * @return array{0:int,1:int}|null
     */
    public static function span_containing(int $now, string $start, string $end, \DateTimeZone $tz): ?array
    {
        [$sh, $sm] = self::hm($start);
        [$eh, $em] = self::hm($end);
        $local = (new \DateTimeImmutable('@' . $now))->setTimezone($tz);
        $today = $local->setTime(0, 0, 0);

        $s = $today->setTime($sh, $sm)->getTimestamp();
        $e = $today->setTime($eh, $em)->getTimestamp();
        if ($e <= $s) {
            // Crosses midnight: the span is [s, e + 1 day) and also [s − 1 day, e).
            if ($now >= $s) {
                return [$s, $e + DAY_IN_SECONDS];
            }
            if ($now < $e) {
                return [$s - DAY_IN_SECONDS, $e];
            }
            return null;
        }
        return ($now >= $s && $now < $e) ? [$s, $e] : null;
    }

    /** The first instant ≥ [$from] that is inside the daily window start→end. */
    public static function next_open(int $from, string $start, string $end, \DateTimeZone $tz): int
    {
        if (self::span_containing($from, $start, $end, $tz) !== null) {
            return $from;
        }
        [$sh, $sm] = self::hm($start);
        $local = (new \DateTimeImmutable('@' . $from))->setTimezone($tz);
        $open  = $local->setTime($sh, $sm)->getTimestamp();
        if ($open < $from) {
            $open += DAY_IN_SECONDS;
        }
        return $open;
    }

    /** Midnight of [$now]'s local day. */
    public static function day_start(int $now, \DateTimeZone $tz): int
    {
        return (new \DateTimeImmutable('@' . $now))->setTimezone($tz)->setTime(0, 0, 0)->getTimestamp();
    }

    /** @return array{0:int,1:int} */
    private static function hm(string $value): array
    {
        if (!preg_match('/^(\d{1,2}):(\d{2})$/', trim($value), $m)) {
            return [0, 0];
        }
        return [max(0, min(23, (int) $m[1])), max(0, min(59, (int) $m[2]))];
    }

    private static function tz_of(string $name): \DateTimeZone
    {
        try {
            return new \DateTimeZone($name);
        } catch (\Throwable $e) {
            return new \DateTimeZone('Asia/Riyadh');
        }
    }

    private static function send(): array
    {
        return ['action' => 'send', 'reason' => '', 'not_before' => null];
    }

    private static function skip(string $reason): array
    {
        return ['action' => 'skip', 'reason' => $reason, 'not_before' => null];
    }

    private static function defer(string $reason, int $until): array
    {
        return ['action' => 'defer', 'reason' => $reason, 'not_before' => $until];
    }
}
