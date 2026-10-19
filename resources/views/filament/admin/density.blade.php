@php $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]); @endphp
{{-- Row density for every table: sits next to the column manager. --}}
<div class="mt-density mt-pop-anchor" x-data="{ open: false }" x-on:keydown.escape.window="open = false">
    <button type="button" class="mt-tool-btn" x-on:click="open = ! open" x-bind:aria-expanded="open"
        aria-label="{{ $t('كثافة الصفوف', 'Row density') }}"
        x-tooltip="{ content: @js($t('كثافة الصفوف', 'Row density')), theme: $store.theme }">
        <x-filament::icon icon="heroicon-m-bars-3" class="h-4 w-4" />
    </button>
    <div class="mt-pop mt-pop-end mt-menu" x-show="open" x-cloak x-transition.opacity.duration.120ms x-on:click.outside="open = false">
        <p class="mt-pop-title">{{ $t('كثافة الصفوف', 'Row density') }}</p>
        @foreach (['compact' => ['مضغوط', 'Compact', 'heroicon-m-bars-4'], 'comfortable' => ['مريح', 'Comfortable', 'heroicon-m-bars-3'], 'spacious' => ['واسع', 'Spacious', 'heroicon-m-bars-2']] as $key => [$ar, $en, $icon])
            <button type="button" class="mt-menu-item" x-on:click="$store.mtDensity.set('{{ $key }}'); open = false"
                x-bind:aria-pressed="$store.mtDensity.v === '{{ $key }}'">
                <x-filament::icon :icon="$icon" class="mt-menu-icon" />
                <span class="flex-1">{{ $t($ar, $en) }}</span>
                <x-filament::icon icon="heroicon-m-check" class="mt-menu-check" x-show="$store.mtDensity.v === '{{ $key }}'" />
            </button>
        @endforeach
    </div>
</div>
