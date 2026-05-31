<?php

namespace App\Filament\Pages;

use Filament\Pages\Dashboard;
use Illuminate\Support\Facades\Cache;
use App\Services\SAP\SapClient;
use Filament\Pages\Dashboard\Concerns\HasFiltersForm;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Form;
use Filament\Forms\Components\Section;
use Carbon\Carbon;

class StoreDashboard extends Dashboard
{
    use HasFiltersForm;
    protected static bool $shouldRegisterNavigation = false;
    protected static ?string $slug = 'store-dashboard/{storeCode}';
    protected static string $routePath = 'store-dashboard/{storeCode}';

    public ?string $storeCode = null;
    public string $storeName = 'Store Analytics';

    public function mount(): void
    {
        $this->storeCode = request()->route('storeCode');
        
        $employeeNames = Cache::remember('sap_sales_persons_map', 3600 * 24, function () {
            try {
                $sapClient = app(SapClient::class);
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

        $this->storeName = $employeeNames[$this->storeCode] ?? "Store " . $this->storeCode;
        $this->storeName = str_replace(['POS Cashier - ', 'POS Cashier-'], '', $this->storeName);
    }

    public function getTitle(): string
    {
        return $this->storeName;
    }

    public function getSubheading(): ?string
    {
        return 'لوحة التحكم والتحليل المفصلة للفرع (Branch Command Center)';
    }

    public function filtersForm(Form $form): Form
    {
        return $form->schema([
            Section::make()
                ->schema([
                    DatePicker::make('startDate')
                        ->label('Start Date (من)')
                        ->default(Carbon::today()->startOfMonth()->toDateString())
                        ->native(false),
                    DatePicker::make('endDate')
                        ->label('End Date (إلى)')
                        ->default(Carbon::today()->toDateString())
                        ->native(false),
                ])
                ->columns(2),
        ]);
    }

    public function getWidgets(): array
    {
        return [
            \App\Filament\RetailWidgets\StoreLevel\StoreExecutiveKPIWidget::class,
            \App\Filament\RetailWidgets\StoreLevel\StoreDailyRevenueTimeline::class,
            \App\Filament\RetailWidgets\StoreLevel\StoreProductBestsellersTable::class,
            \App\Filament\RetailWidgets\StoreLevel\StoreReturnsTable::class,
            \App\Filament\RetailWidgets\StoreLevel\StoreSmartReplenishmentTable::class,
            \App\Filament\RetailWidgets\StoreLevel\StoreOverstockTable::class,
        ];
    }
}
