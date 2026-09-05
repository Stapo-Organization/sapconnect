<?php
/**
 * Zooboxi_Loyalty_Schema — the tables behind «عائلة زوبوكسي» (seven in Phase 1, six more
 * for Phase 2 «العادة»: subscriptions, supply events, referrals, stamp programs, stamps,
 * notices).
 *
 * WHY LAZY: this store is deployed by scp, so `register_activation_hook` never fires.
 * Exactly like Zooboxi_App_Tokens, one cheap option read guards a dbDelta run, and
 * every entry point that can be the FIRST touch after a deploy (admin_init, the v2
 * controller, the cron, the CLI, the order hooks) calls maybe_install() first.
 *
 * Every DATETIME in this module is UTC (`current_time('mysql', true)` / gmdate).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Schema
{
    /** ONE version for the whole module — bump when any table below changes. */
    public const DB_VERSION = 2;

    /** Option holding the installed schema version. */
    public const DB_OPTION = 'zooboxi_loyalty_db_version';

    /* ── Table names (never hardcode 'wp_' — prod is `zbx_`) ────────── */

    public static function members(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_members';
    }

    public static function pets(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_pets';
    }

    public static function ledger(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_paws_ledger';
    }

    public static function rewards(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_rewards';
    }

    public static function grants(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_grants';
    }

    public static function scratch(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_scratch_cards';
    }

    public static function missions(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_missions';
    }

    /* ── Phase 2 ── */

    public static function subscriptions(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_subscriptions';
    }

    public static function supply_events(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_supply_events';
    }

    public static function referrals(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_referrals';
    }

    public static function stamp_programs(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_stamp_programs';
    }

    public static function stamps(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_stamps';
    }

    public static function notices(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'zb_notices';
    }

    /** All tables, keyed by short name (used by the admin health box). */
    public static function all(): array
    {
        return [
            'members'        => self::members(),
            'pets'           => self::pets(),
            'ledger'         => self::ledger(),
            'rewards'        => self::rewards(),
            'grants'         => self::grants(),
            'scratch'        => self::scratch(),
            'missions'       => self::missions(),
            'subscriptions'  => self::subscriptions(),
            'supply_events'  => self::supply_events(),
            'referrals'      => self::referrals(),
            'stamp_programs' => self::stamp_programs(),
            'stamps'         => self::stamps(),
            'notices'        => self::notices(),
        ];
    }

    /* ── Install ────────────────────────────────────────────────────── */

    /** Cheap no-op after the first run (one option read). */
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

        if (!function_exists('dbDelta')) {
            if (!defined('ABSPATH') || !file_exists(ABSPATH . 'wp-admin/includes/upgrade.php')) {
                return;
            }
            require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        }

        $charset = $wpdb->get_charset_collate();
        $members = self::members();
        $pets    = self::pets();
        $ledger  = self::ledger();
        $rewards = self::rewards();
        $grants  = self::grants();
        $scratch = self::scratch();
        $missions = self::missions();
        $subscriptions  = self::subscriptions();
        $supply_events  = self::supply_events();
        $referrals      = self::referrals();
        $stamp_programs = self::stamp_programs();
        $stamps         = self::stamps();
        $notices        = self::notices();

        $sql = [];

        $sql[] = "CREATE TABLE {$members} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            joined_at DATETIME NOT NULL,
            holdout TINYINT(1) NOT NULL DEFAULT 0,
            tier_key VARCHAR(16) NOT NULL DEFAULT 'new',
            tier_orders_12m INT NOT NULL DEFAULT 0,
            tier_computed_at DATETIME NULL DEFAULT NULL,
            paws_balance INT NOT NULL DEFAULT 0,
            last_earn_at DATETIME NULL DEFAULT NULL,
            profile_completed_at DATETIME NULL DEFAULT NULL,
            referral_code VARCHAR(12) NULL DEFAULT NULL,
            winback_at DATETIME NULL DEFAULT NULL,
            nudge_week CHAR(7) NOT NULL DEFAULT '',
            nudge_count TINYINT NOT NULL DEFAULT 0,
            PRIMARY KEY  (id),
            UNIQUE KEY user_id (user_id),
            UNIQUE KEY referral_code (referral_code)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$pets} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            name VARCHAR(60) NOT NULL DEFAULT '',
            species VARCHAR(12) NOT NULL DEFAULT 'other',
            breed VARCHAR(80) NOT NULL DEFAULT '',
            sex VARCHAR(1) NOT NULL DEFAULT '',
            weight_kg DECIMAL(5,2) NULL DEFAULT NULL,
            birth_date DATE NULL DEFAULT NULL,
            neutered TINYINT(1) NULL DEFAULT NULL,
            photo_id BIGINT UNSIGNED NULL DEFAULT NULL,
            avatar VARCHAR(24) NOT NULL DEFAULT '',
            notes VARCHAR(200) NOT NULL DEFAULT '',
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            deleted_at DATETIME NULL DEFAULT NULL,
            PRIMARY KEY  (id),
            KEY user_id (user_id),
            KEY user_live (user_id, deleted_at)
        ) {$charset};";

        // The append-only book. The UNIQUE key IS the idempotency contract: the same
        // reason for the same reference can never be written twice, so a replayed
        // order-completed hook cannot double-pay.
        $sql[] = "CREATE TABLE {$ledger} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            delta INT NOT NULL DEFAULT 0,
            balance_after INT NOT NULL DEFAULT 0,
            reason VARCHAR(32) NOT NULL DEFAULT '',
            ref_type VARCHAR(24) NOT NULL DEFAULT '',
            ref_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            note VARCHAR(200) NOT NULL DEFAULT '',
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY entry (user_id, reason, ref_type, ref_id),
            KEY user_created (user_id, created_at),
            KEY created_at (created_at)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$rewards} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            kind VARCHAR(20) NOT NULL DEFAULT 'gift_product',
            reward_key VARCHAR(32) NOT NULL DEFAULT '',
            title_ar VARCHAR(120) NOT NULL DEFAULT '',
            title_en VARCHAR(120) NOT NULL DEFAULT '',
            desc_ar VARCHAR(240) NOT NULL DEFAULT '',
            desc_en VARCHAR(240) NOT NULL DEFAULT '',
            product_id BIGINT UNSIGNED NULL DEFAULT NULL,
            variation_id BIGINT UNSIGNED NULL DEFAULT NULL,
            paws_cost INT NOT NULL DEFAULT 0,
            cost_sar DECIMAL(8,2) NOT NULL DEFAULT 0.00,
            value_sar DECIMAL(8,2) NOT NULL DEFAULT 0.00,
            validity_days INT NOT NULL DEFAULT 21,
            min_tier VARCHAR(16) NOT NULL DEFAULT '',
            monthly_cap INT NULL DEFAULT NULL,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            sort INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY reward_key (reward_key),
            KEY active_sort (is_active, sort)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$grants} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            reward_id BIGINT UNSIGNED NOT NULL,
            source VARCHAR(16) NOT NULL DEFAULT 'admin',
            source_ref BIGINT UNSIGNED NOT NULL DEFAULT 0,
            state VARCHAR(12) NOT NULL DEFAULT 'pending',
            activates_on_order BIGINT UNSIGNED NULL DEFAULT NULL,
            expires_at DATETIME NULL DEFAULT NULL,
            claimed_at DATETIME NULL DEFAULT NULL,
            redeemed_order_id BIGINT UNSIGNED NULL DEFAULT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            KEY user_state (user_id, state),
            KEY activates_on_order (activates_on_order),
            KEY state_expires (state, expires_at)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$scratch} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            order_id BIGINT UNSIGNED NOT NULL,
            prize_kind VARCHAR(8) NOT NULL DEFAULT 'paws',
            prize_paws INT NOT NULL DEFAULT 0,
            prize_reward_id BIGINT UNSIGNED NULL DEFAULT NULL,
            grant_id BIGINT UNSIGNED NULL DEFAULT NULL,
            state VARCHAR(8) NOT NULL DEFAULT 'sealed',
            revealed_at DATETIME NULL DEFAULT NULL,
            settled TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY order_id (order_id),
            KEY user_created (user_id, created_at)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$missions} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            period CHAR(7) NOT NULL DEFAULT '',
            template_key VARCHAR(32) NOT NULL DEFAULT '',
            kind VARCHAR(12) NOT NULL DEFAULT '',
            title_ar VARCHAR(160) NOT NULL DEFAULT '',
            title_en VARCHAR(160) NOT NULL DEFAULT '',
            body_ar VARCHAR(240) NOT NULL DEFAULT '',
            body_en VARCHAR(240) NOT NULL DEFAULT '',
            target INT NOT NULL DEFAULT 1,
            progress INT NOT NULL DEFAULT 0,
            params LONGTEXT NULL,
            reward_kind VARCHAR(8) NOT NULL DEFAULT 'paws',
            reward_paws INT NOT NULL DEFAULT 0,
            reward_reward_id BIGINT UNSIGNED NULL DEFAULT NULL,
            state VARCHAR(10) NOT NULL DEFAULT 'active',
            completed_at DATETIME NULL DEFAULT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY assignment (user_id, period, template_key),
            KEY user_period (user_id, period),
            KEY user_state (user_id, state)
        ) {$charset};";

        /* ── Phase 2 «العادة» ─────────────────────────────────────── */

        // One row per (customer, product, variation): the soft subscription. The
        // UNIQUE key doubles as the "already subscribed" check.
        $sql[] = "CREATE TABLE {$subscriptions} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            pet_id BIGINT UNSIGNED NULL DEFAULT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            variation_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            qty INT NOT NULL DEFAULT 1,
            interval_days INT NOT NULL DEFAULT 30,
            next_at DATE NULL DEFAULT NULL,
            state VARCHAR(10) NOT NULL DEFAULT 'active',
            deliveries INT NOT NULL DEFAULT 0,
            reminder_for DATE NULL DEFAULT NULL,
            last_order_id BIGINT UNSIGNED NULL DEFAULT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY line (user_id, product_id, variation_id),
            KEY user_state (user_id, state),
            KEY state_next (state, next_at)
        ) {$charset};";

        // «خلص الأكل» / «عندي كفاية»: the customer correcting the forecast.
        $sql[] = "CREATE TABLE {$supply_events} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            variation_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            kind VARCHAR(8) NOT NULL DEFAULT 'out',
            until DATE NULL DEFAULT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            KEY user_product (user_id, product_id, created_at)
        ) {$charset};";

        // A referee belongs to exactly one referrer, forever (UNIQUE referee_id).
        $sql[] = "CREATE TABLE {$referrals} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            referrer_id BIGINT UNSIGNED NOT NULL,
            referee_id BIGINT UNSIGNED NOT NULL,
            code VARCHAR(12) NOT NULL DEFAULT '',
            state VARCHAR(10) NOT NULL DEFAULT 'pending',
            first_order_id BIGINT UNSIGNED NULL DEFAULT NULL,
            qualified_at DATETIME NULL DEFAULT NULL,
            rewarded_at DATETIME NULL DEFAULT NULL,
            flags VARCHAR(200) NOT NULL DEFAULT '',
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY referee (referee_id),
            KEY referrer_state (referrer_id, state),
            KEY state_created (state, created_at)
        ) {$charset};";

        $sql[] = "CREATE TABLE {$stamp_programs} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            title_ar VARCHAR(120) NOT NULL DEFAULT '',
            title_en VARCHAR(120) NOT NULL DEFAULT '',
            brand_term_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            units_required INT NOT NULL DEFAULT 6,
            min_pack_kg DECIMAL(5,2) NOT NULL DEFAULT 0.00,
            reward_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            is_active TINYINT(1) NOT NULL DEFAULT 0,
            sort INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            KEY active_sort (is_active, sort)
        ) {$charset};";

        // One order line stamps once, whatever happens to the hook.
        $sql[] = "CREATE TABLE {$stamps} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            program_id BIGINT UNSIGNED NOT NULL,
            order_id BIGINT UNSIGNED NOT NULL,
            order_item_id BIGINT UNSIGNED NOT NULL,
            units INT NOT NULL DEFAULT 1,
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY line (program_id, order_item_id),
            KEY user_program (user_id, program_id)
        ) {$charset};";

        // Every notice sent (mail or in-app), so the same one is never sent twice and
        // the weekly cap can be counted.
        $sql[] = "CREATE TABLE {$notices} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            kind VARCHAR(24) NOT NULL DEFAULT '',
            ref VARCHAR(40) NOT NULL DEFAULT '',
            channel VARCHAR(8) NOT NULL DEFAULT 'mail',
            sent_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            UNIQUE KEY once (user_id, kind, ref),
            KEY user_sent (user_id, sent_at)
        ) {$charset};";

        foreach ($sql as $statement) {
            dbDelta($statement);
        }

        update_option(self::DB_OPTION, self::DB_VERSION, false);
    }

    /** Does a table physically exist? (used before any wc_order_stats read too) */
    public static function table_exists(string $table): bool
    {
        global $wpdb;
        // phpcs:ignore WordPress.DB.PreparedSQL
        return (string) $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $table)) === $table;
    }

    /* ── Default catalogue seed ─────────────────────────────────────── */

    /**
     * Seed the five Phase-1 rewards. Idempotent: keyed on `reward_key`, so running it
     * twice never duplicates a row and never overwrites the owner's edits.
     *
     * The gift rows deliberately ship with NO product attached — the owner picks the
     * actual SKU in the admin screen; an unattached gift_product is skipped by the
     * scratch roll and shown as non-redeemable in the catalogue.
     *
     * @return array{created:int,skipped:int}
     */
    public static function seed_defaults(): array
    {
        global $wpdb;
        self::maybe_install();

        $now  = current_time('mysql', true);
        $rows = [
            [
                'reward_key' => 'express_free',
                'kind'       => 'express_free',
                'title_ar'   => 'ترقية توصيل سريع مجاني',
                'title_en'   => 'Free express upgrade',
                'desc_ar'    => 'طلبك القادم يصلك بالتوصيل السريع بلا رسوم — داخل نطاق التوصيل السريع.',
                'desc_en'    => 'Your next order ships express with no fee — inside the express zone.',
                'paws_cost'  => 250,
                'cost_sar'   => 8.00,
                'value_sar'  => 15.00,
                'validity_days' => 21,
                'sort'       => 5,
            ],
            [
                'reward_key' => 'free_delivery',
                'kind'       => 'free_delivery',
                'title_ar'   => 'توصيل مجاني بلا حد أدنى',
                'title_en'   => 'Free delivery, no minimum',
                'desc_ar'    => 'استخدمها في سلتك القادمة ولن تدفع رسوم توصيل مهما كان المبلغ.',
                'desc_en'    => 'Use it on your next basket — no delivery fee, whatever the total.',
                'paws_cost'  => 400,
                'cost_sar'   => 10.00,
                'value_sar'  => 25.00,
                'validity_days' => 21,
                'sort'       => 10,
            ],
            [
                'reward_key' => 'small_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية صغيرة',
                'title_en'   => 'Small gift',
                'desc_ar'    => 'مكافأة صغيرة تُضاف لسلتك مجاناً.',
                'desc_en'    => 'A small treat added to your basket, free.',
                'paws_cost'  => 600,
                'cost_sar'   => 12.00,
                'value_sar'  => 25.00,
                'validity_days' => 21,
                'sort'       => 20,
            ],
            [
                'reward_key' => 'medium_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية متوسطة',
                'title_en'   => 'Medium gift',
                'desc_ar'    => 'هدية أكبر لعائلتك، مجاناً مع طلبك.',
                'desc_en'    => 'A bigger gift for your family, free with your order.',
                'paws_cost'  => 1500,
                'cost_sar'   => 30.00,
                'value_sar'  => 60.00,
                'validity_days' => 21,
                'sort'       => 30,
            ],
            [
                'reward_key' => 'mystery_box',
                'kind'       => 'gift_product',
                'title_ar'   => 'صندوق مفاجآت',
                'title_en'   => 'Mystery box',
                'desc_ar'    => 'صندوق نختاره لك بأنفسنا — لا تعرف ما بداخله حتى يصل.',
                'desc_en'    => 'A box we pick ourselves — you only find out when it arrives.',
                'paws_cost'  => 3000,
                'cost_sar'   => 60.00,
                'value_sar'  => 120.00,
                'validity_days' => 21,
                'sort'       => 40,
            ],
            // ── Granted-only gifts (paws_cost 0): the moments of Phase 2 ──
            [
                'reward_key' => 'welcome_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية الترحيب',
                'title_en'   => 'Welcome gift',
                'desc_ar'    => 'هدية صغيرة مع أول طلب من التطبيق.',
                'desc_en'    => 'A small gift with your first order from the app.',
                'paws_cost'  => 0,
                'cost_sar'   => 10.00,
                'value_sar'  => 20.00,
                'validity_days' => 30,
                'sort'       => 50,
            ],
            [
                'reward_key' => 'referral_welcome',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية صديق زوبوكسي',
                'title_en'   => 'Friend-of-Zooboxi gift',
                'desc_ar'    => 'جئت بدعوة من صديق — هذه الهدية مع أول طلب لك.',
                'desc_en'    => 'You came by a friend\'s invitation — this gift rides with your first order.',
                'paws_cost'  => 0,
                'cost_sar'   => 10.00,
                'value_sar'  => 20.00,
                'validity_days' => 30,
                'sort'       => 55,
            ],
            [
                'reward_key' => 'birthday_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية عيد الميلاد',
                'title_en'   => 'Birthday gift',
                'desc_ar'    => 'هدية باسم حيوانك في أسبوع عيد ميلاده، تُضاف لطلبك مجاناً.',
                'desc_en'    => 'A gift in your pet\'s name for its birthday week, added to your order free.',
                'paws_cost'  => 0,
                'cost_sar'   => 12.00,
                'value_sar'  => 25.00,
                'validity_days' => 28,
                'sort'       => 60,
            ],
            [
                'reward_key' => 'winback_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية «اشتقنا لك»',
                'title_en'   => '"We missed you" gift',
                'desc_ar'    => 'مرّ وقت طويل — هذه الهدية مع طلبك القادم.',
                'desc_en'    => 'It has been a while — this gift comes with your next order.',
                'paws_cost'  => 0,
                'cost_sar'   => 15.00,
                'value_sar'  => 30.00,
                'validity_days' => 30,
                'sort'       => 65,
            ],
            [
                'reward_key' => 'sub_gift',
                'kind'       => 'gift_product',
                'title_ar'   => 'هدية الاشتراك',
                'title_en'   => 'Subscription gift',
                'desc_ar'    => 'مع كل توصيلة اشتراك ثالثة — شكراً لانتظامك.',
                'desc_en'    => 'With every third subscription delivery — thank you for the rhythm.',
                'paws_cost'  => 0,
                'cost_sar'   => 12.00,
                'value_sar'  => 25.00,
                'validity_days' => 30,
                'sort'       => 70,
            ],
        ];

        $created = 0;
        $skipped = 0;

        foreach ($rows as $row) {
            $exists = (int) $wpdb->get_var($wpdb->prepare(
                'SELECT id FROM ' . self::rewards() . ' WHERE reward_key = %s LIMIT 1',
                $row['reward_key']
            ));
            if ($exists > 0) {
                $skipped++;
                continue;
            }

            $ok = $wpdb->insert(self::rewards(), [
                'kind'          => $row['kind'],
                'reward_key'    => $row['reward_key'],
                'title_ar'      => $row['title_ar'],
                'title_en'      => $row['title_en'],
                'desc_ar'       => $row['desc_ar'],
                'desc_en'       => $row['desc_en'],
                'product_id'    => null,
                'variation_id'  => null,
                'paws_cost'     => $row['paws_cost'],
                'cost_sar'      => $row['cost_sar'],
                'value_sar'     => $row['value_sar'],
                'validity_days' => $row['validity_days'],
                'min_tier'      => '',
                'monthly_cap'   => null,
                'is_active'     => 1,
                'sort'          => $row['sort'],
                'created_at'    => $now,
                'updated_at'    => $now,
            ], ['%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%d', '%f', '%f', '%d', '%s', '%d', '%d', '%d', '%s', '%s']);

            if ($ok) {
                $created++;
            } else {
                $skipped++;
            }
        }

        return ['created' => $created, 'skipped' => $skipped];
    }
}
