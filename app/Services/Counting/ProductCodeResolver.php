<?php

namespace App\Services\Counting;

use App\Models\Product;
use App\Models\ProductBarcode;
use App\Services\SAP\ItemBarcodeResolver;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Resolve whatever a counter scans or types — piece barcode, carton barcode,
 * a barcode the cashier uses, or the SAP item code — to a product, and say
 * which kind of code it was so a carton scan can be counted as cartons.
 */
class ProductCodeResolver
{
    /**
     * @return array{product: Product, kind: string, pack_size: float|null}|null
     *   kind: piece | carton | pos | other | item_code
     */
    public static function resolve(string $raw): ?array
    {
        $code = trim($raw);
        if ($code === '') {
            return null;
        }

        $product = Product::where('item_code', strtoupper($code))->first();
        if ($product) {
            return self::result($product, 'item_code');
        }

        $product = Product::where('piece_barcode', $code)->first();
        if ($product) {
            return self::result($product, 'piece');
        }

        if (Schema::hasTable('product_barcodes')) {
            $norm = ItemBarcodeResolver::normalize($code);
            if ($norm !== '' && strlen($norm) >= 6) {
                $row = ProductBarcode::where('barcode_norm', $norm)
                    ->orderByRaw("CASE kind WHEN 'piece' THEN 0 WHEN 'pos' THEN 1 WHEN 'carton' THEN 2 ELSE 3 END")
                    ->orderByDesc('is_primary')
                    ->orderByDesc('scan_count')
                    ->first();
                if ($row) {
                    $product = Product::where('item_code', $row->item_code)->first();
                    if ($product) {
                        return self::result($product, $row->kind);
                    }
                }
            }
        }

        // Last resort: leading-zero tolerant match on the piece barcode.
        $digits = preg_replace('/\D+/', '', $code);
        if ($digits !== '' && strlen($digits) >= 6) {
            $stripped = ltrim($digits, '0');
            $expr = DB::getDriverName() === 'sqlite'
                ? "LTRIM(piece_barcode, '0') = ?"
                : "TRIM(LEADING '0' FROM piece_barcode) = ?";
            $product = Product::whereNotNull('piece_barcode')->whereRaw($expr, [$stripped])->first();
            if ($product) {
                return self::result($product, 'piece');
            }
        }

        return null;
    }

    private static function result(Product $product, string $kind): array
    {
        $pack = (float) ($product->sales_items_per_unit ?? 0);
        return [
            'product' => $product,
            'kind' => $kind,
            // A carton barcode carries its piece count; otherwise offer the
            // sales pack as the default carton size (editable in the app).
            'pack_size' => $pack > 1 ? $pack : null,
        ];
    }
}
