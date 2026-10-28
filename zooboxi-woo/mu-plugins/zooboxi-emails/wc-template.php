<?php
/**
 * The HTML of a Zooboxi customer email (see zooboxi-emails.php). WooCommerce
 * includes this file in place of its own template, with `$email` in scope.
 */

defined('ABSPATH') || exit;

echo Zooboxi_Mail_Hooks::html($email); // phpcs:ignore WordPress.Security.EscapeOutput -- built from escaped parts
