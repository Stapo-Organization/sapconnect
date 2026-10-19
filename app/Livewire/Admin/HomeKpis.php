<?php

namespace App\Livewire\Admin;

use App\Filament\RetailWidgets\RetailExecutiveStatsWidget;

/**
 * Today's retail KPIs on the admin home: the same numbers as the Retail
 * dashboard, refreshed every two minutes instead of every five seconds.
 */
class HomeKpis extends RetailExecutiveStatsWidget
{
    protected static ?string $pollingInterval = '120s';
}
