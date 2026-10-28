<?php
/**
 * Zooboxi_Mail — every customer email of the order journey, in the order's
 * language («D · المزيج», owner-approved 2026-10-28).
 *
 * The language is the one the order was placed in (`_zooboxi_lang`, stamped at
 * checkout by the English website and, below, by the app); everything else is
 * Arabic. Names come from the catalogue's English meta when there is one;
 * what the customer typed (their name, the pet's, the address, a staff note)
 * stays as it was written.
 */

defined('ABSPATH') || exit;

final class Zooboxi_Mail
{
    public const LANG = '_zooboxi_lang';

    /** @var array<string,array{0:string,1:string}> */
    private const T = [
        'pill'             => ['طلب #%s', 'Order #%s'],
        'your_box'         => ['صندوقك', 'Your box'],
        'box_of'           => ['صندوق %s', "%s's box"],
        'items_meta'       => ['%1$d منتجات · %2$d قطع', '%1$d items · %2$d pieces'],
        'items_meta_one'   => ['منتج واحد · %d قطع', '1 item · %d pieces'],
        'qty'              => ['× %d', '× %d'],
        'subtotal'         => ['المجموع الفرعي', 'Subtotal'],
        'discount'         => ['الخصم', 'Discount'],
        'vat_note'         => ['شامل الضريبة 15٪ (%s)', 'Incl. 15%% VAT (%s)'],
        'track'            => ['تابع طلبك', 'Track your order'],
        'view'             => ['شوف طلبك', 'View your order'],
        'reply'            => ['تحتاج شي؟ رد على هذا الإيميل ونرد عليك.', 'Need anything? Just reply to this email.'],
        'apps'             => ['كل طلباتك ونقاط عائلة زوبوكسي في التطبيق', 'All your orders and Zooboxi Family rewards in the app'],
        'legal'            => ['متجر زوبوكسي · الرياض', 'Zooboxi Store · Riyadh'],
        'why'              => ['وصلتك هذه الرسالة لأنك طلبت من زوبوكسي.', "You're receiving this because you ordered from Zooboxi."],
        'pet_fallback'     => ['أليفك', 'your pet'],

        // the path
        'st_received'      => ['استلمنا', 'Received'],
        'st_packing'       => ['نجهّزه', 'Packing'],
        'st_packed'        => ['جهّزناه', 'Packed'],
        'st_way'           => ['في الطريق', 'On the way'],
        'st_done'          => ['وصل', 'Delivered'],

        // 01 received
        'rcv_subject'      => ['استلمنا طلبك #%1$s — %2$s', 'Order #%1$s is in — %2$s'],
        'rcv_title'        => ['طلبك صار عندنا!', 'Your order is in!'],
        'rcv_line'         => ['%1$s بيفرح يا %2$s — نجهّز صندوقه الحين.', '%1$s is in for a treat, %2$s — we are packing the box now.'],
        'rcv_line_anon'    => ['%s بيفرح — نجهّز صندوقه الحين.', '%s is in for a treat — we are packing the box now.'],
        'rcv_hold_line'    => ['بنأكد الدفع ونبدأ التجهيز على طول.', 'We are confirming your payment, then packing starts.'],
        'rcv_bubble'       => ['بجهّزه بنفسي!', "I'll pack it myself!"],
        'rcv_invoice'      => ['فاتورتك الضريبية توصلك مع رسالة التوصيل.', 'Your tax invoice comes with the delivery email.'],
        'pre_rcv'          => ['%1$s · %2$s · تابعه لحظة بلحظة', '%1$s · %2$s · Follow it live'],
        // promises
        'p_express_label'  => ['يوصلك خلال', 'Arriving within'],
        'p_express_big'    => ['ساعتين', '2 hours'],
        'p_express_small'  => ['من وقت طلبك %s', 'from your order at %s'],
        'p_express_stub'   => ['إكسبريس', 'Express'],
        'p_express_short'  => ['يوصلك خلال ساعتين', 'arriving within 2 hours'],
        'p_same_label'     => ['يوصلك', 'Arriving'],
        'p_same_big'       => ['اليوم', 'Today'],
        'p_same_stub'      => ['نفس اليوم', 'Same day'],
        'p_same_short'     => ['يوصلك اليوم', 'arriving today'],
        'p_ship_label'     => ['يوصلك خلال', 'Arriving within'],
        'p_ship_big'       => ['4–5 أيام', '4–5 days'],
        'p_ship_small'     => ['أيام عمل · %s', 'business days · %s'],
        'p_ship_stub'      => ['شحن', 'Shipping'],
        'p_ship_short'     => ['يوصلك خلال 4–5 أيام عمل', 'arriving in 4–5 business days'],

        // 02 payment
        'pay_subject'      => ['باقي خطوة على طلبك #%s', 'One step left on order #%s'],
        'pay_title'        => ['باقي خطوة وحدة', 'Just one more step'],
        'pay_line'         => ['الدفع ما اكتمل، وسلتك محفوظة كما هي.', "Your payment didn't go through — your basket is saved."],
        'pay_button'       => ['أكمل الدفع', 'Complete payment'],
        'pay_secure'       => ['الرابط يفتح صفحة دفع آمنة لنفس الطلب. تقدر تدفع بنفس الطريقة أو تختار غيرها.', 'The link opens a secure payment page for this same order — pay the same way or pick another.'],
        'pay_ignore'       => ['ما تبغى الطلب؟ تجاهل هذي الرسالة، وما راح نرسل غيرها.', "Changed your mind? Ignore this email — we won't send another."],
        'pay_total'        => ['الإجمالي شامل الضريبة', 'Total incl. VAT'],
        'pay_bubble'       => ['ننتظرك!', 'Waiting for you!'],
        'pend_subject'     => ['طلبك #%s ينتظر الدفع', 'Order #%s is waiting for payment'],
        'pend_line'        => ['طلبك محفوظ — باقي بس الدفع.', 'Your order is saved — only the payment is left.'],
        'pay_hold'         => ['نحجز لك المنتجات لين %s، وبعدها ينلغي الطلب تلقائياً.', "We're holding your items until %s — after that the order is cancelled automatically."],
        'can_bubble'       => ['نشوفك قريب!', 'See you soon!'],

        // 04 on the way
        'otw_subject'      => ['طلبك #%s في الطريق إليك', 'Order #%s is on its way'],
        'otw_title'        => ['في الطريق إليك!', 'On its way!'],
        'otw_line'         => ['المندوب استلم %s وجاي لك.', 'The courier has %s and is heading to you.'],
        'otw_label'        => ['المندوب', 'Your courier'],
        'otw_big'          => ['قرّب يوصل', 'Almost there'],
        'otw_stub'         => ['تتبّع', 'Track'],
        'otw_stub_sub'     => ['على الخريطة', 'on the map'],
        'otw_button'       => ['تتبّع المندوب على الخريطة', 'Track your courier'],
        'otw_app'          => ['في التطبيق تشوف المندوب يتحرك على الخريطة، ويوصلك إشعار لحظة وصوله.', 'In the app you can watch the courier on the map and get a ping the moment they arrive.'],
        'otw_app_link'     => ['حمّل تطبيق زوبوكسي', 'Get the Zooboxi app'],
        'shp_subject'      => ['طلبك #%s انشحن', 'Order #%s has shipped'],
        'shp_title'        => ['صندوقك انشحن!', 'Your box has shipped!'],
        'shp_line'         => ['سلّمناه لشركة الشحن، ويوصلك خلال 4–5 أيام عمل.', 'It is with the carrier and arrives in 4–5 business days.'],
        'shp_label'        => ['رقم الشحنة', 'Tracking number'],
        'pre_otw'          => ['تابع %s لحظة بلحظة', 'Follow %s live'],

        // 05 delivered
        'dlv_subject'      => ['وصل طلبك #%1$s — بالعافية على %2$s', 'Order #%1$s delivered — enjoy, %2$s!'],
        'dlv_title'        => ['وصل! بالعافية على %s', 'Delivered! Enjoy, %s'],
        'dlv_line'         => ['صندوق طلب #%s وصل.', 'The box for order #%s has arrived.'],
        'dlv_invoice'      => ['الفاتورة الضريبية', 'Tax invoice'],
        'dlv_invoice_sub'  => ['رقم %s · مرفقة بالإيميل', 'No. %s · attached'],
        'dlv_download'     => ['تحميل', 'Download'],
        'dlv_rate_title'   => ['وش رأي %s؟', 'What does %s think?'],
        'dlv_rate_line'    => ['نجمة وحدة تكفي — رأيك يساعد غيرك يختار لأليفه.', 'One tap is enough — your rating helps others choose.'],
        'dlv_rate_alt'     => ['قيّم %s', 'Rate %s'],
        'dlv_again_title'  => ['نفس الصندوق مرة ثانية؟', 'Same box again?'],
        'dlv_again_line'   => ['من صفحة طلبك تقدر تطلبه كامل مرة ثانية بأسعار اليوم.', "From your order page, reorder the whole box at today's prices."],
        'dlv_again'        => ['اطلبه مرة ثانية', 'Order it again'],
        'dlv_remind'       => ['أنبّهك قبل يخلص أكل %s؟ فعّل التذكير من التطبيق وأحسبها لك من طلباتك.', "Want a nudge before %s's food runs out? Turn on reminders in the app — I'll work it out from your orders."],
        'dlv_remind_link'  => ['افتح التطبيق', 'Open the app'],
        'pre_dlv'          => ['فاتورتك مرفقة · وش رأي %s؟', 'Your invoice is attached · What does %s think?'],
        'pre_dlv_noinv'    => ['وش رأي %s؟', 'What does %s think?'],
        'dlv_subject_anon' => ['وصل طلبك #%s — بالعافية', 'Order #%s delivered — enjoy!'],
        'dlv_title_anon'   => ['وصل! بالعافية', 'Delivered — enjoy!'],
        'dlv_rate_anon'    => ['وش رأيك؟', 'What do you think?'],
        'dlv_remind_anon'  => ['أنبّهك قبل يخلص الأكل؟ فعّل التذكير من التطبيق وأحسبها لك من طلباتك.', "Want a nudge before the food runs out? Turn on reminders in the app — I'll work it out from your orders."],
        'pre_dlv_anon'     => ['فاتورتك مرفقة · وش رأيك؟', 'Your invoice is attached · What do you think?'],
        'pre_dlv_bare'     => ['وش رأيك في طلبك؟', 'What do you think of your order?'],
        'ship_express'     => ['توصيل إكسبريس', 'Express delivery'],
        'ship_same_day'    => ['توصيل نفس اليوم', 'Same-day delivery'],
        'ship_shipping'    => ['الشحن', 'Shipping'],

        // 06 invoice alone
        'inv_subject'      => ['فاتورتك الضريبية لطلب #%s — زوبوكسي', 'Your tax invoice for order #%s — Zooboxi'],
        'inv_title'        => ['فاتورتك الضريبية', 'Your tax invoice'],
        'inv_line'         => ['مرفقة بهذا الإيميل، ومحفوظة في حسابك.', 'Attached to this email and saved in your account.'],
        'inv_no'           => ['رقم الفاتورة', 'Invoice no.'],
        'inv_order'        => ['الطلب', 'Order'],
        'inv_vat'          => ['ضريبة القيمة المضافة 15٪', 'VAT 15%'],
        'inv_total'        => ['الإجمالي شامل الضريبة', 'Total incl. VAT'],
        'inv_button'       => ['حمّل الفاتورة', 'Download the invoice'],
        'inv_more'         => ['تلقاها كمان في أي وقت من صفحة الطلب في حسابك، أو من «طلباتي» في التطبيق.', 'You can also find it any time on the order page in your account, or under «My orders» in the app.'],
        'pre_inv'          => ['فاتورة رقم %1$s · %2$s · PDF مرفق', 'Invoice %1$s · %2$s · PDF attached'],

        // 07 cancelled
        'can_subject'      => ['ألغينا طلبك #%s', 'Order #%s was cancelled'],
        'can_title'        => ['ألغينا طلبك', 'Your order was cancelled'],
        'can_line'         => ['طلب #%s انلغى.', 'Order #%s has been cancelled.'],
        'can_money'        => ['إذا انخصم منك مبلغ، فريقنا يرجّعه ويوصلك إيميل بالتفاصيل. وإذا عندك سؤال، رد على هذا الإيميل.', "If you were charged, our team will refund you and email the details. Any question — just reply."],
        'can_button'       => ['اطلب من جديد', 'Shop again'],

        // 08 refunded / 03 adjusted
        'ref_subject'      => ['رجّعنا مبلغ طلبك #%s', 'Refund for order #%s'],
        'adj_subject'      => ['تعديل على طلبك #%s', 'A change to order #%s'],
        'ref_title'        => ['رجّعنا مبلغك', 'Your refund is on its way'],
        'adj_title'        => ['تعديل بسيط على طلبك', 'A small change to your order'],
        'ref_line'         => ['رجّعنا مبلغ طلب #%s كامل.', 'We refunded order #%s in full.'],
        'adj_line'         => ['جزء من طلب #%s ما قدرنا نوصله، فرجّعنا فرقه.', "Part of order #%s couldn't be delivered, so we refunded the difference."],
        'ref_label'        => ['رجّعنا لك', 'Refunded'],
        'ref_to'           => ['إلى %s', 'to %s'],
        'ref_bank'         => ['يظهر في حسابك حسب بنكك، عادة خلال أيام عمل.', 'It shows in your account depending on your bank, usually within a few business days.'],
        'ref_changed'      => ['وش تغيّر', 'What changed'],
        'ref_was'          => ['الإجمالي السابق', 'Previous total'],
        'ref_now'          => ['الإجمالي الجديد', 'New total'],
        'ref_reason'       => ['السبب: %s', 'Reason: %s'],

        // 09 note
        'note_subject'     => ['رسالة بخصوص طلبك #%s', 'A note about order #%s'],
        'note_title'       => ['رسالة من فريقنا', 'A note from our team'],
        'note_line'        => ['بخصوص طلبك #%s', 'About your order #%s'],
    ];

    public static function t(string $key, string $lang, ...$args): string
    {
        $pair = self::T[$key] ?? [$key, $key];
        $text = $pair[$lang === 'en' ? 1 : 0];
        return $args ? vsprintf($text, $args) : $text;
    }

    /* ── language ─────────────────────────────────────── */

    public static function lang_of(\WC_Order $order): string
    {
        return (string) $order->get_meta(self::LANG) === 'en' ? 'en' : 'ar';
    }

    /** The app's checkout carries ?lang=en; the website stamps its own. */
    public static function stamp_app_language(\WC_Order $order): void
    {
        if ((string) $order->get_meta(self::LANG) !== '' || !(defined('REST_REQUEST') && REST_REQUEST)) {
            return;
        }
        $lang = isset($_GET['lang']) ? strtolower(sanitize_text_field(wp_unslash($_GET['lang']))) : '';
        if ($lang === '' && class_exists('Zooboxi_V2_Bootstrap')) {
            $lang = Zooboxi_V2_Bootstrap::lang();
        }
        if ($lang === 'en') {
            $order->update_meta_data(self::LANG, 'en');
        }
    }

    /** The customer's latest language, for the emails that are not about one order. */
    public static function remember_customer_language(int $order_id): void
    {
        $order = wc_get_order($order_id);
        if ($order instanceof \WC_Order && $order->get_customer_id()) {
            update_user_meta($order->get_customer_id(), self::LANG, self::lang_of($order));
        }
    }

    /* ── order data ───────────────────────────────────── */

    private static function url(string $url, string $lang): string
    {
        return $lang === 'en' && function_exists('zv_en_url') ? zv_en_url($url) : $url;
    }

    private static function pet(\WC_Order $order, string $lang): string
    {
        $uid = (int) $order->get_customer_id();
        if ($uid && class_exists('Zooboxi_Loyalty_Pets')) {
            $name = Zooboxi_Loyalty_Pets::first_name($uid, '', '');
            if (trim($name) !== '') {
                return trim($name);
            }
        }
        return '';
    }

    private static function product_name(\WC_Order_Item_Product $item, string $lang): string
    {
        $stored = wp_strip_all_tags($item->get_name());
        $product = $item->get_product();
        if ($lang !== 'en' || !($product instanceof \WC_Product)) {
            return $stored;
        }
        $id = $product->get_parent_id() ?: $product->get_id();
        $en = trim((string) get_post_meta($id, '_zooboxi_name_en', true));
        if ($en === '' && get_post_meta($id, '_zb_bundle_id', true) !== '' && class_exists('Zooboxi_V2_Bundles_Controller')) {
            $en = (string) Zooboxi_V2_Bundles_Controller::english_name($id);
        }
        if ($en === '') {
            return $stored;
        }
        return function_exists('zv_en_tidy') ? zv_en_tidy($en) : $en;
    }

    /** @return array<int,array{name:string,sub:string,image:string,amount:float,qty:int,url:string,product_id:int}> */
    private static function lines(\WC_Order $order, string $lang): array
    {
        $lines = [];
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            $product = $item->get_product();
            $image   = '';
            if ($product instanceof \WC_Product) {
                $image_id = $product->get_image_id() ?: ($product->get_parent_id() ? (int) get_post_thumbnail_id($product->get_parent_id()) : 0);
                $image    = $image_id ? (string) wp_get_attachment_image_url((int) $image_id, 'woocommerce_thumbnail') : '';
            }
            $qty = (int) $item->get_quantity();
            $pid = (int) $item->get_product_id();
            $lines[] = [
                'name'       => self::product_name($item, $lang),
                'sub'        => self::t('qty', $lang, $qty),
                'image'      => $image,
                'amount'     => (float) $item->get_total() + (float) $item->get_total_tax(),
                'qty'        => $qty,
                'product_id' => $pid,
                'url'        => $pid && get_post_status($pid) === 'publish' ? self::url((string) get_permalink($pid), $lang) : '',
            ];
        }
        return $lines;
    }

    private static function box_title(\WC_Order $order, string $lang): string
    {
        $pet = self::pet($order, $lang);
        return $pet !== '' ? self::t('box_of', $lang, $pet) : self::t('your_box', $lang);
    }

    private static function box_meta(array $lines, string $lang): string
    {
        $pieces = array_sum(array_column($lines, 'qty'));
        return count($lines) === 1 ? self::t('items_meta_one', $lang, $pieces) : self::t('items_meta', $lang, count($lines), $pieces);
    }

    private static function receipt(Zooboxi_Mail_Kit $kit, \WC_Order $order, array $lines): string
    {
        $lang     = $kit->lang;
        $type     = (string) $order->get_meta('_zooboxi_delivery_type');
        $shipping = (float) $order->get_shipping_total() + (float) $order->get_shipping_tax();
        $discount = (float) $order->get_discount_total() + (float) $order->get_discount_tax();
        $fees     = [];
        foreach ($order->get_fees() as $fee) {
            $fees[] = [wp_strip_all_tags($fee->get_name()), (float) $fee->get_total() + (float) $fee->get_total_tax()];
        }
        // The subtotal is what is left of the order's own total, so the rows always add up
        // to it (summing rounded lines drifted by a halala, #33284).
        $subtotal = (float) $order->get_total() - $shipping - array_sum(array_column($fees, 1)) + $discount;
        $totals   = [[self::t('subtotal', $lang), $subtotal]];
        if ($order->get_items('shipping')) {
            // Labelled by the delivery the customer chose: the method's stored title can lag
            // behind it (an express order carried «توصيل عادي (خلال 24 ساعة)»).
            $totals[] = [self::t($type === 'express' ? 'ship_express' : ($type === 'same_day' ? 'ship_same_day' : 'ship_shipping'), $lang), $shipping];
        }
        $totals = array_merge($totals, $fees);
        if ($discount > 0) {
            $totals[] = [self::t('discount', $lang), -$discount];
        }
        $note = self::t('vat_note', $lang, number_format((float) $order->get_total_tax(), 2));
        $method = trim(wp_strip_all_tags((string) $order->get_payment_method_title()));
        if ($method !== '') {
            $note .= ' · ' . $method;
        }
        return $kit->receipt(self::box_title($order, $lang), self::box_meta($lines, $lang), $lines, $totals, (float) $order->get_total(), $note);
    }

    private static function place(\WC_Order $order): string
    {
        $parts = array_filter([trim((string) $order->get_shipping_address_2()) ?: trim((string) $order->get_billing_address_2()), trim((string) $order->get_shipping_city()) ?: trim((string) $order->get_billing_city())]);
        $text  = implode('، ', $parts);
        return mb_strlen($text) > 48 ? mb_substr($text, 0, 46) . '…' : $text;
    }

    private static function time_of(\WC_Order $order, string $lang): string
    {
        $date = $order->get_date_paid() ?: $order->get_date_created();
        if (!$date) {
            return '';
        }
        $date->setTimezone(wp_timezone());
        $time = $date->format('g:i');
        return $time . ($lang === 'en' ? ($date->format('A') === 'AM' ? ' AM' : ' PM') : ($date->format('A') === 'AM' ? ' ص' : ' م'));
    }

    /** [label, big, small, stub icon, stub title, short] for the order's delivery type. */
    private static function promise(\WC_Order $order, string $lang): array
    {
        $type  = (string) $order->get_meta('_zooboxi_delivery_type');
        $place = self::place($order);
        if ($type === 'express') {
            return [self::t('p_express_label', $lang), self::t('p_express_big', $lang), self::t('p_express_small', $lang, self::time_of($order, $lang)), 'bolt.png', self::t('p_express_stub', $lang), self::t('p_express_short', $lang)];
        }
        if ($type === 'same_day') {
            return [self::t('p_same_label', $lang), self::t('p_same_big', $lang), $place, 'truck.png', self::t('p_same_stub', $lang), self::t('p_same_short', $lang)];
        }
        return [self::t('p_ship_label', $lang), self::t('p_ship_big', $lang), self::t('p_ship_small', $lang, $place), 'truck.png', self::t('p_ship_stub', $lang), self::t('p_ship_short', $lang)];
    }

    private static function footer(Zooboxi_Mail_Kit $kit, string $extra = ''): string
    {
        $lang = $kit->lang;
        return $kit->footer(
            $kit->footer_apps(self::t('apps', $lang), home_url('/app/'))
            . $kit->footer_line(esc_html(self::t('reply', $lang)), '15px', '#FFFFFF')
            . ($extra !== '' ? $kit->footer_line($extra) : '')
            . $kit->footer_line(esc_html(self::t('legal', $lang)) . '<br>' . esc_html(self::t('why', $lang)))
        );
    }

    private static function view_url(\WC_Order $order, string $lang): string
    {
        return self::url($order->get_view_order_url(), $lang);
    }

    /* ── the emails ───────────────────────────────────── */

    /** @return array{subject:string,html:string} */
    public static function received(\WC_Order $order, bool $on_hold = false): array
    {
        $lang  = self::lang_of($order);
        $kit   = new Zooboxi_Mail_Kit($lang);
        $lines = self::lines($order, $lang);
        $n     = $order->get_order_number();
        $name  = trim((string) $order->get_billing_first_name());
        $pet   = self::pet($order, $lang) ?: self::t('pet_fallback', $lang);
        [$label, $big, $small, $icon, $stub, $short] = self::promise($order, $lang);

        $line = $on_hold ? self::t('rcv_hold_line', $lang)
            : ($name !== '' ? self::t('rcv_line', $lang, self::ucfirst($pet), $name) : self::t('rcv_line_anon', $lang, self::ucfirst($pet)));

        $blocks = $kit->board('teal', self::t('pill', $lang, $n), self::t('rcv_title', $lang), $line, $kit->talking('cat-present', self::t('rcv_bubble', $lang)))
            . $kit->ticket($kit->ticket_main($label, esc_html($big), $small), $kit->ticket_stub($icon, $stub))
            . $kit->path([
                ['step-done.png', self::t('st_received', $lang), true],
                ['step-pack-current.png', self::t('st_packing', $lang), true],
                ['step-truck-todo.png', self::t('st_way', $lang), false],
                ['step-home-todo.png', self::t('st_done', $lang), false],
            ])
            . $kit->button(self::t('track', $lang), self::view_url($order, $lang))
            . self::receipt($kit, $order, $lines)
            . ($order->is_paid() ? $kit->signoff('dog-wave', esc_html(self::t('rcv_invoice', $lang)) . ' ' . esc_html(self::t('reply', $lang))) : '');

        $pre = self::t('pre_rcv', $lang, self::box_title($order, $lang), self::box_meta($lines, $lang));
        return [
            'subject' => self::t('rcv_subject', $lang, $n, $short),
            'html'    => $kit->page(self::t('rcv_title', $lang), $pre, $blocks, self::footer($kit)),
        ];
    }

    /** «أكمل الدفع»: after a failed payment, or ($reminder) an order left unpaid. */
    public static function payment(\WC_Order $order, bool $reminder = false): array
    {
        $lang  = self::lang_of($order);
        $kit   = new Zooboxi_Mail_Kit($lang);
        $lines = self::lines($order, $lang);
        $n     = $order->get_order_number();
        $line  = self::t($reminder ? 'pend_line' : 'pay_line', $lang);
        $hold  = self::hold_until($order, $lang);

        $basket = $kit->strip($lines)
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '" style="margin-top:14px;"><tr>'
            . '<td align="' . $kit->start . '" style="font-size:15px;color:' . Zooboxi_Mail_Kit::MUTED . ';">' . esc_html(self::t('pay_total', $lang)) . '</td>'
            . '<td align="' . $kit->end . '" style="color:' . Zooboxi_Mail_Kit::DEEP . ';">' . $kit->money((float) $order->get_total(), 22, 'teal') . '</td></tr></table>';

        $blocks = $kit->board('cream', self::t('pill', $lang, $n), self::t('pay_title', $lang), $line, $kit->talking('cat-sleep', self::t('pay_bubble', $lang), 120))
            . $kit->card(self::box_title($order, $lang), $basket)
            . $kit->button(self::t('pay_button', $lang), self::url($order->get_checkout_payment_url(), $lang))
            . ($hold !== '' ? $kit->text('<img src="' . esc_url(Zooboxi_Mail_Kit::img('clock.png')) . '" width="20" height="20" alt="" style="vertical-align:-4px;border:0;"> <b>' . esc_html(self::t('pay_hold', $lang, $hold)) . '</b>', '20px 32px 0', '15px', Zooboxi_Mail_Kit::INK) : '')
            . $kit->text('<img src="' . esc_url(Zooboxi_Mail_Kit::img('lock.png')) . '" width="20" height="20" alt="" style="vertical-align:-4px;border:0;"> ' . esc_html(self::t('pay_secure', $lang)), '20px 32px 0', '15px', Zooboxi_Mail_Kit::INK)
            . $kit->text(esc_html(self::t('pay_ignore', $lang)));

        return [
            'subject' => self::t($reminder ? 'pend_subject' : 'pay_subject', $lang, $n),
            'html'    => $kit->page(self::t('pay_title', $lang), $line, $blocks, self::footer($kit)),
        ];
    }

    /**
     * When WooCommerce cancels the unpaid order (its «hold stock» minutes after
     * it was placed), as «5:42 م» — or '' when it never does.
     */
    private static function hold_until(\WC_Order $order, string $lang): string
    {
        $minutes = (int) get_option('woocommerce_hold_stock_minutes', 0);
        $created = $order->get_date_created();
        if ($minutes <= 0 || get_option('woocommerce_manage_stock') !== 'yes' || !$created || !$order->has_status('pending')) {
            return '';
        }
        $until = new \WC_DateTime('@' . ($created->getTimestamp() + $minutes * MINUTE_IN_SECONDS));
        if ($until->getTimestamp() <= time()) {
            return '';
        }
        $until->setTimezone(wp_timezone());
        return $until->format('g:i') . ($lang === 'en' ? ($until->format('A') === 'AM' ? ' AM' : ' PM') : ($until->format('A') === 'AM' ? ' ص' : ' م'));
    }

    public static function on_the_way(\WC_Order $order): array
    {
        $lang     = self::lang_of($order);
        $kit      = new Zooboxi_Mail_Kit($lang);
        $lines    = self::lines($order, $lang);
        $n        = $order->get_order_number();
        $box      = self::box_title($order, $lang);
        $tracking = (string) $order->get_meta('_mrsool_tracking_url');
        $courier  = trim((string) $order->get_meta('_mrsool_courier_name'));
        $shipno   = trim((string) $order->get_meta('_shipgo_tracking'));
        $shipping = (string) $order->get_meta('_zooboxi_delivery_type') === 'shipping';
        $link     = $tracking !== '' ? $tracking : self::view_url($order, $lang);

        if ($shipping) {
            $title   = self::t('shp_title', $lang);
            $line    = self::t('shp_line', $lang);
            $ticket  = $kit->ticket(
                $kit->ticket_main(self::t('shp_label', $lang), $shipno !== '' ? '<span dir="ltr" style="font-size:30px;">' . esc_html($shipno) . '</span>' : esc_html(self::t('p_ship_big', $lang)), (string) $order->get_meta('_shipgo_carrier')),
                $kit->ticket_stub('truck.png', self::t('p_ship_stub', $lang))
            );
            $subject = self::t('shp_subject', $lang, $n);
        } else {
            $title   = self::t('otw_title', $lang);
            $line    = self::t('otw_line', $lang, $lang === 'en' ? lcfirst($box) : $box);
            $ticket  = $kit->ticket(
                $kit->ticket_main(self::t('otw_label', $lang), esc_html($courier !== '' ? $courier : self::t('otw_big', $lang)), self::place($order)),
                $kit->ticket_stub('pin.png', self::t('otw_stub', $lang), self::t('otw_stub_sub', $lang), '#8E3626'),
                '#FBE7E2',
                $link
            );
            $subject = self::t('otw_subject', $lang, $n);
        }

        $blocks = $kit->board('teal', self::t('pill', $lang, $n), $title, $line, $kit->art($kit->pic('otw-' . $kit->dir . '.png', 536, 'display:block;margin:0 auto;width:100%;max-width:536px;')))
            . $ticket
            . $kit->path([
                ['step-done.png', self::t('st_received', $lang), true],
                ['step-done.png', self::t('st_packed', $lang), true],
                ['step-truck-current.png', self::t('st_way', $lang), true],
                ['step-home-todo.png', self::t('st_done', $lang), false],
            ])
            . $kit->button($shipping ? self::t('track', $lang) : self::t('otw_button', $lang), $link)
            . $kit->card($box, $kit->strip($lines))
            . (!$shipping ? $kit->signoff('cat-wave', esc_html(self::t('otw_app', $lang)) . ' <a href="' . esc_url(home_url('/app/')) . '" style="font-weight:800;color:' . Zooboxi_Mail_Kit::BUTTON . ';">' . esc_html(self::t('otw_app_link', $lang)) . '</a>') : '');

        return [
            'subject' => $subject,
            'html'    => $kit->page($title, self::t('pre_otw', $lang, $box), $blocks, self::footer($kit)),
        ];
    }

    public static function delivered(\WC_Order $order, string $invoice_no = ''): array
    {
        $lang  = self::lang_of($order);
        $kit   = new Zooboxi_Mail_Kit($lang);
        $lines = self::lines($order, $lang);
        $n     = $order->get_order_number();
        $pet   = self::pet($order, $lang);
        $named = $pet !== '';

        $art = $kit->art($kit->pic('sparkle-amber.png', 22, 'margin:0 10px 120px;') . $kit->pic('cat-hug.png', 170) . $kit->pic('sparkle-cream.png', 28, 'margin:0 10px 90px;'));

        $stars = '';
        foreach ($lines as $i => $line) {
            if ($line['url'] === '') {
                continue;
            }
            $href = esc_url(add_query_arg('review', '1', $line['url']) . '#reviews');
            $five = str_repeat('<img src="' . esc_url(Zooboxi_Mail_Kit::img('star.png')) . '" width="20" height="20" alt="" style="display:inline-block;border:0;margin:0 1px;">', 5);
            $stars .= '<tr><td style="padding:12px 0;border-top:1px solid ' . Zooboxi_Mail_Kit::LINE . ';"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '"><tr>'
                . '<td width="56" style="padding-' . $kit->end . ':12px;">' . $kit->thumb($line['image'], 56) . '</td>'
                . '<td align="' . $kit->start . '" style="font-size:15px;font-weight:700;line-height:1.45;">' . esc_html($line['name']) . '</td>'
                . '<td align="' . $kit->end . '" style="white-space:nowrap;padding-' . $kit->start . ':8px;"><a href="' . $href . '" title="' . esc_attr(self::t('dlv_rate_alt', $lang, $line['name'])) . '" style="text-decoration:none;">' . $five . '</a></td>'
                . '</tr></table></td></tr>';
            if ($i >= 3) {
                break;
            }
        }

        $again = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="' . Zooboxi_Mail_Kit::BUTTON . '" style="background:' . Zooboxi_Mail_Kit::BUTTON . ';border-radius:26px;"><tr><td align="' . $kit->start . '" style="padding:24px;">'
            . '<div style="font-size:24px;font-weight:800;color:#FFF7EA;">' . esc_html(self::t('dlv_again_title', $lang)) . '</div>'
            . '<div style="font-size:15px;line-height:1.6;color:#D5ECE9;padding:6px 0 16px;">' . esc_html(self::t('dlv_again_line', $lang)) . '</div>'
            . '<a href="' . esc_url(self::view_url($order, $lang)) . '" style="display:inline-block;background:' . Zooboxi_Mail_Kit::CORAL . ';color:#FFFFFF;text-decoration:none;font-size:17px;font-weight:800;padding:13px 26px;border-radius:999px;">' . esc_html(self::t('dlv_again', $lang)) . '</a>'
            . '</td></tr></table>';

        $title  = $named ? self::t('dlv_title', $lang, $pet) : self::t('dlv_title_anon', $lang);
        $blocks = $kit->board('teal', self::t('pill', $lang, $n), $title, self::t('dlv_line', $lang, $n), $art)
            . ($invoice_no !== '' ? self::invoice_ticket($kit, $order, $invoice_no) : '')
            . ($stars !== '' ? $kit->card($named ? self::t('dlv_rate_title', $lang, $pet) : self::t('dlv_rate_anon', $lang), '<div style="font-size:15px;color:' . Zooboxi_Mail_Kit::MUTED . ';padding-bottom:8px;">' . esc_html(self::t('dlv_rate_line', $lang)) . '</div><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' . $stars . '</table>') : '')
            . $kit->row($again, '20px 16px 0')
            . $kit->signoff('cat-sit-up', esc_html($named ? self::t('dlv_remind', $lang, $pet) : self::t('dlv_remind_anon', $lang)) . ' <a href="' . esc_url(home_url('/app/')) . '" style="font-weight:800;color:' . Zooboxi_Mail_Kit::BUTTON . ';">' . esc_html(self::t('dlv_remind_link', $lang)) . '</a>');

        $pre = $named
            ? ($invoice_no !== '' ? self::t('pre_dlv', $lang, $pet) : self::t('pre_dlv_noinv', $lang, $pet))
            : ($invoice_no !== '' ? self::t('pre_dlv_anon', $lang) : self::t('pre_dlv_bare', $lang));
        return [
            'subject' => $named ? self::t('dlv_subject', $lang, $n, $pet) : self::t('dlv_subject_anon', $lang, $n),
            'html'    => $kit->page($title, $pre, $blocks, self::footer($kit)),
        ];
    }

    private static function invoice_ticket(Zooboxi_Mail_Kit $kit, \WC_Order $order, string $number): string
    {
        $lang = $kit->lang;
        $pdf  = '<table role="presentation" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '"><tr>'
            . '<td width="44" height="54" align="center" valign="bottom" bgcolor="' . Zooboxi_Mail_Kit::CORAL . '" style="background:' . Zooboxi_Mail_Kit::CORAL . ';border-radius:8px;color:#FFFFFF;font-size:12px;font-weight:800;padding-bottom:8px;">PDF</td>'
            . '<td style="padding-' . $kit->start . ':14px;"><div style="font-size:17px;font-weight:800;color:' . Zooboxi_Mail_Kit::INK . ';">' . esc_html(self::t('dlv_invoice', $lang)) . '</div>'
            . '<div style="font-size:14px;color:' . Zooboxi_Mail_Kit::MUTED . ';">' . esc_html(self::t('dlv_invoice_sub', $lang, $number)) . '</div></td></tr></table>';
        $url = class_exists('Zooboxi_Invoices') ? Zooboxi_Invoices::pdf_url($order) : self::view_url($order, $lang);
        return $kit->ticket($pdf, $kit->ticket_stub('download.png', self::t('dlv_download', $lang)), '#E4F2EF', $url);
    }

    public static function invoice(\WC_Order $order, string $number): array
    {
        $lang = self::lang_of($order);
        $kit  = new Zooboxi_Mail_Kit($lang);
        $n    = $order->get_order_number();
        $paid = $order->get_date_paid() ?: $order->get_date_created();

        $rows = '';
        foreach ([
            [self::t('inv_no', $lang), '<b>' . esc_html($number) . '</b>'],
            [self::t('inv_order', $lang), '<b>#' . esc_html($n) . '</b>'],
            [self::t('inv_vat', $lang), $kit->money((float) $order->get_total_tax(), 15)],
        ] as [$k, $v]) {
            $rows .= '<tr><td align="' . $kit->start . '" style="padding:11px 0;border-bottom:1px solid ' . Zooboxi_Mail_Kit::LINE . ';font-size:16px;color:' . Zooboxi_Mail_Kit::MUTED . ';">' . esc_html($k) . '</td>'
                . '<td align="' . $kit->end . '" style="padding:11px 0;border-bottom:1px solid ' . Zooboxi_Mail_Kit::LINE . ';font-size:16px;color:' . Zooboxi_Mail_Kit::INK . ';">' . $v . '</td></tr>';
        }
        $rows .= '<tr><td align="' . $kit->start . '" style="padding:14px 0 0;font-size:18px;font-weight:800;">' . esc_html(self::t('inv_total', $lang)) . '</td>'
            . '<td align="' . $kit->end . '" style="padding:14px 0 0;color:' . Zooboxi_Mail_Kit::DEEP . ';">' . $kit->money((float) $order->get_total(), 30, 'teal') . '</td></tr>';

        $blocks = $kit->board('teal', $paid ? self::date_of($paid, $lang) : '', self::t('inv_title', $lang), self::t('inv_line', $lang), $kit->talking('cat-sit-up', self::t('dlv_invoice_sub', $lang, $number), 110))
            . self::invoice_ticket($kit, $order, $number)
            . $kit->card('', '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '">' . $rows . '</table>')
            . $kit->button(self::t('inv_button', $lang), class_exists('Zooboxi_Invoices') ? Zooboxi_Invoices::pdf_url($order) : self::view_url($order, $lang), Zooboxi_Mail_Kit::BUTTON)
            . $kit->text(esc_html(self::t('inv_more', $lang)));

        return [
            'subject' => self::t('inv_subject', $lang, $n),
            'html'    => $kit->page(self::t('inv_title', $lang), self::t('pre_inv', $lang, $number, number_format((float) $order->get_total(), 2) . ($lang === 'en' ? ' SAR' : ' ر.س')), $blocks, self::footer($kit)),
        ];
    }

    public static function cancelled(\WC_Order $order): array
    {
        $lang = self::lang_of($order);
        $kit  = new Zooboxi_Mail_Kit($lang);
        $n    = $order->get_order_number();

        $blocks = $kit->board('cream', self::t('pill', $lang, $n), self::t('can_title', $lang), self::t('can_line', $lang, $n), $kit->talking('cat-sleep', self::t('can_bubble', $lang), 120))
            . $kit->card(self::box_title($order, $lang), $kit->strip(self::lines($order, $lang)))
            . $kit->text(esc_html(self::t('can_money', $lang)), '20px 32px 0', '16px', Zooboxi_Mail_Kit::INK)
            . $kit->button(self::t('can_button', $lang), self::url(home_url('/'), $lang), Zooboxi_Mail_Kit::BUTTON);

        return [
            'subject' => self::t('can_subject', $lang, $n),
            'html'    => $kit->page(self::t('can_title', $lang), self::t('can_line', $lang, $n), $blocks, self::footer($kit)),
        ];
    }

    public static function refunded(\WC_Order $order, ?\WC_Order_Refund $refund, bool $partial): array
    {
        $lang   = self::lang_of($order);
        $kit    = new Zooboxi_Mail_Kit($lang);
        $n      = $order->get_order_number();
        $amount = $refund ? abs((float) $refund->get_amount()) : (float) $order->get_total_refunded();
        $method = trim(wp_strip_all_tags((string) $order->get_payment_method_title()));

        $changed = '';
        if ($partial && $refund) {
            foreach ($refund->get_items() as $item) {
                if (!($item instanceof \WC_Order_Item_Product)) {
                    continue;
                }
                $changed .= '<tr><td style="padding:10px 0;border-top:1px solid ' . Zooboxi_Mail_Kit::LINE . ';"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '"><tr>'
                    . '<td align="' . $kit->start . '" style="font-size:15px;font-weight:700;">' . esc_html(self::product_name($item, $lang)) . '<div style="font-size:13px;font-weight:500;color:#9A3B2B;">' . esc_html('− ' . abs((int) $item->get_quantity())) . '</div></td>'
                    . '<td align="' . $kit->end . '" style="color:#9A3B2B;">' . $kit->money(abs((float) $item->get_total() + (float) $item->get_total_tax()), 15, 'coral') . '</td></tr></table></td></tr>';
            }
        }
        $reason = $refund ? trim((string) $refund->get_reason()) : '';

        $main   = $kit->ticket_main(self::t('ref_label', $lang), $kit->money($amount, 40, 'teal'), $method !== '' ? self::t('ref_to', $lang, $method) : '');
        $totals = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $kit->dir . '">'
            . '<tr><td align="' . $kit->start . '" style="padding:4px 0;font-size:15px;color:' . Zooboxi_Mail_Kit::MUTED . ';">' . esc_html(self::t('ref_was', $lang)) . '</td><td align="' . $kit->end . '" style="text-decoration:line-through;color:' . Zooboxi_Mail_Kit::MUTED . ';">' . $kit->money((float) $order->get_total(), 15, 'muted', '500') . '</td></tr>'
            . '<tr><td align="' . $kit->start . '" style="padding:6px 0;font-size:18px;font-weight:800;">' . esc_html(self::t('ref_now', $lang)) . '</td><td align="' . $kit->end . '" style="color:' . Zooboxi_Mail_Kit::DEEP . ';">' . $kit->money(max(0.0, (float) $order->get_total() - (float) $order->get_total_refunded()), 22, 'teal') . '</td></tr></table>';

        $blocks = $kit->board('cream', self::t('pill', $lang, $n), self::t($partial ? 'adj_title' : 'ref_title', $lang), self::t($partial ? 'adj_line' : 'ref_line', $lang, $n), $kit->talking('dog-present', $partial ? self::t('adj_title', $lang) : self::t('ref_title', $lang), 104))
            . $kit->ticket($main, $kit->ticket_stub('undo.png', $method !== '' ? $method : self::t('ref_label', $lang)))
            . $kit->text(esc_html(self::t('ref_bank', $lang)))
            . ($changed !== '' ? $kit->card(self::t('ref_changed', $lang), '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' . $changed . '</table>' . $totals) : '')
            . ($reason !== '' ? $kit->text(esc_html(self::t('ref_reason', $lang, $reason))) : '')
            . $kit->button(self::t('view', $lang), self::view_url($order, $lang), Zooboxi_Mail_Kit::BUTTON);

        return [
            'subject' => self::t($partial ? 'adj_subject' : 'ref_subject', $lang, $n),
            'html'    => $kit->page(self::t($partial ? 'adj_title' : 'ref_title', $lang), self::t($partial ? 'adj_line' : 'ref_line', $lang, $n), $blocks, self::footer($kit)),
        ];
    }

    public static function note(\WC_Order $order, string $note): array
    {
        $lang = self::lang_of($order);
        $kit  = new Zooboxi_Mail_Kit($lang);
        $n    = $order->get_order_number();

        $blocks = $kit->board('teal', self::t('pill', $lang, $n), self::t('note_title', $lang), self::t('note_line', $lang, $n))
            . $kit->signoff('dog-wave', nl2br(esc_html($note)))
            . $kit->button(self::t('view', $lang), self::view_url($order, $lang), Zooboxi_Mail_Kit::BUTTON, '8px 32px 0');

        return [
            'subject' => self::t('note_subject', $lang, $n),
            'html'    => $kit->page(self::t('note_title', $lang), wp_trim_words($note, 18), $blocks, self::footer($kit)),
        ];
    }

    /** «22 أكتوبر 2026» / "22 October 2026", in Riyadh time — the site locale is en_US, so not date_i18n. */
    private static function date_of(\WC_DateTime $date, string $lang): string
    {
        $date->setTimezone(wp_timezone());
        if ($lang === 'en') {
            return $date->format('j F Y');
        }
        $months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
        return $date->format('j') . ' ' . $months[(int) $date->format('n') - 1] . ' ' . $date->format('Y');
    }

    private static function ucfirst(string $s): string
    {
        return preg_match('/^[a-z]/', $s) ? ucfirst($s) : $s;
    }
}
