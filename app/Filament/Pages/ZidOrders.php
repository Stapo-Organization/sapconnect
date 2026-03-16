<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;

class ZidOrders extends Page
{
    public static function canAccess(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';
    public static function getNavigationGroup(): ?string
    {
        return __('Zid OMS');
    }

    public function getTitle(): string | \Illuminate\Contracts\Support\Htmlable
    {
        return __('Zid Orders');
    }
    protected static string $view = 'filament.pages.zid-orders';
}
