<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\Warehouse;
use App\Models\ZooboxiWarehouse;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Sync the warehouse master from SAP.
 *
 * This used to be a stub that slept for a second and reported success, so the
 * `warehouses` table stayed frozen at whatever the initial 2025-12-21 import
 * left behind. Branches opened since then never appeared, and the retail
 * dashboard papered over it with a hardcoded name map.
 *
 * Paging matters: the Service Layer returns 20 rows per page, and Muntajat has
 * more warehouses than that. Reading one page and stopping is what made the
 * list look complete when it was not.
 *
 * Syncing the master is only half the job. `zooboxi_warehouses` — the config
 * that decides which branches serve store customers — is hand-kept, so the
 * five branches SAP delivered on 2026-07-28 reached the master and then sat
 * invisible to the store: only RUH010 was ever added, by hand, for the Mrsool
 * pilot. A new branch now drafts itself here (inactive, awaiting a GPS pin) so
 * it surfaces on /admin/zooboxi-warehouses instead of going quietly missing.
 */
class SyncWarehouses extends Command
{
    protected $signature = 'sap:sync-warehouses {--code=} {--full} {--dry-run}';

    protected $description = 'Sync Warehouses from SAP';

    private const PAGE = 20;

    /** Refuse to prune below this many rows — a bad page would empty the table. */
    private const MIN_EXPECTED = 5;

    /**
     * SAP names every retail branch "<Name> Store - <CITY>". Everything else in
     * the master is a 3PL, marketplace inventory pool, head office or the
     * damaged-goods bin — none of which may ever serve a store customer, so the
     * word is what separates a branch from a warehouse.
     */
    private const STORE_PATTERN = '/\bstore\b/i';

    public function handle()
    {
        $automation = Automation::where('code', $this->option('code') ?: 'sync_warehouses')->first();
        $sapDatabase = 'PPTC_V5_PROD';
        $dry = (bool) $this->option('dry-run');

        $this->info("Starting Warehouses Sync for {$sapDatabase}...");

        if ($automation && ! $dry) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        try {
            $sap = app(\App\Services\SAP\SapClient::class);
            $sap->setCompanyDb($sapDatabase);

            $rows = [];
            $skip = 0;
            $page = 1;
            do {
                $this->info("  Fetching Warehouses page {$page}... (Skip: {$skip})");
                $response = $sap->get('Warehouses', [
                    '$select'  => 'WarehouseCode,WarehouseName,BusinessPlaceID,Inactive',
                    '$orderby' => 'WarehouseCode',
                    '$top'     => self::PAGE,
                    '$skip'    => $skip,
                ]);
                $batch = $response['value'] ?? [];
                $this->info('    - Retrieved '.count($batch).' warehouses.');
                $rows = array_merge($rows, $batch);
                $skip += self::PAGE;
                $page++;
            } while (count($batch) === self::PAGE);

            if (count($rows) < self::MIN_EXPECTED) {
                throw new \RuntimeException(
                    'SAP returned only '.count($rows).' warehouses; refusing to overwrite the master.'
                );
            }

            $seen = [];
            $created = 0;
            $updated = 0;
            foreach ($rows as $w) {
                $code = $w['WarehouseCode'] ?? null;
                if (! $code) {
                    continue;
                }
                $seen[] = $code;

                if ($dry) {
                    continue;
                }

                $existing = Warehouse::where('warehouse_code', $code)->first();
                $attrs = [
                    'warehouse_name' => $w['WarehouseName'] ?? $code,
                    'source'         => 'production',
                ];

                if ($existing) {
                    if ($existing->warehouse_name !== $attrs['warehouse_name']) {
                        $existing->update($attrs);
                        $updated++;
                        $this->line("    ~ {$code}: renamed to {$attrs['warehouse_name']}");
                    }
                } else {
                    Warehouse::create($attrs + ['warehouse_code' => $code]);
                    $created++;
                    $this->line("    + {$code}: {$attrs['warehouse_name']}");
                }
            }

            // Warehouses that vanished from SAP are reported, never deleted:
            // stock rows, invoices and transfers still reference them.
            $stale = Warehouse::whereNotIn('warehouse_code', $seen)
                ->pluck('warehouse_code')->all();

            $drafted = $this->draftZooboxiBranches($rows, $dry);

            $msg = sprintf(
                'Warehouses Sync Completed. %d in SAP, %d created, %d renamed%s%s.',
                count($rows), $created, $updated,
                $drafted ? ', '.count($drafted).' drafted for Zooboxi: '.implode(', ', $drafted) : '',
                $stale ? ', '.count($stale).' no longer in SAP: '.implode(', ', $stale) : ''
            );
            $this->info($dry ? "[dry-run] {$msg}" : $msg);

            if ($automation && ! $dry) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status'        => 'success',
                    'message'       => $msg,
                ]);
            }

            return self::SUCCESS;
        } catch (\Throwable $e) {
            $this->error($e->getMessage());
            Log::error('sap:sync-warehouses failed', ['error' => $e->getMessage()]);

            if ($automation && ! $dry) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status'        => 'failed',
                    'message'       => $e->getMessage(),
                ]);
            }

            return self::FAILURE;
        }
    }

    /**
     * Draft a `zooboxi_warehouses` row for every SAP branch that has none.
     *
     * Drafts are created INACTIVE on purpose. Activating a row opens the branch
     * to store customers — it enters the delivery promise and reachability
     * maths — so that stays a human decision. What the sync removes is the
     * silent part: the branch now appears in the admin list asking to be set
     * up, instead of existing only in SAP.
     *
     * Presentation data comes from config/b2b_showrooms.php, the curated file
     * the B2B storefront already reads, so a branch surveyed once is described
     * once. Coordinates it does not have stay null rather than guessed.
     *
     * @param  array<int, array<string, mixed>>  $rows  SAP warehouse rows
     * @return string[] codes drafted this run
     */
    private function draftZooboxiBranches(array $rows, bool $dry): array
    {
        if (! Schema::hasTable('zooboxi_warehouses')) {
            return [];
        }

        $showrooms = config('b2b_showrooms', []);

        // A Zooboxi row may serve a SAP code under a different warehouse_code
        // via the sap_warehouse_codes bridge (WooStockService documents the
        // WH-RYD-01 -> ['01','02'] shape). Matching on warehouse_code alone
        // would draft a second row for a branch that is already served, and the
        // unique index would not catch it because the codes differ.
        $known = ZooboxiWarehouse::query()
            ->get(['warehouse_code', 'sap_warehouse_codes'])
            ->flatMap(fn ($r) => array_merge([$r->warehouse_code], (array) ($r->sap_warehouse_codes ?? [])))
            ->filter()
            ->unique()
            ->all();

        $drafted = [];

        foreach ($rows as $w) {
            $code = $w['WarehouseCode'] ?? null;
            $name = $w['WarehouseName'] ?? '';

            if (! $code || in_array($code, $known, true)) {
                continue;
            }
            if (! preg_match(self::STORE_PATTERN, $name)) {
                continue; // a 3PL / marketplace / admin location, never a shopfront
            }
            if (($w['Inactive'] ?? 'tNO') === 'tYES') {
                continue; // a closed branch should not be offered for setup
            }

            $cfg = $showrooms[$code] ?? [];
            $drafted[] = $code;

            if ($dry) {
                continue;
            }

            ZooboxiWarehouse::create([
                'warehouse_code'      => $code,
                'sap_warehouse_codes' => [$code],
                'display_name_ar'     => $cfg['name_ar'] ?? $name,
                'display_name_en'     => $name,
                'city'                => $cfg['city_ar'] ?? $this->siblingCity($code),
                'address_ar'          => $cfg['addr_ar'] ?? null,
                'address_en'          => $cfg['addr'] ?? null,
                'latitude'            => $cfg['lat'] ?? null,
                'longitude'           => $cfg['lng'] ?? null,
                // Left off until a human reviews the branch: each of these
                // changes what customers are promised.
                'is_active'           => false,
                'is_central'          => false,
                'is_main_hub'         => false,
                'is_pickup_enabled'   => false,
            ]);

            $this->line("    * {$code}: drafted for Zooboxi (inactive"
                .(isset($cfg['lat']) ? '' : ', needs GPS').')');
        }

        return $drafted;
    }

    /**
     * City for a branch the showroom config does not describe.
     *
     * Same-day grouping compares `city` for exact equality
     * (WooDeliveryService::findCentralWarehouse), so a new Riyadh branch must
     * spell the city exactly like RUH002-008 already do. Copying a sibling that
     * shares the three-letter prefix keeps the spelling consistent instead of
     * inventing a second variant. Empty when there is no sibling to learn from.
     */
    private function siblingCity(string $code): string
    {
        return (string) ZooboxiWarehouse::query()
            ->where('warehouse_code', 'like', substr($code, 0, 3).'%')
            ->whereNotNull('city')
            ->where('city', '<>', '')
            ->value('city');
    }
}
