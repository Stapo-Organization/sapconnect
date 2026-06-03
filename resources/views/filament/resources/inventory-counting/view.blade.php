<x-filament-panels::page>
    @php
        $isCycle      = $record->counting_type === 'cycle';
        $targets      = collect($record->target_items ?? []);
        $linesByCode  = $record->lines->keyBy('item_code');
        $countedCodes = $record->lines->pluck('item_code')->unique();

        $targetTotal = $targets->count();
        $countedDone = $isCycle
            ? $targets->filter(fn ($t) => $countedCodes->contains($t['item_code'] ?? null))->count()
            : $record->lines->count();
        $denominator = $isCycle ? $targetTotal : max($record->lines->count(), 1);
        $progressPct = $denominator > 0 ? round($countedDone / $denominator * 100, 1) : 0;

        // Threshold colours (hex for inline ring, full class names for Tailwind build).
        $hex      = $progressPct >= 100 ? '#22c55e' : ($progressPct >= 50 ? '#f59e0b' : '#ef4444');
        $barFill  = $progressPct >= 100 ? 'bg-green-500' : ($progressPct >= 50 ? 'bg-amber-500' : 'bg-red-500');

        $statusMeta = match ($record->status) {
            'completed' => ['label' => __('Completed'),   'cls' => 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',  'dot' => 'bg-green-500'],
            'cancelled' => ['label' => __('Cancelled'),   'cls' => 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',        'dot' => 'bg-red-500'],
            default     => ['label' => __('In Progress'), 'cls' => 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400', 'dot' => 'bg-amber-500'],
        };

        $byClass = $targets->groupBy('abc_class')->map(fn ($items) => [
            'total' => $items->count(),
            'done'  => $items->filter(fn ($t) => $countedCodes->contains($t['item_code'] ?? null))->count(),
        ]);

        $names = $targetTotal > 0
            ? \App\Models\Product::whereIn('item_code', $targets->pluck('item_code'))->get()
                ->mapWithKeys(fn ($p) => [$p->item_code => $p->display_name])->all()
            : [];

        $classStyles = [
            'A' => ['badge' => 'bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-400',   'bar' => 'bg-rose-500'],
            'B' => ['badge' => 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400', 'bar' => 'bg-amber-500'],
            'C' => ['badge' => 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',   'bar' => 'bg-slate-400'],
        ];
    @endphp

    <div class="space-y-6">

        {{-- ───────── Header / Hero ───────── --}}
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
            <div class="flex flex-col lg:flex-row">

                {{-- Left: identity + meta --}}
                <div class="flex-1 p-6">
                    <div class="flex flex-wrap items-center gap-2 mb-3">
                        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold {{ $statusMeta['cls'] }}">
                            <span class="w-1.5 h-1.5 rounded-full {{ $statusMeta['dot'] }}"></span>
                            {{ $statusMeta['label'] }}
                        </span>
                        @if($isCycle)
                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400">🔄 {{ __('Cycle Count') }}</span>
                        @else
                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300">📋 {{ __('Full Count') }}</span>
                        @endif
                    </div>

                    <h2 class="text-2xl font-bold text-gray-900 dark:text-white">{{ $record->warehouse_name ?? $record->warehouse_code }}</h2>
                    <p class="text-sm text-gray-500 dark:text-gray-400 font-mono mt-0.5">{{ $record->warehouse_code }}</p>

                    {{-- meta tiles --}}
                    <div class="grid grid-cols-2 sm:grid-cols-3 gap-x-6 gap-y-4 mt-6">
                        <div>
                            <p class="text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500">{{ __('Counted By') }}</p>
                            <p class="text-sm font-semibold text-gray-800 dark:text-gray-200 mt-0.5">{{ $record->user?->name ?? '—' }}</p>
                        </div>
                        <div>
                            <p class="text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500">{{ __('Created At') }}</p>
                            <p class="text-sm font-semibold text-gray-800 dark:text-gray-200 mt-0.5">{{ $record->created_at?->format('Y-m-d H:i') ?? '—' }}</p>
                        </div>
                        <div>
                            <p class="text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500">{{ __('Completed At') }}</p>
                            <p class="text-sm font-semibold text-gray-800 dark:text-gray-200 mt-0.5">{{ $record->completed_at?->format('Y-m-d H:i') ?? '—' }}</p>
                        </div>
                    </div>

                    @if($record->notes)
                        <div class="mt-5 pt-4 border-t border-gray-100 dark:border-gray-700">
                            <p class="text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500 mb-1">{{ __('Notes') }}</p>
                            <p class="text-sm text-gray-600 dark:text-gray-300">{{ $record->notes }}</p>
                        </div>
                    @endif
                </div>

                {{-- Right: progress ring --}}
                @if($isCycle && $targetTotal > 0)
                <div class="lg:w-72 shrink-0 bg-gray-50 dark:bg-gray-900/40 border-t lg:border-t-0 lg:border-s border-gray-200 dark:border-gray-700 p-6 flex flex-col items-center justify-center">
                    <div class="relative w-36 h-36 rounded-full" style="background: conic-gradient({{ $hex }} {{ $progressPct }}%, #e5e7eb {{ $progressPct }}%);">
                        <div class="absolute inset-[10px] bg-white dark:bg-gray-800 rounded-full flex flex-col items-center justify-center">
                            <span class="text-3xl font-extrabold text-gray-900 dark:text-white leading-none">{{ rtrim(rtrim(number_format($progressPct, 1), '0'), '.') }}%</span>
                            <span class="text-xs text-gray-400 dark:text-gray-500 mt-1">{{ __('completed') }}</span>
                        </div>
                    </div>
                    <p class="mt-4 text-sm font-semibold text-gray-700 dark:text-gray-200">
                        {{ $countedDone }} / {{ $targetTotal }} {{ __('items') }}
                    </p>
                    <p class="text-xs text-gray-400 dark:text-gray-500">{{ $targetTotal - $countedDone }} {{ __('remaining') }}</p>
                </div>
                @endif
            </div>
        </div>

        {{-- ───────── ABC breakdown ───────── --}}
        @if($isCycle && $targetTotal > 0)
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            @foreach(['A', 'B', 'C'] as $cls)
                @php
                    $cd  = $byClass->get($cls, ['total' => 0, 'done' => 0]);
                    $pct = $cd['total'] > 0 ? round($cd['done'] / $cd['total'] * 100) : 0;
                    $st  = $classStyles[$cls];
                @endphp
                <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-4">
                    <div class="flex items-center justify-between mb-3">
                        <span class="inline-flex items-center justify-center w-7 h-7 rounded-lg text-sm font-bold {{ $st['badge'] }}">{{ $cls }}</span>
                        <span class="text-xs font-medium text-gray-400 dark:text-gray-500">{{ __('Class') }} {{ $cls }}</span>
                    </div>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">{{ $cd['done'] }} <span class="text-base font-normal text-gray-400">/ {{ $cd['total'] }}</span></p>
                    <div class="mt-3 bg-gray-100 dark:bg-gray-700 rounded-full h-1.5 overflow-hidden">
                        <div class="{{ $st['bar'] }} h-1.5 rounded-full transition-all" style="width: {{ $pct }}%"></div>
                    </div>
                </div>
            @endforeach
        </div>
        @endif

        {{-- ───────── Items to count ───────── --}}
        @if($isCycle && $targetTotal > 0)
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100 dark:border-gray-700">
                <h3 class="text-base font-bold text-gray-800 dark:text-gray-200 flex items-center gap-2">📋 {{ __('Items to Count') }}</h3>
                <div class="flex items-center gap-3">
                    <div class="hidden sm:block w-40 bg-gray-100 dark:bg-gray-700 rounded-full h-2 overflow-hidden">
                        <div class="{{ $barFill }} h-2 rounded-full" style="width: {{ $progressPct }}%"></div>
                    </div>
                    <span class="text-sm font-semibold text-gray-600 dark:text-gray-300">{{ $countedDone }} / {{ $targetTotal }}</span>
                </div>
            </div>

            <div class="max-h-[460px] overflow-y-auto">
                <table class="w-full text-sm">
                    <thead class="sticky top-0 bg-gray-50 dark:bg-gray-900/80 backdrop-blur z-10">
                        <tr class="border-b border-gray-200 dark:border-gray-700 text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500">
                            <th class="text-center py-3 px-3 w-12 font-medium">#</th>
                            <th class="text-start py-3 px-3 font-medium">{{ __('Item Code') }}</th>
                            <th class="text-start py-3 px-3 font-medium">{{ __('Item Name') }}</th>
                            <th class="text-center py-3 px-3 font-medium">{{ __('Class') }}</th>
                            <th class="text-center py-3 px-3 font-medium">{{ __('Counted Qty') }}</th>
                            <th class="text-center py-3 px-3 font-medium">{{ __('Status') }}</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-50 dark:divide-gray-800">
                        @foreach($targets as $i => $t)
                            @php
                                $code   = $t['item_code'] ?? '—';
                                $cls    = $t['abc_class'] ?? '—';
                                $line   = $linesByCode->get($code);
                                $isDone = $countedCodes->contains($code);
                                $st     = $classStyles[$cls] ?? $classStyles['C'];
                            @endphp
                            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/40 transition-colors {{ $isDone ? 'bg-green-50/50 dark:bg-green-900/10' : '' }}">
                                <td class="py-2.5 px-3 text-center text-gray-400 tabular-nums">{{ $i + 1 }}</td>
                                <td class="py-2.5 px-3 font-mono text-gray-800 dark:text-gray-200">{{ $code }}</td>
                                <td class="py-2.5 px-3 text-gray-700 dark:text-gray-300 max-w-[280px] truncate">{{ $names[$code] ?? '—' }}</td>
                                <td class="py-2.5 px-3 text-center">
                                    <span class="inline-flex items-center justify-center w-6 h-6 rounded-md text-xs font-bold {{ $st['badge'] }}">{{ $cls }}</span>
                                </td>
                                <td class="py-2.5 px-3 text-center font-semibold tabular-nums text-gray-800 dark:text-gray-200">
                                    {{ $line ? number_format($line->counted_quantity) : '—' }}
                                </td>
                                <td class="py-2.5 px-3 text-center">
                                    @if($isDone)
                                        <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400">✓ {{ __('Counted') }}</span>
                                    @else
                                        <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400">⏳ {{ __('Pending') }}</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
        @endif

        {{-- ───────── Variance Report (completed only) ───────── --}}
        @if($record->isCompleted() && $record->lines->where('variance_status', '!=', null)->count() > 0)
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
            <h3 class="text-base font-bold text-gray-800 dark:text-gray-200 mb-4">📊 {{ __('Variance Report') }}</h3>

            @php
                $lines = $record->lines;
                $statusCounts = $lines->groupBy('variance_status')->map->count();
                $totalCounted = $lines->sum('counted_quantity');
                $totalSystem = $lines->sum('system_quantity');
                $accuracy = $totalSystem > 0 ? round(100 - (abs($totalCounted - $totalSystem) / $totalSystem * 100), 2) : 100;
                $accCls = $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red');
                $accStyles = [
                    'green' => 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-600 dark:text-green-400',
                    'amber' => 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-600 dark:text-amber-400',
                    'red'   => 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-600 dark:text-red-400',
                ][$accCls];
            @endphp

            {{-- Summary Cards --}}
            <div class="grid grid-cols-2 md:grid-cols-5 gap-3 mb-6">
                <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold text-green-600 dark:text-green-400">{{ $statusCounts->get('match', 0) }}</p>
                    <p class="text-sm text-green-700 dark:text-green-500">✅ {{ __('Match') }}</p>
                </div>
                <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold text-amber-600 dark:text-amber-400">{{ $statusCounts->get('within_tolerance', 0) }}</p>
                    <p class="text-sm text-amber-700 dark:text-amber-500">⚡ {{ __('Tolerance') }}</p>
                </div>
                <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold text-blue-600 dark:text-blue-400">{{ $statusCounts->get('over', 0) }}</p>
                    <p class="text-sm text-blue-700 dark:text-blue-500">📈 {{ __('Over') }}</p>
                </div>
                <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold text-red-600 dark:text-red-400">{{ $statusCounts->get('short', 0) }}</p>
                    <p class="text-sm text-red-700 dark:text-red-500">📉 {{ __('Short') }}</p>
                </div>
                <div class="border rounded-lg p-4 text-center {{ $accStyles }}">
                    <p class="text-2xl font-bold">{{ $accuracy }}%</p>
                    <p class="text-sm">🎯 {{ __('Accuracy') }}</p>
                </div>
            </div>

            {{-- Discrepancies Table --}}
            @php
                $discrepancies = $lines->whereNotIn('variance_status', ['match', 'within_tolerance', 'uncounted', null])->sortByDesc(fn ($l) => abs($l->variance_percentage));
            @endphp

            @if($discrepancies->count() > 0)
            <h4 class="font-semibold text-gray-800 dark:text-gray-200 mb-3">⚠️ {{ __('Discrepancies') }} ({{ $discrepancies->count() }})</h4>
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr class="border-b border-gray-200 dark:border-gray-700 text-xs uppercase tracking-wide text-gray-400 dark:text-gray-500">
                            <th class="text-start py-2 px-3 font-medium">{{ __('Item Code') }}</th>
                            <th class="text-start py-2 px-3 font-medium">{{ __('Item Name') }}</th>
                            <th class="text-center py-2 px-3 font-medium">{{ __('System Qty') }}</th>
                            <th class="text-center py-2 px-3 font-medium">{{ __('Counted Qty') }}</th>
                            <th class="text-center py-2 px-3 font-medium">{{ __('Variance') }}</th>
                            <th class="text-center py-2 px-3 font-medium">{{ __('Variance %') }}</th>
                            <th class="text-center py-2 px-3 font-medium">{{ __('Status') }}</th>
                            <th class="text-start py-2 px-3 font-medium">{{ __('Note') }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($discrepancies->take(50) as $line)
                        <tr class="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700/50">
                            <td class="py-2 px-3 font-mono text-gray-800 dark:text-gray-200">{{ $line->item_code }}</td>
                            <td class="py-2 px-3 text-gray-700 dark:text-gray-300 max-w-[200px] truncate">{{ $line->item_name }}</td>
                            <td class="py-2 px-3 text-center text-gray-600 dark:text-gray-400">{{ number_format($line->system_quantity) }}</td>
                            <td class="py-2 px-3 text-center font-semibold text-gray-800 dark:text-gray-200">{{ number_format($line->counted_quantity) }}</td>
                            <td class="py-2 px-3 text-center font-bold {{ $line->variance > 0 ? 'text-blue-600 dark:text-blue-400' : 'text-red-600 dark:text-red-400' }}">
                                {{ $line->variance > 0 ? '+' : '' }}{{ number_format($line->variance) }}
                            </td>
                            <td class="py-2 px-3 text-center {{ abs($line->variance_percentage) > 10 ? 'text-red-600 dark:text-red-400 font-bold' : 'text-gray-600 dark:text-gray-400' }}">
                                {{ number_format($line->variance_percentage, 1) }}%
                            </td>
                            <td class="py-2 px-3 text-center">
                                @if($line->variance_status === 'short')
                                    <span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400">{{ __('Short') }}</span>
                                @elseif($line->variance_status === 'over')
                                    <span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400">{{ __('Over') }}</span>
                                @else
                                    <span class="px-2 py-1 rounded-full text-xs font-semibold bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400">{{ $line->variance_status }}</span>
                                @endif
                            </td>
                            <td class="py-2 px-3 text-start text-gray-500 dark:text-gray-400 max-w-[150px] truncate">{{ $line->investigation_note ?? '—' }}</td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @else
            <div class="text-center py-8">
                <p class="text-green-600 dark:text-green-400 text-lg font-semibold">🎉 {{ __('No discrepancies found!') }}</p>
                <p class="text-gray-500 dark:text-gray-400 text-sm mt-1">{{ __('All counted items match or are within tolerance') }}</p>
            </div>
            @endif
        </div>
        @endif

        {{-- ───────── Scanned items (read-only) ───────── --}}
        @livewire(\App\Livewire\InventoryScanner::class, ['countingId' => $record->id, 'isReadOnly' => true])
    </div>
</x-filament-panels::page>
