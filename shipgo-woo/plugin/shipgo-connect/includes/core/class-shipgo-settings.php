<?php
defined('ABSPATH') || exit;

/** Typed accessors over the single `shipgo_connect_settings` option. */
class ShipGo_Settings {

    const OPTION = 'shipgo_connect_settings';

    public static function all(): array {
        $s = get_option(self::OPTION, []);
        return is_array($s) ? $s : [];
    }

    public static function get(string $key, $default = '') {
        $s = self::all();
        return $s[$key] ?? $default;
    }

    public static function update(array $patch): void {
        update_option(self::OPTION, array_merge(self::all(), $patch));
    }

    public static function is_enabled(): bool {
        return self::get('enabled') === 'yes' && self::base_url() !== '' && self::api_key() !== '';
    }

    public static function base_url(): string {
        return untrailingslashit((string) self::get('base_url'));
    }

    public static function api_key(): string {
        return (string) self::get('api_key');
    }

    public static function webhook_secret(): string {
        return (string) self::get('webhook_secret');
    }

    /** sk_test_… keys mean the connection is in sandbox/observe mode. */
    public static function is_sandbox(): bool {
        return strpos(self::api_key(), 'sk_test_') === 0;
    }

    /** Masked display of the key (prefix only) — never echo the full secret. */
    public static function masked_key(): string {
        $k = self::api_key();
        return $k === '' ? '' : substr($k, 0, 12) . str_repeat('•', 8);
    }
}
