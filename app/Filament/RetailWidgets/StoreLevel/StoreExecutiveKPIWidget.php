<?php

namespace App\Filament\RetailWidgets\StoreLevel;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use App\Models\SapInvoice;
use App\Models\SapCreditMemo;
use Carbon\Carbon;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use Illuminate\Support\Facades\DB;

class StoreExecutiveKPIWidget extends BaseWidget
{
    use InteractsWithPageFilters;

    protected static ?string $pollingInterval = '30s';
    protected static bool $isDiscovered = false;

    protected function getStats(): array
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

        // 1. Invoices (ex-VAT)
        $invoicesAgg = SapInvoice::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->where('sales_employee_code', $storeCode)
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('COUNT(*) as count'), DB::raw('SUM(doc_total / 1.15) as total'))
            ->first();

        // 2. Returns (ex-VAT)
        $returnsAgg = SapCreditMemo::where('card_code', $cardCode)
            ->where('cancelled', 'N')
            ->where('sales_employee_code', $storeCode)
            ->whereBetween('doc_date', [$startDate, $endDate])
            ->select(DB::raw('COUNT(*) as count'), DB::raw('SUM(doc_total / 1.15) as total'))
            ->first();

        $grossSales = (float) ($invoicesAgg->total ?? 0);
        $totalInvoices = (int) ($invoicesAgg->count ?? 0);
        
        $totalReturns = (float) ($returnsAgg->total ?? 0);
        $totalReturnDocs = (int) ($returnsAgg->count ?? 0);

        $netSales = $grossSales - $totalReturns;

        $aov = $totalInvoices > 0 ? ($netSales / $totalInvoices) : 0;
        $returnRate = $grossSales > 0 ? ($totalReturns / $grossSales) * 100 : 0;

        return [
            Stat::make('صافي المبيعات (Net Sales)', number_format($netSales, 2) . ' SAR')
                ->description('المبيعات الإجمالية: ' . number_format($grossSales, 2))
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('success'),
                
            Stat::make('العمليات البيعية (Transactions)', number_format($totalInvoices))
                ->description('متوسط سلة العميل: ' . number_format($aov, 2) . ' SAR')
                ->descriptionIcon('heroicon-m-shopping-bag')
                ->color('primary'),

            Stat::make('المرتجعات (Returns)', number_format($totalReturns, 2) . ' SAR')
                ->description('معدل الاسترجاع: ' . number_format($returnRate, 2) . '% من الإجمالي')
                ->descriptionIcon('heroicon-m-arrow-path-rounded-square')
                ->color($returnRate > 5 ? 'danger' : 'warning'),
        ];
    }
}
