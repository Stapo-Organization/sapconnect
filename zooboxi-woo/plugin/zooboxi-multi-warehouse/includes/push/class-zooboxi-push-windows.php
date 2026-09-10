<?php
/**
 * The Saudi calendar on top of the gate: Ramadan, and the adhan.
 *
 * Ramadan turns the day around — 48% of people are most active after
 * iftar, 38% after taraweeh, 24% before suhoor (YouGov/Adjust) — so while
 * the mode is on, marketing moves to 21:00–00:30 and the only thing allowed
 * in the small hours is the food-running-out reminder for express customers,
 * in a suhoor slot. The rest of the day is quiet.
 *
 * The adhan pause is a courtesy, not a law: marketing holds for ten minutes
 * either side of each prayer. Times come from AlAdhan (Umm al-Qura method)
 * once a day and are cached; if the lookup fails there is simply no pause.
 *
 * Both plug into the gate through filters, so the gate's own rules stay
 * pure and testable.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Windows
{
    public static function boot(): void
    {
        add_filter('zooboxi_push_window_override', [self::class, 'ramadan'], 10, 5);
        add_filter('zooboxi_push_window_block', [self::class, 'adhan'], 10, 5);
    }

    public static function defaults(): array
    {
        return [
            'ramadan_from'      => '',       // Y-m-d, empty = off
            'ramadan_to'        => '',
            'ramadan_start'     => '21:00',  // marketing window in Ramadan
            'ramadan_end'       => '00:30',
            'suhoor_start'      => '02:00',  // express replenishment only
            'suhoor_end'        => '03:30',
            'adhan'             => 'yes',
            'adhan_minutes'     => 10,
            'adhan_lat'         => '24.7136',
            'adhan_lng'         => '46.6753',
        ];
    }

    public static function opt(string $key)
    {
        $d = self::defaults();
        $v = get_option('zooboxi_push_' . $key, null);
        if ($v === null || $v === '') {
            return $d[$key] ?? null;
        }
        return is_int($d[$key] ?? null) ? (int) $v : (string) $v;
    }

    /** Is [$now] inside the configured Ramadan range (local calendar)? */
    public static function is_ramadan(int $now): bool
    {
        $from = (string) self::opt('ramadan_from');
        $to   = (string) self::opt('ramadan_to');
        if ($from === '' || $to === '') {
            return false;
        }
        $day = (new \DateTimeImmutable('@' . $now))->setTimezone(Zooboxi_Push_Gate::tz())->format('Y-m-d');
        return $day >= $from && $day <= $to;
    }

    /**
     * Ramadan override for the gate: null when the mode is off; ['allow']
     * inside a Ramadan window; [reason, until] otherwise.
     */
    public static function ramadan($override, string $tier, int $now, array $o, array $msg = [])
    {
        if ($override !== null || $tier === Zooboxi_Push_Gate::TIER_TRANSACTIONAL || !self::is_ramadan($now)) {
            return $override;
        }
        $tz = Zooboxi_Push_Gate::tz();
        $m_start = (string) self::opt('ramadan_start');
        $m_end   = (string) self::opt('ramadan_end');

        if ($tier === Zooboxi_Push_Gate::TIER_SERVICE) {
            // Service messages keep the default quiet hours but are also
            // allowed in the evening window that crosses midnight.
            if (Zooboxi_Push_Gate::span_containing($now, $m_start, $m_end, $tz) !== null) {
                return ['allow'];
            }
            return null;
        }

        // Marketing: the evening window…
        if (Zooboxi_Push_Gate::span_containing($now, $m_start, $m_end, $tz) !== null) {
            return ['allow'];
        }
        // …or, for the food reminder of an express customer, the suhoor slot.
        $suhoor_ok = (string) ($msg['source'] ?? '') === 'reorder' && !empty($msg['express']);
        $s_start = (string) self::opt('suhoor_start');
        $s_end   = (string) self::opt('suhoor_end');
        if ($suhoor_ok && Zooboxi_Push_Gate::span_containing($now, $s_start, $s_end, $tz) !== null) {
            return ['allow'];
        }
        $next = Zooboxi_Push_Gate::next_open($now, $m_start, $m_end, $tz);
        if ($suhoor_ok) {
            $next = min($next, Zooboxi_Push_Gate::next_open($now, $s_start, $s_end, $tz));
        }
        return ['ramadan', $next];
    }

    /** The adhan pause: marketing holds ±N minutes around each prayer. */
    public static function adhan($block, string $tier, int $now, array $o, array $msg = [])
    {
        if ($block !== null || $tier !== Zooboxi_Push_Gate::TIER_MARKETING || self::opt('adhan') !== 'yes') {
            return $block;
        }
        $pad   = max(0, (int) self::opt('adhan_minutes')) * MINUTE_IN_SECONDS;
        $times = self::prayer_times($now);
        foreach ($times as $name => $ts) {
            if ($now >= $ts - $pad && $now < $ts + $pad) {
                return ['adhan_' . $name, $ts + $pad];
            }
        }
        return $block;
    }

    /**
     * Today's five prayers as unix timestamps, from AlAdhan, cached until
     * midnight. An empty array when the lookup failed (cached an hour so a
     * dead API is not asked five times a minute).
     *
     * @return array<string,int>
     */
    public static function prayer_times(int $now): array
    {
        $tz    = Zooboxi_Push_Gate::tz();
        $local = (new \DateTimeImmutable('@' . $now))->setTimezone($tz);
        $key   = 'zooboxi_push_adhan_' . $local->format('Y-m-d');
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }

        $url = sprintf(
            'https://api.aladhan.com/v1/timings/%s?latitude=%s&longitude=%s&method=4',
            $local->format('d-m-Y'),
            rawurlencode((string) self::opt('adhan_lat')),
            rawurlencode((string) self::opt('adhan_lng'))
        );
        $response = wp_remote_get($url, ['timeout' => 6]);
        $times    = [];
        if (!is_wp_error($response) && (int) wp_remote_retrieve_response_code($response) === 200) {
            $body = json_decode((string) wp_remote_retrieve_body($response), true);
            $t    = $body['data']['timings'] ?? [];
            foreach (['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'] as $name) {
                $hm = (string) ($t[$name] ?? '');
                if (preg_match('/^(\d{1,2}):(\d{2})/', $hm, $m)) {
                    $times[strtolower($name)] = $local->setTime((int) $m[1], (int) $m[2])->getTimestamp();
                }
            }
        }
        $until_midnight = $local->setTime(23, 59, 59)->getTimestamp() - $now;
        set_transient($key, $times, $times ? max(60, $until_midnight) : HOUR_IN_SECONDS);
        return $times;
    }
}
