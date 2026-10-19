@php
    $t = fn (string $ar, string $en) => \App\Support\AdminShell::t([$ar, $en]);
    $b = $this->board();
    $T = $b['totals'];
    $money = fn ($v) => number_format((float) $v);
    $periods = ['today' => ['اليوم', 'Today'], 'week' => ['هذا الأسبوع', 'This week'], 'month' => ['هذا الشهر', 'This month'], 'year' => ['هذه السنة', 'This year']];
    $cols = [
        'net' => ['صافي المبيعات', 'Net sales'],
        'profit' => ['الربح', 'Profit'],
        'invoices' => ['الفواتير', 'Invoices'],
        'aov' => ['متوسط السلة', 'Avg basket'],
        'returns' => ['المرتجعات', 'Returns'],
        'score' => ['التقييم', 'Rating'],
        'bleeding' => ['فرص ضائعة/شهر', 'Lost / month'],
        'trapped' => ['مخزون راكد', 'Stagnant stock'],
        'ops_total' => ['مهام مفتوحة', 'Open tasks'],
    ];
@endphp

<x-filament-panels::page class="mt-branches">
    <header class="mt-page-head">
        <div>
            <h1 class="mt-page-title">{{ $t('الفروع', 'Branches') }}</h1>
            <p class="mt-page-sub">{{ $t('مبيعات التجزئة لكل معرض من سجل الكاشير C0000001 · نفس أرقام تطبيق المالك', 'Retail sales per showroom from register C0000001 · same numbers as the owner app') }}</p>
        </div>
        <div class="mt-seg" role="group" aria-label="{{ $t('الفترة', 'Period') }}">
            @foreach ($periods as $key => $label)
                <button type="button" wire:click="setPeriod('{{ $key }}')" @class(['mt-seg-btn', 'is-active' => $b['period']['key'] === $key]) aria-pressed="{{ $b['period']['key'] === $key ? 'true' : 'false' }}">{{ $t(...$label) }}</button>
            @endforeach
        </div>
    </header>

    <section class="mt-kpis" wire:loading.class="is-loading">
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('صافي المبيعات', 'Net sales') }}</span>
            <span class="mt-kpi-value">{{ $money($T['net']) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ $t('بعد المرتجعات، بدون ضريبة', 'After returns, ex-VAT') }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('الربح الإجمالي', 'Gross profit') }}</span>
            <span class="mt-kpi-value">{{ $money($T['profit']) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ $T['margin'] !== null ? $t('هامش', 'Margin') . ' ' . $T['margin'] . '%' : '—' }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('الفواتير', 'Invoices') }}</span>
            <span class="mt-kpi-value">{{ number_format($T['invoices']) }}</span>
            <span class="mt-kpi-sub">{{ $t('متوسط السلة', 'Avg basket') }} {{ $money($T['aov']) }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('المرتجعات', 'Returns') }}</span>
            <span class="mt-kpi-value">{{ $money($T['returns']) }} <x-mt.riyal /></span>
            <span class="mt-kpi-sub">{{ $T['gross'] > 0 ? round($T['returns'] / $T['gross'] * 100, 1) . '% ' . $t('من المبيعات', 'of sales') : '—' }}</span>
        </div>
        <div class="mt-kpi">
            <span class="mt-kpi-label">{{ $t('الفروع البائعة', 'Selling branches') }}</span>
            <span class="mt-kpi-value">{{ $T['branches'] }}</span>
            <span class="mt-kpi-sub">{{ $b['period']['from'] }} ← {{ $b['period']['to'] }}</span>
        </div>
    </section>

    <section class="mt-panel-card">
        <div class="mt-card-head"><h2>{{ $t('مبيعات الشبكة', 'Network sales') }}</h2></div>
        <div class="mt-card-body">
            <x-mt.trend-chart :trend="$b['trend']" :height="150" />
        </div>
    </section>

    <section class="mt-panel-card">
        <div class="mt-card-head">
            <h2>{{ $t('ترتيب الفروع', 'Branch ranking') }}</h2>
            <span class="mt-card-meta">{{ $t('اضغط أي فرع لتفاصيله الكاملة · اضغط رأس العمود للترتيب', 'Open any branch for its full picture · click a column to sort') }}</span>
        </div>
        <div class="mt-grid-wrap">
            <table class="mt-grid">
                <thead>
                    <tr>
                        <th class="is-num">#</th>
                        <th><button type="button" wire:click="sortBy('name')" @class(['is-sorted' => $sort === 'name'])>{{ $t('الفرع', 'Branch') }}</button></th>
                        @foreach ($cols as $key => $label)
                            <th class="is-num"><button type="button" wire:click="sortBy('{{ $key }}')" @class(['is-sorted' => $sort === $key])>{{ $t(...$label) }}@if ($sort === $key)<x-filament::icon icon="heroicon-m-chevron-down" class="mt-sort-ico" />@endif</button></th>
                        @endforeach
                    </tr>
                </thead>
                <tbody>
                    @forelse ($b['rows'] as $i => $r)
                        <tr wire:key="br-{{ $r['code'] }}" class="mt-grid-row" onclick="window.location='{{ \App\Filament\Pages\BranchDetail::urlFor($r['code'], $b['period']['key']) }}'">
                            <td class="is-num is-muted">{{ $i + 1 }}</td>
                            <td>
                                <a href="{{ \App\Filament\Pages\BranchDetail::urlFor($r['code'], $b['period']['key']) }}" class="mt-branch-cell">
                                    <span class="mt-branch-name">{{ $r['name'] }}</span>
                                    <span class="mt-code">{{ $r['code'] }}</span>
                                </a>
                            </td>
                            <td class="is-num">
                                <div class="mt-bar-cell">
                                    <span class="mt-strong">{{ $money($r['net']) }}</span>
                                    <span class="mt-bar"><i style="width: {{ $r['bar'] }}%"></i></span>
                                    <span class="mt-mini">{{ $r['share'] }}%</span>
                                </div>
                            </td>
                            <td class="is-num">
                                {{ $money($r['profit']) }}
                                @if ($r['margin'] !== null)<span class="mt-mini">{{ $r['margin'] }}%{{ $r['estimated'] ? '*' : '' }}</span>@endif
                            </td>
                            <td class="is-num">{{ number_format($r['invoices']) }}</td>
                            <td class="is-num">{{ $money($r['aov']) }}</td>
                            <td class="is-num">{{ $money($r['returns']) }}</td>
                            <td class="is-num">
                                @if ($r['score'] !== null)
                                    <span @class(['mt-score', 'is-good' => $r['score'] >= 75, 'is-mid' => $r['score'] >= 55 && $r['score'] < 75, 'is-low' => $r['score'] < 55])>{{ $r['score'] }}</span>
                                @else — @endif
                            </td>
                            <td class="is-num">@if ($r['bleeding'] > 0)<span class="mt-warn-text">{{ $money($r['bleeding']) }}</span>@else — @endif</td>
                            <td class="is-num">@if ($r['trapped'] > 0){{ $money($r['trapped']) }}@else — @endif</td>
                            <td class="is-num">@if ($r['ops_total'] > 0)<span class="mt-count">{{ $r['ops_total'] }}</span>@else — @endif</td>
                        </tr>
                    @empty
                        <tr><td colspan="11" class="mt-grid-empty">{{ $t('لا توجد مبيعات تجزئة مسجّلة في آخر 90 يوماً.', 'No retail sales recorded in the last 90 days.') }}</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        <p class="mt-card-note">{{ $t('المبالغ بالريال بدون ضريبة. * هامش تقديري لفرع لا تتوفر له أرباح SAP الفعلية في الفترة. «فرص ضائعة» و«مخزون راكد» من آخر تحليل ليلي.', 'Amounts in SAR ex-VAT. * estimated margin where SAP actual profit is missing. Lost and stagnant figures come from the last nightly analysis.') }}</p>
    </section>
</x-filament-panels::page>
