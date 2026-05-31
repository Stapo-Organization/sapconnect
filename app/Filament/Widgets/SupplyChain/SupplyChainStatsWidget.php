<?php

namespace App\Filament\Widgets\SupplyChain;

use App\Models\PaymentAlert;
use App\Models\PurchaseOrder;
use App\Models\Shipment;
use App\Models\Supplier;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class SupplyChainStatsWidget extends StatsOverviewWidget
{
    protected static ?string $pollingInterval = '30s';

    protected function getStats(): array
    {
        $activePOs = PurchaseOrder::where('sync_status', '!=', 'synced')
            ->orWhereNull('sync_status')
            ->count();

        $activeShipments = Shipment::whereIn('status', ['scheduled', 'shipped', 'arrived_port'])
            ->count();

        $pendingPayments = PaymentAlert::where('status', 'pending')->sum('due_amount');

        $expiringContracts = Supplier::whereNotNull('end_date')
            ->where('end_date', '<=', now()->addDays(30))
            ->where('end_date', '>=', now())
            ->count();

        return [
            Stat::make('Active Purchase Orders', $activePOs)
                ->description('Orders not yet synced with SAP')
                ->descriptionIcon('heroicon-m-shopping-cart')
                ->color('primary'),

            Stat::make('Active Shipments', $activeShipments)
                ->description('In transit or awaiting delivery')
                ->descriptionIcon('heroicon-m-truck')
                ->color('info'),

            Stat::make('Pending Payments', number_format($pendingPayments, 2) . ' SAR')
                ->description('Due payments awaiting processing')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color($pendingPayments > 0 ? 'warning' : 'success'),

            Stat::make('Expiring Contracts', $expiringContracts)
                ->description('Within next 30 days')
                ->descriptionIcon('heroicon-m-exclamation-triangle')
                ->color($expiringContracts > 0 ? 'danger' : 'success'),
        ];
    }
}
