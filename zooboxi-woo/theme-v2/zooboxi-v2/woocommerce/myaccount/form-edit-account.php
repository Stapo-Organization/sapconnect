<?php
/**
 * Account details — grouped into plain-language sections.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

do_action('woocommerce_before_edit_account_form');

$zbx_phone    = (string) get_user_meta($user->ID, 'billing_phone', true);
$zbx_internal = zooboxi_is_internal_email($user->user_email);
?>

<form class="woocommerce-EditAccountForm edit-account zbx-form" action="" method="post" <?php do_action('woocommerce_edit_account_form_tag'); ?>>

    <?php do_action('woocommerce_edit_account_form_start'); ?>

    <div class="zbx-fs">
        <h3 class="zbx-fs__legend"><span aria-hidden="true">👤</span> بياناتك</h3>
        <p class="zbx-fs__note">الاسم يظهر في تأكيد الطلب وعند التسليم</p>

        <div class="zbx-fs__grid">
            <p class="woocommerce-form-row form-row">
                <label for="account_first_name">الاسم الأول&nbsp;<span class="required">*</span></label>
                <input type="text" class="woocommerce-Input woocommerce-Input--text input-text" name="account_first_name"
                       id="account_first_name" autocomplete="given-name" value="<?php echo esc_attr($user->first_name); ?>" required />
            </p>
            <p class="woocommerce-form-row form-row">
                <label for="account_last_name">اسم العائلة&nbsp;<span class="required">*</span></label>
                <input type="text" class="woocommerce-Input woocommerce-Input--text input-text" name="account_last_name"
                       id="account_last_name" autocomplete="family-name" value="<?php echo esc_attr($user->last_name); ?>" required />
            </p>
        </div>

        <p class="woocommerce-form-row form-row">
            <label for="account_display_name">الاسم الظاهر&nbsp;<span class="required">*</span></label>
            <input type="text" class="woocommerce-Input woocommerce-Input--text input-text" name="account_display_name"
                   id="account_display_name" value="<?php echo esc_attr($user->display_name); ?>" required />
            <span class="zbx-fs__hint">هذا الاسم الذي نخاطبك به داخل المتجر</span>
        </p>
    </div>

    <div class="zbx-fs">
        <h3 class="zbx-fs__legend"><span aria-hidden="true">📇</span> وسائل التواصل</h3>

        <?php if ($zbx_phone) : ?>
            <p class="woocommerce-form-row form-row zbx-locked">
                <label for="zbx_login_phone">رقم الجوال</label>
                <input type="tel" id="zbx_login_phone" class="input-text" value="<?php echo esc_attr($zbx_phone); ?>" readonly dir="ltr" />
                <span class="zbx-fs__hint"><span aria-hidden="true">🔒</span> هذا رقمك للدخول والتوصيل — لتغييره تواصل مع الدعم</span>
            </p>
        <?php endif; ?>

        <p class="woocommerce-form-row form-row">
            <label for="account_email">البريد الإلكتروني<?php echo $zbx_internal ? ' <span class="zbx-opt">(اختياري)</span>' : '&nbsp;<span class="required">*</span>'; ?></label>
            <input type="email" class="woocommerce-Input woocommerce-Input--email input-text" name="account_email"
                   id="account_email" autocomplete="email" dir="ltr"
                   placeholder="<?php echo $zbx_internal ? 'name@example.com' : ''; ?>"
                   value="<?php echo esc_attr($zbx_internal ? '' : $user->user_email); ?>" />
            <span class="zbx-fs__hint">
                <?php echo $zbx_internal
                    ? 'أضف بريدك لتصلك فواتير الطلبات وتأكيداتها.'
                    : 'نرسل عليه فواتير طلباتك وتأكيداتها.'; ?>
            </span>
        </p>
    </div>

    <div class="zbx-fs zbx-fs--pw">
        <h3 class="zbx-fs__legend"><span aria-hidden="true">🔑</span> كلمة المرور</h3>
        <p class="zbx-fs__note">اتركها فارغة إذا ما تبغى تغييرها</p>

        <p class="woocommerce-form-row form-row">
            <label for="password_current">كلمة المرور الحالية</label>
            <input type="password" class="woocommerce-Input woocommerce-Input--password input-text"
                   name="password_current" id="password_current" autocomplete="off" />
        </p>
        <div class="zbx-fs__grid">
            <p class="woocommerce-form-row form-row">
                <label for="password_1">كلمة المرور الجديدة</label>
                <input type="password" class="woocommerce-Input woocommerce-Input--password input-text"
                       name="password_1" id="password_1" autocomplete="off" />
            </p>
            <p class="woocommerce-form-row form-row">
                <label for="password_2">تأكيد كلمة المرور</label>
                <input type="password" class="woocommerce-Input woocommerce-Input--password input-text"
                       name="password_2" id="password_2" autocomplete="off" />
            </p>
        </div>
    </div>

    <?php do_action('woocommerce_edit_account_form_fields'); ?>
    <?php do_action('woocommerce_edit_account_form'); ?>

    <p class="zbx-form__actions">
        <?php wp_nonce_field('save_account_details', 'save-account-details-nonce'); ?>
        <button type="submit" class="woocommerce-Button zbx-btn zbx-btn--solid" name="save_account_details" value="حفظ التعديلات">حفظ التعديلات</button>
        <input type="hidden" name="action" value="save_account_details" />
    </p>

    <?php do_action('woocommerce_edit_account_form_end'); ?>
</form>

<?php do_action('woocommerce_after_edit_account_form'); ?>
