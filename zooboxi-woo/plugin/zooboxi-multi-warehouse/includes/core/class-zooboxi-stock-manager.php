<?php
/**
 * Manages per-warehouse stock stored in WooCommerce product meta.
 *
 * OWNERSHIP (2026-09-06). The meta `_zooboxi_warehouse_stock` is a JSON array of
 * {warehouse_code, in_stock} and `_stock` is its SUM. It used to have exactly one
 * writer — the sapconnect pull — so `update_stock()` replaced the whole array.
 * Now RUH003 («مستودع الشحن — الرياض») is fulfilled by ShipGo/Stapo while every
 * branch stays on SAP, i.e. TWO writers on one field. A plain replace from either
 * side would erase the other's warehouses, so each writer declares what it owns
 * and may only touch those codes; everything else is preserved untouched.
 */
class Zooboxi_Stock_Manager
{
    /** Warehouses fulfilled by ShipGo (option, so it changes without a deploy). */
    public static function shipgo_codes(): array
    {
        $codes = get_option('zooboxi_shipgo_warehouses', ['RUH003']);
        if (is_string($codes)) {
            $codes = array_filter(array_map('trim', explode(',', $codes)));
        }
        return is_array($codes) ? array_values(array_map('strval', $codes)) : ['RUH003'];
    }

    /** Is this warehouse code fulfilled by ShipGo? */
    public static function is_shipgo_code(string $code): bool
    {
        return in_array($code, self::shipgo_codes(), true);
    }

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
                if (($ws['warehouse_code'] ?? '') === $warehouseCode) {
                    $available = (float) ($ws['in_stock'] ?? 0);
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

    /** Quantity currently recorded for one warehouse (0 when absent). */
    public static function get_warehouse_qty(int $productId, string $code): float
    {
        foreach (self::get_warehouse_stock($productId) as $ws) {
            if (($ws['warehouse_code'] ?? '') === $code) return (float) ($ws['in_stock'] ?? 0);
        }
        return 0.0;
    }

    /**
     * Update the per-warehouse meta + the total WooCommerce stock.
     *
     * @param string $owner 'sap'    — the sapconnect pull: owns every code EXCEPT ShipGo's
     *                      'shipgo' — the ShipGo callback: owns ONLY the ShipGo codes
     *                      'all'    — legacy full replace (migrations/imports only)
     */
    public static function update_stock(int $productId, array $warehouseStocks, string $owner = 'sap'): void
    {
        $merged = $owner === 'all'
            ? self::normalize($warehouseStocks)
            : self::merge_owned($productId, $warehouseStocks, $owner);

        update_post_meta($productId, '_zooboxi_warehouse_stock', wp_json_encode(array_values($merged)));

        $total = 0;
        foreach ($merged as $ws) $total += (float) ($ws['in_stock'] ?? 0);
        update_post_meta($productId, '_stock', $total);
        update_post_meta($productId, '_stock_status', $total > 0 ? 'instock' : 'outofstock');
        update_post_meta($productId, '_manage_stock', 'yes');
    }

    /** Write ONE warehouse slot, leaving every other warehouse exactly as it is. */
    public static function set_warehouse_stock(int $productId, string $code, float $qty): void
    {
        self::update_stock($productId, [['warehouse_code' => $code, 'in_stock' => $qty]],
            self::is_shipgo_code($code) ? 'shipgo' : 'sap');
    }

    /**
     * Keep the rows this writer does NOT own, take the rows it does.
     * A writer that owns a code but omits it from its payload means "zero there" —
     * that is how a sold-out warehouse disappears — so owned codes are rebuilt
     * from the payload alone, never carried over.
     */
    private static function merge_owned(int $productId, array $incoming, string $owner): array
    {
        $out = [];
        foreach (self::get_warehouse_stock($productId) as $ws) {
            $code = (string) ($ws['warehouse_code'] ?? '');
            if ($code === '' || self::owns($owner, $code)) continue;      // dropped: this writer rebuilds it
            $out[$code] = ['warehouse_code' => $code, 'in_stock' => (float) ($ws['in_stock'] ?? 0)];
        }
        foreach (self::normalize($incoming) as $ws) {
            $code = (string) $ws['warehouse_code'];
            if (!self::owns($owner, $code)) continue;                      // refuse writes outside the scope
            $out[$code] = $ws;
        }
        return $out;
    }

    private static function owns(string $owner, string $code): bool
    {
        return $owner === 'shipgo' ? self::is_shipgo_code($code) : !self::is_shipgo_code($code);
    }

    /**
     * WHO FULFILS THIS ORDER — the single-source rule (Mohamed, 2026-09-06).
     *
     * 'shipgo' only when ONE ShipGo warehouse (RUH003) covers EVERY line; anything
     * else — a line it lacks, a line it is short on — goes to sapconnect as before.
     * Never split an order across two systems: that is two pickings, two waybills
     * and one confused customer.
     *
     * The answer is STAMPED on the order the first time it is asked, because stock
     * moves: a retry an hour later must reach the same system that already has it.
     */
    public static function fulfilment_source(\WC_Order $order): string
    {
        $stamped = (string) $order->get_meta('_zooboxi_fulfilment');
        if ($stamped === 'shipgo' || $stamped === 'sap') return $stamped;

        $items = [];
        foreach ($order->get_items() as $item) {
            if (!method_exists($item, 'get_product_id')) continue;
            $pid = $item->get_variation_id() ?: $item->get_product_id();
            if (!$pid) continue;
            $items[] = ['product_id' => (int) $pid, 'quantity' => (float) $item->get_quantity()];
        }

        $source = 'sap';
        if (!empty($items)) {
            foreach (self::shipgo_codes() as $code) {
                if (self::has_all_items($code, $items)) { $source = 'shipgo'; break; }
            }
        }

        $order->update_meta_data('_zooboxi_fulfilment', $source);
        $order->save();
        return $source;
    }

    /** Drop malformed rows, coerce types, de-duplicate on the warehouse code. */
    private static function normalize(array $rows): array
    {
        $out = [];
        foreach ($rows as $ws) {
            if (!is_array($ws)) continue;
            $code = trim((string) ($ws['warehouse_code'] ?? ''));
            if ($code === '') continue;
            $out[$code] = ['warehouse_code' => $code, 'in_stock' => (float) ($ws['in_stock'] ?? 0)];
        }
        return $out;
    }
}
