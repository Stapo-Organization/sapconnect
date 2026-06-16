<?php
/**
 * Settings page for Zooboxi plugin.
 *
 * Card-based, RTL-first admin UI. Every setting has an info (ⓘ) button that opens
 * a modal explaining it in detail. The save handler and all option names are
 * unchanged — only the presentation. CSS/JS are scoped under `.zbx-settings`.
 */
class Zooboxi_Settings_Page
{
    public static function render(): void
    {
        if (!current_user_can('manage_woocommerce')) return;

        $saved = false;

        // Handle save
        if (isset($_POST['zooboxi_save_settings']) && check_admin_referer('zooboxi_settings')) {
            $fields = [
                'zooboxi_api_url', 'zooboxi_api_token',
                'zooboxi_express_fee', 'zooboxi_standard_fee', 'zooboxi_shipping_fee',
                'zooboxi_free_shipping_min', 'zooboxi_stock_sync_interval', 'zooboxi_default_price_list',
                'zooboxi_low_stock_threshold', 'zooboxi_new_days',
                'zooboxi_badge_pct_hot', 'zooboxi_badge_pct_back',
                'zooboxi_badge_pct_trend', 'zooboxi_badge_pct_new',
            ];
            foreach ($fields as $field) {
                if (isset($_POST[$field])) {
                    update_option($field, sanitize_text_field($_POST[$field]));
                }
            }
            // Badge percentile cutoffs are cached — recompute on next view.
            delete_transient('zooboxi_badge_cutoffs');
            // Checkboxes: absent in POST means "off", so set them explicitly.
            $toggles = [
                'zooboxi_smart_shipments', 'zooboxi_express_ranking',
                'zooboxi_recommended_sort', 'zooboxi_dynamic_badges',
                'zooboxi_fbt_block', 'zooboxi_clearance_collection',
                'zooboxi_sku_search',
            ];
            foreach ($toggles as $toggle) {
                update_option($toggle, isset($_POST[$toggle]) ? 'yes' : 'no');
            }
            $saved = true;
        }

        $help = self::help_content();

        self::styles();
        ?>
        <div class="wrap zbx-settings">
            <div class="zbx-hero">
                <div class="zbx-hero__logo">🐾</div>
                <div>
                    <h1><?php esc_html_e('إعدادات Zooboxi', 'zooboxi'); ?></h1>
                    <p><?php esc_html_e('التحكم بالتوصيل والمزامنة والميزات الذكية وأوسمة المنتجات — كلها من مكان واحد. اضغط ⓘ بجوار أي إعداد لشرحه.', 'zooboxi'); ?></p>
                </div>
            </div>

            <?php if ($saved): ?>
                <div class="zbx-saved">✓ <?php esc_html_e('تم حفظ الإعدادات بنجاح', 'zooboxi'); ?></div>
            <?php endif; ?>

            <form method="post">
                <?php wp_nonce_field('zooboxi_settings'); ?>

                <div class="zbx-grid">

                    <!-- ── الاتصال بـ sapconnect ── -->
                    <section class="zbx-card">
                        <header class="zbx-card__head">
                            <span class="zbx-card__icon">🔌</span>
                            <div>
                                <h2 class="zbx-card__title"><?php esc_html_e('الاتصال بـ sapconnect', 'zooboxi'); ?></h2>
                                <p class="zbx-card__sub"><?php esc_html_e('بيانات الربط مع نظام المزامنة', 'zooboxi'); ?></p>
                            </div>
                        </header>
                        <div class="zbx-card__body">
                            <div class="zbx-field zbx-field--stack">
                                <div class="zbx-label-row">
                                    <label class="zbx-field__label" for="zooboxi_api_url"><?php esc_html_e('رابط الـ API', 'zooboxi'); ?></label>
                                    <?php echo self::info_btn('api_url'); ?>
                                </div>
                                <div class="zbx-field__control zbx-field__control--full">
                                    <input type="url" class="zbx-input--full" name="zooboxi_api_url" id="zooboxi_api_url" value="<?php echo esc_attr(get_option('zooboxi_api_url')); ?>" placeholder="https://sapapi.muntajat.sa/api/woo">
                                </div>
                            </div>
                            <div class="zbx-field zbx-field--stack">
                                <div class="zbx-label-row">
                                    <label class="zbx-field__label" for="zooboxi_api_token"><?php esc_html_e('رمز الوصول (Token)', 'zooboxi'); ?></label>
                                    <?php echo self::info_btn('api_token'); ?>
                                </div>
                                <div class="zbx-field__control zbx-field__control--full">
                                    <input type="password" class="zbx-input--full" name="zooboxi_api_token" id="zooboxi_api_token" value="<?php echo esc_attr(get_option('zooboxi_api_token')); ?>" autocomplete="off">
                                </div>
                            </div>
                        </div>
                    </section>

                    <!-- ── المزامنة ── -->
                    <section class="zbx-card">
                        <header class="zbx-card__head">
                            <span class="zbx-card__icon">🔄</span>
                            <div>
                                <h2 class="zbx-card__title"><?php esc_html_e('المزامنة', 'zooboxi'); ?></h2>
                                <p class="zbx-card__sub"><?php esc_html_e('إعدادات استيراد البيانات من SAP', 'zooboxi'); ?></p>
                            </div>
                        </header>
                        <div class="zbx-card__body">
                            <div class="zbx-field">
                                <div class="zbx-field__main">
                                    <div class="zbx-label-row">
                                        <label class="zbx-field__label" for="zooboxi_default_price_list"><?php esc_html_e('قائمة الأسعار الافتراضية', 'zooboxi'); ?></label>
                                        <?php echo self::info_btn('price_list'); ?>
                                    </div>
                                    <p class="zbx-field__desc"><?php esc_html_e('رقم قائمة الأسعار المعتمدة من SAP عند المزامنة.', 'zooboxi'); ?></p>
                                </div>
                                <div class="zbx-field__control">
                                    <input type="number" class="zbx-input--num" name="zooboxi_default_price_list" id="zooboxi_default_price_list" value="<?php echo esc_attr(get_option('zooboxi_default_price_list', 1)); ?>" min="1">
                                </div>
                            </div>
                        </div>
                    </section>

                    <!-- ── رسوم التوصيل ── -->
                    <section class="zbx-card zbx-card--wide">
                        <header class="zbx-card__head">
                            <span class="zbx-card__icon">🚚</span>
                            <div>
                                <h2 class="zbx-card__title"><?php esc_html_e('رسوم التوصيل', 'zooboxi'); ?></h2>
                                <p class="zbx-card__sub"><?php esc_html_e('قيم الرسوم بالريال السعودي لكل نوع توصيل.', 'zooboxi'); ?></p>
                            </div>
                        </header>
                        <div class="zbx-card__body">
                            <div class="zbx-fees">
                                <?php
                                $fees = [
                                    'zooboxi_express_fee'      => ['⚡', __('توصيل سريع', 'zooboxi'), 15, 'express_fee'],
                                    'zooboxi_standard_fee'     => ['📦', __('توصيل عادي', 'zooboxi'), 10, 'standard_fee'],
                                    'zooboxi_shipping_fee'     => ['🚛', __('شحن وطني', 'zooboxi'), 25, 'shipping_fee'],
                                    'zooboxi_free_shipping_min'=> ['🎁', __('حد الشحن المجاني', 'zooboxi'), 200, 'free_shipping_min'],
                                ];
                                foreach ($fees as $name => $f): ?>
                                    <div class="zbx-fee">
                                        <span class="zbx-fee__ic"><?php echo $f[0]; ?></span>
                                        <div class="zbx-fee__top">
                                            <label class="zbx-fee__label" for="<?php echo esc_attr($name); ?>"><?php echo esc_html($f[1]); ?></label>
                                            <?php echo self::info_btn($f[3]); ?>
                                        </div>
                                        <div class="zbx-fee__input">
                                            <input type="number" name="<?php echo esc_attr($name); ?>" id="<?php echo esc_attr($name); ?>" value="<?php echo esc_attr(get_option($name, $f[2])); ?>" step="0.01" min="0">
                                            <span class="zbx-suffix"><?php esc_html_e('ر.س', 'zooboxi'); ?></span>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </section>

                    <!-- ── الميزات الذكية ── -->
                    <section class="zbx-card zbx-card--wide">
                        <header class="zbx-card__head">
                            <span class="zbx-card__icon">🚀</span>
                            <div>
                                <h2 class="zbx-card__title"><?php esc_html_e('الميزات الذكية', 'zooboxi'); ?></h2>
                                <p class="zbx-card__sub"><?php esc_html_e('تجربة التوصيل والترتيب والاقتراحات.', 'zooboxi'); ?></p>
                            </div>
                        </header>
                        <div class="zbx-card__body">
                            <?php
                            $features = [
                                'zooboxi_smart_shipments' => [
                                    __('الشحنات الذكية', 'zooboxi'),
                                    __('تقسيم السلة إلى شحنات حسب السرعة (سريع/عادي) برسوم منفصلة. ⚠️ اختبرها على طلب تجريبي قبل الإطلاق.', 'zooboxi'),
                                    'no', 'smart_shipments',
                                ],
                                'zooboxi_express_ranking' => [
                                    __('أولوية الفرع السريع في الترتيب', 'zooboxi'),
                                    __('عرض المنتجات المتوفّرة في فرع العميل (توصيل ساعتين) أولاً.', 'zooboxi'),
                                    'yes', 'express_ranking',
                                ],
                                'zooboxi_recommended_sort' => [
                                    __('ترتيب «موصى به» الافتراضي', 'zooboxi'),
                                    __('جعل الترتيب الذكي (درجة ذكاء المخزون) هو الافتراضي في صفحات المتجر.', 'zooboxi'),
                                    'yes', 'recommended_sort',
                                ],
                                'zooboxi_fbt_block' => [
                                    __('بلوك «يُشترى عادةً معاً»', 'zooboxi'),
                                    __('عرض المنتجات المكمّلة (FBT) أسفل صفحة المنتج.', 'zooboxi'),
                                    'yes', 'fbt_block',
                                ],
                                'zooboxi_clearance_collection' => [
                                    __('مجموعة «تصفية»', 'zooboxi'),
                                    __('تفعيل شورت كود [zooboxi_clearance] لعرض منتجات التصفية.', 'zooboxi'),
                                    'yes', 'clearance_collection',
                                ],
                                'zooboxi_sku_search' => [
                                    __('بحث المتجر بالباركود ورمز الصنف', 'zooboxi'),
                                    __('جعل بحث المتجر يطابق المنتج بالباركود (SKU) ورمز صنف SAP، إضافةً إلى الاسم.', 'zooboxi'),
                                    'yes', 'sku_search',
                                ],
                            ];
                            foreach ($features as $name => $f): ?>
                                <div class="zbx-field">
                                    <div class="zbx-field__main">
                                        <div class="zbx-label-row">
                                            <span class="zbx-field__label"><?php echo esc_html($f[0]); ?></span>
                                            <?php echo self::info_btn($f[3]); ?>
                                        </div>
                                        <p class="zbx-field__desc"><?php echo esc_html($f[1]); ?></p>
                                    </div>
                                    <div class="zbx-field__control">
                                        <label class="zbx-switch">
                                            <input type="checkbox" name="<?php echo esc_attr($name); ?>" value="yes" <?php checked(get_option($name, $f[2]), 'yes'); ?>>
                                            <span class="zbx-slider"></span>
                                        </label>
                                    </div>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </section>

                    <!-- ── أوسمة المنتجات ── -->
                    <section class="zbx-card zbx-card--wide">
                        <header class="zbx-card__head">
                            <span class="zbx-card__icon">🏷️</span>
                            <div>
                                <h2 class="zbx-card__title"><?php esc_html_e('أوسمة المنتجات', 'zooboxi'); ?></h2>
                                <p class="zbx-card__sub"><?php esc_html_e('الأوسمة الذكية على بطاقات وصفحات المنتجات.', 'zooboxi'); ?></p>
                            </div>
                        </header>
                        <div class="zbx-card__body">
                            <div class="zbx-field">
                                <div class="zbx-field__main">
                                    <div class="zbx-label-row">
                                        <span class="zbx-field__label"><?php esc_html_e('تفعيل الأوسمة الديناميكية', 'zooboxi'); ?></span>
                                        <?php echo self::info_btn('dynamic_badges'); ?>
                                    </div>
                                    <p class="zbx-field__desc"><?php esc_html_e('عرض الأوسمة (الأكثر طلباً / بقي X قطع / وصل حديثاً…) تلقائياً.', 'zooboxi'); ?></p>
                                </div>
                                <div class="zbx-field__control">
                                    <label class="zbx-switch">
                                        <input type="checkbox" name="zooboxi_dynamic_badges" value="yes" <?php checked(get_option('zooboxi_dynamic_badges', 'yes'), 'yes'); ?>>
                                        <span class="zbx-slider"></span>
                                    </label>
                                </div>
                            </div>
                            <div class="zbx-field">
                                <div class="zbx-field__main">
                                    <div class="zbx-label-row">
                                        <label class="zbx-field__label" for="zooboxi_low_stock_threshold"><?php esc_html_e('عتبة وسم «بقي X قطع»', 'zooboxi'); ?></label>
                                        <?php echo self::info_btn('low_stock_threshold'); ?>
                                    </div>
                                    <p class="zbx-field__desc"><?php esc_html_e('يظهر وسم الندرة عندما يكون المتاح للعميل ≤ هذا الرقم.', 'zooboxi'); ?></p>
                                </div>
                                <div class="zbx-field__control">
                                    <input type="number" class="zbx-input--num" name="zooboxi_low_stock_threshold" id="zooboxi_low_stock_threshold" value="<?php echo esc_attr(get_option('zooboxi_low_stock_threshold', 5)); ?>" min="1" max="50">
                                    <span class="zbx-suffix"><?php esc_html_e('قطعة', 'zooboxi'); ?></span>
                                </div>
                            </div>
                            <div class="zbx-field">
                                <div class="zbx-field__main">
                                    <div class="zbx-label-row">
                                        <label class="zbx-field__label" for="zooboxi_new_days"><?php esc_html_e('نافذة وسم «وصل حديثاً»', 'zooboxi'); ?></label>
                                        <?php echo self::info_btn('new_days'); ?>
                                    </div>
                                    <p class="zbx-field__desc"><?php esc_html_e('يُعدّ المنتج «جديداً» إذا أُضيف خلال هذه المدة.', 'zooboxi'); ?></p>
                                </div>
                                <div class="zbx-field__control">
                                    <input type="number" class="zbx-input--num" name="zooboxi_new_days" id="zooboxi_new_days" value="<?php echo esc_attr(get_option('zooboxi_new_days', 45)); ?>" min="1" max="180">
                                    <span class="zbx-suffix"><?php esc_html_e('يوم', 'zooboxi'); ?></span>
                                </div>
                            </div>

                            <div class="zbx-subhead">
                                <div class="zbx-label-row">
                                    <h3><?php esc_html_e('نسبة عرض كل وسم', 'zooboxi'); ?></h3>
                                    <?php echo self::info_btn('badge_pct'); ?>
                                </div>
                                <p><?php esc_html_e('يظهر كل وسم فقط على أعلى هذه النسبة من المنتجات المؤهّلة له (مرتّبةً بدرجة الذكاء) فيبقى مميّزاً. اكتب 100% لعرضه على الكل.', 'zooboxi'); ?></p>
                            </div>
                            <div class="zbx-badges">
                                <?php
                                $badge_tunes = [
                                    'hot'   => ['🔥', __('الأكثر طلباً', 'zooboxi'),          30,  '#fdefe3', '#c2410c', 'pct_hot'],
                                    'back'  => ['🔄', __('سريع النفاد — متوفّر الآن', 'zooboxi'),100, '#e9f1fe', '#1d4ed8', 'pct_back'],
                                    'trend' => ['📈', __('رائج الآن', 'zooboxi'),             25,  '#f6eafc', '#7e22ce', 'pct_trend'],
                                    'new'   => ['✨', __('وصل حديثاً', 'zooboxi'),            10,  '#e8f6ee', '#166534', 'pct_new'],
                                ];
                                foreach ($badge_tunes as $key => $b):
                                    $opt = 'zooboxi_badge_pct_' . $key; ?>
                                    <div class="zbx-badge-tune">
                                        <div class="zbx-tune-top">
                                            <span class="zbx-pill" style="background:<?php echo esc_attr($b[3]); ?>;color:<?php echo esc_attr($b[4]); ?>"><?php echo $b[0]; ?> <?php echo esc_html($b[1]); ?></span>
                                            <?php echo self::info_btn($b[5]); ?>
                                        </div>
                                        <div class="zbx-tune-row">
                                            <label for="<?php echo esc_attr($opt); ?>"><?php esc_html_e('أعلى', 'zooboxi'); ?></label>
                                            <input type="number" class="zbx-input--num" name="<?php echo esc_attr($opt); ?>" id="<?php echo esc_attr($opt); ?>" value="<?php echo esc_attr(get_option($opt, $b[2])); ?>" min="1" max="100">
                                            <span class="zbx-suffix">%</span>
                                            <span class="zbx-tune-hint"><?php esc_html_e('من المؤهّلين', 'zooboxi'); ?></span>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </section>

                </div>

                <div class="zbx-save">
                    <button type="submit" name="zooboxi_save_settings" class="button button-primary"><?php esc_html_e('حفظ الإعدادات', 'zooboxi'); ?></button>
                </div>
            </form>

            <!-- Help modal -->
            <div class="zbx-modal" id="zbx-modal" hidden>
                <div class="zbx-modal__backdrop" data-close></div>
                <div class="zbx-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="zbx-modal-title">
                    <button type="button" class="zbx-modal__close" data-close aria-label="<?php esc_attr_e('إغلاق', 'zooboxi'); ?>">&times;</button>
                    <h3 class="zbx-modal__title" id="zbx-modal-title"></h3>
                    <div class="zbx-modal__body"></div>
                </div>
            </div>
        </div>

        <script>
        window.ZBX_HELP = <?php echo wp_json_encode($help); ?>;
        (function () {
            function init() {
                var modal = document.getElementById('zbx-modal');
                if (!modal) return;
                var help = window.ZBX_HELP || {};
                var titleEl = modal.querySelector('.zbx-modal__title');
                var bodyEl = modal.querySelector('.zbx-modal__body');
                function open(key) {
                    var h = help[key];
                    if (!h) return;
                    titleEl.textContent = h.title || '';
                    bodyEl.innerHTML = h.body || '';
                    modal.hidden = false;
                    document.body.classList.add('zbx-modal-open');
                }
                function close() {
                    modal.hidden = true;
                    document.body.classList.remove('zbx-modal-open');
                }
                document.querySelectorAll('.zbx-info').forEach(function (btn) {
                    btn.addEventListener('click', function (e) {
                        e.preventDefault();
                        open(btn.getAttribute('data-help'));
                    });
                });
                modal.addEventListener('click', function (e) {
                    if (e.target.hasAttribute('data-close')) close();
                });
                document.addEventListener('keydown', function (e) {
                    if (e.key === 'Escape' && !modal.hidden) close();
                });
            }
            if (document.readyState !== 'loading') { init(); }
            else { document.addEventListener('DOMContentLoaded', init); }
        })();
        </script>
        <?php
    }

    /** A small info (ⓘ) button that opens the help modal for $key. */
    private static function info_btn(string $key): string
    {
        return '<button type="button" class="zbx-info" data-help="' . esc_attr($key) . '" aria-label="' . esc_attr__('شرح الإعداد', 'zooboxi') . '">'
            . '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
            . '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>'
            . '</button>';
    }

    /**
     * Detailed per-setting explanations shown in the modal. Keyed by the same
     * slug passed to info_btn(). Bodies are trusted, hardcoded HTML.
     *
     * @return array<string,array{title:string,body:string}>
     */
    private static function help_content(): array
    {
        return [
            'api_url' => [
                'title' => __('رابط الـ API (sapconnect)', 'zooboxi'),
                'body'  => __('<p>العنوان الذي يتصل به المتجر بخدمة <strong>sapconnect</strong> لجلب المنتجات والمخزون والأسعار من نظام SAP.</p><p>القيمة المعتادة: <code>https://sapapi.muntajat.sa/api/woo</code>. لا تغيّره إلا إذا تغيّر دومين الخدمة.</p><p>إذا كان فارغاً أو خاطئاً تتوقف المزامنة بالكامل.</p>', 'zooboxi'),
            ],
            'api_token' => [
                'title' => __('رمز الوصول (Token)', 'zooboxi'),
                'body'  => __('<p>مفتاح المصادقة السري للاتصال بـ sapconnect — اعتبره كلمة سر ولا تشاركه.</p><p>إذا تغيّر الرمز في الخادم لازم تحدّثه هنا، وإلا تفشل المزامنة برسالة صلاحيات (401/403).</p>', 'zooboxi'),
            ],
            'price_list' => [
                'title' => __('قائمة الأسعار الافتراضية', 'zooboxi'),
                'body'  => __('<p>رقم قائمة الأسعار في SAP التي تُعتمد كسعر بيع عند المزامنة. SAP يدعم عدة قوائم أسعار لكل صنف (تجزئة، جملة…).</p><p><strong>تأكد</strong> من مطابقة الرقم لقائمة البيع بالتجزئة الصحيحة، وإلا تُستورد أسعار غير صحيحة للمتجر.</p>', 'zooboxi'),
            ],
            'express_fee' => [
                'title' => __('رسوم التوصيل السريع', 'zooboxi'),
                'body'  => __('<p>الرسوم (بالريال) للتوصيل خلال <strong>ساعتين</strong> من الفرع/المعرض القريب من العميل.</p><p>تظهر في السلة والدفع عند توفّر التوصيل السريع لموقع العميل. اكتب <strong>0</strong> لجعله مجانياً.</p>', 'zooboxi'),
            ],
            'standard_fee' => [
                'title' => __('رسوم التوصيل العادي', 'zooboxi'),
                'body'  => __('<p>رسوم التوصيل خلال <strong>24 ساعة</strong> من المستودع داخل نفس مدينة العميل.</p><p>اكتب <strong>0</strong> لجعله مجانياً.</p>', 'zooboxi'),
            ],
            'shipping_fee' => [
                'title' => __('رسوم الشحن الوطني', 'zooboxi'),
                'body'  => __('<p>رسوم الشحن (<strong>4–5 أيام عمل</strong>) من المستودع الرئيسي إلى بقية المدن خارج نطاق التوصيل المحلي.</p><p>اكتب <strong>0</strong> لجعله مجانياً.</p>', 'zooboxi'),
            ],
            'free_shipping_min' => [
                'title' => __('حد الشحن المجاني', 'zooboxi'),
                'body'  => __('<p>إجمالي السلة الذي عنده يصبح الشحن <strong>مجانياً</strong>.</p><p>مثال: <code>200</code> يعني الطلبات ≥ 200 ر.س تُشحن مجاناً.</p><p>ارفع الرقم لزيادة متوسط قيمة الطلب، أو اخفضه لتشجيع الطلبات الصغيرة.</p>', 'zooboxi'),
            ],
            'smart_shipments' => [
                'title' => __('الشحنات الذكية', 'zooboxi'),
                'body'  => __('<p>يقسّم سلة العميل تلقائياً إلى <strong>شحنات حسب سرعة التوفّر</strong> (سريع / عادي / شحن) برسوم منفصلة لكل شحنة، في طلب ودفعة واحدة.</p><p>مفيد حين تكون منتجات السلة في مستودعات مختلفة.</p><p>⚠️ ميزة متقدمة — <strong>اختبرها على طلب تجريبي</strong> قبل تفعيلها للعملاء.</p>', 'zooboxi'),
            ],
            'express_ranking' => [
                'title' => __('أولوية الفرع السريع في الترتيب', 'zooboxi'),
                'body'  => __('<p>عند تفعيله، المنتجات المتوفّرة في فرع العميل (القابلة للتوصيل خلال ساعتين) تظهر <strong>أولاً</strong> في صفحات المتجر.</p><p>يعتمد على موقع العميل المُكتشف، فيرى أولاً ما يصله بسرعة.</p>', 'zooboxi'),
            ],
            'recommended_sort' => [
                'title' => __('ترتيب «موصى به» الافتراضي', 'zooboxi'),
                'body'  => __('<p>يجعل <strong>الترتيب الذكي</strong> (درجة ذكاء المخزون: الطلب + التوفّر + صحة الصنف) هو الافتراضي في المتجر بدل الأحدث/الاسم.</p><p>يرفع المنتجات الأعلى أداءً وتوفّراً إلى الأعلى تلقائياً.</p>', 'zooboxi'),
            ],
            'fbt_block' => [
                'title' => __('بلوك «يُشترى عادةً معاً»', 'zooboxi'),
                'body'  => __('<p>يعرض أسفل صفحة المنتج اقتراحات لمنتجات <strong>مكمّلة</strong> (Frequently Bought Together) مبنية على تحليل الطلبات الفعلية.</p><p>يرفع متوسط قيمة السلة عبر البيع المتقاطع.</p>', 'zooboxi'),
            ],
            'clearance_collection' => [
                'title' => __('مجموعة «تصفية»', 'zooboxi'),
                'body'  => __('<p>يفعّل الشورت كود <code>[zooboxi_clearance]</code> الذي يعرض منتجات التصفية (الراكدة أو قرب انتهاء الصلاحية المرشّحة للتخفيض).</p><p>ضعه في أي صفحة لعرض مجموعة التصفية. التخفيضات <strong>اقتراحية</strong> ولا تكسر سعر الجملة.</p>', 'zooboxi'),
            ],
            'sku_search' => [
                'title' => __('بحث المتجر بالباركود ورمز الصنف', 'zooboxi'),
                'body'  => __('<p>افتراضياً بحث WooCommerce يطابق <strong>اسم المنتج فقط</strong> — ومنتجاتنا اسمها عربي، والباركود مخزّن كـ SKU ورمز SAP في حقل داخلي، فالبحث بهما كان يرجع فارغاً.</p><p>عند تفعيله، يبحث المتجر أيضاً في <strong>الباركود (SKU)</strong> و<strong>رمز صنف SAP</strong> (مثل <code>P12600221</code>) فيجد المنتج بأيٍّ منهما.</p><p>لا يضعف بحث الاسم العربي — يضيف نتائج فقط.</p>', 'zooboxi'),
            ],
            'dynamic_badges' => [
                'title' => __('الأوسمة الديناميكية', 'zooboxi'),
                'body'  => __('<p>المفتاح الرئيسي لكل الأوسمة الذكية على المنتجات: <strong>الأكثر طلباً، سريع النفاد، رائج الآن، وصل حديثاً، بقي X قطع</strong>.</p><p>إيقافه يخفيها كلها. الأوسمة تتحدّث تلقائياً مع بيانات المخزون والذكاء.</p>', 'zooboxi'),
            ],
            'low_stock_threshold' => [
                'title' => __('عتبة وسم «بقي X قطع»', 'zooboxi'),
                'body'  => __('<p>يظهر وسم الندرة (⏳ بقي X قطع فقط) حين يكون المتاح للعميل في فرعه <strong>≤ هذا الرقم</strong>.</p><p>مبني على نفس المخزون الذي يحدّ كمية الإضافة للسلة، فلا يتناقض معه أبداً.</p><p>مثال: <code>5</code> = يظهر عند بقاء 5 قطع أو أقل. <strong>لا يخضع</strong> لنسبة العرض لأنه حقيقة مخزون وليس ترتيباً.</p>', 'zooboxi'),
            ],
            'new_days' => [
                'title' => __('نافذة وسم «وصل حديثاً»', 'zooboxi'),
                'body'  => __('<p>المدة (أيام) التي يُعدّ خلالها المنتج «جديداً» منذ إضافته.</p><p>مثال: <code>45</code> = أي منتج أُضيف خلال آخر 45 يوماً مؤهّل للوسم.</p><p>المؤهّلون يُفلترون بعدها بنسبة العرض أدناه.</p>', 'zooboxi'),
            ],
            'badge_pct' => [
                'title' => __('نسبة عرض كل وسم', 'zooboxi'),
                'body'  => __('<p>لتفادي إغراق المتجر بالأوسمة، يظهر كل وسم فقط على <strong>أعلى نسبة % من المنتجات المؤهّلة له</strong>، مرتّبةً بدرجة الذكاء (rank score).</p><ul><li><strong>30%</strong> = أفضل 30% من المؤهّلين يحصلون على الوسم.</li><li><strong>100%</strong> = كل المؤهّلين.</li></ul><p>التحكم منفصل لكل وسم. تتجدّد العتبات تلقائياً مع تحديث بيانات الذكاء.</p>', 'zooboxi'),
            ],
            'pct_hot' => [
                'title' => __('نسبة وسم «الأكثر طلباً» 🔥', 'zooboxi'),
                'body'  => __('<p>المنتج <strong>مؤهّل</strong> إذا كان من نجوم المبيعات (فئة A في تحليل ABC أو منتج بطل).</p><p>يظهر الوسم على أعلى هذه النسبة من المؤهّلين فقط. مثال: <code>30%</code> = أفضل 30% من نجوم المبيعات.</p>', 'zooboxi'),
            ],
            'pct_back' => [
                'title' => __('نسبة وسم «سريع النفاد — متوفّر الآن» 🔄', 'zooboxi'),
                'body'  => __('<p>المنتج مؤهّل إذا أثبت أنه <strong>ينفد بسرعة</strong> لكنه متوفّر الآن (حالة starved).</p><p>هذه الحالة نادرة أصلاً، لذا الافتراضي <code>100%</code> (اعرضه على الكل). اخفض النسبة لو أردت قصره على الأهم.</p>', 'zooboxi'),
            ],
            'pct_trend' => [
                'title' => __('نسبة وسم «رائج الآن» 📈', 'zooboxi'),
                'body'  => __('<p>المنتج مؤهّل إذا كان <strong>سريع الحركة</strong> (طلب fast) وليس من الأبطال.</p><p>يظهر على أعلى هذه النسبة من المؤهّلين بدرجة الذكاء. <code>25%</code> افتراضياً.</p>', 'zooboxi'),
            ],
            'pct_new' => [
                'title' => __('نسبة وسم «وصل حديثاً» ✨', 'zooboxi'),
                'body'  => __('<p>من بين المنتجات ضمن نافذة «وصل حديثاً» (بالأعلى)، يظهر الوسم على أعلى هذه النسبة فقط — أي <strong>أفضل الوافدين الجدد</strong> بدرجة الذكاء.</p><p>لأن كل الكتالوج استُورد حديثاً، النسبة المنخفضة (<code>10%</code>) ضرورية وإلا ظهر الوسم على كل المنتجات.</p>', 'zooboxi'),
            ],
        ];
    }

    /** Scoped styles for the settings page (no external asset needed). */
    private static function styles(): void
    {
        ?>
        <style id="zbx-settings-css">
        .zbx-settings{max-width:1100px}
        .zbx-settings *{box-sizing:border-box}
        .zbx-settings .zbx-hero{display:flex;align-items:center;gap:18px;margin:18px 0 20px;padding:24px 28px;
            border-radius:18px;color:#fff;background:linear-gradient(135deg,#0d9488 0%,#0f766e 100%);
            box-shadow:0 12px 30px rgba(13,148,136,.28)}
        .zbx-settings .zbx-hero__logo{font-size:42px;line-height:1;filter:drop-shadow(0 2px 5px rgba(0,0,0,.25))}
        .zbx-settings .zbx-hero h1{margin:0 0 3px;padding:0;color:#fff;font-size:24px;font-weight:800;line-height:1.2}
        .zbx-settings .zbx-hero p{margin:0;font-size:13px;opacity:.92}
        .zbx-settings .zbx-saved{margin:0 0 18px;padding:12px 16px;border-radius:12px;font-weight:700;font-size:13px;
            color:#065f46;background:#dcfce7;border:1px solid #86efac}

        .zbx-settings .zbx-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;align-items:start}
        .zbx-settings .zbx-card{background:#fff;border:1px solid #e6eae8;border-radius:16px;overflow:hidden;
            box-shadow:0 1px 3px rgba(15,23,42,.05)}
        .zbx-settings .zbx-card--wide{grid-column:1 / -1}
        .zbx-settings .zbx-card__head{display:flex;align-items:center;gap:12px;padding:15px 18px;
            border-bottom:1px solid #eef1f0;background:#fbfdfc}
        .zbx-settings .zbx-card__icon{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;
            font-size:20px;background:#e6f6f3;flex-shrink:0}
        .zbx-settings .zbx-card__title{margin:0;padding:0;font-size:15.5px;font-weight:800;color:#0f172a}
        .zbx-settings .zbx-card__sub{margin:2px 0 0;font-size:12px;color:#6b7a85}
        .zbx-settings .zbx-card__body{padding:4px 18px 12px}

        .zbx-settings .zbx-field{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;
            padding:14px 0;border-bottom:1px solid #f1f4f3}
        .zbx-settings .zbx-field:last-child{border-bottom:0}
        .zbx-settings .zbx-field--stack{flex-direction:column;align-items:stretch;gap:8px}
        .zbx-settings .zbx-field__main{min-width:0}
        .zbx-settings .zbx-label-row{display:flex;align-items:center;gap:6px}
        .zbx-settings .zbx-field__label{display:block;font-weight:700;font-size:13.5px;color:#1e293b}
        .zbx-settings .zbx-field__desc{margin:5px 0 0;font-size:12px;line-height:1.6;color:#6b7a85}
        .zbx-settings .zbx-field__control{flex-shrink:0;display:flex;align-items:center;gap:8px}
        .zbx-settings .zbx-field__control--full{width:100%}

        /* Info button */
        .zbx-settings .zbx-info{display:inline-flex;align-items:center;justify-content:center;width:22px;height:22px;
            padding:0;border:0;border-radius:50%;background:#eef2f1;color:#64748b;cursor:pointer;flex-shrink:0;
            transition:background .15s,color .15s,transform .1s}
        .zbx-settings .zbx-info:hover{background:#0d9488;color:#fff}
        .zbx-settings .zbx-info:active{transform:scale(.92)}
        .zbx-settings .zbx-info:focus-visible{outline:0;box-shadow:0 0 0 3px rgba(13,148,136,.3)}

        .zbx-settings input[type=text],.zbx-settings input[type=url],
        .zbx-settings input[type=password],.zbx-settings input[type=number]{
            border:1px solid #d7dedb;border-radius:10px;padding:9px 12px;font-size:13px;background:#fff;
            min-height:0;line-height:1.4;box-shadow:none;transition:border-color .15s,box-shadow .15s}
        .zbx-settings input:focus{border-color:#0d9488;box-shadow:0 0 0 3px rgba(13,148,136,.15);outline:0}
        .zbx-settings .zbx-input--full{width:100%}
        .zbx-settings .zbx-input--num{width:88px;text-align:center}
        .zbx-settings .zbx-suffix{font-size:13px;font-weight:700;color:#475569}

        /* Toggle switch (direction-agnostic via logical properties) */
        .zbx-settings .zbx-switch{position:relative;display:inline-block;width:46px;height:26px;flex-shrink:0}
        .zbx-settings .zbx-switch input{position:absolute;opacity:0;width:0;height:0}
        .zbx-settings .zbx-slider{position:absolute;inset:0;cursor:pointer;background:#cbd5e1;border-radius:999px;
            transition:background .2s}
        .zbx-settings .zbx-slider::before{content:"";position:absolute;height:20px;width:20px;inset-block-start:3px;
            inset-inline-start:3px;background:#fff;border-radius:50%;box-shadow:0 1px 3px rgba(0,0,0,.25);
            transition:inset-inline-start .2s}
        .zbx-settings .zbx-switch input:checked + .zbx-slider{background:#0d9488}
        .zbx-settings .zbx-switch input:checked + .zbx-slider::before{inset-inline-start:23px}
        .zbx-settings .zbx-switch input:focus-visible + .zbx-slider{box-shadow:0 0 0 3px rgba(13,148,136,.3)}

        /* Fees grid */
        .zbx-settings .zbx-fees{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;padding:8px 0}
        .zbx-settings .zbx-fee{border:1px solid #eef1f0;border-radius:14px;padding:14px;text-align:center;background:#fff}
        .zbx-settings .zbx-fee__ic{font-size:22px;display:block;margin-bottom:6px}
        .zbx-settings .zbx-fee__top{display:flex;align-items:center;justify-content:center;gap:6px;margin-bottom:10px}
        .zbx-settings .zbx-fee__label{font-size:12.5px;font-weight:700;color:#334155}
        .zbx-settings .zbx-fee__input{display:flex;align-items:center;justify-content:center;gap:6px}
        .zbx-settings .zbx-fee__input input{width:84px;text-align:center}

        /* Badge tuning */
        .zbx-settings .zbx-subhead{padding:16px 0 4px;border-top:1px solid #f1f4f3;margin-top:6px}
        .zbx-settings .zbx-subhead h3{margin:0;font-size:14px;font-weight:800;color:#0f172a}
        .zbx-settings .zbx-subhead p{margin:5px 0 0;font-size:12px;line-height:1.6;color:#6b7a85}
        .zbx-settings .zbx-badges{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;padding:12px 0 4px}
        .zbx-settings .zbx-badge-tune{display:flex;flex-direction:column;gap:12px;padding:15px;
            border:1px solid #eef1f0;border-radius:14px;background:#fff}
        .zbx-settings .zbx-tune-top{display:flex;align-items:center;justify-content:space-between;gap:8px}
        .zbx-settings .zbx-pill{display:inline-flex;align-items:center;gap:5px;
            font-size:11.5px;font-weight:800;padding:6px 12px;border-radius:999px}
        .zbx-settings .zbx-tune-row{display:flex;align-items:center;gap:8px}
        .zbx-settings .zbx-tune-row label{font-size:12.5px;font-weight:700;color:#475569}
        .zbx-settings .zbx-tune-hint{font-size:11.5px;color:#94a3b8}

        /* Save bar */
        .zbx-settings .zbx-save{position:sticky;bottom:0;z-index:5;margin-top:20px;padding:14px 0;
            background:linear-gradient(to top,#f0f0f1 65%,rgba(240,240,241,0))}
        .zbx-settings .zbx-save .button-primary{background:#0d9488;border-color:#0f766e;color:#fff;
            border-radius:10px;height:auto;padding:9px 30px;font-size:14px;font-weight:700;
            box-shadow:0 6px 16px rgba(13,148,136,.32);text-shadow:none}
        .zbx-settings .zbx-save .button-primary:hover,
        .zbx-settings .zbx-save .button-primary:focus{background:#0f766e;border-color:#0f766e}

        /* Help modal */
        body.zbx-modal-open{overflow:hidden}
        .zbx-settings .zbx-modal{position:fixed;inset:0;z-index:100000;display:flex;align-items:center;
            justify-content:center;padding:20px}
        .zbx-settings .zbx-modal[hidden]{display:none}
        .zbx-settings .zbx-modal__backdrop{position:absolute;inset:0;background:rgba(15,23,42,.55)}
        .zbx-settings .zbx-modal__dialog{position:relative;z-index:1;width:100%;max-width:480px;background:#fff;
            border-radius:18px;padding:24px 26px;box-shadow:0 25px 60px rgba(0,0,0,.32);
            animation:zbxpop .18s ease}
        @keyframes zbxpop{from{opacity:0;transform:translateY(10px) scale(.98)}to{opacity:1;transform:none}}
        .zbx-settings .zbx-modal__close{position:absolute;inset-block-start:14px;inset-inline-end:16px;border:0;
            width:30px;height:30px;border-radius:50%;background:#f1f5f4;color:#475569;font-size:20px;line-height:1;
            cursor:pointer}
        .zbx-settings .zbx-modal__close:hover{background:#e2e8e0}
        .zbx-settings .zbx-modal__title{margin:0 0 12px;font-size:18px;font-weight:800;color:#0f172a;
            padding-inline-end:36px}
        .zbx-settings .zbx-modal__body{font-size:13.5px;line-height:1.85;color:#334155}
        .zbx-settings .zbx-modal__body p{margin:0 0 10px}
        .zbx-settings .zbx-modal__body p:last-child{margin-bottom:0}
        .zbx-settings .zbx-modal__body ul{margin:0 0 10px;padding-inline-start:20px;list-style:disc}
        .zbx-settings .zbx-modal__body li{margin:0 0 5px}
        .zbx-settings .zbx-modal__body strong{color:#0f172a}
        .zbx-settings .zbx-modal__body code{background:#f1f5f4;padding:1px 6px;border-radius:6px;font-size:12.5px}

        @media (max-width:960px){
            .zbx-settings .zbx-grid,.zbx-settings .zbx-badges{grid-template-columns:1fr}
            .zbx-settings .zbx-fees{grid-template-columns:repeat(2,1fr)}
        }
        </style>
        <?php
    }
}
