<?php
/**
 * Admin menu + dashboard overview.
 */
class Zooboxi_Admin
{
    public function register_menu(): void
    {
        add_menu_page(
            __('Zooboxi', 'zooboxi'),
            __('Zooboxi', 'zooboxi'),
            'manage_woocommerce',
            'zooboxi',
            [Zooboxi_Sync_Dashboard::class, 'render'],
            'dashicons-store',
            56
        );

        add_submenu_page('zooboxi', __('لوحة المزامنة', 'zooboxi'), __('المزامنة', 'zooboxi'), 'manage_woocommerce', 'zooboxi', [Zooboxi_Sync_Dashboard::class, 'render']);
        add_submenu_page('zooboxi', __('الإعدادات', 'zooboxi'), __('الإعدادات', 'zooboxi'), 'manage_woocommerce', 'zooboxi-settings', [Zooboxi_Settings_Page::class, 'render']);
    }
}
