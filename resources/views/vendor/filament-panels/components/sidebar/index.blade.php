@props([
    'navigation',
])

{{--
    Muntajat shell (overrides Filament's sidebar): a dark rail of domains and a
    panel listing the chosen domain's screens in titled sections. Items still
    come from Filament's navigation, so permissions, badges and the active
    state are unchanged; App\Support\AdminShell only re-files them.
--}}
@php
    $openSidebarClasses = 'fi-sidebar-open w-[--sidebar-width] translate-x-0 shadow-xl ring-1 ring-gray-950/5 dark:ring-white/10 rtl:-translate-x-0';
    $domains = \App\Support\AdminShell::domains($navigation);
    $activeKey = collect($domains)->firstWhere('active', true)['key'] ?? ($domains[0]['key'] ?? 'home');
    $pinned = \App\Support\AdminShell::pinnedViews();
    $user = filament()->auth()->user();
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $badgeTone = fn (?string $c) => match ($c) { 'danger' => 'is-danger', 'warning' => 'is-warning', 'success' => 'is-success', default => '' };
@endphp

{{-- format-ignore-start --}}
<aside
    x-data="{ domain: @js($activeKey) }"
    x-cloak="-lg"
    x-bind:class="
        $store.sidebar.isOpen
            ? @js($openSidebarClasses . ' ' . 'lg:sticky')
            : 'w-[--sidebar-width] -translate-x-full rtl:translate-x-full lg:sticky'
    "
    {{ $attributes->class(['fi-sidebar mt-sidebar fixed inset-y-0 start-0 z-30 flex h-screen transition-all lg:z-0 lg:translate-x-0 rtl:lg:-translate-x-0 lg:transition-none']) }}
>
    <nav class="mt-rail" aria-label="{{ $t('أقسام النظام', 'Sections') }}">
        <a href="{{ filament()->getHomeUrl() }}" class="mt-rail-logo" aria-label="{{ $t('الرئيسية', 'Home') }}">م</a>

        @foreach ($domains as $d)
            <button
                type="button"
                class="mt-rail-btn"
                x-bind:class="{ 'is-active': domain === @js($d['key']) }"
                x-bind:aria-pressed="domain === @js($d['key'])"
                x-on:click="domain = @js($d['key'])"
                aria-label="{{ $d['label'] }}"
                x-tooltip="{ content: @js($d['label']), placement: document.dir === 'rtl' ? 'left' : 'right', theme: $store.theme }"
            >
                <x-filament::icon :icon="$d['icon']" class="h-5 w-5" />
                @if ($d['alert'])
                    <span class="mt-rail-dot" aria-hidden="true"></span>
                @endif
            </button>
            @if ($loop->first && count($domains) > 1)
                <span class="mt-rail-sep" aria-hidden="true"></span>
            @endif
        @endforeach

        <div class="mt-rail-foot">
            @if ($user)
                <a href="{{ filament()->getProfileUrl() }}" class="mt-rail-avatar" aria-label="{{ $t('ملفي', 'My profile') }}">
                    {{ mb_substr(filament()->getUserName($user), 0, 1) }}
                </a>
            @endif
        </div>
    </nav>

    <div class="mt-panel">
        {{ \Filament\Support\Facades\FilamentView::renderHook(\Filament\View\PanelsRenderHook::SIDEBAR_NAV_START) }}

        @foreach ($domains as $d)
            <div class="mt-panel-body fi-sidebar-nav" x-show="domain === @js($d['key'])" @if (! $d['active']) style="display: none" @endif>
                <div class="mt-panel-head">
                    <h2 class="mt-panel-title">{{ $d['label'] }}</h2>
                </div>

                @if ($d['key'] === 'home' && count($pinned))
                    <div class="mt-sec">
                        <p class="mt-sec-label">{{ $t('عروض مثبّتة', 'Pinned views') }}</p>
                        <ul>
                            @foreach ($pinned as $view)
                                @if ($url = $view->url())
                                    <li>
                                        <a href="{{ $url }}" @class(['mt-item', 'fi-active' => request()->integer('sv') === $view->id])>
                                            <x-filament::icon icon="heroicon-o-star" class="mt-item-icon" />
                                            <span class="mt-item-label">{{ $view->name }}</span>
                                        </a>
                                    </li>
                                @endif
                            @endforeach
                        </ul>
                    </div>
                @endif

                @foreach ($d['sections'] as $section)
                    <div class="mt-sec">
                        @if (count($d['sections']) > 1 || $d['key'] !== 'home')
                            <p class="mt-sec-label">{{ $section['label'] }}</p>
                        @endif
                        <ul>
                            @foreach ($section['items'] as $item)
                                <li @class(['fi-sidebar-item', 'fi-active' => $item['active']])>
                                    <a
                                        {{ \Filament\Support\generate_href_html($item['url'], $item['newTab']) }}
                                        x-on:click="window.matchMedia(`(max-width: 1024px)`).matches && $store.sidebar.close()"
                                        @class(['mt-item', 'fi-active' => $item['active']])
                                        @if ($item['active']) aria-current="page" @endif
                                    >
                                        @if (filled($item['icon']))
                                            <x-filament::icon :icon="$item['icon']" class="mt-item-icon" />
                                        @endif
                                        <span class="mt-item-label">{{ $item['label'] }}</span>
                                        @if (filled($item['badge']))
                                            <span @class(['mt-badge', $badgeTone($item['badgeColor'])])>{{ $item['badge'] }}</span>
                                        @endif
                                        @if ($item['newTab'])
                                            <x-filament::icon icon="heroicon-m-arrow-up-left" class="mt-item-ext" />
                                        @endif
                                    </a>
                                </li>
                            @endforeach
                        </ul>
                    </div>
                @endforeach
            </div>
        @endforeach

        {{ \Filament\Support\Facades\FilamentView::renderHook(\Filament\View\PanelsRenderHook::SIDEBAR_NAV_END) }}
        {{ \Filament\Support\Facades\FilamentView::renderHook(\Filament\View\PanelsRenderHook::SIDEBAR_FOOTER) }}
    </div>
</aside>
{{-- format-ignore-end --}}
