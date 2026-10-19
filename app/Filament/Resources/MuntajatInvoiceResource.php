<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MuntajatInvoiceResource\Pages;
use App\Models\MuntajatCustomer;
use App\Models\MuntajatInvoice;
use App\Services\ShipGo\MuntajatSapService;
use App\Services\ShipGo\ShipGoSapService;

/**
 * Muntajat → Muntajat Invoices: the ShipGo Invoices screen applied to the main
 * company (PPTC_V5_PROD). The retail cash register (C0000001) is excluded.
 */
class MuntajatInvoiceResource extends ShipGoInvoiceResource
{
    protected static ?string $model = MuntajatInvoice::class;
    protected static ?string $slug = 'muntajat-invoices';

    public static function getNavigationGroup(): ?string { return __('Muntajat'); }
    public static function getNavigationLabel(): string { return __('Muntajat Invoices'); }
    public static function getModelLabel(): string { return __('Muntajat Invoice'); }
    public static function getPluralModelLabel(): string { return __('Muntajat Invoices'); }

    public static function sapService(): ShipGoSapService
    {
        return app(MuntajatSapService::class);
    }

    public static function pdfRouteName(): string
    {
        return 'muntajat.invoices.pdf';
    }

    public static function customerModel(): string
    {
        return MuntajatCustomer::class;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMuntajatInvoices::route('/'),
            'view'  => Pages\ViewMuntajatInvoice::route('/{record}'),
        ];
    }
}
