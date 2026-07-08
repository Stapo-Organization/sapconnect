<?php

namespace App\Console\Commands;

use App\Models\Brand;
use App\Models\Product;
use App\Models\ProductRegistration;
use App\Models\RegistrationPriority;
use Carbon\Carbon;
use Illuminate\Console\Command;
use OpenSpout\Reader\XLSX\Reader as XlsxReader;

/**
 * ONE-TIME (idempotent) import of the SFDA registration tabs of the Operations
 * workbook into `product_registrations`, consolidating the 5 overlapping sheets
 * into one current row per SKU.
 *
 * Design notes:
 *  - Columns are mapped by HEADER NAME (not fixed index) because the sheets have
 *    different layouts, duplicate "Vendor Code"/"Status" columns, and drift.
 *  - Dedup key = normalized item/vendor code. On collision we KEEP the most-advanced
 *    row (has certificate > higher status rank > latest request date) and back-fill
 *    any blank fields from the other rows, so the merged record is as complete as
 *    the sheets allow.
 *  - "Current/active only": a row that ends up `rejected` with NO certificate is
 *    dropped as historical noise (per the migration decision).
 *  - Product/brand links are best-effort & nullable (legacy codes rarely match SAP).
 *  - --dry-run reports counts without writing.
 */
class ImportProductRegistrations extends Command
{
    protected $signature = 'sfda:import-registrations
                            {file : Path to the Operation Tasks .xlsx}
                            {--dry-run : Parse and report counts without writing}';

    protected $description = 'Import & consolidate SFDA product registrations from the Operations workbook';

    /**
     * Registration sheets to read. We deliberately EXCLUDE "Saud" and "Sheet12":
     * both are Google-Sheets formula mirrors (=IFERROR(__xludf.DUMMYFUNCTION…) /
     * =Saud!F1) whose cached values openspout cannot read — it returns the formula
     * text. "Sheet14" is the readable values-twin of "Saud" (same vendor codes),
     * and "Sheet15" holds the rest. Registration Tracking gives the code + EN/AR
     * name (its Status is a =VLOOKUP we can't resolve → falls back to 'new').
     */
    private const REG_SHEETS = ['Registration Tracking Sheet', 'Sheet14', 'Sheet15'];

    private const PRIORITY_SHEET = 'FDA Registration Priority';

    public function handle(): int
    {
        $file = $this->argument('file');
        if (!is_file($file)) {
            $this->error("File not found: {$file}");
            return self::FAILURE;
        }
        $dry = (bool) $this->option('dry-run');

        $reader = new XlsxReader();
        $reader->open($file);

        $acc = [];          // item_code => merged record array
        $rowsSeen = 0;
        $priorities = [];   // brand_code => [priority, brand_name]

        foreach ($reader->getSheetIterator() as $sheet) {
            $sheetName = $sheet->getName();

            if ($sheetName === self::PRIORITY_SHEET) {
                $this->readPriorities($sheet, $priorities);
                continue;
            }
            if (!in_array($sheetName, self::REG_SHEETS, true)) {
                continue;
            }

            $this->info("Reading sheet: {$sheetName}");
            $header = null;
            $map = null;

            foreach ($sheet->getRowIterator() as $row) {
                $cells = $row->toArray();

                if ($header === null) {
                    $header = array_map(fn ($c) => $this->str($c), $cells);
                    $map = $this->resolveColumns($header);
                    continue;
                }

                $rec = $this->extractRecord($cells, $map, $sheetName);
                if ($rec === null) {
                    continue; // no code on this row
                }
                $rowsSeen++;
                $this->mergeInto($acc, $rec);
            }
        }
        $reader->close();

        // Finalize: drop rejected-with-no-certificate, resolve product/brand links.
        $records = [];
        $dropped = 0;
        foreach ($acc as $code => $rec) {
            if ($rec['status'] === 'rejected' && blank($rec['certificate_number'])) {
                $dropped++;
                continue;
            }
            $records[$code] = $this->resolveLinks($rec);
        }

        $matched = count(array_filter($records, fn ($r) => $r['product_id'] !== null));
        $unmatched = count($records) - $matched;

        $this->line('');
        $this->info('──────── Summary ────────');
        $this->line("Rows read (with code):   {$rowsSeen}");
        $this->line("Unique registrations:    " . count($records));
        $this->line("  ↳ matched to product:  {$matched}");
        $this->line("  ↳ unmatched (no SKU):  {$unmatched}");
        $this->line("Dropped (rejected/nocert): {$dropped}");
        $this->line("Brand priorities:        " . count($priorities));

        if ($dry) {
            $this->warn('DRY RUN — nothing written.');
            $this->previewUnmatched($records);
            return self::SUCCESS;
        }

        // Write.
        $new = $updated = 0;
        foreach ($records as $code => $rec) {
            $existing = ProductRegistration::where('item_code', $code)->exists();
            ProductRegistration::updateOrCreate(['item_code' => $code], $rec);
            $existing ? $updated++ : $new++;
        }
        foreach ($priorities as $brandCode => $p) {
            RegistrationPriority::updateOrCreate(
                ['brand_code' => $brandCode],
                ['priority' => $p['priority'], 'brand_name' => $p['brand_name']]
            );
        }

        $this->info("Written: {$new} new, {$updated} updated registrations, " . count($priorities) . ' priorities.');
        return self::SUCCESS;
    }

    /* -------------------- column resolution -------------------- */

    /**
     * Map logical fields to column indices by fuzzy header match.
     * `code` is a LIST of candidate columns (sheets have duplicate Vendor Code cols;
     * we take the first non-empty at extraction time).
     */
    private function resolveColumns(array $header): array
    {
        $map = ['code' => [], 'name_ar' => null, 'item_name' => null, 'range' => null,
                'vendor_code' => null, 'reference_number' => null, 'certificate_number' => null,
                'status' => null, 'is_registered' => null, 'request_date' => null,
                'received_date' => null, 'expiry_date' => null, 'remarks' => null];

        foreach ($header as $idx => $raw) {
            $h = mb_strtolower(trim($raw));
            if ($h === '') continue;

            if (str_contains($h, 'item code') || str_contains($h, 'vendor code') || $h === 'sap code') {
                $map['code'][] = $idx;
                if ($map['vendor_code'] === null) $map['vendor_code'] = $idx;
            } elseif (str_contains($h, 'name ar') || str_contains($h, 'اسم') || str_contains($h, 'arabic')) {
                $map['name_ar'] ??= $idx;
            } elseif (str_contains($h, 'item name') || str_contains($h, 'description')) {
                $map['item_name'] ??= $idx;
            } elseif ($h === 'range') {
                $map['range'] ??= $idx;
            } elseif (str_contains($h, 'product registration')) {
                $map['certificate_number'] ??= $idx;   // MAFE… / FEM-25… certificate
            } elseif (str_contains($h, 'reference') || $h === 'number') {
                $map['reference_number'] ??= $idx;
            } elseif ($h === 'registred' || $h === 'registered') {
                $map['is_registered'] ??= $idx;
            } elseif (str_contains($h, 'request date')) {
                $map['request_date'] ??= $idx;
            } elseif (str_contains($h, 'received date') || str_contains($h, 'recieved date')) {
                $map['received_date'] ??= $idx;
            } elseif (str_contains($h, 'expiry') || str_contains($h, 'expire')) {
                $map['expiry_date'] ??= $idx;
            } elseif (str_contains($h, 'remark')) {
                $map['remarks'] ??= $idx;
            } elseif ($h === 'status') {
                $map['status'] ??= $idx;   // first Status column wins
            }
        }

        return $map;
    }

    private function extractRecord(array $cells, array $map, string $sheet): ?array
    {
        // Code = first non-empty candidate column, normalized.
        $code = null;
        foreach ($map['code'] as $idx) {
            $v = $this->normalizeCode($this->cell($cells, $idx));
            if ($v !== '') { $code = $v; break; }
        }
        if ($code === null || $code === '') {
            return null;
        }

        $rawStatus = $this->cell($cells, $map['status']);

        return [
            'item_code'          => $code,
            'vendor_code'        => $this->str($this->cell($cells, $map['vendor_code'])) ?: $code,
            'name_ar'            => $this->str($this->cell($cells, $map['name_ar'])) ?: null,
            'item_name'          => $this->str($this->cell($cells, $map['item_name'])) ?: null,
            'range'              => $this->str($this->cell($cells, $map['range'])) ?: null,
            'reference_number'   => $this->str($this->cell($cells, $map['reference_number'])) ?: null,
            'certificate_number' => $this->str($this->cell($cells, $map['certificate_number'])) ?: null,
            'status'             => ProductRegistration::normalizeStatus($rawStatus),
            'is_registered'      => $this->truthy($this->cell($cells, $map['is_registered'])),
            'request_date'       => $this->date($this->cell($cells, $map['request_date'])),
            'received_date'      => $this->date($this->cell($cells, $map['received_date'])),
            'expiry_date'        => $this->date($this->cell($cells, $map['expiry_date'])),
            'remarks'            => $this->str($this->cell($cells, $map['remarks'])) ?: null,
            'source_sheet'       => $sheet,
        ];
    }

    /**
     * Merge an incoming record into the accumulator: keep the more-advanced row's
     * status/certificate/source, and back-fill any blank field from either side.
     */
    private function mergeInto(array &$acc, array $rec): void
    {
        $code = $rec['item_code'];
        if (!isset($acc[$code])) {
            $acc[$code] = $rec;
            return;
        }

        $cur = $acc[$code];
        $incomingBetter = $this->isBetter($rec, $cur);
        $winner = $incomingBetter ? $rec : $cur;
        $loser  = $incomingBetter ? $cur : $rec;

        // Start from the winner, back-fill blanks from the loser.
        $merged = $winner;
        foreach ($loser as $k => $v) {
            if (blank($merged[$k] ?? null) && filled($v)) {
                $merged[$k] = $v;
            }
        }
        // is_registered is a bool OR across rows.
        $merged['is_registered'] = ($cur['is_registered'] || $rec['is_registered']);

        $acc[$code] = $merged;
    }

    /** Ranking: has certificate > higher status rank > latest request date. */
    private function isBetter(array $a, array $b): bool
    {
        $aCert = filled($a['certificate_number']);
        $bCert = filled($b['certificate_number']);
        if ($aCert !== $bCert) return $aCert;

        $ar = ProductRegistration::statusRank($a['status']);
        $br = ProductRegistration::statusRank($b['status']);
        if ($ar !== $br) return $ar > $br;

        return (string) ($a['request_date'] ?? '') > (string) ($b['request_date'] ?? '');
    }

    private function resolveLinks(array $rec): array
    {
        $rec['product_id'] = null;
        $rec['brand_code'] = null;
        $rec['brand_id']   = null;

        $product = Product::where('item_code', $rec['item_code'])
            ->where('source', 'production')
            ->first();

        if ($product) {
            $rec['product_id'] = $product->id;
            if ($product->items_group_code) {
                $rec['brand_code'] = (string) $product->items_group_code;
                $rec['brand_id'] = Brand::where('code', $product->items_group_code)->value('id');
            }
        }

        return $rec;
    }

    private function readPriorities($sheet, array &$priorities): void
    {
        $header = null;
        foreach ($sheet->getRowIterator() as $row) {
            $cells = $row->toArray();
            if ($header === null) { $header = true; continue; }
            $brand = $this->str($this->cell($cells, 0));
            $prio  = $this->cell($cells, 1);
            if ($brand === '') continue;
            $priorities[$brand] = [
                'priority'   => is_numeric($prio) ? (int) $prio : 0,
                'brand_name' => $brand,
            ];
        }
    }

    private function previewUnmatched(array $records): void
    {
        $sample = array_slice(
            array_filter($records, fn ($r) => $r['product_id'] === null),
            0, 15, true
        );
        if (empty($sample)) return;
        $this->line('');
        $this->line('Sample unmatched codes (first 15):');
        foreach ($sample as $code => $r) {
            $this->line("  {$code}  —  " . ($r['name_ar'] ?: $r['item_name'] ?: '?'));
        }
    }

    /* -------------------- cell helpers -------------------- */

    private function cell(array $cells, ?int $idx)
    {
        if ($idx === null) return null;
        return $cells[$idx] ?? null;
    }

    private function str($v): string
    {
        if ($v instanceof \DateTimeInterface) return $v->format('Y-m-d');
        if (is_float($v) && floor($v) == $v) return (string) (int) $v; // 361.0 → "361"
        // Collapse embedded newlines / runs of whitespace from the spreadsheet cells.
        return trim(preg_replace('/\s+/u', ' ', (string) ($v ?? '')));
    }

    /** Item/vendor code: trim, uppercase, drop trailing ".0" from float-typed cells. */
    private function normalizeCode($v): string
    {
        $s = $this->str($v);
        return mb_strtoupper($s);
    }

    private function truthy($v): bool
    {
        $s = mb_strtolower($this->str($v));
        return in_array($s, ['yes', 'y', '1', 'true', 'مكتمل'], true);
    }

    private function date($v): ?string
    {
        if ($v instanceof \DateTimeInterface) {
            $y = (int) $v->format('Y');
            return ($y >= 2015 && $y <= 2100) ? $v->format('Y-m-d') : null;
        }
        $s = $this->str($v);
        if ($s === '' || $s === '0') return null;
        try {
            $d = Carbon::parse($s);
            $y = (int) $d->format('Y');
            return ($y >= 2015 && $y <= 2100) ? $d->format('Y-m-d') : null;
        } catch (\Throwable) {
            return null;
        }
    }
}
