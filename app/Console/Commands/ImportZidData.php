<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Product;
use Illuminate\Support\Facades\DB;

class ImportZidData extends Command
{
    protected $signature = 'zooboxi:import-zid {files* : Path(s) to ZID CSV batch files}
                            {--dry-run : Show what would be imported without making changes}
                            {--reset : Reset all zooboxi_active flags before import}';

    protected $description = 'Import ZID product data (descriptions, categories, images) into sapconnect products via barcode matching';

    private int $matched = 0;
    private int $noBarcode = 0;
    private int $noSapMatch = 0;
    private int $duplicateSkip = 0;
    private int $totalProcessed = 0;
    private array $unmatchedProducts = [];

    public function handle(): int
    {
        $files = $this->argument('files');
        $isDryRun = $this->option('dry-run');
        $reset = $this->option('reset');

        if ($isDryRun) {
            $this->warn('🔍 DRY RUN — no changes will be made.');
        }

        // Reset zooboxi_active if requested
        if ($reset && !$isDryRun) {
            $count = Product::where('zooboxi_active', true)->count();
            Product::where('zooboxi_active', true)->update(['zooboxi_active' => false]);
            $this->info("Reset {$count} products' zooboxi_active flag.");
        }

        // Build barcode → product_id lookup (in-memory for speed)
        $this->info('Building barcode lookup index...');
        $barcodeMap = Product::where('source', 'production')
            ->whereNotNull('piece_barcode')
            ->where('piece_barcode', '!=', '')
            ->pluck('id', 'piece_barcode')
            ->toArray();
        $this->info('  Index built: ' . count($barcodeMap) . ' barcodes.');

        // Track already-matched IDs to skip duplicate barcodes across batches
        $matchedIds = [];

        foreach ($files as $filePath) {
            if (!file_exists($filePath)) {
                $this->error("File not found: {$filePath}");
                continue;
            }

            $this->info("\n📂 Processing: {$filePath}");
            $this->processFile($filePath, $barcodeMap, $matchedIds, $isDryRun);
        }

        // Summary
        $this->newLine();
        $this->table(
            ['Metric', 'Count'],
            [
                ['Total ZID rows processed', $this->totalProcessed],
                ['✅ Matched & imported', $this->matched],
                ['⚠️ No barcode in ZID', $this->noBarcode],
                ['❌ No SAP match', $this->noSapMatch],
                ['🔄 Duplicate SKU (skipped)', $this->duplicateSkip],
            ]
        );

        $matchRate = $this->totalProcessed > 0
            ? round($this->matched / $this->totalProcessed * 100, 1)
            : 0;
        $this->info("Match rate: {$matchRate}%");

        // Export unmatched
        if (!empty($this->unmatchedProducts)) {
            $unmatchedPath = storage_path('app/zid_unmatched.csv');
            $fp = fopen($unmatchedPath, 'w');
            fputcsv($fp, ['sku', 'name_ar', 'name_en']);
            foreach ($this->unmatchedProducts as $row) {
                fputcsv($fp, $row);
            }
            fclose($fp);
            $this->info("📄 Unmatched products saved to: {$unmatchedPath}");
        }

        return 0;
    }

    private function processFile(string $filePath, array &$barcodeMap, array &$matchedIds, bool $isDryRun): void
    {
        $handle = fopen($filePath, 'r');
        if (!$handle) {
            $this->error("Cannot open file: {$filePath}");
            return;
        }

        // Read header
        $header = fgetcsv($handle);
        if (!$header) {
            $this->error("Empty file: {$filePath}");
            fclose($handle);
            return;
        }

        // Clean BOM from first header field
        $header[0] = preg_replace('/^\xEF\xBB\xBF/', '', $header[0]);

        $rowCount = 0;
        $batchData = [];

        while (($row = fgetcsv($handle)) !== false) {
            if (count($row) !== count($header)) {
                continue; // Skip malformed rows
            }

            $data = array_combine($header, $row);
            $this->totalProcessed++;
            $rowCount++;

            $sku = trim($data['sku'] ?? '');

            // Skip rows without SKU
            if (empty($sku)) {
                $this->noBarcode++;
                continue;
            }

            // Find matching SAP product by barcode
            $productId = $barcodeMap[$sku] ?? null;

            if (!$productId) {
                $this->noSapMatch++;
                $this->unmatchedProducts[] = [
                    $sku,
                    mb_substr($data['name_ar'] ?? '', 0, 100),
                    mb_substr($data['name_en'] ?? '', 0, 100),
                ];
                continue;
            }

            // Skip if already matched (duplicate barcode across batches)
            if (isset($matchedIds[$productId])) {
                $this->duplicateSkip++;
                continue;
            }

            $matchedIds[$productId] = true;

            // Parse images into JSON array
            $images = $this->parseImages($data['images'] ?? '');

            // Build update data
            $updateData = [
                'zooboxi_active' => true,
                'zb_name_ar' => $this->clean($data['name_ar'] ?? null, 500),
                'zb_name_en' => $this->clean($data['name_en'] ?? null, 500),
                'zb_description_ar' => $data['description_ar'] ?? null,
                'zb_description_en' => $data['description_en'] ?? null,
                'zb_short_description_ar' => $data['short_description_ar'] ?? null,
                'zb_short_description_en' => $data['short_description_en'] ?? null,
                'zb_categories_ar' => $this->clean($data['categories_ar'] ?? null),
                'zb_categories_en' => $this->clean($data['categories_en'] ?? null),
                'zb_keywords' => $this->clean($data['keywords'] ?? null, 1000),
                'zb_seo_title_ar' => $this->clean($data['product_page_title_ar'] ?? null, 500),
                'zb_seo_description_ar' => $data['product_page_description_ar'] ?? null,
                'zb_seo_title_en' => $this->clean($data['product_page_title_en'] ?? null, 500),
                'zb_seo_description_en' => $data['product_page_description_en'] ?? null,
                'zb_images' => !empty($images) ? $images : null,
                'zb_weight' => is_numeric($data['weight'] ?? null) ? (float) $data['weight'] : null,
                'zb_weight_unit' => $this->clean($data['weight_unit'] ?? null, 10),
            ];

            if (!$isDryRun) {
                $batchData[] = ['id' => $productId, 'data' => $updateData];

                // Flush in batches of 100
                if (count($batchData) >= 100) {
                    $this->flushBatch($batchData);
                    $batchData = [];
                }
            }

            $this->matched++;

            if ($rowCount % 500 === 0) {
                $this->line("  ... processed {$rowCount} rows ({$this->matched} matched)");
            }
        }

        // Flush remaining
        if (!$isDryRun && !empty($batchData)) {
            $this->flushBatch($batchData);
        }

        fclose($handle);
        $this->info("  Done: {$rowCount} rows processed.");
    }

    private function flushBatch(array $batchData): void
    {
        DB::transaction(function () use ($batchData) {
            foreach ($batchData as $item) {
                Product::where('id', $item['id'])->update($item['data']);
            }
        });
    }

    private function parseImages(?string $imagesStr): array
    {
        if (empty($imagesStr)) return [];

        // ZID exports images as comma-separated URLs
        $urls = array_filter(
            array_map('trim', explode(',', $imagesStr)),
            fn($url) => !empty($url) && filter_var($url, FILTER_VALIDATE_URL)
        );

        return array_values($urls);
    }

    private function clean(?string $value, int $maxLength = 0): ?string
    {
        if ($value === null || trim($value) === '') return null;
        $value = trim($value);
        if ($maxLength > 0 && mb_strlen($value) > $maxLength) {
            $value = mb_substr($value, 0, $maxLength);
        }
        return $value;
    }
}
