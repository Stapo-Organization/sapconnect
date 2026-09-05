<?php
/**
 * Zooboxi_Loyalty_CLI — `wp zooboxi loyalty <command>`.
 *
 * These are the three operations a deploy actually needs: install/seed the catalogue,
 * run the daily job by hand, and print the pre-program baseline so the owner can judge
 * the program against what the store was already doing.
 *
 * Registered ONLY under WP_CLI, so a web request never pays for this file's existence.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_CLI
{
    public static function register(): void
    {
        if (!defined('WP_CLI') || !WP_CLI || !class_exists('WP_CLI')) {
            return;
        }
        \WP_CLI::add_command('zooboxi loyalty', __CLASS__);
    }

    /**
     * Print the 365-day order baseline as JSON.
     *
     * ## OPTIONS
     *
     * [--fresh]
     * : Recompute instead of reading the six-hour cache.
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty baseline --fresh
     *
     * @when after_wp_load
     */
    public function baseline($args, $assoc_args): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        $fresh = isset($assoc_args['fresh']);
        \WP_CLI::line(wp_json_encode(Zooboxi_Loyalty::baseline($fresh), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }

    /**
     * Run the daily housekeeping job now (paw expiry + grant expiry).
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty daily
     *
     * @when after_wp_load
     */
    public function daily(): void
    {
        $result = Zooboxi_Loyalty::run_daily();
        \WP_CLI::success(sprintf(
            'paws expired: %d across %d members · grants expired: %d',
            (int) $result['paws_expired'],
            (int) $result['members_expired'],
            (int) $result['grants_expired']
        ));
    }

    /**
     * Install the tables and seed the default reward catalogue. Idempotent.
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty seed-defaults
     *
     * @subcommand seed-defaults
     * @when after_wp_load
     */
    public function seed_defaults(): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        $result = Zooboxi_Loyalty_Schema::seed_defaults();
        \WP_CLI::success(sprintf(
            'rewards created: %d · already present: %d',
            (int) $result['created'],
            (int) $result['skipped']
        ));
        \WP_CLI::line('Attach a product to each gift reward in: Zooboxi → 🐾 عائلة زوبوكسي → الهدايا.');
    }

    /**
     * Run the Phase 2 daily jobs now (subscription reminders, referral payouts,
     * birthdays, win-back).
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty habit-daily
     *
     * @subcommand habit-daily
     * @when after_wp_load
     */
    public function habit_daily(): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        $r = Zooboxi_Loyalty_Moments::run_daily();
        \WP_CLI::success(sprintf(
            'subscription reminders: %d · referrals paid: %d · birthdays: %d · win-backs: %d',
            (int) $r['sub_reminders'],
            (int) $r['referrals_paid'],
            (int) $r['birthdays'],
            (int) $r['winbacks']
        ));
    }

    /**
     * Print one customer's supply gauge (the food forecast) as JSON.
     *
     * ## OPTIONS
     *
     * <user_id>
     * : The customer's user id.
     *
     * [--fresh]
     * : Rebuild instead of reading the 15-minute cache.
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty supply 42 --fresh
     *
     * @when after_wp_load
     */
    public function supply($args, $assoc_args): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        $user_id = (int) ($args[0] ?? 0);
        $rows    = Zooboxi_Loyalty_Supply::items($user_id, isset($assoc_args['fresh']));
        \WP_CLI::line(wp_json_encode(Zooboxi_Loyalty_Supply::dtos($rows, $user_id), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }

    /**
     * Print the current program metrics as JSON.
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty metrics
     *
     * @when after_wp_load
     */
    public function metrics(): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        \WP_CLI::line(wp_json_encode(Zooboxi_Loyalty::metrics(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }

    /**
     * Print the scratch prize table with its resolved probabilities and expected cost.
     *
     * ## EXAMPLES
     *
     *     wp zooboxi loyalty odds
     *
     * @when after_wp_load
     */
    public function odds(): void
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        \WP_CLI::line(wp_json_encode(Zooboxi_Loyalty_Scratch::odds(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    }
}
