<?php

namespace App\Filament\Pages;

use App\Support\AdminShell;
use Filament\Pages\Dashboard as BaseDashboard;
use Illuminate\Contracts\Support\Htmlable;

/** The previous dashboard: every registered widget, unchanged. */
class Insights extends BaseDashboard
{
    protected static string $routePath = 'insights';

    protected static ?string $slug = 'insights';

    protected static ?string $navigationIcon = 'heroicon-o-chart-bar-square';

    protected static ?int $navigationSort = -9;

    public static function getNavigationLabel(): string
    {
        return AdminShell::t(['المؤشرات', 'Insights']);
    }

    public function getTitle(): string|Htmlable
    {
        return AdminShell::t(['المؤشرات', 'Insights']);
    }
}
