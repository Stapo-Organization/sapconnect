<?php

namespace App\Services\SAP;

use App\Models\ProductBarcode;
use Illuminate\Support\Facades\DB;

/**
 * Decides which SAP barcode is the PIECE barcode of an item and lists every
 * usable barcode the item carries (piece / carton / other).
 *
 * Rule (validated 2026-10-05 against 650k POS-scanned invoice lines, 99.3% agreement):
 *   piece  = ItemBarCodeCollection entry whose UoMEntry == InventoryUoMEntry
 *            (SAP's inventory unit is the retail piece; invoices sell in that unit)
 *   carton = entry whose UoMEntry is the default sales/purchasing unit (≠ inventory)
 *   other  = any other real barcode
 * Placeholders ('X', the item code, non-digit strings, < 8 or > 14 digits) are ignored.
 * When several piece barcodes exist, the one already stored on the product wins
 * (stability for store SKUs), then SAP's main BarCode, then the first listed.
 */
class ItemBarcodeResolver
{
    public static function isReal(?string $value, string $itemCode): bool
    {
        $v = trim((string) $value);
        if ($v === '' || $v === $itemCode) {
            return false;
        }
        return (bool) preg_match('/^\d{8,14}$/', $v);
    }

    /** Digits only, leading zeros stripped: the key the tolerant lookup matches on. */
    public static function normalize(?string $value): string
    {
        return ltrim(preg_replace('/\D+/', '', (string) $value), '0');
    }

    /**
     * @param  array  $item  SAP Items row with BarCode, InventoryUoMEntry, DefaultSalesUoMEntry,
     *                       DefaultPurchasingUoMEntry, ItemBarCodeCollection
     * @return array{piece: ?string, carton: ?string, rows: array<int, array<string, mixed>>}
     */
    public static function resolve(array $item, ?string $currentPiece = null): array
    {
        $code = (string) ($item['ItemCode'] ?? '');
        $inv = $item['InventoryUoMEntry'] ?? null;
        $sales = $item['DefaultSalesUoMEntry'] ?? null;
        $purch = $item['DefaultPurchasingUoMEntry'] ?? null;

        $piece = [];
        $carton = [];
        $rows = [];
        foreach (($item['ItemBarCodeCollection'] ?? []) as $bc) {
            $v = trim((string) ($bc['Barcode'] ?? ''));
            if (! self::isReal($v, $code)) {
                continue;
            }
            $u = $bc['UoMEntry'] ?? null;
            if ($inv !== null && $u === $inv) {
                $kind = 'piece';
                $piece[] = $v;
            } elseif (($sales !== null && $u === $sales && $sales !== $inv) || ($purch !== null && $u === $purch && $purch !== $inv)) {
                $kind = 'carton';
                $carton[] = $v;
            } else {
                $kind = 'other';
            }
            $rows[$v] = [
                'barcode' => $v,
                'barcode_norm' => self::normalize($v),
                'kind' => $kind,
                'uom_entry' => is_numeric($u) ? (int) $u : null,
                'free_text' => isset($bc['FreeText']) ? mb_substr((string) $bc['FreeText'], 0, 100) : null,
                'is_primary' => false,
            ];
        }

        $main = trim((string) ($item['BarCode'] ?? ''));
        $main = self::isReal($main, $code) ? $main : null;
        $current = self::isReal($currentPiece, $code) ? trim((string) $currentPiece) : null;

        $chosen = null;
        if ($piece) {
            if ($current !== null && in_array($current, $piece, true)) {
                $chosen = $current;
            } elseif ($main !== null && in_array($main, $piece, true)) {
                $chosen = $main;
            } else {
                $chosen = $piece[0];
            }
        } elseif ($current !== null) {
            $chosen = $current;
        } elseif ($main !== null && ! in_array($main, $carton, true)) {
            $chosen = $main;
        }

        if ($chosen !== null) {
            if (! isset($rows[$chosen])) {
                $rows[$chosen] = [
                    'barcode' => $chosen,
                    'barcode_norm' => self::normalize($chosen),
                    'kind' => 'piece',
                    'uom_entry' => is_numeric($inv) ? (int) $inv : null,
                    'free_text' => null,
                    'is_primary' => false,
                ];
            }
            $rows[$chosen]['is_primary'] = true;
        }

        return [
            'piece' => $chosen,
            'carton' => $carton[0] ?? null,
            'rows' => array_values($rows),
        ];
    }

    /**
     * Mirror SAP's barcode rows for one item into product_barcodes (source=sap).
     * Rows from other sources (pos_invoice, manual) are left alone.
     * Writes only what changed, so the hourly sync stays cheap.
     */
    public static function syncRows(string $itemCode, array $rows): void
    {
        $existing = ProductBarcode::where('item_code', $itemCode)->where('source', 'sap')->get()->keyBy('barcode');
        $seen = [];
        foreach ($rows as $r) {
            $seen[$r['barcode']] = true;
            $row = $existing->get($r['barcode']);
            if (! $row) {
                ProductBarcode::updateOrCreate(
                    ['item_code' => $itemCode, 'barcode' => $r['barcode']],
                    $r + ['source' => 'sap']
                );
                continue;
            }
            $dirty = false;
            foreach (['barcode_norm', 'kind', 'uom_entry', 'free_text', 'is_primary'] as $f) {
                if ((string) $row->{$f} !== (string) $r[$f]) {
                    $dirty = true;
                    break;
                }
            }
            if ($dirty) {
                $row->fill($r)->save();
            }
        }
        $stale = $existing->keys()->filter(fn ($b) => ! isset($seen[$b]))->values()->all();
        if ($stale) {
            ProductBarcode::where('item_code', $itemCode)->where('source', 'sap')->whereIn('barcode', $stale)->delete();
        }
    }

    /**
     * Resolve any typed/scanned code to an item code through product_barcodes,
     * tolerant to leading zeros and non-digit noise. Piece barcodes win over
     * carton ones; a conflicting (shared) barcode goes to the primary row.
     */
    public static function lookupItemCode(string $raw): ?string
    {
        $norm = self::normalize($raw);
        if ($norm === '' || strlen($norm) < 6) {
            return null;
        }
        return ProductBarcode::where('barcode_norm', $norm)
            ->orderByRaw("CASE kind WHEN 'piece' THEN 0 WHEN 'pos' THEN 1 WHEN 'carton' THEN 2 ELSE 3 END")
            ->orderByDesc('is_primary')
            ->orderByDesc('scan_count')
            ->value('item_code');
    }
}
