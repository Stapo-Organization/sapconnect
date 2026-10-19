@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $views = $this->views;
    $active = $activeId ? $views->firstWhere('id', $activeId) : null;
    $activeMine = $active && (int) $active->user_id === $me;
@endphp

{{-- Saved views as tabs inside the table card's toolbar (start side), Polaris-style. --}}
<div
    class="mt-views"
    x-data="{
        saveOpen: false,
        menuOpen: false,
        renaming: false,
        confirmDelete: false,
        name: '',
        shared: false,
        pinned: true,
        baseline: '',
        modified: false,
        keys: @js(\App\Livewire\Admin\TableViews::KEYS),
        norm(qs) {
            const out = [];
            for (const [k, v] of new URLSearchParams(qs)) {
                if (this.keys.includes(k.split('[')[0]) && v !== '') out.push(encodeURIComponent(k) + '=' + encodeURIComponent(v));
            }
            return out.sort().join('&');
        },
        current() { return this.norm(window.location.search) },
        columns() {
            try { return JSON.parse(JSON.stringify(this.$wire.$parent?.toggledTableColumns ?? {})) } catch (e) { return {} }
        },
        init() {
            this.baseline = this.current();
            const check = () => setTimeout(() => { this.modified = this.current() !== this.baseline }, 60);
            Livewire.hook('commit', ({ succeed }) => succeed(check));
        },
        submitSave() {
            if (! this.name.trim()) { this.$refs.name.focus(); return }
            this.$wire.save(this.name, this.current(), this.columns(), this.shared, this.pinned);
        },
    }"
    x-on:keydown.escape.window="saveOpen = false; menuOpen = false"
>
    <div class="mt-views-track" role="tablist" aria-label="{{ $t('العروض المحفوظة', 'Saved views') }}">
        <button type="button" role="tab" aria-selected="{{ $active ? 'false' : 'true' }}"
            @class(['mt-view', 'is-active' => ! $active]) wire:click="openAll">
            {{ $t('الكل', 'All') }}
        </button>

        @foreach ($views as $view)
            @php $isActive = $view->id === $activeId; $mine = (int) $view->user_id === $me; @endphp
            <div @class(['mt-view-wrap', 'mt-pop-anchor', 'is-active' => $isActive])>
                <button type="button" role="tab" aria-selected="{{ $isActive ? 'true' : 'false' }}"
                    @class(['mt-view', 'is-active' => $isActive])
                    @if ($isActive) x-on:click="menuOpen = ! menuOpen; saveOpen = false; renaming = false; confirmDelete = false" x-bind:aria-expanded="menuOpen"
                    @else wire:click="open({{ $view->id }})" @endif
                    @if (! $mine) title="{{ $t('مشترك من', 'Shared by') }} {{ $view->user?->name }}" @endif>
                    @if (! $mine)
                        <x-filament::icon icon="heroicon-m-user-group" class="mt-view-icon" />
                    @endif
                    <span>{{ $view->name }}</span>
                    @if ($isActive)
                        <span class="mt-view-dot" x-show="modified" x-cloak title="{{ $t('عُدّل ولم يُحفظ', 'Unsaved changes') }}"></span>
                        <x-filament::icon icon="heroicon-m-chevron-down" class="mt-view-caret" />
                    @endif
                </button>

                @if ($isActive)
                    <div class="mt-pop mt-menu" x-show="menuOpen" x-cloak x-transition.opacity.duration.120ms x-on:click.outside="menuOpen = false">
                        @if ($activeMine)
                            <button type="button" class="mt-menu-item" x-show="modified" x-on:click="$wire.overwrite({{ $view->id }}, current(), columns())">
                                <x-filament::icon icon="heroicon-m-arrow-down-tray" class="mt-menu-icon" />{{ $t('احفظ التعديلات على العرض', 'Save changes to view') }}
                            </button>
                            <button type="button" class="mt-menu-item" wire:click="togglePin({{ $view->id }})">
                                <x-filament::icon icon="heroicon-m-star" class="mt-menu-icon" />{{ $view->is_pinned ? $t('أزِله من الرئيسية', 'Unpin from home') : $t('ثبّته في الرئيسية', 'Pin to home') }}
                            </button>
                            <button type="button" class="mt-menu-item" wire:click="toggleShare({{ $view->id }})">
                                <x-filament::icon icon="heroicon-m-user-group" class="mt-menu-icon" />{{ $view->is_shared ? $t('أوقف المشاركة', 'Stop sharing') : $t('شاركه مع الفريق', 'Share with team') }}
                            </button>
                            <button type="button" class="mt-menu-item" x-show="! renaming" x-on:click="renaming = true; $nextTick(() => $refs.rename.focus())">
                                <x-filament::icon icon="heroicon-m-pencil" class="mt-menu-icon" />{{ $t('إعادة التسمية', 'Rename') }}
                            </button>
                            <form class="mt-rename" x-show="renaming" x-cloak x-on:submit.prevent="$wire.rename({{ $view->id }}, $refs.rename.value); renaming = false; menuOpen = false">
                                <input x-ref="rename" value="{{ $view->name }}" maxlength="80" aria-label="{{ $t('الاسم الجديد', 'New name') }}">
                                <button type="submit" class="mt-btn mt-btn-primary">{{ $t('حفظ', 'Save') }}</button>
                            </form>
                            <div class="mt-menu-sep"></div>
                            <button type="button" class="mt-menu-item is-danger" x-show="! confirmDelete" x-on:click="confirmDelete = true">
                                <x-filament::icon icon="heroicon-m-trash" class="mt-menu-icon" />{{ $t('حذف العرض', 'Delete view') }}
                            </button>
                            <button type="button" class="mt-menu-item is-danger is-confirm" x-show="confirmDelete" x-cloak wire:click="delete({{ $view->id }})">
                                {{ $t('تأكيد الحذف نهائياً', 'Confirm delete') }}
                            </button>
                        @else
                            <p class="mt-pop-hint">{{ $t('مشترك من', 'Shared by') }} {{ $view->user?->name }} — {{ $t('احفظ نسختك الخاصة لتعديله.', 'save your own copy to change it.') }}</p>
                        @endif
                    </div>
                @endif
            </div>
        @endforeach

        <div class="mt-pop-anchor">
            <button type="button" class="mt-view mt-view-add" x-on:click="saveOpen = ! saveOpen; menuOpen = false; $nextTick(() => $refs.name?.focus())"
                x-bind:aria-expanded="saveOpen" aria-label="{{ $t('حفظ كعرض', 'Save view') }}"
                x-tooltip="{ content: @js($t('احفظ الجدول كعرض', 'Save as view')), theme: $store.theme }">
                <x-filament::icon icon="heroicon-m-plus" class="h-4 w-4" />
            </button>
            <form class="mt-pop" x-show="saveOpen" x-cloak x-transition.opacity.duration.120ms x-on:click.outside="saveOpen = false" x-on:submit.prevent="submitSave()">
                <p class="mt-pop-title">{{ $t('حفظ الجدول كما تراه', 'Save the table as you see it') }}</p>
                <p class="mt-pop-hint">{{ $t('الفلاتر والبحث والترتيب والأعمدة الظاهرة.', 'Filters, search, sort and visible columns.') }}</p>
                <label class="mt-field">
                    <span>{{ $t('اسم العرض', 'View name') }}</span>
                    <input x-ref="name" x-model="name" maxlength="80" placeholder="{{ $t('مثال: شحنات متأخرة', 'e.g. Late shipments') }}">
                </label>
                <label class="mt-check"><input type="checkbox" x-model="pinned"> <span>{{ $t('ثبّته في الرئيسية', 'Pin to home') }}</span></label>
                <label class="mt-check"><input type="checkbox" x-model="shared"> <span>{{ $t('شاركه مع الفريق', 'Share with team') }}</span></label>
                <div class="mt-pop-actions">
                    <button type="button" class="mt-btn" x-on:click="saveOpen = false">{{ $t('إلغاء', 'Cancel') }}</button>
                    <button type="submit" class="mt-btn mt-btn-primary">{{ $t('حفظ', 'Save') }}</button>
                </div>
            </form>
        </div>
    </div>
</div>
