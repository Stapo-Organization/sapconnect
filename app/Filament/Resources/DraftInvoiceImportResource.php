<?php

namespace App\Filament\Resources;

use App\Filament\Resources\DraftInvoiceImportResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\DraftInvoiceRun;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

/**
 * "تقرير مبيعات → مسودات فواتير SAP".
 *
 * Upload a flat sales report (one row = one sold line) and turn it into SAP
 * **draft** invoices (Drafts / oInvoices), one draft per warehouse-chunk, with
 * nearest-expiry (FEFO) batches attached for batch-managed items and freight
 * summed into the header. Drafts never post to the ledger until a human opens
 * them in SAP and clicks Add. The heavy work runs in a background CLI worker.
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
            ->columns([
                Tables\Columns\TextColumn::make('id')->label('#')->sortable(),
                Tables\Columns\TextColumn::make('source_file')->label('الملف')->limit(28)->tooltip(fn ($record) => $record->source_file)->searchable(),
                Tables\Columns\TextColumn::make('company_db')->label('قاعدة SAP')->badge()->color('gray'),
                Tables\Columns\TextColumn::make('mode')->label('النوع')->badge()
                    ->formatStateUsing(fn ($state) => $state === 'post' ? 'ترحيل (POST)' : 'معاينة')
                    ->color(fn ($state) => $state === 'post' ? 'warning' : 'gray'),
                Tables\Columns\TextColumn::make('warehouse_filter')->label('مستودع')->default('الكل')->badge(),
                Tables\Columns\TextColumn::make('status')->label('الحالة')->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'pending' => 'بالانتظار', 'running' => 'يعمل…', 'done' => 'تم', 'failed' => 'فشل', default => $state,
                    })
                    ->color(fn ($state) => match ($state) {
                        'running' => 'info', 'done' => 'success', 'failed' => 'danger', default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('totals')->label('النتيجة')->getStateUsing(function ($record) {
                    $t = $record->totals;
                    if (!$t) {
                        return '—';
                    }
                    return sprintf(
                        'مسودات %d · مرحّلة %d · تخطّي %d · فشل %d · استثناءات %d',
                        $t['drafts'] ?? 0, $t['posted'] ?? 0, $t['skipped'] ?? 0, $t['failed'] ?? 0, $t['exceptions'] ?? 0
                    );
                })->wrap(),
                Tables\Columns\TextColumn::make('created_at')->label('التاريخ')->dateTime('Y-m-d H:i')->sortable(),
            ])
            ->actions([
                Tables\Actions\Action::make('details')
                    ->label('تفاصيل')
                    ->icon('heroicon-o-eye')
                    ->modalHeading(fn ($record) => "تفاصيل العملية #{$record->id}")
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('إغلاق')
                    ->modalContent(fn ($record) => new \Illuminate\Support\HtmlString(static::detailsHtml($record))),

                Tables\Actions\Action::make('download_preview')
                    ->label('المعاينة')->icon('heroicon-o-document-magnifying-glass')->color('info')
                    ->visible(fn ($record) => filled($record->preview_path))
                    ->action(fn ($record) => static::downloadArtifact($record->preview_path)),

                Tables\Actions\Action::make('download_exceptions')
                    ->label('الاستثناءات')->icon('heroicon-o-exclamation-triangle')->color('warning')
                    ->visible(fn ($record) => filled($record->exceptions_path))
                    ->action(fn ($record) => static::downloadArtifact($record->exceptions_path)),

                Tables\Actions\Action::make('download_result')
                    ->label('النتيجة')->icon('heroicon-o-check-circle')->color('success')
                    ->visible(fn ($record) => filled($record->result_path))
                    ->action(fn ($record) => static::downloadArtifact($record->result_path)),
            ])
            ->bulkActions([
                Tables\Actions\DeleteBulkAction::make(),
            ]);
    }

    /** Create the run row + spawn the background worker. Returns the run. */
    public static function startRun(array $data): DraftInvoiceRun
    {
        $relPath = $data['file'];
        $absPath = Storage::disk('local')->path($relPath);

        $post = !($data['dry_run'] ?? true);

        $run = DraftInvoiceRun::create([
            'source_file' => basename($absPath),
            'file_hash' => '',
            'company_db' => $data['company_db'] ?: config('draft_invoices.default_db'),
            'mode' => $post ? 'post' : 'dry_run',
            'card_code' => $data['card_code'] ?: null,
            'doc_date' => $data['doc_date'] ?: now()->format('Y-m-d'),
            'chunk_size' => (int) ($data['chunk_size'] ?: 200),
            'expense_code' => $data['expense_code'] !== null && $data['expense_code'] !== '' ? (int) $data['expense_code'] : null,
            'tax_code' => $data['tax_code'] ?: null,
            'no_batches' => (bool) ($data['no_batches'] ?? false),
            'warehouse_filter' => $data['warehouse_filter'] ?: null,
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

    protected static function downloadArtifact(string $path)
    {
        $abs = Storage::disk('local')->path($path);
        abort_unless(is_file($abs), 404);
        return response()->download($abs, basename($path));
    }

    protected static function detailsHtml(DraftInvoiceRun $record): string
    {
        $t = $record->totals ?? [];
        $rows = '';
        foreach (($t['warehouses'] ?? []) as $wh => $w) {
            $rows .= sprintf(
                '<tr><td class="px-2 py-1 font-mono">%s</td><td class="px-2 py-1">%d</td><td class="px-2 py-1">%d</td><td class="px-2 py-1 text-green-600">%d</td><td class="px-2 py-1 text-gray-500">%d</td><td class="px-2 py-1 text-red-600">%d</td></tr>',
                e($wh), $w['chunks'] ?? 0, $w['lines'] ?? 0, $w['posted'] ?? 0, $w['skipped'] ?? 0, $w['failed'] ?? 0
            );
        }

        $whTable = $rows
            ? '<table class="text-xs w-full border mt-1"><thead><tr class="bg-gray-100"><th class="px-2 py-1 text-right">مستودع</th><th class="px-2 py-1">مسودات</th><th class="px-2 py-1">أسطر</th><th class="px-2 py-1">مرحّلة</th><th class="px-2 py-1">تخطّي</th><th class="px-2 py-1">فشل</th></tr></thead><tbody>' . $rows . '</tbody></table>'
            : '<div class="text-xs text-gray-400">لا توجد بيانات بعد.</div>';

        $err = $record->error ? '<div class="mt-2 p-2 bg-red-50 text-red-700 text-xs rounded">' . e($record->error) . '</div>' : '';
        $cmd = $record->command ? '<div class="mt-3 text-xs"><div class="text-gray-500 mb-1">إذا بقيت الحالة «بالانتظار»، شغّل هذا الأمر عبر SSH:</div><pre class="bg-gray-900 text-gray-100 p-2 rounded overflow-auto" style="font-size:0.7rem">' . e($record->command) . '</pre></div>' : '';

        return '<div dir="rtl" class="space-y-2 text-sm">' . $whTable . $err . $cmd . '</div>';
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListDraftInvoiceImports::route('/'),
        ];
    }
}
