<?php
/**
 * Zooboxi_Loyalty_Pets — «عائلتي»: the pet profiles the whole program hangs on.
 *
 * WHY IT EARNS PAWS: a pet with a weight and a birth date is the difference between
 * guessing what a customer needs and knowing it. Phase 1 pays 50 paws per pet and a
 * one-off 100 for the first COMPLETE profile — the only paws in the program that are
 * bought with data rather than with money.
 *
 * Deletion is soft (`deleted_at`): the paws already paid for a pet must stay explicable
 * in the ledger, and a customer who removes a pet must not be able to re-add it for
 * another 50 (the ledger's UNIQUE key on `pet:{id}` guarantees that).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Pets
{
    public const SPECIES = ['cat', 'dog', 'bird', 'fish', 'small', 'reptile', 'other'];
    public const SEXES   = ['m', 'f', ''];

    /** Per-request memo: user_id => live pet rows (the summary reads pets ~5 times). */
    private static array $memo = [];

    public static function forget(int $user_id): void
    {
        unset(self::$memo[$user_id]);
    }

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    /** Every live pet of a customer, oldest first (the order they were added). */
    public static function all(int $user_id): array
    {
        if ($user_id <= 0) {
            return [];
        }
        if (isset(self::$memo[$user_id])) {
            return self::$memo[$user_id];
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::pets()
            . ' WHERE user_id = %d AND deleted_at IS NULL ORDER BY id ASC',
            $user_id
        ), ARRAY_A);

        return self::$memo[$user_id] = (is_array($rows) ? $rows : []);
    }

    public static function find(int $pet_id, int $user_id): ?array
    {
        if ($pet_id <= 0 || $user_id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::pets()
            . ' WHERE id = %d AND user_id = %d AND deleted_at IS NULL LIMIT 1',
            $pet_id,
            $user_id
        ), ARRAY_A);

        return is_array($row) ? $row : null;
    }

    public static function count(int $user_id): int
    {
        return count(self::all($user_id));
    }

    public static function max(): int
    {
        return max(1, Zooboxi_Loyalty::opt_int('max_pets'));
    }

    /** The first pet's name, or a friendly stand-in for mission copy. */
    public static function first_name(int $user_id, string $lang_ar = 'صديقك', string $lang_en = 'your pet'): string
    {
        $pets = self::all($user_id);
        foreach ($pets as $pet) {
            $name = trim((string) $pet['name']);
            if ($name !== '') {
                return $name;
            }
        }
        return Zooboxi_Loyalty::pick($lang_ar, $lang_en);
    }

    /** Species keys the customer actually owns (drives the category mission). */
    public static function species_of(int $user_id): array
    {
        $out = [];
        foreach (self::all($user_id) as $pet) {
            $out[(string) $pet['species']] = true;
        }
        return array_keys($out);
    }

    /* ══════════════════════════════════════════════════════════════
       VALIDATE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Normalise and validate an incoming pet body.
     *
     * @param array $input  raw request params
     * @param bool  $partial PATCH semantics — only validate the keys that were sent
     * @return array{data:array,formats:array,errors:array<string,string>}
     */
    public static function validate(array $input, bool $partial = false): array
    {
        $data    = [];
        $formats = [];
        $errors  = [];

        $has = static fn (string $k) => array_key_exists($k, $input) && $input[$k] !== null;

        // ── name (required on create) ──
        if ($has('name') || !$partial) {
            $name = trim(wp_strip_all_tags((string) ($input['name'] ?? '')));
            $name = mb_substr($name, 0, 60);
            if ($name === '') {
                $errors['name'] = Zooboxi_Loyalty::pick('اسم الحيوان مطلوب', 'A pet name is required.');
            } else {
                $data['name'] = $name;
                $formats[]    = '%s';
            }
        }

        // ── species (required on create) ──
        if ($has('species') || !$partial) {
            $species = sanitize_key((string) ($input['species'] ?? ''));
            if (!in_array($species, self::SPECIES, true)) {
                $errors['species'] = Zooboxi_Loyalty::pick('اختر نوع الحيوان', 'Pick a species.');
            } else {
                $data['species'] = $species;
                $formats[]       = '%s';
            }
        }

        // ── breed ──
        if ($has('breed')) {
            $data['breed'] = mb_substr(trim(wp_strip_all_tags((string) $input['breed'])), 0, 80);
            $formats[]     = '%s';
        }

        // ── sex ──
        if ($has('sex')) {
            $sex = strtolower(trim((string) $input['sex']));
            if (!in_array($sex, self::SEXES, true)) {
                $errors['sex'] = Zooboxi_Loyalty::pick('الجنس غير صالح', 'Invalid sex value.');
            } else {
                $data['sex'] = $sex;
                $formats[]   = '%s';
            }
        }

        // ── weight ──
        if (array_key_exists('weight_kg', $input)) {
            if ($input['weight_kg'] === null || $input['weight_kg'] === '') {
                $data['weight_kg'] = null;
                $formats[]         = '%s';
            } else {
                $weight = (float) $input['weight_kg'];
                if ($weight <= 0 || $weight > 200) {
                    $errors['weight_kg'] = Zooboxi_Loyalty::pick('الوزن غير منطقي', 'That weight is not plausible.');
                } else {
                    $data['weight_kg'] = round($weight, 2);
                    $formats[]         = '%f';
                }
            }
        }

        // ── birth date ──
        if (array_key_exists('birth_date', $input)) {
            $raw = trim((string) ($input['birth_date'] ?? ''));
            if ($raw === '') {
                $data['birth_date'] = null;
                $formats[]          = '%s';
            } elseif (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw) || !strtotime($raw)) {
                $errors['birth_date'] = Zooboxi_Loyalty::pick('تاريخ الميلاد غير صالح', 'Invalid birth date.');
            } elseif (strtotime($raw) > time() + DAY_IN_SECONDS) {
                $errors['birth_date'] = Zooboxi_Loyalty::pick('تاريخ الميلاد في المستقبل', 'The birth date is in the future.');
            } elseif (strtotime($raw) < strtotime('-60 years')) {
                $errors['birth_date'] = Zooboxi_Loyalty::pick('تاريخ الميلاد قديم جداً', 'That birth date is too far back.');
            } else {
                $data['birth_date'] = $raw;
                $formats[]          = '%s';
            }
        }

        // ── neutered ──
        if (array_key_exists('neutered', $input)) {
            if ($input['neutered'] === null || $input['neutered'] === '') {
                $data['neutered'] = null;
            } else {
                $data['neutered'] = wc_string_to_bool($input['neutered']) ? 1 : 0;
            }
            $formats[] = '%d';
        }

        // ── avatar key (a drawn illustration in the app, never an emoji) ──
        if ($has('avatar')) {
            $data['avatar'] = mb_substr(sanitize_key((string) $input['avatar']), 0, 24);
            $formats[]      = '%s';
        }

        // ── notes ──
        if ($has('notes')) {
            $data['notes'] = mb_substr(trim(wp_strip_all_tags((string) $input['notes'])), 0, 200);
            $formats[]     = '%s';
        }

        // ── photo (an existing attachment id only) ──
        if (array_key_exists('photo_id', $input)) {
            $pid = absint($input['photo_id'] ?? 0);
            if ($pid > 0 && get_post_type($pid) !== 'attachment') {
                $errors['photo_id'] = Zooboxi_Loyalty::pick('الصورة غير موجودة', 'That photo does not exist.');
            } else {
                $data['photo_id'] = $pid ?: null;
                $formats[]        = '%d';
            }
        }

        return ['data' => $data, 'formats' => $formats, 'errors' => $errors];
    }

    /* ══════════════════════════════════════════════════════════════
       WRITE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Create a pet and pay for it.
     *
     * @return array{pet:?array,errors:array,code:string,paws:int}
     */
    public static function create(int $user_id, array $input): array
    {
        if ($user_id <= 0) {
            return ['pet' => null, 'errors' => [], 'code' => 'unauthorized', 'paws' => 0];
        }
        Zooboxi_Loyalty_Schema::maybe_install();

        if (self::count($user_id) >= self::max()) {
            return ['pet' => null, 'errors' => [], 'code' => 'pets_limit', 'paws' => 0];
        }

        $checked = self::validate($input, false);
        if (!empty($checked['errors'])) {
            return ['pet' => null, 'errors' => $checked['errors'], 'code' => 'pet_invalid', 'paws' => 0];
        }

        Zooboxi_Loyalty_Members::ensure($user_id);

        $now  = Zooboxi_Loyalty::now();
        $data = $checked['data'] + [
            'user_id'    => $user_id,
            'created_at' => $now,
            'updated_at' => $now,
        ];

        global $wpdb;
        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::pets(), $data);
        if (!$ok) {
            return ['pet' => null, 'errors' => [], 'code' => 'pet_failed', 'paws' => 0];
        }

        $pet_id = (int) $wpdb->insert_id;
        self::forget($user_id);
        $pet    = self::find($pet_id, $user_id);

        $paws = self::award_for_pet($user_id, $pet_id);
        $paws += self::maybe_award_profile($user_id);
        self::after_save($user_id);

        return ['pet' => $pet, 'errors' => [], 'code' => '', 'paws' => $paws];
    }

    /**
     * Update a pet. `paws` is 100 when this edit completed the profile for the first
     * time — the only moment an edit can pay.
     *
     * @return array{pet:?array,errors:array,code:string,paws:int}
     */
    public static function update(int $user_id, int $pet_id, array $input): array
    {
        $pet = self::find($pet_id, $user_id);
        if ($pet === null) {
            return ['pet' => null, 'errors' => [], 'code' => 'pet_not_found', 'paws' => 0];
        }

        $checked = self::validate($input, true);
        if (!empty($checked['errors'])) {
            return ['pet' => null, 'errors' => $checked['errors'], 'code' => 'pet_invalid', 'paws' => 0];
        }
        if (empty($checked['data'])) {
            return ['pet' => $pet, 'errors' => [], 'code' => '', 'paws' => 0];
        }

        $data = $checked['data'];
        $data['updated_at'] = Zooboxi_Loyalty::now();

        global $wpdb;
        $wpdb->update(Zooboxi_Loyalty_Schema::pets(), $data, ['id' => $pet_id, 'user_id' => $user_id]);
        self::forget($user_id);

        $paws = self::maybe_award_profile($user_id);
        self::after_save($user_id);

        return ['pet' => self::find($pet_id, $user_id), 'errors' => [], 'code' => '', 'paws' => $paws];
    }

    /** Soft delete — the paid paws keep their explanation in the ledger. */
    public static function delete(int $user_id, int $pet_id): bool
    {
        if (self::find($pet_id, $user_id) === null) {
            return false;
        }
        global $wpdb;
        $ok = (bool) $wpdb->update(
            Zooboxi_Loyalty_Schema::pets(),
            ['deleted_at' => Zooboxi_Loyalty::now(), 'updated_at' => Zooboxi_Loyalty::now()],
            ['id' => $pet_id, 'user_id' => $user_id],
            ['%s', '%s'],
            ['%d', '%d']
        );
        self::forget($user_id);
        return $ok;
    }

    /* ══════════════════════════════════════════════════════════════
       PAWS
       ══════════════════════════════════════════════════════════════ */

    /** 50 paws per pet, at most `max_pets` times, once per pet id. */
    private static function award_for_pet(int $user_id, int $pet_id): int
    {
        $amount = Zooboxi_Loyalty::opt_int('pet_paws');
        if ($amount <= 0) {
            return 0;
        }
        // Never pay beyond the cap, even if pets were added and removed repeatedly.
        global $wpdb;
        $paid = (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::ledger()
            . " WHERE user_id = %d AND reason = 'pet_added'",
            $user_id
        ));
        if ($paid >= self::max()) {
            return 0;
        }

        return Zooboxi_Loyalty_Ledger::add($user_id, $amount, 'pet_added', 'pet', $pet_id) > 0 ? $amount : 0;
    }

    /** 100 paws the first time any pet carries BOTH a weight and a birth date. */
    public static function maybe_award_profile(int $user_id): int
    {
        $amount = Zooboxi_Loyalty::opt_int('profile_paws');
        if ($amount <= 0 || !self::profile_is_complete($user_id)) {
            return 0;
        }
        if (!Zooboxi_Loyalty_Members::mark_profile_complete($user_id)) {
            return 0; // already stamped — this is not the first time
        }
        return Zooboxi_Loyalty_Ledger::add($user_id, $amount, 'profile_complete', 'user', $user_id) > 0 ? $amount : 0;
    }

    /**
     * After any pet write: the profile mission may now be finishable, and the species
     * a customer owns is an input to next month's category mission.
     */
    private static function after_save(int $user_id): void
    {
        try {
            if (class_exists('Zooboxi_Loyalty_Missions')) {
                Zooboxi_Loyalty_Missions::progress_profile($user_id);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] profile mission progress failed: ' . $e->getMessage());
        }
    }

    /** Is at least one pet complete (weight + birth date)? */
    public static function profile_is_complete(int $user_id): bool
    {
        foreach (self::all($user_id) as $pet) {
            if (self::is_complete($pet)) {
                return true;
            }
        }
        return false;
    }

    public static function is_complete(array $pet): bool
    {
        return $pet['weight_kg'] !== null && (float) $pet['weight_kg'] > 0
            && !empty($pet['birth_date']) && $pet['birth_date'] !== '0000-00-00';
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function dto(array $pet): array
    {
        $birth = (string) ($pet['birth_date'] ?? '');
        $birth = ($birth === '' || $birth === '0000-00-00') ? '' : $birth;

        return [
            'id'                => (int) $pet['id'],
            'name'              => (string) $pet['name'],
            'species'           => (string) $pet['species'],
            'breed'             => (string) $pet['breed'],
            'sex'               => (string) $pet['sex'],
            'weight_kg'         => $pet['weight_kg'] === null ? null : (float) $pet['weight_kg'],
            'birth_date'        => $birth ?: null,
            'age_label'         => $birth ? self::age_label($birth) : null,
            'neutered'          => $pet['neutered'] === null ? null : ((int) $pet['neutered'] === 1),
            'avatar'            => (string) $pet['avatar'],
            'photo_url'         => !empty($pet['photo_id']) ? (wp_get_attachment_image_url((int) $pet['photo_id'], 'medium') ?: null) : null,
            'is_complete'       => self::is_complete($pet),
            'birthday_in_days'  => $birth ? self::birthday_in_days($birth) : null,
        ];
    }

    public static function dtos(int $user_id): array
    {
        $out = [];
        foreach (self::all($user_id) as $pet) {
            $out[] = self::dto($pet);
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       AGE
       ══════════════════════════════════════════════════════════════ */

    /**
     * «سنتان و3 أشهر» / "2y 3m".
     *
     * Arabic needs the dual ("سنتان", "شهران") and switches plural form again above
     * ten, so this is spelled out rather than run through a generic pluraliser.
     */
    public static function age_label(string $birth_date): string
    {
        $birth = strtotime($birth_date . ' 00:00:00 UTC');
        if (!$birth || $birth > time()) {
            return '';
        }

        $from = new \DateTimeImmutable('@' . $birth);
        $now  = new \DateTimeImmutable('@' . time());
        $diff = $from->diff($now);

        $years  = (int) $diff->y;
        $months = (int) $diff->m;

        if (Zooboxi_Loyalty::pick('ar', 'en') === 'en') {
            if ($years <= 0 && $months <= 0) {
                return '<1m';
            }
            $parts = [];
            if ($years > 0) {
                $parts[] = $years . 'y';
            }
            if ($months > 0) {
                $parts[] = $months . 'm';
            }
            return implode(' ', $parts);
        }

        if ($years <= 0 && $months <= 0) {
            return 'أقل من شهر';
        }

        $parts = [];
        if ($years > 0) {
            $parts[] = self::ar_count($years, 'سنة', 'سنتان', 'سنوات', 'سنة');
        }
        if ($months > 0) {
            $parts[] = self::ar_count($months, 'شهر', 'شهران', 'أشهر', 'شهراً');
        }
        return implode(' و', $parts);
    }

    /** Arabic counted-noun agreement: 1 / 2 (dual) / 3–10 (plural) / 11+ (singular accusative). */
    private static function ar_count(int $n, string $one, string $two, string $few, string $many): string
    {
        if ($n === 1) {
            return $one;
        }
        if ($n === 2) {
            return $two;
        }
        if ($n <= 10) {
            return $n . ' ' . $few;
        }
        return $n . ' ' . $many;
    }

    /** Days until the next birthday anniversary (0 = today). */
    public static function birthday_in_days(string $birth_date): ?int
    {
        $birth = strtotime($birth_date . ' 00:00:00 UTC');
        if (!$birth) {
            return null;
        }

        $today = strtotime(gmdate('Y-m-d') . ' 00:00:00 UTC');
        $month = gmdate('m', $birth);
        $day   = gmdate('d', $birth);

        $next = strtotime(gmdate('Y') . '-' . $month . '-' . $day . ' 00:00:00 UTC');
        if ($next === false) {
            return null;
        }
        if ($next < $today) {
            $next = strtotime((gmdate('Y') + 1) . '-' . $month . '-' . $day . ' 00:00:00 UTC');
        }
        if ($next === false) {
            return null;
        }

        return (int) floor(($next - $today) / DAY_IN_SECONDS);
    }
}
