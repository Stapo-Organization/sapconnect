<?php
/**
 * Plugin Name: Zooboxi — customer emails «D · المزيج»
 * Description: Every customer email of the order journey in the customer's own language (the order's `_zooboxi_lang`), in the owner-approved design D (2026-10-28). WooCommerce keeps sending its emails (settings, resend, triggers); only their content, subject and styles are ours. Adds «في الطريق إليك» for customers without the app, attaches the tax invoice to «وصل طلبك», and drops mail to the placeholder addresses of phone-only accounts.
 */

defined('ABSPATH') || exit;

require_once __DIR__ . '/zooboxi-emails/class-zooboxi-mail-kit.php';
require_once __DIR__ . '/zooboxi-emails/class-zooboxi-mail.php';

final class Zooboxi_Mail_Hooks
{
    /** WooCommerce email id → its HTML template. */
    private const TEMPLATES = [
        'customer_processing_order' => 'emails/customer-processing-order.php',
        'customer_on_hold_order'    => 'emails/customer-on-hold-order.php',
        'customer_failed_order'     => 'emails/customer-failed-order.php',
        'customer_completed_order'  => 'emails/customer-completed-order.php',
        'customer_refunded_order'   => 'emails/customer-refunded-order.php',
        'customer_cancelled_order'  => 'emails/customer-cancelled-order.php',
        'customer_note'             => 'emails/customer-note.php',
    ];

    public const META_OTW = '_zb_mail_on_the_way';
    public const META_PAY = '_zb_mail_pay_reminder';

    /** Minutes after an unpaid order is placed before «أكمل الدفع» goes out (hold stock is 60). */
    private const PAY_REMINDER_MINUTES = 20;

    /** @var array<string,array{subject:string,html:string}> built once per send */
    private static array $built = [];

    /** @var array<string,string> email key → attached invoice number */
    private static array $attached = [];

    public static function boot(): void
    {
        add_action('woocommerce_checkout_create_order', [Zooboxi_Mail::class, 'stamp_app_language'], 6);
        // Fired by WC_Checkout::create_order() — the website's checkout and the app's alike.
        add_action('woocommerce_checkout_order_created', static function ($order) {
            if ($order instanceof \WC_Order) {
                Zooboxi_Mail::remember_customer_language($order->get_id());
            }
        }, 20);

        foreach (array_keys(self::TEMPLATES) as $id) {
            add_filter('woocommerce_email_subject_' . $id, [__CLASS__, 'subject'], 99, 3);
        }
        add_filter('wc_get_template', [__CLASS__, 'template'], 99, 5);
        add_filter('woocommerce_email_styles', [__CLASS__, 'styles'], 99, 2);
        add_filter('woocommerce_email_attachments', [__CLASS__, 'attachments'], 20, 4);
        add_action('woocommerce_email_sent', [__CLASS__, 'sent'], 10, 3);
        add_filter('woocommerce_email_enabled_customer_cancelled_order', [__CLASS__, 'cancelled_only_if_paid'], 20, 3);

        add_action('woocommerce_order_status_zb-on-the-way', [__CLASS__, 'queue_on_the_way'], 20, 1);
        add_action('zooboxi_mail_on_the_way', [__CLASS__, 'on_the_way'], 10, 1);

        add_action('woocommerce_checkout_order_created', [__CLASS__, 'queue_pay_reminder'], 30);
        add_action('zooboxi_mail_pay_reminder', [__CLASS__, 'pay_reminder'], 10, 1);
        add_filter('woocommerce_email_enabled_customer_failed_order', [__CLASS__, 'failed_unless_reminded'], 20, 3);
        add_filter('user_has_cap', [__CLASS__, 'pay_with_key'], 20, 3);
        add_filter('woocommerce_order_email_verification_required', [__CLASS__, 'key_verifies_email'], 20, 3);

        add_filter('pre_wp_mail', [__CLASS__, 'skip_placeholders'], 10, 2);
    }

    /* ── WooCommerce's emails, our content ───────────────── */

    private static function key(\WC_Email $email): string
    {
        $object = $email->object;
        return $email->id . ':' . ($object instanceof \WC_Order ? $object->get_id() : 0) . ':' . (isset($email->refund) && $email->refund ? $email->refund->get_id() : 0);
    }

    /** Builds (once) what this WooCommerce email should say. */
    private static function build(\WC_Email $email): ?array
    {
        $order = $email->object;
        if (!($order instanceof \WC_Order) || !isset(self::TEMPLATES[$email->id])) {
            return null;
        }
        $key = self::key($email);
        if (isset(self::$built[$key])) {
            return self::$built[$key];
        }
        try {
            switch ($email->id) {
                case 'customer_processing_order':
                    $out = Zooboxi_Mail::received($order);
                    break;
                case 'customer_on_hold_order':
                    $out = Zooboxi_Mail::received($order, true);
                    break;
                case 'customer_failed_order':
                    $out = Zooboxi_Mail::payment($order);
                    break;
                case 'customer_completed_order':
                    $out = Zooboxi_Mail::delivered($order, self::invoice_number($order));
                    break;
                case 'customer_refunded_order':
                    $refund = isset($email->refund) && $email->refund instanceof \WC_Order_Refund ? $email->refund : null;
                    $out    = Zooboxi_Mail::refunded($order, $refund, !empty($email->partial_refund));
                    break;
                case 'customer_cancelled_order':
                    $out = Zooboxi_Mail::cancelled($order);
                    break;
                case 'customer_note':
                    $out = Zooboxi_Mail::note($order, (string) ($email->customer_note ?? ''));
                    break;
                default:
                    $out = null;
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi mail] ' . $email->id . ' #' . $order->get_id() . ': ' . $e->getMessage());
            $out = null; // WooCommerce's own template goes out instead — never no email
        }
        if ($out !== null) {
            self::$built[$key] = $out;
        }
        return $out;
    }

    public static function subject($subject, $order, $email = null)
    {
        if ($email instanceof \WC_Email && ($built = self::build($email))) {
            return $built['subject'];
        }
        return $subject;
    }

    /** The HTML template of our emails is a one-line file that prints what build() made. */
    public static function template($template, $template_name, $args, $template_path, $default_path)
    {
        $email = $args['email'] ?? null;
        if (!($email instanceof \WC_Email) || !empty($args['plain_text']) || (self::TEMPLATES[$email->id] ?? '') !== $template_name) {
            return $template;
        }
        return self::build($email) !== null ? __DIR__ . '/zooboxi-emails/wc-template.php' : $template;
    }

    public static function html(\WC_Email $email): string
    {
        return self::build($email)['html'] ?? '';
    }

    /** Our HTML carries its own inline styles; WooCommerce's sheet would restyle it. */
    public static function styles($css, $email = null)
    {
        return $email instanceof \WC_Email && isset(self::TEMPLATES[$email->id]) && $email->object instanceof \WC_Order && $email->get_email_type() !== 'plain' ? '' : $css;
    }

    /** Only an order that was paid gets «ألغينا طلبك» — unpaid ones simply expired. */
    public static function cancelled_only_if_paid($enabled, $order, $email = null)
    {
        return $order instanceof \WC_Order && $order->get_date_paid() !== null;
    }

    /* ── the tax invoice rides on «وصل طلبك» ─────────────── */

    private static function invoice_number(\WC_Order $order): string
    {
        return class_exists('Zooboxi_Invoices') ? (string) $order->get_meta(Zooboxi_Invoices::META_NO) : '';
    }

    public static function attachments($attachments, $email_id, $object, $email = null)
    {
        if ($email_id !== 'customer_completed_order' || !($object instanceof \WC_Order) || !class_exists('Zooboxi_Invoices')) {
            return $attachments;
        }
        $number = self::invoice_number($object);
        if ($number === '' || (string) $object->get_meta(Zooboxi_Invoices::META_MAILED) !== '') {
            return $attachments;
        }
        $pdf = Zooboxi_Invoices::fetch_pdf($object->get_id());
        if ($pdf === null) {
            return $attachments;
        }
        $file = trailingslashit(get_temp_dir()) . 'zooboxi-invoice-' . preg_replace('/\D/', '', $number) . '.pdf';
        file_put_contents($file, $pdf);
        $attachments   = (array) $attachments;
        $attachments[] = $file;
        self::$attached[$object->get_id()] = $number;
        return $attachments;
    }

    public static function sent($sent, $email_id, $email = null)
    {
        if ($email_id !== 'customer_completed_order' || !($email instanceof \WC_Email) || !($email->object instanceof \WC_Order)) {
            return;
        }
        $order = $email->object;
        $number = self::$attached[$order->get_id()] ?? '';
        if ($number === '') {
            return;
        }
        @unlink(trailingslashit(get_temp_dir()) . 'zooboxi-invoice-' . preg_replace('/\D/', '', $number) . '.pdf');
        if ($sent && class_exists('Zooboxi_Invoices')) {
            $order->update_meta_data(Zooboxi_Invoices::META_MAILED, current_time('mysql'));
            $order->save();
            $order->add_order_note(sprintf('أُرفقت الفاتورة الضريبية %s برسالة «وصل طلبك» إلى %s.', $number, $order->get_billing_email()));
        }
    }

    /* ── «في الطريق إليك» ─────────────────────────────────── */

    /** A minute later: the courier's name and tracking link arrive with the status push. */
    public static function queue_on_the_way($order_id): void
    {
        if (!wp_next_scheduled('zooboxi_mail_on_the_way', [(int) $order_id])) {
            wp_schedule_single_event(time() + 60, 'zooboxi_mail_on_the_way', [(int) $order_id]);
        }
    }

    public static function on_the_way($order_id): void
    {
        $order = wc_get_order((int) $order_id);
        if (!($order instanceof \WC_Order) || (string) $order->get_meta(self::META_OTW) !== '') {
            return;
        }
        $to = (string) $order->get_billing_email();
        if (!self::real_address($to)) {
            return;
        }
        // Express and same-day move in minutes: the app's push says it better. Email
        // only those without the app; a shipment (days, a tracking number) always.
        $shipping = (string) $order->get_meta('_zooboxi_delivery_type') === 'shipping';
        if (!$shipping && $order->get_customer_id() && class_exists('Zooboxi_Push') && Zooboxi_Push::devices_for((int) $order->get_customer_id())) {
            $order->update_meta_data(self::META_OTW, 'push');
            $order->save_meta_data();
            return;
        }
        $mail = Zooboxi_Mail::on_the_way($order);
        if (wp_mail($to, $mail['subject'], $mail['html'], ['Content-Type: text/html; charset=UTF-8'])) {
            $order->update_meta_data(self::META_OTW, current_time('mysql'));
            $order->save_meta_data();
            $order->add_order_note(sprintf('أُرسل إيميل «في الطريق إليك» إلى %s.', $to));
        }
    }

    /* ── «أكمل الدفع» for an order left unpaid ─────────────── */

    public static function queue_pay_reminder($order): void
    {
        if (!($order instanceof \WC_Order) || !$order->needs_payment() || $order->get_payment_method() === 'cod') {
            return;
        }
        $args = [(int) $order->get_id()];
        if (!wp_next_scheduled('zooboxi_mail_pay_reminder', $args)) {
            wp_schedule_single_event(time() + self::PAY_REMINDER_MINUTES * MINUTE_IN_SECONDS, 'zooboxi_mail_pay_reminder', $args);
        }
    }

    public static function pay_reminder($order_id): void
    {
        $order = wc_get_order((int) $order_id);
        // Still waiting, never paid, not reminded: a failed payment already got WooCommerce's
        // «أكمل الدفع», a paid or cancelled one needs nothing.
        if (!($order instanceof \WC_Order) || !$order->has_status('pending') || !$order->needs_payment() || $order->get_date_paid()
            || (string) $order->get_meta(self::META_PAY) !== '') {
            return;
        }
        $to = (string) $order->get_billing_email();
        if (!self::real_address($to)) {
            return;
        }
        $mail = Zooboxi_Mail::payment($order, true);
        if (wp_mail($to, $mail['subject'], $mail['html'], ['Content-Type: text/html; charset=UTF-8'])) {
            $order->update_meta_data(self::META_PAY, current_time('mysql'));
            $order->save_meta_data();
            $order->add_order_note(sprintf('أُرسل تذكير «أكمل الدفع» مع رابط السداد إلى %s.', $to));
        }
    }

    /** One «أكمل الدفع» per order: the reminder already carried the link. */
    public static function failed_unless_reminded($enabled, $order, $email = null)
    {
        return $order instanceof \WC_Order && (string) $order->get_meta(self::META_PAY) !== '' ? false : $enabled;
    }

    /** The order key in the link is the proof (as for guest orders); signing in on a phone first loses the sale. */
    private static function pay_link_order(): ?\WC_Order
    {
        if (empty($_GET['pay_for_order']) || empty($_GET['key'])) {
            return null;
        }
        $order_id = absint(get_query_var('order-pay'));
        $order    = $order_id ? wc_get_order($order_id) : null;
        $key      = sanitize_text_field(wp_unslash($_GET['key']));
        return $order instanceof \WC_Order && $order->needs_payment() && hash_equals((string) $order->get_order_key(), $key) ? $order : null;
    }

    public static function pay_with_key($allcaps, $caps, $args)
    {
        if (($args[0] ?? '') === 'pay_for_order' && empty($allcaps['pay_for_order'])) {
            $order = self::pay_link_order();
            if ($order && (int) ($args[2] ?? 0) === $order->get_id()) {
                $allcaps['pay_for_order'] = true;
            }
        }
        return $allcaps;
    }

    public static function key_verifies_email($required, $order = null, $context = '')
    {
        $link = self::pay_link_order();
        return $link && $order instanceof \WC_Order && $link->get_id() === $order->get_id() ? false : $required;
    }

    /* ── phone-only accounts ──────────────────────────────── */

    public static function real_address(string $email): bool
    {
        return $email !== '' && is_email($email) && !str_ends_with(strtolower($email), '@zooboxi.local');
    }

    /** OTP accounts start with «…@zooboxi.local»; mail to them only bounces. */
    public static function skip_placeholders($short, $atts)
    {
        $to = $atts['to'] ?? [];
        $to = is_array($to) ? $to : explode(',', (string) $to);
        $to = array_filter(array_map('trim', $to));
        if ($to && !array_filter($to, static fn($a) => self::real_address(preg_replace('/^.*<([^>]+)>.*$/', '$1', $a)))) {
            return false;
        }
        return $short;
    }
}

Zooboxi_Mail_Hooks::boot();
