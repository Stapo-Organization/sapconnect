<?php
/**
 * Sign in — phone-first, because that is how this store's customers register.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

do_action('woocommerce_before_customer_login_form');

$zbx_register = 'yes' === get_option('woocommerce_enable_myaccount_registration');
$zbx_freemin  = zooboxi_free_shipping_min();
?>

<div class="zbx-auth">

    <aside class="zbx-auth__pitch">
        <span class="zbx-auth__mark" aria-hidden="true">🐾</span>
        <h2>حسابك في زوبوكسي</h2>
        <p>سجّل دخولك عشان تتابع طلباتك وتعيد شراء أصنافك بضغطة وحدة.</p>
        <ul>
            <li><span aria-hidden="true">🛵</span> تتبّع طلبك خطوة بخطوة</li>
            <li><span aria-hidden="true">🔁</span> إعادة الطلب من مشترياتك السابقة</li>
            <li><span aria-hidden="true">📍</span> عناوينك محفوظة — إتمام الطلب أسرع</li>
            <li><span aria-hidden="true">🎁</span> توصيل مجاني للطلبات فوق <?php echo wp_kses_post(wc_price($zbx_freemin)); ?></li>
        </ul>
    </aside>

    <div class="zbx-auth__forms">

        <button type="button" id="zbx-auth-otp" class="zbx-btn zbx-btn--solid zbx-auth__otp" hidden>
            <span aria-hidden="true">📱</span> الدخول برقم الجوال
        </button>
        <p class="zbx-auth__or" id="zbx-auth-or" hidden><span>أو بكلمة المرور</span></p>

        <form class="woocommerce-form woocommerce-form-login login zbx-form" method="post">

            <?php do_action('woocommerce_login_form_start'); ?>

            <p class="woocommerce-form-row form-row">
                <label for="username">رقم الجوال أو اسم المستخدم&nbsp;<span class="required">*</span></label>
                <input type="text" class="woocommerce-Input woocommerce-Input--text input-text" name="username" id="username"
                       autocomplete="username" dir="ltr"
                       value="<?php echo (!empty($_POST['username']) && is_string($_POST['username'])) ? esc_attr(wp_unslash($_POST['username'])) : ''; ?>" required />
            </p>

            <p class="woocommerce-form-row form-row">
                <label for="password">كلمة المرور&nbsp;<span class="required">*</span></label>
                <span class="zbx-pw">
                    <input class="woocommerce-Input woocommerce-Input--text input-text" type="password" name="password" id="password"
                           autocomplete="current-password" required />
                    <button type="button" class="zbx-pw__eye" aria-label="إظهار كلمة المرور">👁️</button>
                </span>
            </p>

            <?php do_action('woocommerce_login_form'); ?>

            <div class="zbx-auth__row">
                <label class="zbx-check">
                    <input class="woocommerce-form__input woocommerce-form__input-checkbox" name="rememberme" type="checkbox" value="forever" />
                    <span>تذكّرني</span>
                </label>
                <a class="zbx-auth__lost" href="<?php echo esc_url(wp_lostpassword_url()); ?>">نسيت كلمة المرور؟</a>
            </div>

            <p class="zbx-form__actions">
                <?php wp_nonce_field('woocommerce-login', 'woocommerce-login-nonce'); ?>
                <button type="submit" class="woocommerce-button woocommerce-form-login__submit zbx-btn zbx-btn--solid"
                        name="login" value="تسجيل الدخول">تسجيل الدخول</button>
            </p>

            <?php do_action('woocommerce_login_form_end'); ?>
        </form>

        <?php if ($zbx_register) : ?>
            <details class="zbx-auth__reg">
                <summary>ما عندك حساب؟ <strong>أنشئ حساب جديد</strong></summary>

                <form method="post" class="woocommerce-form woocommerce-form-register register zbx-form" <?php do_action('woocommerce_register_form_tag'); ?>>

                    <?php do_action('woocommerce_register_form_start'); ?>

                    <?php if ('no' === get_option('woocommerce_registration_generate_username')) : ?>
                        <p class="woocommerce-form-row form-row">
                            <label for="reg_username">اسم المستخدم&nbsp;<span class="required">*</span></label>
                            <input type="text" class="woocommerce-Input woocommerce-Input--text input-text" name="username" id="reg_username"
                                   autocomplete="username" dir="ltr"
                                   value="<?php echo (!empty($_POST['username'])) ? esc_attr(wp_unslash($_POST['username'])) : ''; ?>" required />
                        </p>
                    <?php endif; ?>

                    <p class="woocommerce-form-row form-row">
                        <label for="reg_email">البريد الإلكتروني&nbsp;<span class="required">*</span></label>
                        <input type="email" class="woocommerce-Input woocommerce-Input--text input-text" name="email" id="reg_email"
                               autocomplete="email" dir="ltr"
                               value="<?php echo (!empty($_POST['email'])) ? esc_attr(wp_unslash($_POST['email'])) : ''; ?>" required />
                    </p>

                    <?php if ('no' === get_option('woocommerce_registration_generate_password')) : ?>
                        <p class="woocommerce-form-row form-row">
                            <label for="reg_password">كلمة المرور&nbsp;<span class="required">*</span></label>
                            <input type="password" class="woocommerce-Input woocommerce-Input--text input-text" name="password"
                                   id="reg_password" autocomplete="new-password" required />
                        </p>
                    <?php else : ?>
                        <p class="zbx-fs__hint">سنرسل لك كلمة المرور على بريدك.</p>
                    <?php endif; ?>

                    <?php do_action('woocommerce_register_form'); ?>

                    <p class="zbx-form__actions">
                        <?php wp_nonce_field('woocommerce-register', 'woocommerce-register-nonce'); ?>
                        <button type="submit" class="woocommerce-Button woocommerce-form-register__submit zbx-btn zbx-btn--solid"
                                name="register" value="إنشاء الحساب">إنشاء الحساب</button>
                    </p>

                    <?php do_action('woocommerce_register_form_end'); ?>
                </form>
            </details>
        <?php endif; ?>

    </div>
</div>

<?php do_action('woocommerce_after_customer_login_form'); ?>
