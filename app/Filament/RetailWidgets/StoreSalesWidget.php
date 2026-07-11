<?php

namespace App\Filament\RetailWidgets;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\Warehouse;
use App\Models\SapInvoice;
use Carbon\Carbon;

class StoreSalesWidget extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static bool $isDiscovered = false;

    protected static ?string $pollingInterval = '30s';

    protected function getStats(): array
    {
        $startDate = $this->filters['startDate'] ?? Carbon::today()->toDateString();
        $endDate = $this->filters['endDate'] ?? Carbon::today()->toDateString();

        $startDate = Carbon::parse($startDate)->startOfDay();
        $endDate = Carbon::parse($endDate)->endOfDay();

        $cardCode = 'C0000001';

        // Get all retail invoices in date range grouped by employee code (ex-VAT)
        $invoicesByEmp = SapInvoice::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select('sales_employee_code', \Illuminate\Support\Facades\DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('sales_employee_code')
            ->get();

        // Get all retail returns in date range grouped by employee code (ex-VAT)
        $returnsByEmp = \App\Models\SapCreditMemo::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select('sales_employee_code', \Illuminate\Support\Facades\DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('sales_employee_code')
            ->get()
            ->keyBy('sales_employee_code');

        $stats = [];

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
                
                if (empty($map)) {
                    \Illuminate\Support\Facades\Cache::forget('sap_sales_persons_map');
                }
                
                return $map;
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Cache::forget('sap_sales_persons_map');
                return [];
            }
        });

        foreach ($invoicesByEmp as $row) {
            $code = $row->sales_employee_code;
            $totalSales = $row->total;

            if (!$code) continue; // skip null entries
            
            $totalReturns = isset($returnsByEmp[$code]) ? $returnsByEmp[$code]->total : 0;
            $netSales = $totalSales - $totalReturns;

            $storeName = $employeeNames[$code] ?? "Sales Employee: " . $code;
            
            // Clean up the name for the dashboard if needed, or leave it exactly as SAP
            $storeName = str_replace('POS Cashier - ', '', $storeName);
            $storeName = str_replace('POS Cashier-', '', $storeName);

            $stats[] = Stat::make($storeName, number_format($netSales, 2) . ' SAR')
                ->description("الإجمالي: " . number_format($totalSales, 2) . " | المرتجع: " . number_format($totalReturns, 2))
                ->descriptionIcon('heroicon-m-receipt-refund')
                ->color($netSales > 0 ? 'success' : 'danger')
                ->url(url('/admin/store-dashboard/' . $code))
                ->extraAttributes([
                    'class' => 'cursor-pointer hover:shadow-lg transition-shadow duration-300',
                ]);
        }

        // Sort stats descending by sales
        usort($stats, function($a, $b) {
            return 0;
        });

        return $stats;
    }
}
