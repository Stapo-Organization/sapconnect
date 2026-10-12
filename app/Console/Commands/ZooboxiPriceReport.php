<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Services\Zooboxi\PriceBook;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * تقرير أسعار زوبوكسي — which products the price book had to floor to
 * wholesale (no retail price, or retail below wholesale) and which have no
 * price at all. SAP is read-only for us, so this is the owner's fix list.
 */
class ZooboxiPriceReport extends Command
{
    protected $signature = 'zooboxi:price-report {--csv=reports/zooboxi-price-issues.csv : where to write the issue list (storage/app)}';

    protected $description = 'List store products whose SAP retail price is missing or below wholesale';

    public function handle(): int
    {
        $counts = [PriceBook::STATUS_OK => 0, PriceBook::STATUS_NO_RETAIL => 0, PriceBook::STATUS_BELOW_WHOLESALE => 0, PriceBook::STATUS_NO_PRICE => 0];
        $rows = [];

        Product::wooSyncable()->production()
            ->select(['id', 'item_code', 'item_name', 'prices', 'sales_items_per_unit', 'zooboxi_active'])
            // chunkById pages on id — an item_code ORDER BY would break the paging
            ->chunkById(500, function ($products) use (&$counts, &$rows) {
                foreach ($products as $p) {
                    $q = PriceBook::forProduct($p);
                    $counts[$q['status']]++;
                    if ($q['status'] === PriceBook::STATUS_OK) {
                        continue;
                    }
                    $rows[] = [
                        $p->item_code,
                        $p->item_name,
                        $q['status'],
                        $q['wholesale'],
                        $q['retail'],
                        $q['shelves']['all'],
                        $q['shelves']['express'],
                        $p->zooboxi_active ? 'yes' : 'no',
                    ];
                }
            });

        usort($rows, fn ($a, $b) => strcmp($a[0], $b[0]));
        $path = (string) $this->option('csv');
        $fh = fopen('php://temp', 'r+');
        fputcsv($fh, ['item_code', 'item_name', 'status', 'wholesale_ex_vat', 'retail_ex_vat', 'shelf_all_inc_vat', 'shelf_express_inc_vat', 'zooboxi_active']);
        foreach ($rows as $r) {
            fputcsv($fh, $r);
        }
        rewind($fh);
        Storage::put($path, "\xEF\xBB\xBF" . stream_get_contents($fh));
        fclose($fh);

        $this->table(['status', 'products'], collect($counts)->map(fn ($n, $s) => [$s, $n])->values()->all());
        $this->info('issue list: ' . Storage::path($path) . ' (' . count($rows) . ' rows)');

        return self::SUCCESS;
    }
}
