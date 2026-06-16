<?php

namespace App\Filament\Pages;

use App\Filament\Widgets\ZooboxiClearanceWidget;
use App\Filament\Widgets\ZooboxiInventoryStatsWidget;
use App\Filament\Widgets\ZooboxiReorderWidget;
use Filament\Pages\Dashboard;

/**
 * Owner-facing dashboard for the Zooboxi inventory intelligence: the 57M-SAR clearance
 * opportunity (channel-safe) and the stockout-driven reorder list. Reads the DB-only
 * intelligence tables — no SAP calls.
 */
class ZooboxiIntelligence extends Dashboard
{
    protected static ?string $slug = 'zooboxi-intelligence';
    protected static string $routePath = 'zooboxi-intelligence'; // Dashboard subclasses need an explicit route path
    protected static ?string $navigationIcon = 'heroicon-o-sparkles';
    protected static ?string $navigationLabel = 'ذكاء المخزون والتصريف';
    protected static ?int $navigationSort = 1;

    public function getTitle(): string
    {
        return 'ذكاء المخزون والتصريف (Zooboxi)';
    }

    public function getSubheading(): ?string
    {
        return 'فرصة التصريف الآمن لقناة الجملة + المنتجات المقطوعة التي تحتاج إعادة طلب';
    }

    public function getWidgets(): array
    {
        return [
            ZooboxiInventoryStatsWidget::class,
            ZooboxiClearanceWidget::class,
            ZooboxiReorderWidget::class,
        ];
    }

    public function getColumns(): int|array
    {
        return 1;
    }

    // Restricted to Super Admin only (gates both the route and the nav item).
    public static function canAccess(): bool
    {
        return auth()->check() && auth()->user()->hasRole('Super Admin');
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canAccess();
    }
}
