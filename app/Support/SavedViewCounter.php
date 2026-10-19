<?php

namespace App\Support;

use App\Livewire\Admin\TableViews;
use App\Models\AdminSavedView;
use Illuminate\Support\Facades\Cache;
use Throwable;

/**
 * Counts the records a saved view shows, by booting its list page off-screen
 * with the view's URL state and asking Filament for the filtered query, so the
 * number always matches the table exactly (same filters, tab, search, scopes).
 */
class SavedViewCounter
{
    public static function count(AdminSavedView $view): ?int
    {
        $key = 'admin-sv-count:' . $view->id . ':' . md5((string) $view->query . $view->updated_at);

        return Cache::remember($key, now()->addMinutes(5), function () use ($view): ?int {
            try {
                $class = $view->page_class;
                if (! class_exists($class) || ! $class::getResource()::canViewAny()) {
                    return null;
                }
                $page = app('livewire')->new($class);
                $page->mount();
                parse_str((string) $view->query, $state);
                foreach (TableViews::KEYS as $prop) {
                    if (array_key_exists($prop, $state) && property_exists($page, $prop)) {
                        $page->{$prop} = $state[$prop];
                    }
                }
                $page->mountInteractsWithTable();
                $page->bootedInteractsWithTable();

                return $page->getFilteredTableQuery()->count();
            } catch (Throwable $e) {
                report($e);

                return null;
            }
        });
    }

    /** @return array<int, string> short human summary of what the view narrows */
    public static function summary(AdminSavedView $view): array
    {
        parse_str((string) $view->query, $state);
        $t = fn (string $ar, string $en) => AdminShell::t([$ar, $en]);
        $out = [];
        $filters = collect($state['tableFilters'] ?? [])->filter(fn ($f) => collect(is_array($f) ? $f : [$f])->flatten()->filter(fn ($v) => filled($v) && $v !== 'false' && $v !== '0')->isNotEmpty())->count();
        if ($filters) {
            $out[] = $filters . ' ' . ($filters === 1 ? $t('فلتر', 'filter') : $t('فلاتر', 'filters'));
        }
        if (filled($state['tableSearch'] ?? null)) {
            $out[] = $t('بحث', 'search') . ': ' . mb_strimwidth((string) $state['tableSearch'], 0, 18, '…');
        }
        if (filled($state['activeTab'] ?? null)) {
            $out[] = $t('تبويب', 'tab') . ': ' . $state['activeTab'];
        }
        if (filled($state['tableSortColumn'] ?? null)) {
            $out[] = $t('مرتّب', 'sorted');
        }
        if ($view->is_shared) {
            $out[] = $t('مشترك', 'shared');
        }

        return $out;
    }
}
