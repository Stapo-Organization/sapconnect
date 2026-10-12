<?php
/**
 * Zooboxi_Price_Book — one product, two shelves, two prices.
 *
 * The backend's price book (App\Services\Zooboxi\PriceBook) sends every
 * product with `shelf_prices` — VAT-inclusive PIECE prices per storefront:
 *
 *   all      زوبكسي   = retail list × 1.15
 *   express  إكسبريس  = retail list × 1.05 × 1.15
 *
 * This class does two jobs:
 *
 *  1. WRITE — `apply()` puts the زوبكسي price where WooCommerce keeps its
 *     price (`_regular_price`/`_price`, on each variation × its pack size for
 *     a variable product) and stamps the إكسبريس price beside it as
 *     `_zooboxi_price_express` (also × pack size). A carton is therefore
 *     always piece × count: no per-unit discount, ever — the carton incentive
 *     is a gift or free delivery.
 *
 *  2. READ — while a request is served on the إكسبريس shelf, the WooCommerce
 *     price getters answer with the express meta instead. Catalogue cards,
 *     the app DTO, the cart and checkout all read prices through those
 *     getters, so an express basket is priced express end to end and the
 *     order freezes those numbers. The served shelf comes from
 *     Zooboxi_Cart_Shelf::requested(): outside branch hours an express
 *     request IS a زوبكسي request (same catalogue, same basket, same price).
 *
 * A product with no express meta (a bundle, an old row) keeps its one price
 * on both shelves. A sale price (owner-approved clearance) is honoured on
 * both shelves: the customer never pays more than the sale.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Price_Book
{
    public const META_EXPRESS = '_zooboxi_price_express';
    public const META_STATUS  = '_zooboxi_price_status';
    public const META_PIECE   = '_zooboxi_price_piece';   // زوبكسي piece price, for reference

    public static function hooks(): void
    {
        add_filter('woocommerce_product_get_price', [self::class, 'filter_price'], 20, 2);
        add_filter('woocommerce_product_get_regular_price', [self::class, 'filter_regular_price'], 20, 2);
        add_filter('woocommerce_product_variation_get_price', [self::class, 'filter_price'], 20, 2);
        add_filter('woocommerce_product_variation_get_regular_price', [self::class, 'filter_regular_price'], 20, 2);
        // Variable parents cache their children's prices under a hash; the
        // shelf must be part of that hash or one shelf would serve the other's.
        add_filter('woocommerce_variation_prices_price', [self::class, 'filter_variation_price'], 20, 3);
        add_filter('woocommerce_variation_prices_regular_price', [self::class, 'filter_variation_regular_price'], 20, 3);
        add_filter('woocommerce_get_variation_prices_hash', [self::class, 'prices_hash'], 20, 3);
    }

    /* ── which shelf is priced right now ─────────────── */

    /** 'express' only while the request is really served by an open express branch. */
    public static function shelf(): string
    {
        if (!class_exists('Zooboxi_Cart_Shelf')) {
            return 'all';
        }
        return Zooboxi_Cart_Shelf::requested() === Zooboxi_Cart_Shelf::EXPRESS ? 'express' : 'all';
    }

    public static function is_express(): bool
    {
        return self::shelf() === 'express';
    }

    /* ── read side ───────────────────────────────────── */

    private static function express_of(int $id): float
    {
        return $id > 0 ? (float) get_post_meta($id, self::META_EXPRESS, true) : 0.0;
    }

    /** @param mixed $price */
    public static function filter_price($price, $product)
    {
        if (!self::is_express() || !($product instanceof \WC_Product)) {
            return $price;
        }
        $express = self::express_of($product->get_id());
        if ($express <= 0) {
            return $price;
        }
        // 'edit' context reads the raw props, so this cannot re-enter the filter.
        $sale = (float) $product->get_sale_price('edit');
        if ($sale > 0 && $sale < $express && $product->is_on_sale('edit')) {
            return wc_format_decimal($sale);
        }
        return wc_format_decimal($express);
    }

    /** @param mixed $price */
    public static function filter_regular_price($price, $product)
    {
        if (!self::is_express() || !($product instanceof \WC_Product)) {
            return $price;
        }
        $express = self::express_of($product->get_id());
        return $express > 0 ? wc_format_decimal($express) : $price;
    }

    /** @param mixed $price */
    public static function filter_variation_price($price, $variation, $parent)
    {
        return self::filter_price($price, $variation);
    }

    /** @param mixed $price */
    public static function filter_variation_regular_price($price, $variation, $parent)
    {
        return self::filter_regular_price($price, $variation);
    }

    public static function prices_hash($hash, $product, $for_display)
    {
        if (is_array($hash)) {
            $hash['zb_shelf'] = self::shelf();
        }
        return $hash;
    }

    /* ── write side ──────────────────────────────────── */

    /**
     * Write a backend feed row's shelf prices onto the store product.
     * Returns true when the row carried shelf prices (handled), false when
     * the caller should fall back to the legacy single-list price.
     */
    public static function apply(int $productId, array $row): bool
    {
        $shelves = $row['shelf_prices'] ?? null;
        if (!is_array($shelves)) {
            return false;
        }
        $all     = (float) ($shelves['all'] ?? 0);
        $express = (float) ($shelves['express'] ?? 0);
        if ($all <= 0) {
            // Nothing usable in SAP: leave the shelf as it is, say why.
            update_post_meta($productId, self::META_STATUS, (string) ($row['price_status'] ?? 'no_price'));
            return true;
        }
        if ($express <= 0) {
            $express = $all;
        }
        $product = wc_get_product($productId);
        if (!$product) {
            return true;
        }

        update_post_meta($productId, self::META_STATUS, (string) ($row['price_status'] ?? ''));
        update_post_meta($productId, self::META_PIECE, wc_format_decimal($all, 2));

        if ($product->is_type('variable')) {
            $parentCode = (string) get_post_meta($productId, '_zooboxi_item_code', true);
            $changed = false;
            foreach ($product->get_children() as $vid) {
                // A variation with its OWN SAP identity is priced by its own feed row.
                $own = (string) get_post_meta((int) $vid, '_zooboxi_item_code', true);
                if ($own !== '' && $own !== $parentCode) {
                    continue;
                }
                $units = class_exists('Zooboxi_Units') ? Zooboxi_Units::for_id((int) $vid) : 1;
                $changed = self::write((int) $vid, $all * $units, $express * $units) || $changed;
            }
            // The parent answers "from" prices and the lookup table from its children.
            update_post_meta($productId, self::META_EXPRESS, wc_format_decimal($express, 2));
            if ($changed) {
                \WC_Product_Variable::sync($productId);
                wc_delete_product_transients($productId);
            }
            return true;
        }

        if (self::write($productId, $all, $express)) {
            wc_delete_product_transients($productId);
        }
        return true;
    }

    /**
     * Regular/current price via the product object (so the meta lookup table
     * and caches follow), express as plain meta. Saves only on a real change:
     * the hourly sync walks thousands of products that mostly did not move.
     */
    private static function write(int $id, float $regular, float $express): bool
    {
        $p = wc_get_product($id);
        if (!$p) {
            return false;
        }
        $reg = wc_format_decimal($regular, 2);
        $exp = wc_format_decimal($express, 2);
        $changed = false;

        if ((string) $p->get_regular_price('edit') !== (string) $reg) {
            $p->set_regular_price($reg);
            $changed = true;
        }
        $sale = (string) $p->get_sale_price('edit');
        $current = ($sale !== '' && (float) $sale > 0 && (float) $sale < $regular && $p->is_on_sale('edit')) ? $sale : $reg;
        if ((string) $p->get_price('edit') !== (string) $current) {
            $p->set_price($current);
            $changed = true;
        }
        if ($changed) {
            $p->save();
        }
        if ((string) get_post_meta($id, self::META_EXPRESS, true) !== (string) $exp) {
            update_post_meta($id, self::META_EXPRESS, $exp);
            $changed = true;
        }
        return $changed;
    }
}
