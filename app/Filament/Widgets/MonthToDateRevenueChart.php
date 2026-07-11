<?php

namespace App\Filament\Widgets;

use Filament\Widgets\ChartWidget;
use App\Models\SapInvoice;
use App\Models\SapCreditMemo;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class MonthToDateRevenueChart extends ChartWidget
{
    protected static ?string $heading = 'مسار الإيرادات (Revenue Timeline - الشهر الحالي)';
    protected static ?string $pollingInterval = '30s';
    protected static ?int $sort = 5;

    protected function getType(): string
    {
        return 'line';
    }

    protected function getData(): array
    {
        $startDate = Carbon::now()->startOfMonth();
        $endDate = Carbon::now()->endOfDay();

        $cardCode = 'C0000001';

        // Group invoices by Date (ex-VAT)
        $invoicesByDate = SapInvoice::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        // Group returns by Date (ex-VAT)
        $returnsByDate = SapCreditMemo::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('DATE(doc_date) as date'), DB::raw('SUM(doc_total / 1.15) as total'))
            ->groupBy('date')
            ->get()
            ->keyBy('date');

        $labels = [];
        $netData = [];
        $grossData = [];

        // Build array of all dates between start of month and today
        for ($date = $startDate->copy(); $date->lte(Carbon::now()); $date->addDay()) {
            $dateString = $date->toDateString();
            $labels[] = $date->format('d M');

            // Find matching data or 0
            $invObj = $invoicesByDate->firstWhere('date', $dateString);
            $gross = $invObj ? (float) $invObj->total : 0;
            
            $retObj = isset($returnsByDate[$dateString]) ? (float) $returnsByDate[$dateString]->total : 0;

            $net = $gross - $retObj;

            $grossData[] = $gross;
            $netData[] = $net;
        }

        return [
            'datasets' => [
                [
                    'label' => 'صافي الإيرادات (Net Revenue)',
                    'data' => $netData,
                    'borderColor' => '#10b981', // green
                    'backgroundColor' => 'rgba(16, 185, 129, 0.1)',
                    'fill' => true,
                    'tension' => 0.4,
                ],
                [
                    'label' => 'إجمالي المبيعات (Gross Sales)',
                    'data' => $grossData,
                    'borderColor' => '#3b82f6', // blue
                    'borderDash' => [5, 5],
                    'fill' => false,
                    'tension' => 0.4,
                ],
            ],
            'labels' => $labels,
        ];
    }
}
