<?php

namespace App\Console\Commands;

use App\Models\InventoryCounting;
use App\Models\InventoryCountingBatch;
use App\Models\InventoryCountingSnapshot;
use App\Services\ShipGo\PagedSapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Freeze SAP's book quantity (InStock) for every item of a full count's
 * warehouse at the moment counting starts. Read-only: GET Items only.
 *
 * The 10-minute stock mirror can be stale, so the full count measures every
 * variance against this snapshot instead.
 *
 * Batch-managed items also get their SAP batches in this warehouse (expiry
 * dates via the saved `batchesitems` query, GET) so counters can tap the date
 * printed on the pack. --batches-only refreshes just those.
 */
class SnapshotCountingStock extends Command
{
    protected $signature = 'counting:snapshot {id : inventory_countings.id} {--page=200} {--batches-only} {--costs-only}';
    protected $description = 'Snapshot SAP InStock for a full count (read-only)';

    public function handle(): int
    {
        $counting = InventoryCounting::find($this->argument('id'));
        if (! $counting) {
            $this->error('Counting session not found');
            return self::FAILURE;
        }
        $wh = $counting->warehouse_code;
        $cutoff = now();
        $sap = new PagedSapClient((int) $this->option('page'));
        $sap->setCompanyDb('PPTC_V5_PROD');

        if ($this->option('costs-only')) {
            $this->snapshotCosts($sap, $counting);
            return self::SUCCESS;
        }

        if ($this->option('batches-only')) {
            $codes = InventoryCountingSnapshot::where('inventory_counting_id', $counting->id)->pluck('item_code')->all();
            $batchItems = $this->batchManaged($sap, $codes);
            $this->snapshotBatches($sap, $counting, $batchItems);
            return self::SUCCESS;
        }

        $counting->update(['snapshot_status' => 'running']);

        try {
            $batchItems = [];
            $costs = DB::table('product_costs')->pluck('cost_proxy_sar', 'item_code');

            $skip = 0;
            $rows = 0;
            $seen = [];
            do {
                $resp = $sap->get('Items', [
                    '$select' => 'ItemCode,ManageBatchNumbers,ItemWarehouseInfoCollection',
                    '$filter' => "startswith(ItemCode,'P')",
                    '$orderby' => 'ItemCode',
                    '$skip' => $skip,
                ]);
                $items = $resp['value'] ?? [];
                $batch = [];
                foreach ($items as $it) {
                    $code = $it['ItemCode'] ?? null;
                    if (! $code || isset($seen[$code])) {
                        continue;
                    }
                    $seen[$code] = true;
                    foreach ($it['ItemWarehouseInfoCollection'] ?? [] as $w) {
                        if (($w['WarehouseCode'] ?? null) !== $wh) {
                            continue;
                        }
                        $qty = (float) ($w['InStock'] ?? 0);
                        if ($qty == 0.0) {
                            break; // only items the book says are here
                        }
                        $batch[] = [
                            'inventory_counting_id' => $counting->id,
                            'item_code' => $code,
                            'system_qty' => $qty,
                            'unit_cost' => isset($costs[$code]) ? (float) $costs[$code] : null,
                            'sap_unit_cost' => isset($w['StandardAveragePrice']) ? (float) $w['StandardAveragePrice'] : null,
                            'created_at' => $cutoff,
                            'updated_at' => $cutoff,
                        ];
                        if (($it['ManageBatchNumbers'] ?? 'tNO') === 'tYES') {
                            $batchItems[] = $code;
                        }
                        break;
                    }
                }
                if ($batch) {
                    InventoryCountingSnapshot::upsert($batch, ['inventory_counting_id', 'item_code'], ['system_qty', 'unit_cost', 'sap_unit_cost', 'updated_at']);
                    $rows += count($batch);
                }
                $skip += count($items);
                $this->line("  page skip={$skip} rows={$rows}");
            } while (! empty($items));

            // Expiry choices are a convenience: a batch failure never blocks the count.
            try {
                $this->snapshotBatches($sap, $counting, $batchItems);
            } catch (\Throwable $e) {
                Log::warning("counting:snapshot {$counting->id} batches failed: " . $e->getMessage());
            }

            $counting->update(['snapshot_status' => 'ready', 'snapshot_at' => $cutoff]);
            $this->info("Snapshot ready: {$rows} items with stock in {$wh}");
            return self::SUCCESS;
        } catch (\Throwable $e) {
            Log::error("counting:snapshot {$counting->id} failed: " . $e->getMessage());
            $counting->update(['snapshot_status' => 'failed']);
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }

    /**
     * SAP's warehouse cost for every item of the count — the book items and
     * anything found on the shelves that the book did not list (stored with a
     * zero book so its overage has a value too). Read-only GET Items.
     */
    private function snapshotCosts(PagedSapClient $sap, InventoryCounting $counting): void
    {
        $wh = $counting->warehouse_code;
        $codes = InventoryCountingSnapshot::where('inventory_counting_id', $counting->id)->pluck('item_code')
            ->merge(DB::table('inventory_counting_lines')->where('inventory_counting_id', $counting->id)->distinct()->pluck('item_code'))
            ->unique()->values()->all();
        $proxy = DB::table('product_costs')->whereIn('item_code', $codes)->pluck('cost_proxy_sar', 'item_code');
        $known = InventoryCountingSnapshot::where('inventory_counting_id', $counting->id)->pluck('item_code')->flip();
        $now = now();
        $rows = 0;
        foreach (array_chunk($codes, 40) as $chunk) {
            $filter = implode(' or ', array_map(fn ($c) => "ItemCode eq '" . str_replace("'", "''", $c) . "'", $chunk));
            $resp = $sap->get('Items', ['$select' => 'ItemCode,ItemWarehouseInfoCollection', '$filter' => $filter]);
            foreach ($resp['value'] ?? [] as $it) {
                $w = collect($it['ItemWarehouseInfoCollection'] ?? [])->firstWhere('WarehouseCode', $wh);
                $cost = isset($w['StandardAveragePrice']) ? (float) $w['StandardAveragePrice'] : null;
                if (isset($known[$it['ItemCode']])) {
                    InventoryCountingSnapshot::where('inventory_counting_id', $counting->id)->where('item_code', $it['ItemCode'])
                        ->update(['sap_unit_cost' => $cost, 'updated_at' => $now]);
                } else {
                    InventoryCountingSnapshot::create([
                        'inventory_counting_id' => $counting->id, 'item_code' => $it['ItemCode'], 'system_qty' => 0,
                        'unit_cost' => isset($proxy[$it['ItemCode']]) ? (float) $proxy[$it['ItemCode']] : null, 'sap_unit_cost' => $cost,
                    ]);
                }
                $rows++;
            }
        }
        $this->info("SAP costs: {$rows} items in {$wh}");
    }

    /** Which of these items SAP manages by batch (only those carry expiry dates). */
    private function batchManaged(PagedSapClient $sap, array $codes): array
    {
        $out = [];
        foreach (array_chunk($codes, 40) as $chunk) {
            $filter = implode(' or ', array_map(fn ($c) => "ItemCode eq '" . str_replace("'", "''", $c) . "'", $chunk));
            $resp = $sap->get('Items', ['$select' => 'ItemCode,ManageBatchNumbers', '$filter' => $filter]);
            foreach ($resp['value'] ?? [] as $it) {
                if (($it['ManageBatchNumbers'] ?? 'tNO') === 'tYES') {
                    $out[] = $it['ItemCode'];
                }
            }
        }
        return $out;
    }

    /** SAP batches with stock in the count's warehouse, one read-only query per item. */
    private function snapshotBatches(PagedSapClient $sap, InventoryCounting $counting, array $codes): void
    {
        $wh = $counting->warehouse_code;
        $now = now();
        $rows = 0;
        foreach ($codes as $i => $code) {
            $resp = $sap->get("SQLQueries('batchesitems')/List", ['ItemCode' => "'" . str_replace("'", "''", $code) . "'"]);
            $batch = [];
            foreach ($resp['value'] ?? [] as $r) {
                if (($r['WhsCode'] ?? null) !== $wh || empty($r['BatchNumber']) || (float) ($r['Quantity'] ?? 0) <= 0) {
                    continue;
                }
                $exp = preg_match('/^(\d{4})(\d{2})(\d{2})$/', (string) ($r['ExpiryDate'] ?? ''), $m) ? "{$m[1]}-{$m[2]}-{$m[3]}" : null;
                $batch[] = [
                    'inventory_counting_id' => $counting->id,
                    'item_code' => $code,
                    'batch' => mb_substr((string) $r['BatchNumber'], 0, 64),
                    'expiry_date' => $exp,
                    'quantity' => (float) $r['Quantity'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
            if ($batch) {
                InventoryCountingBatch::upsert($batch, ['inventory_counting_id', 'item_code', 'batch'], ['expiry_date', 'quantity', 'updated_at']);
                $rows += count($batch);
            }
            if (($i + 1) % 100 === 0) {
                $this->line('  batches ' . ($i + 1) . '/' . count($codes) . " rows={$rows}");
            }
        }
        $this->info('Batches: ' . count($codes) . " batch items, {$rows} batches in {$wh}");
    }
}
