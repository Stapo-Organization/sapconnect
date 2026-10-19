<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MuntajatCustomerResource\Pages;
use App\Models\MuntajatCustomer;
use App\Services\ShipGo\MuntajatSapService;
use App\Services\ShipGo\ShipGoSapService;

/**
 * Muntajat → Muntajat Customers: the ShipGo Customers screen applied to the
 * main company (PPTC_V5_PROD). Read-only; statements come from the ledger.
 */
class MuntajatCustomerResource extends ShipGoCustomerResource
{
    protected static ?string $model = MuntajatCustomer::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';
    protected static ?string $slug = 'muntajat-customers';

    public static function getNavigationGroup(): ?string { return __('Muntajat'); }
    public static function getNavigationLabel(): string { return __('Muntajat Customers'); }
    public static function getModelLabel(): string { return __('Muntajat Customer'); }
    public static function getPluralModelLabel(): string { return __('Muntajat Customers'); }

    public static function sapService(): ShipGoSapService
    {
        return app(MuntajatSapService::class);
    }

    public static function statementRouteName(): string
    {
        return 'muntajat.customers.statement';
    }

    public static function invoiceResource(): string
    {
        return MuntajatInvoiceResource::class;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMuntajatCustomers::route('/'),
            'view'  => Pages\ViewMuntajatCustomer::route('/{record}'),
        ];
    }
}
