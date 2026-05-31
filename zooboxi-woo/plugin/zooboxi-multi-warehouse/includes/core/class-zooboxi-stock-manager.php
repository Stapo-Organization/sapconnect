<?php
/**
 * Manages per-warehouse stock stored in WooCommerce product meta.
 */
class Zooboxi_Stock_Manager
{
    /**
     * Check if ALL items in a list are available in a specific warehouse.
     *
     * @param string $warehouseCode
     * @param array  $items [['id' => product_id, 'quantity' => qty], ...]
     */
    public static function has_all_items(string $warehouseCode, array $items): bool
    {
        foreach ($items as $item) {
            $productId = $item['product_id'] ?? ($item['id'] ?? 0);
            $qty       = $item['quantity'] ?? 1;

            $warehouseStock = self::get_warehouse_stock($productId);
            $available = 0;

            foreach ($warehouseStock as $ws) {
                if ($ws['warehouse_code'] === $warehouseCode) {
                    $available = (float) $ws['in_stock'];
                    break;
                }
            }

            if ($available < $qty) return false;
        }

        return true;
    }

    /**
     * Get per-warehouse stock breakdown for a product.
     */
    public static function get_warehouse_stock(int $productId): array
    {
        $raw = get_post_meta($productId, '_zooboxi_warehouse_stock', true);
        if (empty($raw)) return [];

        $decoded = is_string($raw) ? json_decode($raw, true) : $raw;
        return is_array($decoded) ? $decoded : [];
    }

    /**
     * Update the total WooCommerce stock + per-warehouse meta.
     */
    public static function update_stock(int $productId, array $warehouseStocks): void
    {
        // Store per-warehouse breakdown
        update_post_meta($productId, '_zooboxi_warehouse_stock', wp_json_encode($warehouseStocks));

        // Sum total stock
        $total = array_sum(array_column($warehouseStocks, 'in_stock'));
        update_post_meta($productId, '_stock', $total);
        update_post_meta($productId, '_stock_status', $total > 0 ? 'instock' : 'outofstock');
        update_post_meta($productId, '_manage_stock', 'yes');
    }
}
