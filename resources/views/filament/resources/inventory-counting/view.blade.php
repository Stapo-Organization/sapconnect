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
                        @else
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400">
                                {{ __('Draft') }}
                            </span>
                        @endif
                    </p>
                </div>
                <div>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Counted By') }}</span>
                    <p class="text-lg font-bold text-gray-800 dark:text-gray-200">{{ $record->user?->name ?? '—' }}</p>
                </div>
            </div>
            @if($record->notes)
            <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <span class="text-sm text-gray-500 dark:text-gray-400">{{ __('Notes') }}</span>
                <p class="text-gray-700 dark:text-gray-300 mt-1">{{ $record->notes }}</p>
            </div>
            @endif
        </div>

        {{-- Scanned Items (read-only) --}}
        @livewire(\App\Livewire\InventoryScanner::class, ['countingId' => $record->id, 'isReadOnly' => true])
    </div>
</x-filament-panels::page>
