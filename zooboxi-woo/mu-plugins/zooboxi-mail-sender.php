<?php
/**
 * Plugin Name: Zooboxi — send mail as zooboxi.com
 * Description: Every store email leaves as «زوبوكسي» <info@zooboxi.com> with info@zooboxi.com as the envelope sender (Return-Path). The server's own name (pris1006.startdedicated.com) has no SPF, so Gmail treated every store email as a forgery of zooboxi.com and filed it as spam; zooboxi.com's SPF already lists this server (62.138.14.178), so the matching envelope passes SPF and DMARC.
 */

defined('ABSPATH') || exit;

const ZOOBOXI_MAIL_FROM      = 'info@zooboxi.com';
const ZOOBOXI_MAIL_FROM_NAME = 'زوبوكسي';

// WordPress's default sender (wordpress@store.zooboxi.com) → the store's address.
add_filter('wp_mail_from', static function ($from) {
    return str_starts_with((string) $from, 'wordpress@') ? ZOOBOXI_MAIL_FROM : $from;
});
add_filter('wp_mail_from_name', static function ($name) {
    return ($name === '' || $name === 'WordPress') ? ZOOBOXI_MAIL_FROM_NAME : $name;
});

// WooCommerce's sender name is empty in its settings.
add_filter('woocommerce_email_from_name', static function ($name) {
    return trim((string) $name) === '' ? ZOOBOXI_MAIL_FROM_NAME : $name;
});

// Envelope sender: only for mail that claims to be from zooboxi.com.
add_action('phpmailer_init', static function ($mailer) {
    if (str_ends_with(strtolower((string) $mailer->From), '@zooboxi.com')) {
        $mailer->Sender = $mailer->From;
    }
});
