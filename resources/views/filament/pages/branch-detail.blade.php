@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $d = $this->data();
    $k = $d['kpi'] ?? [];
    $money = fn ($v) => number_format((float) $v);
    $qty = fn ($v) => rtrim(rtrim(number_format((float) $v, 1), '0'), '.');
    $periods = ['today' => ['اليوم', 'Today'], 'week' => ['هذا الأسبوع', 'This week'], 'month' => ['هذا الشهر', 'This month'], 'year' => ['هذه السنة', 'This year']];
    $vitalLabels = [
        'hero_availability' => ['توفر الأكثر مبيعاً', 'Best-seller availability', 'الأصناف الأعلى مبيعاً موجودة على الرف', 'Top sellers are on the shelf'],
        'capital_efficiency' => ['حركة المخزون', 'Stock movement', 'نسبة المخزون الذي يتحرك فعلاً', 'Share of stock that actually moves'],
        'basket_size' => ['حجم السلة', 'Basket size', 'عدد الأصناف في الفاتورة', 'Items per invoice'],
        'count_accuracy' => ['دقة الجرد', 'Count accuracy', 'تطابق الجرد مع النظام', 'Counts match the system'],
    ];
    $score = $d['score'] ?? null;
    $ops = $d['ops'] ?? [];
    $stock = $d['stock'] ?? [];
    $back = \App\Support\AdminShell::isArabic() ? 'heroicon-m-arrow-right' : 'heroicon-m-arrow-left';
@endphp

<x-filament-panels::page class="mt-branch">
    {{-- header --}}
    <header class="mt-page-head">
        <div class="mt-branch-id">
            <a href="{{ $this->branchesUrl() }}" class="mt-back" aria-label="{{ $t('كل الفروع', 'All branches') }}"><x-filament::icon :icon="$back" class="h-4 w-4" /></a>
            <div>
                <div class="mt-branch-title">
                    <h1 class="mt-page-title">{{ $d['name'] }}</h1>
                    <span class="mt-code">{{ $d['code'] }}</span>
                    @if ($score)
                        <span @class(['mt-score', 'is-good' => $score['value'] >= 75, 'is-mid' => $score['value'] >= 55 && $score['value'] < 75, 'is-low' => $score['value'] < 55])>
                            {{ $t('التقييم', 'Rating') }} {{ $score['value'] }}
                        </span>
                    @endif
                </div>
                <p class="mt-page-sub">
                    @if ($d['sales_rank']){{ $t('الترتيب بالمبيعات', 'Sales rank') }} {{ $d['sales_rank'] }} {{ $t('من', 'of') }} {{ $d['branch_count'] }}@endif
                    @if ($score && $score['rank']) · {{ $t('ترتيب التقييم', 'Rating rank') }} {{ $score['rank'] }} {{ $t('من', 'of') }} {{ $score['total_branches'] }}@endif
                    · {{ $d['period']['from'] }} ← {{ $d['period']['to'] }}
                </p>
            </div>
        </div>
        <div class="mt-head-tools">
            <label class="mt-select" x-data>
                <span class="sr-only">{{ $t('انتقل إلى فرع', 'Jump to branch') }}</span>
                <select x-on:change="if ($event.target.value) window.location = $event.target.value">
                    @foreach ($d['siblings'] as $s)
                        <option value="{{ \App\Filament\Pages\BranchDetail::urlFor($s['code'], $d['period']['key']) }}" @selected($s['code'] === $d['code'])>{{ $s['name'] }} · {{ $s['code'] }}</option>
                    @endforeach
                </select>
                <x-filament::icon icon="heroicon-m-chevron-down" class="mt-select-ico" />
            </label>
            <div class="mt-seg" role="group" aria-label="{{ $t('الفترة', 'Period') }}">
                @foreach ($periods as $key => $label)
                    <button type="button" wire:click="setPeriod('{{ $key }}')" @class(['mt-seg-btn', 'is-active' => $d['period']['key'] === $key]) aria-pressed="{{ $d['period']['key'] === $key ? 'true' : 'false' }}">{{ $t(...$label) }}</button>
                @endforeach
            </div>
        </div>
    </header>

    {{-- KPIs --}}
    <section class="mt-kpis" wire:loading.class="is-loading">
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('صافي المبيعات', 'Net sales') }}</span>
            <span class="mt-kpi-value">{{ $money($k['net'] ?? 0) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ ($k['share'] ?? 0) }}% {{ $t('من مبيعات الشبكة', 'of network sales') }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('الربح الإجمالي', 'Gross profit') }}</span>
            <span class="mt-kpi-value">{{ $money($k['profit'] ?? 0) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ ($k['margin'] ?? null) !== null ? $t('هامش', 'Margin') . ' ' . $k['margin'] . '%' . (($k['estimated'] ?? false) ? ' · ' . $t('تقديري', 'estimated') : '') : '—' }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('الفواتير', 'Invoices') }}</span>
            <span class="mt-kpi-value">{{ number_format($k['invoices'] ?? 0) }}</span>
            <span class="mt-kpi-sub">{{ $t('متوسط السلة', 'Avg basket') }} {{ $money($k['aov'] ?? 0) }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('المرتجعات', 'Returns') }}</span>
            <span class="mt-kpi-value">{{ $money($k['returns'] ?? 0) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ ($k['gross'] ?? 0) > 0 ? round($k['returns'] / $k['gross'] * 100, 1) . '% ' . $t('من المبيعات', 'of sales') : '—' }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('فرص بيع ضائعة', 'Lost sales') }}</span>
            <span class="mt-kpi-value is-warn">{{ $money($d['bleeding']['total']) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ $t('شهرياً بسبب نقص المخزون', 'per month from stock gaps') }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('مخزون راكد', 'Stagnant stock') }}</span>
            <span class="mt-kpi-value">{{ $money($d['trapped']['total']) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ $t('قيمة بالتكلفة لا تتحرك', 'at cost, not moving') }}</span>
        </div>
    </section>

    {{-- trend + rating --}}
    <div class="mt-cols mt-cols-2-1">
        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('المبيعات والربح', 'Sales & profit') }}</h2></div>
            <div class="mt-card-body"><x-mt.trend-chart :trend="$d['trend']" :height="190" /></div>
            @if (! empty($d['compare']))
                <div class="mt-compare">
                    <p class="mt-compare-title">{{ $t('مقارنة بمتوسط الشبكة', 'Against the network average') }}</p>
                    <div class="mt-compare-grid">
                        @foreach ($d['compare'] as $c)
                            @php
                                $L = ['net' => ['المبيعات', 'Sales', ''], 'aov' => ['متوسط السلة', 'Avg basket', ''], 'margin' => ['الهامش', 'Margin', '%'], 'returns' => ['نسبة المرتجع', 'Return rate', '%']][$c['key']];
                                $has = $c['branch'] !== null && $c['network'] !== null && (float) $c['network'] != 0.0;
                                $diff = $has ? ($c['key'] === 'margin' || $c['key'] === 'returns' ? round($c['branch'] - $c['network'], 1) : round(($c['branch'] - $c['network']) / abs($c['network']) * 100)) : null;
                                $good = $diff !== null && (($c['better'] === 'up' && $diff >= 0) || ($c['better'] === 'down' && $diff <= 0));
                                $fmt = fn ($v) => $L[2] === '%' ? $v . '%' : number_format((float) $v);
                            @endphp
                            <div class="mt-compare-cell">
                                <span class="mt-compare-l">{{ $t($L[0], $L[1]) }}</span>
                                <span class="mt-compare-v">{{ $c['branch'] !== null ? $fmt($c['branch']) : '—' }}</span>
                                <span class="mt-compare-n">
                                    {{ $t('الشبكة', 'Network') }} {{ $c['network'] !== null ? $fmt($c['network']) : '—' }}
                                    @if ($diff !== null && $diff != 0)
                                        <b @class(['is-good' => $good, 'is-bad' => ! $good])>{{ $diff > 0 ? '▲' : '▼' }} {{ abs($diff) }}{{ ($c['key'] === 'margin' || $c['key'] === 'returns') ? ' ' . $t('نقطة', 'pt') : '%' }}</b>
                                    @endif
                                </span>
                            </div>
                        @endforeach
                    </div>
                </div>
            @endif
        </section>

        <section class="mt-panel-card">
            <div class="mt-card-head">
                <h2>{{ $t('صحة المعرض', 'Showroom health') }}</h2>
                @if ($score && $score['trend'] !== null && $score['trend'] != 0)
                    <span @class(['mt-pill', 'is-ok' => $score['trend'] > 0, 'is-danger' => $score['trend'] < 0])>{{ $score['trend'] > 0 ? '+' : '' }}{{ $score['trend'] }}</span>
                @endif
            </div>
            @if ($score)
                <div class="mt-health-score">
                    <div class="mt-ring" style="--v: {{ min(100, max(0, $score['value'])) }}">
                        <span>{{ $score['value'] }}</span>
                    </div>
                    <p>{{ $t('من 100 · يُحسب ليلياً من توفر الأكثر مبيعاً وحركة المخزون وحجم السلة ودقة الجرد', 'out of 100 · computed nightly from best-seller availability, stock movement, basket size and count accuracy') }}</p>
                </div>
                <ul class="mt-vitals">
                    @foreach ($d['vitals'] as $v)
                        @php $L = $vitalLabels[$v['key']] ?? [$v['key'], $v['key'], '', '']; @endphp
                        <li>
                            <div class="mt-vital-top">
                                <span class="mt-vital-name">{{ $t($L[0], $L[1]) }}</span>
                                <span class="mt-vital-val">{{ $v['value'] !== null ? $v['value'] : '—' }}@if (isset($v['raw'])) <span class="mt-mini">({{ $v['raw'] }} {{ $t('صنف/فاتورة', 'items/invoice') }})</span>@endif</span>
                            </div>
                            <span class="mt-bar is-thin"><i style="width: {{ $v['value'] ?? 0 }}%"></i></span>
                            <span class="mt-vital-hint">{{ $t($L[2], $L[3]) }}</span>
                        </li>
                    @endforeach
                </ul>
            @else
                <p class="mt-card-empty">{{ $t('لم يُحسب تقييم لهذا الفرع بعد.', 'No rating computed for this branch yet.') }}</p>
            @endif
        </section>
    </div>

    {{-- product lists --}}
    <div class="mt-cols mt-cols-3">
        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('الأكثر مبيعاً', 'Best sellers') }}</h2><span class="mt-card-meta">{{ $t('بالوحدات', 'by units') }}</span></div>
            <ul class="mt-items">
                @forelse ($d['top'] as $i => $p)
                    <li class="mt-item-row">
                        <span class="mt-rank">{{ $i + 1 }}</span>
                        <img src="{{ $p['image_url'] }}" alt="" loading="lazy" class="mt-thumb" onerror="this.style.visibility='hidden'">
                        <span class="mt-item-main"><span class="mt-item-name">{{ $p['name'] }}</span><span class="mt-code">{{ $p['item_code'] }}</span></span>
                        <span class="mt-item-val">{{ $qty($p['units']) }}</span>
                    </li>
                @empty
                    <li class="mt-card-empty">{{ $t('لا مبيعات في هذه الفترة.', 'No sales in this period.') }}</li>
                @endforelse
            </ul>
        </section>

        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('فرص بيع ضائعة', 'Lost sales') }}</h2><span class="mt-card-meta">{{ $t('أصناف ناقصة تخسّر مبيعات', 'short items losing sales') }}</span></div>
            <ul class="mt-items">
                @forelse ($d['bleeding']['items'] as $p)
                    <li class="mt-item-row">
                        <img src="{{ $p['image_url'] }}" alt="" loading="lazy" class="mt-thumb" onerror="this.style.visibility='hidden'">
                        <span class="mt-item-main">
                            <span class="mt-item-name">{{ $p['name'] }}</span>
                            <span class="mt-item-sub">
                                {{ $t('بالمعرض', 'on hand') }} {{ $qty($p['current_stock']) }}
                                · <span @class(['mt-tag-inline', 'is-warn' => $p['remedy'] === 'reorder'])>{{ $p['remedy'] === 'transfer' ? $t('متوفر للتحويل', 'transferable') . ' ' . $qty($p['net_available']) : $t('يحتاج طلب من المورد', 'needs supplier order') }}</span>
                                @if ($p['on_order'] > 0) · {{ $t('قيد الطلب', 'on order') }} {{ $qty($p['on_order']) }}@endif
                            </span>
                        </span>
                        <span class="mt-item-val is-warn">{{ $money($p['lost_revenue_monthly']) }}<small>/{{ $t('شهر', 'mo') }}</small></span>
                    </li>
                @empty
                    <li class="mt-card-empty">{{ $t('لا نقص مؤثر — ممتاز.', 'No costly gaps — well done.') }}</li>
                @endforelse
            </ul>
            @if ($url = $this->tableUrl('suggested-stock-transfers', ['target_warehouse' => '@']))
                <a href="{{ $url }}" class="mt-card-foot">{{ $t('التوزيع الذكي لهذا الفرع', 'Smart distribution for this branch') }}</a>
            @endif
        </section>

        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('مخزون راكد', 'Stagnant stock') }}</h2><span class="mt-card-meta">{{ $t('بطيء أو بلا حركة', 'slow or not moving') }}</span></div>
            <ul class="mt-items">
                @forelse ($d['trapped']['items'] as $p)
                    <li class="mt-item-row">
                        <img src="{{ $p['image_url'] }}" alt="" loading="lazy" class="mt-thumb" onerror="this.style.visibility='hidden'">
                        <span class="mt-item-main">
                            <span class="mt-item-name">{{ $p['name'] }}</span>
                            <span class="mt-item-sub">{{ $p['health_status'] === 'dead' ? $t('بلا مبيعات', 'no sales') : $t('فائض', 'excess') . ' ' . $qty($p['excess_units']) }} · {{ $t('بالمعرض', 'on hand') }} {{ $qty($p['current_stock']) }}</span>
                        </span>
                        <span class="mt-item-val">{{ $money($p['capital_at_risk_sar']) }}</span>
                    </li>
                @empty
                    <li class="mt-card-empty">{{ $t('لا مخزون راكد يُذكر.', 'No notable stagnant stock.') }}</li>
                @endforelse
            </ul>
        </section>
    </div>

    {{-- stock + operations --}}
    <div class="mt-cols mt-cols-2">
        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('المخزون في الفرع', 'Stock at branch') }}</h2></div>
            <div class="mt-stats">
                <div><span class="mt-stat-v">{{ number_format($stock['skus'] ?? 0) }}</span><span class="mt-stat-l">{{ $t('صنف متوفر', 'SKUs in stock') }}</span></div>
                <div><span class="mt-stat-v">{{ $qty($stock['units'] ?? 0) }}</span><span class="mt-stat-l">{{ $t('وحدة', 'units') }}</span></div>
                <div><span class="mt-stat-v">{{ $qty($stock['committed'] ?? 0) }}</span><span class="mt-stat-l">{{ $t('محجوز', 'committed') }}</span></div>
                <div><span class="mt-stat-v">{{ $qty($stock['incoming'] ?? 0) }}</span><span class="mt-stat-l">{{ $t('قادم', 'incoming') }}</span></div>
            </div>
            <div class="mt-links">
                @foreach ([['warehouse-item-stocks', 'مخزون الفرع', 'Branch stock'], ['product-abc-classifications', 'تصنيف ABC', 'ABC classes'], ['inventory-countings', 'الجرد', 'Counts']] as [$path, $ar, $en])
                    @if ($url = $this->tableUrl($path, ['warehouse_code' => '@']))
                        <a href="{{ $url }}" class="mt-link-chip">{{ $t($ar, $en) }}</a>
                    @endif
                @endforeach
            </div>
        </section>

        <section class="mt-panel-card">
            <div class="mt-card-head"><h2>{{ $t('التشغيل', 'Operations') }}</h2><span class="mt-card-meta">{{ $t('ما ينتظر الفرع الآن', 'what is waiting now') }}</span></div>
            <div class="mt-ops">
                @foreach ([
                    ['quality_pending', 'quality-task-instances', ['warehouse_code' => '@', 'status' => 'pending'], false, 'مهام جودة معلّقة', 'Quality tasks pending', 'heroicon-o-shield-check'],
                    ['counting_active', 'inventory-countings', ['warehouse_code' => '@', 'status' => 'in_progress'], false, 'جرد جارٍ', 'Counts in progress', 'heroicon-o-clipboard-document-check'],
                    ['transfers_new', 'stock-transfers', ['internal_status' => 'New'], true, 'تحويلات جديدة', 'New transfers', 'heroicon-o-arrows-right-left'],
                    ['zooboxi_pending', 'zooboxi-orders', ['warehouse_code' => '@', 'delivery_status' => 'pending'], false, 'طلبات زوبكسي معلّقة', 'Zooboxi orders pending', 'heroicon-o-shopping-bag'],
                ] as [$key, $path, $filters, $search, $ar, $en, $icon])
                    @php $n = (int) ($ops[$key] ?? 0); $url = $this->tableUrl($path, $filters, $search); @endphp
                    <a @if ($url) href="{{ $url }}" @endif @class(['mt-op', 'is-hot' => $n > 0])>
                        <x-filament::icon :icon="$icon" class="mt-op-ico" />
                        <span class="mt-op-l">{{ $t($ar, $en) }}</span>
                        <span class="mt-op-v">{{ $n }}</span>
                        @if ($key === 'zooboxi_pending' && ($ops['zooboxi_urgent'] ?? 0) > 0)
                            <span class="mt-pill is-danger">{{ $ops['zooboxi_urgent'] }} {{ $t('إكسبريس', 'express') }}</span>
                        @endif
                    </a>
                @endforeach
            </div>
        </section>
    </div>
</x-filament-panels::page>
