@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $hasQuery = mb_strlen(trim($q)) >= 2;
    $groups = collect($hasQuery ? $this->records : [])->groupBy('group');
@endphp

<div
    x-data="{
        open: false,
        q: '',
        idx: 0,
        screens: @js($screens),
        views: @js($views),
        actions: [
            { id: 'dark', label: @js($t('الوضع الداكن', 'Dark mode')), keywords: 'dark theme داكن ليلي' },
            { id: 'light', label: @js($t('الوضع الفاتح', 'Light mode')), keywords: 'light theme فاتح نهاري' },
            { id: 'locale', label: @js($t('English — تبديل اللغة', 'العربية — switch language')), keywords: 'language lang english arabic لغة انجليزي عربي' },
            { id: 'compact', label: @js($t('جداول مضغوطة', 'Compact tables')), keywords: 'density compact كثافة مضغوط' },
            { id: 'comfortable', label: @js($t('جداول مريحة', 'Comfortable tables')), keywords: 'density comfortable كثافة مريح' },
        ],
        norm(s) {
            return (s || '').toString().toLowerCase()
                .replace(/[ً-ْـ]/g, '')
                .replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي');
        },
        match(list, limit) {
            const q = this.norm(this.q).trim();
            if (! q) return list.slice(0, limit);
            const tokens = q.split(/\s+/);
            return list
                .map((it) => {
                    const label = this.norm(it.label);
                    const hay = label + ' ' + this.norm(it.keywords) + ' ' + this.norm(it.where);
                    if (! tokens.every((tk) => hay.includes(tk))) return null;
                    return { it, score: label.startsWith(q) ? 0 : label.includes(q) ? 1 : 2 };
                })
                .filter(Boolean)
                .sort((a, b) => a.score - b.score)
                .slice(0, limit)
                .map((x) => x.it);
        },
        get screenHits() { return this.match(this.screens, this.q ? 8 : 6) },
        get viewHits() { return this.match(this.q ? this.views : this.views.filter((v) => v.pinned), 5) },
        get actionHits() { return this.q ? this.match(this.actions, 3) : [] },
        show() {
            this.open = true;
            this.$nextTick(() => { this.$refs.input.focus(); this.$refs.input.select(); this.reset() });
        },
        close() { this.open = false },
        items() { return [...this.$refs.list.querySelectorAll('[data-mt-cmd]')] },
        paint() {
            this.items().forEach((el, i) => el.classList.toggle('is-active', i === this.idx));
            this.items()[this.idx]?.scrollIntoView({ block: 'nearest' });
        },
        reset() { this.idx = 0; this.$nextTick(() => this.paint()) },
        move(step) {
            const n = this.items().length;
            if (! n) return;
            this.idx = (this.idx + step + n) % n;
            this.paint();
        },
        go() { this.items()[this.idx]?.click() },
        run(id) {
            if (id === 'dark' || id === 'light') {
                localStorage.setItem('theme', id);
                window.dispatchEvent(new CustomEvent('theme-changed', { detail: id }));
                document.documentElement.classList.toggle('dark', id === 'dark');
            } else if (id === 'locale') {
                this.$wire.toggleLocale();
            } else {
                Alpine.store('mtDensity').set(id);
            }
            this.close();
        },
        init() {
            this.$watch('q', () => this.reset());
            new MutationObserver(() => this.paint()).observe(this.$refs.list, { childList: true, subtree: true });
        },
    }"
    x-on:keydown.window.prevent.meta.k="open ? close() : show()"
    x-on:keydown.window.prevent.ctrl.k="open ? close() : show()"
    x-on:mt-palette.window="show()"
>
    <div class="mt-cmd-overlay" x-show="open" x-cloak x-transition.opacity.duration.150ms x-on:click.self="close()" x-on:keydown.escape.window="close()">
        <div class="mt-cmd" role="dialog" aria-modal="true" aria-label="{{ $t('بحث وأوامر', 'Search and commands') }}" x-show="open" x-transition.scale.origin.top.duration.150ms>
            <label class="mt-cmd-input">
                <x-filament::icon icon="heroicon-o-magnifying-glass" class="h-5 w-5 shrink-0" />
                <input
                    x-ref="input"
                    x-model="q"
                    x-on:input.debounce.250ms="$wire.$set('q', q)"
                    x-on:keydown.down.prevent="move(1)"
                    x-on:keydown.up.prevent="move(-1)"
                    x-on:keydown.enter.prevent="go()"
                    placeholder="{{ $t('ابحث عن شاشة أو عرض أو سجل… منتج، مورد، طلب', 'Search screens, views or records… product, supplier, order') }}"
                    aria-label="{{ $t('بحث', 'Search') }}"
                    autocomplete="off"
                    spellcheck="false"
                >
                <span wire:loading wire:target="q" class="mt-cmd-spin" aria-hidden="true"></span>
                <kbd class="mt-kbd">Esc</kbd>
            </label>

            <div class="mt-cmd-list" x-ref="list">
                <template x-if="viewHits.length">
                    <div class="mt-cmd-group">
                        <p class="mt-cmd-group-label">{{ $t('العروض المحفوظة', 'Saved views') }}</p>
                        <template x-for="v in viewHits" :key="v.url">
                            <a data-mt-cmd class="mt-cmd-item" :href="v.url" x-on:mouseenter="idx = items().indexOf($el); paint()">
                                <x-filament::icon icon="heroicon-o-star" class="mt-cmd-icon" />
                                <span class="mt-cmd-label" x-text="v.label"></span>
                                <span class="mt-cmd-where" x-text="v.where"></span>
                            </a>
                        </template>
                    </div>
                </template>

                <template x-if="screenHits.length">
                    <div class="mt-cmd-group">
                        <p class="mt-cmd-group-label">{{ $t('الشاشات', 'Screens') }}</p>
                        <template x-for="s in screenHits" :key="s.url">
                            <a data-mt-cmd class="mt-cmd-item" :href="s.url" :target="s.newTab ? '_blank' : null" x-on:mouseenter="idx = items().indexOf($el); paint()">
                                <x-filament::icon icon="heroicon-o-rectangle-stack" class="mt-cmd-icon" />
                                <span class="mt-cmd-label" x-text="s.label"></span>
                                <span class="mt-cmd-where" x-text="s.where"></span>
                            </a>
                        </template>
                    </div>
                </template>

                @if ($hasQuery)
                    @foreach ($groups as $group => $rows)
                        <div class="mt-cmd-group" wire:key="g-{{ md5($group) }}">
                            <p class="mt-cmd-group-label">{{ $group }}</p>
                            @foreach ($rows as $row)
                                <a data-mt-cmd class="mt-cmd-item" href="{{ $row['url'] }}" x-on:mouseenter="idx = items().indexOf($el); paint()" wire:key="r-{{ md5($row['url']) }}">
                                    <x-filament::icon icon="heroicon-o-document-text" class="mt-cmd-icon" />
                                    <span class="mt-cmd-label">{{ $row['title'] }}</span>
                                    @if ($row['sub'])
                                        <span class="mt-cmd-where">{{ $row['sub'] }}</span>
                                    @endif
                                </a>
                            @endforeach
                        </div>
                    @endforeach
                @endif

                <template x-if="actionHits.length">
                    <div class="mt-cmd-group">
                        <p class="mt-cmd-group-label">{{ $t('أوامر', 'Commands') }}</p>
                        <template x-for="a in actionHits" :key="a.id">
                            <button type="button" data-mt-cmd class="mt-cmd-item" x-on:click="run(a.id)" x-on:mouseenter="idx = items().indexOf($el); paint()">
                                <x-filament::icon icon="heroicon-o-command-line" class="mt-cmd-icon" />
                                <span class="mt-cmd-label" x-text="a.label"></span>
                            </button>
                        </template>
                    </div>
                </template>

                @if ($hasQuery && $groups->isEmpty())
                    <p class="mt-cmd-empty" x-show="! screenHits.length && ! viewHits.length && ! actionHits.length" wire:loading.remove wire:target="q">
                        {{ $t('لا نتائج مطابقة.', 'No matches.') }}
                    </p>
                @endif
            </div>

            <div class="mt-cmd-foot">
                <span><kbd class="mt-kbd">↑</kbd><kbd class="mt-kbd">↓</kbd> {{ $t('للتنقل', 'to move') }}</span>
                <span><kbd class="mt-kbd">Enter</kbd> {{ $t('للفتح', 'to open') }}</span>
                <span class="mt-cmd-foot-end"><kbd class="mt-kbd">⌘</kbd><kbd class="mt-kbd">K</kbd> {{ $t('من أي مكان', 'from anywhere') }}</span>
            </div>
        </div>
    </div>
</div>
