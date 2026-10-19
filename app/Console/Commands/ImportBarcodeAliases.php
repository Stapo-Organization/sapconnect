<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Models\ProductBarcode;
use App\Services\SAP\ItemBarcodeResolver;
use Illuminate\Console\Command;

/**
 * Load extra barcodes for items from a CSV (item_code, barcode, kind, source, scan_count)
 * into product_barcodes. Never overwrites an existing (item_code, barcode) row and never
 * steals a barcode that another item already owns. Does not touch products.piece_barcode.
 */
class ImportBarcodeAliases extends Command
{
    protected $signature = 'products:import-barcode-aliases {file} {--dry-run}';
    protected $description = 'Import additional product barcodes (POS-observed or manual) into product_barcodes';

    public function handle(): int
    {
        $file = $this->argument('file');
        if (! is_readable($file)) {
            $this->error("Cannot read $file");
            return self::FAILURE;
        }
        $fh = fopen($file, 'r');
        $header = fgetcsv($fh);
        if (! $header || ! in_array('item_code', $header, true) || ! in_array('barcode', $header, true)) {
            $this->error('CSV needs at least item_code,barcode columns');
            return self::FAILURE;
        }
        $idx = array_flip($header);
        $stats = ['rows' => 0, 'added' => 0, 'exists' => 0, 'conflict' => 0, 'no_product' => 0, 'junk' => 0];
        $dry = (bool) $this->option('dry-run');

        while (($r = fgetcsv($fh)) !== false) {
            $stats['rows']++;
            $code = trim($r[$idx['item_code']] ?? '');
            $bc = trim($r[$idx['barcode']] ?? '');
            if (! ItemBarcodeResolver::isReal($bc, $code)) {
                $stats['junk']++;
                continue;
            }
            if (! Product::where('item_code', $code)->exists()) {
                $stats['no_product']++;
                continue;
            }
            $norm = ItemBarcodeResolver::normalize($bc);
            if (ProductBarcode::where('item_code', $code)->where('barcode_norm', $norm)->exists()) {
                $stats['exists']++;
                continue;
            }
            if (ProductBarcode::where('barcode_norm', $norm)->where('item_code', '!=', $code)->exists()) {
                $stats['conflict']++;
                $this->line("  conflict: $code $bc already belongs to another item, skipped");
                continue;
            }
            $stats['added']++;
            if ($dry) {
                continue;
            }
            ProductBarcode::create([
                'item_code' => $code,
                'barcode' => $bc,
                'barcode_norm' => $norm,
                'kind' => trim($r[$idx['kind']] ?? '') ?: 'pos',
                'source' => trim($r[$idx['source']] ?? '') ?: 'manual',
                'scan_count' => (int) ($r[$idx['scan_count']] ?? 0),
                'is_primary' => false,
            ]);
        }
        fclose($fh);
        $this->info(($dry ? '[dry-run] ' : '') . json_encode($stats));
        return self::SUCCESS;
    }
}
