<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SuggestedStockTransfer;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class StoreSmartReplenishmentTable extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static ?int $sort = 5;
    protected int | string | array $columnSpan = 'half';
    protected static ?string $heading = 'توصيات التحويل الذكي (Smart Replenishment)';
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

        return $table
            ->query(
                SuggestedStockTransfer::query()
                    ->whereIn('target_warehouse', $warehouses)
                    ->where('suggested_quantity', '>', 0)
                    ->orderByDesc('suggested_quantity')
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
                    ->label('المنتج المقترح (Item)'),
                Tables\Columns\TextColumn::make('target_warehouse')
                    ->label('المستودع (Warehouse)')
                    ->badge()
                    ->color('warning'),
                Tables\Columns\TextColumn::make('ordered_qty')
                    ->label('بالطريق (Ordered)')
                    ->getStateUsing(function ($record) {
                        return \App\Models\WarehouseItemStock::where('item_code', $record->item_code)
                            ->where('warehouse_code', $record->target_warehouse)
                            ->value('ordered') ?? 0;
                    })
                    ->badge()
                    ->color('info')
                    ->icon('heroicon-m-clock'),
                Tables\Columns\TextColumn::make('suggested_quantity')
                    ->label('موصى بتحويله (Suggested)')
                    ->badge()
                    ->color('primary')
                    ->icon('heroicon-m-truck'),
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
                            fputcsv($handle, ['كود المنتج', 'المستودع', 'الكمية بالطريق', 'الكمية الموصى بها']);
                            foreach ($records as $record) {
                                $ordered = \App\Models\WarehouseItemStock::where('item_code', $record->item_code)
                                    ->where('warehouse_code', $record->target_warehouse)
                                    ->value('ordered') ?? 0;
                                fputcsv($handle, [$record->item_code, $record->target_warehouse, $ordered, $record->suggested_quantity]);
                            }
                            fclose($handle);
                        }, 'smart_replenishment.csv');
                    })
            ])
            ->defaultPaginationPageOption(5)
            ->paginated([5, 10, 25, 50, 'all']);
    }
}
