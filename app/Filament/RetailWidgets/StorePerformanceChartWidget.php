<?php

namespace App\Filament\RetailWidgets;

use Filament\Widgets\ChartWidget;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapInvoice;
use App\Models\SapCreditMemo;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

class StorePerformanceChartWidget extends ChartWidget
{
    use InteractsWithPageFilters;

    protected static bool $isDiscovered = false;

    protected static ?string $heading = 'أداء المعارض (صافي المبيعات)';
    protected static ?string $pollingInterval = '30s';
    protected static ?int $sort = 2; // Position ordering

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getData(): array
    {
        $startDate = $this->filters['startDate'] ?? Carbon::today()->toDateString();
        $endDate = $this->filters['endDate'] ?? Carbon::today()->toDateString();

        $startDate = Carbon::parse($startDate)->startOfDay();
        $endDate = Carbon::parse($endDate)->endOfDay();

        $cardCode = 'C0000001';

        $invoicesByEmp = SapInvoice::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select('sales_employee_code', DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('sales_employee_code')
            ->get();

        $returnsByEmp = SapCreditMemo::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select('sales_employee_code', DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('sales_employee_code')
            ->get()
            ->keyBy('sales_employee_code');

        $employeeNames = Cache::remember('sap_sales_persons_map', 3600 * 24, function () {
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

        $labels = [];
        $data = [];
        $colors = [];

        // Combine logic
        $storeData = [];
        foreach ($invoicesByEmp as $row) {
            $code = $row->sales_employee_code;
            if (!$code) continue;

            $totalSales = $row->total;
            $totalReturns = isset($returnsByEmp[$code]) ? $returnsByEmp[$code]->total : 0;
            $netSales = $totalSales - $totalReturns;

            $storeName = $employeeNames[$code] ?? "Code: " . $code;
            $storeName = str_replace(['POS Cashier - ', 'POS Cashier-'], '', $storeName);
            
            $storeData[] = [
                'name' => $storeName,
                'net' => $netSales
            ];
        }

        // Sort by net sales descending
        usort($storeData, function($a, $b) {
            return $b['net'] <=> $a['net'];
        });

        foreach ($storeData as $store) {
            $labels[] = $store['name'];
            $data[] = $store['net'];
            $colors[] = $store['net'] >= 0 ? 'rgba(74, 222, 128, 0.8)' : 'rgba(248, 113, 113, 0.8)'; // green / red
        }

        return [
            'datasets' => [
                [
                    'label' => 'صافي المبيعات (Net Sales)',
                    'data' => $data,
                    'backgroundColor' => $colors,
                    'borderRadius' => 4,
                ],
            ],
            'labels' => $labels,
        ];
    }
}
