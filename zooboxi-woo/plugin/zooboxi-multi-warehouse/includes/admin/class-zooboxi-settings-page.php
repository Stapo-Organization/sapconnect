<?php
/**
 * Settings page for Zooboxi plugin.
 */
class Zooboxi_Settings_Page
{
    public static function render(): void
    {
        if (!current_user_can('manage_woocommerce')) return;

        // Handle save
        if (isset($_POST['zooboxi_save_settings']) && check_admin_referer('zooboxi_settings')) {
            $fields = [
                'zooboxi_api_url', 'zooboxi_api_token',
                'zooboxi_express_fee', 'zooboxi_standard_fee', 'zooboxi_shipping_fee',
                'zooboxi_free_shipping_min', 'zooboxi_stock_sync_interval', 'zooboxi_default_price_list',
            ];
            foreach ($fields as $field) {
                if (isset($_POST[$field])) {
                    update_option($field, sanitize_text_field($_POST[$field]));
                }
            }
            echo '<div class="notice notice-success"><p>' . esc_html__('تم حفظ الإعدادات بنجاح', 'zooboxi') . '</p></div>';
        }

        ?>
        <div class="wrap">
            <h1>⚙️ <?php esc_html_e('إعدادات Zooboxi', 'zooboxi'); ?></h1>
            <form method="post">
                <?php wp_nonce_field('zooboxi_settings'); ?>
                <table class="form-table">
                    <tr>
                        <th><label for="zooboxi_api_url"><?php esc_html_e('sapconnect API URL', 'zooboxi'); ?></label></th>
                        <td><input type="url" name="zooboxi_api_url" id="zooboxi_api_url" class="regular-text" value="<?php echo esc_attr(get_option('zooboxi_api_url')); ?>"></td>
                    </tr>
                    <tr>
                        <th><label for="zooboxi_api_token"><?php esc_html_e('API Token', 'zooboxi'); ?></label></th>
                        <td><input type="password" name="zooboxi_api_token" id="zooboxi_api_token" class="regular-text" value="<?php echo esc_attr(get_option('zooboxi_api_token')); ?>"></td>
                    </tr>
                    <tr><td colspan="2"><hr><h2><?php esc_html_e('رسوم التوصيل', 'zooboxi'); ?></h2></td></tr>
                    <tr>
                        <th><label for="zooboxi_express_fee"><?php esc_html_e('توصيل سريع (ر.س)', 'zooboxi'); ?></label></th>
                        <td><input type="number" name="zooboxi_express_fee" id="zooboxi_express_fee" value="<?php echo esc_attr(get_option('zooboxi_express_fee', 15)); ?>" step="0.01"></td>
                    </tr>
                    <tr>
                        <th><label for="zooboxi_standard_fee"><?php esc_html_e('توصيل عادي (ر.س)', 'zooboxi'); ?></label></th>
                        <td><input type="number" name="zooboxi_standard_fee" id="zooboxi_standard_fee" value="<?php echo esc_attr(get_option('zooboxi_standard_fee', 10)); ?>" step="0.01"></td>
                    </tr>
                    <tr>
                        <th><label for="zooboxi_shipping_fee"><?php esc_html_e('شحن وطني (ر.س)', 'zooboxi'); ?></label></th>
                        <td><input type="number" name="zooboxi_shipping_fee" id="zooboxi_shipping_fee" value="<?php echo esc_attr(get_option('zooboxi_shipping_fee', 25)); ?>" step="0.01"></td>
                    </tr>
                    <tr>
                        <th><label for="zooboxi_free_shipping_min"><?php esc_html_e('حد الشحن المجاني (ر.س)', 'zooboxi'); ?></label></th>
                        <td><input type="number" name="zooboxi_free_shipping_min" id="zooboxi_free_shipping_min" value="<?php echo esc_attr(get_option('zooboxi_free_shipping_min', 200)); ?>" step="0.01"></td>
                    </tr>
                    <tr><td colspan="2"><hr><h2><?php esc_html_e('المزامنة', 'zooboxi'); ?></h2></td></tr>
                    <tr>
                        <th><label for="zooboxi_default_price_list"><?php esc_html_e('قائمة الأسعار الافتراضية', 'zooboxi'); ?></label></th>
                        <td><input type="number" name="zooboxi_default_price_list" id="zooboxi_default_price_list" value="<?php echo esc_attr(get_option('zooboxi_default_price_list', 1)); ?>" min="1"></td>
                    </tr>
                </table>
                <p class="submit">
                    <input type="submit" name="zooboxi_save_settings" class="button-primary" value="<?php esc_attr_e('حفظ الإعدادات', 'zooboxi'); ?>">
                </p>
            </form>
        </div>
        <?php
    }
}
