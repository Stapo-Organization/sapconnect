<?php

namespace App\Filament\RetailWidgets;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapCreditMemoLine;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class TopReturnedProductsWidget extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static bool $isDiscovered = false;

    protected static ?int $sort = 5;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'أكثر المنتجات المرتجعة للرقابة (Top 5 Returned)';

    public function table(Table $table): Table
    {
        $startDate = $this->filters['startDate'] ?? Carbon::today()->toDateString();
        $endDate = $this->filters['endDate'] ?? Carbon::today()->toDateString();

        $startDate = Carbon::parse($startDate)->startOfDay();
        $endDate = Carbon::parse($endDate)->endOfDay();

        return $table
            ->query(
                SapCreditMemoLine::query()
                    ->join('sap_credit_memos', 'sap_credit_memo_lines.sap_credit_memo_id', '=', 'sap_credit_memos.id')
                    ->where('sap_credit_memos.card_code', 'C0000001')
                    ->whereBetween('sap_credit_memos.doc_date', [$startDate, $endDate])
                    ->select(
                        DB::raw('MAX(sap_credit_memo_lines.id) as id'),
                        'sap_credit_memo_lines.item_code',
                        DB::raw('MAX(sap_credit_memo_lines.item_description) as description'),
                        DB::raw('SUM(sap_credit_memo_lines.quantity) as total_qty'),
                        DB::raw('SUM(sap_credit_memo_lines.price * sap_credit_memo_lines.quantity) as total_value')
                    )
                    ->groupBy('sap_credit_memo_lines.item_code')
                    ->orderByDesc('total_value') // Order by value
                    ->limit(5)
            )
            ->columns([
                Tables\Columns\TextColumn::make('item_code')
                    ->label('كود المنتج'),
                Tables\Columns\TextColumn::make('description')
                    ->label('الوصف')
                    ->limit(20)
                    ->tooltip(function (\Filament\Tables\Columns\TextColumn $column): ?string {
                        $state = $column->getState();
                        return strlen($state) > 20 ? $state : null;
                    }),
                Tables\Columns\TextColumn::make('total_qty')
                    ->label('العدد المسترجع')
                    ->badge()
                    ->color('danger'),
                Tables\Columns\TextColumn::make('total_value')
                    ->label('خسارة العائد (SAR)')
                    ->money('SAR')
                    ->color('danger'),
            ])
            ->paginated(false);
    }
}
