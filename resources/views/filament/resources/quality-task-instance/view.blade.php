@php
    $snap = $record->requirements_snapshot ?? [];
    $proofType = $snap['proof_type'] ?? 'photo';
    $slot = $snap['slot'] ?? null;
    $hasSlot = $slot && ($slot['key'] ?? '_default') !== '_default';
    $photos = $record->photos;
    $generalPhotos = $photos->whereNull('checklist_item_key');
    $statusMeta = match ($record->status) {
        'submitted' => ['label' => __('Submitted'), 'bg' => 'bg-green-100 text-green-700', 'dot' => 'bg-green-500'],
        'cancelled' => ['label' => __('Cancelled'), 'bg' => 'bg-red-100 text-red-700', 'dot' => 'bg-red-500'],
        default => ['label' => __('Pending'), 'bg' => 'bg-amber-100 text-amber-700', 'dot' => 'bg-amber-500'],
    };
    $proofLabel = match ($proofType) {
        'acknowledge' => __('Acknowledge'),
        'checklist' => __('Checklist'),
        default => __('Photo'),
    };
@endphp

<x-filament-panels::page>
    <div class="space-y-6">

        {{-- Hero header --}}
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
            <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                <div>
                    <div class="flex flex-wrap gap-2 mb-3">
                        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold {{ $statusMeta['bg'] }}">
                            <span class="w-2 h-2 rounded-full {{ $statusMeta['dot'] }}"></span>{{ $statusMeta['label'] }}
                        </span>
                        <span class="px-3 py-1 rounded-full text-xs font-bold bg-blue-100 text-blue-700">{{ $proofLabel }}</span>
                        @if($hasSlot)
                            <span class="px-3 py-1 rounded-full text-xs font-bold bg-purple-100 text-purple-700">{{ $slot['label_ar'] ?? $slot['label_en'] }}</span>
                        @endif
                    </div>
                    <h2 class="text-2xl font-bold text-gray-900 dark:text-white">{{ $record->title }}</h2>
                    @if($record->description)
                        <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">{{ $record->description }}</p>
                    @endif
                </div>
                <div class="text-end space-y-1">
                    <p class="text-sm text-gray-500">{{ __('Warehouse') }}: <span class="font-semibold text-gray-800 dark:text-gray-200">{{ $record->warehouse_name ?? $record->warehouse_code }}</span></p>
                    <p class="text-sm text-gray-500">{{ __('Date') }}: <span class="font-semibold">{{ $record->scheduled_date?->format('Y-m-d') }}</span></p>
                    @if($record->submitted_at)
                        <p class="text-sm text-gray-500">{{ __('Submitted') }}: <span class="font-semibold">{{ $record->submitted_at->format('Y-m-d H:i') }}</span></p>
                        <p class="text-sm text-gray-500">{{ __('By') }}: <span class="font-semibold">{{ $record->submitter?->name ?? '—' }}</span></p>
                    @endif
                </div>
            </div>

            @if($record->comment)
                <div class="mt-4 p-4 rounded-xl bg-gray-50 dark:bg-gray-900/40 border border-gray-200 dark:border-gray-700">
                    <p class="text-xs font-bold text-gray-500 mb-1">{{ __('Comment') }}</p>
                    <p class="text-sm text-gray-800 dark:text-gray-200">{{ $record->comment }}</p>
                </div>
            @endif
        </div>

        {{-- Checklist results --}}
        @if($proofType === 'checklist')
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
                <h3 class="font-bold text-gray-900 dark:text-white mb-4">📋 {{ __('Checklist') }}</h3>
                <div class="space-y-4">
                    @foreach($snap['checklist_items'] ?? [] as $item)
                        @php
                            $key = $item['key'];
                            $result = $record->checklist_results[$key] ?? null;
                            $done = $result['checked'] ?? false;
                            $itemPhotos = $photos->where('checklist_item_key', $key);
                        @endphp
                        <div class="p-4 rounded-xl border {{ $done ? 'border-green-200 bg-green-50 dark:bg-green-900/10' : 'border-gray-200 dark:border-gray-700' }}">
                            <div class="flex items-center gap-2 mb-2">
                                <span class="text-lg">{{ $done ? '✅' : '⏳' }}</span>
                                <span class="font-semibold text-gray-800 dark:text-gray-200">{{ $item['label'] ?? $key }}</span>
                                @if($item['require_photo'] ?? false)
                                    <span class="text-xs text-gray-400">({{ __('photo required') }})</span>
                                @endif
                            </div>
                            @if($itemPhotos->isNotEmpty())
                                <div class="grid grid-cols-3 md:grid-cols-5 gap-2">
                                    @foreach($itemPhotos as $photo)
                                        <a href="{{ $photo->url }}" target="_blank">
                                            <img src="{{ $photo->url }}" class="rounded-lg object-cover w-full h-24 hover:opacity-80 transition" alt="">
                                        </a>
                                    @endforeach
                                </div>
                            @endif
                        </div>
                    @endforeach
                </div>
            </div>
        @endif

        {{-- General photos --}}
        @if($generalPhotos->isNotEmpty())
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
                <h3 class="font-bold text-gray-900 dark:text-white mb-4">📸 {{ __('Photos') }} ({{ $generalPhotos->count() }})</h3>
                <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    @foreach($generalPhotos as $photo)
                        <a href="{{ $photo->url }}" target="_blank" class="group">
                            <img src="{{ $photo->url }}" class="rounded-lg object-cover w-full h-48 group-hover:opacity-80 transition" alt="">
                        </a>
                    @endforeach
                </div>
            </div>
        @endif

        @if($proofType === 'acknowledge' && $record->status === 'submitted')
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6 text-center">
                <p class="text-green-600 font-semibold">✅ {{ __('Acknowledged as completed') }}</p>
            </div>
        @endif
    </div>
</x-filament-panels::page>
