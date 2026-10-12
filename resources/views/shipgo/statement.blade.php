@php
    $cur   = $customer->currency ?: 'SAR';
    $amt   = fn ($v) => $cur . ' ' . ($v < 0 ? '-' : '') . number_format(abs((float) $v), 2);
    $d     = fn ($s) => $s ? \Carbon\Carbon::parse($s)->format('d.m.y') : '';
    $logo  = resource_path('images/shipgo-logo.png');
@endphp
<!DOCTYPE html>
<html lang="ar">
<head>
<meta charset="utf-8">
<style>
    @page { margin: 8mm 8mm 12mm 8mm; }
    body { font-family: tajawal, sans-serif; color: #111827; font-size: 8pt; }
    table { border-collapse: collapse; }
    .band { width: 100%; }
    .band td { padding: 0; }
    .navy { background: #1F2358; color: #fff; text-align: center; font-size: 14pt; font-weight: bold; height: 13mm; vertical-align: middle; }
    .orange { background: #F26A21; color: #fff; text-align: center; font-size: 10.5pt; font-weight: bold; height: 9mm; vertical-align: middle; }
    .logo-cell { background: #fff; width: 34mm; text-align: center; vertical-align: middle; }
    .meta { width: 100%; margin: 2mm 0 1.5mm; color: #6b7280; font-size: 7pt; }
    .meta td { padding: 0 2mm; }
    table.lines { width: 100%; }
    table.lines th { background: #D9E7F5; color: #111827; font-weight: bold; padding: 2.2mm 1.5mm; font-size: 7.5pt; text-align: center; border-bottom: 1px solid #c7d7ea; }
    table.lines td { padding: 1.6mm 1.5mm; border-bottom: 1px solid #eef1f5; font-size: 7.6pt; vertical-align: middle; }
    table.lines tr.alt td { background: #fafbfd; }
    td.c { text-align: center; }
    td.l { text-align: left; }
    td.r, th.r { text-align: right; white-space: nowrap; }
    tr.ob td { font-weight: bold; }
    .total { width: 100%; margin-top: 2mm; }
    .total td { background: #F26A21; color: #fff; font-weight: bold; font-size: 10pt; padding: 3mm 4mm; }
    .note { margin-top: 3mm; color: #6b7280; font-size: 6.8pt; text-align: right; }
    .neg { color: #b91c1c; }
</style>
</head>
<body>

{{-- Header: logo box on the right spanning both bands, navy title + orange subtitle --}}
<table class="band">
    <tr>
        <td class="navy" dir="rtl">{{ $company['company_name_ar'] ?? 'شركة شيب قو' }} - {{ $company['company_name'] ?? 'ShipGo' }}</td>
        <td class="logo-cell" rowspan="2">
            @if(is_file($logo))<img src="{{ $logo }}" style="width: 30mm;">@else <b style="color:#1F2358;font-size:14pt">ShipGo</b>@endif
        </td>
    </tr>
    <tr>
        <td class="orange" dir="rtl">كشف حساب &nbsp;·&nbsp; {{ $customer->card_name }} &nbsp;·&nbsp; <span dir="ltr">{{ $customer->card_code }}</span></td>
    </tr>
</table>

<table class="meta" dir="rtl">
    <tr>
        <td style="text-align:right">الفترة: {{ $from->format('d.m.Y') }} – {{ $to->format('d.m.Y') }}</td>
        <td style="text-align:center">{{ $customer->federal_tax_id ? 'الرقم الضريبي: ' . $customer->federal_tax_id : '' }}{{ $customer->city ? ' · ' . $customer->city : '' }}{{ $customer->cellular ? ' · ' . $customer->cellular : '' }}</td>
        <td style="text-align:left">تاريخ الإصدار: {{ $generated->format('d.m.Y H:i') }} &nbsp;·&nbsp; {{ config('sap.shipgo_company_db') }}</td>
    </tr>
</table>

<table class="lines" dir="ltr">
    <thead>
        <tr>
            <th style="width:9%">Posting Date</th>
            <th style="width:9%">Due Date</th>
            <th style="width:6%">Origin</th>
            <th style="width:9%">Origin No.</th>
            <th style="width:11%">Offset Account</th>
            <th style="width:22%">Details</th>
            <th class="r" style="width:11%">Debit (LC)</th>
            <th class="r" style="width:11%">Credit (LC)</th>
            <th class="r" style="width:14%">Cumulative Balance (LC)</th>
        </tr>
    </thead>
    <tbody>
        <tr class="ob">
            <td class="c"></td>
            <td class="c"></td>
            <td class="c">OB</td>
            <td class="c"></td>
            <td class="c"></td>
            <td class="l"><b>Opening Balance</b>{{ $statement['opening'] != 0 ? ' (before ' . $from->format('d.m.y') . ')' : '' }}</td>
            <td class="r"></td>
            <td class="r"></td>
            <td class="r">{{ $amt($statement['opening']) }}</td>
        </tr>
        @forelse($statement['lines'] as $i => $l)
            <tr class="{{ $i % 2 ? 'alt' : '' }}">
                <td class="c">{{ $d($l['date']) }}</td>
                <td class="c">{{ $d($l['due_date'] ?? $l['date']) }}</td>
                <td class="c">{{ $l['origin'] ?? '' }}</td>
                <td class="c">{{ $l['ref_no'] ?: '' }}</td>
                <td class="c">{{ $l['offset_account'] ?? '' }}</td>
                <td class="l">{{ $l['memo'] ?: $l['type_label'] }}</td>
                <td class="r">{{ $l['debit'] > 0 ? $amt($l['debit']) : '' }}</td>
                <td class="r">{{ $l['credit'] > 0 ? $amt($l['credit']) : '' }}</td>
                <td class="r">{{ $amt($l['balance']) }}</td>
            </tr>
        @empty
            <tr><td colspan="9" class="c" style="color:#6b7280">No transactions in the selected period — لا توجد حركات خلال الفترة</td></tr>
        @endforelse
    </tbody>
</table>

<table class="total">
    <tr>
        <td style="width:50%">Total &nbsp;·&nbsp; الرصيد الختامي</td>
        <td style="text-align:right; direction:ltr">{{ $amt($statement['closing']) }}</td>
    </tr>
</table>

<div class="note" dir="rtl">
    إجمالي المدين خلال الفترة {{ $amt($statement['debit']) }} · إجمالي الدائن {{ $amt($statement['credit']) }} · الرصيد الموجب مستحق على العميل.
    @if(($statement['source'] ?? '') === 'documents')
        مبني على مستندات المبيعات والدفعات ولا يشمل قيود اليومية اليدوية.
    @else
        مستخرج من دفتر الأستاذ في SAP.
    @endif
    رصيد SAP وقت آخر مزامنة ({{ optional($customer->synced_at)->format('d.m.Y H:i') ?: '-' }}): {{ $amt($customer->current_account_balance) }}
</div>

</body>
</html>
