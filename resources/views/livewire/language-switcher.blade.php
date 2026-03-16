<div class="flex items-center ml-2">
    @php
        $isAr = app()->getLocale() === 'ar';
    @endphp

    <button wire:click="toggle" type="button" title="Switch Language / تغيير اللغة"
        class="flex items-center gap-x-2 px-3 py-1 text-xs font-bold rounded-full transition-colors border shadow-sm bg-gray-100 text-gray-700 border-gray-200 hover:bg-gray-200">
        <x-heroicon-m-language class="w-4 h-4" />
        <span>{{ $isAr ? 'English' : 'العربية' }}</span>
    </button>
</div>