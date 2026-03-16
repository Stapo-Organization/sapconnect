<x-filament::widget class="fi-sap-status-widget">
    <div
        class="fixed bottom-4 right-4 z-50 flex items-center gap-x-2 px-3 py-2 text-white rounded-lg shadow-md opacity-90 hover:opacity-100 transition-opacity {{ $color }}">
        <x-heroicon-o-server class="w-4 h-4 animate-pulse" />
        <span class="font-bold text-xs tracking-wide">{{ $db }}</span>
    </div>
</x-filament::widget>