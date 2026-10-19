<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InventoryCounting;
use App\Models\InventoryCountingLine;
use App\Models\StoreLocation;
use App\Services\Counting\FullCountService;
use App\Services\Counting\ProductCodeResolver;
use App\Support\AppFeatures;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Symfony\Component\Process\Process;

/**
 * Full (wall-to-wall) showroom count + the showroom map.
 * Writes only to the sapconnect DB; SAP is read (snapshot) and never written.
 */
class FullCountController extends Controller
{
    public function __construct(private FullCountService $svc) {}

    // ─── Showroom map ───────────────────────────────────────────

    public function locations(Request $request, string $wh)
    {
        $this->authorizeWarehouse($request, $wh);
        $rows = StoreLocation::where('warehouse_code', $wh)->orderBy('sort')->orderBy('code')->get();
        $units = $rows->groupBy('unit_code')->map(function ($shelves, $unit) {
            $f = $shelves->first();
            return [
                'unit_code' => $unit,
                'kind' => $f->kind,
                'name' => $f->name,
                'sort' => $f->sort,
                'shelves' => $shelves->map(fn ($s) => [
                    'code' => $s->code,
                    'shelf_no' => $s->shelf_no,
                    'labeled' => $s->labeled_at !== null,
                ])->values(),
                'labeled' => $shelves->whereNotNull('labeled_at')->count(),
            ];
        })->values();

        return response()->json([
            'warehouse_code' => $wh,
            'units' => $units,
            'totals' => [
                'units' => $units->count(),
                'shelves' => $rows->count(),
                'labeled' => $rows->whereNotNull('labeled_at')->count(),
            ],
        ]);
    }

    public function createUnit(Request $request, string $wh)
    {
        $this->authorizeWarehouse($request, $wh, 'inventory_counting.create');
        $data = $request->validate([
            'kind' => 'required|in:' . implode(',', array_keys(StoreLocation::KINDS)),
            'name' => 'nullable|string|max:120',
            'shelves' => 'required|integer|min:1|max:12',
        ]);
        $prefix = StoreLocation::KINDS[$data['kind']];

        $unit = DB::transaction(function () use ($wh, $data, $prefix) {
            $used = StoreLocation::where('warehouse_code', $wh)->where('unit_code', 'like', $prefix . '%')
                ->lockForUpdate()->pluck('unit_code')->unique()
                ->map(fn ($u) => (int) substr($u, 1))->all();
            $n = 1;
            while (in_array($n, $used, true)) {
                $n++;
            }
            $unit = $prefix . str_pad((string) $n, 2, '0', STR_PAD_LEFT);
            $sort = (int) StoreLocation::where('warehouse_code', $wh)->max('sort') + 1;
            for ($i = 1; $i <= $data['shelves']; $i++) {
                StoreLocation::create([
                    'warehouse_code' => $wh,
                    'code' => $unit . '-R' . $i,
                    'unit_code' => $unit,
                    'kind' => $data['kind'],
                    'name' => $data['name'] ?? null,
                    'shelf_no' => $i,
                    'sort' => $sort,
                ]);
            }
            return $unit;
        });

        return response()->json(['unit_code' => $unit], 201);
    }

    public function updateUnit(Request $request, string $wh, string $unit)
    {
        $this->authorizeWarehouse($request, $wh, 'inventory_counting.create');
        $data = $request->validate([
            'name' => 'nullable|string|max:120',
            'shelves' => 'nullable|integer|min:1|max:12',
        ]);
        $shelves = StoreLocation::where('warehouse_code', $wh)->where('unit_code', $unit)->orderBy('shelf_no')->get();
        abort_if($shelves->isEmpty(), 404);
        $f = $shelves->first();

        DB::transaction(function () use ($data, $shelves, $f, $wh, $unit) {
            if (array_key_exists('name', $data)) {
                StoreLocation::where('warehouse_code', $wh)->where('unit_code', $unit)->update(['name' => $data['name']]);
            }
            if (! empty($data['shelves'])) {
                $want = (int) $data['shelves'];
                $have = $shelves->count();
                for ($i = $have + 1; $i <= $want; $i++) {
                    StoreLocation::create([
                        'warehouse_code' => $wh, 'code' => $unit . '-R' . $i, 'unit_code' => $unit,
                        'kind' => $f->kind, 'name' => $data['name'] ?? $f->name, 'shelf_no' => $i, 'sort' => $f->sort,
                    ]);
                }
                if ($want < $have) {
                    $drop = $shelves->where('shelf_no', '>', $want)->pluck('code');
                    abort_if(InventoryCountingLine::whereIn('location_code', $drop)->exists(), 422, 'لا يمكن حذف رف عليه أسطر جرد.');
                    StoreLocation::where('warehouse_code', $wh)->whereIn('code', $drop)->delete();
                }
            }
        });

        return response()->json(['ok' => true]);
    }

    public function deleteUnit(Request $request, string $wh, string $unit)
    {
        $this->authorizeWarehouse($request, $wh, 'inventory_counting.create');
        $codes = StoreLocation::where('warehouse_code', $wh)->where('unit_code', $unit)->pluck('code');
        abort_if($codes->isEmpty(), 404);
        abort_if(InventoryCountingLine::whereIn('location_code', $codes)->exists(), 422, 'لا يمكن حذف وحدة عليها أسطر جرد.');
        StoreLocation::where('warehouse_code', $wh)->where('unit_code', $unit)->delete();
        return response()->json(['ok' => true]);
    }

    /** Scan a stuck label to confirm it is in place and readable. */
    public function verifyLabel(Request $request, string $wh)
    {
        $this->authorizeWarehouse($request, $wh);
        $request->validate(['code' => 'required|string']);
        $parsed = StoreLocation::parseScan($request->code);
        abort_if(! $parsed, 422, 'هذا ليس ملصق رف.');
        [$scanWh, $code] = $parsed;
        abort_if($scanWh && $scanWh !== $wh, 422, 'هذا الملصق لمعرض آخر.');
        $loc = StoreLocation::where('warehouse_code', $wh)->where('code', $code)->firstOrFail();
        if (! $loc->labeled_at) {
            $loc->update(['labeled_at' => now()]);
        }
        return response()->json(['code' => $loc->code, 'unit_code' => $loc->unit_code, 'labeled' => true]);
    }

    /** A short-lived link the app opens in the browser to print the labels. */
    public function labelsLink(Request $request, string $wh)
    {
        $this->authorizeWarehouse($request, $wh);
        $request->validate(['format' => 'nullable|in:a4,a4x30,thermal,thermal62', 'unit' => 'nullable|string|max:16']);
        // Relative signature: valid whatever scheme/host the request arrives on.
        $url = url(URL::temporarySignedRoute('store-labels', now()->addMinutes(30), array_filter([
            'wh' => $wh,
            'format' => $request->input('format', 'a4'),
            'unit' => $request->input('unit'),
        ]), false));
        return response()->json(['url' => $url]);
    }

    // ─── Full count session ─────────────────────────────────────

    /** Start (or return the active) full count for a showroom and freeze the SAP book. */
    public function start(Request $request)
    {
        $data = $request->validate(['warehouse_code' => 'required|string']);
        $wh = $data['warehouse_code'];
        $this->authorizeWarehouse($request, $wh, 'inventory_counting.create');

        $active = InventoryCounting::where('warehouse_code', $wh)
            ->where('counting_type', InventoryCounting::TYPE_FULL)
            ->where('status', InventoryCounting::STATUS_IN_PROGRESS)->first();
        if ($active) {
            return response()->json(['data' => $this->svc->sessionSummary($active), 'existing' => true]);
        }
        abort_if(! StoreLocation::where('warehouse_code', $wh)->exists(), 422, 'ابنِ خريطة المعرض أولاً.');

        $warehouse = \App\Models\Warehouse::where('warehouse_code', $wh)->first();
        $c = InventoryCounting::create([
            'warehouse_code' => $wh,
            'warehouse_name' => $warehouse?->warehouse_name,
            'status' => InventoryCounting::STATUS_IN_PROGRESS,
            'counting_type' => InventoryCounting::TYPE_FULL,
            'phase' => InventoryCounting::PHASE_COUNTING,
            'snapshot_status' => 'pending',
            'counted_by' => $request->user()->id,
            'started_by' => $request->user()->id,
            'started_at' => now(),
            'scheduled_date' => now()->toDateString(),
            'priority' => 'high',
        ]);
        $this->spawnSnapshot($c);

        return response()->json(['data' => $this->svc->sessionSummary($c->fresh()), 'existing' => false], 201);
    }

    public function active(Request $request)
    {
        $codes = $this->userWarehouses($request);
        $q = InventoryCounting::where('counting_type', InventoryCounting::TYPE_FULL)
            ->where('status', InventoryCounting::STATUS_IN_PROGRESS);
        if ($codes) {
            $q->whereIn('warehouse_code', $codes);
        }
        $c = $q->latest()->first();
        return response()->json(['data' => $c ? $this->svc->sessionSummary($c) : null]);
    }

    public function board(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        if ($c->snapshot_status === 'failed' || ($c->snapshot_status === 'pending' && $c->created_at->lt(now()->subMinutes(3))) || $this->snapshotStalled($c)) {
            $this->spawnSnapshot($c); // retry a failed, never-started or silently killed book snapshot
        }
        $board = $this->svc->board($c);
        $board['can_manage'] = $this->canManage($request);
        if ($board['can_manage']) {
            $board['team'] = \App\Models\User::where('warehouse_code', 'like', '%"' . $c->warehouse_code . '"%')
                ->orderBy('name')->get(['id', 'name'])->map(fn ($u) => ['user_id' => $u->id, 'name' => $u->name])->values();
        }
        return response()->json($board);
    }

    public function setPhase(Request $request, int $id)
    {
        $c = $this->session($request, $id, 'inventory_counting.complete');
        $this->ensureManager($request);
        $data = $request->validate(['phase' => 'required|in:counting,recount,missing,review']);
        $c->update(['phase' => $data['phase']]);
        return response()->json(['data' => $this->svc->sessionSummary($c)]);
    }

    /**
     * A counter takes a unit; marking it done hands it back to the supervisor.
     * One open unit per counter: taking a new one means closing the last one
     * (close_previous). Handing a unit to someone else, or freeing another
     * counter's unit, is the manager's call from the board (assign / release).
     */
    public function unit(Request $request, int $id, string $unit, string $action)
    {
        $c = $this->session($request, $id);
        abort_unless(in_array($action, ['claim', 'done', 'release', 'assign'], true), 404);
        abort_if(! StoreLocation::where('warehouse_code', $c->warehouse_code)->where('unit_code', $unit)->exists(), 404);
        $user = $request->user();
        $manager = $this->canManage($request);
        $closePrevious = $request->boolean('close_previous');
        $target = null;
        if ($action === 'assign') {
            $this->ensureManager($request);
            $target = \App\Models\User::findOrFail($request->validate(['user_id' => 'required|integer'])['user_id']);
            abort_if(! str_contains((string) $target->getRawOriginal('warehouse_code'), '"' . $c->warehouse_code . '"'), 422, 'هذا الموظف ليس من فريق المعرض.');
        }

        DB::transaction(function () use ($c, $unit, $action, $user, $manager, $closePrevious, $target) {
            $c = InventoryCounting::lockForUpdate()->find($c->id);
            $a = $c->unit_assignments ?? [];
            $cur = $a[$unit] ?? null;
            $openBy = fn (int $uid) => collect($a)->filter(fn ($x, $u) => $u !== $unit && ($x['status'] ?? '') === 'counting' && (int) $x['user_id'] === $uid)->keys()->first();
            $busy = $cur && ($cur['status'] ?? '') === 'counting';

            if ($action === 'claim') {
                abort_if($busy && (int) $cur['user_id'] !== $user->id, 409, 'يعدّها ' . ($cur['user_name'] ?? 'زميل') . ' الآن. اطلب من المشرف تحويلها لك.');
                if ($prev = $openBy($user->id)) {
                    abort_unless($closePrevious, 409, "أنهِ الوحدة {$prev} أولاً قبل أن تستلم وحدة جديدة.");
                    $a[$prev] = array_merge($a[$prev], ['status' => 'done', 'done_at' => now()->toIso8601String()]);
                }
                $a[$unit] = ['user_id' => $user->id, 'user_name' => $user->name, 'status' => 'counting', 'claimed_at' => now()->toIso8601String()];
            } elseif ($action === 'assign') {
                $prev = $openBy($target->id);
                abort_if($prev, 409, "{$target->name} يعدّ الوحدة {$prev} الآن. أنهِها أو حرّرها أولاً.");
                $a[$unit] = ['user_id' => $target->id, 'user_name' => $target->name, 'status' => 'counting', 'claimed_at' => now()->toIso8601String(), 'assigned_by' => $user->id];
            } elseif ($action === 'done') {
                abort_if($busy && (int) $cur['user_id'] !== $user->id && ! $manager, 403, 'يعدّها ' . ($cur['user_name'] ?? 'زميل') . '. هو من يُنهيها أو المشرف.');
                $a[$unit] = array_merge($cur ?? ['user_id' => $user->id, 'user_name' => $user->name], ['status' => 'done', 'done_at' => now()->toIso8601String()]);
            } else {
                abort_if($busy && (int) $cur['user_id'] !== $user->id && ! $manager, 403, 'تحرير وحدة زميل من صلاحية المشرف.');
                unset($a[$unit]);
            }
            $c->update(['unit_assignments' => $a]);
        });

        return response()->json(['ok' => true]);
    }

    /** What did the counter just scan: a shelf label or a product (piece/carton)? */
    public function resolve(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        $request->validate(['code' => 'required|string|max:64']);
        $code = trim($request->code);

        if ($parsed = StoreLocation::parseScan($code)) {
            [$scanWh, $loc] = $parsed;
            abort_if($scanWh && $scanWh !== $c->warehouse_code, 422, 'هذا الملصق لمعرض آخر.');
            $l = StoreLocation::where('warehouse_code', $c->warehouse_code)->where('code', $loc)->first();
            abort_if(! $l, 404, 'الرف غير موجود في خريطة المعرض.');
            return response()->json(['type' => 'location', 'location' => [
                'code' => $l->code, 'unit_code' => $l->unit_code, 'shelf_no' => $l->shelf_no, 'name' => $l->name, 'kind' => $l->kind,
            ]]);
        }

        $hit = ProductCodeResolver::resolve($code);
        abort_if(! $hit, 404, 'لم نجد الصنف. أدخل كود ساب يدوياً.');
        $p = $hit['product'];
        return response()->json(['type' => 'product', 'matched_kind' => $hit['kind'], 'pack_size' => $hit['pack_size'], 'product' => [
            'item_code' => $p->item_code,
            'item_name' => $p->item_name,
            'item_name_ar' => $p->zb_name_ar,
            'piece_barcode' => $p->piece_barcode,
            'image_url' => 'https://ppte.sa/imghd/' . substr($p->item_code, 0, 4) . '/' . $p->item_code . '.png',
        ], 'expiry_options' => $this->svc->expiryOptions($c, $p->item_code)]);
    }

    /** Record one count line (blind: the response never carries the book quantity). */
    public function count(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        $data = $request->validate([
            'item_code' => 'required|string|max:64',
            'location_code' => 'nullable|string|max:32',
            'quantity' => 'nullable|numeric|min:0|max:100000',
            'cartons' => 'nullable|numeric|min:0|max:10000',
            'pack_size' => 'nullable|numeric|min:1|max:10000',
            'loose' => 'nullable|numeric|min:0|max:100000',
            'count_round' => 'nullable|integer|in:1,2,3',
            // What the packs say, split by date; [] = no date printed, absent = not asked.
            'expiries' => 'nullable|array|max:8',
            'expiries.*.date' => ['required', 'regex:/^20[2-4]\d-(0[1-9]|1[0-2])(-(0[1-9]|[12]\d|3[01]))?$/'],
            'expiries.*.qty' => 'required|numeric|min:0|max:100000',
            'expiries.*.batch' => 'nullable|string|max:64',
            // Counting from «my unit»: the shelf must be in the unit this counter holds.
            'unit_code' => 'nullable|string|max:16',
            // A recount from the queue stays open until the counter closes the item.
            'keep_open' => 'nullable|boolean',
        ]);
        $user = $request->user();
        $round = (int) ($data['count_round'] ?? 1);
        $product = \App\Models\Product::where('item_code', $data['item_code'])->first();
        abort_if(! $product, 404, 'الصنف غير موجود.');

        $loc = $data['location_code'] ?? null;
        if ($loc && $loc !== FullCountService::MISSING_LOCATION) {
            abort_if(! StoreLocation::where('warehouse_code', $c->warehouse_code)->where('code', $loc)->exists(), 422, 'الرف غير موجود في خريطة المعرض.');
        }
        abort_if($round === 1 && ! $loc, 422, 'امسح ملصق الرف أولاً.');
        if ($round === 1 && ! empty($data['unit_code'])) {
            $shelfUnit = StoreLocation::where('warehouse_code', $c->warehouse_code)->where('code', $loc)->value('unit_code');
            abort_if($shelfUnit !== $data['unit_code'], 422, "هذا الرف من الوحدة {$shelfUnit}. أنهِ وحدتك أولاً ثم استلمها.");
            $held = ($c->unit_assignments ?? [])[$data['unit_code']] ?? null;
            abort_if(! $held || ($held['status'] ?? '') !== 'counting' || (int) $held['user_id'] !== $user->id, 409,
                'الوحدة ' . $data['unit_code'] . ' لم تعد معك' . ($held && ($held['status'] ?? '') === 'counting' ? ' (حُوّلت إلى ' . ($held['user_name'] ?? '') . ')' : '') . '.');
        }

        if (isset($data['cartons'])) {
            abort_if(empty($data['pack_size']), 422, 'حدّد عدد الحبّات في الكرتون.');
            $qty = $data['cartons'] * $data['pack_size'] + ($data['loose'] ?? 0);
        } else {
            abort_if(! isset($data['quantity']), 422, 'أدخل الكمية.');
            $qty = (float) $data['quantity'];
        }

        $expiries = null;
        if ($request->has('expiries')) {
            $expiries = collect($data['expiries'] ?? [])
                ->map(fn ($e) => array_filter(['date' => $e['date'], 'qty' => (float) $e['qty'], 'batch' => $e['batch'] ?? null], fn ($v) => $v !== null))
                ->filter(fn ($e) => $e['qty'] > 0)->values()->all();
            abort_if($expiries && abs(array_sum(array_column($expiries, 'qty')) - $qty) > 0.001, 422, 'مجموع كميات التواريخ لا يساوي الكمية.');
        }

        if ($round === 2) {
            // Blind recount: someone who did not count round 1.
            $earlier = InventoryCountingLine::where('inventory_counting_id', $c->id)->where('item_code', $product->item_code)
                ->where('count_round', 1)->where('counted_by', $user->id)->exists();
            abort_if($earlier && $loc !== FullCountService::MISSING_LOCATION, 422, 'إعادة العدّ يقوم بها شخص آخر غير من عدّ أولاً.');
        }

        $keepOpen = $round >= 2 && ! empty($data['keep_open']);
        if ($keepOpen) {
            // Open (or join) this item's recount; one counter at a time.
            DB::transaction(function () use ($c, $product, $round, $user) {
                $c = InventoryCounting::lockForUpdate()->find($c->id);
                $prog = $c->recount_progress ?? [];
                $open = $prog[$product->item_code] ?? null;
                abort_if($open && (int) $open['user_id'] !== $user->id, 409, 'يعيد عدّ هذا الصنف ' . ($open['user_name'] ?? 'زميل') . ' الآن.');
                if (! $open || (int) $open['round'] !== $round) {
                    $prog[$product->item_code] = ['round' => $round, 'user_id' => $user->id, 'user_name' => $user->name, 'at' => now()->toIso8601String()];
                    $c->update(['recount_progress' => $prog]);
                }
            });
        }

        $book = (float) (\App\Models\InventoryCountingSnapshot::where('inventory_counting_id', $c->id)->where('item_code', $product->item_code)->value('system_qty') ?? 0);
        $line = InventoryCountingLine::create([
            'inventory_counting_id' => $c->id,
            'item_code' => $product->item_code,
            'item_name' => $product->item_name,
            'piece_barcode' => $product->piece_barcode,
            'location_code' => $loc,
            'counted_by' => $user->id,
            'count_round' => $round,
            'cartons' => $data['cartons'] ?? null,
            'pack_size' => isset($data['cartons']) ? $data['pack_size'] : null,
            'loose' => isset($data['cartons']) ? ($data['loose'] ?? 0) : null,
            'expiries' => $expiries,
            'counted_quantity' => $qty,
            'system_quantity' => $book,
            'variance' => 0,
            'variance_percentage' => 0,
            'variance_status' => 'uncounted',
        ]);

        return response()->json(['data' => $this->lineJson($line)], 201);
    }

    public function myLines(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        $q = InventoryCountingLine::where('inventory_counting_id', $c->id)->where('counted_by', $request->user()->id);
        if ($request->filled('location')) {
            $q->where('location_code', $request->location);
        }
        if ($request->filled('item')) {
            $q->where('item_code', $request->item);
        }
        if ($request->filled('round')) {
            $q->where('count_round', (int) $request->round);
        }
        $lines = $q->with('product:item_code,zb_name_ar')->latest('id')->limit((int) $request->input('limit', 30))->get();
        return response()->json(['data' => $lines->map(fn ($l) => $this->lineJson($l))]);
    }

    public function deleteLine(Request $request, int $id, int $lineId)
    {
        $c = $this->session($request, $id);
        $line = InventoryCountingLine::where('inventory_counting_id', $c->id)->findOrFail($lineId);
        abort_if((int) $line->counted_by !== $request->user()->id, 403, 'يمكنك حذف أسطرك فقط.');
        $line->delete();
        DB::transaction(function () use ($c, $line) {
            $c = InventoryCounting::lockForUpdate()->find($c->id);
            $prog = $c->recount_progress ?? [];
            $open = $prog[$line->item_code] ?? null;
            if ($open && (int) $open['round'] === (int) $line->count_round && (int) $open['user_id'] === (int) $line->counted_by
                && ! InventoryCountingLine::where('inventory_counting_id', $c->id)->where('item_code', $line->item_code)
                    ->where('count_round', $line->count_round)->where('counted_by', $line->counted_by)->exists()) {
                unset($prog[$line->item_code]);
                $c->update(['recount_progress' => $prog ?: null]);
            }
        });
        return response()->json(['ok' => true]);
    }

    /** The recounter has covered every place the item sits: their lines now count. */
    public function closeRecount(Request $request, int $id, string $item)
    {
        $c = $this->session($request, $id);
        $manager = $this->canManage($request);
        DB::transaction(function () use ($c, $item, $request, $manager) {
            $c = InventoryCounting::lockForUpdate()->find($c->id);
            $prog = $c->recount_progress ?? [];
            $open = $prog[$item] ?? null;
            if (! $open) {
                return;
            }
            abort_if((int) $open['user_id'] !== $request->user()->id && ! $manager, 403, 'يعيد عدّه ' . ($open['user_name'] ?? 'زميل') . '.');
            unset($prog[$item]);
            $c->update(['recount_progress' => $prog ?: null]);
        });
        return response()->json(['ok' => true]);
    }

    public function recountQueue(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        return response()->json(['data' => $this->svc->recountQueue($c, $request->user()->id)]);
    }

    public function missing(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        return response()->json(['data' => $this->svc->missing($c)]);
    }

    /** Missing sweep: «not found» = a second, independent zero (round 2). */
    public function markMissing(Request $request, int $id)
    {
        $c = $this->session($request, $id);
        $data = $request->validate(['item_code' => 'required|string|max:64']);
        $product = \App\Models\Product::where('item_code', $data['item_code'])->firstOrFail();
        $exists = InventoryCountingLine::where('inventory_counting_id', $c->id)->where('item_code', $product->item_code)->exists();
        abort_if($exists, 422, 'هذا الصنف عُدّ بالفعل.');
        $book = (float) (\App\Models\InventoryCountingSnapshot::where('inventory_counting_id', $c->id)->where('item_code', $product->item_code)->value('system_qty') ?? 0);
        $line = InventoryCountingLine::create([
            'inventory_counting_id' => $c->id,
            'item_code' => $product->item_code,
            'item_name' => $product->item_name,
            'piece_barcode' => $product->piece_barcode,
            'location_code' => FullCountService::MISSING_LOCATION,
            'counted_by' => $request->user()->id,
            'count_round' => 2,
            'counted_quantity' => 0,
            'system_quantity' => $book,
            'variance' => 0,
            'variance_percentage' => 0,
            'variance_status' => 'uncounted',
        ]);
        return response()->json(['data' => $this->lineJson($line)], 201);
    }

    public function result(Request $request, int $id)
    {
        $c = $this->session($request, $id, null, true);
        $res = $this->svc->result($c);
        unset($res['rows']);
        $res['expiry'] = $this->svc->expiry($c);
        return response()->json($res);
    }

    public function exportLink(Request $request, int $id)
    {
        $c = $this->session($request, $id, null, true);
        $kind = $request->validate(['kind' => 'nullable|in:variance,expiry'])['kind'] ?? 'variance';
        $params = $kind === 'expiry' ? ['id' => $c->id, 'kind' => 'expiry'] : ['id' => $c->id];
        $url = url(URL::temporarySignedRoute('full-count-export', now()->addMinutes(30), $params, false));
        return response()->json(['url' => $url]);
    }

    public function approve(Request $request, int $id)
    {
        $c = $this->session($request, $id, 'inventory_counting.complete');
        $this->ensureManager($request);
        abort_if($c->snapshot_status !== 'ready', 422, 'رصيد ساب لم يُجمَّد بعد.');
        abort_if(! empty($c->recount_progress), 422, 'بقيت أصناف إعادة عدّ لم يُنهِها أصحابها.');
        $board = $this->svc->board($c);
        abort_if($board['queues']['recount'] > 0 || $board['queues']['supervisor'] > 0, 422, 'طابور إعادة العدّ لم ينتهِ.');
        abort_if($board['queues']['missing'] > 0, 422, 'بقيت أصناف مفقودة بلا قرار.');

        // Write the settled quantity onto every item's lines for the existing variance views.
        DB::transaction(function () use ($c, $request) {
            $book = $this->svc->book($c);
            foreach ($this->svc->items($c) as $code => $it) {
                $final = (float) FullCountService::finalQty($it);
                $sys = (float) ($book[$code] ?? 0);
                $diff = $final - $sys;
                InventoryCountingLine::where('inventory_counting_id', $c->id)->where('item_code', $code)->update([
                    'system_quantity' => $sys,
                    'variance' => $diff,
                    'variance_percentage' => $sys > 0 ? round(abs($diff) / $sys * 100, 4) : ($final > 0 ? 100 : 0),
                    'variance_status' => abs($diff) < 0.0001 ? 'match' : ($diff > 0 ? 'over' : 'short'),
                ]);
            }
            $c->update([
                'phase' => InventoryCounting::PHASE_APPROVED,
                'status' => InventoryCounting::STATUS_COMPLETED,
                'completed_at' => now(),
                'approved_by' => $request->user()->id,
                'approved_at' => now(),
            ]);
        });

        return response()->json(['data' => $this->svc->sessionSummary($c->fresh())]);
    }

    /**
     * Abandon a session (a rehearsal, or a count started by mistake). The lines stay
     * attached to the cancelled session; the next start opens a fresh one with a new
     * SAP book snapshot.
     */
    public function cancel(Request $request, int $id)
    {
        $c = $this->session($request, $id, 'inventory_counting.complete');
        $this->ensureManager($request);
        $c->markAsCancelled();
        return response()->json(['data' => $this->svc->sessionSummary($c->fresh())]);
    }

    // ─── Helpers ────────────────────────────────────────────────

    private function lineJson(InventoryCountingLine $l): array
    {
        return [
            'id' => $l->id,
            'item_code' => $l->item_code,
            'item_name' => $l->item_name,
            'item_name_ar' => $l->relationLoaded('product') ? $l->product?->zb_name_ar : \App\Models\Product::where('item_code', $l->item_code)->value('zb_name_ar'),
            'piece_barcode' => $l->piece_barcode,
            'location_code' => $l->location_code,
            'count_round' => (int) $l->count_round,
            'quantity' => (float) $l->counted_quantity,
            'cartons' => $l->cartons,
            'pack_size' => $l->pack_size,
            'loose' => $l->loose,
            'expiries' => $l->expiries,
            'created_at' => optional($l->created_at)->toIso8601String(),
        ];
    }

    /** «running» but its log (one line per SAP page) has been quiet for 10 minutes: the job died. */
    private function snapshotStalled(InventoryCounting $c): bool
    {
        if ($c->snapshot_status !== 'running') {
            return false;
        }
        $log = storage_path("logs/counting_snapshot_{$c->id}.log");
        $last = is_file($log) ? filemtime($log) : $c->created_at->getTimestamp();
        return $last < now()->subMinutes(10)->getTimestamp();
    }

    private function spawnSnapshot(InventoryCounting $c): void
    {
        $c->update(['snapshot_status' => 'pending']);
        // The cPanel `php` wrapper (128M) dies on this job without a word and leaves the
        // snapshot «running» forever — call the EA PHP 8.2 CLI directly, with room to work.
        $ea = '/opt/cpanel/ea-php82/root/usr/bin/php';
        $php = is_executable($ea) ? $ea : (config('draft_invoices.php_binary') ?: 'php');
        $log = storage_path("logs/counting_snapshot_{$c->id}.log");
        $args = [$php, '-d', 'memory_limit=1G', base_path('artisan'), 'counting:snapshot', (string) $c->id];
        $shell = 'nohup ' . implode(' ', array_map('escapeshellarg', $args)) . ' >> ' . escapeshellarg($log) . ' 2>&1 &';
        try {
            Process::fromShellCommandline($shell, base_path())->setTimeout(null)->run();
        } catch (\Throwable $e) {
            Log::warning('counting:snapshot spawn failed: ' . $e->getMessage());
        }
    }

    private function userWarehouses(Request $request): array
    {
        $codes = $request->user()?->warehouse_code;
        if (is_string($codes)) {
            $d = json_decode($codes, true);
            $codes = is_array($d) ? $d : [$codes];
        }
        return array_values(array_filter((array) $codes));
    }

    private function authorizeWarehouse(Request $request, string $wh, ?string $ability = null): void
    {
        $codes = $this->userWarehouses($request);
        abort_if($codes && ! in_array($wh, $codes, true), 403, 'غير مصرح لك بهذا المعرض.');
        if ($ability) {
            abort_unless(AppFeatures::userCan($request->user(), $ability), 403, 'لا تملك صلاحية هذا الإجراء.');
        }
    }

    /** The owner, by account — not every Super Admin (config counting.managers overrides). */
    private const MANAGERS = ['mahgoub@ppte.sa'];

    /** Approving, cancelling and moving people between units is the owner's alone. */
    private function canManage(Request $request): bool
    {
        $email = strtolower((string) $request->user()?->email);
        return $email !== '' && in_array($email, array_map('strtolower', (array) (config('counting.managers') ?? self::MANAGERS)), true);
    }

    private function ensureManager(Request $request): void
    {
        abort_unless($this->canManage($request), 403, 'هذا الإجراء للمدير فقط.');
    }

    private function session(Request $request, int $id, ?string $ability = null, bool $allowClosed = false): InventoryCounting
    {
        $c = InventoryCounting::where('counting_type', InventoryCounting::TYPE_FULL)->findOrFail($id);
        $this->authorizeWarehouse($request, $c->warehouse_code, $ability);
        abort_if(! $allowClosed && ! $c->isInProgress(), 422, 'هذا الجرد مغلق.');
        return $c;
    }
}
