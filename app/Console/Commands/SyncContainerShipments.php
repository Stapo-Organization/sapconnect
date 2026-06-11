<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\ContainerShipment;
use App\Services\Traqo\TraqoClient;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Pulls the already-tracked Traqo shipment list into container_shipments, then
 * refreshes per-shipment detail (route / events / vessel / locations) for the
 * ones Traqo has resolved.
 *
 * READ-ONLY against Traqo: only GETs are issued, and detail is fetched ONLY for
 * numbers already present in /shipments — so no new shipment slot is ever
 * consumed. Runs daily via the `automations` table (see AutomationSchedule).
 */
class SyncContainerShipments extends Command
{
    protected $signature = 'traqo:sync-shipments {--no-detail : Skip the per-shipment detail fetch (list only)}';
    protected $description = 'Read-only sync of Traqo ocean-freight shipments into the local mirror';

    private const PAGE_SIZE = 100;

    public function handle(TraqoClient $traqo): int
    {
        if (!$traqo->configured()) {
            $this->error('Traqo credentials missing (services.traqo.token). Aborting.');
            return self::FAILURE;
        }

        // Never let two syncs overlap (also covers a manual "refresh now" racing the cron).
        $lock = Cache::lock('traqo:sync-shipments', 600);
        if (!$lock->get()) {
            $this->warn('Another Traqo sync is already running — skipping this tick.');
            return self::SUCCESS;
        }

        $automation = Automation::where('command_signature', $this->signature)->first()
            ?? Automation::where('command_signature', 'traqo:sync-shipments')->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        $seen = 0;
        $detailed = 0;
        $status = 'success';

        try {
            $now = now();

            // 1) Walk the paginated list (slot-free) and upsert the summary rows.
            $page = 1;
            $listed = [];
            while (true) {
                $body = $traqo->shipments($page, self::PAGE_SIZE);
                $rows = $body['data'] ?? [];
                if (empty($rows)) {
                    break;
                }

                foreach ($rows as $row) {
                    $name = $row['name'] ?? null;
                    if (!$name) {
                        continue;
                    }
                    $listed[$name] = $row;

                    ContainerShipment::updateOrCreate(
                        ['name' => $name],
                        [
                            'shipment_uid'         => $this->uidFromUrl($row['shipment_public_url'] ?? null),
                            'reference_number'     => $row['reference_number'] ?? '',
                            'shipment_type'        => $row['shipment_type'] ?? null,
                            'sealine'              => $row['sealine'] ?? null,
                            'sealine_name'         => $row['sealine_name'] ?? null,
                            'status'               => $row['status'] ?? null,
                            'origin'               => $row['origin'] ?? null,
                            'destination'          => $row['destination'] ?? null,
                            'eta'                  => $this->parseDate($row['eta'] ?? null),
                            'total_days'           => $this->intOrNull($row['total_days'] ?? null),
                            'remaining_days'       => $this->intOrNull($row['remaining_days'] ?? null),
                            'number_of_containers' => (int) ($row['number_of_containers'] ?? 0),
                            'is_active'            => (bool) ($row['is_active'] ?? true),
                            'is_delayed'           => (bool) ($row['is_delayed'] ?? false),
                            'shipment_public_url'  => $row['shipment_public_url'] ?? null,
                            'fetched_at'           => $now,
                        ]
                    );
                    $seen++;
                }

                if (count($rows) < self::PAGE_SIZE) {
                    break; // last page
                }
                $page++;
            }

            // 2) Refresh detail for resolved shipments.
            //
            // CRITICAL: a /container or /bl lookup of a DELIVERED shipment makes
            // Traqo register a brand-new tracking entry (new slot) every time —
            // and because the same reference can appear under several SHP names,
            // re-fetching also DOUBLES the duplicates each run (1→2→4→8…). So we
            // (a) skip delivered + pending, and (b) fetch each reference at most
            // once per run. Active containers re-read for free, so they're safe.
            if (!$this->option('no-detail')) {
                $fetchedRefs = [];
                foreach ($listed as $name => $row) {
                    $model = ContainerShipment::where('name', $name)->first();
                    if (!$model || $model->isPending() || $model->isDelivered()) {
                        continue;
                    }

                    $ref = $row['reference_number'] ?? null;
                    $sealine = $row['sealine'] ?? null;
                    if (!$ref || isset($fetchedRefs[$ref])) {
                        continue; // already fetched this reference this run
                    }
                    $fetchedRefs[$ref] = true;

                    $isBl = ($row['shipment_type'] ?? '') === 'Bill of Lading';
                    $body = $isBl ? $traqo->bl($ref, $sealine) : $traqo->container($ref, $sealine);
                    $data = $body['data'] ?? null;
                    if (!is_array($data)) {
                        continue;
                    }

                    $model->update([
                        'latitude'          => $this->floatOrNull($data['latitude'] ?? null),
                        'longitude'         => $this->floatOrNull($data['longitude'] ?? null),
                        'route_json'        => isset($data['route_json']) ? (is_string($data['route_json']) ? $data['route_json'] : json_encode($data['route_json'])) : null,
                        'remote_synced_at'  => $this->parseDate($data['last_synced_at'] ?? null),
                        'detail'            => [
                            'voyage_plan_table' => $data['voyage_plan_table'] ?? [],
                            'containers_table'  => $data['containers_table']  ?? [],
                            'locations_table'   => $data['locations_table']   ?? [],
                            'facilities_table'  => $data['facilities_table']  ?? [],
                            'eta_history_table' => $data['eta_history_table'] ?? [],
                            'events_table'      => $data['events_table']      ?? [],
                            'vessels_table'     => $data['vessels_table']     ?? [],
                        ],
                        'detail_fetched_at' => now(),
                    ]);
                    $detailed++;
                    usleep(150000); // 0.15s — be gentle on the upstream API
                }
            }

            // Mirror cleanup: drop local rows no longer present in Traqo (e.g. once
            // the operator deletes duplicate/old shipments in the Traqo dashboard).
            // Guarded by a non-empty pull so a failed list never wipes the mirror.
            $pruned = 0;
            if ($seen > 0 && !empty($listed)) {
                $pruned = ContainerShipment::whereNotIn('name', array_keys($listed))->delete();
            }

            $msg = "Traqo sync success. listed={$seen} detailed={$detailed} pruned={$pruned}";
            $this->info($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Throwable $e) {
            $status = 'failed';
            $msg = 'Traqo sync error: ' . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        } finally {
            $lock->release();
        }

        return $status === 'failed' ? self::FAILURE : self::SUCCESS;
    }

    private function parseDate(?string $value): ?Carbon
    {
        if (blank($value)) {
            return null;
        }
        try {
            return Carbon::parse($value);
        } catch (\Throwable) {
            return null;
        }
    }

    private function intOrNull($value): ?int
    {
        return is_numeric($value) ? (int) $value : null;
    }

    private function floatOrNull($value): ?float
    {
        return is_numeric($value) ? (float) $value : null;
    }

    /** Pull the shipment_uid out of the public share URL (?shipment_uid=...). */
    private function uidFromUrl(?string $url): ?string
    {
        if (!$url) {
            return null;
        }
        parse_str((string) parse_url($url, PHP_URL_QUERY), $q);
        return $q['shipment_uid'] ?? null;
    }
}
