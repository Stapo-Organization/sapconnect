<?php
/**
 * Campaigns — the one way a person at the store sends a push by hand.
 *
 * Not a broadcast button. A campaign names its audience (species, city,
 * how recently they ordered, tier), is written in both languages, is
 * previewed on the owner's own phone (the canary), may be dry-run, and
 * must be approved before it goes out — and then it goes out as ordinary
 * marketing rows, through the same gate as everything else: quiet hours,
 * caps, the holdout, the person's own hour.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Campaigns
{
    const S_DRAFT     = 'draft';
    const S_APPROVED  = 'approved';
    const S_SENT      = 'sent';
    const S_CANCELLED = 'cancelled';

    /** Audiences past this size need a second look; past the hard cap they wait. */
    const WARN_AUDIENCE = 2000;
    const MAX_AUDIENCE  = 5000;

    public static function table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zooboxi_push_campaigns';
    }

    public static function install(string $collate): string
    {
        return 'CREATE TABLE ' . self::table() . " (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(120) NOT NULL DEFAULT '',
            status VARCHAR(12) NOT NULL DEFAULT 'draft',
            audience LONGTEXT NULL,
            title_ar TEXT NULL,
            body_ar TEXT NULL,
            title_en TEXT NULL,
            body_en TEXT NULL,
            route VARCHAR(191) NOT NULL DEFAULT '/home',
            image_url VARCHAR(255) NOT NULL DEFAULT '',
            topic VARCHAR(16) NOT NULL DEFAULT 'offers',
            schedule_at DATETIME NULL,
            sto TINYINT(1) NOT NULL DEFAULT 1,
            dry_run TINYINT(1) NOT NULL DEFAULT 0,
            audience_count INT UNSIGNED NOT NULL DEFAULT 0,
            queued INT UNSIGNED NOT NULL DEFAULT 0,
            approved_by VARCHAR(60) NOT NULL DEFAULT '',
            approved_at DATETIME NULL,
            created_by VARCHAR(60) NOT NULL DEFAULT '',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            sent_at DATETIME NULL,
            PRIMARY KEY  (id),
            KEY status (status)
        ) {$collate};";
    }

    public static function get(int $id): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table() . ' WHERE id = %d', $id), ARRAY_A);
        if ($row) {
            $row['audience'] = json_decode((string) $row['audience'], true) ?: [];
        }
        return $row ?: null;
    }

    public static function recent(int $limit = 30): array
    {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . self::table() . ' ORDER BY id DESC LIMIT %d', $limit), ARRAY_A) ?: [];
        foreach ($rows as &$r) {
            $r['audience'] = json_decode((string) $r['audience'], true) ?: [];
        }
        return $rows;
    }

    /** Create or update a draft from the composer form. */
    public static function save(array $in, int $id = 0): int
    {
        global $wpdb;
        $audience = [
            'species'         => array_values(array_filter(array_map('sanitize_key', (array) ($in['species'] ?? [])))),
            'cities'          => array_values(array_filter(array_map('sanitize_text_field', (array) ($in['cities'] ?? [])))),
            'last_order_days' => max(0, (int) ($in['last_order_days'] ?? 0)),
            'tiers'           => array_values(array_filter(array_map('sanitize_key', (array) ($in['tiers'] ?? [])))),
            'guests'          => !empty($in['guests']),
        ];
        $row = [
            'name'        => sanitize_text_field((string) ($in['name'] ?? '')),
            'audience'    => wp_json_encode($audience),
            'title_ar'    => sanitize_text_field((string) ($in['title_ar'] ?? '')),
            'body_ar'     => sanitize_textarea_field((string) ($in['body_ar'] ?? '')),
            'title_en'    => sanitize_text_field((string) ($in['title_en'] ?? '')),
            'body_en'     => sanitize_textarea_field((string) ($in['body_en'] ?? '')),
            'route'       => '/' . ltrim(sanitize_text_field((string) ($in['route'] ?? '/home')), '/'),
            'image_url'   => esc_url_raw((string) ($in['image_url'] ?? '')),
            'topic'       => in_array((string) ($in['topic'] ?? ''), Zooboxi_Push::TOPICS, true) ? (string) $in['topic'] : 'offers',
            'schedule_at' => self::local_to_utc((string) ($in['schedule_at'] ?? '')),
            'sto'         => !empty($in['sto']) ? 1 : 0,
            'dry_run'     => !empty($in['dry_run']) ? 1 : 0,
        ];
        if ($id > 0) {
            $existing = self::get($id);
            if ($existing === null || $existing['status'] !== self::S_DRAFT) {
                return $id;
            }
            $wpdb->update(self::table(), $row, ['id' => $id]);
        } else {
            $row['status']     = self::S_DRAFT;
            $row['created_by'] = wp_get_current_user()->user_login ?? '';
            $row['created_at'] = gmdate('Y-m-d H:i:s');
            $wpdb->insert(self::table(), $row);
            $id = (int) $wpdb->insert_id;
        }
        $wpdb->update(self::table(), ['audience_count' => count(self::audience($audience))], ['id' => $id]);
        return $id;
    }

    private static function local_to_utc(string $local): ?string
    {
        $local = trim($local);
        if ($local === '') {
            return null;
        }
        try {
            $dt = new \DateTimeImmutable($local, Zooboxi_Push_Gate::tz());
            return gmdate('Y-m-d H:i:s', $dt->getTimestamp());
        } catch (\Throwable $e) {
            return null;
        }
    }

    /* ══════════════════════════════════════════════════════════════
       AUDIENCE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Who this campaign reaches: [{user_id, guest_id}], deduplicated per
     * person. Filters narrow; an empty filter means "everyone with the app".
     */
    public static function audience(array $a): array
    {
        global $wpdb;
        $species = (array) ($a['species'] ?? []);
        $cities  = (array) ($a['cities'] ?? []);
        $days    = (int) ($a['last_order_days'] ?? 0);
        $tiers   = (array) ($a['tiers'] ?? []);
        $guests  = !empty($a['guests']) && !$species && !$tiers && !$days && !$cities;

        $sql = 'SELECT DISTINCT user_id, guest_id FROM ' . Zooboxi_Push::table() . ' WHERE enabled = 1';
        $sql .= $guests ? '' : ' AND user_id > 0';
        $rows = $wpdb->get_results($sql, ARRAY_A) ?: [];

        $people = [];
        foreach ($rows as $r) {
            $uid = (int) $r['user_id'];
            $key = $uid > 0 ? 'u' . $uid : 'g' . $r['guest_id'];
            if (isset($people[$key])) {
                continue;
            }
            if ($uid > 0) {
                if ($species && class_exists('Zooboxi_Loyalty_Pets') && !array_intersect($species, Zooboxi_Loyalty_Pets::species_of($uid))) {
                    continue;
                }
                if ($tiers && class_exists('Zooboxi_Loyalty_Members') && !in_array(Zooboxi_Loyalty_Members::tier_key($uid), $tiers, true)) {
                    continue;
                }
                if ($days > 0 && !Zooboxi_Push_Journeys::ordered_since($uid, time() - $days * DAY_IN_SECONDS)) {
                    continue;
                }
                if ($cities) {
                    $city = (string) get_user_meta($uid, 'billing_city', true);
                    $hit  = false;
                    foreach ($cities as $c) {
                        if ($c !== '' && mb_stripos($city, $c) !== false) {
                            $hit = true;
                            break;
                        }
                    }
                    if (!$hit) {
                        continue;
                    }
                }
            }
            $people[$key] = ['user_id' => $uid, 'guest_id' => $uid > 0 ? '' : (string) $r['guest_id']];
        }
        return array_values($people);
    }

    /* ══════════════════════════════════════════════════════════════
       CANARY, APPROVE, SEND
       ══════════════════════════════════════════════════════════════ */

    /** One copy to one chosen device, bypassing nothing but the audience. */
    public static function canary(int $id, int $device_id): bool
    {
        $c = self::get($id);
        global $wpdb;
        $device = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . Zooboxi_Push::table() . ' WHERE id = %d', $device_id), ARRAY_A);
        if ($c === null || !$device) {
            return false;
        }
        $en = str_starts_with((string) ($device['locale'] ?? 'ar'), 'en');
        return Zooboxi_Push::send_raw(
            (string) $device['token'],
            (string) ($en && $c['title_en'] !== '' ? $c['title_en'] : $c['title_ar']),
            (string) ($en && $c['body_en'] !== '' ? $c['body_en'] : $c['body_ar']),
            (string) $c['route'],
            ['topic' => (string) $c['topic'], 'campaign' => (string) $id, 'msg' => '0'],
            ['collapse_key' => 'campaign-' . $id, 'thread_id' => 'offers', 'image' => (string) $c['image_url']]
        );
    }

    public static function approve(int $id): array
    {
        $c = self::get($id);
        if ($c === null || $c['status'] !== self::S_DRAFT) {
            return ['ok' => false, 'message' => 'الحملة ليست مسودة.'];
        }
        if (trim((string) $c['title_ar']) === '' && trim((string) $c['body_ar']) === '') {
            return ['ok' => false, 'message' => 'اكتب النص العربي أولًا.'];
        }
        $people = self::audience($c['audience']);
        if (count($people) > self::MAX_AUDIENCE && !$c['dry_run']) {
            return ['ok' => false, 'message' => 'الجمهور أكبر من ' . self::MAX_AUDIENCE . ' — ضيّقه أو جزّئه.'];
        }
        global $wpdb;
        $wpdb->update(self::table(), [
            'status'      => self::S_APPROVED,
            'approved_by' => wp_get_current_user()->user_login ?? '',
            'approved_at' => gmdate('Y-m-d H:i:s'),
            'audience_count' => count($people),
        ], ['id' => $id]);
        return self::dispatch($id);
    }

    /** Queue one marketing row per person. Dry run writes rows that never send. */
    public static function dispatch(int $id): array
    {
        $c = self::get($id);
        if ($c === null || $c['status'] !== self::S_APPROVED) {
            return ['ok' => false, 'message' => 'الحملة غير معتمدة.'];
        }
        $people = self::audience($c['audience']);
        $queued = 0;
        $when   = Zooboxi_Push_Engine::ts($c['schedule_at']);
        foreach ($people as $p) {
            $r = Zooboxi_Push_Engine::submit([
                'user_id'      => (int) $p['user_id'],
                'guest_id'     => (string) $p['guest_id'],
                'topic'        => (string) $c['topic'],
                'tier'         => Zooboxi_Push_Gate::TIER_MARKETING,
                'copy'         => ['ar' => [$c['title_ar'], $c['body_ar']], 'en' => [$c['title_en'] ?: $c['title_ar'], $c['body_en'] ?: $c['body_ar']]],
                'route'        => (string) $c['route'],
                'data'         => ['campaign' => (string) $id],
                'image'        => (string) $c['image_url'],
                'collapse_key' => 'campaign-' . $id,
                'thread_id'    => 'offers',
                'level'        => 'passive',
                'relevance'    => 0.5,
                'source'       => 'campaign',
                'source_id'    => (string) $id,
                'key'          => 'campaign:' . $id . ':' . ($p['user_id'] > 0 ? 'u' . $p['user_id'] : 'g' . $p['guest_id']),
                'not_before'   => $when > time() ? $when : 0,
                'sto'          => !empty($c['sto']) && $when <= time(),
                'expires_at'   => ($when > time() ? $when : time()) + 2 * DAY_IN_SECONDS,
                'dry_run'      => !empty($c['dry_run']),
            ]);
            if ($r['id'] > 0 && $r['status'] !== 'duplicate') {
                $queued++;
            }
        }
        global $wpdb;
        $wpdb->update(self::table(), ['status' => self::S_SENT, 'queued' => $queued, 'sent_at' => gmdate('Y-m-d H:i:s')], ['id' => $id]);
        return ['ok' => true, 'message' => sprintf('%d في الطابور%s.', $queued, !empty($c['dry_run']) ? ' (تجربة جافة — لن يُرسَل شيء)' : '')];
    }

    public static function cancel(int $id): void
    {
        global $wpdb;
        $wpdb->update(self::table(), ['status' => self::S_CANCELLED], ['id' => $id]);
        $wpdb->query($wpdb->prepare(
            'UPDATE ' . Zooboxi_Push_Engine::outbox() . " SET status = %s, reason = 'campaign_cancelled' WHERE source = 'campaign' AND source_id = %s AND status = %s",
            Zooboxi_Push_Engine::S_CANCELLED, (string) $id, Zooboxi_Push_Engine::S_PENDING
        ));
    }
}
