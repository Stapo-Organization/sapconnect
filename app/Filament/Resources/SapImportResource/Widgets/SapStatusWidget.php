<?php

namespace App\Filament\Resources\SapImportResource\Widgets;

use Filament\Widgets\Widget;

class SapStatusWidget extends Widget
{
    protected static string $view = 'filament.resources.sap-import-resource.widgets.sap-status-widget';

    // Ensure full width usage so it doesn't mess up grid too much (though it's fixed pos)
    protected int|string|array $columnSpan = 'full';

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getViewData(): array
    {
        $db = session('sap_company_db', config('sap.company_db'));
        $isProd = $db === 'PPTC_V5_PROD';
        $color = $isProd ? 'bg-green-600' : 'bg-orange-500';

        return [
            'db' => $db,
            'isProd' => $isProd,
            'color' => $color,
        ];
    }
}
