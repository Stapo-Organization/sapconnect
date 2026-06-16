<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\WarehouseItemStock;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

/**
 * Pulls per-warehouse stock (InStock) for every "P" item from SAP (read-only
 * OData) into warehouse_item_stocks.
 *
 * Hardened against the failure modes that froze — then briefly wiped — the
 * mirror:
 *  • Overlap lock — the dynamic automation scheduler runs this every 10 min
 *    WITHOUT withoutOverlapping(), so heavy runs used to pile up and hammer SAP.
 *  • Page only on an EMPTY response — SAP Service Layer caps each page at ~20
 *    rows regardless of $top, so "fewer than requested" is NOT the end. (Reading
 *    it as the end ended the pass after one page.)
 *  • Per-page retry + skip — a single timed-out / 500 page no longer aborts the
 *    whole pass.
 *  • Destructive cleanup runs ONLY after a clean pass that refreshed a sane
 *    number of rows (MIN_TOUCHED_FOR_CLEANUP) — a thin/empty pull must never be
 *    allowed to delete the whole table.
 *
 * SAP is import-only: this only issues OData GETs; nothing is written back.
 */
class SyncRecentStock extends Command
{
    protected $signature = 'sap:sync-recent-stock';
    protected $description = 'Smart, resilient sync of SAP per-warehouse stock';

    private const COMPANY_DB = 'PPTC_V5_PROD';
    private const SAP_PAGE = 20;   // SAP Service Layer server-side page cap
    private const MAX_RETRIES = 3;
    private const MAX_FAILED_PAGES = 25;       // bail a pass if SAP is clearly down
    private const MIN_TOUCHED_FOR_CLEANUP = 5000; // safety floor before any delete

    public function handle()
    {
        // Overlap guard: never let two stock syncs hit SAP at once. TTL is long
        // enough to cover a full catalogue pass (~20 rows/page, thousands of pages).
        $lock = Cache::lock('sap:sync-recent-stock', 7200);
        if (!$lock->get()) {
            $this->warn('Another stock sync is already running — skipping this tick.');
            return self::SUCCESS;
        }

        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        // Long catalogue passes OOM'd at the default 128M (query-log growth +
        // per-row Eloquent). Give headroom and stop buffering every query.
        @ini_set('memory_limit', '512M');
        DB::disableQueryLog();

        $this->info('Starting resilient stock sync...');
        $syncStartTime = now();

        $totalItems = 0;
        $touched = 0;
        $failedPages = 0;
        $reachedEnd = false; // saw an empty page (true end of catalogue)

        try {
            $sapClient = app(\App\Services\SAP\SapClient::class);
            $sapClient->setCompanyDb(self::COMPANY_DB);

            $skip = 0;
            while (true) {
                $items = $this->fetchPage($sapClient, $skip);

                if ($items === false) {
                    // Page failed after retries — skip it, keep going so one bad
                    // page doesn't lose the whole refresh, but the pass is no
                    // longer "clean" (we won't run the destructive cleanup).
                    $failedPages++;
                    $skip += self::SAP_PAGE;
                    if ($failedPages >= self::MAX_FAILED_PAGES) {
                        $this->warn('Too many failed pages — SAP likely unavailable; ending pass early.');
                        break;
                    }
                    continue;
                }

                if (empty($items)) {
                    $reachedEnd = true;
                    break; // the ONLY valid end-of-catalogue signal
                }

                $now = now();
                $rows = [];
                foreach ($items as $item) {
                    $itemCode = $item['ItemCode'] ?? null;
                    if (!$itemCode) {
                        continue;
                    }
                    foreach (($item['ItemWarehouseInfoCollection'] ?? []) as $whs) {
                        $warehouseCode = $whs['WarehouseCode'] ?? null;
                        $inStock   = $whs['InStock']   ?? 0;
                        $committed = $whs['Committed'] ?? 0;
                        $ordered   = $whs['Ordered']   ?? 0;
                        // Keep a row if ANY of the three is non-zero — a warehouse can
                        // have committed/ordered with zero physical stock (e.g. inbound).
                        if ($warehouseCode && ($inStock != 0 || $committed != 0 || $ordered != 0)) {
                            $rows[] = [
                                'item_code'      => $itemCode,
                                'warehouse_code' => $warehouseCode,
                                'in_stock'       => $inStock,
                                'committed'      => $committed,
                                'ordered'        => $ordered,
                                'created_at'     => $now,
                                'updated_at'     => $now,
                            ];
                        }
                    }
                }
                if (!empty($rows)) {
                    // One memory-light upsert per page (vs SELECT+write per row),
                    // keyed on the (item_code, warehouse_code) unique index.
                    WarehouseItemStock::upsert($rows, ['item_code', 'warehouse_code'], ['in_stock', 'committed', 'ordered', 'updated_at']);
                    $touched += count($rows);
                }

                $count = count($items);
                $totalItems += $count;
                $skip += $count;
                usleep(200000); // 0.2s — be gentle on SAP
            }

            // Cleanup is destructive (rows not refreshed = went to 0 / removed in
            // SAP). Run it ONLY on a clean pass to the true end that also refreshed
            // a sane number of rows — otherwise a thin/failed pull would wipe live
            // stock (which is exactly what happened once).
            $clean = $reachedEnd && $failedPages === 0;
            $deleted = 0;
            $status = 'partial';
            if ($clean && $touched >= self::MIN_TOUCHED_FOR_CLEANUP) {
                $deleted = WarehouseItemStock::where('updated_at', '<', $syncStartTime)->delete();
                $status = 'success';
            } elseif ($clean) {
                Log::warning("Stock sync reached end but only touched {$touched} rows (< " . self::MIN_TOUCHED_FOR_CLEANUP . ") — skipping cleanup for safety.");
            }

            $msg = sprintf(
                'Stock sync %s. items=%d touched=%d failedPages=%d reachedEnd=%s cleaned=%d',
                $status, $totalItems, $touched, $failedPages, $reachedEnd ? 'yes' : 'no', $deleted
            );
            $this->info($msg);
            if ($automation) {
                $automation->update(['last_run_status' => $status]);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => $status, 'message' => $msg]);
            }
        } catch (\Throwable $e) {
            $msg = 'Error syncing recent stock: ' . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        } finally {
            $lock->release();
        }

        return self::SUCCESS;
    }

    /**
     * Fetch one page with warehouse stock. Retries transient SAP failures
     * (timeouts / 500s); returns the items array on success, [] at the end of
     * the catalogue, or false if the page failed after all retries.
     *
     * @return array|false
     */
    private function fetchPage(\App\Services\SAP\SapClient $sapClient, int $skip)
    {
        for ($attempt = 1; $attempt <= self::MAX_RETRIES; $attempt++) {
            try {
                $response = $sapClient->get('Items', [
                    '$select'  => 'ItemCode,ItemWarehouseInfoCollection',
                    '$filter'  => "startswith(ItemCode, 'P')",
                    '$top'     => self::SAP_PAGE,
                    '$skip'    => $skip,
                    '$orderby' => 'ItemCode',
                ]);
                return $response['value'] ?? [];
            } catch (\Throwable $e) {
                Log::warning("Stock sync page skip={$skip} attempt {$attempt}/" . self::MAX_RETRIES . ' failed: ' . $e->getMessage());
                if ($attempt < self::MAX_RETRIES) {
                    sleep(3 * $attempt); // 3s, 6s backoff
                }
            }
        }
        return false;
    }
}
