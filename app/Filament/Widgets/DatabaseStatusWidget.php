<?php

namespace App\Filament\Widgets;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class DatabaseStatusWidget extends BaseWidget
{
    // High priority to sit at the top
    protected static ?int $sort = -3;

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getStats(): array
    {
        $db = 'PPTC_V5_PROD';
        $username = config("sap.databases.{$db}.username", config('sap.username'));

        return [
            Stat::make(__('Current Database'), __('Production'))
                ->description(__("Connected to Live SAP Data") . " ($db)\n" . __('User:') . " $username")
                ->descriptionIcon('heroicon-m-check-circle')
                ->color('success')
                ->chart([7, 7, 7, 7, 7]), // Cosmetic chart
        ];
    }
}
