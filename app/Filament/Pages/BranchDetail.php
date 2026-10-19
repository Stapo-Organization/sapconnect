<?php

namespace App\Filament\Pages;

use App\Support\AdminShell;
use App\Support\BranchBoard;
use Filament\Pages\Page;
use Illuminate\Contracts\Support\Htmlable;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Url;

/**
 * One branch in full: sales and profit for the period, trend, best sellers,
 * the branch rating and its vitals, lost-sales opportunities, stagnant stock,
 * stock on hand and open operations — each linking to its filtered table.
 */
class BranchDetail extends Page
{
    protected static string $view = 'filament.pages.branch-detail';

    protected static ?string $slug = 'branches/{code}';

    protected static bool $shouldRegisterNavigation = false;

    #[Locked]
    public string $code = '';

    #[Url]
    public string $period = 'month';

    public static function canAccess(): bool
    {
        return RetailDashboard::canAccess();
    }

    public function mount(string $code): void
    {
        $this->code = strtoupper(trim($code));
        abort_unless(app(BranchBoard::class)->branch($this->code, BranchBoard::period($this->period)) !== null, 404);
    }

    public function getTitle(): string|Htmlable
    {
        return $this->data()['name'] ?? $this->code;
    }

    public function getHeading(): string|Htmlable
    {
        return '';
    }

    public function setPeriod(string $period): void
    {
        $this->period = BranchBoard::period($period);
    }

    /** @return array<string, mixed> */
    public function data(): array
    {
        return app(BranchBoard::class)->branch($this->code, BranchBoard::period($this->period)) ?? [];
    }

    public function branchesUrl(): string
    {
        return Branches::getUrl(['period' => $this->period]);
    }

    public static function urlFor(string $code, string $period = 'month'): string
    {
        return static::getUrl(['code' => $code, 'period' => $period]);
    }

    /**
     * Admin table URL narrowed to this branch, or null when the user cannot open it.
     * $filters: filter name => value, where '@' stands for this branch's code.
     */
    public function tableUrl(string $path, array $filters = [], bool $searchCode = false): ?string
    {
        $url = AdminShell::screenUrl($path);
        if (! $url) {
            return null;
        }
        $query = [];
        foreach ($filters as $name => $value) {
            $query['tableFilters'][$name]['value'] = $value === '@' ? $this->code : $value;
        }
        if ($searchCode) {
            $query['tableSearch'] = $this->code;
        }

        return $url . ($query ? '?' . http_build_query($query) : '');
    }
}
