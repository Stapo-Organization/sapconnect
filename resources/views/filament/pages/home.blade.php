@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $user = filament()->auth()->user();
    $firstName = \Illuminate\Support\Str::of(filament()->getUserName($user))->explode(' ')->first();
    $pinned = $this->pinned();
    $shortcuts = $this->shortcuts();
    $health = $this->health();
    $today = now('Asia/Riyadh')->locale(app()->getLocale());
    $problems = collect($health)->where('tone', 'danger')->count();
@endphp

<x-filament-panels::page class="mt-home">
    {{-- greeting + command in one band --}}
    <section class="mt-home-top">
        <div class="mt-home-greet">
            <p class="mt-home-date">{{ $today->translatedFormat('l j F') }}</p>
            <h1 class="mt-home-title">{{ $this->greeting() }}، {{ $firstName }}</h1>
        </div>
        <button type="button" class="mt-home-command" x-data x-on:click="$dispatch('mt-palette')">
            <x-filament::icon icon="heroicon-o-magnifying-glass" class="h-4 w-4 shrink-0" />
            <span>{{ $t('ابحث عن شاشة أو منتج أو مورد أو طلب…', 'Search a screen, product, supplier or order…') }}</span>
            <kbd class="mt-kbd">⌘K</kbd>
        </button>
    </section>

    @if ($this->showKpis())
        <section class="mt-home-kpis">
            <div class="mt-card-head">
                <h2>{{ $t('التجزئة اليوم', 'Retail today') }}</h2>
                @if ($retail = \App\Support\AdminShell::screenUrl('retail-dashboard'))
                    <a href="{{ $retail }}" class="mt-link">{{ $t('التفاصيل', 'Details') }}</a>
                @endif
            </div>
            @livewire(\App\Livewire\Admin\HomeKpis::class, [], key('home-kpis'))
        </section>
    @endif

    <div class="mt-home-grid">
        <div class="mt-home-main">
        {{-- pinned views --}}
        <section class="mt-panel-card" wire:init="loadCounts">
            <div class="mt-card-head">
                <h2>{{ $t('عروضك المثبّتة', 'Pinned views') }}</h2>
                <span class="mt-card-meta">{{ $t('جدول + فلاتر + أعمدة، بعدد حي', 'Table + filters + columns, live count') }}</span>
            </div>

            @if (count($pinned))
                <ul class="mt-rows">
                    @foreach ($pinned as $view)
                        @php $url = $view->url(); @endphp
                        @continue(! $url)
                        <li wire:key="pin-{{ $view->id }}">
                            <a href="{{ $url }}" class="mt-row">
                                <span class="mt-row-icon"><x-filament::icon icon="heroicon-m-star" class="h-4 w-4" /></span>
                                <span class="mt-row-main">
                                    <span class="mt-row-title">{{ $view->name }}</span>
                                    <span class="mt-row-sub">
                                        {{ \App\Support\AdminShell::screenLabel(\App\Support\AdminShell::pathKey($view->baseUrl())) ?? $t('جدول', 'Table') }}
                                        @foreach (\App\Support\SavedViewCounter::summary($view) as $tag)
                                            · {{ $tag }}
                                        @endforeach
                                    </span>
                                </span>
                                <span class="mt-row-count">
                                    @if (! $countsLoaded)
                                        <span class="mt-skel" aria-label="{{ $t('جارٍ العد', 'Counting') }}"></span>
                                    @elseif (($counts[$view->id] ?? null) === null)
                                        —
                                    @else
                                        {{ number_format($counts[$view->id]) }}
                                    @endif
                                </span>
                                <x-filament::icon :icon="\App\Support\AdminShell::isArabic() ? 'heroicon-m-chevron-left' : 'heroicon-m-chevron-right'" class="mt-row-go" />
                            </a>
                        </li>
                    @endforeach
                </ul>
            @else
                <div class="mt-empty">
                    <span class="mt-empty-icon"><x-filament::icon icon="heroicon-o-star" class="h-5 w-5" /></span>
                    <div>
                        <p class="mt-empty-title">{{ $t('ثبّت أهم جداولك هنا', 'Pin your key tables here') }}</p>
                        <p class="mt-empty-text">{{ $t('افتح أي جدول، اضبط الفلاتر والأعمدة، ثم اضغط + بجانب «الكل» واختر «ثبّته في الرئيسية».', 'Open any table, set filters and columns, press + next to “All” and tick “Pin to home”.') }}</p>
                    </div>
                </div>
            @endif
        </section>

        @if (count($health))
            <section class="mt-panel-card">
                <div class="mt-card-head">
                    <h2>{{ $t('صحة التكامل', 'Integration health') }}</h2>
                    @if ($problems)
                        <span class="mt-pill is-danger">{{ $problems }} {{ $t('متعطلة', 'failing') }}</span>
                    @else
                        <span class="mt-pill is-ok">{{ $t('سليمة', 'Healthy') }}</span>
                    @endif
                </div>
                <ul class="mt-health">
                    @foreach ($health as $h)
                        <li class="mt-health-item">
                            <span @class(['mt-dot', 'is-danger' => $h['tone'] === 'danger', 'is-muted' => $h['tone'] === 'muted'])></span>
                            <span class="mt-health-name">{{ $h['name'] }}</span>
                            <span class="mt-row-when">{{ $h['when'] }}</span>
                        </li>
                    @endforeach
                </ul>
                @if ($url = $this->automationsUrl())
                    <a href="{{ $url }}" class="mt-card-foot">{{ $t('كل الأتمتة', 'All automations') }}</a>
                @endif
            </section>
        @endif
    </div>

        <aside class="mt-home-side">
            @if (count($shortcuts))
                <section class="mt-panel-card">
                    <div class="mt-card-head"><h2>{{ $t('وصول سريع', 'Quick access') }}</h2></div>
                    <ul class="mt-rows">
                        @foreach ($shortcuts as $s)
                            <li>
                                <a href="{{ $s['url'] }}" class="mt-row is-compact">
                                    <span class="mt-row-main">
                                        <span class="mt-row-title">{{ $s['label'] }}</span>
                                        <span class="mt-row-sub">{{ $s['where'] }}</span>
                                    </span>
                                    <x-filament::icon :icon="\App\Support\AdminShell::isArabic() ? 'heroicon-m-chevron-left' : 'heroicon-m-chevron-right'" class="mt-row-go" />
                                </a>
                            </li>
                        @endforeach
                    </ul>
                </section>
            @endif

        </aside>
    </div>
</x-filament-panels::page>
