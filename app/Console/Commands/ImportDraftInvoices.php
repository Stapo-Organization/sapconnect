<?php

namespace App\Console\Commands;

use App\Models\DraftInvoiceRun;
use App\Services\SAP\DraftInvoiceImportService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Build SAP **draft** invoices from a flat sales-report file.
 *
 * Dry-run (default) writes a preview + exceptions report and never touches SAP.
 * Add --post to actually create the drafts (idempotent: already-posted chunks
 * are skipped on re-run). This is the workhorse for very large warehouses
 * (e.g. tens of thousands of lines) where the web request would time out.
 *
 *   php artisan sap:draft-invoices --file=/path/Sales.xlsx --db=PPTC_V5_PROD \
 *       --card-code=CAPP0004 --chunk=200 --expense-code=1 [--warehouse=UZH002] [--post]
 */
class ImportDraftInvoices extends Command
{
    protected $signature = 'sap:draft-invoices
        {--file= : Absolute path to the .xlsx/.csv sales report}
        {--run-id= : Execute an existing DraftInvoiceRun (from the Filament launcher)}
        {--db=PPTC_V5_PROD : SAP company database}
        {--card-code= : Customer / BP code (else taken from the file BP column)}
        {--doc-date= : Document date Y-m-d (default: today)}
        {--chunk=200 : Max document lines per draft}
        {--expense-code= : SAP freight expense code for the header (omit to skip freight)}
        {--tax-code= : Optional tax code for lines (omit => SAP default)}
        {--no-batches : Skip batch allocation entirely (no BatchNumbers on lines)}
        {--warehouse= : Only process this warehouse}
        {--post : Actually create the drafts in SAP (default is dry-run preview)}';

    protected $description = 'Build SAP draft invoices (Drafts/oInvoices) from a sales-report file, with FEFO batch allocation.';

    public function handle(DraftInvoiceImportService $service): int
    {
        // A full report holds tens of thousands of rows + per-item batch caches
        // in memory; the host's default CLI memory_limit (128M) is too small.
        @ini_set('memory_limit', '1024M');
        // Prevent the query log from retaining every large draft/ApiLog insert.
        \Illuminate\Support\Facades\DB::connection()->disableQueryLog();

        $post = (bool) $this->option('post');

        // Resolve / create the run.
        if ($runId = $this->option('run-id')) {
            $run = DraftInvoiceRun::find($runId);
            if (!$run) {
                $this->error("Run #$runId not found.");
                return self::FAILURE;
            }
            $filePath = $this->resolveFilePath($this->option('file') ?: $run->source_file);
        } else {
            $filePath = $this->resolveFilePath($this->option('file'));
            if (!$filePath) {
                $this->error('Provide --file=/abs/path.xlsx');
                return self::FAILURE;
            }
            $run = DraftInvoiceRun::create([
                'source_file' => basename($filePath),
                'file_hash' => '',
                'company_db' => $this->option('db'),
                'mode' => $post ? 'post' : 'dry_run',
                'card_code' => $this->option('card-code') ?: null,
                'doc_date' => $this->option('doc-date') ?: now()->format('Y-m-d'),
                'chunk_size' => (int) $this->option('chunk'),
                'expense_code' => $this->option('expense-code') ?: null,
                'tax_code' => $this->option('tax-code') ?: null,
                'no_batches' => (bool) $this->option('no-batches'),
                'warehouse_filter' => $this->option('warehouse') ?: null,
                'status' => 'pending',
            ]);
        }

        if (!$filePath || !is_file($filePath)) {
            $msg = "File not found: " . ($filePath ?: '(none)');
            $run->forceFill(['status' => 'failed', 'error' => $msg, 'finished_at' => now()])->save();
            $this->error($msg);
            return self::FAILURE;
        }

        // The run row carries the mode; keep it consistent with --post.
        $run->forceFill([
            'mode' => $post ? 'post' : 'dry_run',
            'status' => 'running',
            'started_at' => now(),
            'error' => null,
        ])->save();

        $this->line(sprintf(
            '<info>%s</info> run #%d | db=%s | chunk=%d | warehouse=%s | file=%s',
            $post ? 'POST' : 'DRY-RUN', $run->id, $run->company_db, $run->chunk_size,
            $run->warehouse_filter ?: 'ALL', basename($filePath)
        ));

        try {
            $totals = $service->run($run, $filePath, $post, fn (string $m) => $this->line('  ' . $m));
        } catch (\Throwable $e) {
            $run->forceFill(['status' => 'failed', 'error' => $e->getMessage(), 'finished_at' => now()])->save();
            $this->error('FAILED: ' . $e->getMessage());
            return self::FAILURE;
        }

        $this->newLine();
        $this->table(['Metric', 'Value'], [
            ['Mode', $post ? 'POST' : 'DRY-RUN'],
            ['Source rows', $totals['rows']],
            ['Drafts', $totals['drafts']],
            ['Posted', $totals['posted']],
            ['Skipped (already posted)', $totals['skipped']],
            ['Failed', $totals['failed']],
            ['Total lines', $totals['lines']],
            ['Freight total', $totals['freight_total']],
            ['Exceptions', $totals['exceptions']],
        ]);
        $this->info("Run #{$run->id} {$run->status}. Exceptions: " . ($run->exceptions_path ?: '-'));
        if (!$post && $run->preview_path) {
            $this->info("Preview: storage/app/private/{$run->preview_path}");
        }

        return self::SUCCESS;
    }

    /** Accept absolute paths or storage-relative paths. */
    protected function resolveFilePath(?string $path): ?string
    {
        if (!$path) {
            return null;
        }
        if (is_file($path)) {
            return $path;
        }
        if (Storage::disk('local')->exists($path)) {
            return Storage::disk('local')->path($path);
        }
        return $path; // let caller report not-found
    }
}
