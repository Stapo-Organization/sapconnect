<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Services\SFDA\SfdaClient;
use Illuminate\Console\Command;

/**
 * READ-ONLY cross-check of our SAP catalog against the official SFDA food
 * registry (apis.sfda.gov.sa), joined by BARCODE — a far better key than the
 * ops team's legacy vendor codes, which match zero SAP products.
 *
 * A probe/report: it NEVER writes to SFDA and (in this phase) never writes to
 * our DB. Run a small sample first with --raw to see the real payload, then we
 * widen coverage and decide what to persist.
 *
 *   php artisan sfda:verify-registrations --barcode=6281123037010   (single probe)
 *   php artisan sfda:verify-registrations --limit=30 --raw           (sample sweep)
 */
class VerifyProductRegistrations extends Command
{
    protected $signature = 'sfda:verify-registrations
                            {--limit=30 : Sample size — products (with a numeric barcode) to check}
                            {--barcode= : Probe a single barcode and dump the raw response}
                            {--raw : Print the raw body of the first registered hit}';

    protected $description = 'Cross-check SAP products against the official SFDA food registry by barcode (read-only)';

    public function handle(SfdaClient $sfda): int
    {
        if (!$sfda->isConfigured()) {
            $this->error('SFDA API is not configured. Set SFDA_CONSUMER_KEY / SFDA_CONSUMER_SECRET in .env.');
            return self::FAILURE;
        }

        $this->line('Token : ' . config('services.sfda.token_url'));
        $this->line('Base  : ' . config('services.sfda.base_url'));

        try {
            $sfda->token();
            $this->info('✓ OAuth token acquired.');
        } catch (\Throwable $e) {
            $this->error('Auth failed: ' . $e->getMessage());
            return self::FAILURE;
        }

        // ---- Single-barcode probe -------------------------------------------
        if ($barcode = trim((string) $this->option('barcode'))) {
            $r = $sfda->lookupFoodByBarcode($barcode);
            $this->line('');
            $this->line(rtrim($r['raw']) ?: '(empty body)');
            $this->line('');
            if ($r['error']) {
                $this->warn('Result: ' . $r['error']);
            } else {
                $this->info($r['registered']
                    ? "Result: REGISTERED · ref {$r['reference']} · status {$r['status_en']} ({$r['status_ar']}) · brand {$r['brand']}"
                    : "Result: NOT registered (code {$r['code']}).");
            }
            return self::SUCCESS;
        }

        // ---- Sample sweep ----------------------------------------------------
        $limit = max(1, (int) $this->option('limit'));
        $products = Product::query()
            ->where('source', 'production')
            ->whereNotNull('piece_barcode')
            ->where('piece_barcode', '!=', '')
            ->orderBy('item_code')
            ->get(['item_code', 'item_name', 'piece_barcode']);

        // SFDA accepts digit-only barcodes; skip anything else up front.
        $numeric = $products->filter(fn ($p) => ctype_digit(trim((string) $p->piece_barcode)))->take($limit)->values();
        $skipped = $products->count() - $products->filter(fn ($p) => ctype_digit(trim((string) $p->piece_barcode)))->count();

        if ($numeric->isEmpty()) {
            $this->warn('No production products with a numeric barcode found (checked ' . $products->count() . ' rows).');
            return self::SUCCESS;
        }

        $this->info("Checking {$numeric->count()} products against the SFDA food registry …");
        $delayUs = max(0, (int) config('services.sfda.sweep_delay_ms', 300)) * 1000;

        $rows = [];
        $registered = $notFound = $errors = 0;
        $dumped = false;

        foreach ($numeric as $i => $p) {
            $bc = trim((string) $p->piece_barcode);
            $r = $sfda->lookupFoodByBarcode($bc);

            if ($r['error']) {
                $errors++;
                $sfdaCell = 'ERR: ' . mb_substr($r['error'], 0, 22);
            } elseif ($r['registered']) {
                $registered++;
                $sfdaCell = '✓ ' . ($r['status_en'] ?: 'Registered');
                if (!$dumped && $this->option('raw')) {
                    $this->line('');
                    $this->comment("──── raw for {$bc} ({$p->item_code}) ────");
                    $this->line(rtrim($r['raw']));
                    $this->comment('──── end raw ────');
                    $this->line('');
                    $dumped = true;
                }
            } else {
                $notFound++;
                $sfdaCell = '— not found';
            }

            $rows[] = [$bc, $p->item_code, mb_substr((string) $p->item_name, 0, 28), $sfdaCell, $r['reference'] ?: ''];

            if ($delayUs && $i < $numeric->count() - 1) {
                usleep($delayUs);
            }
        }

        $this->table(['Barcode', 'SAP Code', 'Name', 'SFDA', 'Ref #'], $rows);
        $this->line('');
        $this->info("Checked {$numeric->count()}: registered {$registered} · not-found {$notFound} · errors {$errors}");
        if ($skipped > 0) {
            $this->comment("Skipped {$skipped} product(s) with a non-numeric barcode (SFDA accepts digits only).");
        }
        $this->comment('Read-only probe: nothing was written to SFDA or the local DB.');

        return self::SUCCESS;
    }
}
