<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Counting Info --}}
        <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Warehouse Code') }}</span>
                    <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $record->warehouse_code }}</p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Warehouse Name') }}</span>
                    <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $record->warehouse_name }}</p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Status') }}</span>
                    <p class="mt-1">
                        @if($record->status === 'completed')
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
                                {{ __('Completed') }}
                            </span>
                        @elseif($record->status === 'cancelled')
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400">
                                {{ __('Cancelled') }}
                            </span>
                        @else
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400">
                                {{ __('In Progress') }}
                            </span>
                        @endif
                    </p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Counted By') }}</span>
                    <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $record->user?->name ?? '—' }}</p>
                </div>
            </div>

            {{-- Counting Type & Priority --}}
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Counting Type') }}</span>
                    <p class="mt-1">
                        @if($record->counting_type === 'cycle')
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400">
                                🔄 {{ __('Cycle Count') }}
                            </span>
                        @else
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400">
                                📋 {{ __('Full Count') }}
                            </span>
                        @endif
                    </p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Created At') }}</span>
                    <p class="text-gray-800 dark:text-gray-200 font-semibold">{{ $record->created_at?->format('Y-m-d H:i') ?? '—' }}</p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Completed At') }}</span>
                    <p class="text-gray-800 dark:text-gray-200 font-semibold">{{ $record->completed_at?->format('Y-m-d H:i') ?? '—' }}</p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Total Items') }}</span>
                    @if($record->counting_type === 'cycle')
                        <p class="text-lg font-bold text-gray-800 dark:text-gray-200">
                            {{ $record->lines->pluck('item_code')->unique()->count() }} / {{ count($record->target_items ?? []) }}
                        </p>
                    @else
                        <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $record->lines->count() }}</p>
                    @endif
                </div>
            </div>

            @if($record->notes)
            <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Notes') }}</span>
                <p class="text-gray-700 dark:text-gray-300 mt-1">{{ $record->notes }}</p>
            </div>
            @endif
        </div>

        {{-- Target Items & Progress (cycle counts) --}}
        @php
            $targets = collect($record->target_items ?? []);
        @endphp
        @if($record->counting_type === 'cycle' && $targets->count() > 0)
        @php
            $linesByCode  = $record->lines->keyBy('item_code');
            $countedCodes = $record->lines->pluck('item_code')->unique();
            $targetTotal  = $targets->count();
            $countedDone  = $targets->filter(fn ($t) => $countedCodes->contains($t['item_code'] ?? null))->count();
            $progressPct  = $targetTotal > 0 ? round($countedDone / $targetTotal * 100, 1) : 0;
            // Full literal class names so Tailwind keeps them in the compiled build.
            $barFill  = $progressPct >= 100 ? 'bg-green-500' : ($progressPct >= 50 ? 'bg-amber-500' : 'bg-red-500');
            $barText  = $progressPct >= 100 ? 'text-green-600 dark:text-green-400' : ($progressPct >= 50 ? 'text-amber-600 dark:text-amber-400' : 'text-red-600 dark:text-red-400');

            $byClass = $targets->groupBy('abc_class')->map(function ($items) use ($countedCodes) {
                return [
                    'total' => $items->count(),
                    'done'  => $items->filter(fn ($t) => $countedCodes->contains($t['item_code'] ?? null))->count(),
                ];
            });

            $names = \App\Models\Product::whereIn('item_code', $targets->pluck('item_code'))
                ->get()->mapWithKeys(fn ($p) => [$p->item_code => $p->display_name])->all();
        @endphp

        <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200">📋 {{ __('Items to Count') }}</h3>
                <span class="text-sm font-semibold text-gray-600 dark:text-gray-300">
                    {{ $countedDone }} / {{ $targetTotal }} {{ __('counted') }}
                </span>
            </div>

            {{-- Progress bar --}}
            <div class="mb-2 flex items-center gap-3">
                <div class="flex-1 bg-gray-200 dark:bg-gray-700 rounded-full h-4 overflow-hidden">
                    <div class="{{ $barFill }} h-4 rounded-full transition-all" style="width: {{ $progressPct }}%"></div>
                </div>
                <span class="text-sm font-bold {{ $barText }} w-14 text-left">{{ $progressPct }}%</span>
            </div>

            {{-- ABC breakdown --}}
            <div class="grid grid-cols-3 gap-3 my-4">
                @foreach(['A', 'B', 'C'] as $cls)
                    @php $cd = $byClass->get($cls, ['total' => 0, 'done' => 0]); @endphp
                    <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-3 text-center">
                        <p class="text-xs text-gray-500 dark:text-gray-400 mb-1">{{ __('Class') }} {{ $cls }}</p>
                        <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $cd['done'] }} / {{ $cd['total'] }}</p>
                    </div>
                @endforeach
            </div>

            {{-- Target items table --}}
            <div class="overflow-x-auto max-h-[420px] overflow-y-auto border border-gray-100 dark:border-gray-800 rounded-lg">
                <table class="w-full text-sm">
                    <thead class="sticky top-0 bg-gray-50 dark:bg-gray-900">
                        <tr class="border-b border-gray-200 dark:border-gray-700">
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400 w-10">#</th>
                            <th class="text-right py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Item Code') }}</th>
                            <th class="text-right py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Item Name') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Class') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Counted Qty') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Status') }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($targets as $i => $t)
                            @php
                                $code    = $t['item_code'] ?? '—';
                                $cls     = $t['abc_class'] ?? '—';
                                $line    = $linesByCode->get($code);
                                $isDone  = $countedCodes->contains($code);
                            @endphp
                            <tr class="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700/50 {{ $isDone ? 'bg-green-50/40 dark:bg-green-900/10' : '' }}">
                                <td class="py-2 px-3 text-center text-gray-400">{{ $i + 1 }}</td>
                                <td class="py-2 px-3 font-mono text-gray-800 dark:text-gray-200">{{ $code }}</td>
                                <td class="py-2 px-3 text-gray-700 dark:text-gray-300 max-w-[260px] truncate">{{ $names[$code] ?? '—' }}</td>
                                <td class="py-2 px-3 text-center">
                                    <span class="px-2 py-0.5 rounded-full text-xs font-semibold
                                        {{ $cls === 'A' ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' : ($cls === 'B' ? 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' : 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300') }}">
                                        {{ $cls }}
                                    </span>
                                </td>
                                <td class="py-2 px-3 text-center font-semibold text-gray-800 dark:text-gray-200">
                                    {{ $line ? number_format($line->counted_quantity) : '—' }}
                                </td>
                                <td class="py-2 px-3 text-center">
                                    @if($isDone)
                                        <span class="px-2 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400">✓ {{ __('Counted') }}</span>
                                    @else
                                        <span class="px-2 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400">⏳ {{ __('Pending') }}</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
        @endif

        {{-- Variance Report (only for completed sessions) --}}
        @if($record->isCompleted() && $record->lines->where('variance_status', '!=', null)->count() > 0)
        <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
            <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-4">📊 {{ __('Variance Report') }}</h3>

            @php
                $lines = $record->lines;
                $statusCounts = $lines->groupBy('variance_status')->map->count();
                $totalCounted = $lines->sum('counted_quantity');
                $totalSystem = $lines->sum('system_quantity');
                $accuracy = $totalSystem > 0 ? round(100 - (abs($totalCounted - $totalSystem) / $totalSystem * 100), 2) : 100;
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
                <div class="bg-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-50 dark:bg-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-900/20 border border-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-200 dark:border-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-800 rounded-lg p-4 text-center">
                    <p class="text-2xl font-bold text-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-600 dark:text-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-400">{{ $accuracy }}%</p>
                    <p class="text-sm text-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-700 dark:text-{{ $accuracy >= 98 ? 'green' : ($accuracy >= 95 ? 'amber' : 'red') }}-500">🎯 {{ __('Accuracy') }}</p>
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
                        <tr class="border-b border-gray-200 dark:border-gray-700">
                            <th class="text-right py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Item Code') }}</th>
                            <th class="text-right py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Item Name') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('System Qty') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Counted Qty') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Variance') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Variance %') }}</th>
                            <th class="text-center py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Status') }}</th>
                            <th class="text-right py-2 px-3 text-gray-500 dark:text-gray-400">{{ __('Note') }}</th>
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
                            <td class="py-2 px-3 text-right text-gray-500 dark:text-gray-400 max-w-[150px] truncate">{{ $line->investigation_note ?? '—' }}</td>
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

        {{-- Scanned Items (read-only) --}}
        @livewire(\App\Livewire\InventoryScanner::class, ['countingId' => $record->id, 'isReadOnly' => true])
    </div>
</x-filament-panels::page>
