<?php

namespace App\Console\Commands;

use App\Models\Warehouse;
use App\Services\Counting\AbcClassificationService;
use Illuminate\Console\Command;

class ClassifyAbcCommand extends Command
{
    protected $signature = 'counting:classify-abc
                            {--warehouse= : Specific warehouse code to classify}
                            {--months=12 : Number of months of sales data to analyze}';

    protected $description = 'Calculate ABC classification for products in warehouses based on sales data';

    // Retail store warehouses that need cycle counting
    private const STORE_WAREHOUSES = [
        'RUH002', 'RUH004', 'RUH005', 'RUH006', 'RUH007', 'RUH008',
        'JED002', 'DMM001', 'MED001', 'ABH001', 'UZH001', 'KHO001', 'HBT001',
    ];

    public function handle(): int
    {
        $service = new AbcClassificationService();
        $months = (int) $this->option('months');
        $specificWarehouse = $this->option('warehouse');

        $warehouses = $specificWarehouse
            ? [$specificWarehouse]
            : self::STORE_WAREHOUSES;

        $this->info("🔄 Classifying products (ABC) using {$months} months of sales data...");
        $this->newLine();

        $totalClassified = 0;

        foreach ($warehouses as $code) {
            $warehouse = Warehouse::where('warehouse_code', $code)->first();
            $name = $warehouse?->warehouse_name ?? $code;

            $this->info("📊 {$code} — {$name}");

            try {
                $result = $service->classifyWarehouse($code, $months);

                $this->table(
                    ['Class', 'Items'],
                    [
                        ['A', $result['A']],
                        ['B', $result['B']],
                        ['C', $result['C']],
                        ['Total', $result['total']],
                    ]
                );

                $totalClassified += $result['total'];
            } catch (\Exception $e) {
                $this->error("  ❌ Error: {$e->getMessage()}");
            }

            $this->newLine();
        }

        $this->info("✅ Done! Classified {$totalClassified} items across " . count($warehouses) . " warehouses.");

        return Command::SUCCESS;
    }
}
