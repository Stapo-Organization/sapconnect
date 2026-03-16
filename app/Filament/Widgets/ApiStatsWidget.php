<?php

namespace App\Filament\Widgets;

use App\Models\ApiLog;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class ApiStatsWidget extends BaseWidget
{
    protected static ?int $sort = 1;

    // Auto refresh
    protected static ?string $pollingInterval = '10s';

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getStats(): array
    {
        $query = ApiLog::query();

        // Scope to user if Operator
        $user = auth()->user();
        if ($user && $user->hasRole('Operator')) {
            $query->where('user_id', $user->id);
        }

        $totalToday = (clone $query)->whereDate('created_at', today())->count();
        $errorsToday = (clone $query)->whereDate('created_at', today())
            ->where('status_code', '>=', 400)
            ->count();

        $successRate = $totalToday > 0
            ? round((($totalToday - $errorsToday) / $totalToday) * 100, 1)
            : 100;

        return [
            Stat::make(__('Total API Requests (Today)'), $totalToday)
                ->description(__('Incoming API Traffic'))
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('success'),

            Stat::make(__('Failed Requests (Today)'), $errorsToday)
                ->description(__('4xx or 5xx Errors'))
                ->descriptionIcon('heroicon-m-exclamation-triangle')
                ->color($errorsToday > 0 ? 'danger' : 'gray'),

            Stat::make(__('Success Rate'), $successRate . '%')
                ->description(__('Reliability'))
                ->color('success'),
        ];
    }
}
