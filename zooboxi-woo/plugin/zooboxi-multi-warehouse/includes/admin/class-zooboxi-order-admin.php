<?php
/**
 * WooCommerce admin: show the fulfilling Zooboxi branch on the orders screen.
 *
 * Adds a "الفرع" column to the orders list (HPOS + legacy) and a line on the
 * order-detail screen, resolved from the order meta `_zooboxi_warehouse`
 * against the synced `{prefix}zooboxi_warehouses` table (display_name_ar).
 */
class Zooboxi_Order_Admin
{
    /** @var array<string,bool> guards against double rendering across HPOS hook variants */
    private array $rendered = [];

    public function register_hooks(): void
    {
        // Orders list — HPOS (custom order tables)
        add_filter('manage_woocommerce_page_wc-orders_columns', [$this, 'add_column']);
        add_action('manage_woocommerce_page_wc-orders_custom_column', [$this, 'render_column_object'], 10, 2);
        add_action('woocommerce_shop_order_list_table_custom_column', [$this, 'render_column_object'], 10, 2);

        // Orders list — legacy (posts)
        add_filter('manage_edit-shop_order_columns', [$this, 'add_column']);
        add_action('manage_shop_order_posts_custom_column', [$this, 'render_column_post'], 10, 2);

        // Order detail screen (both storage modes)
        add_action('woocommerce_admin_order_data_after_order_details', [$this, 'render_in_order_detail']);
    }

    /**
     * Insert the "الفرع" column right after the status column.
     */
    public function add_column(array $columns): array
    {
        $new = [];
        foreach ($columns as $key => $label) {
            $new[$key] = $label;
            if ($key === 'order_status') {
                $new['zooboxi_branch'] = __('الفرع', 'zooboxi');
            }
        }
        if (!isset($new['zooboxi_branch'])) {
            $new['zooboxi_branch'] = __('الفرع', 'zooboxi');
        }
        return $new;
    }

    /** HPOS render — receives ($column, $order). */
    public function render_column_object($column, $order): void
    {
        if ($column !== 'zooboxi_branch' || !is_object($order)) {
            return;
        }
        $key = $order->get_id() . ':' . $column;
        if (isset($this->rendered[$key])) {
            return; // another HPOS hook variant already rendered it
        }
        $this->rendered[$key] = true;
        echo $this->branch_html($order); // phpcs:ignore WordPress.Security.EscapeOutput
    }

    /** Legacy render — receives ($column, $post_id). */
    public function render_column_post($column, $post_id): void
    {
        if ($column !== 'zooboxi_branch') {
            return;
        }
        $order = wc_get_order($post_id);
        if ($order) {
            echo $this->branch_html($order); // phpcs:ignore WordPress.Security.EscapeOutput
        }
    }

    /** Order-detail screen line. */
    public function render_in_order_detail($order): void
    {
        if (!is_object($order)) {
            return;
        }
        $code = (string) $order->get_meta('_zooboxi_warehouse');
        if ($code === '') {
            return;
        }
        $name = self::warehouse_name($code);
        echo '<p class="form-field form-field-wide"><strong>'
            . esc_html__('الفرع (Zooboxi):', 'zooboxi') . '</strong> '
            . esc_html($name !== '' ? "{$name} ({$code})" : $code) . '</p>';
    }

    private function branch_html($order): string
    {
        $code = (string) $order->get_meta('_zooboxi_warehouse');
        if ($code === '') {
            return '<span style="color:#9ca3af">—</span>';
        }
        $name = self::warehouse_name($code);
        if ($name !== '') {
            return '<span style="font-weight:600">' . esc_html($name) . '</span>'
                . '<br><small style="color:#9ca3af;font-family:monospace">' . esc_html($code) . '</small>';
        }
        return '<span style="font-family:monospace">' . esc_html($code) . '</span>';
    }

    /**
     * Branch display name (Arabic) for a warehouse code, from the synced table.
     */
    private static function warehouse_name(string $code): string
    {
        static $cache = [];
        if (array_key_exists($code, $cache)) {
            return $cache[$code];
        }
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        $name = $wpdb->get_var(
            $wpdb->prepare("SELECT display_name_ar FROM {$table} WHERE warehouse_code = %s LIMIT 1", $code)
        );
        return $cache[$code] = ($name ? (string) $name : '');
    }
}
