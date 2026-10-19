<?php

namespace App\Services\Counting;

use App\Models\InventoryCounting;
use App\Models\InventoryCountingBatch;
use App\Models\InventoryCountingLine;
use App\Models\InventoryCountingSnapshot;
use App\Models\Product;
use App\Models\StoreLocation;
use Carbon\Carbon;
use Illuminate\Support\Collection;

/**
 * The rules of a full (wall-to-wall) count.
 *
 * Rounds: 1 = the zone count, 2 = a blind recount by someone else (or the
 * missing-items sweep), 3 = the supervisor's deciding count. An item's final
 * quantity is the total of its latest round, summed over every shelf.
 *
 * An item goes to recount when its round-1 total differs from the SAP book
 * snapshot by at least RECOUNT_MIN_UNITS and RECOUNT_MIN_PCT. A recount that
 * agrees with the first count or with the book settles it; otherwise the
 * supervisor counts a third time.
 */
class FullCountService
{
    public const RECOUNT_MIN_UNITS = 2;
    public const RECOUNT_MIN_PCT = 0.10;
    public const MISSING_LOCATION = 'MISSING';
    /** Expiry buckets in days from today; anything later is fine. */
    public const EXPIRY_BUCKETS = ['expired' => -1, 'd30' => 30, 'd60' => 60, 'd90' => 90];

    /** item_code => system qty from the snapshot (book at cut-off). */
    public function book(InventoryCounting $c): Collection
    {
        return InventoryCountingSnapshot::where('inventory_counting_id', $c->id)
            ->pluck('system_qty', 'item_code')
            ->map(fn ($v) => (float) $v);
    }

    /** item_code => unit cost: SAP's warehouse average cost, else the product_costs estimate. */
    public function costs(InventoryCounting $c): Collection
    {
        return InventoryCountingSnapshot::where('inventory_counting_id', $c->id)
            ->get(['item_code', 'unit_cost', 'sap_unit_cost'])
            ->mapWithKeys(fn ($s) => [$s->item_code => $s->sap_unit_cost > 0 ? (float) $s->sap_unit_cost : ($s->unit_cost !== null ? (float) $s->unit_cost : null)])
            ->filter(fn ($v) => $v !== null);
    }

    /**
     * The accounting picture: the SAP book valued at SAP cost against what is
     * actually on the shelves (latest round; never found = 0), split into
     * overage, shortage on counted items and items never found, and into what
     * is settled versus still in recount.
     */
    public function valuation(InventoryCounting $c): array
    {
        $book = $this->book($c);
        $items = $this->items($c);
        $snap = InventoryCountingSnapshot::where('inventory_counting_id', $c->id)->get(['item_code', 'unit_cost', 'sap_unit_cost'])->keyBy('item_code');
        $proxy = \Illuminate\Support\Facades\DB::table('product_costs')->whereIn('item_code', $items->keys())->pluck('cost_proxy_sar', 'item_code');
        $v = ['book_value' => 0.0, 'counted_value' => 0.0, 'over' => 0.0, 'short_counted' => 0.0, 'not_found' => 0.0,
            'settled_net' => 0.0, 'pending_net' => 0.0, 'pending_items' => 0, 'items' => 0,
            'sap_cost_items' => 0, 'estimate_items' => 0, 'no_cost_items' => 0, 'no_cost_units' => 0.0, 'top' => [],
            'groups' => array_fill_keys(['match', 'over', 'short'], ['items' => 0, 'units' => 0.0, 'value' => 0.0]), 'lines' => []];
        $rows = [];
        foreach ($book->keys()->merge($items->keys())->unique() as $code) {
            $sys = (float) ($book[$code] ?? 0);
            $it = $items->get($code);
            $final = $it ? (float) self::finalQty($it) : null;
            if ($final === null && $sys <= 0) {
                continue;
            }
            $counted = $final ?? 0.0;
            $s = $snap->get($code);
            $cost = $s && $s->sap_unit_cost > 0 ? (float) $s->sap_unit_cost : ($s && $s->unit_cost !== null ? (float) $s->unit_cost : (isset($proxy[$code]) ? (float) $proxy[$code] : null));
            $v['items']++;

            // Item by item against the book: exact match, over it, or short of it (never found included).
            $delta = $counted - $sys;
            $group = abs($delta) < 0.0001 ? 'match' : ($delta > 0 ? 'over' : 'short');
            $state = $it ? self::state($it, $sys) : 'settled';
            $v['groups'][$group]['items']++;
            $v['groups'][$group]['units'] += $group === 'match' ? $counted : abs($delta);
            $v['groups'][$group]['value'] += $cost === null ? 0 : ($group === 'match' ? $counted : $delta) * $cost;
            $v['lines'][] = ['item_code' => $code, 'group' => $group, 'book' => $sys, 'counted' => $counted, 'found' => $final !== null,
                'not_in_book' => ! isset($book[$code]), 'cost' => $cost, 'value' => $cost === null ? null : round(($group === 'match' ? $counted : $delta) * $cost, 2),
                'state' => $state, 'locations' => array_values($it['locations'] ?? []), 'name' => $it['name'] ?? null, 'barcode' => $it['barcode'] ?? null];

            if ($cost === null) {
                $v['no_cost_items']++;
                $v['no_cost_units'] += abs($counted - $sys);
                continue;
            }
            $s && $s->sap_unit_cost > 0 ? $v['sap_cost_items']++ : $v['estimate_items']++;
            $diff = ($counted - $sys) * $cost;
            $v['book_value'] += $sys * $cost;
            $v['counted_value'] += $counted * $cost;
            if ($final === null) {
                $v['not_found'] += $diff;
            } elseif ($diff > 0) {
                $v['over'] += $diff;
            } else {
                $v['short_counted'] += $diff;
            }
            if ($state === 'settled') {
                $v['settled_net'] += $diff;
            } else {
                $v['pending_net'] += $diff;
                $v['pending_items']++;
            }
            if (abs($diff) >= 0.005) {
                $rows[] = ['item_code' => $code, 'book' => $sys, 'counted' => $counted, 'found' => $final !== null, 'cost' => $cost, 'value' => round($diff, 2), 'state' => $state];
            }
        }
        usort($rows, fn ($a, $b) => abs($b['value']) <=> abs($a['value']));
        $v['top'] = array_slice($rows, 0, 15);
        foreach (['book_value', 'counted_value', 'over', 'short_counted', 'not_found', 'settled_net', 'pending_net', 'no_cost_units'] as $k) {
            $v[$k] = round($v[$k], 2);
        }
        foreach ($v['groups'] as $g => $t) {
            $v['groups'][$g]['units'] = round($t['units'], 3);
            $v['groups'][$g]['value'] = round($t['value'], 2);
        }
        $v['net'] = round($v['counted_value'] - $v['book_value'], 2);
        return $v;
    }

    /**
     * Per item: totals per round, who counted round 1/2, where it was found.
     *
     * @return Collection<string, array{r: array<int,float>, by: array<int,array<int,int>>, locations: array<int,string>, name: ?string, barcode: ?string}>
     */
    public function items(InventoryCounting $c): Collection
    {
        $out = collect();
        $cutoff = $c->sales_cutoff_at;
        InventoryCountingLine::where('inventory_counting_id', $c->id)
            ->select(['item_code', 'item_name', 'piece_barcode', 'location_code', 'counted_by', 'count_round', 'counted_quantity', 'created_at'])
            ->orderBy('id')
            ->each(function ($l) use ($out, $cutoff) {
                $code = $l->item_code;
                $it = $out->get($code, ['r' => [], 'by' => [], 'locations' => [], 'name' => $l->item_name, 'barcode' => $l->piece_barcode, 'after' => [], 'sold_after' => []]);
                $round = (int) ($l->count_round ?: 1);
                $it['r'][$round] = ($it['r'][$round] ?? 0) + (float) $l->counted_quantity;
                if ($l->counted_by) {
                    $it['by'][$round][(int) $l->counted_by] = (int) $l->counted_by;
                }
                if ($round === 1 && $l->location_code && $l->location_code !== self::MISSING_LOCATION) {
                    $it['locations'][$l->location_code] = $l->location_code;
                }
                // A round counted after the showroom sold again: remember when it started.
                if ($cutoff && $l->created_at && $l->created_at->gt($cutoff)) {
                    $it['after'][$round] = min($it['after'][$round] ?? $l->created_at, $l->created_at);
                }
                $out->put($code, $it);
            });

        if ($cutoff) {
            $sales = $this->salesAfter($c);
            $out = $out->map(function ($it, $code) use ($sales) {
                foreach ($it['after'] as $round => $at) {
                    // Add back what left the shelf between the cut-off and this count.
                    $sold = collect($sales[$code] ?? [])->filter(fn ($e) => $e[0] <= $at->format('Y-m-d H:i:s'))->sum(fn ($e) => $e[1]);
                    if (abs($sold) > 0.0001) {
                        $it['r'][$round] += $sold;
                        $it['sold_after'][$round] = $sold;
                    }
                }
                return $it;
            });
        }

        // A recount still open is provisional: its lines wait until the counter
        // closes the item, so the item stays in their queue and settles nothing.
        foreach ($c->recount_progress ?? [] as $code => $p) {
            if ($out->has($code)) {
                $it = $out->get($code);
                $round = (int) $p['round'];
                $it['open'] = $p + ['qty' => $it['r'][$round] ?? 0];
                unset($it['r'][$round], $it['sold_after'][$round]);
                $out->put($code, $it);
            }
        }
        return $out;
    }

    /** @var array<int, Collection> */
    private array $salesMemo = [];

    /**
     * Net pieces out of the count's warehouse after its sales cut-off, per item:
     * [[time, qty]] with sales positive and returns negative, from the SAP mirror
     * (invoices every 10 min with their SAP time; credit notes every minute, timed by sync).
     *
     * @return Collection<string, array<int, array{0: string, 1: float}>>
     */
    public function salesAfter(InventoryCounting $c): Collection
    {
        if (! $c->sales_cutoff_at) {
            return collect();
        }
        return $this->salesMemo[$c->id] ??= (function () use ($c) {
            $from = $c->sales_cutoff_at->format('Y-m-d H:i:s');
            $events = \Illuminate\Support\Facades\DB::table('sap_invoice_lines as l')
                ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
                ->where('l.warehouse_code', $c->warehouse_code)->where('i.cancelled', '<>', 'Y')
                ->where('i.doc_date', '>=', $c->sales_cutoff_at->toDateString())
                ->selectRaw("l.item_code, CONCAT(i.doc_date, ' ', COALESCE(i.doc_time, '00:00:00')) as at, l.quantity as qty")
                ->get()
                ->concat(\Illuminate\Support\Facades\DB::table('sap_credit_memo_lines as l')
                    ->join('sap_credit_memos as m', 'm.id', '=', 'l.sap_credit_memo_id')
                    ->where('l.warehouse_code', $c->warehouse_code)->where('m.cancelled', '<>', 'Y')
                    ->where('m.doc_date', '>=', $c->sales_cutoff_at->toDateString())
                    ->selectRaw('l.item_code, m.created_at as at, -l.quantity as qty')
                    ->get())
                ->filter(fn ($e) => (string) $e->at > $from);
            // Cashier swaps: the till recorded `from`, the customer took `to`.
            foreach ($c->sales_corrections ?? [] as $s) {
                $events->push((object) ['item_code' => $s['from'], 'at' => $s['at'], 'qty' => -(float) $s['qty']]);
                $events->push((object) ['item_code' => $s['to'], 'at' => $s['at'], 'qty' => (float) $s['qty']]);
            }
            return $events->groupBy('item_code')
                ->map(fn ($g) => $g->map(fn ($e) => [substr((string) $e->at, 0, 19), (float) $e->qty])->sortBy(0)->values()->all());
        })();
    }

    public static function finalQty(array $it): ?float
    {
        foreach ([3, 2, 1] as $r) {
            if (array_key_exists($r, $it['r'])) {
                return $it['r'][$r];
            }
        }
        return null;
    }

    public static function needsRecount(float $first, float $book): bool
    {
        $diff = abs($first - $book);
        return $diff >= self::RECOUNT_MIN_UNITS && $diff >= self::RECOUNT_MIN_PCT * max($book, 1);
    }

    /**
     * pending_recount (round 2 needed) | pending_supervisor (round 3 needed) | settled
     */
    public static function state(array $it, float $book): string
    {
        if (array_key_exists(3, $it['r'])) {
            return 'settled';
        }
        if (array_key_exists(2, $it['r'])) {
            $r2 = $it['r'][2];
            $r1 = $it['r'][1] ?? null;
            if ($r1 === null || abs($r2 - $r1) < 0.0001 || abs($r2 - $book) < 0.0001) {
                return 'settled';
            }
            return 'pending_supervisor';
        }
        if (array_key_exists(1, $it['r']) && self::needsRecount($it['r'][1], $book)) {
            return 'pending_recount';
        }
        return 'settled';
    }

    /**
     * The blind recount queue for one user: never an item they counted in a
     * round they would now re-check, and never the quantities. Once the
     * supervisor has handed out the recount (recount_assignments), a counter
     * with a share sees only their own items.
     */
    public function recountQueue(InventoryCounting $c, int $userId): array
    {
        $book = $this->book($c);
        $items = $this->items($c);
        $assigned = array_map('intval', $c->recount_assignments ?? []);
        $mineOnly = in_array($userId, $assigned, true);
        $products = Product::whereIn('item_code', $items->keys())->get()->keyBy('item_code');
        $queue = [];
        foreach ($items as $code => $it) {
            $open = $it['open'] ?? null;
            $state = self::state($it, $book[$code] ?? 0.0);
            if ($state === 'settled' && ! $open) {
                continue;
            }
            if ($mineOnly && ! $open && ($assigned[$code] ?? null) !== $userId) {
                continue;
            }
            $round = $open ? (int) $open['round'] : ($state === 'pending_recount' ? 2 : 3);
            // Round 2 is strictly blind (never the first counter). Round 3 is the
            // supervisor's deciding count: open to anyone so a small team never deadlocks.
            // A recount already under way belongs to whoever started it.
            $countedBefore = $round === 2 ? array_values($it['by'][1] ?? []) : [];
            $mine = $open && (int) $open['user_id'] === $userId;
            if ($mineOnly && $open && ! $mine) {
                continue;
            }
            $p = $products->get($code);
            $queue[] = [
                'item_code' => $code,
                'item_name' => $p?->item_name ?? $it['name'],
                'item_name_ar' => $p?->zb_name_ar,
                'piece_barcode' => $p?->piece_barcode ?? $it['barcode'],
                'round' => $round,
                'locations' => array_values($it['locations']),
                'yours' => $open ? $mine : ! in_array($userId, $countedBefore, true),
                'in_progress' => (bool) $open,
                'by_name' => $open && ! $mine ? ($open['user_name'] ?? null) : null,
            ];
        }
        // Mine under way first, then by round and shelf.
        usort($queue, fn ($a, $b) => [! ($a['in_progress'] && $a['yours']), $a['round'], $a['locations'][0] ?? 'ZZ']
            <=> [! ($b['in_progress'] && $b['yours']), $b['round'], $b['locations'][0] ?? 'ZZ']);
        return $queue;
    }

    /** Items the book says are here that nobody has counted yet. */
    public function missing(InventoryCounting $c): array
    {
        $book = $this->book($c)->filter(fn ($q) => $q > 0);
        $counted = $this->items($c)->keys()->flip();
        $codes = $book->keys()->reject(fn ($code) => isset($counted[$code]))->values();
        $products = Product::whereIn('item_code', $codes)->get()->keyBy('item_code');
        return $codes->map(function ($code) use ($products) {
            $p = $products->get($code);
            return [
                'item_code' => $code,
                'item_name' => $p?->item_name,
                'item_name_ar' => $p?->zb_name_ar,
                'piece_barcode' => $p?->piece_barcode,
                'items_group_code' => $p?->items_group_code,
            ];
        })->sortBy(['items_group_code', 'item_code'])->values()->all();
    }

    public function board(InventoryCounting $c): array
    {
        $book = $this->book($c);
        $items = $this->items($c);
        $locations = StoreLocation::where('warehouse_code', $c->warehouse_code)->orderBy('sort')->orderBy('code')->get();
        $assign = $c->unit_assignments ?? [];

        $countedShelves = InventoryCountingLine::where('inventory_counting_id', $c->id)
            ->where('count_round', 1)->whereNotNull('location_code')
            ->distinct()->pluck('location_code')->flip();

        $units = $locations->groupBy('unit_code')->map(function ($shelves, $unit) use ($countedShelves, $assign) {
            $first = $shelves->first();
            $done = $shelves->filter(fn ($s) => isset($countedShelves[$s->code]))->count();
            $a = $assign[$unit] ?? null;
            return [
                'unit_code' => $unit,
                'kind' => $first->kind,
                'name' => $first->name,
                'shelves' => $shelves->count(),
                'shelves_counted' => $done,
                'counted_shelves' => $shelves->filter(fn ($s) => isset($countedShelves[$s->code]))->pluck('code')->values(),
                'shelf_codes' => $shelves->pluck('code')->values(),
                'status' => $a['status'] ?? ($done > 0 ? 'counting' : 'free'),
                'user_id' => $a['user_id'] ?? null,
                'user_name' => $a['user_name'] ?? null,
            ];
        })->values();

        $states = ['pending_recount' => 0, 'pending_supervisor' => 0];
        $countedUnits = 0.0;
        foreach ($items as $code => $it) {
            $countedUnits += $it['r'][1] ?? 0;
            $s = self::state($it, $book[$code] ?? 0.0);
            if (isset($it['open']) && $s === 'settled') {
                $s = (int) $it['open']['round'] === 2 ? 'pending_recount' : 'pending_supervisor';
            }
            if (isset($states[$s])) {
                $states[$s]++;
            }
        }
        $missing = $book->filter(fn ($q) => $q > 0)->keys()->reject(fn ($k) => $items->has($k))->count();

        $people = InventoryCountingLine::where('inventory_counting_id', $c->id)
            ->whereNotNull('counted_by')
            ->selectRaw('counted_by, COUNT(*) as n_lines, SUM(counted_quantity) as units, MIN(created_at) as first_at, MAX(created_at) as last_at')
            ->groupBy('counted_by')->get();
        $names = \App\Models\User::whereIn('id', $people->pluck('counted_by'))->pluck('name', 'id');
        $people = $people->map(function ($p) use ($names) {
            $hours = max((strtotime($p->last_at) - strtotime($p->first_at)) / 3600, 0.25);
            return [
                'user_id' => (int) $p->counted_by,
                'name' => $names[$p->counted_by] ?? '',
                'lines' => (int) $p->n_lines,
                'units' => (float) $p->units,
                'units_per_hour' => round((float) $p->units / $hours),
            ];
        })->sortByDesc('units')->values();

        $bookUnits = $book->filter(fn ($q) => $q > 0)->sum();
        return [
            'session' => $this->sessionSummary($c),
            'totals' => [
                'book_units' => $bookUnits,
                'book_items' => $book->filter(fn ($q) => $q > 0)->count(),
                'counted_units' => $countedUnits,
                'counted_items' => $items->count(),
                'progress' => $bookUnits > 0 ? min(1, $countedUnits / $bookUnits) : 0,
                'units_total' => $units->count(),
                'units_done' => $units->where('status', 'done')->count(),
                'elapsed_minutes' => $c->started_at ? (int) $c->started_at->diffInMinutes(now()) : 0,
            ],
            'queues' => [
                'recount' => $states['pending_recount'],
                'supervisor' => $states['pending_supervisor'],
                'missing' => $missing,
            ],
            'units' => $units,
            'people' => $people,
        ];
    }

    public function result(InventoryCounting $c): array
    {
        $book = $this->book($c);
        $costs = $this->costs($c);
        $items = $this->items($c);
        $codes = $book->keys()->merge($items->keys())->unique();
        $products = Product::whereIn('item_code', $codes)->get(['item_code', 'item_name', 'zb_name_ar', 'piece_barcode'])->keyBy('item_code');

        $rows = [];
        $match = 0;
        $over = 0.0;
        $short = 0.0;
        foreach ($codes as $code) {
            $sys = (float) ($book[$code] ?? 0);
            $it = $items->get($code);
            $final = $it ? (float) self::finalQty($it) : null;
            if ($final === null && $sys <= 0) {
                continue;
            }
            $counted = $final ?? 0.0; // never found = 0 (only after the missing sweep)
            $diff = $counted - $sys;
            $cost = $costs[$code] ?? null;
            $value = $cost !== null ? round($diff * $cost, 2) : null;
            if (abs($diff) < 0.0001) {
                $match++;
            } elseif ($value !== null) {
                $diff > 0 ? $over += $value : $short += $value;
            }
            $p = $products->get($code);
            $rows[] = [
                'item_code' => $code,
                'item_name' => $p?->item_name ?? ($it['name'] ?? null),
                'item_name_ar' => $p?->zb_name_ar,
                'piece_barcode' => $p?->piece_barcode,
                'system_qty' => $sys,
                'counted_qty' => $counted,
                'counted' => $final !== null,
                'variance' => $diff,
                'unit_cost' => $cost,
                'variance_value' => $value,
            ];
        }
        $total = count($rows);
        $variances = array_values(array_filter($rows, fn ($r) => abs($r['variance']) >= 0.0001));
        usort($variances, fn ($a, $b) => abs($b['variance_value'] ?? $b['variance']) <=> abs($a['variance_value'] ?? $a['variance']));

        return [
            'session' => $this->sessionSummary($c),
            'summary' => [
                'items' => $total,
                'matched' => $match,
                'with_variance' => $total - $match,
                'accuracy' => $total > 0 ? round($match / $total, 4) : null,
                'over_value' => round($over, 2),
                'short_value' => round($short, 2),
                'net_value' => round($over + $short, 2),
            ],
            'top_variances' => array_slice($variances, 0, 25),
            'rows' => $rows,
        ];
    }

    /** SAP batch expiry dates in the count's warehouse: item_code => [{date, batch}] (nearest first, one per date). */
    public function expiryOptions(InventoryCounting $c, string $itemCode): array
    {
        return InventoryCountingBatch::where('inventory_counting_id', $c->id)->where('item_code', $itemCode)
            ->whereNotNull('expiry_date')->orderBy('expiry_date')->get()
            ->unique(fn ($b) => $b->expiry_date->toDateString())
            ->map(fn ($b) => ['date' => $b->expiry_date->toDateString(), 'batch' => $b->batch])
            ->values()->all();
    }

    /** The last day a pack is good: «2027-03» (month/year on the pack) → 2027-03-31. */
    public static function expiryEnd(string $date): Carbon
    {
        return strlen($date) === 7 ? Carbon::createFromFormat('Y-m-d', $date . '-01')->endOfMonth()->startOfDay() : Carbon::parse($date)->startOfDay();
    }

    /**
     * What the counters read on the packs (round 1): what is already expired or
     * expires within 30/60/90 days, and shelf dates SAP holds no batch for in
     * this warehouse (a batch received or sold under the wrong number).
     */
    public function expiry(InventoryCounting $c, bool $withRows = false): array
    {
        $today = now()->startOfDay();
        $costs = $this->costs($c);
        $sapDates = InventoryCountingBatch::where('inventory_counting_id', $c->id)->whereNotNull('expiry_date')->get()
            ->groupBy('item_code')->map(fn ($g) => $g->map(fn ($b) => $b->expiry_date->toDateString())->unique()->sort()->values()->all());

        $lines = InventoryCountingLine::where('inventory_counting_id', $c->id)->where('count_round', 1)
            ->get(['item_code', 'location_code', 'expiries']);
        $asked = $lines->filter(fn ($l) => $l->expiries !== null);

        $byDate = []; // item|date => row
        foreach ($asked as $l) {
            foreach ($l->expiries as $e) {
                $key = $l->item_code . '|' . $e['date'];
                $row = $byDate[$key] ?? ['item_code' => $l->item_code, 'date' => $e['date'], 'qty' => 0.0, 'locations' => []];
                $row['qty'] += (float) $e['qty'];
                if ($l->location_code && $l->location_code !== self::MISSING_LOCATION) {
                    $row['locations'][$l->location_code] = $l->location_code;
                }
                $byDate[$key] = $row;
            }
        }

        $products = Product::whereIn('item_code', collect($byDate)->pluck('item_code')->unique())
            ->get(['item_code', 'item_name', 'zb_name_ar', 'piece_barcode'])->keyBy('item_code');
        $buckets = array_fill_keys(array_keys(self::EXPIRY_BUCKETS), ['items' => [], 'units' => 0.0, 'value' => 0.0]);
        $soon = [];
        $mismatch = [];
        $all = [];
        foreach ($byDate as $row) {
            $days = (int) $today->diffInDays(self::expiryEnd($row['date']), false);
            $cost = $costs[$row['item_code']] ?? null;
            $p = $products->get($row['item_code']);
            $out = [
                'item_code' => $row['item_code'],
                'item_name' => $p?->item_name,
                'item_name_ar' => $p?->zb_name_ar,
                'piece_barcode' => $p?->piece_barcode,
                'date' => $row['date'],
                'days' => $days,
                'qty' => $row['qty'],
                'value' => $cost !== null ? round($row['qty'] * $cost, 2) : null,
                'locations' => array_values($row['locations']),
            ];
            foreach (self::EXPIRY_BUCKETS as $name => $limit) {
                if ($name === 'expired' ? $days < 0 : $days <= $limit) {
                    $buckets[$name]['items'][$row['item_code']] = true;
                    $buckets[$name]['units'] += $row['qty'];
                    $buckets[$name]['value'] += $out['value'] ?? 0;
                    $out['bucket'] = $name;
                    $soon[] = $out;
                    break;
                }
            }
            // Only batch-managed items have SAP dates to disagree with.
            $known = $sapDates[$row['item_code']] ?? null;
            $out['in_sap'] = $known === null ? null : $this->dateMatches($row['date'], $known);
            if ($out['in_sap'] === false) {
                $mismatch[] = $out + ['sap_dates' => $known];
            }
            $all[] = $out + ['sap_dates' => $known ?? []];
        }
        usort($soon, fn ($a, $b) => [$a['days'], $a['item_code']] <=> [$b['days'], $b['item_code']]);
        usort($mismatch, fn ($a, $b) => [$a['days'], $a['item_code']] <=> [$b['days'], $b['item_code']]);

        return [
            'lines' => $lines->count(),
            'lines_with_date' => $asked->filter(fn ($l) => ! empty($l->expiries))->count(),
            'lines_no_date' => $asked->filter(fn ($l) => empty($l->expiries))->count(),
            'buckets' => array_map(fn ($b) => ['items' => count($b['items']), 'units' => $b['units'], 'value' => round($b['value'], 2)], $buckets),
            'soon' => array_slice($soon, 0, 300),
            'mismatch' => array_slice($mismatch, 0, 150),
            'mismatch_total' => count($mismatch),
        ] + ($withRows ? ['rows' => collect($all)->sortBy(['days', 'item_code'])->values()->all()] : []);
    }

    /** A month/year read matches any SAP batch in that month; a full date must match exactly. */
    private function dateMatches(string $date, array $sapDates): bool
    {
        foreach ($sapDates as $d) {
            if (strlen($date) === 7 ? str_starts_with($d, $date) : $d === $date) {
                return true;
            }
        }
        return false;
    }

    public function sessionSummary(InventoryCounting $c): array
    {
        return [
            'id' => $c->id,
            'warehouse_code' => $c->warehouse_code,
            'warehouse_name' => $c->warehouse_name,
            'status' => $c->status,
            'phase' => $c->phase,
            'snapshot_status' => $c->snapshot_status,
            'snapshot_at' => optional($c->snapshot_at)->toIso8601String(),
            'started_at' => optional($c->started_at)->toIso8601String(),
            'approved_at' => optional($c->approved_at)->toIso8601String(),
        ];
    }
}
