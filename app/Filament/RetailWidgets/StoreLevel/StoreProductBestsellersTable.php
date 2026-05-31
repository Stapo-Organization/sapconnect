<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapInvoiceLine;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class StoreProductBestsellersTable extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static ?int $sort = 3;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'أفضل المنتجات مبيعاً بالفرع (Bestsellers)';
    protected static bool $isDiscovered = false;

    public function table(Table $table): Table
    {
        $storeCode = request()->route('storeCode');
        if (!$storeCode && request()->header('referer')) {
            $segments = explode('/', parse_url(request()->header('referer'), PHP_URL_PATH));
            $storeCode = end($segments);
        }
        $startDate = $this->filters['startDate'] ?? Carbon::now()->startOfMonth()->toDateString();
        $endDate = $this->filters['endDate'] ?? Carbon::now()->endOfDay()->toDateString();

        $startDate = Carbon::parse($startDate)->startOfDay();
        $endDate = Carbon::parse($endDate)->endOfDay();

        return $table
            ->query(
                SapInvoiceLine::query()
                    ->join('sap_invoices', 'sap_invoice_lines.sap_invoice_id', '=', 'sap_invoices.id')
                    ->where('sap_invoices.card_code', 'C0000001')
                    ->where('sap_invoices.sales_employee_code', $storeCode)
                    ->whereBetween('sap_invoices.doc_date', [$startDate, $endDate])
                    ->select(
                        DB::raw('MAX(sap_invoice_lines.id) as id'),
                        'sap_invoice_lines.item_code',
                        DB::raw('SUM(sap_invoice_lines.quantity) as total_qty')
                    )
                    ->groupBy('sap_invoice_lines.item_code')
                    ->orderByDesc('total_qty')
            )
            ->columns([
                Tables\Columns\ImageColumn::make('product_image')
                    ->label('صورة المنتج')
                    ->alignCenter()
                    ->state(function ($record) {
                        $code = $record->item_code;
                        return empty($code) ? null : "https://ppte.sa/img/" . substr($code, 0, 4) . "/{$code}.png";
                    }),
                Tables\Columns\TextColumn::make('item_code')
                    ->label('كود المنتج'),
                Tables\Columns\TextColumn::make('total_qty')
                    ->label('الكمية المباعة هنا')
                    ->badge()
                    ->color('success'),
            ])
            ->headerActions([
                Tables\Actions\Action::make('export_csv')
                    ->label('تصدير إكسل')
                    ->icon('heroicon-o-document-arrow-down')
                    ->action(function ($livewire) {
                        $records = $livewire->getTableQuery()->get();
                        return response()->streamDownload(function() use ($records) {
                            $handle = fopen('php://output', 'w');
                            fputs($handle, chr(0xEF) . chr(0xBB) . chr(0xBF));
                            fputcsv($handle, ['كود المنتج', 'الكمية المباعة']);
                            foreach ($records as $record) {
                                fputcsv($handle, [$record->item_code, $record->total_qty]);
                            }
                            fclose($handle);
                        }, 'bestsellers.csv');
                    })
            ])
            ->defaultPaginationPageOption(5)
            ->paginated([5, 10, 25, 50, 'all']);
    }
}
