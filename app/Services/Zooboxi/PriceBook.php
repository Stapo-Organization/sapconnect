<?php

namespace App\Services\Zooboxi;

use App\Models\Product;

/**
 * دفتر أسعار زوبوكسي — the ONE place a shelf price is computed.
 *
 * SAP carries prices per PIECE and EX-VAT. The store shows VAT-inclusive
 * prices, and each storefront has its own shelf:
 *
 *   زوبكسي  (all)      = retail list           × (1 + VAT)
 *   إكسبريس (express)  = retail list × (1 + m) × (1 + VAT)   m = express markup
 *
 * The retail list is «Retail PL - Muntajat» (SAP list 2). List 1 is the
 * WHOLESALE list our ~470 resellers buy at — the store must never net below
 * it (see the channel-conflict rule). So the base is floored to wholesale:
 * a missing or sub-wholesale retail price never hides a product and never
 * undercuts a reseller; it is flagged for the owner to fix in SAP instead.
 *
 * Owner decisions 2026-09-22: retail = list 2; express = list 2 + 5%;
 * VAT 15% added on top (SAP prices are ex-VAT). Carton prices are the piece
 * price × pieces per carton, with no per-unit discount — the carton incentive
 * is a gift or free delivery, never a lower unit price.
 */
final class PriceBook
{
    public const SHELF_ALL = 'all';
    public const SHELF_EXPRESS = 'express';

    public const STATUS_OK = 'ok';                          // retail list present and ≥ wholesale
    public const STATUS_NO_RETAIL = 'no_retail';            // no retail price → floored to wholesale
    public const STATUS_BELOW_WHOLESALE = 'below_wholesale';// retail < wholesale → floored to wholesale
    public const STATUS_NO_PRICE = 'no_price';              // nothing usable → not priced

    public static function retailList(): int
    {
        return (int) config('services.zooboxi_pricing.price_list', 2);
    }

    public static function wholesaleList(): int
    {
        return (int) config('services.zooboxi_pricing.wholesale_list', 1);
    }

    public static function vatRate(): float
    {
        return (float) config('services.zooboxi_pricing.vat_rate', 0.15);
    }

    public static function expressMarkup(): float
    {
        return (float) config('services.zooboxi_pricing.express_markup', 0.05);
    }

    /**
     * Price of one SAP list from a product's `prices` JSON. Tolerates the
     * Service Layer shape (PriceList/Price), snake_case, and rows keyed by
     * list number. Only a positive price counts.
     */
    public static function listPrice(?array $prices, int $list): ?float
    {
        foreach ((array) $prices as $key => $row) {
            if (! is_array($row)) {
                continue;
            }
            $pl = $row['PriceList'] ?? $row['priceList'] ?? $row['price_list'] ?? (is_numeric($key) ? (int) $key : null);
            if ($pl === null || (int) $pl !== $list) {
                continue;
            }
            $price = (float) ($row['Price'] ?? $row['price'] ?? 0);

            return $price > 0 ? $price : null;
        }

        return null;
    }

    /**
     * @return array{
     *   retail: ?float, wholesale: ?float, base: ?float, status: string,
     *   shelves: array{all: ?float, express: ?float}
     * }  ex-VAT inputs, VAT-inclusive per-piece shelf prices (2 dp)
     */
    public static function quote(?array $prices): array
    {
        $retail = self::listPrice($prices, self::retailList());
        $wholesale = self::listPrice($prices, self::wholesaleList());

        if ($retail === null && $wholesale === null) {
            $status = self::STATUS_NO_PRICE;
            $base = null;
        } elseif ($retail === null) {
            $status = self::STATUS_NO_RETAIL;
            $base = $wholesale;
        } elseif ($wholesale !== null && $retail < $wholesale) {
            $status = self::STATUS_BELOW_WHOLESALE;
            $base = $wholesale;
        } else {
            $status = self::STATUS_OK;
            $base = $retail;
        }

        $vat = 1 + self::vatRate();
        $markup = 1 + self::expressMarkup();

        return [
            'retail' => $retail,
            'wholesale' => $wholesale,
            'base' => $base,
            'status' => $status,
            'shelves' => [
                self::SHELF_ALL => $base === null ? null : round($base * $vat, 2),
                self::SHELF_EXPRESS => $base === null ? null : round($base * $markup * $vat, 2),
            ],
        ];
    }

    /** quote() plus the carton factor, for feeds. */
    public static function forProduct(Product $product): array
    {
        $q = self::quote($product->prices);
        $q['units'] = max(1, (int) round((float) ($product->sales_items_per_unit ?? 1)));

        return $q;
    }

    /** The store's base (ex-VAT, per piece) — what discount ceilings are measured against. */
    public static function baseOf(Product $product): float
    {
        return (float) (self::quote($product->prices)['base'] ?? 0.0);
    }
}
