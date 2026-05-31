<?php

namespace App\Filament\Pages;

use Filament\Pages\Dashboard as BaseDashboard;
use Filament\Pages\Dashboard\Concerns\HasFiltersForm;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Form;
use Filament\Forms\Components\Section;
use Carbon\Carbon;

class RetailDashboard extends BaseDashboard
{
    use HasFiltersForm;

    protected static ?string $navigationIcon = 'heroicon-o-presentation-chart-line';
    protected static string $routePath = 'retail-dashboard';
    protected static ?string $slug = 'retail-dashboard';
    protected static ?int $navigationSort = 1;

    public static function getNavigationGroup(): string { return __('Retail'); }
    public function getTitle(): string|\Illuminate\Contracts\Support\Htmlable { return __('Retail Dashboard'); }
    public static function getNavigationLabel(): string { return __('Retail Dashboard'); }

    public static function canAccess(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canAccess();
    }

    public function filtersForm(Form $form): Form
    {
        return $form->schema([
            Section::make()
                ->schema([
                    DatePicker::make('startDate')
                        ->label('Start Date')
                        ->default(Carbon::today()->toDateString())
                        ->native(false),
                    DatePicker::make('endDate')
                        ->label('End Date')
                        ->default(Carbon::today()->toDateString())
                        ->native(false),
                ])
                ->columns(2),
        ]);
    }

    public function getWidgets(): array
    {
        return [
            \App\Filament\RetailWidgets\RetailExecutiveStatsWidget::class,
            \App\Filament\RetailWidgets\StoreSalesWidget::class,
            \App\Filament\RetailWidgets\StorePerformanceChartWidget::class,
            \App\Filament\RetailWidgets\RevenueTimelineChartWidget::class,
            \App\Filament\RetailWidgets\TopSellingProductsWidget::class,
            \App\Filament\RetailWidgets\TopReturnedProductsWidget::class,
        ];
    }
}
