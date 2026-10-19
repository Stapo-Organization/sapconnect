<?php

namespace App\Filament\Resources;

use App\Filament\Resources\DraftInvoiceImportResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\DraftInvoiceChunk;
use App\Models\DraftInvoiceRun;
use App\Services\SAP\DraftInvoiceImportService;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

/**
 * "تقرير مبيعات → مسودات فواتير SAP".
 *
 * Upload a flat sales report (one row = one sold line). Every upload is first
 * ANALYSED (nothing is written to SAP): customers split, returns netted off
 * the sales, customers/items checked in SAP, duplicates listed, an Excel
 * report built. A clean analysis then gets an «ارفع إلى SAP» button that
 * creates the **draft** invoices (Drafts / oInvoices) with the same file and
 * settings. Drafts never post to the ledger until a human opens them in SAP
 * and clicks Add. The heavy work runs in a background CLI worker.
 */
class DraftInvoiceImportResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = DraftInvoiceRun::class;

    protected static ?string $navigationIcon = 'heroicon-o-document-currency-dollar';

    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    public static function getNavigationGroup(): ?string
    {
        return __('SAP Management');
    }

    public static function getNavigationLabel(): string
    {
        return 'مسودات فواتير (تقرير مبيعات)';
    }

    public static function getModelLabel(): string
    {
        return 'عملية استيراد';
    }

    public static function getPluralModelLabel(): string
    {
        return 'مسودات فواتير (تقرير مبيعات)';
    }

    public static function form(Form $form): Form
    {
        // Runs are created via the page header "Launch" action, not an edit form.
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->poll('10s')
            ->defaultSort('id', 'desc')
            ->recordAction('review')
            ->columns([
                Tables\Columns\TextColumn::make('id')->label('#')->sortable(),
                Tables\Columns\TextColumn::make('source_file')->label('الملف')->limit(34)->tooltip(fn ($record) => $record->source_file)->searchable()->weight('medium'),
                Tables\Columns\TextColumn::make('mode')->label('العملية')->badge()
                    ->formatStateUsing(fn ($state) => $state === 'post' ? 'رفع إلى SAP' : 'تحليل')
                    ->icon(fn ($state) => $state === 'post' ? 'heroicon-m-cloud-arrow-up' : 'heroicon-m-magnifying-glass')
                    ->color(fn ($state) => $state === 'post' ? 'warning' : 'gray'),
                Tables\Columns\TextColumn::make('status')->label('الحالة')->badge()
                    ->formatStateUsing(fn ($state, $record) => match ($state) {
                        'pending' => 'بالانتظار', 'running' => 'يعمل…', 'failed' => 'فشل',
                        'done' => static::blockingErrors($record) ? 'فيه أخطاء' : 'تم',
                        default => $state,
                    })
                    ->color(fn ($state, $record) => match ($state) {
                        'running', 'pending' => 'info', 'failed' => 'danger',
                        'done' => static::blockingErrors($record) ? 'danger' : 'success',
                        default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('customers')->label('العملاء')
                    ->getStateUsing(fn ($record) => count($record->totals['warehouses'] ?? []) ?: '—')->alignCenter(),
                Tables\Columns\TextColumn::make('drafts')->label('المسودات')
                    ->getStateUsing(function ($record) {
                        $t = $record->totals;
                        if (!$t) {
                            return '—';
                        }
                        return $record->mode === 'post'
                            ? sprintf('%d / %d', ($t['posted'] ?? 0) + ($t['skipped'] ?? 0), $t['drafts'] ?? 0)
                            : (string) ($t['drafts'] ?? 0);
                    })
                    ->description(fn ($record) => ($record->mode === 'post' && ($record->totals['failed'] ?? 0)) ? 'فشل ' . $record->totals['failed'] : null)
                    ->alignCenter(),
                Tables\Columns\TextColumn::make('net_total')->label('الصافي ﷼')
                    ->getStateUsing(fn ($record) => isset($record->totals['net_total']) ? number_format((float) $record->totals['net_total'], 2) : '—')
                    ->description(fn ($record) => ($record->totals['returns']['lines'] ?? 0) ? 'بعد خصم ' . $record->totals['returns']['lines'] . ' مرتجع' : null),
                Tables\Columns\TextColumn::make('notes')->label('ملاحظات')
                    ->getStateUsing(function ($record) {
                        $t = $record->totals;
                        if (!$t) {
                            return null;
                        }
                        $e = static::blockingErrors($record);
                        $w = $t['warnings'] ?? max(0, ($t['exceptions'] ?? 0) - $e);
                        return array_values(array_filter([
                            $e ? "أخطاء $e" : null,
                            $w ? "تنبيهات $w" : null,
                            ($t['duplicates']['extra_lines'] ?? 0) ? 'مكرر ' . $t['duplicates']['extra_lines'] : null,
                        ]));
                    })
                    ->badge()
                    ->color(fn ($state) => str_starts_with((string) $state, 'أخطاء') ? 'danger' : 'warning'),
                Tables\Columns\TextColumn::make('created_at')->label('التاريخ')->dateTime('Y-m-d H:i')->sortable()->color('gray'),
            ])
            ->actions([
                Tables\Actions\Action::make('review')
                    ->label('مراجعة')
                    ->icon('heroicon-o-eye')
                    ->slideOver()
                    ->modalWidth('6xl')
                    ->modalHeading(fn ($record) => ($record->mode === 'post' ? 'رفع' : 'تحليل') . " #{$record->id} — {$record->source_file}")
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('إغلاق')
                    ->modalContent(fn ($record) => view('filament.resources.draft-invoice-import.review', [
                        'run' => $record,
                        'notes' => static::notes($record),
                        'logTail' => static::logTail($record),
                    ])),

                Tables\Actions\Action::make('post')
                    ->label('ارفع إلى SAP')
                    ->icon('heroicon-o-cloud-arrow-up')
                    ->color('success')
                    ->button()
                    ->visible(fn ($record) => static::canPost($record))
                    ->requiresConfirmation()
                    ->modalIcon('heroicon-o-cloud-arrow-up')
                    ->modalHeading('رفع المسودات إلى SAP')
                    ->modalDescription(function ($record) {
                        $t = $record->totals;
                        $customers = count($t['warehouses'] ?? []);
                        return sprintf(
                            'سيتم إنشاء %d مسودة فاتورة لـ %d %s بصافي %s ﷼ في %s بتاريخ %s. المسودة لا تُرحّل محاسبياً ولا مخزنياً حتى تفتحها في SAP وتضغط Add. الرفع آمن من التكرار: أي مسودة رُفعت من قبل لنفس الملف تُتخطّى.',
                            $t['drafts'] ?? 0, $customers, $customers === 1 ? 'عميل' : 'عملاء',
                            number_format((float) ($t['net_total'] ?? 0), 2), $record->company_db, optional($record->doc_date)->format('Y-m-d')
                        );
                    })
                    ->modalSubmitActionLabel('نعم، ارفع')
                    ->action(function ($record) {
                        $run = static::startPostFrom($record);
                        Notification::make()
                            ->title('بدأ الرفع #' . $run->id)
                            ->body('يتم إنشاء المسودات في SAP بالخلفية. تابع التقدّم من «مراجعة».')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('report')
                    ->label('تقرير Excel')
                    ->icon('heroicon-o-table-cells')
                    ->color('gray')
                    ->visible(fn ($record) => filled($record->totals['report_path'] ?? null))
                    ->action(fn ($record) => static::downloadArtifact($record->totals['report_path'], sprintf('تقرير_%s_%d.xlsx', $record->mode === 'post' ? 'رفع' : 'تحليل', $record->id))),

                Tables\Actions\ActionGroup::make([
                    Tables\Actions\Action::make('download_preview')
                        ->label('معاينة المسودات (JSON)')->icon('heroicon-o-code-bracket')
                        ->visible(fn ($record) => filled($record->preview_path))
                        ->action(fn ($record) => static::downloadArtifact($record->preview_path)),
                    Tables\Actions\Action::make('download_exceptions')
                        ->label('الملاحظات (JSON)')->icon('heroicon-o-exclamation-triangle')
                        ->visible(fn ($record) => filled($record->exceptions_path))
                        ->action(fn ($record) => static::downloadArtifact($record->exceptions_path)),
                    Tables\Actions\Action::make('download_result')
                        ->label('نتيجة الرفع (JSON)')->icon('heroicon-o-check-circle')
                        ->visible(fn ($record) => filled($record->result_path))
                        ->action(fn ($record) => static::downloadArtifact($record->result_path)),
                    Tables\Actions\Action::make('ssh')
                        ->label('أمر SSH')->icon('heroicon-o-command-line')
                        ->visible(fn ($record) => filled($record->command))
                        ->modalHeading('أمر التشغيل اليدوي')
                        ->modalDescription('إذا بقيت العملية «بالانتظار» (مثلاً لو كان التشغيل بالخلفية معطّل)، شغّل هذا الأمر على السيرفر.')
                        ->modalSubmitAction(false)
                        ->modalCancelActionLabel('إغلاق')
                        ->modalContent(fn ($record) => new \Illuminate\Support\HtmlString('<pre dir="ltr" style="white-space:pre-wrap;font-size:.75rem;background:#0f172a;color:#e2e8f0;padding:.75rem;border-radius:.5rem">' . e($record->command) . '</pre>')),
                ])->icon('heroicon-m-ellipsis-vertical')->tooltip('ملفات تقنية'),
            ])
            ->bulkActions([
                Tables\Actions\DeleteBulkAction::make(),
            ]);
    }

    /** Blocking errors of a run (older runs predate the split, so they have none). */
    public static function blockingErrors(DraftInvoiceRun $run): int
    {
        return (int) ($run->totals['errors'] ?? 0);
    }

    /**
     * A finished, clean analysis can be uploaded once: not while another upload
     * of the same file is running, and not after every draft is already in SAP.
     */
    public static function canPost(DraftInvoiceRun $run): bool
    {
        $t = $run->totals;
        if ($run->mode !== 'dry_run' || $run->status !== 'done' || !$t || ($t['drafts'] ?? 0) < 1 || static::blockingErrors($run) || !isset($t['errors'])) {
            return false;
        }
        if (!is_file($t['file_path'] ?? '')) {
            return false;
        }

        $busy = DraftInvoiceRun::query()
            ->where('file_hash', $run->file_hash)
            ->where('mode', 'post')
            ->whereIn('status', ['pending', 'running'])
            ->exists();
        if ($busy) {
            return false;
        }

        $posted = DraftInvoiceChunk::query()->where('file_hash', $run->file_hash)->where('status', 'posted')->count();
        return $posted < ($t['drafts'] ?? 0);
    }

    /** Grouped, labelled notes for the review screen. */
    public static function notes(DraftInvoiceRun $run): array
    {
        $path = $run->exceptions_path ? Storage::disk('local')->path($run->exceptions_path) : null;
        if (!$path || !is_file($path)) {
            return [];
        }
        $labels = [
            'missing_key' => 'أسطر بدون كود صنف أو مستودع',
            'unknown_customer' => 'عملاء غير موجودين في SAP',
            'unknown_item' => 'أصناف غير موجودة في SAP',
            'zero_qty' => 'أسطر كميتها صفر (تجاهلناها)',
            'return_unmatched' => 'مرتجعات ما لقينا لها مبيعات تُخصم منها',
            'no_batch_in_warehouse' => 'أصناف بدون دفعة في المستودع',
            'qty_over_onhand' => 'كميات أكبر من رصيد الدفعات',
            'non_positive_qty' => 'أسطر كميتها صفر أو سالبة',
        ];
        $grouped = [];
        foreach (json_decode((string) file_get_contents($path), true) ?: [] as $e) {
            $type = $e['type'] ?? 'other';
            $grouped[$type] ??= [
                'label' => $labels[$type] ?? $type,
                'blocking' => in_array($type, DraftInvoiceImportService::BLOCKING, true),
                'count' => 0,
            ];
            $grouped[$type]['count']++;
        }
        uasort($grouped, fn ($a, $b) => [$b['blocking'], $b['count']] <=> [$a['blocking'], $a['count']]);

        return array_values($grouped);
    }

    public static function logTail(DraftInvoiceRun $run, int $lines = 14): ?string
    {
        $file = storage_path("logs/draft_invoice_run_{$run->id}.log");
        if (!is_file($file)) {
            return null;
        }
        $all = preg_split('/\R/', trim((string) file_get_contents($file)));
        return implode("\n", array_slice($all, -$lines));
    }

    /** Analyse an uploaded file (never writes to SAP). */
    public static function startAnalysis(array $data): DraftInvoiceRun
    {
        return static::launch([
            'file_path' => Storage::disk('local')->path($data['file']),
            'card_code' => $data['card_code'] ?? null,
            'doc_date' => $data['doc_date'] ?? null,
            'chunk_size' => $data['chunk_size'] ?? 200,
            'expense_code' => $data['expense_code'] ?? null,
            'tax_code' => $data['tax_code'] ?? null,
            'no_batches' => !($data['with_batches'] ?? false),
            'warehouse_filter' => $data['warehouse_filter'] ?? null,
        ], post: false);
    }

    /** Upload exactly what a clean analysis showed: same file, same settings. */
    public static function startPostFrom(DraftInvoiceRun $analysis): DraftInvoiceRun
    {
        abort_unless(static::canPost($analysis), 422, 'This analysis cannot be uploaded.');

        return static::launch([
            'file_path' => $analysis->totals['file_path'],
            'card_code' => $analysis->card_code,
            'doc_date' => optional($analysis->doc_date)->format('Y-m-d'),
            'chunk_size' => $analysis->chunk_size,
            'expense_code' => $analysis->expense_code,
            'tax_code' => $analysis->tax_code,
            'no_batches' => $analysis->no_batches,
            'warehouse_filter' => $analysis->warehouse_filter,
        ], post: true);
    }

    /** Create the run row + spawn the background worker. */
    protected static function launch(array $p, bool $post): DraftInvoiceRun
    {
        $absPath = $p['file_path'];

        $run = DraftInvoiceRun::create([
            'source_file' => basename($absPath),
            'file_hash' => '',
            'company_db' => config('draft_invoices.default_db'),
            'mode' => $post ? 'post' : 'dry_run',
            'card_code' => $p['card_code'] ?: null,
            'doc_date' => $p['doc_date'] ?: now()->format('Y-m-d'),
            'chunk_size' => (int) ($p['chunk_size'] ?: 200),
            'expense_code' => filled($p['expense_code']) ? (int) $p['expense_code'] : null,
            'tax_code' => $p['tax_code'] ?: null,
            'no_batches' => (bool) $p['no_batches'],
            'warehouse_filter' => $p['warehouse_filter'] ?: null,
            'status' => 'pending',
            'created_by' => auth()->id(),
        ]);

        $php = config('draft_invoices.php_binary') ?: 'php';
        $artisan = base_path('artisan');
        $logFile = storage_path("logs/draft_invoice_run_{$run->id}.log");

        // Copy-pasteable SSH command (shown in the UI as a fallback).
        $copyable = sprintf(
            'cd %s && %s artisan sap:draft-invoices --run-id=%d --file=%s%s',
            base_path(), $php, $run->id, escapeshellarg($absPath), $post ? ' --post' : ''
        );
        $run->update(['command' => $copyable]);

        // Spawn detached so the web request returns immediately.
        $args = [$php, $artisan, 'sap:draft-invoices', '--run-id=' . $run->id, '--file=' . $absPath];
        if ($post) {
            $args[] = '--post';
        }
        $shell = 'nohup ' . implode(' ', array_map('escapeshellarg', $args)) . ' >> ' . escapeshellarg($logFile) . ' 2>&1 &';

        try {
            Process::fromShellCommandline($shell, base_path())->setTimeout(null)->run();
        } catch (\Throwable $e) {
            // Spawn failed (e.g. exec disabled): the run stays "pending" and the
            // SSH command above is shown so it can be launched manually.
            \Illuminate\Support\Facades\Log::warning('DraftInvoice spawn failed: ' . $e->getMessage());
        }

        return $run;
    }

    protected static function downloadArtifact(string $path, ?string $name = null)
    {
        $abs = Storage::disk('local')->path($path);
        abort_unless(is_file($abs), 404);
        return response()->download($abs, $name ?? basename($path));
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListDraftInvoiceImports::route('/'),
        ];
    }
}
