@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $b = $this->board();
    $T = $b['totals'];
    $P = $b['params'];
    $label = fn (string $code) => \App\Services\Inventory\BranchGapService::warehouseLabel($code);
    $n = fn ($v) => number_format((float) $v, abs((float) $v) >= 10 || fmod((float) $v, 1) == 0.0 ? 0 : 1);
    $to = \App\Support\AdminShell::isArabic() ? '←' : '→';
    $canRequest = \App\Filament\Pages\BranchStockGaps::canRequest();
    $tgt = $label($P['target']);
    $src = $label($P['source']);
    $tabs = [
        'all' => ['كل الناقص', 'All gaps'],
        'out' => ['نافد تماماً', 'Out of stock'],
        'transfer' => ['قابل للتحويل', 'Transferable'],
        'none' => ['بدون فائض في المصدر', 'No spare at source'],
    ];
@endphp

<x-filament-panels::page class="gx-page">
<div
    x-data="{
        sel: {},
        note: '',
        confirm: false,
        busy: false,
        get count() { return Object.keys(this.sel).length },
        get pcs() { return Object.values(this.sel).reduce((a, v) => a + (parseInt(v) || 0), 0) },
        toggle(code, suggest) { if (code in this.sel) { delete this.sel[code] } else { this.sel[code] = suggest || 1 } },
        pickAll() { this.$root.querySelectorAll('[data-gx-code]').forEach(el => { const s = parseInt(el.dataset.gxSuggest) || 0; if (s > 0 && !(el.dataset.gxCode in this.sel)) this.sel[el.dataset.gxCode] = s }) },
        clear() { this.sel = {} },
        lines() { return Object.entries(this.sel).map(([c, q]) => ({ item_code: c, quantity: parseInt(q) || 0 })).filter(l => l.quantity > 0) },
        async send() {
            this.busy = true
            await $wire.requestTransfer(this.lines(), this.note)
            this.busy = false
            this.confirm = false
        },
    }"
    x-on:gaps-requested.window="sel = {}; note = ''"
    x-on:gaps-reset.window="sel = {}"
    class="gx"
>
    <header class="gx-head">
        <div>
            <h1 class="gx-title">{{ $t('عجز الفروع', 'Branch gaps') }}</h1>
            <p class="gx-sub">{{ $t('أصناف تبيع في المعارض وأونلاين على شيب قو، ومخزونها ضعيف في', 'Items that sell in the showrooms and online on ShipGo but run thin at') }} <strong>{{ $tgt }}</strong> · {{ $t('ونقترح تحويلها من', 'suggested from') }} <strong>{{ $src }}</strong></p>
        </div>
        <div class="gx-head-tools">
            <button type="button" class="gx-btn" wire:click="refreshBoard" wire:loading.attr="disabled">
                <x-filament::icon icon="heroicon-m-arrow-path" class="gx-ico" wire:loading.class="gx-spin" wire:target="refreshBoard" />
                {{ $t('تحديث', 'Refresh') }}
            </button>
            <button type="button" class="gx-btn" wire:click="export">
                <x-filament::icon icon="heroicon-m-arrow-down-tray" class="gx-ico" />
                {{ $t('تصدير Excel', 'Export Excel') }}
            </button>
        </div>
    </header>

    <section class="gx-controls">
        <label class="gx-field">
            <span>{{ $t('من', 'From') }}</span>
            <select wire:model.live="source">
                @foreach ($b['sources'] as $code => $name)
                    <option value="{{ $code }}">{{ $name }}</option>
                @endforeach
            </select>
        </label>
        <x-filament::icon icon="heroicon-m-arrow-long-left" class="gx-ico gx-arrow" />
        <label class="gx-field">
            <span>{{ $t('إلى الفرع الناقص', 'To the branch short') }}</span>
            <select wire:model.live="target">
                @foreach (\App\Filament\Pages\BranchStockGaps::TARGETS as $code)
                    <option value="{{ $code }}">{{ $label($code) }}</option>
                @endforeach
            </select>
        </label>
        <span class="gx-sep"></span>
        <label class="gx-field">
            <span>{{ $t('فترة المبيعات', 'Sales window') }}</span>
            <select wire:model.live="window">
                @foreach ([30, 60, 90] as $v)<option value="{{ $v }}">{{ $v }} {{ $t('يوم', 'days') }}</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('يغطي الفرع', 'Cover at branch') }}</span>
            <select wire:model.live="cover">
                @foreach ([7, 14, 21, 30] as $v)<option value="{{ $v }}">{{ $v }} {{ $t('يوم', 'days') }}</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('يبقى في المصدر', 'Source keeps') }}</span>
            <select wire:model.live="keep">
                @foreach ([14, 30, 45, 60] as $v)<option value="{{ $v }}">{{ $v }} {{ $t('يوم', 'days') }}</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('نصيب الفرع من الأونلاين', 'Branch share of online') }}</span>
            <select wire:model.live="share">
                @foreach ([0, 5, 10, 20, 30] as $v)<option value="{{ $v }}">{{ $v }}%</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('صنف «يبيع» من', 'Counts as selling from') }}</span>
            <select wire:model.live="min">
                @foreach ([5, 10, 20, 40, 80] as $v)<option value="{{ $v }}">{{ $v }} {{ $t('حبة/شهر', 'pcs/month') }}</option>@endforeach
            </select>
        </label>
    </section>

    <section class="gx-controls gx-focus">
        <span class="gx-focus-title">
            <x-filament::icon icon="heroicon-m-funnel" class="gx-ico" />
            {{ $t('ركّز على', 'Focus on') }}
        </span>
        <div class="gx-seg" role="group" aria-label="{{ $t('الأهم', 'Most important') }}">
            @foreach (['all' => ['الكل', 'All'], '50' => ['أهم 50', 'Top 50'], '100' => ['أهم 100', 'Top 100'], '200' => ['أهم 200', 'Top 200'], 'p80' => ['80% من الخسارة', '80% of the loss']] as $key => $lab)
                <button type="button" wire:click="$set('top', '{{ $key }}')" @class(['gx-seg-btn', 'is-active' => $top === $key]) aria-pressed="{{ $top === $key ? 'true' : 'false' }}">{{ $t(...$lab) }}</button>
            @endforeach
        </div>
        <label class="gx-field">
            <span>{{ $t('الحيوان', 'Pet') }}</span>
            <select wire:model.live="pet">
                <option value="">{{ $t('الكل', 'All') }}</option>
                @foreach ($b['facets']['pets'] as $name => $count)<option value="{{ $name }}">{{ $name }} ({{ $count }})</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('القسم', 'Department') }}</span>
            <select wire:model.live="dept" @disabled($pet === '')>
                <option value="">{{ $pet === '' ? $t('اختر الحيوان أولاً', 'Pick a pet first') : $t('الكل', 'All') }}</option>
                @foreach ($b['facets']['depts'] as $name => $count)<option value="{{ $name }}">{{ \Illuminate\Support\Str::after($name, ' › ') }} ({{ $count }})</option>@endforeach
            </select>
        </label>
        <label class="gx-field">
            <span>{{ $t('العلامة التجارية', 'Brand') }}</span>
            <select wire:model.live="brand">
                <option value="">{{ $t('الكل', 'All') }}</option>
                @foreach ($b['facets']['brands'] as $name => $count)<option value="{{ $name }}">{{ $name }} ({{ $count }})</option>@endforeach
            </select>
        </label>
        @if ($top !== 'all' || $pet !== '' || $brand !== '')
            <span class="gx-focus-note">{{ number_format($T['items']) }} {{ $t('صنف تمثل', 'items carry') }} <b dir="ltr">{{ $b['top_share'] }}%</b> {{ $t('من خسارة القائمة', 'of the listed loss') }}</span>
        @endif
    </section>

    @if ($result)
        <div @class(['gx-banner', 'is-ok' => $result['ok'], 'is-bad' => ! $result['ok']])>
            @if ($result['ok'])
                <x-filament::icon icon="heroicon-m-check-circle" class="gx-ico" />
                <span>{{ count($result['docs']) > 1 ? $t('تم إنشاء طلبات التحويل في ساب', 'SAP transfer requests') : $t('تم إنشاء طلب التحويل في ساب رقم', 'SAP transfer request') }} <strong>{{ collect($result['docs'])->map(fn ($d) => '#' . $d)->join('، ') }}</strong> · {{ $result['lines'] }} {{ $t('صنف', 'items') }} · {{ number_format($result['pcs']) }} {{ $t('حبة', 'pcs') }}. {{ $t('يظهر لفرع', 'It shows in HUB for') }} {{ $src }} {{ $t('في تطبيق HUB للتجهيز والإرسال.', 'to prepare and send.') }}</span>
            @else
                <x-filament::icon icon="heroicon-m-exclamation-triangle" class="gx-ico" />
                <span>@if (! empty($result['docs'])){{ $t('أُنشئ في ساب', 'Created in SAP') }} {{ collect($result['docs'])->map(fn ($d) => '#' . $d)->join('، ') }}، {{ $t('لكن', 'but') }} @endif{{ $t('ساب رفض الطلب', 'SAP refused the request') }} ({{ $result['reference'] }}): {{ $result['error'] }}</span>
            @endif
        </div>
    @endif

    <section class="gx-kpis" wire:loading.class="is-loading">
        <div class="gx-kpi">
            <span class="gx-kpi-l">{{ $t('أصناف ناقصة', 'Items short') }}</span>
            <span class="gx-kpi-v">{{ number_format($T['items']) }}</span>
            <span class="gx-kpi-s">{{ $t('منها', 'of which') }} <b class="is-warm">{{ number_format($T['out']) }}</b> {{ $t('نافدة تماماً', 'fully out') }} · {{ number_format($T['gap_pcs']) }} {{ $t('حبة عجز', 'pcs short') }}</span>
        </div>
        <div class="gx-kpi">
            <span class="gx-kpi-l">{{ $t('نقدر نحوّلها من', 'Transferable from') }} {{ $src }}</span>
            <span class="gx-kpi-v is-accent">{{ number_format($T['transferable']) }}</span>
            <span class="gx-kpi-s">{{ number_format($T['transfer_pcs']) }} {{ $t('حبة، ويبقى للمصدر حاجته', 'pcs, and the source keeps what it needs') }}</span>
        </div>
        <div class="gx-kpi">
            <span class="gx-kpi-l">{{ $t('ما فيها فائض في', 'No spare at') }} {{ $src }}</span>
            <span class="gx-kpi-v">{{ number_format($T['no_source']) }}</span>
            <span class="gx-kpi-s">{{ $t('نوضح لك مصدر بديل إن وُجد', 'an alternative source is shown when one exists') }}</span>
        </div>
        <div class="gx-kpi">
            <span class="gx-kpi-l">{{ $t('مبيعات ضائعة شهرياً', 'Sales lost a month') }}</span>
            <span class="gx-kpi-v is-warm">{{ number_format($T['lost_value']) }}</span>
            <span class="gx-kpi-s">{{ $t('ريال في', 'SAR at') }} {{ $tgt }} {{ $t('لو ما تحرّكنا · بدون ضريبة', 'if nothing moves · ex-VAT') }}</span>
            <span class="gx-kpi-s gx-kpi-halo">+ <b>{{ number_format($T['halo_value']) }}</b> {{ $t('أثر على الفاتورة (تقديري)', 'basket effect (estimate)') }}</span>
        </div>
    </section>

    <section class="gx-card">
        <div class="gx-card-head">
            <div class="gx-tabs" role="tablist">
                @foreach ($tabs as $key => $lab)
                    <button type="button" role="tab" wire:click="setTab('{{ $key }}')" @class(['gx-tab', 'is-active' => $tab === $key]) aria-selected="{{ $tab === $key ? 'true' : 'false' }}">
                        {{ $t(...$lab) }} <span class="gx-tab-n">{{ number_format($b['tabs'][$key]) }}</span>
                    </button>
                @endforeach
            </div>
            <div class="gx-card-tools">
                <input type="search" wire:model.live.debounce.400ms="q" class="gx-search" placeholder="{{ $t('ابحث بالاسم أو الكود أو الباركود', 'Search name, code or barcode') }}">
                @if ($canRequest)
                    <button type="button" class="gx-btn" x-on:click="pickAll()">{{ $t('حدد كل القابل للتحويل', 'Select all transferable') }}</button>
                @endif
            </div>
        </div>

        <div class="gx-grid-wrap" wire:loading.class="is-loading">
            <table class="gx-grid">
                <thead>
                    <tr>
                        @if ($canRequest)<th class="gx-c-check"></th>@endif
                        <th class="is-num gx-c-rank">#</th>
                        <th>{{ $t('المنتج', 'Product') }}</th>
                        <th class="is-num">{{ $t('يبيع شهرياً', 'Sells a month') }}</th>
                        <th class="is-num">{{ $tgt }}</th>
                        <th class="is-num">{{ $t('الهدف', 'Goal') }}</th>
                        <th class="is-num">{{ $t('العجز', 'Gap') }}</th>
                        <th class="is-num">{{ $t('يضيع شهرياً', 'Lost a month') }}</th>
                        <th class="is-num">{{ $src }}</th>
                        <th class="is-num">{{ $t('نطلب', 'Request') }}</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($b['rows'] as $r)
                        <tr wire:key="gx-{{ $r['code'] }}" @if ($r['source_spare'] > 0) data-gx-code="{{ $r['code'] }}" data-gx-suggest="{{ $r['suggest'] }}" @endif :class="('{{ $r['code'] }}' in sel) && 'is-picked'">
                            @if ($canRequest)
                                <td class="gx-c-check">
                                    @if ($r['source_spare'] > 0)
                                        <input type="checkbox" class="gx-check" :checked="'{{ $r['code'] }}' in sel" x-on:change="toggle('{{ $r['code'] }}', {{ $r['suggest'] }})" aria-label="{{ $r['code'] }}">
                                    @endif
                                </td>
                            @endif
                            <td class="is-num gx-c-rank">
                                <span class="gx-rank">{{ $r['rank'] }}</span>
                                <span class="gx-mini" dir="ltr" title="{{ $t('نسبة الخسارة المتراكمة حتى هذا الصنف', 'Cumulative share of the loss up to this item') }}">{{ $r['cum'] }}%</span>
                            </td>
                            <td>
                                <div class="gx-prod">
                                    <span class="gx-thumb"><img src="{{ $r['image'] }}" alt="" loading="lazy" onerror="this.style.visibility='hidden'"></span>
                                    <span class="gx-prod-main">
                                        <span class="gx-prod-name" title="{{ $r['name'] }}">{{ $r['name'] }}</span>
                                        <span class="gx-prod-sub">
                                            <span class="gx-code">{{ $r['code'] }}</span>
                                            @if ($r['barcode'])<span class="gx-code">{{ $r['barcode'] }}</span>@endif
                                            @if ($r['out'])<span class="gx-pill is-warm">{{ $t('نافد', 'Out') }}</span>@endif
                                        </span>
                                    </span>
                                </div>
                            </td>
                            <td class="is-num">
                                <div class="gx-stack">
                                    <span><b>{{ $n($r['show_month']) }}</b> <i>{{ $t('معارض', 'showrooms') }}</i></span>
                                    <span><b>{{ $n($r['online_month']) }}</b> <i>{{ $t('أونلاين', 'online') }}</i></span>
                                    <span class="gx-mini">{{ $t('في', 'in') }} {{ $r['branches'] }} {{ $t('فرع', 'branches') }}</span>
                                </div>
                            </td>
                            <td class="is-num">
                                <div class="gx-stack">
                                    <span><b @class(['is-warm' => $r['out']])>{{ $n($r['on_hand']) }}</b> <i>{{ $t('عنده', 'on hand') }}</i></span>
                                    @if ($r['coming'] > 0)<span><b>{{ $n($r['coming']) }}</b> <i>{{ $t('بالطريق', 'on the way') }}</i></span>@endif
                                    <span class="gx-mini">@if (! $r['out'] && $r['cover_days'] !== null){{ $t('يكفي', 'lasts') }} {{ $r['cover_days'] }} {{ $t('يوم', 'days') }} · @endif{{ $t('متوقع', 'expected') }} {{ $n($r['est_month']) }}/{{ $t('شهر', 'mo') }}</span>
                                </div>
                            </td>
                            <td class="is-num"><b>{{ $r['goal'] }}</b></td>
                            <td class="is-num"><span class="gx-gap">{{ $r['gap'] }}</span></td>
                            <td class="is-num">
                                <div class="gx-stack">
                                    <span><b class="is-warm">{{ number_format($r['lost_value']) }}</b> <i>{{ $t('ريال', 'SAR') }}</i></span>
                                    @if ($r['halo_value'] > 0)
                                        <span class="gx-mini" title="{{ $t('في', 'In') }} {{ $r['anchor_pct'] }}% {{ $t('من فواتيره هو الصنف الأغلى، فالعميل غالباً جاء علشانه', 'of its invoices it is the biggest line, so the visit was likely for it') }}">+ {{ number_format($r['halo_value']) }} {{ $t('فاتورة', 'basket') }}</span>
                                    @endif
                                    <span class="gx-mini">{{ $r['lost_days'] }} {{ $t('يوم بدون مخزون', 'days empty') }}</span>
                                </div>
                            </td>
                            <td class="is-num">
                                <div class="gx-stack">
                                    <span><b>{{ $n($r['source_on_hand']) }}</b> <i>{{ $t('عنده', 'on hand') }}</i></span>
                                    @if ($r['source_spare'] > 0)
                                        <span class="gx-mini is-accent">{{ $t('يقدر يعطي', 'can spare') }} {{ $r['source_spare'] }}</span>
                                    @else
                                        <span class="gx-mini">{{ $t('ما عنده فائض', 'no spare') }}</span>
                                    @endif
                                    @if ($r['status'] !== 'full' && $r['alt'])
                                        <span class="gx-mini gx-alt">{{ $t('متوفر في', 'spare at') }} {{ $r['alt']['name'] }}: {{ $r['alt']['spare'] }}</span>
                                    @endif
                                </div>
                            </td>
                            <td class="is-num">
                                @if ($r['source_spare'] > 0 && $canRequest)
                                    <input type="number" min="0" max="{{ (int) $r['source_spare'] }}" step="1" class="gx-qty"
                                        :value="sel['{{ $r['code'] }}'] ?? {{ $r['suggest'] }}"
                                        x-on:input="const v = Math.max(0, Math.min({{ (int) $r['source_spare'] }}, parseInt($event.target.value) || 0)); if (v > 0) { sel['{{ $r['code'] }}'] = v } else { delete sel['{{ $r['code'] }}'] }">
                                @elseif ($r['suggest'] > 0)
                                    <b>{{ $r['suggest'] }}</b>
                                @else
                                    <span class="gx-mini">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="10" class="gx-empty">{{ $t('ما فيه عجز بهذه الإعدادات. جرّب فترة أطول أو حد مبيعات أقل.', 'No gaps with these settings. Try a longer window or a lower selling threshold.') }}</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        @if ($b['shown'] > count($b['rows']))
            <p class="gx-note">{{ $t('معروض أول', 'Showing the first') }} {{ count($b['rows']) }} {{ $t('من', 'of') }} {{ number_format($b['shown']) }} · {{ $t('ابحث أو استخدم التصدير للباقي.', 'search or export for the rest.') }}</p>
        @endif
    </section>

    <details class="gx-card gx-how">
        <summary>{{ $t('كيف نحسب العجز؟', 'How the gap is worked out') }}</summary>
        <ul>
            <li>{{ $t('مبيعات المعارض: كاشير التجزئة C0000001 في كل المعارض خلال آخر', 'Showroom sales: retail register C0000001 across every showroom over the last') }} {{ $P['window'] }} {{ $t('يوم، بعد خصم المرتجعات.', 'days, net of returns.') }}</li>
            <li>{{ $t('مبيعات الأونلاين: فواتير متاجر شيب قو من مستودعاتها (الرياض، جدة، عنيزة). تقارير المتاجر تُرفع شهرياً، فآخر بيانات حتى', 'Online sales: ShipGo store invoices from its warehouses (Riyadh, Jeddah, Unaizah). Store reports are posted monthly; latest data up to') }} {{ $b['online_until'] ?? '—' }}.</li>
            <li>{{ $t('بيع الفرع المتوقع = الأعلى بين بيعه الفعلي ومتوسط معرض في الرياض، زائد', 'Expected branch sales = the higher of its own sales and an average Riyadh showroom, plus') }} {{ $P['online_share'] }}% {{ $t('من طلب الأونلاين (طلبات إكسبريس الرياض).', 'of online demand (Riyadh express orders).') }}</li>
            <li>{{ $t('المبيعات الضائعة: لو ما وصلها شي، كم يوم من الـ30 الجاية يكون الرف فاضي (بعد ما يخلص المخزون واللي بالطريق) × بيعها اليومي × متوسط سعر الحبة في المعارض.', 'Lost sales: if nothing arrives, how many of the next 30 days the shelf stands empty (after stock and what is on the way run out) × daily sales × the average showroom piece price.') }}</li>
            <li>{{ $t('أثر على الفاتورة (تقديري): من فواتير المعارض، الفاتورة اللي يكون فيها الصنف هو الأغلى نعتبر العميل جاء علشانه، وقيمة باقي أصنافها ممكن تضيع معه. نضرب متوسط هذي القيمة لكل فاتورة × عدد الفواتير اللي تضيع. هذا تقدير أعلى، لأن بعض العملاء يشترون الباقي على أي حال.', 'Basket effect (estimate): on showroom invoices where the item is the biggest line we assume the visit was for it, so the other lines may leave with it. Their average value per invoice × the invoices lost. An upper estimate: some customers buy the rest anyway.') }}</li>
            <li>{{ $t('الترتيب حسب الضائع + أثر الفاتورة، فالأهم فوق. «أهم 50/100/200» تأخذ الأعلى من القائمة بعد فلتر الحيوان والقسم والعلامة، و«80% من الخسارة» تأخذ أقل عدد أصناف يغطي 80% منها، وهذا أنسب للفروع الصغيرة. الرقم تحت # هو نسبة الخسارة المتراكمة حتى هذا الصنف.', 'Sorted by lost sales + basket effect. «Top 50/100/200» keep the top of the list after the pet, department and brand filters; «80% of the loss» keeps the fewest items covering 80% of it, the right cut for a small branch. The figure under # is the cumulative share of the loss.') }}</li>
            <li>{{ $t('الهدف = بيع', 'Goal =') }} {{ $P['cover'] }} {{ $t('يوم، وما يقل عن 3 حبات على الرف. العجز = الهدف − المخزون − اللي بالطريق في طلبات تحويل مفتوحة.', 'days of sales, never under 3 on the shelf. Gap = goal − stock − what open transfer requests are already bringing.') }}</li>
            <li>{{ $t('المصدر يعطي فقط فائضه: مخزونه المتاح ناقص بيعه لـ', 'The source only gives its surplus: its free stock less') }} {{ $P['keep'] }} {{ $t('يوم، ويبقى عنده 3 حبات على الأقل.', 'days of its own sales, keeping at least 3 on its shelf.') }}</li>
            <li>{{ $t('المخزون من نسخة ساب المحلية (تتحدث كل 10 دقائق). الطلب يُنشأ في ساب كـ«طلب تحويل مخزون» بالحبة، وما يحرّك المخزون حتى يرسله الفرع.', 'Stock comes from the local SAP mirror (refreshed every 10 minutes). The request is created in SAP as an inventory transfer request, in pieces, and moves nothing until the branch sends it.') }}</li>
        </ul>
    </details>

    @if ($b['history']->isNotEmpty())
        <section class="gx-card">
            <div class="gx-card-head"><h2 class="gx-h2">{{ $t('آخر الطلبات من هذه الصفحة', 'Recent requests from this page') }}</h2></div>
            <div class="gx-grid-wrap">
                <table class="gx-grid">
                    <thead><tr>
                        <th>{{ $t('ساب', 'SAP') }}</th><th>{{ $t('المسار', 'Route') }}</th><th class="is-num">{{ $t('أصناف', 'Items') }}</th><th class="is-num">{{ $t('حبات', 'Pcs') }}</th><th>{{ $t('بواسطة', 'By') }}</th><th>{{ $t('الوقت', 'When') }}</th>
                    </tr></thead>
                    <tbody>
                        @foreach ($b['history'] as $h)
                            <tr>
                                <td>
                                    @if ($h->status === 'posted')<b>#{{ $h->doc_num }}</b>
                                    @else <span class="gx-pill is-warm" title="{{ $h->error }}">{{ $t('فشل', 'Failed') }}</span>@endif
                                    <span class="gx-code">{{ $h->reference }}</span>
                                </td>
                                <td>{{ $label($h->from_warehouse) }} {{ $to }} {{ $label($h->to_warehouse) }}</td>
                                <td class="is-num">{{ count($h->lines ?? []) }}</td>
                                <td class="is-num">{{ number_format($h->total_quantity) }}</td>
                                <td>{{ $h->user?->name ?? '—' }}</td>
                                <td class="gx-mini">{{ $h->created_at?->diffForHumans() }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </section>
    @endif

    @if ($canRequest)
        <div class="gx-bar" x-show="count > 0" x-transition.opacity x-cloak>
            <div class="gx-bar-info">
                <b x-text="count"></b> {{ $t('صنف', 'items') }} · <b x-text="pcs.toLocaleString('en')"></b> {{ $t('حبة', 'pcs') }}
                <span class="gx-mini">{{ $src }} {{ $to }} {{ $tgt }}</span>
            </div>
            <div class="gx-bar-actions">
                <button type="button" class="gx-btn" x-on:click="clear()">{{ $t('إلغاء التحديد', 'Clear') }}</button>
                <button type="button" class="gx-btn gx-btn-primary" x-on:click="confirm = true">{{ $t('اطلب التحويل', 'Request transfer') }}</button>
            </div>
        </div>

        <div class="gx-modal" x-show="confirm" x-transition.opacity x-cloak x-on:keydown.escape.window="if (!busy) confirm = false">
            <div class="gx-modal-card" x-on:click.outside="if (!busy) confirm = false">
                <h3 class="gx-h2">{{ $t('إنشاء طلب تحويل في ساب', 'Create a transfer request in SAP') }}</h3>
                <p class="gx-modal-text">
                    {{ $t('من', 'From') }} <b>{{ $src }}</b> {{ $t('إلى', 'to') }} <b>{{ $tgt }}</b> ·
                    <b x-text="count"></b> {{ $t('صنف', 'items') }}، <b x-text="pcs.toLocaleString('en')"></b> {{ $t('حبة', 'pcs') }}.
                    {{ $t('هذا «طلب تحويل» فقط: ما يتحرك المخزون حتى يجهزه', 'This is a request only: no stock moves until') }} {{ $src }} {{ $t('ويرسله من تطبيق HUB.', 'prepares and sends it from HUB.') }}
                </p>
                <label class="gx-field gx-field-wide">
                    <span>{{ $t('ملاحظة (اختياري)', 'Note (optional)') }}</span>
                    <input type="text" x-model="note" maxlength="200" placeholder="{{ $t('مثلاً: عاجل لطلبات الإكسبريس', 'e.g. urgent for express orders') }}">
                </label>
                <div class="gx-modal-actions">
                    <button type="button" class="gx-btn" x-on:click="confirm = false" :disabled="busy">{{ $t('رجوع', 'Back') }}</button>
                    <button type="button" class="gx-btn gx-btn-primary" x-on:click="send()" :disabled="busy">
                        <span x-show="!busy">{{ $t('أنشئ الطلب في ساب', 'Create in SAP') }}</span>
                        <span x-show="busy">{{ $t('جاري الإرسال…', 'Sending…') }}</span>
                    </button>
                </div>
            </div>
        </div>
    @endif

    <style>
        .gx { --gx-surface: var(--mt-surface, #fff); --gx-surface-2: var(--mt-surface-2, #f7f7f6); --gx-line: var(--mt-line, #e3e3e1); --gx-line-soft: var(--mt-line-soft, #ebebea); --gx-ink: var(--mt-ink, #1a1a1a); --gx-ink-2: var(--mt-ink-2, #4a4a4a); --gx-ink-3: var(--mt-ink-3, #616161); --gx-accent: var(--mt-accent, #1f6f54); --gx-accent-soft: var(--mt-accent-soft, #e4f1eb); --gx-warm: var(--mt-warm, #b4532a); --gx-warm-soft: var(--mt-warm-soft, #fbe9e1); --gx-shadow: var(--mt-card-shadow, 0 0 0 1px rgba(26,26,26,.07), 0 1px 3px rgba(26,26,26,.05)); display: flex; flex-direction: column; gap: 1rem; padding-bottom: 5rem; color: var(--gx-ink); }
        .gx [x-cloak] { display: none !important; }
        .gx-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
        .gx-title { font-size: 1.35rem; font-weight: 700; margin: 0; }
        .gx-sub { margin: .25rem 0 0; color: var(--gx-ink-3); font-size: .875rem; }
        .gx-sub strong { color: var(--gx-ink); font-weight: 600; }
        .gx-head-tools, .gx-card-tools, .gx-bar-actions, .gx-modal-actions { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; }
        .gx-btn { display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .75rem; border-radius: .5rem; font-size: .8125rem; font-weight: 600; background: var(--gx-surface); color: var(--gx-ink); box-shadow: var(--mt-btn-2, 0 0 0 1px rgba(0,0,0,.12) inset); white-space: nowrap; }
        .gx-btn:hover { background: var(--gx-surface-2); }
        .gx-btn:disabled { opacity: .55; cursor: default; }
        .gx-btn-primary { background: #303030; color: #fff; box-shadow: var(--mt-btn-1, none); }
        .gx-btn-primary:hover { background: #1a1a1a; }
        .gx-ico { width: 1rem; height: 1rem; flex: none; }
        .gx-spin { animation: gx-spin .8s linear infinite; }
        @keyframes gx-spin { to { transform: rotate(360deg); } }
.gx-focus { padding-block: .6rem; }
        .gx-focus-title { display: inline-flex; align-items: center; gap: .35rem; font-size: .8125rem; font-weight: 700; margin-bottom: .45rem; }
        .gx-focus-note { font-size: .75rem; color: var(--gx-ink-3); margin-bottom: .5rem; }
        .gx-focus-note b { color: var(--gx-ink); }
        .gx-seg { display: inline-flex; padding: .2rem; gap: .15rem; border-radius: .6rem; background: var(--gx-surface-2); box-shadow: 0 0 0 1px var(--gx-line-soft) inset; flex-wrap: wrap; }
        .gx-seg-btn { padding: .35rem .7rem; border-radius: .45rem; font-size: .8125rem; font-weight: 600; color: var(--gx-ink-3); white-space: nowrap; }
        .gx-seg-btn:hover { color: var(--gx-ink); }
        .gx-seg-btn.is-active { background: var(--gx-surface); color: var(--gx-ink); box-shadow: 0 1px 2px rgba(0,0,0,.08), 0 0 0 1px var(--gx-line-soft); }
        .gx-c-rank { width: 3rem; }
        .gx-c-rank .gx-mini { display: block; }
        .gx-rank { font-weight: 700; }
        .gx-field select:disabled { opacity: .55; }
                .gx-controls { display: flex; flex-wrap: wrap; align-items: flex-end; gap: .75rem; padding: .75rem 1rem; background: var(--gx-surface); border-radius: .75rem; box-shadow: var(--gx-shadow); }
        .gx-field { display: flex; flex-direction: column; gap: .25rem; font-size: .75rem; color: var(--gx-ink-3); }
        .gx-field select, .gx-field input { min-width: 7.5rem; padding: .35rem 2rem .35rem .6rem; border-radius: .5rem; border: 1px solid var(--gx-line); background-color: var(--gx-surface); color: var(--gx-ink); font-size: .8125rem; }
        .gx-field input { padding: .45rem .6rem; }
        .gx-field-wide { width: 100%; }
        .gx-field-wide input { width: 100%; }
        .gx-arrow { color: var(--gx-ink-3); margin-bottom: .5rem; }
        [dir="ltr"] .gx-arrow { transform: scaleX(-1); }
        .gx-sep { width: 1px; align-self: stretch; background: var(--gx-line); margin: 0 .25rem; }
        .gx-banner { display: flex; gap: .5rem; align-items: flex-start; padding: .75rem 1rem; border-radius: .75rem; font-size: .875rem; }
        .gx-banner.is-ok { background: var(--gx-accent-soft); color: var(--gx-accent); }
        .gx-banner.is-bad { background: var(--gx-warm-soft); color: var(--gx-warm); }
        .gx-banner .gx-ico { margin-top: .15rem; }
        .gx-kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .75rem; }
        .gx-kpis.is-loading, .gx-grid-wrap.is-loading { opacity: .55; transition: opacity .15s; }
        .gx-kpi { display: flex; flex-direction: column; gap: .2rem; padding: .85rem 1rem; background: var(--gx-surface); border-radius: .75rem; box-shadow: var(--gx-shadow); min-width: 0; }
        .gx-kpi-l { font-size: .75rem; color: var(--gx-ink-3); font-weight: 600; }
        .gx-kpi-v { font-size: 1.5rem; font-weight: 700; font-variant-numeric: tabular-nums; }
        .gx-kpi-s { font-size: .75rem; color: var(--gx-ink-3); }
        .gx-kpi-halo b { color: var(--gx-ink-2); }
        .is-accent { color: var(--gx-accent); }
        .is-warm { color: var(--gx-warm); }
        .gx-card { background: var(--gx-surface); border-radius: .75rem; box-shadow: var(--gx-shadow); overflow: hidden; }
        .gx-card-head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; flex-wrap: wrap; padding: .6rem .75rem; border-bottom: 1px solid var(--gx-line-soft); }
        .gx-h2 { font-size: .9375rem; font-weight: 700; margin: 0; }
        .gx-tabs { display: flex; gap: .25rem; flex-wrap: wrap; }
        .gx-tab { padding: .35rem .65rem; border-radius: .5rem; font-size: .8125rem; font-weight: 600; color: var(--gx-ink-3); }
        .gx-tab:hover { background: var(--gx-surface-2); color: var(--gx-ink); }
        .gx-tab.is-active { background: var(--mt-hover, #e3e3e2); color: var(--gx-ink); }
        .gx-tab-n { font-variant-numeric: tabular-nums; font-weight: 500; opacity: .75; margin-inline-start: .15rem; }
        .gx-search { width: 16rem; max-width: 100%; padding: .4rem .65rem; border-radius: .5rem; border: 1px solid var(--gx-line); background: var(--gx-surface); color: var(--gx-ink); font-size: .8125rem; }
        .gx-grid-wrap { overflow-x: auto; }
        .gx-grid { width: 100%; border-collapse: collapse; font-size: .8125rem; }
        .gx-grid thead th { position: sticky; top: 0; padding: .5rem .75rem; background: var(--gx-surface-2); border-bottom: 1px solid var(--gx-line); font-size: .75rem; font-weight: 600; color: var(--gx-ink-3); text-align: start; white-space: nowrap; }
        .gx-grid td { padding: .55rem .75rem; border-bottom: 1px solid var(--gx-line-soft); vertical-align: middle; font-variant-numeric: tabular-nums; }
        .gx-grid .is-num { text-align: end; white-space: nowrap; }
        .gx-grid tbody tr:hover { background: var(--mt-row-hover, #f7f7f6); }
        .gx-grid tbody tr.is-picked { background: var(--gx-accent-soft); }
        .gx-c-check { width: 2.25rem; text-align: center !important; }
        .gx-check { width: 1rem; height: 1rem; border-radius: .25rem; accent-color: var(--gx-accent); cursor: pointer; }
        .gx-prod { display: flex; align-items: center; gap: .65rem; min-width: 15rem; max-width: 26rem; }
        .gx-thumb { flex: none; width: 2.5rem; height: 2.5rem; border-radius: .5rem; background: #fff; box-shadow: 0 0 0 1px var(--gx-line-soft); display: grid; place-items: center; overflow: hidden; }
        .gx-thumb img { width: 100%; height: 100%; object-fit: contain; }
        .gx-prod-main { display: flex; flex-direction: column; gap: .15rem; min-width: 0; }
        .gx-prod-name { font-weight: 600; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; line-height: 1.35; }
        .gx-prod-sub { display: flex; gap: .35rem; align-items: center; flex-wrap: wrap; }
        .gx-code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .6875rem; color: var(--gx-ink-3); direction: ltr; unicode-bidi: isolate; }
        .gx-pill { display: inline-flex; padding: .05rem .4rem; border-radius: 999px; font-size: .6875rem; font-weight: 700; background: var(--gx-surface-2); }
        .gx-pill.is-warm { background: var(--gx-warm-soft); color: var(--gx-warm); }
        .gx-stack { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; line-height: 1.3; }
        .gx-stack i { font-style: normal; color: var(--gx-ink-3); font-size: .75rem; }
        .gx-mini { font-size: .72rem; color: var(--gx-ink-3); }
        .gx-mini.is-accent { color: var(--gx-accent); font-weight: 600; }
        .gx-alt { color: var(--gx-ink-2); }
        .gx-gap { display: inline-flex; min-width: 2rem; justify-content: center; padding: .1rem .45rem; border-radius: .4rem; background: var(--gx-warm-soft); color: var(--gx-warm); font-weight: 700; }
        .gx-qty { width: 4.5rem; padding: .3rem .45rem; border-radius: .45rem; border: 1px solid var(--gx-line); background: var(--gx-surface); color: var(--gx-ink); text-align: center; font-variant-numeric: tabular-nums; }
        .gx-empty { padding: 2.5rem !important; text-align: center; color: var(--gx-ink-3); }
        .gx-note { margin: 0; padding: .6rem .9rem; font-size: .75rem; color: var(--gx-ink-3); }
        .gx-how summary { cursor: pointer; padding: .75rem 1rem; font-weight: 600; font-size: .875rem; }
        .gx-how ul { margin: 0; padding: 0 2.25rem 1rem; display: flex; flex-direction: column; gap: .4rem; font-size: .8125rem; color: var(--gx-ink-2); list-style: disc; }
        .gx-bar { position: fixed; z-index: 30; bottom: 1rem; inset-inline: 0; margin-inline: auto; width: min(44rem, calc(100% - 2rem)); display: flex; align-items: center; justify-content: space-between; gap: .75rem; flex-wrap: wrap; padding: .6rem .75rem .6rem 1rem; border-radius: .9rem; background: var(--gx-surface); box-shadow: var(--mt-shadow-lg, 0 12px 32px rgba(26,26,26,.14), 0 0 0 1px rgba(26,26,26,.08)); }
        .gx-bar-info { display: flex; align-items: baseline; gap: .35rem; flex-wrap: wrap; font-size: .875rem; }
        .gx-modal { position: fixed; inset: 0; z-index: 50; display: grid; place-items: center; padding: 1rem; background: rgba(0, 0, 0, .35); }
        .gx-modal-card { width: min(30rem, 100%); display: flex; flex-direction: column; gap: .85rem; padding: 1.25rem; border-radius: .9rem; background: var(--gx-surface); box-shadow: var(--mt-shadow-lg, 0 12px 32px rgba(0,0,0,.2)); }
        .gx-modal-text { margin: 0; font-size: .875rem; color: var(--gx-ink-2); line-height: 1.6; }
        .gx-modal-actions { justify-content: flex-end; }
        @media (max-width: 1024px) { .gx-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
        @media (max-width: 640px) {
            .gx-kpis { grid-template-columns: minmax(0, 1fr); }
            .gx-sep, .gx-arrow { display: none; }
            .gx-field { flex: 1 1 45%; }
            .gx-field select { min-width: 0; width: 100%; }
            .gx-search { width: 100%; }
        }
    </style>
</div>
</x-filament-panels::page>
