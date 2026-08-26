<?php
/**
 * Zooboxi_Units — how many warehouse PIECES one cart-able unit represents.
 *
 * The store's stock is counted in pieces of the parent's SAP item, but a
 * variation can sell a PACK of them (كرتون = 17 حبة). SAP carries the factor
 * as Sales Items Per Unit; the backfill/sync stamp it on each variation as
 * `_zooboxi_units`. Everything that reasons about availability — the cart
 * cap, the shipment splitter, the app's quantities — multiplies through here.
 *
 * A missing meta means 1, which is exactly today's behaviour: the feature
 * turns on per-variation as data lands, never as a big-bang switch.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Units
{
    /** Pieces represented by one unit of this purchasable id. Never < 1. */
    public static function for_id(int $id): int
    {
        if ($id <= 0) {
            return 1;
        }
        $units = (int) get_post_meta($id, '_zooboxi_units', true);
        return $units > 0 ? $units : 1;
    }

    /** The factor for a cart line: its variation when it has one, else the product. */
    public static function for_cart_item(array $item): int
    {
        $vid = (int) ($item['variation_id'] ?? 0);
        return self::for_id($vid > 0 ? $vid : (int) ($item['product_id'] ?? 0));
    }

    /** Whole units obtainable from a pool of pieces. */
    public static function units_from_pieces(int $pieces, int $units): int
    {
        return $units > 1 ? intdiv(max(0, $pieces), $units) : max(0, $pieces);
    }

    /**
     * The one honest quantity guard.
     *
     * Every line that draws on the same parent's piece pool is clamped IN CART
     * ORDER so the group's total (qty × units per line) never exceeds what this
     * customer can actually be served. This is what per-line checks can never
     * catch: 50 pieces and 12 cartons are two lines but ONE pool — WooCommerce
     * validates each against the shelf number alone and happily oversells.
     *
     * Pool per parent: the fulfilment resolver's cross-tier total when the
     * customer has coordinates (what checkout can truly deliver), else the
     * area-filtered stock quantity. Unmanaged stock → unlimited, untouched.
     *
     * Returns the number of adjusted lines. Never throws.
     */
    public static function clamp_cart($cart = null): int
    {
        $cart = $cart instanceof \WC_Cart ? $cart : (function_exists('WC') ? WC()->cart : null);
        if (!$cart) {
            return 0;
        }

        $lat = 0.0;
        $lng = 0.0;
        if (class_exists('Zooboxi_Fulfillment')) {
            [$lat, $lng] = array_pad(array_values(Zooboxi_Fulfillment::customer_location()), 2, 0.0);
            $lat = (float) $lat;
            $lng = (float) $lng;
        }

        $pools    = []; // parent pid => pieces available (null = unlimited)
        $used     = []; // parent pid => pieces granted so far this walk
        $adjusted = 0;

        foreach ($cart->get_cart() as $key => $item) {
            $product = $item['data'] ?? null;
            if (!($product instanceof \WC_Product)) {
                continue;
            }
            $pid = (int) ($item['product_id'] ?? 0);
            $qty = (int) ($item['quantity'] ?? 0);
            if ($pid <= 0 || $qty <= 0) {
                continue;
            }

            $units = self::for_cart_item($item);

            if (!array_key_exists($pid, $pools)) {
                $pool = null;
                if ($lat && $lng && class_exists('Zooboxi_Fulfillment')) {
                    // Ask for far more than any cart holds → the full capacity.
                    $plan = Zooboxi_Fulfillment::resolve($pid, 100000, $lat, $lng);
                    if (isset($plan['reachable_total'])) {
                        $pool = (int) $plan['reachable_total'];
                    }
                }
                if ($pool === null) {
                    $parent = wc_get_product($pid);
                    if ($parent instanceof \WC_Product && $parent->managing_stock()) {
                        $stock = $parent->get_stock_quantity(); // area-filtered
                        $pool  = $stock === null ? null : (int) $stock;
                    }
                }
                $pools[$pid] = $pool;
                $used[$pid]  = 0;
            }

            $pool = $pools[$pid];
            if ($pool === null) {
                continue;
            }

            $allowed = self::units_from_pieces(max(0, $pool - $used[$pid]), $units);
            if ($qty > $allowed) {
                $adjusted++;
                try {
                    if ($allowed <= 0) {
                        $cart->remove_cart_item($key);
                    } else {
                        $cart->set_quantity($key, $allowed, false);
                    }
                    if (function_exists('wc_add_notice')) {
                        wc_add_notice(
                            $allowed <= 0
                                ? sprintf(__('«%s» لم يعد متاحًا بالكمية المطلوبة فأزلناه من السلة', 'zooboxi'), $product->get_name())
                                : sprintf(__('عدّلنا كمية «%1$s» إلى المتاح فعليًا: %2$d', 'zooboxi'), $product->get_name(), $allowed),
                            'notice'
                        );
                    }
                } catch (\Throwable $e) {
                    // never break the cart over a clamp
                }
                $qty = max(0, $allowed);
            }

            $used[$pid] += $qty * $units;
        }

        return $adjusted;
    }
}
