<?php

namespace App\Filament\Pages;

use App\Models\ContainerShipment;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Artisan;

/**
 * Read-only ocean-freight board backed by the local Traqo snapshot
 * (container_shipments). Pure display: refreshNow() only re-runs the read-only
 * sync command — nothing is ever written back to Traqo.
 *
 * The default Filament header is suppressed (getHeading/'') in favour of the
 * custom ocean banner rendered inside the view.
 */
class ContainerTracking extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-globe-alt';
    protected static ?string $navigationLabel = 'تتبّع الحاويات';
    protected static ?int $navigationSort = 3;
    protected static string $view = 'filament.pages.container-tracking';

    /** Selected shipment `name` for the detail drawer (null = closed). */
    public ?string $selected = null;

    /** Active state filter chip: all|in_transit|overdue|arriving|pending|delivered. */
    public string $filter = 'all';

    /** Free-text search over number / carrier / lane. */
    public string $search = '';

    /** Sort mode: urgency | eta | added. */
    public string $sort = 'urgency';

    /** When true, the list groups containers that travel together into one shipment. */
    public bool $groupByShipment = false;

    private ?Collection $cache = null;

    public static function getNavigationGroup(): ?string
    {
        return 'Supply Chain';
    }

    public function getTitle(): string
    {
        return 'تتبّع الحاويات الواردة';
    }

    // Suppress the default Filament page header — the ocean banner is the hero.
    public function getHeading(): string
    {
        return '';
    }

    public function getSubheading(): ?string
    {
        return null;
    }

    /** Re-run the read-only sync; wired to the banner button. */
    public function refreshNow(): void
    {
        Artisan::call('traqo:sync-shipments');
        $this->cache = null;
        Notification::make()->title('تم تحديث الشحنات من Traqo')->success()->send();
    }

    /** Push Traqo ETD/ETA into the Google Sheet ledger; wired to the banner button. */
    public function pushToSheet(): void
    {
        Artisan::call('traqo:push-sheet');
        $out = trim(Artisan::output());
        if (str_contains($out, 'success')) {
            Notification::make()->title('تم تحديث Google Sheet')->body($out)->success()->send();
        } else {
            Notification::make()->title('تعذّر تحديث Google Sheet')->body($out ?: 'راجع السجل')->danger()->send();
        }
    }

    /**
     * Export the CURRENTLY VISIBLE shipments (after filter + search + sort) to a
     * UTF-8 CSV that opens cleanly in Excel — same dependency-free pattern used
     * elsewhere in the panel (BOM + fputcsv, no Excel library).
     */
    public function export(): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $rows = $this->visibleShipments();
        $filename = 'containers_' . now()->format('Y_m_d_Hi') . '.csv';

        return response()->streamDownload(function () use ($rows) {
            $h = fopen('php://output', 'w');
            fwrite($h, "\xEF\xBB\xBF"); // UTF-8 BOM → Excel renders Arabic correctly
            fputcsv($h, [
                'الحالة', 'رقم الحاوية', 'رقم الشحنة', 'النوع', 'الناقل',
                'المنشأ', 'الوجهة', 'تاريخ الشحن', 'الوصول المتوقّع', 'المتبقّي (يوم)', 'متأخرة',
                'التقدّم %', 'الباخرة', 'IMO', 'رابط التتبّع',
            ]);
            foreach ($rows as $s) {
                fputcsv($h, [
                    $s->stateLabel(),
                    $s->reference_number,
                    $s->name,
                    $s->shipment_type,
                    $s->sealine_name ?: $s->sealine,
                    $s->origin,
                    $s->destination,
                    $s->shipDate()?->format('Y-m-d'),
                    $s->eta?->format('Y-m-d H:i'),
                    $s->remaining_days,
                    $s->isOverdue() ? 'نعم' : '',
                    $s->progressPercent(),
                    optional($s->currentVessel())['vessel'] ?? '',
                    optional($s->currentVessel())['imo'] ?? '',
                    $s->shipment_public_url,
                ]);
            }
            fclose($h);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    /** All shipments (memoised per request). */
    public function shipments(): Collection
    {
        return $this->cache ??= ContainerShipment::all();
    }

    /** Shipments after filter + search + sort. */
    public function visibleShipments(): Collection
    {
        $items = $this->shipments();

        if ($this->filter !== 'all') {
            $items = $items->filter(fn (ContainerShipment $s) => $s->state() === $this->filter);
        }

        $q = trim($this->search);
        if ($q !== '') {
            $needle = mb_strtolower($q);
            $items = $items->filter(function (ContainerShipment $s) use ($needle) {
                $hay = mb_strtolower(implode(' ', array_filter([
                    $s->reference_number, $s->name, $s->sealine_name, $s->sealine, $s->origin, $s->destination,
                ])));
                return str_contains($hay, $needle);
            });
        }

        $items = match ($this->sort) {
            'eta'   => $items->sortBy(fn (ContainerShipment $s) => $s->remaining_days ?? PHP_INT_MAX),
            'added' => $items->sortByDesc('created_at'),
            default => $items->sortBy(fn (ContainerShipment $s) => $this->urgencyRank($s)),
        };

        return $items->values();
    }

    /** Composite sort key: state priority then soonest. */
    private function urgencyRank(ContainerShipment $s): array
    {
        $order = ['overdue' => 0, 'arriving' => 1, 'in_transit' => 2, 'delivered' => 3, 'pending' => 4];
        return [$order[$s->state()] ?? 9, $s->remaining_days ?? PHP_INT_MAX];
    }

    /** Overdue + arriving-soon, most urgent first — feeds the "تحتاج انتباهك" strip. */
    public function attentionItems(): Collection
    {
        return $this->shipments()
            ->filter(fn (ContainerShipment $s) => $s->needsAttention())
            ->sortBy(fn (ContainerShipment $s) => $s->remaining_days ?? PHP_INT_MAX)
            ->values();
    }

    /** Counts per state for the badge row. */
    public function counts(): array
    {
        $counts = ['all' => 0, 'overdue' => 0, 'arriving' => 0, 'in_transit' => 0, 'pending' => 0, 'delivered' => 0];
        foreach ($this->shipments() as $s) {
            $counts['all']++;
            $counts[$s->state()]++;
        }
        return $counts;
    }

    /** Headline numbers for the ocean banner. */
    public function summary(): array
    {
        $all = $this->shipments();
        $nearest = $all
            ->filter(fn (ContainerShipment $s) => $s->isInTransit() && $s->remaining_days !== null && $s->remaining_days >= 0)
            ->sortBy('remaining_days')
            ->first();

        $nearestLabel = '—';
        if ($nearest) {
            $r = $nearest->remaining_days;
            $nearestLabel = $r === 0 ? 'اليوم' : ($r === 1 ? 'غداً' : "بعد {$r} أيام");
        }

        return [
            'total'    => $all->count(),
            'overdue'  => $all->filter(fn (ContainerShipment $s) => $s->isOverdue())->count(),
            'arriving' => $all->filter(fn (ContainerShipment $s) => $s->needsAttention() && !$s->isOverdue())->count(),
            'nearest'  => $nearestLabel,
        ];
    }

    /** Visible shipments grouped by derived physical-shipment key. */
    public function shipmentGroups(): Collection
    {
        return $this->visibleShipments()->groupBy(fn (ContainerShipment $s) => $s->shipmentGroupKey());
    }

    /** Other containers travelling in the same shipment as $s (for the drawer). */
    public function siblingsOf(ContainerShipment $s): Collection
    {
        $key = $s->shipmentGroupKey();
        if (str_starts_with($key, 'solo:')) {
            return collect();
        }
        return $this->shipments()
            ->filter(fn (ContainerShipment $x) => $x->shipmentGroupKey() === $key && $x->name !== $s->name)
            ->values();
    }

    public function selectedShipment(): ?ContainerShipment
    {
        return $this->selected ? $this->shipments()->firstWhere('name', $this->selected) : null;
    }

    public function lastSyncedLabel(): ?string
    {
        $latest = $this->shipments()->max('fetched_at');
        return $latest ? Carbon::parse($latest)->diffForHumans() : null;
    }
}
