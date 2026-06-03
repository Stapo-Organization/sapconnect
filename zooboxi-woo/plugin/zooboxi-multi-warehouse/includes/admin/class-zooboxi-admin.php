<?php
/**
 * Admin menu + dashboard overview.
 */
class Zooboxi_Admin
{
    public function __construct()
    {
        // Add SAP Code column to WooCommerce products list
        add_filter('manage_edit-product_columns', [$this, 'add_sap_code_column'], 20);
        add_action('manage_product_posts_custom_column', [$this, 'render_sap_code_column'], 10, 2);
        add_filter('manage_edit-product_sortable_columns', [$this, 'make_sap_code_column_sortable']);
        
        // Handle sorting by SAP Code
        add_action('pre_get_posts', [$this, 'sort_by_sap_code']);

        // Add custom CSS to admin head to prevent column squeezing
        add_action('admin_head', [$this, 'add_admin_styles']);
    }

    /**
     * Inject admin styles to set an explicit width and prevent wrapping on the SAP Code column.
     */
    public function add_admin_styles(): void
    {
        $screen = get_current_screen();
        if ($screen && $screen->id === 'edit-product') {
            echo '<style>
                .widefat .column-sap_code {
                    width: 120px !important;
                    white-space: nowrap !important;
                    vertical-align: middle !important;
                }
                .column-sap_code code {
                    font-family: monospace;
                    background: #f0fdfa !important;
                    border: 1px solid #99f6e4 !important;
                    padding: 4px 8px !important;
                    border-radius: 6px !important;
                    font-size: 12px !important;
                    color: #0d9488 !important;
                    font-weight: bold !important;
                    display: inline-block !important;
                    white-space: nowrap !important;
                }
            </style>';
        }
    }

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
        add_submenu_page('zooboxi', __('المخزون والمستودعات', 'zooboxi'), __('📦 المخزون', 'zooboxi'), 'manage_woocommerce', 'zooboxi-stock', [Zooboxi_Stock_Dashboard::class, 'render']);
        add_submenu_page('zooboxi', __('الإعدادات', 'zooboxi'), __('الإعدادات', 'zooboxi'), 'manage_woocommerce', 'zooboxi-settings', [Zooboxi_Settings_Page::class, 'render']);
    }

    /**
     * Add SAP Code column right after the SKU column.
     */
    public function add_sap_code_column(array $columns): array
    {
        $new_columns = [];
        foreach ($columns as $key => $column) {
            $new_columns[$key] = $column;
            if ($key === 'sku') {
                $new_columns['sap_code'] = __('رمز SAP', 'zooboxi');
            }
        }
        return $new_columns;
    }

    /**
     * Output the _zooboxi_item_code meta value in the SAP Code column.
     */
    public function render_sap_code_column(string $column, int $postId): void
    {
        if ($column === 'sap_code') {
            $item_code = get_post_meta($postId, '_zooboxi_item_code', true);
            if (!empty($item_code)) {
                echo '<code style="font-family:monospace;background:#f3f4f6;padding:2px 6px;border-radius:4px;font-size:12px;color:#0d9488;font-weight:bold;">' . esc_html($item_code) . '</code>';
            } else {
                echo '<span style="color:#d1d5db;">—</span>';
            }
        }
    }

    /**
     * Declare the SAP Code column as sortable.
     */
    public function make_sap_code_column_sortable(array $columns): array
    {
        $columns['sap_code'] = 'sap_code';
        return $columns;
    }

    /**
     * Order the WP_Query by the _zooboxi_item_code meta value when sorting by SAP Code.
     */
    public function sort_by_sap_code(\WP_Query $query): void
    {
        if (!is_admin() || !$query->is_main_query()) return;

        if ($query->get('post_type') === 'product' && $query->get('orderby') === 'sap_code') {
            $query->set('meta_key', '_zooboxi_item_code');
            $query->set('orderby', 'meta_value');
        }
    }
}
