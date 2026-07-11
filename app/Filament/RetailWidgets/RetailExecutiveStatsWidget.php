<?php

namespace App\Filament\RetailWidgets;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Filament\Widgets\Concerns\InteractsWithPageFilters;
use App\Models\SapInvoice;
use App\Models\SapCreditMemo;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class RetailExecutiveStatsWidget extends BaseWidget
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

        // Base Queries — exclude cancelled documents (SAP CANCELED = 'N')
        $invoicesQuery = SapInvoice::where('card_code', $cardCode)->where('cancelled', 'N')->whereBetween('doc_date', [$startDate, $endDate]);
        $returnsQuery = SapCreditMemo::where('card_code', $cardCode)->where('cancelled', 'N')->whereBetween('doc_date', [$startDate, $endDate]);

        // 1. Total Gross Sales (ex-VAT to match SAP LineTotal basis)
        $grossSales = (float) $invoicesQuery->sum(DB::raw('doc_total / 1.15'));
        
        // 2. Total Returns (ex-VAT)
        $totalReturns = (float) $returnsQuery->sum(DB::raw('doc_total / 1.15'));

        // 3. Net Revenue (already ex-VAT)
        $netRevenue = $grossSales - $totalReturns;

        // 4. Transactions (Total Invoices)
        $totalInvoices = $invoicesQuery->count();

        // 5. Return Rate %
        $returnRate = $grossSales > 0 ? ($totalReturns / $grossSales) * 100 : 0;

        // 6. Average Order Value (AOV)
        $aov = $totalInvoices > 0 ? ($netRevenue / $totalInvoices) : 0;

        return [
            Stat::make('صافي الإيرادات (Net Revenue)', number_format($netRevenue, 2) . ' SAR')
                ->description('بدون ضريبة — المبيعات ناقص المرتجعات')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('success'),

            Stat::make('إجمالي العمليات (Transactions)', number_format($totalInvoices))
                ->description('عدد طلبات البيع')
                ->descriptionIcon('heroicon-m-shopping-cart')
                ->color('primary'),

            Stat::make('معدل الاسترجاع (Return Rate)', number_format($returnRate, 2) . '%')
                ->description('نسبة المرتجعات من المبيعات')
                ->descriptionIcon($returnRate > 5 ? 'heroicon-m-arrow-trending-up' : 'heroicon-m-arrow-trending-down')
                ->color($returnRate > 5 ? 'danger' : 'success'),

            Stat::make('متوسط سلة المشتريات (AOV)', number_format($aov, 2) . '  SAR')
                ->description('قيمة سلة العميل الواحد')
                ->descriptionIcon('heroicon-m-currency-dollar')
                ->color('warning'),
        ];
    }
}
