<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ContainerShipment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * ContainerTracking (تتبّع الحاويات) — owner-facing ocean-freight board for the
 * app. A pure read from our local Traqo mirror (`container_shipments`); it makes
 * NO calls to Traqo, so it never consumes a tracking slot. The daily
 * `traqo:sync-shipments` command keeps the mirror fresh.
 *
 *   GET /container-tracking            → summary + ordered list (filters: state, search, sort)
 *   GET /container-tracking/{id}       → one shipment with events, vessel, ETA history, siblings
 *
 * Lifecycle/lateness is DERIVED on the model (isOverdue recomputes from
 * remaining_days because Traqo's is_delayed flag is unreliable); we just surface
 * the already-computed accessors so the app never re-implements that logic.
 */
class ContainerTrackingController extends Controller
{
    /** Urgency ordering: overdue first, pending last (mirrors the Filament board). */
    private const STATE_RANK = [
        'overdue'    => 0,
        'arriving'   => 1,
        'in_transit' => 2,
        'delivered'  => 3,
        'pending'    => 4,
    ];

    public function index(Request $request): JsonResponse
    {
        $all = ContainerShipment::query()->where('is_active', true)->get();

        $counts = ['all' => 0, 'overdue' => 0, 'arriving' => 0, 'in_transit' => 0, 'pending' => 0, 'delivered' => 0];
        foreach ($all as $s) {
            $counts['all']++;
            $counts[$s->state()]++;
        }

        $visible = $this->filtered($all, $request);
        $visible = $this->sorted($visible, $request->query('sort', 'urgency'));

        // Nearest upcoming arrival, for the hero line.
        $nearest = $all
            ->filter(fn (ContainerShipment $s) => $s->isInTransit() && $s->remaining_days !== null && $s->remaining_days >= 0)
            ->sortBy('remaining_days')
            ->first();

        $lastSynced = $all->max('remote_synced_at') ?? $all->max('fetched_at');

        return response()->json([
            'summary' => [
                'counts'         => $counts,
                'attention'      => $all->filter(fn (ContainerShipment $s) => $s->needsAttention())->count(),
                'nearest_label'  => $nearest?->remainingLabel(),
                'nearest_lane'   => $nearest ? ($nearest->originShort() . ' → ' . $nearest->destinationShort()) : null,
                'last_synced_at' => $lastSynced?->toIso8601String(),
            ],
            'containers' => $visible->map(fn (ContainerShipment $s) => $this->card($s))->values(),
        ]);
    }

    public function show(int $id): JsonResponse
    {
        $s = ContainerShipment::findOrFail($id);

        $siblings = ContainerShipment::query()
            ->where('is_active', true)
            ->where('id', '!=', $s->id)
            ->get()
            ->filter(fn (ContainerShipment $o) => $o->shipmentGroupKey() === $s->shipmentGroupKey())
            ->map(fn (ContainerShipment $o) => [
                'id'        => $o->id,
                'reference' => $o->reference_number,
                'state'     => $o->state(),
            ])
            ->values();

        $vessel = $s->currentVessel();

        return response()->json([
            'container' => array_merge($this->card($s), [
                'total_days'       => $s->total_days,
                'latitude'         => $s->latitude,
                'longitude'        => $s->longitude,
                'public_url'       => $s->shipment_public_url,
                'detail_fetched_at' => $s->detail_fetched_at?->toIso8601String(),
                'current_vessel'   => $vessel ? [
                    'name' => $vessel['name'] ?? ($vessel['vessel'] ?? null),
                    'imo'  => $vessel['imo'] ?? null,
                    'mmsi' => $vessel['mmsi'] ?? null,
                ] : null,
                'events'      => $this->events($s),
                'eta_history' => $this->etaHistory($s),
                'siblings'    => $siblings,
            ]),
        ]);
    }

    /* -------------------- shaping -------------------- */

    /** The list-row / detail-header payload for one shipment. */
    private function card(ContainerShipment $s): array
    {
        return [
            'id'                   => $s->id,
            'name'                 => $s->name,
            'reference'            => $s->reference_number,
            'carrier'              => $s->sealine_name ?: $s->sealine,
            'type'                 => $s->shipment_type,
            'state'                => $s->state(),
            'state_label'          => $s->stateLabel(),
            'state_color'          => $s->stateColor(),
            'origin'               => $s->origin,
            'destination'          => $s->destination,
            'origin_short'         => $s->originShort(),
            'destination_short'    => $s->destinationShort(),
            'origin_flag'          => $s->originFlag(),
            'destination_flag'     => $s->destinationFlag(),
            'eta'                  => $s->eta?->toIso8601String(),
            'ship_date'            => $s->shipDate()?->toIso8601String(),
            'remaining_days'       => $s->remaining_days,
            'remaining_label'      => $s->remainingLabel(),
            'progress_percent'     => $s->progressPercent(),
            'number_of_containers' => (int) $s->number_of_containers,
            'eta_change_count'     => $s->etaChangeCount(),
            'needs_attention'      => $s->needsAttention(),
        ];
    }

    /** Events timeline, newest first, normalised to a stable shape for the app. */
    private function events(ContainerShipment $s): array
    {
        return collect($s->events())
            ->map(fn ($e) => [
                'description' => $e['description'] ?? ($e['event'] ?? ''),
                'location'    => $e['location'] ?? '',
                'country'     => $e['country'] ?? '',
                'date'        => $e['date'] ?? ($e['timestamp'] ?? null),
                'is_actual'   => (bool) ($e['is_actual'] ?? ($e['actual'] ?? true)),
            ])
            ->filter(fn ($e) => $e['description'] !== '' || $e['location'] !== '')
            ->sortByDesc('date')
            ->values()
            ->all();
    }

    private function etaHistory(ContainerShipment $s): array
    {
        return collect($s->detail['eta_history_table'] ?? [])
            ->map(fn ($e) => [
                'eta'  => $e['eta'] ?? null,
                'date' => $e['date'] ?? ($e['changed_at'] ?? null),
            ])
            ->filter(fn ($e) => $e['eta'] !== null)
            ->values()
            ->all();
    }

    private function filtered(Collection $rows, Request $request): Collection
    {
        $state = $request->query('state', 'all');
        if ($state !== 'all' && array_key_exists($state, self::STATE_RANK)) {
            $rows = $rows->filter(fn (ContainerShipment $s) => $s->state() === $state);
        }

        if ($q = trim((string) $request->query('search', ''))) {
            $needle = mb_strtolower($q);
            $rows = $rows->filter(function (ContainerShipment $s) use ($needle) {
                $hay = mb_strtolower(implode(' ', array_filter([
                    $s->reference_number, $s->name, $s->sealine_name, $s->sealine, $s->origin, $s->destination,
                ])));
                return str_contains($hay, $needle);
            });
        }

        return $rows->values();
    }

    private function sorted(Collection $rows, string $sort): Collection
    {
        return match ($sort) {
            'eta'   => $rows->sortBy(fn (ContainerShipment $s) => $s->remaining_days ?? PHP_INT_MAX)->values(),
            'added' => $rows->sortByDesc('created_at')->values(),
            default => $rows->sortBy([
                fn (ContainerShipment $a, ContainerShipment $b) => (self::STATE_RANK[$a->state()] ?? 9) <=> (self::STATE_RANK[$b->state()] ?? 9),
                fn (ContainerShipment $a, ContainerShipment $b) => ($a->remaining_days ?? PHP_INT_MAX) <=> ($b->remaining_days ?? PHP_INT_MAX),
            ])->values(),
        };
    }
}
