<?php

namespace App\Providers\Filament;

use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Pages;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Filament\Widgets;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Session\Middleware\AuthenticateSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\ChartWidget;
use Filament\Widgets\TableWidget;

class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login(\App\Filament\Pages\Auth\Login::class)
            ->profile(\App\Filament\Pages\Auth\EditProfile::class)
            ->brandName('Muntajat Automation Platform')
            ->colors([
                'primary' => Color::Amber,
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->pages([
                Pages\Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\\Filament\\Widgets')
            ->discoverWidgets(in: app_path('Filament/RetailWidgets'), for: 'App\\Filament\\RetailWidgets')
            ->discoverWidgets(in: app_path('Filament/Widgets/SupplyChain'), for: 'App\\Filament\\Widgets\\SupplyChain')
            ->widgets([
                Widgets\AccountWidget::class,
                \App\Filament\Widgets\DatabaseStatusWidget::class,
                Widgets\AccountWidget::class,
                \App\Filament\Widgets\TopLevelMetricsWidget::class,
                \App\Filament\Widgets\StockTransferAnalyticsWidget::class,
                \App\Filament\Widgets\AlrajhiAnalyticsWidget::class,
                \App\Filament\Widgets\TransferStatusDonutChart::class,
                \App\Filament\Widgets\MonthToDateRevenueChart::class,
                \App\Filament\Widgets\PendingTransfersTable::class,
                \App\Filament\Widgets\AutomationHealthLogTable::class,
                // Supply Chain Widgets
                \App\Filament\Widgets\SupplyChain\SupplyChainStatsWidget::class,
                \App\Filament\Widgets\SupplyChain\ShipmentStatusChart::class,
                \App\Filament\Widgets\SupplyChain\PaymentDueTimeline::class,
                \App\Filament\Widgets\SupplyChain\SupplierPerformanceChart::class,
                // Removed BranchManagerStats and LatestBranchTransfers as requested by new full admin dashboard
            ])
            ->navigationItems([
                \Filament\Navigation\NavigationItem::make('API Doc (Developer)')
                    ->url('/docs/api', shouldOpenInNewTab: true)
                    ->icon('heroicon-o-book-open')
                    ->group('System')
                    ->sort(99)
                    ->visible(fn(): bool => !auth()->user()->hasAnyRole(['Branch Manager', 'Stakeholder'])),
            ])
            ->font('Cairo')
            ->renderHook(
                \Filament\View\PanelsRenderHook::GLOBAL_SEARCH_AFTER,
                fn(): string => \Illuminate\Support\Facades\Blade::render('
                    <div class="flex gap-2">
                        @livewire(\App\Livewire\LanguageSwitcher::class)
                    </div>
                ')
            )
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                \App\Http\Middleware\SetLocale::class,
                AuthenticateSession::class, // Laravel 11 specific? No, standard class
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ]);
    }
}
