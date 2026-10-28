<?php
/**
 * Zooboxi_Invoices — the shopper's simplified tax invoice.
 *
 * sapconnect posts a paid order to SAP as an A/R invoice and the ZATCA service signs
 * it; sapconnect then serves the result (JSON + the A4 PDF) to this store only. The
 * store is the one that knows whose order it is, so every way a shopper reaches the
 * invoice passes through here:
 *   - a 10-minute cron asks about recent paid orders, stamps `_zb_invoice_no` once the
 *     invoice is ready, and emails the PDF to the shopper (once);
 *   - «الفاتورة الضريبية» on the web order page streams the PDF (?zb_invoice=ID);
 *   - the app reads the same data through the v2 orders API.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Invoices
{
    public const META_NO     = '_zb_invoice_no';
    public const META_MAILED = '_zb_invoice_mailed';

    private const CRON       = 'zooboxi_invoice_poll';
    private const MAIL_SINCE = 'zooboxi_invoice_mail_since';
    private const INTERVAL   = 'zooboxi_ten_minutes';

    /** Gateways whose orders become SAP invoices (sapconnect config zooboxi_sap.gateways). */
    private const GATEWAYS = ['myfatoorah_v2', 'myfatoorah', 'tamara-gateway'];

    /** Order statuses that will never carry an invoice. */
    private const NOT_INVOICED = ['pending', 'failed', 'cancelled', 'refunded', 'checkout-draft', 'trash'];

    private static bool $shown = false;

    /** @var array<int,bool> the two HPOS column hooks both fire; draw each cell once */
    private static array $cells = [];

    public static function hooks(): void
    {
        add_filter('cron_schedules', [__CLASS__, 'schedules']);
        add_action(self::CRON, [__CLASS__, 'poll']);
        add_action('init', [__CLASS__, 'schedule']);
        add_action('template_redirect', [__CLASS__, 'serve_pdf']);
        add_action('woocommerce_order_details_after_order_table', [__CLASS__, 'order_page_button']);

        if (is_admin()) {
            // Orders list (HPOS, both hook variants) + the single-order screen: print the invoice.
            add_filter('manage_woocommerce_page_wc-orders_columns', [__CLASS__, 'admin_column']);
            add_action('manage_woocommerce_page_wc-orders_custom_column', [__CLASS__, 'admin_cell'], 10, 2);
            add_action('woocommerce_shop_order_list_table_custom_column', [__CLASS__, 'admin_cell'], 10, 2);
            add_action('woocommerce_admin_order_data_after_order_details', [__CLASS__, 'admin_detail']);
        }
    }

    public static function schedules(array $s): array
    {
        $s[self::INTERVAL] = ['interval' => 600, 'display' => 'Every 10 minutes (Zooboxi invoices)'];
        return $s;
    }

    public static function schedule(): void
    {
        // Orders paid before the invoice email existed are not mailed out of the blue.
        if (get_option(self::MAIL_SINCE) === false) {
            add_option(self::MAIL_SINCE, time(), '', false);
        }
        if (!wp_next_scheduled(self::CRON)) {
            wp_schedule_event(time() + 120, self::INTERVAL, self::CRON);
        }
    }

    /**
     * What the shopper sees about this order's invoice.
     *
     * @return array{status:string, number?:string}|null  null = this order gets no invoice
     */
    public static function state(\WC_Order $order, bool $shown = false): ?array
    {
        // A theme that places the invoice itself says so; the plugin's fallback button then stays out.
        self::$shown = self::$shown || $shown;

        $no = (string) $order->get_meta(self::META_NO);
        if ($no !== '') {
            return ['status' => 'ready', 'number' => $no];
        }
        return self::expects_invoice($order) ? ['status' => 'issuing'] : null;
    }

    private static function expects_invoice(\WC_Order $order): bool
    {
        return in_array($order->get_payment_method(), self::GATEWAYS, true)
            && $order->get_date_paid()
            && !in_array($order->get_status(), self::NOT_INVOICED, true);
    }

    /* ── sapconnect ─────────────────────────────────── */

    /** @return array{status:string, invoice:?array}|null  null = could not ask */
    public static function fetch(int $order_id): ?array
    {
        $res = self::get('/orders/' . $order_id . '/invoice', 'application/json', 10);
        if ($res === null) {
            return null;
        }
        $data = json_decode($res, true);
        return is_array($data) && isset($data['status']) ? $data : null;
    }

    /** The PDF bytes, or null until it is ready / when sapconnect cannot be reached. */
    public static function fetch_pdf(int $order_id): ?string
    {
        $pdf = self::get('/orders/' . $order_id . '/invoice/pdf', 'application/pdf', 60);
        return ($pdf !== null && strncmp($pdf, '%PDF', 4) === 0) ? $pdf : null;
    }

    private static function get(string $path, string $accept, int $timeout): ?string
    {
        $token = (string) get_option('zooboxi_api_token', '');
        if ($token === '') {
            return null;
        }
        $base = rtrim((string) get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $res  = wp_remote_get($base . $path, [
            'headers' => ['Authorization' => 'Bearer ' . $token, 'Accept' => $accept],
            'timeout' => $timeout,
        ]);
        if (is_wp_error($res) || (int) wp_remote_retrieve_response_code($res) !== 200) {
            return null;
        }
        return (string) wp_remote_retrieve_body($res);
    }

    /** The invoice JSON with the store's own product thumbnails (the app shows those everywhere else). */
    public static function for_app(\WC_Order $order): ?array
    {
        $data = self::fetch($order->get_id());
        if ($data === null) {
            return null;
        }
        if (($data['status'] ?? '') === 'ready' && is_array($data['invoice'] ?? null)) {
            self::mark_ready($order, (string) $data['invoice']['number']);
            foreach ($data['invoice']['lines'] as &$line) {
                $sku = (string) ($line['barcode'] ?? '');
                $id  = $sku !== '' ? wc_get_product_id_by_sku($sku) : 0;
                $product = $id ? wc_get_product($id) : null;
                if ($product && class_exists('Zooboxi_Product_DTO')) {
                    $line['image'] = Zooboxi_Product_DTO::image_url($product, 'woocommerce_thumbnail') ?: $line['image'];
                }
            }
            unset($line);
        }
        return $data;
    }

    private static function mark_ready(\WC_Order $order, string $number): bool
    {
        if ($number === '' || (string) $order->get_meta(self::META_NO) === $number) {
            return false;
        }
        $order->update_meta_data(self::META_NO, $number);
        $order->save();
        $order->add_order_note(sprintf('صدرت الفاتورة الضريبية المبسطة رقم %s.', $number));
        return true;
    }

    /* ── cron: stamp + email ─────────────────────────── */

    public static function poll(): void
    {
        $statuses = array_diff(array_map(static fn($s) => substr($s, 3), array_keys(wc_get_order_statuses())), self::NOT_INVOICED);
        $orders = wc_get_orders([
            'limit'          => 25,
            'status'         => array_values($statuses),
            'payment_method' => self::GATEWAYS,
            'date_created'   => '>' . (time() - 30 * DAY_IN_SECONDS),
            'orderby'        => 'date',
            'order'          => 'DESC',
            // Not yet mailed, not merely not yet stamped: the app or the admin screen can
            // stamp the number first, and the shopper must still get the email (#33282).
            'meta_query'     => [['key' => self::META_MAILED, 'compare' => 'NOT EXISTS']],
        ]);

        foreach ($orders as $order) {
            if (!($order instanceof \WC_Order) || !self::expects_invoice($order)) {
                continue;
            }
            $number = (string) $order->get_meta(self::META_NO);
            if ($number === '') {
                $data = self::fetch($order->get_id());
                if (($data['status'] ?? '') !== 'ready' || empty($data['invoice']['number'])) {
                    continue;
                }
                $number = (string) $data['invoice']['number'];
                self::mark_ready($order, $number);
            }
            // The invoice rides on «وصل طلبك» (mu-plugin zooboxi-emails). It goes alone only
            // when the order was completed before its number arrived, or is still not
            // delivered two days after payment.
            if (class_exists('Zooboxi_Mail_Hooks') && !$order->has_status('completed')) {
                $paid = $order->get_date_paid();
                if ($paid && $paid->getTimestamp() > time() - 2 * DAY_IN_SECONDS) {
                    continue;
                }
            }
            self::mail($order, $number);
        }
    }

    /** One email per order, with the PDF attached. */
    public static function mail(\WC_Order $order, string $number): bool
    {
        if ($order->get_meta(self::META_MAILED)) {
            return false;
        }
        $paid = $order->get_date_paid();
        if (!$paid || $paid->getTimestamp() < (int) get_option(self::MAIL_SINCE, 0)) {
            return false;
        }
        $email = (string) $order->get_billing_email();
        if ($email === '' || !is_email($email) || substr($email, -strlen('@zooboxi.local')) === '@zooboxi.local') {
            return false;
        }
        $pdf = self::fetch_pdf($order->get_id());
        if ($pdf === null) {
            return false;
        }

        $dir  = trailingslashit(get_temp_dir());
        $file = $dir . 'zooboxi-invoice-' . preg_replace('/\D/', '', $number) . '.pdf';
        file_put_contents($file, $pdf);

        $name = trim((string) $order->get_billing_first_name());
        $url  = $order->get_view_order_url();
        $body = '<div dir="rtl" style="text-align:right; font-size:15px; line-height:1.8">'
            . '<p>' . esc_html($name !== '' ? sprintf('أهلًا %s،', $name) : 'أهلًا،') . '</p>'
            . '<p>' . esc_html(sprintf('مرفقة لك الفاتورة الضريبية المبسطة رقم %s لطلبك #%s.', $number, $order->get_order_number())) . '</p>'
            . '<p>' . esc_html('تقدر تحمّلها في أي وقت من صفحة الطلب في حسابك أو من تطبيق زوبوكسي.') . '</p>'
            . '<p><a href="' . esc_url($url) . '" style="display:inline-block; background:#297978; color:#ffffff; padding:10px 22px; border-radius:999px; text-decoration:none; font-weight:bold">' . esc_html('عرض الطلب') . '</a></p>'
            . '<p style="color:#7A6260">' . esc_html('شكرًا لأنك اخترت زوبوكسي لأليفك.') . '</p>'
            . '</div>';

        if (class_exists('Zooboxi_Mail')) {
            // The customer's language and the store's email design (mu-plugin zooboxi-emails).
            $built = Zooboxi_Mail::invoice($order, $number);
            $sent  = (bool) wp_mail($email, $built['subject'], $built['html'], ['Content-Type: text/html; charset=UTF-8'], [$file]);
        } else {
            $mailer  = WC()->mailer();
            $subject = sprintf('فاتورتك الضريبية لطلب #%s — زوبوكسي', $order->get_order_number());
            $sent    = (bool) $mailer->send($email, $subject, $mailer->wrap_message('فاتورتك الضريبية', $body), ['Content-Type: text/html; charset=UTF-8'], [$file]);
        }
        @unlink($file);

        if ($sent) {
            $order->update_meta_data(self::META_MAILED, current_time('mysql'));
            $order->save();
            $order->add_order_note(sprintf('أُرسلت الفاتورة الضريبية %s إلى %s.', $number, $email));
        }
        return $sent;
    }

    /* ── web: My Account ─────────────────────────────── */

    public static function pdf_url(\WC_Order $order): string
    {
        return add_query_arg(['zb_invoice' => $order->get_id(), 'key' => $order->get_order_key()], home_url('/'));
    }

    /** The order's owner, an admin, or whoever holds the order key (the email link). */
    private static function may_view(\WC_Order $order): bool
    {
        if (current_user_can('manage_woocommerce')) {
            return true;
        }
        $user = get_current_user_id();
        if ($user && (int) $order->get_customer_id() === $user) {
            return true;
        }
        $key = isset($_GET['key']) ? sanitize_text_field(wp_unslash($_GET['key'])) : '';
        return $key !== '' && hash_equals((string) $order->get_order_key(), $key);
    }

    public static function serve_pdf(): void
    {
        if (empty($_GET['zb_invoice'])) {
            return;
        }
        $order = wc_get_order(absint($_GET['zb_invoice']));
        if (!($order instanceof \WC_Order) || !self::may_view($order)) {
            wp_die(esc_html('الفاتورة غير متاحة.'), '', ['response' => 404]);
        }
        $pdf = self::fetch_pdf($order->get_id());
        if ($pdf === null) {
            wp_die(esc_html('الفاتورة الضريبية قيد الإصدار، جرّب بعد دقائق.'), '', ['response' => 404]);
        }
        $no = (string) $order->get_meta(self::META_NO);
        nocache_headers();
        header('Content-Type: application/pdf');
        header('Content-Disposition: inline; filename="zooboxi-invoice-' . preg_replace('/\D/', '', $no ?: (string) $order->get_id()) . '.pdf"');
        header('Content-Length: ' . strlen($pdf));
        echo $pdf; // phpcs:ignore WordPress.Security.EscapeOutput
        exit;
    }

    public static function order_page_button(\WC_Order $order): void
    {
        if (self::$shown) {
            return;
        }
        $state = self::state($order);
        if ($state === null) {
            return;
        }
        if ($state['status'] === 'ready') {
            printf(
                '<p class="zb-invoice"><a class="button zb-invoice__btn" href="%s" target="_blank" rel="noopener">%s</a> <span class="zb-invoice__no">%s</span></p>',
                esc_url(self::pdf_url($order)),
                esc_html('تحميل الفاتورة الضريبية (PDF)'),
                esc_html(sprintf('رقم %s', $state['number']))
            );
            return;
        }
        echo '<p class="zb-invoice zb-invoice--pending">' . esc_html('الفاتورة الضريبية قيد الإصدار، وتوصلك على إيميلك أول ما تصدر.') . '</p>';
    }

    /* ── wp-admin: orders list + order screen ────────── */

    public static function admin_column(array $columns): array
    {
        $new = [];
        foreach ($columns as $key => $label) {
            $new[$key] = $label;
            if ($key === 'order_total') {
                $new['zb_invoice'] = 'الفاتورة';
            }
        }
        $new['zb_invoice'] ??= 'الفاتورة';
        return $new;
    }

    public static function admin_cell($column, $order): void
    {
        if ($column !== 'zb_invoice' || !($order instanceof \WC_Order) || isset(self::$cells[$order->get_id()])) {
            return;
        }
        self::$cells[$order->get_id()] = true;
        echo self::admin_html(self::state($order), $order); // phpcs:ignore WordPress.Security.EscapeOutput
    }

    /** The order screen asks sapconnect directly, so a just-issued invoice prints before the cron stamps it. */
    public static function admin_detail($order): void
    {
        if (!($order instanceof \WC_Order)) {
            return;
        }
        $state = self::state($order);
        if ($state !== null && $state['status'] === 'issuing') {
            $data = self::fetch($order->get_id());
            if (($data['status'] ?? '') === 'ready' && !empty($data['invoice']['number'])) {
                self::mark_ready($order, (string) $data['invoice']['number']);
                $state = self::state($order);
            }
        }
        if ($state === null) {
            return;
        }
        echo '<p class="form-field form-field-wide"><strong style="display:block;margin-bottom:4px">الفاتورة الضريبية:</strong>'
            . self::admin_html($state, $order) . '</p>'; // phpcs:ignore WordPress.Security.EscapeOutput
    }

    private static function admin_html(?array $state, \WC_Order $order): string
    {
        if ($state === null) {
            return '<span style="color:#a7aaad">—</span>';
        }
        if ($state['status'] !== 'ready') {
            return '<span style="color:#996800">قيد الإصدار</span>';
        }
        return sprintf(
            '<a class="button button-small" href="%s" target="_blank" rel="noopener" title="%s">🖨️ طباعة</a> <small style="color:#646970">%s</small>',
            esc_url(self::pdf_url($order)),
            esc_attr('طباعة الفاتورة الضريبية ' . $state['number']),
            esc_html($state['number'])
        );
    }
}
