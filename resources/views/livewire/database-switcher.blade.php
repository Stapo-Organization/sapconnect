<div class="flex items-center">
    <button wire:click="toggle" type="button" title="Click to Switch Database"
        class="flex items-center gap-x-2 px-3 py-1 text-xs font-bold rounded-full transition-colors border shadow-sm
            {{ $isProd ? 'bg-green-100 text-green-700 border-green-200 hover:bg-green-200' : 'bg-amber-100 text-amber-700 border-amber-200 hover:bg-amber-200' }}">
        @if($isProd)
            <x-heroicon-m-check-circle class="w-4 h-4" />
            <span>Production ({{ $currentDb }})</span>
        @else
            <x-heroicon-m-beaker class="w-4 h-4" />
            <span>Test ({{ $currentDb }})</span>
        @endif

        <x-heroicon-m-arrow-path class="w-3 h-3 opacity-50 ml-1" />
    </button>
</div>