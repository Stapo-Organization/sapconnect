<?php

namespace App\Filament\Pages;

use App\Support\AdminShell;
use App\Support\BranchBoard;
use Filament\Pages\Page;
use Illuminate\Contracts\Support\Htmlable;
use Livewire\Attributes\Url;

/**
 * «الفروع» — every selling branch ranked for a period, each row opening the
 * branch's full picture (BranchDetail). Same numbers as the owner app.
 */
class Branches extends Page
{
    protected static string $view = 'filament.pages.branches';

    protected static ?string $slug = 'branches';

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';

    protected static ?int $navigationSort = 0;

    #[Url]
    public string $period = 'month';

    #[Url]
    public string $sort = 'net';

    public static function canAccess(): bool
    {
        return RetailDashboard::canAccess();
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Retail');
    }

    public static function getNavigationLabel(): string
    {
        return AdminShell::t(['الفروع', 'Branches']);
    }

    /** Stays highlighted on a branch's detail page too. */
    public static function getNavigationItemActiveRoutePattern(): string
    {
        return 'filament.admin.pages.branches*';
    }

    public function getTitle(): string|Htmlable
    {
        return AdminShell::t(['الفروع', 'Branches']);
    }

    public function getHeading(): string|Htmlable
    {
        return '';
    }

    public function setPeriod(string $period): void
    {
        $this->period = BranchBoard::period($period);
    }

    public function sortBy(string $key): void
    {
        $this->sort = in_array($key, ['net', 'profit', 'invoices', 'aov', 'returns', 'score', 'bleeding', 'trapped', 'ops_total', 'name'], true) ? $key : 'net';
    }

    /** @return array<string, mixed> */
    public function board(): array
    {
        $data = app(BranchBoard::class)->network(BranchBoard::period($this->period));
        $rows = collect($data['rows']);
        $rows = $this->sort === 'name'
            ? $rows->sortBy('name')
            : $rows->sortByDesc(fn ($r) => $r[$this->sort] ?? -INF);
        $data['rows'] = $rows->values()->all();

        return $data;
    }
}
