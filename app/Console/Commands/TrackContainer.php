<?php

namespace App\Console\Commands;

use App\Models\TraqoTrackRequest;
use App\Services\Traqo\TraqoClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;

/**
 * Registers ONE container (or BL) with Traqo for tracking.
 *
 * Unlike the rest of the integration (read-only), this DOES start tracking on
 * Traqo and CONSUMES one shipment slot from the monthly quota — so it is an
 * explicit, single, operator-driven action (one box per shipment is enough; the
 * sheet's "Track in Traqo?" column suggests which). After registering, it pulls
 * the shipment list so the new box shows up on the board + the sheet.
 *
 *   php artisan traqo:track CICU6974478 [--sealine=CMDU] [--bl]
 */
class TrackContainer extends Command
{
    protected $signature = 'traqo:track {number : Container or BL number} {--sealine= : SCAC carrier code (optional)} {--bl : Treat the number as a Bill of Lading} {--force : Re-submit even if already in the ledger}';
    protected $description = 'Register a container/BL with Traqo for tracking (consumes one shipment slot)';

    public function handle(TraqoClient $traqo): int
    {
        if (!$traqo->configured()) {
            $this->error('Traqo not configured (services.traqo.token).');
            return self::FAILURE;
        }

        $number = strtoupper(trim($this->argument('number')));
        $sealine = $this->option('sealine') ?: null;

        // Anti-duplicate guard (same ledger the auto-track uses): if this number
        // was ever submitted, refuse unless explicitly forced — this is what
        // prevents an accidental re-run from burning another slot.
        if (!$this->option('force') && TraqoTrackRequest::alreadyHandled($number)) {
            $existing = TraqoTrackRequest::where('container_number', $number)->first();
            $this->error("{$number} is already in the tracking ledger (status={$existing->status}, since {$existing->created_at}). Refusing to re-submit. Use --force to override.");
            return self::FAILURE;
        }

        $this->info("Registering {$number} with Traqo" . ($sealine ? " (sealine {$sealine})" : '') . ' …');

        $body = $this->option('bl')
            ? $traqo->bl($number, $sealine)
            : $traqo->container($number, $sealine);

        if (empty($body) || !($body['success'] ?? false)) {
            $prior = TraqoTrackRequest::where('container_number', $number)->first();
            TraqoTrackRequest::updateOrCreate(
                ['container_number' => $number],
                ['source' => 'manual', 'status' => 'failed', 'sealine' => $sealine,
                 'shipment_type' => $this->option('bl') ? 'Bill of Lading' : 'Container',
                 'attempts' => ($prior->attempts ?? 0) + 1,
                 'note' => 'manual register rejected by Traqo'],
            );
            $this->error("Traqo did not accept {$number}. Possible causes: quota reached (402), invalid number, or carrier not detected — try --sealine=XXXX. See logs.");
            return self::FAILURE;
        }

        $data = $body['data'] ?? [];

        // Record in the permanent ledger so neither this command nor the
        // auto-track ever re-submits this number.
        TraqoTrackRequest::updateOrCreate(
            ['container_number' => $number],
            ['source' => 'manual', 'status' => 'tracked', 'sealine' => $data['sealine'] ?? $sealine,
             'shipment_type' => $this->option('bl') ? 'Bill of Lading' : 'Container',
             'response_status' => $data['status'] ?? null, 'registered_at' => now(),
             'attempts' => 1, 'note' => 'manual register'],
        );

        $this->info(sprintf(
            'OK — %s registered. status=%s · sealine=%s · ETA=%s',
            $number,
            ($data['status'] ?? '') ?: 'pending (Traqo resolving route)',
            $data['sealine_name'] ?? '-',
            $data['eta'] ?? '-'
        ));

        // Pull it into our mirror so it appears on the board and flows to the sheet.
        $this->line('Syncing local mirror …');
        Artisan::call('traqo:sync-shipments');
        $this->line(trim(Artisan::output()));

        return self::SUCCESS;
    }
}
