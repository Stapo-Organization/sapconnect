<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use App\Models\WarehouseItemStock;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class StoreOverstockTable extends BaseWidget
{
    protected static ?int $sort = 6;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'تكدس المخزون (Overstocked Items > 60 days)';
    protected static bool $isDiscovered = false;

    public function table(Table $table): Table
    {
        $storeCode = request()->route('storeCode');
        if (!$storeCode && request()->header('referer')) {
            $segments = explode('/', parse_url(request()->header('referer'), PHP_URL_PATH));
            $storeCode = end($segments);
        }

        $employeeNames = \Illuminate\Support\Facades\Cache::remember('sap_sales_persons_map', 3600 * 24, function () {
            try {
                $sapClient = app(\App\Services\SAP\SapClient::class);
                $sapClient->setCompanyDb('PPTC_V5_PROD');
                $skip = 0;
                $map = [];
                while (true) {
                    $res = $sapClient->get('SalesPersons', ['$select' => 'SalesEmployeeCode,SalesEmployeeName', '$skip' => $skip]);
                    $values = $res['value'] ?? [];
                    if (empty($values)) break;
                    foreach ($values as $person) {
                        $map[$person['SalesEmployeeCode']] = $person['SalesEmployeeName'];
                    }
                    if (!isset($res['odata.nextLink'])) break;
                    $skip += count($values);
                }
                return $map;
            } catch (\Exception $e) {
                return [];
            }
        });

        $storeName = $employeeNames[$storeCode] ?? '';
        $storeName = str_replace(['POS Cashier - ', 'POS Cashier-'], '', $storeName);

        $warehouses = [];
        if (!empty($storeName)) {
            $warehouses = Warehouse::where('warehouse_name', 'LIKE', '%' . trim($storeName) . '%')
                ->pluck('warehouse_code')
                ->toArray();
        }

        $ninetyDaysAgo = Carbon::now()->subDays(90)->toDateString();
        
        $salesSubquery = "(
            SELECT sap_invoice_lines.item_code, (SUM(sap_invoice_lines.quantity) / 90) as current_ads
            FROM sap_invoice_lines
            JOIN sap_invoices ON sap_invoice_lines.sap_invoice_id = sap_invoices.id
            WHERE sap_invoices.card_code = 'C0000001'
            AND sap_invoices.sales_employee_code = '{$storeCode}'
            AND sap_invoices.doc_date >= '{$ninetyDaysAgo}'
            GROUP BY sap_invoice_lines.item_code
        ) as sales_data";

        return $table
            ->query(
                WarehouseItemStock::query()
                    ->whereIn('warehouse_item_stocks.warehouse_code', $warehouses)
                    ->where('warehouse_item_stocks.in_stock', '>', 5) // At least 5 items
                    ->leftJoin(DB::raw($salesSubquery), 'warehouse_item_stocks.item_code', '=', 'sales_data.item_code')
                    ->whereRaw('(warehouse_item_stocks.in_stock / COALESCE(NULLIF(sales_data.current_ads, 0), 0.001)) > 60')
                    ->select(
                        'warehouse_item_stocks.*',
                        DB::raw('COALESCE(sales_data.current_ads, 0) as ads'),
                        DB::raw('(warehouse_item_stocks.in_stock / COALESCE(NULLIF(sales_data.current_ads, 0), 0.001)) as dos')
                    )
                    ->orderByDesc('dos')
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
                Tables\Columns\TextColumn::make('in_stock')
                    ->label('المخزون الحالي')
                    ->numeric()
                    ->badge()
                    ->color('danger'),
                Tables\Columns\TextColumn::make('ordered')
                    ->label('الكمية بالطريق')
                    ->numeric()
                    ->badge()
                    ->color('info')
                    ->icon('heroicon-m-clock'),
                Tables\Columns\TextColumn::make('ads')
                    ->label('متوسط البيع اليومي')
                    ->getStateUsing(fn ($record) => number_format($record->ads, 2))
                    ->color('gray'),
                Tables\Columns\TextColumn::make('dos')
                    ->label('يكفي لـ (أيام)')
                    ->getStateUsing(function ($record) {
                        return $record->dos > 999 ? '999+ (حركة شبه معدومة)' : floor($record->dos);
                    })
                    ->badge()
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
                            fputcsv($handle, ['كود المنتج', 'المخزون الحالي', 'الكمية بالطريق', 'متوسط البيع اليومي', 'يكفي لـ (أيام)']);
                            foreach ($records as $record) {
                                fputcsv($handle, [$record->item_code, $record->in_stock, $record->ordered, number_format($record->ads, 2), $record->dos > 999 ? '999+' : floor($record->dos)]);
                            }
                            fclose($handle);
                        }, 'overstock_items.csv');
                    })
            ])
            ->defaultPaginationPageOption(5)
            ->paginated([5, 10, 25, 50, 'all']);
    }
}
