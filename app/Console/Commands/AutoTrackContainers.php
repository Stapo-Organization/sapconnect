<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\ContainerShipment;
use App\Models\TraqoTrackRequest;
use App\Services\Google\GoogleSheetsClient;
use App\Services\Traqo\TraqoClient;
use Illuminate\Console\Command;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Automatically registers NEW, active, untracked shipments with Traqo — one
 * representative container per sheet row — within strict safety limits.
 *
 * This is the ONLY automation that WRITES to Traqo (consumes paid slots), so it
 * is wrapped in layered guards designed so the WHSU8376691 slot-churn mistake
 * (16 accidental duplicate registrations) can NEVER recur:
 *
 *   1. Permanent ledger (`traqo_track_requests`, UNIQUE container_number):
 *      a number ever submitted is NEVER submitted again — even if Traqo later
 *      loses/deletes/delivers it. Seeded from the live mirror.
 *   2. Atomic claim-before-call: the ledger row is inserted FIRST; a duplicate
 *      insert throws and is skipped, so the same number can't be sent twice in
 *      one run (e.g. the same box listed in two rows).
 *   3. Per-run cap: at most N registrations per run (a bug can burn N, not 16).
 *   4. Monthly budget: stops once the month's auto-registrations hit the cap,
 *      leaving headroom for manual/emergency adds.
 *   5. Active+new only: only rows whose "Received Dated" (col K) is EMPTY and
 *      that have ZERO already-covered containers — never historical/delivered.
 *   6. Valid ISO-6346 numbers only — malformed tokens are never submitted.
 *   7. Kill switch + lock.
 *
 * On failure it records the attempt (status=failed) and does NOT auto-retry —
 * the number stays claimed so it won't be hammered daily; surfaced for a manual
 * `traqo:track --sealine=...`.
 */
class AutoTrackContainers extends Command
{
    protected $signature = 'traqo:auto-track {--dry : List what WOULD be registered, write nothing}';
    protected $description = 'Auto-register new active untracked shipments with Traqo (one per row, capped & ledgered)';

    private const COL_CONTAINER = 'U';
    private const COL_RECEIVED  = 'K';

    public function handle(TraqoClient $traqo, GoogleSheetsClient $sheets): int
    {
        if (!config('services.traqo.auto_track_enabled', false)) {
            $this->warn('Auto-track is disabled (services.traqo.auto_track_enabled=false). Nothing to do.');
            return self::SUCCESS;
        }
        if (!$traqo->configured()) {
            $this->error('Traqo not configured (services.traqo.token).');
            return self::FAILURE;
        }
        $id = (string) config('services.google_sheets.spreadsheet_id');
        if (!$sheets->configured() || !$id) {
            $this->error('Google Sheets not configured — cannot read candidate rows.');
            return self::FAILURE;
        }

        $lock = Cache::lock('traqo:auto-track', 600);
        if (!$lock->get()) {
            $this->warn('Another auto-track run is in progress — skipping.');
            return self::SUCCESS;
        }

        $automation = Automation::where('command_signature', 'traqo:auto-track')->first();
        if ($automation && !$this->option('dry')) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        $monthlyBudget = (int) config('services.traqo.auto_track_monthly_budget', 40);
        $perRunCap     = (int) config('services.traqo.auto_track_per_run', 5);

        $registered = 0;
        $failed = 0;
        $status = 'success';

        try {
            $spent = TraqoTrackRequest::autoSpentThisMonth();
            $budgetLeft = max(0, $monthlyBudget - $spent);
            if ($budgetLeft <= 0) {
                $msg = "Auto-track: monthly budget reached ({$spent}/{$monthlyBudget}). Skipping until next month.";
                $this->warn($msg);
                $this->finish($automation, 'success', $msg);
                $lock->release();
                return self::SUCCESS;
            }
            $cap = min($perRunCap, $budgetLeft);

            // Authority on what's already covered: the permanent ledger (which
            // includes the seeded live mirror) PLUS the current mirror, belt+braces.
            $handled = TraqoTrackRequest::pluck('container_number')
                ->map(fn ($c) => strtoupper(trim((string) $c)))->flip();
            foreach (ContainerShipment::pluck('reference_number') as $ref) {
                $handled[strtoupper(trim((string) $ref))] = true;
            }

            // Resolve the sheet tab + pull the container & received columns.
            $props = $sheets->firstSheetProps($id);
            $tab = config('services.google_sheets.tab') ?: ($props['title'] ?? null);
            if (!$tab) {
                throw new \RuntimeException('Could not resolve sheet tab (no access?).');
            }
            $q = "'" . str_replace("'", "''", $tab) . "'";
            $rows = $sheets->getValues($id, $q . '!' . self::COL_CONTAINER . '1:' . self::COL_CONTAINER . '2000');
            $received = $sheets->getValues($id, $q . '!' . self::COL_RECEIVED . '1:' . self::COL_RECEIVED . '2000');

            // Build the candidate list: new+active rows, one representative each,
            // de-duplicated across rows.
            $candidates = [];
            $pickedNumbers = [];
            foreach ($rows as $idx => $row) {
                if ($idx === 0) {
                    continue; // header
                }
                $cell = $row[0] ?? '';
                if ($cell === '') {
                    continue;
                }
                $isReceived = trim($received[$idx][0] ?? '') !== '';
                if ($isReceived) {
                    continue; // not active
                }
                $containers = $this->parseContainers($cell);
                if (empty($containers)) {
                    continue;
                }
                // Row already covered if ANY of its boxes is handled/tracked.
                $covered = false;
                foreach ($containers as $cn) {
                    if (isset($handled[$cn])) {
                        $covered = true;
                        break;
                    }
                }
                if ($covered) {
                    continue;
                }
                $rep = $containers[0]; // one box per shipment is enough
                if (isset($pickedNumbers[$rep])) {
                    continue; // same number already queued from another row
                }
                $pickedNumbers[$rep] = true;
                $candidates[] = ['number' => $rep, 'row' => $idx + 1, 'siblings' => count($containers)];
            }

            $this->info(sprintf(
                'Auto-track: %d candidate row(s); budget left this month=%d/%d; per-run cap=%d → will register up to %d.',
                count($candidates), $budgetLeft, $monthlyBudget, $perRunCap, $cap
            ));

            if ($this->option('dry')) {
                foreach ($candidates as $c) {
                    $this->line("  would register {$c['number']} (row {$c['row']}, 1 of {$c['siblings']})");
                }
                $this->info('DRY RUN — nothing registered.');
                if ($automation) $automation->update(['last_run_status' => 'success']);
                $lock->release();
                return self::SUCCESS;
            }

            foreach ($candidates as $c) {
                if ($registered >= $cap) {
                    $this->warn("Cap reached ({$cap}). " . (count($candidates) - $registered - $failed) . ' candidate(s) deferred to the next run.');
                    break;
                }
                $number = $c['number'];

                // (2) Atomic claim: insert the ledger row BEFORE calling Traqo.
                // A duplicate (unique) insert means it was already handled → skip.
                try {
                    $ledger = TraqoTrackRequest::create([
                        'container_number' => $number,
                        'source'           => 'auto',
                        'status'           => 'pending',
                        'attempts'         => 1,
                        'sheet_row'        => $c['row'],
                        'note'             => 'auto-track claim',
                    ]);
                } catch (QueryException $e) {
                    $this->line("  {$number}: already in ledger — skipped (no resubmit).");
                    continue;
                }

                $body = $traqo->container($number, null);
                $ok = !empty($body) && ($body['success'] ?? false);
                if ($ok) {
                    $data = $body['data'] ?? [];
                    $ledger->update([
                        'status'          => 'tracked',
                        'response_status' => $data['status'] ?? null,
                        'sealine'         => $data['sealine'] ?? null,
                        'registered_at'   => now(),
                        'note'            => 'auto-registered',
                    ]);
                    $registered++;
                    $this->info("  ✓ {$number} (row {$c['row']}) → " . (($data['status'] ?? '') ?: 'pending'));
                } else {
                    $ledger->update([
                        'status' => 'failed',
                        'note'   => 'Traqo rejected (carrier not detected / invalid / quota). Try manual traqo:track --sealine=.',
                    ]);
                    $failed++;
                    $this->warn("  ✗ {$number} (row {$c['row']}) rejected — flagged for manual review, will NOT auto-retry.");
                }
                usleep(200000); // gentle on the API
            }

            // Reflect newly-registered shipments on the board + sheet.
            if ($registered > 0) {
                $this->line('Syncing local mirror …');
                Artisan::call('traqo:sync-shipments');
                $this->line(trim(Artisan::output()));
            }

            $msg = "Auto-track done. registered={$registered} failed={$failed} monthSpent=" . TraqoTrackRequest::autoSpentThisMonth() . "/{$monthlyBudget}";
            $this->info($msg);
            $this->finish($automation, 'success', $msg);
        } catch (\Throwable $e) {
            $status = 'failed';
            $msg = 'Auto-track error: ' . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            $this->finish($automation, 'failed', $msg);
        } finally {
            $lock->release();
        }

        return $status === 'failed' ? self::FAILURE : self::SUCCESS;
    }

    private function finish(?Automation $automation, string $status, string $msg): void
    {
        if ($automation && !$this->option('dry')) {
            $automation->update(['last_run_status' => $status]);
            AutomationLog::create(['automation_id' => $automation->id, 'status' => $status, 'message' => $msg]);
        }
    }

    /** Valid ISO-6346 container numbers (4 letters + 7 digits), spaces ignored. */
    private function parseContainers(string $cell): array
    {
        preg_match_all('/[A-Z]{4}\d{7}/', strtoupper(str_replace([' ', "\n", "\r"], ['', ',', ','], $cell)), $m);
        return array_values(array_unique($m[0] ?? []));
    }
}
