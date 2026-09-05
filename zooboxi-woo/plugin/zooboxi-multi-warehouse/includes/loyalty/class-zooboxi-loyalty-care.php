<?php
/**
 * Zooboxi_Loyalty_Care — «الرفيق»: the reasons to open the app without buying.
 *
 * Three tools, one thesis: the more the app knows about the animal, the better the
 * food gauge gets — and the customer gives that knowledge freely when it comes back
 * to them as care rather than as a form.
 *
 *   1. THE FEEDING PLAN. Resting energy (70 × kg^0.75) times a life-stage factor,
 *      nudged by neutering, activity and body condition, turned into grams of dry
 *      and wet food per day. The gauge (Zooboxi_Loyalty_Supply) reads these grams
 *      instead of its generic per-kilo table the moment a pet has a weight — so the
 *      forecast is the customer's animal, not "a cat".
 *   2. THE WEIGHT LOG. One row per pet per day. A profile edit writes one too, so
 *      the chart accumulates without anyone "keeping a log". A monthly mission pays
 *      for a fresh reading because a stale weight is a wrong plan.
 *   3. CARE REMINDERS. Vaccine, deworming, flea/tick, grooming, check-up — lazy rows
 *      ("not set" until the customer taps «تم» once), a suggested product where one
 *      exists, and dated nudges the app turns into local notifications.
 *
 * Nothing here diagnoses. The copy says "plan", "reminder", "trend" — never "healthy".
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Care
{
    public const KINDS = ['vaccine', 'deworm', 'flea_tick', 'grooming', 'checkup'];

    public const ACTIVITIES = ['', 'low', 'normal', 'high'];
    public const CONDITIONS = ['', 'under', 'ideal', 'over'];

    /** Default reminder intervals (days) by species; '*' is every other species. */
    public const DEFAULT_INTERVALS = [
        'cat' => ['vaccine' => 365, 'deworm' => 90, 'flea_tick' => 30, 'grooming' => 60, 'checkup' => 365],
        'dog' => ['vaccine' => 365, 'deworm' => 90, 'flea_tick' => 30, 'grooming' => 60, 'checkup' => 365],
        '*'   => ['checkup' => 365],
    ];

    /** kcal per 100 g, the typical complete foods this store sells. */
    public const DEFAULT_KCAL = [
        'cat' => ['dry' => 375, 'wet' => 90],
        'dog' => ['dry' => 360, 'wet' => 100],
    ];

    /** Title words that mark a product as the answer to a reminder kind (when nothing is pinned). */
    public const SEARCH = [
        'deworm'    => ['ديدان', 'الديدان'],
        'flea_tick' => ['براغيث', 'البراغيث', 'قراد', 'القراد', 'فيبروتيك', 'سبوت اون'],
        'grooming'  => ['شامبو'],
    ];

    public const MIN_INTERVAL = 7;
    public const MAX_INTERVAL = 730;

    /* ══════════════════════════════════════════════════════════════
       CONFIG
       ══════════════════════════════════════════════════════════════ */

    public static function enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('care_enabled') === 'yes';
    }

    /** Reminder intervals: owner JSON merged over the defaults. */
    public static function intervals(): array
    {
        $table = self::DEFAULT_INTERVALS;
        foreach (Zooboxi_Loyalty::opt_json('care_intervals', []) as $species => $kinds) {
            if (!is_array($kinds)) {
                continue;
            }
            foreach ($kinds as $kind => $days) {
                if (in_array($kind, self::KINDS, true) && (int) $days >= self::MIN_INTERVAL) {
                    $table[(string) $species][$kind] = min(self::MAX_INTERVAL, (int) $days);
                }
            }
        }
        return $table;
    }

    /** The reminder kinds that make sense for a species, in display order. */
    public static function kinds_for(string $species): array
    {
        $table = self::intervals();
        $row   = $table[$species] ?? $table['*'] ?? ['checkup' => 365];
        $out   = [];
        foreach (self::KINDS as $kind) {
            if (isset($row[$kind])) {
                $out[] = $kind;
            }
        }
        return $out;
    }

    public static function default_interval(string $species, string $kind): int
    {
        $table = self::intervals();
        return (int) ($table[$species][$kind] ?? $table['*'][$kind] ?? 90);
    }

    /** kcal per 100 g for a species × food kind, owner-overridable. */
    public static function kcal(string $species, string $kind): float
    {
        $table = Zooboxi_Loyalty::opt_json('care_kcal', []);
        $value = (float) ($table[$species][$kind] ?? self::DEFAULT_KCAL[$species][$kind] ?? 0);
        return $value > 0 ? $value : (float) (self::DEFAULT_KCAL[$species][$kind] ?? 350);
    }

    public static function kind_label(string $kind): string
    {
        switch ($kind) {
            case 'vaccine':
                return Zooboxi_Loyalty::pick('التطعيم', 'Vaccination');
            case 'deworm':
                return Zooboxi_Loyalty::pick('علاج الديدان', 'Deworming');
            case 'flea_tick':
                return Zooboxi_Loyalty::pick('البراغيث والقراد', 'Flea & tick');
            case 'grooming':
                return Zooboxi_Loyalty::pick('التنظيف والتجميل', 'Grooming');
            case 'checkup':
                return Zooboxi_Loyalty::pick('الفحص الدوري', 'Check-up');
        }
        return $kind;
    }

    /* ══════════════════════════════════════════════════════════════
       THE FEEDING PLAN
       ══════════════════════════════════════════════════════════════ */

    /** Whole months since a birth date, or null when unknown. */
    public static function age_months(?string $birth_date): ?int
    {
        $birth = (string) $birth_date;
        if ($birth === '' || $birth === '0000-00-00') {
            return null;
        }
        $ts = strtotime($birth . ' 00:00:00 UTC');
        if (!$ts || $ts > time()) {
            return null;
        }
        $diff = (new \DateTimeImmutable('@' . $ts))->diff(new \DateTimeImmutable('@' . time()));
        return (int) $diff->y * 12 + (int) $diff->m;
    }

    /**
     * The daily plan for one pet, or null when there is nothing honest to say (no
     * weight, or a species we have no table for).
     */
    public static function plan(array $pet): ?array
    {
        $species = (string) ($pet['species'] ?? '');
        if (!in_array($species, ['cat', 'dog'], true)) {
            return null;
        }
        $kg = (float) ($pet['weight_kg'] ?? 0);
        if ($kg <= 0) {
            return null;
        }

        $months   = self::age_months($pet['birth_date'] ?? null);
        $neutered = $pet['neutered'] === null || $pet['neutered'] === '' ? null : (int) $pet['neutered'];
        $activity = (string) ($pet['activity'] ?? '');
        $cond     = (string) ($pet['body_condition'] ?? '');
        $is_cat   = $species === 'cat';

        $rer = 70.0 * pow($kg, 0.75);

        if ($months !== null && $months < 4) {
            $stage  = $is_cat ? 'kitten' : 'puppy';
            $factor = $is_cat ? 2.5 : 3.0;
        } elseif ($months !== null && $months < 12) {
            $stage  = 'junior';
            $factor = 2.0;
        } elseif ($months !== null && $months >= ($is_cat ? 132 : 96)) {
            $stage  = 'senior';
            $factor = $is_cat ? 1.1 : 1.4;
        } else {
            $stage  = 'adult';
            $factor = $neutered === 0 ? ($is_cat ? 1.4 : 1.8) : ($is_cat ? 1.2 : 1.6);
        }

        $notes = [];
        if (in_array($stage, ['adult', 'senior'], true)) {
            if ($activity === 'high') {
                $factor += $is_cat ? 0.2 : 0.4;
            } elseif ($activity === 'low') {
                $factor -= $is_cat ? 0.1 : 0.2;
            }
            if ($cond === 'over') {
                $factor  = min($factor, 1.0);
                $notes[] = Zooboxi_Loyalty::pick(
                    'هذه كمية لخفض الوزن بلطف. إن لم يتغيّر الوزن خلال شهرين فاستشر الطبيب البيطري.',
                    'This amount is for gentle weight loss. If the weight has not moved in two months, ask your vet.'
                );
            } elseif ($cond === 'under') {
                $factor += 0.2;
            }
        } elseif ($stage === 'kitten' || $stage === 'puppy') {
            $notes[] = Zooboxi_Loyalty::pick('الصغار يأكلون هذه الكمية على 3–4 وجبات في اليوم.', 'Little ones eat this across 3–4 meals a day.');
        }
        $factor = max(0.8, min(3.0, $factor));

        $kcal     = (int) round($rer * $factor);
        $dry_kcal = !empty($pet['food_kcal']) && (int) $pet['food_kcal'] > 0 ? (float) $pet['food_kcal'] : self::kcal($species, 'dry');
        $wet_kcal = self::kcal($species, 'wet');

        $dry_g = self::round_to($kcal / $dry_kcal * 100, 5);
        $wet_g = self::round_to($kcal / $wet_kcal * 100, 10);

        $override = $pet['feed_g_day'] !== null && $pet['feed_g_day'] !== '' && (float) $pet['feed_g_day'] > 0
            ? round((float) $pet['feed_g_day'], 1)
            : null;

        return [
            'kcal_day'      => $kcal,
            'rer'           => (int) round($rer),
            'factor'        => round($factor, 2),
            'stage'         => $stage,
            'dry_g_day'     => $dry_g,
            'wet_g_day'     => $wet_g,
            'mixed'         => ['dry_g_day' => self::round_to($dry_g / 2, 5), 'wet_g_day' => self::round_to($wet_g / 2, 10)],
            'dry_kcal_100g' => (int) round($dry_kcal),
            'wet_kcal_100g' => (int) round($wet_kcal),
            'override_g_day' => $override,
            'effective_g_day' => $override ?? (float) $dry_g,
            'notes'         => $notes,
        ];
    }

    private static function round_to(float $value, int $step): float
    {
        return (float) (max($step, (int) round($value / $step) * $step));
    }

    /**
     * What the gauge should use: grams/day of this food kind for this pet — the
     * customer's own override for dry food, else the plan, else null (table prior).
     */
    public static function grams_per_day(array $pet, string $kind): ?float
    {
        if (!in_array($kind, ['dry', 'wet'], true)) {
            return null;
        }
        if ($kind === 'dry' && $pet['feed_g_day'] !== null && $pet['feed_g_day'] !== '' && (float) $pet['feed_g_day'] > 0) {
            return (float) $pet['feed_g_day'];
        }
        $plan = self::plan($pet);
        if ($plan === null) {
            return null;
        }
        return $kind === 'dry' ? (float) $plan['dry_g_day'] : (float) $plan['wet_g_day'];
    }

    /* ══════════════════════════════════════════════════════════════
       THE WEIGHT LOG
       ══════════════════════════════════════════════════════════════ */

    /** @return array<int,array> oldest first */
    public static function weights(int $pet_id, int $limit = 24): array
    {
        if ($pet_id <= 0) {
            return [];
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM (SELECT id, weight_kg, noted_on, source FROM ' . Zooboxi_Loyalty_Schema::pet_weights()
            . ' WHERE pet_id = %d ORDER BY noted_on DESC LIMIT %d) t ORDER BY noted_on ASC',
            $pet_id,
            max(1, $limit)
        ), ARRAY_A);
        return is_array($rows) ? $rows : [];
    }

    /** Validate a weight + date pair. @return array{kg:?float,on:?string,error:string} */
    private static function check_weight($kg_raw, $on_raw): array
    {
        $kg = (float) $kg_raw;
        if ($kg <= 0 || $kg > 200) {
            return ['kg' => null, 'on' => null, 'error' => 'weight'];
        }
        $on = trim((string) ($on_raw ?? ''));
        if ($on === '') {
            $on = gmdate('Y-m-d');
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $on) || !strtotime($on . ' 00:00:00 UTC')) {
            return ['kg' => null, 'on' => null, 'error' => 'date'];
        }
        $ts = strtotime($on . ' 00:00:00 UTC');
        if ($ts > time() + DAY_IN_SECONDS || $ts < strtotime('-5 years')) {
            return ['kg' => null, 'on' => null, 'error' => 'date'];
        }
        return ['kg' => round($kg, 2), 'on' => $on, 'error' => ''];
    }

    /**
     * Record a weight. Same pet + same day updates in place (never a duplicate row),
     * the pet's headline weight follows the newest date, and a customer-entered reading
     * moves the monthly weigh-in mission.
     *
     * @return array{ok:bool,code:string,paws:int}
     */
    public static function log_weight(int $user_id, int $pet_id, $kg_raw, $on_raw = null, string $source = 'log'): array
    {
        $pet = Zooboxi_Loyalty_Pets::find($pet_id, $user_id);
        if ($pet === null) {
            return ['ok' => false, 'code' => 'pet_not_found', 'paws' => 0];
        }
        $checked = self::check_weight($kg_raw, $on_raw);
        if ($checked['error'] !== '') {
            return ['ok' => false, 'code' => 'weight_invalid', 'paws' => 0];
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        global $wpdb;
        $table = Zooboxi_Loyalty_Schema::pet_weights();
        $now   = Zooboxi_Loyalty::now();
        // A customer reading always wins over the profile echo of the same day.
        $wpdb->query($wpdb->prepare(
            "INSERT INTO {$table} (user_id, pet_id, weight_kg, noted_on, source, created_at) VALUES (%d, %d, %f, %s, %s, %s)"
            . ' ON DUPLICATE KEY UPDATE weight_kg = VALUES(weight_kg), source = IF(source = %s, source, VALUES(source))',
            $user_id,
            $pet_id,
            $checked['kg'],
            $checked['on'],
            $source === 'profile' ? 'profile' : 'log',
            $now,
            'log'
        ));

        // The headline weight follows the newest reading only.
        $newest = (string) $wpdb->get_var($wpdb->prepare(
            "SELECT MAX(noted_on) FROM {$table} WHERE pet_id = %d",
            $pet_id
        ));
        if ($newest === '' || $newest === $checked['on']) {
            $wpdb->update(
                Zooboxi_Loyalty_Schema::pets(),
                ['weight_kg' => $checked['kg'], 'updated_at' => $now],
                ['id' => $pet_id, 'user_id' => $user_id],
                ['%f', '%s'],
                ['%d', '%d']
            );
        }
        Zooboxi_Loyalty_Pets::forget($user_id);

        $paws = 0;
        if ($source !== 'profile') {
            $before = Zooboxi_Loyalty_Ledger::balance($user_id);
            try {
                Zooboxi_Loyalty_Pets::maybe_award_profile($user_id);
                if (class_exists('Zooboxi_Loyalty_Missions')) {
                    Zooboxi_Loyalty_Missions::progress_profile($user_id);
                    Zooboxi_Loyalty_Missions::progress_kind($user_id, 'care');
                }
            } catch (\Throwable $e) {
                error_log('[Zooboxi Loyalty] weigh-in mission progress failed: ' . $e->getMessage());
            }
            $paws = max(0, Zooboxi_Loyalty_Ledger::balance($user_id) - $before);
        }

        if (class_exists('Zooboxi_Loyalty_Supply')) {
            Zooboxi_Loyalty_Supply::flush($user_id);
        }
        return ['ok' => true, 'code' => '', 'paws' => $paws];
    }

    /** The profile editor's echo: keeps the chart honest without paying twice. */
    public static function record_profile_weight(int $user_id, int $pet_id, float $kg): void
    {
        try {
            self::log_weight($user_id, $pet_id, $kg, null, 'profile');
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] profile weight echo failed: ' . $e->getMessage());
        }
    }

    public static function delete_weight(int $user_id, int $pet_id, int $weight_id): bool
    {
        if (Zooboxi_Loyalty_Pets::find($pet_id, $user_id) === null || $weight_id <= 0) {
            return false;
        }
        global $wpdb;
        $ok = (bool) $wpdb->delete(
            Zooboxi_Loyalty_Schema::pet_weights(),
            ['id' => $weight_id, 'pet_id' => $pet_id, 'user_id' => $user_id],
            ['%d', '%d', '%d']
        );
        if ($ok) {
            // The headline follows whatever is newest now. With nothing left the
            // profile keeps the weight it had — a deleted reading is not "no weight".
            $row = $wpdb->get_row($wpdb->prepare(
                'SELECT weight_kg FROM ' . Zooboxi_Loyalty_Schema::pet_weights() . ' WHERE pet_id = %d ORDER BY noted_on DESC LIMIT 1',
                $pet_id
            ), ARRAY_A);
            if (is_array($row)) {
                $wpdb->update(
                    Zooboxi_Loyalty_Schema::pets(),
                    ['weight_kg' => (float) $row['weight_kg'], 'updated_at' => Zooboxi_Loyalty::now()],
                    ['id' => $pet_id, 'user_id' => $user_id],
                    ['%f', '%s'],
                    ['%d', '%d']
                );
            }
            Zooboxi_Loyalty_Pets::forget($user_id);
            if (class_exists('Zooboxi_Loyalty_Supply')) {
                Zooboxi_Loyalty_Supply::flush($user_id);
            }
        }
        return $ok;
    }

    /** Has this customer logged (not echoed) a weight in the current month? */
    public static function logged_this_period(int $user_id): bool
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pet_weights()
            . " WHERE user_id = %d AND source = 'log' AND noted_on >= %s",
            $user_id,
            gmdate('Y-m-01')
        )) > 0;
    }

    /** The first cat or dog on file — the animals the plan and the weigh-in mission can serve. */
    public static function weighable_pet(int $user_id): ?array
    {
        foreach (Zooboxi_Loyalty_Pets::all($user_id) as $pet) {
            if (in_array((string) $pet['species'], ['cat', 'dog'], true)) {
                return $pet;
            }
        }
        return null;
    }

    /**
     * Latest reading against the newest one at least 60 days older (or the oldest
     * on file). ±10 % is flagged as a trend worth a sentence — never a diagnosis.
     */
    public static function trend(array $entries): ?array
    {
        $n = count($entries);
        if ($n < 2) {
            return null;
        }
        $latest    = $entries[$n - 1];
        $latest_ts = (int) strtotime((string) $latest['noted_on'] . ' 00:00:00 UTC');
        $base      = null;
        for ($i = $n - 2; $i >= 0; $i--) {
            $ts = (int) strtotime((string) $entries[$i]['noted_on'] . ' 00:00:00 UTC');
            if ($latest_ts - $ts >= 60 * DAY_IN_SECONDS) {
                $base = $entries[$i];
                break;
            }
        }
        if ($base === null) {
            $base = $entries[0];
        }
        $from  = (float) $base['weight_kg'];
        $to    = (float) $latest['weight_kg'];
        $delta = round($to - $from, 2);
        $pct   = $from > 0 ? round($delta / $from * 100, 1) : 0.0;
        $days  = (int) max(0, round(($latest_ts - (int) strtotime((string) $base['noted_on'] . ' 00:00:00 UTC')) / DAY_IN_SECONDS));

        return [
            'from_kg'   => $from,
            'to_kg'     => $to,
            'delta_kg'  => $delta,
            'delta_pct' => $pct,
            'days'      => $days,
            'direction' => abs($delta) < 0.05 ? 'flat' : ($delta > 0 ? 'up' : 'down'),
            'flag'      => $pct >= 10 ? 'gain' : ($pct <= -10 ? 'loss' : 'none'),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       CARE REMINDERS
       ══════════════════════════════════════════════════════════════ */

    /** Stored rows for one customer (optionally one pet), keyed "pet:kind". */
    public static function rows(int $user_id, int $pet_id = 0): array
    {
        if ($user_id <= 0) {
            return [];
        }
        global $wpdb;
        $sql  = 'SELECT * FROM ' . Zooboxi_Loyalty_Schema::pet_care() . ' WHERE user_id = %d';
        $args = [$user_id];
        if ($pet_id > 0) {
            $sql   .= ' AND pet_id = %d';
            $args[] = $pet_id;
        }
        $rows = $wpdb->get_results($wpdb->prepare($sql, $args), ARRAY_A);
        $out  = [];
        foreach ((array) $rows as $row) {
            $out[(int) $row['pet_id'] . ':' . (string) $row['kind']] = $row;
        }
        return $out;
    }

    /** @return array{state:string,days:?int} */
    public static function state_of(?array $row): array
    {
        if ($row === null || empty($row['next_on']) || $row['next_on'] === '0000-00-00') {
            return ['state' => 'unset', 'days' => null];
        }
        if ((int) $row['enabled'] !== 1) {
            return ['state' => 'off', 'days' => null];
        }
        $today = strtotime(gmdate('Y-m-d') . ' 00:00:00 UTC');
        $next  = strtotime((string) $row['next_on'] . ' 00:00:00 UTC');
        $days  = (int) round(($next - $today) / DAY_IN_SECONDS);
        if ($days > 7) {
            $state = 'ok';
        } elseif ($days > 0) {
            $state = 'soon';
        } elseif ($days === 0) {
            $state = 'due';
        } else {
            $state = 'overdue';
        }
        return ['state' => $state, 'days' => $days];
    }

    private static function check_date($raw, bool $allow_future): ?string
    {
        $on = trim((string) $raw);
        if ($on === '') {
            return null;
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $on)) {
            return null;
        }
        $ts = strtotime($on . ' 00:00:00 UTC');
        if (!$ts || $ts < strtotime('-10 years')) {
            return null;
        }
        if (!$allow_future && $ts > time() + DAY_IN_SECONDS) {
            return null;
        }
        if ($allow_future && $ts > strtotime('+3 years')) {
            return null;
        }
        return $on;
    }

    /**
     * Create or edit one reminder.
     *
     * @return array{ok:bool,code:string,errors:array<string,string>}
     */
    public static function set(int $user_id, int $pet_id, string $kind, array $input): array
    {
        $pet = Zooboxi_Loyalty_Pets::find($pet_id, $user_id);
        if ($pet === null) {
            return ['ok' => false, 'code' => 'pet_not_found', 'errors' => []];
        }
        if (!in_array($kind, self::kinds_for((string) $pet['species']), true)) {
            return ['ok' => false, 'code' => 'care_kind', 'errors' => []];
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        $existing = self::rows($user_id, $pet_id)[$pet_id . ':' . $kind] ?? null;
        $errors   = [];

        $interval = $existing ? (int) $existing['interval_days'] : self::default_interval((string) $pet['species'], $kind);
        if (array_key_exists('interval_days', $input) && $input['interval_days'] !== null && $input['interval_days'] !== '') {
            $interval = (int) $input['interval_days'];
            if ($interval < self::MIN_INTERVAL || $interval > self::MAX_INTERVAL) {
                $errors['interval_days'] = Zooboxi_Loyalty::pick('الفاصل بين 7 و730 يوماً', 'The interval must be 7–730 days.');
            }
        }

        $last = $existing['last_on'] ?? null;
        if (array_key_exists('last_on', $input)) {
            if ($input['last_on'] === null || $input['last_on'] === '') {
                $last = null;
            } else {
                $last = self::check_date($input['last_on'], false);
                if ($last === null) {
                    $errors['last_on'] = Zooboxi_Loyalty::pick('تاريخ غير صالح', 'Invalid date.');
                }
            }
        }

        $next = $existing['next_on'] ?? null;
        $next_sent = array_key_exists('next_on', $input) && $input['next_on'] !== null && $input['next_on'] !== '';
        if ($next_sent) {
            $next = self::check_date($input['next_on'], true);
            if ($next === null) {
                $errors['next_on'] = Zooboxi_Loyalty::pick('تاريخ غير صالح', 'Invalid date.');
            }
        } elseif (empty($errors) && $last !== null && (array_key_exists('last_on', $input) || array_key_exists('interval_days', $input))) {
            // A new "last done" or a new interval moves the next date with it.
            $next = gmdate('Y-m-d', strtotime($last . ' 00:00:00 UTC') + $interval * DAY_IN_SECONDS);
        }

        if (!empty($errors)) {
            return ['ok' => false, 'code' => 'care_invalid', 'errors' => $errors];
        }
        if ($next === null && $last === null && $existing === null) {
            return ['ok' => false, 'code' => 'care_invalid', 'errors' => ['next_on' => Zooboxi_Loyalty::pick('حدّد آخر مرة أو الموعد القادم', 'Set the last time or the next date.')]];
        }

        $enabled = $existing ? (int) $existing['enabled'] : 1;
        if (array_key_exists('enabled', $input) && $input['enabled'] !== null && $input['enabled'] !== '') {
            $enabled = wc_string_to_bool($input['enabled']) ? 1 : 0;
        }

        global $wpdb;
        $now  = Zooboxi_Loyalty::now();
        $data = [
            'interval_days' => $interval,
            'last_on'       => $last,
            'next_on'       => $next,
            'enabled'       => $enabled,
            'updated_at'    => $now,
        ];
        if ($existing) {
            $wpdb->update(Zooboxi_Loyalty_Schema::pet_care(), $data, ['id' => (int) $existing['id']]);
        } else {
            $wpdb->insert(Zooboxi_Loyalty_Schema::pet_care(), $data + [
                'user_id'    => $user_id,
                'pet_id'     => $pet_id,
                'kind'       => $kind,
                'done_count' => 0,
                'created_at' => $now,
            ]);
        }
        return ['ok' => true, 'code' => '', 'errors' => []];
    }

    /** «تم» — done today (or on a given past day); the next date follows the interval. */
    public static function done(int $user_id, int $pet_id, string $kind, $on_raw = null): array
    {
        $pet = Zooboxi_Loyalty_Pets::find($pet_id, $user_id);
        if ($pet === null) {
            return ['ok' => false, 'code' => 'pet_not_found', 'errors' => []];
        }
        if (!in_array($kind, self::kinds_for((string) $pet['species']), true)) {
            return ['ok' => false, 'code' => 'care_kind', 'errors' => []];
        }
        $on = $on_raw === null || $on_raw === '' ? gmdate('Y-m-d') : self::check_date($on_raw, false);
        if ($on === null) {
            return ['ok' => false, 'code' => 'care_invalid', 'errors' => ['on' => Zooboxi_Loyalty::pick('تاريخ غير صالح', 'Invalid date.')]];
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        $existing = self::rows($user_id, $pet_id)[$pet_id . ':' . $kind] ?? null;
        $interval = $existing ? (int) $existing['interval_days'] : self::default_interval((string) $pet['species'], $kind);
        $next     = gmdate('Y-m-d', strtotime($on . ' 00:00:00 UTC') + $interval * DAY_IN_SECONDS);

        global $wpdb;
        $now = Zooboxi_Loyalty::now();
        if ($existing) {
            $wpdb->query($wpdb->prepare(
                'UPDATE ' . Zooboxi_Loyalty_Schema::pet_care()
                . ' SET last_on = %s, next_on = %s, enabled = 1, done_count = done_count + 1, updated_at = %s WHERE id = %d',
                $on,
                $next,
                $now,
                (int) $existing['id']
            ));
        } else {
            $wpdb->insert(Zooboxi_Loyalty_Schema::pet_care(), [
                'user_id'       => $user_id,
                'pet_id'        => $pet_id,
                'kind'          => $kind,
                'interval_days' => $interval,
                'last_on'       => $on,
                'next_on'       => $next,
                'enabled'       => 1,
                'done_count'    => 1,
                'created_at'    => $now,
                'updated_at'    => $now,
            ]);
        }
        return ['ok' => true, 'code' => '', 'errors' => []];
    }

    /**
     * Up to three product cards for a reminder kind: the owner's pinned ids first,
     * else a title search filtered to the species. Cached half a day.
     */
    public static function products(string $kind, string $species, int $limit = 3): array
    {
        if (!class_exists('Zooboxi_Product_DTO')) {
            return [];
        }
        $pins = Zooboxi_Loyalty::opt_json('care_products', []);
        $ids  = array_values(array_filter(array_map('intval', (array) ($pins[$species][$kind] ?? []))));

        if (empty($ids)) {
            $words = self::SEARCH[$kind] ?? [];
            if (empty($words)) {
                return [];
            }
            $key    = 'zb_care_prod_' . $species . '_' . $kind;
            $cached = get_transient($key);
            if (is_array($cached) && ($cached['_v'] ?? 0) === 2) {
                $ids = $cached['ids'];
            } else {
                $ids = [];
                try {
                    // Title only — a description that merely mentions fleas is not a
                    // flea product (that is how a conditioner ended up in the list).
                    global $wpdb;
                    $like = [];
                    $args = [];
                    foreach ($words as $w) {
                        $like[] = 'post_title LIKE %s';
                        $args[] = '%' . $wpdb->esc_like($w) . '%';
                    }
                    $found = $wpdb->get_col($wpdb->prepare(
                        "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status = 'publish' AND (" . implode(' OR ', $like) . ') ORDER BY menu_order ASC, ID DESC LIMIT 40',
                        $args
                    ));
                    foreach ((array) $found as $pid) {
                        $pid = (int) $pid;
                        $title = (string) get_the_title($pid);
                        if (!self::title_fits_species($title, $species)) {
                            continue;
                        }
                        // A bed called «شامبورد» or a toy called «دودو» is not care.
                        if (preg_match('/سرير|لعبة|كوخ|حامل|صحن|وعاء/u', $title)) {
                            continue;
                        }
                        $for = class_exists('Zooboxi_Loyalty_Supply') ? Zooboxi_Loyalty_Supply::species_of_product($pid) : '';
                        if ($for !== '' && $for !== $species) {
                            continue;
                        }
                        $product = wc_get_product($pid);
                        if (!($product instanceof \WC_Product) || !$product->is_in_stock()) {
                            continue;
                        }
                        $ids[] = $pid;
                        if (count($ids) >= $limit * 2) {
                            break;
                        }
                    }
                } catch (\Throwable $e) {
                    $ids = [];
                }
                set_transient($key, ['_v' => 2, 'ids' => $ids], 12 * HOUR_IN_SECONDS);
            }
        }

        $cards = [];
        foreach ($ids as $pid) {
            $card = Zooboxi_Product_DTO::card($pid);
            if ($card !== null) {
                $cards[] = $card;
            }
            if (count($cards) >= $limit) {
                break;
            }
        }
        return $cards;
    }

    /** «للقطط» on a cat's list, «للكلاب» on a dog's; a title naming neither is allowed. */
    private static function title_fits_species(string $title, string $species): bool
    {
        $cat = mb_strpos($title, 'قط') !== false || stripos($title, 'cat') !== false;
        $dog = mb_strpos($title, 'كلاب') !== false || mb_strpos($title, 'كلب') !== false || stripos($title, 'dog') !== false;
        if ($species === 'cat') {
            return $cat || !$dog;
        }
        if ($species === 'dog') {
            return $dog || !$cat;
        }
        return !$cat && !$dog;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function reminder_dto(array $pet, string $kind, ?array $row, bool $with_products = false): array
    {
        $state = self::state_of($row);
        $due   = in_array($state['state'], ['soon', 'due', 'overdue'], true);
        return [
            'pet'           => ['id' => (int) $pet['id'], 'name' => (string) $pet['name'], 'species' => (string) $pet['species']],
            'kind'          => $kind,
            'label'         => self::kind_label($kind),
            'state'         => $state['state'],
            'days'          => $state['days'],
            'interval_days' => $row ? (int) $row['interval_days'] : self::default_interval((string) $pet['species'], $kind),
            'last_on'       => $row && !empty($row['last_on']) && $row['last_on'] !== '0000-00-00' ? (string) $row['last_on'] : null,
            'next_on'       => $row && !empty($row['next_on']) && $row['next_on'] !== '0000-00-00' ? (string) $row['next_on'] : null,
            'enabled'       => $row ? (int) $row['enabled'] === 1 : true,
            'done_count'    => $row ? (int) $row['done_count'] : 0,
            'products'      => $with_products && ($due || $state['state'] === 'unset') ? self::products($kind, (string) $pet['species']) : [],
        ];
    }

    /** Every reminder kind for one pet, stored or not. */
    public static function reminders(int $user_id, array $pet, bool $with_products = false): array
    {
        $rows = self::rows($user_id, (int) $pet['id']);
        $out  = [];
        foreach (self::kinds_for((string) $pet['species']) as $kind) {
            $out[] = self::reminder_dto($pet, $kind, $rows[(int) $pet['id'] . ':' . $kind] ?? null, $with_products);
        }
        return $out;
    }

    /** The `/pets/{id}/care` payload. */
    public static function payload(int $user_id, array $pet): array
    {
        $entries = self::weights((int) $pet['id']);
        $list    = [];
        foreach ($entries as $row) {
            $list[] = [
                'id'     => (int) $row['id'],
                'kg'     => (float) $row['weight_kg'],
                'on'     => (string) $row['noted_on'],
                'source' => (string) $row['source'],
            ];
        }

        $supply = [];
        try {
            if (class_exists('Zooboxi_Loyalty_Supply') && Zooboxi_Loyalty_Supply::enabled()) {
                $rows = array_values(array_filter(
                    Zooboxi_Loyalty_Supply::items($user_id),
                    static fn ($r) => (int) ($r['pet_id'] ?? 0) === (int) $pet['id']
                ));
                $supply = Zooboxi_Loyalty_Supply::dtos(array_slice($rows, 0, 4), $user_id);
            }
        } catch (\Throwable $e) {
            $supply = [];
        }

        return [
            'pet'       => Zooboxi_Loyalty_Pets::dto($pet),
            'plan'      => self::plan($pet),
            'weight'    => [
                'latest_kg' => $pet['weight_kg'] === null ? null : (float) $pet['weight_kg'],
                'entries'   => $list,
                'trend'     => self::trend($entries),
            ],
            'reminders' => self::reminders($user_id, $pet, true),
            'supply'    => $supply,
            'kinds'     => self::kinds_for((string) $pet['species']),
        ];
    }

    /** The summary block: the nearest reminders across the family, plus the weigh-in flag. */
    public static function summary_block(int $user_id, array $missions = []): array
    {
        $due = [];
        if (self::enabled()) {
            $rows = self::rows($user_id);
            foreach (Zooboxi_Loyalty_Pets::all($user_id) as $pet) {
                foreach (self::kinds_for((string) $pet['species']) as $kind) {
                    $row = $rows[(int) $pet['id'] . ':' . $kind] ?? null;
                    if ($row === null) {
                        continue;
                    }
                    $state = self::state_of($row);
                    if (in_array($state['state'], ['soon', 'due', 'overdue'], true)) {
                        $due[] = self::reminder_dto($pet, $kind, $row, false);
                    }
                }
            }
            usort($due, static fn ($a, $b) => ($a['days'] ?? 0) <=> ($b['days'] ?? 0));
        }

        $weigh_in = false;
        foreach ($missions as $m) {
            if ((string) ($m['kind'] ?? '') === 'care' && (string) ($m['state'] ?? '') === 'active') {
                $weigh_in = true;
                break;
            }
        }

        return [
            'enabled'   => self::enabled(),
            'due'       => array_slice($due, 0, 3),
            'due_count' => count($due),
            'weigh_in'  => $weigh_in,
        ];
    }

    /** Dated nudges: three days before each reminder and on the day itself. */
    public static function nudges(int $user_id): array
    {
        if (!self::enabled()) {
            return [];
        }
        $out   = [];
        $now   = time();
        $ahead = max(0, Zooboxi_Loyalty::opt_int('care_ahead_days', 3));
        $rows  = self::rows($user_id);
        $pets  = [];
        foreach (Zooboxi_Loyalty_Pets::all($user_id) as $pet) {
            $pets[(int) $pet['id']] = $pet;
        }

        foreach ($rows as $row) {
            $pet = $pets[(int) $row['pet_id']] ?? null;
            if ($pet === null || (int) $row['enabled'] !== 1 || empty($row['next_on']) || $row['next_on'] === '0000-00-00') {
                continue;
            }
            $kind  = (string) $row['kind'];
            $label = self::kind_label($kind);
            $name  = (string) $pet['name'];
            $at    = (int) strtotime((string) $row['next_on'] . ' 09:00:00 UTC');
            $state = self::state_of($row);
            $route = '/pets/' . (int) $pet['id'];
            $body  = isset(self::SEARCH[$kind])
                ? Zooboxi_Loyalty::pick('اضغط «تم» عند إنجازه، وستجد المنتج المناسب في ملفه.', 'Tap "Done" once it is handled — the right product is in their profile.')
                : Zooboxi_Loyalty::pick('اضغط «تم» عند إنجازه وسنذكّرك في الموعد القادم.', 'Tap "Done" once it is handled and we will remind you next time.');

            if ($state['state'] === 'ok' || $state['state'] === 'soon') {
                $before = $at - $ahead * DAY_IN_SECONDS;
                if ($ahead > 0 && $before > $now) {
                    $out[] = [
                        'kind'   => 'care',
                        'title'  => sprintf(Zooboxi_Loyalty::pick('%s: موعد %s بعد %d أيام', '%s: %s in %d days'), $name, $label, $ahead),
                        'body'   => $body,
                        'at'     => gmdate('Y-m-d\TH:i:s\Z', $before),
                        'route'  => $route,
                        'pet_id' => (int) $pet['id'],
                        'care'   => $kind,
                    ];
                }
                if ($at > $now) {
                    $out[] = [
                        'kind'   => 'care',
                        'title'  => sprintf(Zooboxi_Loyalty::pick('اليوم موعد %s %s', 'Today: %2$s\'s %1$s'), $label, $name),
                        'body'   => $body,
                        'at'     => gmdate('Y-m-d\TH:i:s\Z', $at),
                        'route'  => $route,
                        'pet_id' => (int) $pet['id'],
                        'care'   => $kind,
                    ];
                }
            } else {
                $out[] = [
                    'kind'   => 'care',
                    'title'  => $state['state'] === 'due'
                        ? sprintf(Zooboxi_Loyalty::pick('اليوم موعد %s %s', 'Today: %2$s\'s %1$s'), $label, $name)
                        : sprintf(Zooboxi_Loyalty::pick('تأخّر موعد %s %s', '%2$s\'s %1$s is overdue'), $label, $name),
                    'body'   => $body,
                    'at'     => gmdate('Y-m-d\TH:i:s\Z', min($now, $at)),
                    'route'  => $route,
                    'pet_id' => (int) $pet['id'],
                    'care'   => $kind,
                ];
            }
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       METRICS
       ══════════════════════════════════════════════════════════════ */

    public static function metrics(string $month_start, string $next_month): array
    {
        global $wpdb;
        $out = ['weights_logged' => 0, 'pets_with_plan' => 0, 'reminders_set' => 0, 'reminders_done' => 0, 'reminders_due' => 0];
        if (!Zooboxi_Loyalty_Schema::table_exists(Zooboxi_Loyalty_Schema::pet_care())) {
            return $out;
        }
        $out['weights_logged'] = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pet_weights() . " WHERE source = 'log' AND created_at >= %s AND created_at < %s",
            $month_start,
            $next_month
        ));
        $out['pets_with_plan'] = (int) $wpdb->get_var(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pets() . " WHERE deleted_at IS NULL AND weight_kg > 0 AND species IN ('cat','dog')"
        );
        $out['reminders_set']  = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pet_care() . ' WHERE enabled = 1 AND next_on IS NOT NULL');
        $out['reminders_done'] = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pet_care() . ' WHERE last_on >= %s AND last_on < %s',
            substr($month_start, 0, 10),
            substr($next_month, 0, 10)
        ));
        $out['reminders_due'] = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::pet_care() . ' WHERE enabled = 1 AND next_on IS NOT NULL AND next_on <= %s',
            gmdate('Y-m-d', time() + 7 * DAY_IN_SECONDS)
        ));
        return $out;
    }
}
