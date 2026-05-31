<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapCreditMemoLine;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class StoreReturnsTable extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static ?int $sort = 4;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'تحليل المرتجعات بالفرع (Returns Analysis)';
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
                SapCreditMemoLine::query()
                    ->join('sap_credit_memos', 'sap_credit_memo_lines.sap_credit_memo_id', '=', 'sap_credit_memos.id')
                    ->where('sap_credit_memos.card_code', 'C0000001')
                    ->where('sap_credit_memos.sales_employee_code', $storeCode)
                    ->whereBetween('sap_credit_memos.doc_date', [$startDate, $endDate])
                    ->select(
                        DB::raw('MAX(sap_credit_memo_lines.id) as id'),
                        'sap_credit_memo_lines.item_code',
                        DB::raw('MAX(sap_credit_memo_lines.item_description) as description'),
                        DB::raw('SUM(sap_credit_memo_lines.quantity) as total_qty'),
                        DB::raw('SUM(sap_credit_memo_lines.price * sap_credit_memo_lines.quantity) as total_value')
                    )
                    ->groupBy('sap_credit_memo_lines.item_code')
                    ->orderByDesc('total_value')
                    ->orderByDesc('total_value')
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
                    ->label('الكمية المسترجعة')
                    ->badge()
                    ->color('danger'),
                Tables\Columns\TextColumn::make('total_value')
                    ->label('خسارة القيمة')
                    ->money('SAR')
                    ->color('danger'),
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
                            fputcsv($handle, ['كود المنتج', 'الكمية المسترجعة', 'خسارة القيمة (SAR)']);
                            foreach ($records as $record) {
                                fputcsv($handle, [$record->item_code, $record->total_qty, $record->total_value]);
                            }
                            fclose($handle);
                        }, 'returns.csv');
                    })
            ])
            ->defaultPaginationPageOption(5)
            ->paginated([5, 10, 25, 50, 'all']);
    }
}
