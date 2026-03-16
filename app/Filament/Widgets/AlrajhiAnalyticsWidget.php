<?php

namespace App\Filament\Widgets;

use App\Models\AlrajhiTransaction;
use App\Models\Automation;
use Carbon\Carbon;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class AlrajhiAnalyticsWidget extends BaseWidget
{
    public static function canView(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    // Make sure this widget spans the full width of the dashboard, below the transfer analytics.
    protected int | string | array $columnSpan = 'full';
    
    // Sort position: prioritize it below StockTransferAnalyticsWidget
    protected static ?int $sort = 3;

    protected function getStats(): array
    {
        $today = Carbon::today();

        // Total count of transactions created today
        $todayCount = AlrajhiTransaction::whereDate('creation_date', $today)->count();
        
        // Total amount for transactions created today
        $todayAmount = AlrajhiTransaction::whereDate('creation_date', $today)->sum('amount');
        
        // Define a unified number formatter
        $formattedAmount = number_format($todayAmount, 2);

        // Fetch last sync automation time for AlRajhi
        $alrajhiDate = Automation::where('code', 'sync_alrajhi_PPTC_V5_PROD')->value('last_run_at');
        $alrajhiDesc = __('Alrajhi sync status') . ($alrajhiDate ? ' - Checked ' . Carbon::parse($alrajhiDate)->diffForHumans() : '');

        return [
            Stat::make(__('Today\'s AlRajhi Transactions'), $todayCount)
                ->description(__('Processed today via API'))
                ->descriptionIcon('heroicon-m-arrows-right-left')
                ->color('primary')
                ->url(\App\Filament\Resources\AlrajhiTransactionResource::getUrl('index')),
                
            Stat::make(__('Today\'s AlRajhi Volume'), "SAR {$formattedAmount}")
                ->description(__('Total monetary value processed today'))
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('success')
                ->url(\App\Filament\Resources\AlrajhiTransactionResource::getUrl('index')),
                
            Stat::make(__('AlRajhi Sync Health'), $alrajhiDate ? Carbon::parse($alrajhiDate)->format('H:i') : 'Never')
                ->description($alrajhiDesc)
                ->descriptionIcon('heroicon-m-arrow-path')
                ->color('info')
                ->url(\App\Filament\Resources\AutomationResource::getUrl('index')),
        ];
    }
}
