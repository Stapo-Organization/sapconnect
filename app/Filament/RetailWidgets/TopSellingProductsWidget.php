<?php

namespace App\Filament\RetailWidgets;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapInvoiceLine;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class TopSellingProductsWidget extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static bool $isDiscovered = false;

    protected static ?int $sort = 4;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'أفضل 5 منتجات مبيعاً (Top 5 Bestsellers)';

    public function table(Table $table): Table
    {
        $startDate = $this->filters['startDate'] ?? Carbon::today()->toDateString();
        $endDate = $this->filters['endDate'] ?? Carbon::today()->toDateString();

        $startDate = Carbon::parse($startDate)->startOfDay();
        $endDate = Carbon::parse($endDate)->endOfDay();

        return $table
            ->query(
                SapInvoiceLine::query()
                    ->join('sap_invoices', 'sap_invoice_lines.sap_invoice_id', '=', 'sap_invoices.id')
                    ->where('sap_invoices.card_code', 'C0000001')
                    ->whereBetween('sap_invoices.doc_date', [$startDate, $endDate])
                    ->select(
                        DB::raw('MAX(sap_invoice_lines.id) as id'),
                        'sap_invoice_lines.item_code',
                        DB::raw('SUM(sap_invoice_lines.quantity) as total_qty')
                    )
                    ->groupBy('sap_invoice_lines.item_code')
                    ->orderByDesc('total_qty') // Order by quantity since price is not tracked individually
                    ->limit(5)
            )
            ->columns([
                Tables\Columns\TextColumn::make('item_code')
                    ->label('كود المنتج'),
                Tables\Columns\TextColumn::make('total_qty')
                    ->label('الكمية المباعة')
                    ->badge()
                    ->color('success'),
            ])
            ->paginated(false);
    }
}
