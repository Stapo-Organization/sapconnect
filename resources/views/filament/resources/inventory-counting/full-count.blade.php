<x-filament-panels::page>
    @php
        // Live progress of a full (wall-to-wall) count, from the same rules the HUB app uses.
        $svc = app(\App\Services\Counting\FullCountService::class);
        $b = $svc->board($record);
        $t = $b['totals'];
        $q = $b['queues'];
        $units = collect($b['units']);
        $people = collect($b['people']);
        $shelvesTotal = $units->sum('shelves');
        $shelvesDone = $units->sum('shelves_counted');

        $r1 = \App\Models\InventoryCountingLine::where('inventory_counting_id', $record->id)->where('count_round', 1)->get(['expiries']);
        $dated = $r1->filter(fn ($l) => ! empty($l->expiries))->count();
        $noDate = $r1->filter(fn ($l) => is_array($l->expiries) && empty($l->expiries))->count();
        $notAsked = $r1->filter(fn ($l) => $l->expiries === null)->count();
        $exp = $svc->expiry($record);

        $recent = \App\Models\InventoryCountingLine::where('inventory_counting_id', $record->id)->latest('id')->limit(15)->get();
        $names = \App\Models\User::whereIn('id', $recent->pluck('counted_by')->merge($people->pluck('user_id'))->filter()->unique())->pluck('name', 'id');
        $products = \App\Models\Product::whereIn('item_code', $recent->pluck('item_code'))->get(['item_code', 'item_name', 'zb_name_ar'])->keyBy('item_code');
        $current = $units->where('status', 'counting')->groupBy('user_id');

        $pct = fn ($a, $b) => $b > 0 ? min(100, round($a / $b * 100)) : 0;
        $num = fn ($v) => number_format((float) $v, 0);
        $unitsPct = $pct($t['counted_units'], $t['book_units']);
        $itemsPct = $pct($t['counted_items'], $t['book_items']);
        $shelvesPct = $pct($shelvesDone, $shelvesTotal);
        $unitDonePct = $pct($t['units_done'], $t['units_total']);
        $elapsed = sprintf('%d:%02d', intdiv($t['elapsed_minutes'], 60), $t['elapsed_minutes'] % 60);
        $label = fn ($d) => strlen($d) === 7 ? substr($d, 5, 2) . '/' . substr($d, 0, 4) : substr($d, 8, 2) . '/' . substr($d, 5, 2) . '/' . substr($d, 0, 4);
        $statusLabel = ['free' => __('Not started'), 'counting' => __('Counting'), 'done' => __('Done')];

        // Every entry, shelf by shelf (map order), filtered by the page's shelf/search fields.
        $entryLimit = 400;
        $shelfOrder = \App\Models\StoreLocation::where('warehouse_code', $record->warehouse_code)
            ->orderBy('sort')->orderBy('code')->pluck('code')->flip();
        $eq = \App\Models\InventoryCountingLine::where('inventory_counting_id', $record->id);
        if ($this->fcShelf) {
            $eq->where('location_code', $this->fcShelf);
        }
        $term = trim($this->fcSearch);
        if ($term !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $term) . '%';
            $codes = \App\Models\Product::where('zb_name_ar', 'like', $like)->orWhere('item_name', 'like', $like)
                ->orWhere('piece_barcode', 'like', $like)->limit(500)->pluck('item_code');
            $eq->where(fn ($w) => $w->where('item_code', 'like', $like)->orWhere('piece_barcode', 'like', $like)->orWhereIn('item_code', $codes));
        }
        $entryTotal = (clone $eq)->count();
        $entries = $eq->orderBy('id')->limit($entryLimit)->get();
        $entryNames = \App\Models\User::whereIn('id', $entries->pluck('counted_by')->filter()->unique())->pluck('name', 'id');
        $entryProducts = \App\Models\Product::whereIn('item_code', $entries->pluck('item_code')->unique())
            ->get(['item_code', 'item_name', 'zb_name_ar', 'piece_barcode'])->keyBy('item_code');
        $byShelf = $entries->groupBy(fn ($l) => $l->location_code ?: '—')
            ->sortBy(fn ($g, $code) => $shelfOrder[$code] ?? PHP_INT_MAX);
        $shelfOptions = \App\Models\InventoryCountingLine::where('inventory_counting_id', $record->id)
            ->whereNotNull('location_code')->distinct()->pluck('location_code')
            ->sortBy(fn ($c) => $shelfOrder[$c] ?? PHP_INT_MAX)->values();
        $qtyFmt = fn ($v) => rtrim(rtrim(number_format((float) $v, 3, '.', ''), '0'), '.');
        $canEdit = $this->canEditEntries();

        // Accounting view: book at SAP cost vs what is on the shelves.
        $val = $svc->valuation($record);
        $sar = fn ($v) => ($v < 0 ? '−' : ($v > 0 ? '+' : '')) . number_format(abs((float) $v), 0) . ' ﷼';
        $plain = fn ($v) => number_format((float) $v, 0) . ' ﷼';
        $valPct = $val['book_value'] > 0 ? round($val['net'] / $val['book_value'] * 100, 1) : 0;
        $valNames = \App\Models\Product::whereIn('item_code', collect($val['top'])->pluck('item_code'))->get(['item_code', 'item_name', 'zb_name_ar'])->keyBy('item_code');
        $stateText = ['settled' => __('Settled'), 'pending_recount' => __('In recount'), 'pending_supervisor' => __('Waiting for supervisor')];

        // Item by item against SAP: one list open at a time, biggest money first.
        $cmpKey = in_array($this->fcCmp, ['match', 'over', 'short'], true) ? $this->fcCmp : 'short';
        $cmpLimit = 300;
        $cmpAll = collect($val['lines'])->where('group', $cmpKey);
        $cmpTerm = mb_strtolower(trim($this->fcCmpSearch));
        if ($cmpTerm !== '') {
            $cmpHit = \App\Models\Product::whereIn('item_code', $cmpAll->pluck('item_code'))
                ->where(fn ($w) => $w->where('zb_name_ar', 'like', '%' . $cmpTerm . '%')->orWhere('item_name', 'like', '%' . $cmpTerm . '%'))
                ->pluck('item_code')->flip();
            $cmpAll = $cmpAll->filter(fn ($r) => isset($cmpHit[$r['item_code']])
                || str_contains(mb_strtolower($r['item_code']), $cmpTerm) || str_contains((string) $r['barcode'], $cmpTerm)
                || collect($r['locations'])->contains(fn ($s) => str_contains(mb_strtolower($s), $cmpTerm)));
        }
        $cmpTotal = $cmpAll->count();
        $cmpRows = $cmpAll->sortByDesc(fn ($r) => abs($r['value'] ?? 0))->take($cmpLimit)->values();
        $cmpNames = \App\Models\Product::whereIn('item_code', $cmpRows->pluck('item_code'))
            ->get(['item_code', 'item_name', 'zb_name_ar', 'piece_barcode'])->keyBy('item_code');
        $cmpTabs = ['short' => ['fc-bad', __('Short of SAP')], 'over' => ['fc-ok', __('Over SAP')], 'match' => ['fc-mute', __('Match SAP exactly')]];

        // Sales after the count: what the showroom sold while items still wait for recount / supervisor.
        $cutoff = $record->sales_cutoff_at;
        $salesRows = collect();
        $salesSettled = 0;
        if ($cutoff) {
            $allItems = $svc->items($record);
            $bookAll = $svc->book($record);
            foreach ($svc->salesAfter($record) as $code => $ev) {
                $it = $allItems->get($code);
                $st = $it ? \App\Services\Counting\FullCountService::state($it, (float) ($bookAll[$code] ?? 0)) : 'settled';
                if ($st === 'settled') {
                    $salesSettled++;
                    continue;
                }
                $salesRows->push(['item_code' => $code, 'net' => collect($ev)->sum(fn ($e) => $e[1]), 'last' => end($ev)[0], 'state' => $st,
                    'r1' => $it['r'][1] ?? null, 'r2' => $it['r'][2] ?? null, 'added' => array_sum($it['sold_after'] ?? [])]);
            }
            $salesRows = $salesRows->sortByDesc('last')->values();
            $salesNames = \App\Models\Product::whereIn('item_code', $salesRows->pluck('item_code'))->get(['item_code', 'item_name', 'zb_name_ar'])->keyBy('item_code');
        }
    @endphp

    <style>
        .fc { --ink:#13141d; --ink2:#585c6c; --ink3:#9a9daa; --line:#e6e7ec; --card:#fff; --soft:#f5f6f8;
              --ok:#0b7d57; --okbg:#e3f4ec; --warn:#b45309; --warnbg:#fdf0dc; --bad:#c0262d; --badbg:#fde8e8; --acc:#0b7d57;
              display:grid; gap:16px; color:var(--ink); font-variant-numeric:tabular-nums; }
        .dark .fc { --ink:#eceef3; --ink2:#a9adba; --ink3:#71768a; --line:#2c2f3a; --card:#1b1d24; --soft:#23262f;
              --ok:#34d399; --okbg:#0f2e24; --warn:#fbbf24; --warnbg:#33270f; --bad:#f87171; --badbg:#3a1517; --acc:#34d399; }
        .fc-card { background:var(--card); border:1px solid var(--line); border-radius:16px; padding:18px; }
        .fc-row { display:flex; flex-wrap:wrap; gap:12px; align-items:center; justify-content:space-between; }
        .fc-h { font-size:20px; font-weight:700; margin:0; }
        .fc-sub { font-size:13px; color:var(--ink2); }
        .fc-chip { display:inline-flex; align-items:center; gap:6px; padding:3px 10px; border-radius:999px; font-size:12px; font-weight:700; }
        .fc-ok { background:var(--okbg); color:var(--ok); } .fc-warn { background:var(--warnbg); color:var(--warn); }
        .fc-bad { background:var(--badbg); color:var(--bad); } .fc-mute { background:var(--soft); color:var(--ink2); }
        .fc-grid { display:grid; gap:12px; grid-template-columns:repeat(auto-fit, minmax(190px, 1fr)); }
        .fc-tile { background:var(--soft); border-radius:12px; padding:14px; }
        .fc-tile .k { font-size:12px; color:var(--ink2); font-weight:600; }
        .fc-tile .v { font-size:26px; font-weight:700; margin-top:2px; }
        .fc-tile .v small { font-size:13px; color:var(--ink2); font-weight:600; }
        .fc-bar { height:8px; border-radius:99px; background:var(--line); overflow:hidden; margin-top:8px; }
        .fc-bar > i { display:block; height:100%; background:var(--acc); border-radius:99px; }
        .fc-title { font-size:15px; font-weight:700; margin:0 0 10px; }
        .fc-units { display:grid; gap:8px; grid-template-columns:repeat(auto-fill, minmax(118px, 1fr)); }
        .fc-unit { border-radius:12px; padding:10px; border:1px solid var(--line); background:var(--card); }
        .fc-unit.done { background:var(--okbg); border-color:transparent; }
        .fc-unit.counting { background:var(--warnbg); border-color:transparent; }
        .fc-unit .c { font-family:ui-monospace,Menlo,monospace; font-weight:700; font-size:15px; direction:ltr; text-align:start; }
        .fc-unit .p { font-size:11px; color:var(--ink2); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
        .fc-table { width:100%; border-collapse:collapse; font-size:13px; }
        .fc-table th { text-align:start; color:var(--ink2); font-weight:600; font-size:12px; padding:8px 6px; border-bottom:1px solid var(--line); }
        .fc-table td { padding:8px 6px; border-bottom:1px solid var(--line); vertical-align:top; }
        .fc-table tr:last-child td { border-bottom:0; }
        .fc-scroll { overflow-x:auto; }
        .fc-mono { font-family:ui-monospace,Menlo,monospace; direction:ltr; unicode-bidi:isolate; }
        .fc-alert { border-radius:12px; padding:12px 14px; font-size:13px; font-weight:600; line-height:1.7; }
        .fc-cols { display:grid; gap:16px; grid-template-columns:repeat(auto-fit, minmax(320px, 1fr)); }
        .fc-filters { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:12px; }
        .fc-input { background:var(--soft); color:var(--ink); border:1px solid var(--line); border-radius:10px; padding:8px 10px; font-size:13px; min-width:0; }
        .fc-input:focus { outline:2px solid var(--acc); outline-offset:-1px; }
        .fc-shelf-h td { background:var(--soft); font-weight:700; }
        .fc-money .v { font-size:22px; }
        .fc-lines { display:grid; gap:6px; font-size:14px; }
        .fc-lines .fc-row { padding:6px 0; border-bottom:1px solid var(--line); }
        .fc-lines .fc-row:last-child { border-bottom:0; font-weight:700; }
        .fc-neg { color:var(--bad); } .fc-pos { color:var(--ok); }
        .fc-act { border:1px solid var(--line); background:var(--card); color:var(--ink2); border-radius:8px; width:30px; height:30px; cursor:pointer; font-size:14px; line-height:1; }
        .fc-act:hover { border-color:var(--acc); color:var(--acc); }
        .fc-del:hover { border-color:var(--bad); color:var(--bad); }
        .fc-tab { text-align:start; cursor:pointer; border:2px solid transparent; font:inherit; color:var(--ink); }
        .fc-tab.fc-bad .v, .fc-tab.fc-bad .k { color:var(--bad); } .fc-tab.fc-ok .v, .fc-tab.fc-ok .k { color:var(--ok); }
        .fc-tab.fc-mute { background:var(--soft); }
        .fc-tab.on { border-color:currentColor; }
        .fc-tab.fc-bad.on { border-color:var(--bad); } .fc-tab.fc-ok.on { border-color:var(--ok); } .fc-tab.fc-mute.on { border-color:var(--ink2); }
    </style>

    <div class="fc" wire:poll.60s>
        {{-- Header --}}
        <div class="fc-card fc-row">
            <div>
                <p class="fc-h">{{ $record->warehouse_name ?? $record->warehouse_code }} · {{ __('Full count') }} #{{ $record->id }}</p>
                <p class="fc-sub">
                    {{ __('Started') }} {{ $record->started_at?->format('Y-m-d H:i') ?? '—' }}
                    · {{ __('Elapsed') }} <span class="fc-mono">{{ $elapsed }}</span>
                    · {{ __('Refreshes every minute') }} ({{ now()->format('H:i:s') }})
                </p>
            </div>
            <div style="display:flex; gap:6px; flex-wrap:wrap">
                @if($record->status === 'completed')
                    <span class="fc-chip fc-ok">{{ __('Approved') }}</span>
                @elseif($record->status === 'cancelled')
                    <span class="fc-chip fc-bad">{{ __('Cancelled') }}</span>
                @else
                    <span class="fc-chip fc-warn">{{ __('In Progress') }} · {{ __('fc_phase_' . ($record->phase ?? 'counting')) }}</span>
                @endif
                <span class="fc-chip {{ $record->snapshot_status === 'ready' ? 'fc-ok' : 'fc-bad' }}">
                    {{ __('SAP book') }}: {{ $record->snapshot_status === 'ready' ? __('Frozen') : $record->snapshot_status }}
                </span>
            </div>
        </div>

        @if($notAsked > 0 && $record->status === 'in_progress')
            <div class="fc-alert fc-warn">
                {{ __(':n count lines have no expiry date because they were counted on an old app version. Everyone must update the app from the download link.', ['n' => $num($notAsked)]) }}
            </div>
        @endif

        {{-- Progress --}}
        <div class="fc-grid">
            <div class="fc-tile">
                <div class="k">{{ __('Pieces counted vs SAP book') }}</div>
                <div class="v">{{ $unitsPct }}% <small>{{ $num($t['counted_units']) }} / {{ $num($t['book_units']) }}</small></div>
                <div class="fc-bar"><i style="width: {{ $unitsPct }}%"></i></div>
            </div>
            <div class="fc-tile">
                <div class="k">{{ __('Items found') }}</div>
                <div class="v">{{ $itemsPct }}% <small>{{ $num($t['counted_items']) }} / {{ $num($t['book_items']) }}</small></div>
                <div class="fc-bar"><i style="width: {{ $itemsPct }}%"></i></div>
            </div>
            <div class="fc-tile">
                <div class="k">{{ __('Shelves counted') }}</div>
                <div class="v">{{ $shelvesPct }}% <small>{{ $num($shelvesDone) }} / {{ $num($shelvesTotal) }}</small></div>
                <div class="fc-bar"><i style="width: {{ $shelvesPct }}%"></i></div>
            </div>
            <div class="fc-tile">
                <div class="k">{{ __('Units finished') }}</div>
                <div class="v">{{ $unitDonePct }}% <small>{{ $num($t['units_done']) }} / {{ $num($t['units_total']) }}</small></div>
                <div class="fc-bar"><i style="width: {{ $unitDonePct }}%"></i></div>
            </div>
        </div>

        <div class="fc-grid">
            <div class="fc-tile"><div class="k">{{ __('Waiting for blind recount') }}</div><div class="v">{{ $num($q['recount']) }}</div></div>
            <div class="fc-tile"><div class="k">{{ __('Waiting for supervisor') }}</div><div class="v">{{ $num($q['supervisor']) }}</div></div>
            <div class="fc-tile"><div class="k">{{ __('In SAP, not found yet') }}</div><div class="v">{{ $num($q['missing']) }}</div></div>
            <div class="fc-tile">
                <div class="k">{{ __('Lines with an expiry date') }}</div>
                <div class="v">{{ $num($dated) }} <small>/ {{ $num($r1->count()) }} · {{ __('no date') }} {{ $num($noDate) }}</small></div>
            </div>
        </div>

        {{-- Accounting comparison --}}
        <div class="fc-card">
            <div class="fc-row" style="margin-bottom:10px">
                <p class="fc-title" style="margin:0">{{ __('Financial comparison at SAP cost') }}</p>
                <span class="fc-chip {{ $val['pending_items'] > 0 || $q['missing'] > 0 ? 'fc-warn' : 'fc-ok' }}">{{ $val['pending_items'] > 0 || $q['missing'] > 0 ? __('Provisional until recount and missing sweep finish') : __('Final') }}</span>
            </div>
            <div class="fc-grid fc-money">
                <div class="fc-tile"><div class="k">{{ __('Stock value in SAP') }}</div><div class="v">{{ $plain($val['book_value']) }}</div></div>
                <div class="fc-tile"><div class="k">{{ __('Stock value counted') }}</div><div class="v">{{ $plain($val['counted_value']) }}</div></div>
                <div class="fc-tile {{ $val['net'] < 0 ? 'fc-bad' : 'fc-ok' }}"><div class="k" style="color:inherit">{{ __('Net difference') }}</div><div class="v">{{ $sar($val['net']) }} <small style="color:inherit">{{ $valPct }}%</small></div></div>
            </div>
            <div class="fc-cols" style="margin-top:12px">
                <div class="fc-lines">
                    <div class="fc-row"><span>{{ __('Overage on counted items') }}</span><span class="fc-pos">{{ $sar($val['over']) }}</span></div>
                    <div class="fc-row"><span>{{ __('Shortage on counted items') }}</span><span class="fc-neg">{{ $sar($val['short_counted']) }}</span></div>
                    <div class="fc-row"><span>{{ __('Items in SAP never found') }}</span><span class="fc-neg">{{ $sar($val['not_found']) }}</span></div>
                    <div class="fc-row"><span>{{ __('Net difference') }}</span><span class="{{ $val['net'] < 0 ? 'fc-neg' : 'fc-pos' }}">{{ $sar($val['net']) }}</span></div>
                </div>
                <div class="fc-lines">
                    <div class="fc-row"><span>{{ __('Settled items') }}</span><span>{{ $sar($val['settled_net']) }}</span></div>
                    <div class="fc-row"><span>{{ __('Still in recount (:n items)', ['n' => $num($val['pending_items'])]) }}</span><span>{{ $sar($val['pending_net']) }}</span></div>
                    <div class="fc-row"><span class="fc-sub">{{ __('Cost from SAP for :a items, estimated for :b, none for :c', ['a' => $num($val['sap_cost_items']), 'b' => $num($val['estimate_items']), 'c' => $num($val['no_cost_items'])]) }}</span><span></span></div>
                </div>
            </div>
            @if($val['top'])
                <div class="fc-scroll" style="margin-top:12px">
                    <table class="fc-table">
                        <thead><tr><th>{{ __('Item') }}</th><th>{{ __('SAP book') }}</th><th>{{ __('Counted') }}</th><th>{{ __('Unit cost') }}</th><th>{{ __('Value') }}</th><th>{{ __('Status') }}</th></tr></thead>
                        <tbody>
                        @foreach($val['top'] as $r)
                            @php $p = $valNames->get($r['item_code']); @endphp
                            <tr>
                                <td>{{ $p?->zb_name_ar ?: ($p?->item_name ?? $r['item_code']) }} <span class="fc-sub fc-mono">{{ $r['item_code'] }}</span></td>
                                <td>{{ $qtyFmt($r['book']) }}</td>
                                <td>{{ $r['found'] ? $qtyFmt($r['counted']) : __('Not found') }}</td>
                                <td>{{ number_format($r['cost'], 2) }}</td>
                                <td class="{{ $r['value'] < 0 ? 'fc-neg' : 'fc-pos' }}" style="font-weight:700; white-space:nowrap">{{ $sar($r['value']) }}</td>
                                <td class="fc-sub">{{ $r['found'] ? ($stateText[$r['state']] ?? $r['state']) : __('Missing sweep') }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </div>

        {{-- Item by item against SAP --}}
        <div class="fc-card">
            <div class="fc-row" style="margin-bottom:10px">
                <p class="fc-title" style="margin:0">{{ __('Items against SAP') }}</p>
                <span class="fc-sub">{{ __('Counted quantity (after recount) vs the frozen SAP book, at SAP cost') }}</span>
            </div>
            <div class="fc-grid">
                @foreach($cmpTabs as $key => $tab)
                    @php $g = $val['groups'][$key]; @endphp
                    <button type="button" class="fc-tile fc-tab {{ $tab[0] }} {{ $cmpKey === $key ? 'on' : '' }}" wire:click="$set('fcCmp', '{{ $key }}')" aria-pressed="{{ $cmpKey === $key ? 'true' : 'false' }}">
                        <div class="k">{{ $tab[1] }}</div>
                        <div class="v">{{ $num($g['items']) }} <small>{{ __('items') }} · {{ $qtyFmt($g['units']) }} {{ __('pcs') }}</small></div>
                        <div class="fc-sub" style="margin-top:4px; font-weight:700">
                            {{ $key === 'match' ? __('Stock value') . ' ' . $plain($g['value']) : $sar($g['value']) }}
                        </div>
                    </button>
                @endforeach
            </div>
            <div class="fc-filters" style="margin-top:12px">
                <input class="fc-input" style="flex:1 1 220px" type="search" wire:model.live.debounce.400ms="fcCmpSearch"
                       placeholder="{{ __('Search this list: name, code, barcode or shelf') }}" aria-label="{{ __('Search') }}">
            </div>
            @if($cmpRows->isEmpty())
                <p class="fc-sub">{{ __('No items in this list.') }}</p>
            @else
                <div class="fc-scroll">
                    <table class="fc-table">
                        <thead><tr>
                            <th>{{ __('Item') }}</th><th>{{ __('Shelf') }}</th><th>{{ __('SAP book') }}</th><th>{{ __('Counted') }}</th>
                            @if($cmpKey !== 'match')<th>{{ __('Pieces difference') }}</th>@endif
                            <th>{{ __('Unit cost') }}</th><th>{{ $cmpKey === 'match' ? __('Stock value') : __('Value') }}</th><th>{{ __('Status') }}</th>
                        </tr></thead>
                        <tbody>
                        @foreach($cmpRows as $r)
                            @php $p = $cmpNames->get($r['item_code']); $d = $r['counted'] - $r['book']; @endphp
                            <tr>
                                <td>
                                    {{ $p?->zb_name_ar ?: ($p?->item_name ?? $r['name'] ?? $r['item_code']) }}
                                    <div class="fc-sub"><span class="fc-mono">{{ $r['item_code'] }}</span>@if($p?->piece_barcode ?: $r['barcode']) · <span class="fc-mono">{{ $p?->piece_barcode ?: $r['barcode'] }}</span>@endif</div>
                                </td>
                                <td class="fc-mono" style="font-size:12px">{{ $r['locations'] ? implode(' ', $r['locations']) : '—' }}</td>
                                <td>{{ $r['not_in_book'] ? __('Not in SAP') : $qtyFmt($r['book']) }}</td>
                                <td style="font-weight:700">{{ $r['found'] ? $qtyFmt($r['counted']) : __('Not found') }}</td>
                                @if($cmpKey !== 'match')
                                    <td class="{{ $d < 0 ? 'fc-neg' : 'fc-pos' }}" style="font-weight:700">{{ ($d > 0 ? '+' : '−') . $qtyFmt(abs($d)) }}</td>
                                @endif
                                <td>{{ $r['cost'] !== null ? number_format($r['cost'], 2) : __('No cost') }}</td>
                                <td class="{{ $cmpKey === 'match' ? '' : ($d < 0 ? 'fc-neg' : 'fc-pos') }}" style="font-weight:700; white-space:nowrap">
                                    {{ $r['value'] === null ? '—' : ($cmpKey === 'match' ? $plain($r['value']) : $sar($r['value'])) }}
                                </td>
                                <td class="fc-sub">{{ $r['found'] ? ($stateText[$r['state']] ?? $r['state']) : __('Missing sweep') }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
                @if($cmpTotal > $cmpRows->count())
                    <p class="fc-sub" style="margin-top:8px">{{ __('Showing :n of :t items, biggest value first. Search to narrow the list.', ['n' => $num($cmpRows->count()), 't' => $num($cmpTotal)]) }}</p>
                @endif
            @endif
        </div>

        @if($cutoff)
            {{-- Sales after the count --}}
            <div class="fc-card">
                <div class="fc-row" style="margin-bottom:10px">
                    <p class="fc-title" style="margin:0">{{ __('Sales after the count') }}</p>
                    <span class="fc-chip {{ $salesRows->isEmpty() ? 'fc-ok' : 'fc-warn' }}">{{ __('Since :t', ['t' => $cutoff->format('d/m H:i')]) }}</span>
                </div>
                <p class="fc-sub" style="margin:0 0 10px">{{ __('Counts entered after this time get the pieces sold since then added back automatically, so they still compare with SAP at count time. Count only what is on the shelf.') }}</p>
                @foreach($record->sales_corrections ?? [] as $s)
                    <div class="fc-alert fc-warn" style="margin-bottom:8px">
                        {{ __('Cashier swap :at: the till recorded :from but the customer took :to × :qty. The tracking moves these pieces to the right item.', ['at' => substr($s['at'], 8, 2) . '/' . substr($s['at'], 5, 2) . ' ' . substr($s['at'], 11, 5), 'from' => $s['from'], 'to' => $s['to'], 'qty' => $qtyFmt($s['qty'])]) }}
                        @if(! empty($s['note']))<span class="fc-sub"> · {{ $s['note'] }}</span>@endif
                    </div>
                @endforeach
                @if($salesRows->isEmpty())
                    <p class="fc-sub">{{ __('No sales yet on items still waiting for recount or supervisor.') }}@if($salesSettled) {{ __(':n settled items sold; SAP handles them by the count date.', ['n' => $num($salesSettled)]) }}@endif</p>
                @else
                    <div class="fc-scroll">
                        <table class="fc-table">
                            <thead><tr><th>{{ __('Item') }}</th><th>{{ __('Sold since count') }}</th><th>{{ __('Last sale') }}</th><th>{{ __('1st count') }}</th><th>{{ __('Recount') }}</th><th>{{ __('Added to later counts') }}</th><th>{{ __('Status') }}</th></tr></thead>
                            <tbody>
                            @foreach($salesRows as $r)
                                @php $p = $salesNames->get($r['item_code']); @endphp
                                <tr>
                                    <td>{{ $p?->zb_name_ar ?: ($p?->item_name ?? $r['item_code']) }} <span class="fc-sub fc-mono">{{ $r['item_code'] }}</span></td>
                                    <td style="font-weight:700">{{ $qtyFmt($r['net']) }}</td>
                                    <td class="fc-mono">{{ substr($r['last'], 11, 5) }}</td>
                                    <td>{{ $r['r1'] !== null ? $qtyFmt($r['r1']) : '—' }}</td>
                                    <td>{{ $r['r2'] !== null ? $qtyFmt($r['r2']) : '—' }}</td>
                                    <td>{{ $r['added'] ? '+' . $qtyFmt($r['added']) : '—' }}</td>
                                    <td class="fc-sub">{{ $stateText[$r['state']] ?? $r['state'] }}</td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </div>
                    @if($salesSettled)
                        <p class="fc-sub" style="margin-top:8px">{{ __(':n settled items sold; SAP handles them by the count date.', ['n' => $num($salesSettled)]) }}</p>
                    @endif
                @endif
            </div>
        @endif

        <div class="fc-cols">
            {{-- People --}}
            <div class="fc-card">
                <p class="fc-title">{{ __('Counters') }}</p>
                @if($people->isEmpty())
                    <p class="fc-sub">{{ __('Nobody has counted yet.') }}</p>
                @else
                    <div class="fc-scroll">
                        <table class="fc-table">
                            <thead><tr><th>{{ __('Name') }}</th><th>{{ __('Now on') }}</th><th>{{ __('Lines') }}</th><th>{{ __('Pieces') }}</th><th>{{ __('Pieces / hour') }}</th></tr></thead>
                            <tbody>
                            @foreach($people as $p)
                                <tr>
                                    <td style="font-weight:700">{{ $p['name'] }}</td>
                                    <td class="fc-mono">{{ $current->get($p['user_id'])?->pluck('unit_code')->join(' ') ?: '—' }}</td>
                                    <td>{{ $num($p['lines']) }}</td>
                                    <td>{{ $num($p['units']) }}</td>
                                    <td>{{ $num($p['units_per_hour']) }}</td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </div>
                @endif
            </div>

            {{-- Expiry so far --}}
            <div class="fc-card">
                <p class="fc-title">{{ __('Expiry dates so far') }}</p>
                <div class="fc-grid" style="grid-template-columns:repeat(2, minmax(0, 1fr))">
                    @foreach(['expired' => 'fc-bad', 'd30' => 'fc-warn', 'd60' => 'fc-warn', 'd90' => 'fc-mute'] as $k => $cls)
                        <div class="fc-tile {{ $cls }}">
                            <div class="k" style="color:inherit">{{ __('fc_exp_' . $k) }}</div>
                            <div class="v" style="font-size:20px">{{ $num($exp['buckets'][$k]['items']) }} <small style="color:inherit">{{ __('items') }} · {{ $num($exp['buckets'][$k]['units']) }} {{ __('pcs') }}</small></div>
                        </div>
                    @endforeach
                </div>
                @if($exp['mismatch_total'] > 0)
                    <p class="fc-sub" style="margin-top:10px">{{ __(':n shelf dates match no SAP batch in this showroom.', ['n' => $num($exp['mismatch_total'])]) }}</p>
                @endif
            </div>
        </div>

        {{-- Units --}}
        <div class="fc-card">
            <div class="fc-row" style="margin-bottom:10px">
                <p class="fc-title" style="margin:0">{{ __('Showroom units') }}</p>
                <div style="display:flex; gap:6px; flex-wrap:wrap">
                    <span class="fc-chip fc-ok">{{ __('Done') }} {{ $units->where('status', 'done')->count() }}</span>
                    <span class="fc-chip fc-warn">{{ __('Counting') }} {{ $units->where('status', 'counting')->count() }}</span>
                    <span class="fc-chip fc-mute">{{ __('Not started') }} {{ $units->where('status', 'free')->count() }}</span>
                </div>
            </div>
            <div class="fc-units">
                @foreach($units->sortBy('unit_code') as $u)
                    <div class="fc-unit {{ $u['status'] }}">
                        <div class="fc-row" style="gap:4px">
                            <span class="c">{{ $u['unit_code'] }}</span>
                            <span class="fc-sub fc-mono" style="font-size:12px">{{ $u['shelves_counted'] }}/{{ $u['shelves'] }}</span>
                        </div>
                        <div class="p">{{ $u['user_name'] ?? $statusLabel[$u['status']] ?? '' }}</div>
                        <div class="fc-bar" style="height:5px; margin-top:6px"><i style="width: {{ $pct($u['shelves_counted'], $u['shelves']) }}%"></i></div>
                    </div>
                @endforeach
            </div>
        </div>

        {{-- Every entry, by shelf --}}
        <div class="fc-card">
            <div class="fc-row" style="margin-bottom:10px">
                <p class="fc-title" style="margin:0">{{ __('All entries by shelf') }}</p>
                <span class="fc-sub">{{ __(':n entries', ['n' => $num($entryTotal)]) }}</span>
            </div>
            <div class="fc-filters">
                <select class="fc-input" wire:model.live="fcShelf" aria-label="{{ __('Shelf') }}">
                    <option value="">{{ __('All shelves') }}</option>
                    @foreach($shelfOptions as $code)
                        <option value="{{ $code }}">{{ $code }}</option>
                    @endforeach
                </select>
                <input class="fc-input" style="flex:1 1 220px" type="search" wire:model.live.debounce.400ms="fcSearch"
                       placeholder="{{ __('Search item name, code or barcode') }}" aria-label="{{ __('Search') }}">
            </div>
            @if($entries->isEmpty())
                <p class="fc-sub">{{ __('No entries match.') }}</p>
            @else
                <div class="fc-scroll">
                    <table class="fc-table">
                        <thead><tr><th>{{ __('Item') }}</th><th>{{ __('Pieces') }}</th><th>{{ __('Cartons') }}</th><th>{{ __('Counter') }}</th><th>{{ __('Time') }}</th><th>{{ __('Round') }}</th><th>{{ __('Expiry') }}</th>@if($canEdit)<th></th>@endif</tr></thead>
                        <tbody>
                        @foreach($byShelf as $shelf => $rows)
                            <tr class="fc-shelf-h">
                                <td colspan="{{ $canEdit ? 8 : 7 }}">
                                    <span class="fc-mono">{{ $shelf === 'MISSING' ? __('Missing sweep') : $shelf }}</span>
                                    <span class="fc-sub"> · {{ __(':n entries', ['n' => $rows->count()]) }} · {{ $qtyFmt($rows->sum('counted_quantity')) }} {{ __('pcs') }}</span>
                                </td>
                            </tr>
                            @foreach($rows as $l)
                                @php $p = $entryProducts->get($l->item_code); @endphp
                                <tr>
                                    <td>
                                        {{ $p?->zb_name_ar ?: ($p?->item_name ?? $l->item_name) }}
                                        <div class="fc-sub"><span class="fc-mono">{{ $l->item_code }}</span>@if($p?->piece_barcode) · <span class="fc-mono">{{ $p->piece_barcode }}</span>@endif</div>
                                    </td>
                                    <td style="font-weight:700; font-size:15px">{{ $qtyFmt($l->counted_quantity) }}</td>
                                    <td class="fc-mono">{{ $l->cartons !== null ? $qtyFmt($l->cartons) . ' × ' . $qtyFmt($l->pack_size) . ' + ' . $qtyFmt($l->loose ?? 0) : '—' }}</td>
                                    <td>{{ $entryNames[$l->counted_by] ?? '—' }}</td>
                                    <td class="fc-mono">{{ $l->created_at?->format('H:i') }}</td>
                                    <td>{{ $l->count_round }}</td>
                                    <td>
                                        @if($l->expiries === null)
                                            <span class="fc-sub">—</span>
                                        @elseif(empty($l->expiries))
                                            <span class="fc-sub">{{ __('no date') }}</span>
                                        @else
                                            <span class="fc-mono">{{ collect($l->expiries)->map(fn ($e) => $label($e['date']) . ' × ' . $qtyFmt($e['qty']))->join('  ·  ') }}</span>
                                        @endif
                                        @if($l->investigation_note)
                                            <div class="fc-sub" style="white-space:pre-line; margin-top:2px" title="{{ $l->investigation_note }}">✎ {{ __('Edited') }}</div>
                                        @endif
                                    </td>
                                    @if($canEdit)
                                        <td style="white-space:nowrap">
                                            <button type="button" class="fc-act" title="{{ __('Edit entry') }}" aria-label="{{ __('Edit entry') }}" wire:click="mountAction('editLine', { line: {{ $l->id }} })">✎</button>
                                            <button type="button" class="fc-act fc-del" title="{{ __('Delete entry?') }}" aria-label="{{ __('Delete entry?') }}" wire:click="mountAction('deleteLine', { line: {{ $l->id }} })">🗑</button>
                                        </td>
                                    @endif
                                </tr>
                            @endforeach
                        @endforeach
                        </tbody>
                    </table>
                </div>
                @if($entryTotal > $entries->count())
                    <p class="fc-sub" style="margin-top:8px">{{ __('Showing the first :n entries. Pick a shelf or search to narrow the list.', ['n' => $num($entries->count())]) }}</p>
                @endif
            @endif
        </div>

        {{-- Latest lines --}}
        <div class="fc-card">
            <p class="fc-title">{{ __('Latest count lines') }}</p>
            @if($recent->isEmpty())
                <p class="fc-sub">{{ __('Nobody has counted yet.') }}</p>
            @else
                <div class="fc-scroll">
                    <table class="fc-table">
                        <thead><tr><th>{{ __('Time') }}</th><th>{{ __('Counter') }}</th><th>{{ __('Shelf') }}</th><th>{{ __('Item') }}</th><th>{{ __('Pieces') }}</th><th>{{ __('Expiry') }}</th><th>{{ __('Round') }}</th></tr></thead>
                        <tbody>
                        @foreach($recent as $l)
                            @php $p = $products->get($l->item_code); @endphp
                            <tr>
                                <td class="fc-mono">{{ $l->created_at?->format('H:i') }}</td>
                                <td>{{ $names[$l->counted_by] ?? '—' }}</td>
                                <td class="fc-mono">{{ $l->location_code ?? '—' }}</td>
                                <td>{{ $p?->zb_name_ar ?: ($p?->item_name ?? $l->item_name) }} <span class="fc-sub fc-mono">{{ $l->item_code }}</span></td>
                                <td style="font-weight:700">{{ rtrim(rtrim(number_format((float) $l->counted_quantity, 3, '.', ''), '0'), '.') }}</td>
                                <td>
                                    @if($l->expiries === null)
                                        <span class="fc-sub">—</span>
                                    @elseif(empty($l->expiries))
                                        <span class="fc-sub">{{ __('no date') }}</span>
                                    @else
                                        <span class="fc-mono">{{ collect($l->expiries)->map(fn ($e) => $label($e['date']) . ' × ' . rtrim(rtrim(number_format((float) $e['qty'], 3, '.', ''), '0'), '.'))->join('  ·  ') }}</span>
                                    @endif
                                </td>
                                <td>{{ $l->count_round }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </div>
    </div>
</x-filament-panels::page>
