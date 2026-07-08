<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Read-only catalog feed for the ShipGo WMS.
 *
 * Serves the locally-synced `products` table — the SAP B1 mirror kept current by
 * `sap:sync-products` (GET-only). SAP itself is strictly read-only; there is NO
 * write path here. Response shape matches ShipGo's SapconnectHttpSource: a bare
 * JSON array of { item_code, item_name, foreign_name, inventory_uom,
 * piece_barcode, sales_items_per_unit, wholesale_price, prices }.
 *
 * Catalog scope = active/sellable items only: production items that carry a
 * positive price on the canonical price list (codebase convention: list 1).
 * Items with no sellable price are excluded (pass ?all=1 to bypass).
 *
 * منتجات (Muntajat) is the master wholesaler, so the whole SAP item master is
 * its catalog; ShipGo attributes the imported offers to the منتجات supplier.
 * Stock is intentionally NOT served here (it will come from an Anchanto Excel).
 */
class ShipGoCatalogController extends Controller
{
    /** GET /api/shipgo/catalog */
    public function catalog(Request $request): JsonResponse
    {
        $priceList  = (int) config('services.shipgo.price_list', 1);
        $includeAll = $request->boolean('all');

        // ~8k production items: stream with a lazy base-query cursor (no Eloquent
        // model hydration, no JSON-cast overhead) and build a lean array. The raw
        // `prices` blob is intentionally NOT returned — ShipGo only needs the
        // explicit `wholesale_price` we compute, and shipping 8k price arrays
        // would blow the request memory limit.
        $rows = Product::query()
            ->production()
            ->toBase()
            ->select([
                'item_code', 'item_name', 'foreign_name', 'inventory_uom',
                'piece_barcode', 'sales_items_per_unit', 'prices', 'zb_images',
            ])
            ->orderBy('item_code')
            ->cursor();

        $out = [];
        foreach ($rows as $p) {
            $wholesale = $this->priceFromList($p->prices, $priceList);
            if (! $includeAll && ! ($wholesale > 0)) {
                continue; // sellable gate: must carry a positive price
            }
            $out[] = [
                'item_code'            => $p->item_code,
                'item_name'            => $p->item_name,       // English
                'foreign_name'         => $p->foreign_name,    // Arabic
                'inventory_uom'        => $p->inventory_uom,
                'piece_barcode'        => $p->piece_barcode,   // consumer/piece SKU
                'sales_items_per_unit' => $p->sales_items_per_unit === null ? null : (float) $p->sales_items_per_unit,
                'wholesale_price'      => $wholesale,
                'image_url'            => $this->firstImage($p->zb_images),
            ];
        }

        return response()->json($out);
    }

    /**
     * GET /api/shipgo/stock — intentionally empty.
     * Stock is OUT of scope for the catalog import; it will be loaded from an
     * Anchanto Excel later, not synced from SAP. Kept so the ShipGo source's
     * stock path resolves (returns [] = no stock movements posted).
     */
    public function stock(Request $request): JsonResponse
    {
        return response()->json([]);
    }

    /** First product image URL from the zb_images JSON (null when none). */
    private function firstImage($zbImages): ?string
    {
        if (is_string($zbImages)) {
            $zbImages = json_decode($zbImages, true) ?: [];
        }
        if (is_array($zbImages) && ! empty($zbImages)) {
            $first = $zbImages[0] ?? null;
            return (is_string($first) && $first !== '') ? $first : null;
        }
        return null;
    }

    /** Extract the price for a SAP price list out of the ItemPrices JSON. */
    private function priceFromList($prices, int $priceList): ?float
    {
        if (is_string($prices)) {
            $prices = json_decode($prices, true) ?: [];
        }
        if (empty($prices) || ! is_array($prices)) {
            return null;
        }
        // exact price list first (convention: list 1 = canonical selling price)
        foreach ($prices as $row) {
            if (is_array($row) && (int) ($row['PriceList'] ?? $row['priceList'] ?? 0) === $priceList) {
                $price = (float) ($row['Price'] ?? $row['price'] ?? 0);
                return $price > 0 ? $price : null;
            }
        }
        // fallback: first positive price on any list
        foreach ($prices as $row) {
            if (! is_array($row)) {
                continue;
            }
            $price = (float) ($row['Price'] ?? $row['price'] ?? 0);
            if ($price > 0) {
                return $price;
            }
        }
        return null;
    }
}
