<div>
    {{-- Barcode Scanner Input --}}
    @unless($isReadOnly)
    <div class="mb-6 p-4 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
        <div class="flex items-center gap-3">
            <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {{ __('Scan Barcode') }}
                </label>
                <input
                    type="text"
                    wire:model="barcode"
                    wire:keydown.enter="scanBarcode"
                    autofocus
                    placeholder="{{ __('Scan or type barcode / item code...') }}"
                    class="w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-primary-500 focus:ring-primary-500 text-lg px-4 py-3"
                />
            </div>
            <button
                wire:click="scanBarcode"
                type="button"
                class="mt-6 px-6 py-3 bg-primary-600 hover:bg-primary-700 text-white font-semibold rounded-lg shadow transition-colors"
            >
                <x-heroicon-m-magnifying-glass class="w-5 h-5 inline-block" />
                {{ __('Search') }}
            </button>
        </div>
    </div>
    @endunless

    {{-- Items Count Summary --}}
    <div class="mb-4 flex items-center justify-between">
        <span class="text-sm font-medium text-gray-500 dark:text-gray-400">
            {{ __('Items Count') }}: <span class="text-lg font-bold text-primary-600">{{ count($items) }}</span>
        </span>
        <span class="text-sm font-medium text-gray-500 dark:text-gray-400">
            {{ __('Total Quantity') }}: <span class="text-lg font-bold text-primary-600">{{ number_format(collect($items)->sum('counted_quantity'), 0) }}</span>
        </span>
    </div>

    {{-- Scanned Items Table --}}
    @if(count($items) > 0)
    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">#</th>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Image') }}</th>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Item Code') }}</th>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Item Name') }}</th>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Piece Barcode') }}</th>
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Counted Quantity') }}</th>
                    @unless($isReadOnly)
                    <th class="px-4 py-3 text-start text-gray-600 dark:text-gray-300 font-semibold">{{ __('Actions') }}</th>
                    @endunless
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                @foreach($items as $index => $item)
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors" wire:key="item-{{ $index }}">
                    <td class="px-4 py-3 text-gray-500">{{ $index + 1 }}</td>
                    <td class="px-4 py-3">
                        <img
                            src="{{ $item['image_url'] }}"
                            alt="{{ $item['item_code'] }}"
                            class="w-14 h-14 object-contain rounded-lg border border-gray-200 dark:border-gray-600 bg-white"
                            onerror="this.style.display='none'"
                        />
                    </td>
                    <td class="px-4 py-3 font-mono text-gray-800 dark:text-gray-200">{{ $item['item_code'] }}</td>
                    <td class="px-4 py-3 text-gray-700 dark:text-gray-300">{{ $item['item_name'] }}</td>
                    <td class="px-4 py-3 text-gray-500 font-mono text-xs">{{ $item['piece_barcode'] ?? '—' }}</td>
                    <td class="px-4 py-3">
                        @if($isReadOnly)
                            <span class="text-lg font-bold text-primary-600">{{ number_format($item['counted_quantity'], 0) }}</span>
                        @else
                            <input
                                type="number"
                                min="0"
                                step="1"
                                value="{{ $item['counted_quantity'] }}"
                                wire:change="updateQuantity({{ $index }}, $event.target.value)"
                                class="w-24 rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white text-center font-bold text-lg shadow-sm focus:border-primary-500 focus:ring-primary-500"
                            />
                        @endif
                    </td>
                    @unless($isReadOnly)
                    <td class="px-4 py-3">
                        <button
                            wire:click="removeItem({{ $index }})"
                            wire:confirm="{{ __('Are you sure?') }}"
                            type="button"
                            class="p-2 text-red-500 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                        >
                            <x-heroicon-m-trash class="w-5 h-5" />
                        </button>
                    </td>
                    @endunless
                </tr>
                @endforeach
            </tbody>
        </table>
    </div>
    @else
    <div class="py-12 text-center bg-white dark:bg-gray-800 rounded-xl border border-dashed border-gray-300 dark:border-gray-600">
        <x-heroicon-o-clipboard-document-check class="w-16 h-16 mx-auto text-gray-300 dark:text-gray-600 mb-4" />
        <p class="text-gray-500 dark:text-gray-400 text-lg">{{ __('No items scanned yet') }}</p>
        <p class="text-gray-400 dark:text-gray-500 text-sm mt-1">{{ __('Use the scanner above to add products') }}</p>
    </div>
    @endif
</div>
