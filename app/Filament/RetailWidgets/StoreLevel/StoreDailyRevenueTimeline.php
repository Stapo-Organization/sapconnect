<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Widgets\ChartWidget;
use App\Models\SapInvoice;
use App\Models\SapCreditMemo;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Filament\Widgets\Concerns\InteractsWithPageFilters;

class StoreDailyRevenueTimeline extends ChartWidget
{
    use InteractsWithPageFilters;

    protected static ?string $heading = 'الأداء اليومي للفرع (Daily Performance)';
    protected static ?string $pollingInterval = '30s';
    protected static bool $isDiscovered = false;
    protected static ?int $sort = 2;
    protected int | string | array $columnSpan = 'full';

    protected function getType(): string
    {
        return 'line';
    }

    protected function getData(): array
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
        $cardCode = 'C0000001';

        $invoices = SapInvoice::where('card_code', $cardCode)
            ->where('sales_employee_code', $storeCode)
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total) as total'))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        $returns = SapCreditMemo::where('card_code', $cardCode)
            ->where('sales_employee_code', $storeCode)
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total) as total'))
            ->groupBy('date')
            ->get()
            ->keyBy('date');

        // Historical Average Calculation
        $historicalInvoices = SapInvoice::where('card_code', $cardCode)
            ->where('sales_employee_code', $storeCode)
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total) as total'))
            ->groupBy('date')
            ->get();

        $historicalReturns = SapCreditMemo::where('card_code', $cardCode)
            ->where('sales_employee_code', $storeCode)
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total) as total'))
            ->groupBy('date')
            ->get()
            ->keyBy('date');

        $dayAverages = [];
        foreach ($historicalInvoices as $row) {
            $day = Carbon::parse($row->date)->day;
            $retTotal = isset($historicalReturns[$row->date]) ? (float) $historicalReturns[$row->date]->total : 0;
            $net = $row->total - $retTotal;
            $dayAverages[$day][] = $net;
        }

        $finalDayAverages = [];
        for ($i = 1; $i <= 31; $i++) {
            if (isset($dayAverages[$i]) && count($dayAverages[$i]) > 0) {
                $finalDayAverages[$i] = array_sum($dayAverages[$i]) / count($dayAverages[$i]);
            } else {
                $finalDayAverages[$i] = 0;
            }
        }

        $labels = [];
        $netData = [];
        $avgData = [];

        for ($date = $startDate->copy(); $date->lte($endDate); $date->addDay()) {
            $dateString = $date->toDateString();
            $labels[] = $date->format('d M');

            $invObj = $invoices->firstWhere('date', $dateString);
            $gross = $invObj ? (float) $invObj->total : 0;
            
            $retObj = isset($returns[$dateString]) ? (float) $returns[$dateString]->total : 0;

            $netData[] = round($gross - $retObj, 2);
            $avgData[] = round($finalDayAverages[$date->day] ?? 0, 2);
        }

        return [
            'datasets' => [
                [
                    'label' => 'صافي مبيعات اليوم (Net Sales)',
                    'data' => $netData,
                    'borderColor' => '#10b981',
                    'backgroundColor' => 'rgba(16, 185, 129, 0.1)',
                    'fill' => true,
                    'tension' => 0.4,
                ],
                [
                    'label' => 'المتوسط التاريخي لهذا اليوم (Day Average)',
                    'data' => $avgData,
                    'borderColor' => '#94a3b8',
                    'borderDash' => [5, 5],
                    'backgroundColor' => 'transparent',
                    'fill' => false,
                    'tension' => 0.4,
                ],
            ],
            'labels' => $labels,
        ];
    }
}
