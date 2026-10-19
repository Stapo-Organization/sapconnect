<?php

namespace App\Filament\Pages;

use App\Models\AdminSavedView;
use App\Models\Automation;
use App\Support\AdminShell;
use App\Support\SavedViewCounter;
use Filament\Pages\Dashboard as BaseDashboard;
use Illuminate\Contracts\Support\Htmlable;
use Illuminate\Support\Carbon;
use Throwable;

/**
 * The admin home («مساحة العمل»): a command box, the user's pinned saved
 * views with live counts, and integration health. The old widget wall lives
 * on the Insights page. Keeps the class name so the route stays
 * filament.admin.pages.dashboard.
 */
class Dashboard extends BaseDashboard
{
    protected static string $view = 'filament.pages.home';

    protected static ?string $navigationIcon = 'heroicon-o-home';

    protected static ?int $navigationSort = -10;

    /** @var array<int, int|null> view id => record count, filled after first paint */
    public array $counts = [];

    public bool $countsLoaded = false;

    public static function getNavigationLabel(): string
    {
        return AdminShell::t(['الرئيسية', 'Home']);
    }

    public function getTitle(): string|Htmlable
    {
        return AdminShell::t(['الرئيسية', 'Home']);
    }

    public function getHeading(): string|Htmlable
    {
        return '';
    }

    public function loadCounts(): void
    {
        foreach ($this->pinned() as $view) {
            $this->counts[$view->id] = SavedViewCounter::count($view);
        }
        $this->countsLoaded = true;
    }

    /** @return array<int, AdminSavedView> */
    public function pinned(): array
    {
        return AdminShell::pinnedViews();
    }

    /** @return array<int, array{label: string, url: string}> quick links the user can open */
    public function shortcuts(): array
    {
        $prefer = ['branches', 'shipments', 'purchase-orders', 'container-tracking', 'warehouse-item-stocks', 'zooboxi-orders', 'payment-alerts', 'retail-dashboard', 'products', 'muntajat-customers', 'ship-go-customers'];
        $screens = collect(AdminShell::paletteScreens(filament()->getNavigation()))
            ->keyBy(fn ($s) => AdminShell::pathKey($s['url']));

        return collect($prefer)->map(fn ($p) => $screens->get($p))->filter()->take(6)
            ->map(fn ($s) => ['label' => $s['label'], 'url' => $s['url'], 'where' => $s['where']])->values()->all();
    }

    /** @return array<int, array<string, mixed>> active automations, problems first */
    public function health(): array
    {
        try {
            if (! \App\Filament\Resources\AutomationResource::canViewAny()) {
                return [];
            }
            return Automation::query()->where('is_active', true)->get()
                ->map(function (Automation $a) {
                    $at = $a->last_run_at ? Carbon::parse($a->last_run_at) : null;
                    $failed = $a->last_run_status === 'failed';

                    return [
                        'name' => $a->name,
                        'command' => $a->command_signature,
                        'when' => $at?->locale(app()->getLocale())->diffForHumans(short: true) ?? AdminShell::t(['لم تعمل بعد', 'never ran']),
                        'tone' => $failed ? 'danger' : ($at === null ? 'muted' : 'ok'),
                        'rank' => $failed ? 0 : ($at === null ? 1 : 2),
                        'ts' => $at?->timestamp ?? 0,
                    ];
                })
                ->sortBy([['rank', 'asc'], ['ts', 'desc']])
                ->take(6)->values()->all();
        } catch (Throwable) {
            return [];
        }
    }

    public function automationsUrl(): ?string
    {
        try {
            return \App\Filament\Resources\AutomationResource::getUrl('index');
        } catch (Throwable) {
            return null;
        }
    }

    public function showKpis(): bool
    {
        try {
            return \App\Filament\Pages\RetailDashboard::canAccess();
        } catch (Throwable) {
            return false;
        }
    }

    public function greeting(): string
    {
        $hour = (int) now('Asia/Riyadh')->format('G');

        return $hour < 12 ? AdminShell::t(['صباح الخير', 'Good morning']) : AdminShell::t(['مساء الخير', 'Good evening']);
    }
}
