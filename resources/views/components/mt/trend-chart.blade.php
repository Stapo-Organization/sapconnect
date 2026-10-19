@props(['trend' => [], 'height' => 180])
{{--
    Sales (bars) + profit (line) from BranchInsightsService::salesProfitTrend.
    Drawn server-side as SVG: no chart library, crisp in both themes. Time
    runs with the reading direction (right-to-left in Arabic).
--}}
@php
    $points = $trend['points'] ?? [];
    $gran = $trend['granularity'] ?? 'day';
    $n = count($points);
    $W = 1000; $H = (int) $height; $pad = 6;
    $max = max(1, ...array_map(fn ($p) => max((float) $p['sales'], (float) $p['profit'], 0), $points ?: [['sales' => 0, 'profit' => 0]]));
    $rtl = \App\Support\AdminShell::isArabic();
    $slot = $n > 0 ? $W / $n : $W;
    $bw = max(2, min(34, $slot * 0.62));
    $x = fn ($i) => $rtl ? $W - ($i + 0.5) * $slot : ($i + 0.5) * $slot;
    $y = fn ($v) => $H - $pad - max(0, (float) $v) / $max * ($H - $pad * 2);
    $line = collect($points)->map(fn ($p, $i) => round($x($i), 1) . ',' . round($y($p['profit']), 1))->implode(' ');
    $fmtLabel = function ($label) use ($gran) {
        if ($gran === 'day') { return \Illuminate\Support\Carbon::parse($label)->format('j/n'); }
        if ($gran === 'month') { return \Illuminate\Support\Carbon::parse($label . '-01')->locale(app()->getLocale())->translatedFormat('M'); }
        return $label;
    };
    $every = max(1, (int) ceil($n / 8));
    $total = array_sum(array_map(fn ($p) => (float) $p['sales'], $points));
@endphp

<div class="mt-chart">
    @if ($n === 0 || $total == 0)
        <p class="mt-chart-empty">{{ \App\Support\AdminShell::t(['لا مبيعات في هذه الفترة بعد.', 'No sales in this period yet.']) }}</p>
    @else
        <svg viewBox="0 0 {{ $W }} {{ $H }}" preserveAspectRatio="none" class="mt-chart-svg" role="img"
             aria-label="{{ \App\Support\AdminShell::t(['المبيعات والربح عبر الفترة', 'Sales and profit over the period']) }}">
            @foreach ([0.25, 0.5, 0.75] as $g)
                <line x1="0" x2="{{ $W }}" y1="{{ round($H - $pad - $g * ($H - $pad * 2), 1) }}" y2="{{ round($H - $pad - $g * ($H - $pad * 2), 1) }}" class="mt-chart-grid" vector-effect="non-scaling-stroke" />
            @endforeach
            @foreach ($points as $i => $p)
                @php $h = max(0, (float) $p['sales']) / $max * ($H - $pad * 2); @endphp
                <rect x="{{ round($x($i) - $bw / 2, 1) }}" y="{{ round($H - $pad - $h, 1) }}" width="{{ round($bw, 1) }}" height="{{ round(max($h, 0.5), 1) }}" rx="2" class="mt-chart-bar">
                    <title>{{ $p['label'] }} — {{ number_format((float) $p['sales']) }} / {{ number_format((float) $p['profit']) }}</title>
                </rect>
            @endforeach
            <polyline points="{{ $line }}" class="mt-chart-line" vector-effect="non-scaling-stroke" />
        </svg>
        <div class="mt-chart-axis">
            @foreach ($points as $i => $p)
                @if ($i % $every === 0 || $i === $n - 1)
                    <span style="inset-inline-start: {{ round(($i + 0.5) / $n * 100, 2) }}%">{{ $fmtLabel($p['label']) }}</span>
                @endif
            @endforeach
        </div>
        <div class="mt-chart-legend">
            <span><i class="mt-key is-bar"></i>{{ \App\Support\AdminShell::t(['صافي المبيعات', 'Net sales']) }}</span>
            <span><i class="mt-key is-line"></i>{{ \App\Support\AdminShell::t(['الربح', 'Profit']) }}</span>
        </div>
    @endif
</div>
