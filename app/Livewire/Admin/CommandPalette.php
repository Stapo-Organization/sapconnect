<?php

namespace App\Livewire\Admin;

use App\Models\AdminSavedView;
use App\Support\AdminSearch;
use App\Support\AdminShell;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Session;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Locked;
use Livewire\Component;
use Throwable;

/**
 * ⌘K palette: screens and saved views are filtered in the browser (instant);
 * records are searched on the server, debounced, through AdminSearch.
 */
class CommandPalette extends Component
{
    public string $q = '';

    /** Screens and views are sent once; filtering them never needs a round trip. */
    #[Locked]
    public array $screens = [];

    #[Locked]
    public array $views = [];

    public function mount(): void
    {
        $this->screens = AdminShell::paletteScreens(filament()->getNavigation());
        $this->views = $this->loadViews();
    }

    /** @return array<int, array<string, mixed>> */
    #[Computed]
    public function records(): array
    {
        return AdminSearch::search($this->q);
    }

    public function toggleLocale(): void
    {
        $target = App::getLocale() === 'ar' ? 'en' : 'ar';
        Session::put('locale', $target);
        $this->redirect(request()->header('Referer') ?: filament()->getHomeUrl());
    }

    /** @return array<int, array<string, string>> */
    private function loadViews(): array
    {
        try {
            return AdminSavedView::query()
                ->where(fn ($q) => $q->where('user_id', Auth::id())->orWhere('is_shared', true))
                ->orderByDesc('is_pinned')->orderBy('name')->limit(60)->get()
                ->map(function (AdminSavedView $v) {
                    $url = $v->url();
                    if ($url === null || ! $v->page_class::getResource()::canViewAny()) {
                        return null;
                    }

                    return [
                        'label' => $v->name,
                        'where' => AdminShell::screenLabel(AdminShell::pathKey($v->baseUrl())) ?? '',
                        'keywords' => $v->name,
                        'url' => $url,
                        'pinned' => $v->is_pinned ? '1' : '',
                    ];
                })->filter()->values()->all();
        } catch (Throwable) {
            return [];
        }
    }

    public function render()
    {
        return view('livewire.admin.command-palette');
    }
}
