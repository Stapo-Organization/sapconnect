<?php

namespace App\Livewire\Admin;

use App\Models\AdminSavedView;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Locked;
use Livewire\Component;

/**
 * The saved-views bar above every resource list table. A view is the list
 * page's URL state (Filament keeps filters/search/sort/tab/grouping in the
 * query string) plus its visible columns, which Filament keeps in session.
 */
class TableViews extends Component
{
    /** Query-string keys a view may carry (Filament ListRecords #[Url] state). */
    public const KEYS = ['tableFilters', 'tableSearch', 'tableSortColumn', 'tableSortDirection', 'activeTab', 'tableGrouping', 'tableGroupingDirection'];

    #[Locked]
    public string $pageClass;

    #[Locked]
    public string $baseUrl;

    #[Locked]
    public ?int $activeId = null;

    public function mount(string $pageClass, string $baseUrl): void
    {
        $this->pageClass = $pageClass;
        $this->baseUrl = $baseUrl;
        $id = (int) request()->query('sv');
        $this->activeId = $id > 0 && $this->views->contains('id', $id) ? $id : null;
    }

    /** @return Collection<int, AdminSavedView> */
    #[Computed]
    public function views(): Collection
    {
        return AdminSavedView::query()
            ->visibleTo((int) Auth::id(), $this->pageClass)
            ->with('user:id,name')
            ->orderBy('position')->orderBy('id')
            ->get();
    }

    public function save(string $name, string $query, array $columns = [], bool $shared = false, bool $pinned = false): void
    {
        $name = trim(mb_substr($name, 0, 80));
        if ($name === '') {
            return;
        }
        $view = AdminSavedView::create([
            'user_id' => Auth::id(),
            'page_class' => $this->pageClass,
            'name' => $name,
            'query' => self::cleanQuery($query),
            'columns' => self::cleanColumns($columns) ?: null,
            'is_shared' => $shared,
            'is_pinned' => $pinned,
            'position' => (int) $this->views->max('position') + 1,
        ]);
        $this->redirect($view->url());
    }

    public function open(int $id): void
    {
        $view = $this->views->firstWhere('id', $id);
        if (! $view) {
            return;
        }
        if ($view->columns) {
            session()->put('tables.' . md5($this->pageClass) . '_toggled_columns', $view->columns);
        }
        $this->redirect($view->url());
    }

    public function openAll(): void
    {
        $this->redirect($this->baseUrl);
    }

    /** Overwrite a view with the table's current state. */
    public function overwrite(int $id, string $query, array $columns = []): void
    {
        $view = $this->mine($id);
        if (! $view) {
            return;
        }
        $view->update(['query' => self::cleanQuery($query), 'columns' => self::cleanColumns($columns) ?: $view->columns]);
        $this->redirect($view->url());
    }

    public function rename(int $id, string $name): void
    {
        $name = trim(mb_substr($name, 0, 80));
        if ($name !== '' && ($view = $this->mine($id))) {
            $view->update(['name' => $name]);
            unset($this->views);
        }
    }

    public function togglePin(int $id): void
    {
        if ($view = $this->mine($id)) {
            $view->update(['is_pinned' => ! $view->is_pinned]);
            unset($this->views);
        }
    }

    public function toggleShare(int $id): void
    {
        if ($view = $this->mine($id)) {
            $view->update(['is_shared' => ! $view->is_shared]);
            unset($this->views);
        }
    }

    public function delete(int $id): void
    {
        if ($view = $this->mine($id)) {
            $view->delete();
            if ($this->activeId === $id) {
                $this->redirect($this->baseUrl);

                return;
            }
            unset($this->views);
        }
    }

    private function mine(int $id): ?AdminSavedView
    {
        $view = $this->views->firstWhere('id', $id);

        return $view && (int) $view->user_id === (int) Auth::id() ? $view : null;
    }

    /** Keep only Filament's list-state keys; drop paging and our own marker. */
    public static function cleanQuery(string $query): string
    {
        parse_str(ltrim($query, '?'), $params);
        $params = array_intersect_key($params, array_flip(self::KEYS));

        return http_build_query(array_filter($params, fn ($v) => $v !== '' && $v !== null && $v !== []));
    }

    /** @return array<string, mixed> nested column-name => bool */
    public static function cleanColumns(array $columns): array
    {
        $out = [];
        foreach ($columns as $key => $value) {
            if (! is_string($key) || strlen($key) > 120) {
                continue;
            }
            $out[$key] = is_array($value) ? self::cleanColumns($value) : (bool) $value;
        }

        return $out;
    }

    public function render()
    {
        return view('livewire.admin.table-views', [
            'me' => (int) Auth::id(),
        ]);
    }
}
