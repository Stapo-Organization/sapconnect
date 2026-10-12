<?php

namespace App\Console\Commands;

use App\Models\Brand;
use App\Models\Product;
use App\Models\ProductRegistration;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use League\Csv\Reader;

/**
 * Seed / refresh `product_registrations` from a CLEANED CSV of SFDA registrations —
 * ONE ROW PER REGISTRATION (reference number), not per product.
 *
 * The CSV is produced from the Operations workbook by extracting the master "Saud"
 * sheet's computed values (openspout cannot read its Google-Sheets formula cells, so
 * the values are pulled with openpyxl locally), supplemented by Sheet15 and overlaid
 * with the Registration Tracking Sheet's tracking fields. Expected columns:
 *   reg_key, reference_number, vendor_code, item_name, name_ar, range,
 *   certificate_number, status, request_date, received_date, expiry_date,
 *   factory_name, remarks, source
 *
 * Idempotent: upserts by `reg_key`. `--truncate` fully replaces the table (used for
 * the one-time model switch from per-product to per-registration). Going forward the
 * team manages registrations directly in sapconnect (Filament), so this is a seeder.
 */
class ImportProductRegistrations extends Command
{
    protected $signature = 'sfda:import-registrations
                            {file : Path to the cleaned registrations CSV}
                            {--truncate : Empty the table before seeding (full replace)}
                            {--dry-run : Parse and report without writing}';

    protected $description = 'Seed SFDA product registrations (one row per registration) from a cleaned CSV';

    public function handle(): int
    {
        $file = $this->argument('file');
        if (!is_file($file)) {
            $this->error("File not found: {$file}");
            return self::FAILURE;
        }
        $dry = (bool) $this->option('dry-run');

        $csv = Reader::createFromPath($file, 'r');
        $csv->setHeaderOffset(0);
        $records = iterator_to_array($csv->getRecords());
        $total = count($records);
        $this->info("Read {$total} rows from CSV.");

        // Resolve product/brand links up front (best-effort by vendor_code → SAP item_code).
        $matched = 0;
        $rowsOut = [];
        $statusCounts = [];
        foreach ($records as $r) {
            $regKey = trim((string) ($r['reg_key'] ?? ''));
            if ($regKey === '') {
                continue; // never happens with our extractor, but stay safe
            }

            $status = ProductRegistration::normalizeStatus($r['status'] ?? '');
            $statusCounts[$status] = ($statusCounts[$status] ?? 0) + 1;

            $vendorCode = trim((string) ($r['vendor_code'] ?? ''));
            $productId = null;
            $brandCode = null;
            $brandId = null;
            if ($vendorCode !== '') {
                $product = Product::where('item_code', $vendorCode)->where('source', 'production')->first();
                if ($product) {
                    $matched++;
                    $productId = $product->id;
                    if ($product->items_group_code) {
                        $brandCode = (string) $product->items_group_code;
                        $brandId = Brand::where('code', $product->items_group_code)->value('id');
                    }
                }
            }

            $rowsOut[$regKey] = [
                'reg_key'            => $regKey,
                'item_code'          => $vendorCode ?: $regKey,     // legacy column mirrors the product code
                'vendor_code'        => $vendorCode ?: null,
                'product_id'         => $productId,
                'brand_code'         => $brandCode,
                'brand_id'           => $brandId,
                'item_name'          => $this->nn($r['item_name'] ?? ''),
                'name_ar'            => $this->nn($r['name_ar'] ?? ''),
                'range'              => $this->nn($r['range'] ?? ''),
                'factory_name'       => $this->nn($r['factory_name'] ?? ''),
                'reference_number'   => $this->nn($r['reference_number'] ?? ''),
                'certificate_number' => $this->nn($r['certificate_number'] ?? ''),
                'status'             => $status,
                'is_registered'      => in_array($status, ['complete', 'certificate_printed'], true),
                'request_date'       => $this->date($r['request_date'] ?? ''),
                'received_date'      => $this->date($r['received_date'] ?? ''),
                'expiry_date'        => $this->date($r['expiry_date'] ?? ''),
                'remarks'            => $this->nn($r['remarks'] ?? ''),
                'source_sheet'       => $this->nn($r['source'] ?? ''),
            ];
        }

        $unique = count($rowsOut);
        $this->line('');
        $this->info('──────── Summary ────────');
        $this->line("Registrations:        {$unique}");
        $this->line("  ↳ matched to product: {$matched}");
        $this->line("  ↳ unmatched (no SKU): " . ($unique - $matched));
        arsort($statusCounts);
        foreach ($statusCounts as $st => $c) {
            $this->line(sprintf("  status %-24s %d", $st, $c));
        }

        if ($dry) {
            $this->warn('DRY RUN — nothing written.');
            return self::SUCCESS;
        }

        if ($this->option('truncate')) {
            ProductRegistration::query()->delete();
            $this->warn('Table truncated (full replace).');
        }

        $now = now();
        $created = $updated = 0;
        foreach (array_chunk($rowsOut, 500, true) as $chunk) {
            foreach ($chunk as $row) {
                $exists = ProductRegistration::where('reg_key', $row['reg_key'])->exists();
                ProductRegistration::updateOrCreate(['reg_key' => $row['reg_key']], $row);
                $exists ? $updated++ : $created++;
            }
        }

        $this->info("Written: {$created} new, {$updated} updated. Total now: " . ProductRegistration::count());
        return self::SUCCESS;
    }

    /** Empty string → null (keeps NULLs clean in the DB). */
    private function nn($v): ?string
    {
        $v = trim((string) $v);
        return $v === '' ? null : $v;
    }

    private function date($v): ?string
    {
        $v = trim((string) $v);
        if ($v === '') {
            return null;
        }
        try {
            $d = Carbon::parse($v);
            $y = (int) $d->format('Y');
            return ($y >= 1990 && $y <= 2100) ? $d->format('Y-m-d') : null;
        } catch (\Throwable) {
            return null;
        }
    }
}
