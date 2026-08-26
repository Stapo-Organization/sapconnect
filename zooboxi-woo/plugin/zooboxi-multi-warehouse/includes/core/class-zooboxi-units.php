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
}
