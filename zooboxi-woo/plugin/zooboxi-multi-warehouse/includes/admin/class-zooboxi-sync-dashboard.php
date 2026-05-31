<?php
/**
 * Sync Dashboard — shows sync status and trigger buttons.
 */
class Zooboxi_Sync_Dashboard
{
    public static function render(): void
    {
        if (!current_user_can('manage_woocommerce')) return;

        // Handle manual sync
        if (isset($_POST['zooboxi_manual_sync']) && check_admin_referer('zooboxi_sync')) {
            $type = sanitize_text_field($_POST['sync_type'] ?? '');
            $engine = new Zooboxi_Sync_Engine();
            $result = match ($type) {
                'products'   => $engine->sync_products(),
                'stock'      => $engine->sync_stock(),
                'prices'     => $engine->sync_prices(),
                'warehouses' => $engine->sync_warehouses(),
                default      => ['error' => 'unknown type'],
            };
            echo '<div class="notice notice-success"><p>' . esc_html(sprintf(__('تم تشغيل مزامنة %s — النتيجة: %s', 'zooboxi'), $type, wp_json_encode($result))) . '</p></div>';
        }

        $logs = Zooboxi_Logger::get_recent(15);
        $latestStock    = Zooboxi_Logger::get_latest('stock');
        $latestProducts = Zooboxi_Logger::get_latest('products');
        $latestPrices   = Zooboxi_Logger::get_latest('prices');

        ?>
        <div class="wrap">
            <h1>🔄 <?php esc_html_e('لوحة مزامنة Zooboxi', 'zooboxi'); ?></h1>

            <!-- Status Cards -->
            <div style="display:grid; grid-template-columns:repeat(3,1fr); gap:16px; margin:20px 0;">
                <?php foreach ([
                    ['المخزون', $latestStock, 'stock'],
                    ['المنتجات', $latestProducts, 'products'],
                    ['الأسعار', $latestPrices, 'prices'],
                ] as [$label, $log, $type]): ?>
                <div style="background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:20px;">
                    <h3 style="margin-top:0;"><?php echo esc_html($label); ?></h3>
                    <?php if ($log): ?>
                        <p>
                            <?php echo $log->status === 'completed' ? '✅' : ($log->status === 'failed' ? '❌' : '⏳'); ?>
                            <?php echo esc_html($log->status); ?>
                            — <?php echo esc_html($log->records_synced); ?> <?php esc_html_e('سجل', 'zooboxi'); ?>
                        </p>
                        <p style="color:#666;font-size:12px;"><?php echo esc_html($log->completed_at ?: $log->started_at); ?></p>
                    <?php else: ?>
                        <p style="color:#999;"><?php esc_html_e('لم تتم المزامنة بعد', 'zooboxi'); ?></p>
                    <?php endif; ?>
                    <form method="post" style="margin-top:8px;">
                        <?php wp_nonce_field('zooboxi_sync'); ?>
                        <input type="hidden" name="sync_type" value="<?php echo esc_attr($type); ?>">
                        <button type="submit" name="zooboxi_manual_sync" class="button button-secondary">🔄 <?php esc_html_e('مزامنة الآن', 'zooboxi'); ?></button>
                    </form>
                </div>
                <?php endforeach; ?>
            </div>

            <!-- Warehouses Sync -->
            <form method="post" style="margin-bottom:20px;">
                <?php wp_nonce_field('zooboxi_sync'); ?>
                <input type="hidden" name="sync_type" value="warehouses">
                <button type="submit" name="zooboxi_manual_sync" class="button button-primary">🏪 <?php esc_html_e('مزامنة المستودعات', 'zooboxi'); ?></button>
            </form>

            <!-- Sync Log Table -->
            <h2><?php esc_html_e('سجل المزامنة', 'zooboxi'); ?></h2>
            <table class="widefat striped">
                <thead>
                    <tr>
                        <th><?php esc_html_e('النوع', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الاتجاه', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الحالة', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('تم / فشل', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('البداية', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الانتهاء', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الخطأ', 'zooboxi'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($logs as $log): ?>
                    <tr>
                        <td><strong><?php echo esc_html($log->sync_type); ?></strong></td>
                        <td><?php echo $log->direction === 'push' ? '⬆️' : '⬇️'; ?> <?php echo esc_html($log->direction); ?></td>
                        <td><?php echo $log->status === 'completed' ? '✅' : ($log->status === 'failed' ? '❌' : '⏳'); ?> <?php echo esc_html($log->status); ?></td>
                        <td><?php echo esc_html($log->records_synced); ?> / <?php echo esc_html($log->records_failed); ?></td>
                        <td style="font-size:12px;"><?php echo esc_html($log->started_at); ?></td>
                        <td style="font-size:12px;"><?php echo esc_html($log->completed_at ?: '—'); ?></td>
                        <td style="color:red;font-size:12px;"><?php echo esc_html($log->error_message ? substr($log->error_message, 0, 80) : '—'); ?></td>
                    </tr>
                    <?php endforeach; ?>
                    <?php if (empty($logs)): ?>
                    <tr><td colspan="7" style="text-align:center;color:#999;"><?php esc_html_e('لا يوجد سجلات مزامنة', 'zooboxi'); ?></td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
        <?php
    }
}
