@auth
    <button type="button" class="mt-topbar-cmd" x-data x-on:click="$dispatch('mt-palette')">
        <x-filament::icon icon="heroicon-o-magnifying-glass" class="h-4 w-4 shrink-0" />
        <span>{{ \App\Support\AdminShell::t(['بحث أو أمر…', 'Search or run…']) }}</span>
        <kbd class="mt-kbd">⌘K</kbd>
    </button>
@endauth
