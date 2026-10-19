@php
    $b        = $inv['brand'];
    $cPrimary = $b['color_primary'] ?? '#1F2358';
    $cAccent  = $b['color_accent'] ?? '#F26A21';
    $cOnAcc   = $b['color_on_accent'] ?? '#FFFFFF';
    $cHead    = $b['color_head'] ?? '#D9E7F5';
    $logo     = resource_path($b['logo'] ?? 'images/shipgo-logo.png');
    $t        = $inv['totals'];
    $z        = $inv['zatca'];
    $cur      = $inv['currency'] === 'SAR' ? 'ر.س' : $inv['currency'];
    $n        = fn ($v, $d = 2) => number_format((float) $v, $d);
    $qty      = fn ($v) => rtrim(rtrim(number_format((float) $v, 3, '.', ','), '0'), '.');
    $date     = fn ($s) => $s ? \Carbon\Carbon::parse($s)->format('d/m/Y') : '—';
    $hasDisc  = collect($inv['lines'])->contains(fn ($l) => $l['discount'] > 0);
    $idLabels = ['CRN' => 'السجل التجاري', 'NAT' => 'الهوية الوطنية', 'IQA' => 'رقم الإقامة', 'TIN' => 'الرقم المميز', '700' => 'الرقم الموحد 700', 'MOM' => 'ترخيص الموارد البشرية', 'MLS' => 'ترخيص البلدية', 'SAG' => 'ترخيص الاستثمار', 'GCC' => 'هوية خليجية', 'PAS' => 'جواز السفر', 'OTH' => 'رقم تعريف آخر'];
    $zatcaOk  = in_array($z['status'], ['CLEARED', 'REPORTED'], true) || $z['reported'];
@endphp
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<style>
    @page { margin: 8mm 8mm 14mm 8mm; }
    body { font-family: tajawal, sans-serif; color: #1f2937; font-size: 8pt; }
    table { border-collapse: collapse; }
    .en { color: #6b7280; font-size: 6.5pt; font-family: dejavusans, tajawal; }
    .muted { color: #6b7280; }

    /* header */
    .hdr { width: 100%; }
    .hdr td { padding: 0; vertical-align: middle; }
    .logo { width: 36mm; text-align: center; background: #fff; }
    .band1 { background: {{ $cPrimary }}; color: #fff; height: 14mm; padding: 0; }
    .band1 .t { font-size: 17pt; font-weight: bold; }
    .band1 .te { font-size: 8pt; letter-spacing: 2px; font-family: dejavusans, tajawal; color: #e5e7eb; }
    .band2 { background: {{ $cAccent }}; color: {{ $cOnAcc }}; height: 9mm; padding: 0 5mm; font-size: 9.5pt; font-weight: bold; }

    .cancel { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; padding: 2mm; text-align: center; font-weight: bold; font-size: 11pt; margin-top: 2mm; }
    .warn { background: #fff7ed; color: #9a3412; border: 1px solid #fdba74; padding: 1.6mm 3mm; margin-top: 2mm; font-size: 7.5pt; }

    /* parties + QR */
    .parties { width: 100%; margin-top: 3mm; }
    td.pcell { vertical-align: top; }
    table.card { width: 100%; border: 1px solid #e5e7eb; }
    table.card td { padding: 1.1mm 2.5mm; vertical-align: top; font-size: 7.8pt; }
    table.card td.ch { background: {{ $cHead }}; padding: 1.8mm 2.5mm; font-weight: bold; font-size: 8.8pt; border-bottom: 1px solid #e5e7eb; }
    table.card td.k { color: #6b7280; width: 33%; }
    table.card td.v { font-weight: bold; }
    table.qrbox { width: 100%; border: 1px solid #e5e7eb; }
    table.qrbox td { text-align: center; padding: 1.5mm 1mm; }
    .badge { display: inline; padding: 0.8mm 2mm; font-size: 7pt; font-weight: bold; }
    .ok { background: #dcfce7; color: #166534; }
    .no { background: #f3f4f6; color: #6b7280; }

    /* details strip */
    .meta { width: 100%; margin-top: 3mm; border: 1px solid #e5e7eb; }
    .meta td { padding: 1.6mm 2mm; border-left: 1px solid #f1f5f9; vertical-align: top; width: 16.6%; }
    .meta .k { color: #6b7280; font-size: 7pt; }
    .meta .ke { color: #9ca3af; font-size: 6pt; font-family: dejavusans, tajawal; }
    .meta .v { font-weight: bold; font-size: 8.3pt; }

    /* lines */
    table.lines { width: 100%; margin-top: 3mm; }
    table.lines th { background: {{ $cPrimary }}; color: #fff; padding: 1.8mm 1.2mm; font-size: 7.4pt; font-weight: bold; text-align: center; vertical-align: middle; }
    table.lines th .en { color: #dbe3f0; font-size: 6pt; font-weight: normal; }
    table.lines td { padding: 1.5mm 1.2mm; border-bottom: 1px solid #eef1f5; font-size: 7.6pt; vertical-align: middle; }
    table.lines tr.alt td { background: #fafbfd; }
    td.c { text-align: center; }
    td.num { text-align: left; direction: ltr; white-space: nowrap; }
    .code { color: #6b7280; font-size: 6.6pt; font-family: dejavusans, tajawal; direction: ltr; }

    /* bottom */
    .bottom { width: 100%; margin-top: 3mm; }
    td.bcell { vertical-align: top; }
    .tot { width: 100%; border: 1px solid #e5e7eb; }
    .tot td { padding: 1.5mm 2.5mm; border-bottom: 1px solid #f1f5f9; font-size: 8pt; }
    .tot td.k { color: #374151; }
    .tot td.v { text-align: left; direction: ltr; white-space: nowrap; font-weight: bold; }
    .tot tr.sub td { background: #f9fafb; }
    .tot tr.grand td { background: {{ $cAccent }}; color: {{ $cOnAcc }}; font-size: 11pt; font-weight: bold; border: none; padding: 2.4mm 2.5mm; }
    .tot tr.grand td .en { color: {{ $cOnAcc }}; font-size: 7pt; }
    table.box { width: 100%; border: 1px solid #e5e7eb; margin-bottom: 2mm; }
    table.box td { padding: 1.6mm 2.5mm; }
    table.box td.h { background: {{ $cHead }}; font-weight: bold; font-size: 7.8pt; color: #374151; }
    .vatb { width: 100%; }
    .vatb th { background: {{ $cHead }}; font-size: 7pt; padding: 1.2mm; }
    .vatb td { font-size: 7.4pt; padding: 1.2mm; text-align: center; border-bottom: 1px solid #f1f5f9; }

    .zfoot { margin-top: 3mm; border-top: 2px solid {{ $cPrimary }}; padding-top: 1.6mm; font-size: 6.8pt; color: #4b5563; }
    .hash { font-family: dejavusans; font-size: 5.8pt; color: #9ca3af; direction: ltr; }
</style>
</head>
<body>

{{-- ============ header ============ --}}
<table class="hdr">
    <tr>
        <td class="logo" rowspan="2">
            @if(is_file($logo))<img src="{{ $logo }}" style="width: {{ $b['logo_width'] ?? '30mm' }};">@endif
        </td>
        <td class="band1">
            <table style="width:100%"><tr>
                <td style="text-align:right; color:#ffffff; font-size:17pt; font-weight:bold; padding:0 4mm">{{ $inv['title_ar'] }}<br><span style="font-size:8pt; color:#e5e7eb; font-family:dejavusans">{{ strtoupper($inv['title_en']) }}</span></td>
                <td style="text-align:left; color:#ffffff; font-size:10pt; font-weight:bold; padding:0 4mm">{{ $b['company_name_ar'] ?? '' }}<br><span style="font-size:8pt; color:#e5e7eb; font-family:dejavusans">{{ $b['company_name'] ?? '' }}</span></td>
            </tr></table>
        </td>
    </tr>
    <tr>
        <td class="band2">
            رقم الفاتورة <span dir="ltr">{{ $inv['number'] }}</span>
            &nbsp;&nbsp;·&nbsp;&nbsp; تاريخ الإصدار {{ $date($inv['issue_date']) }} <span dir="ltr">{{ $inv['issue_time'] }}</span>
        </td>
    </tr>
</table>

@if($inv['cancelled'])
    <div class="cancel">فاتورة ملغاة — CANCELLED</div>
@endif
@if(!$zatcaOk)
    <div class="warn">لم تُرسَل هذه الفاتورة إلى منصة «فاتورة» لدى هيئة الزكاة والضريبة والجمارك — هذه نسخة من النظام وليست فاتورة إلكترونية معتمدة.</div>
@endif

{{-- ============ seller | buyer | QR ============ --}}
<table class="parties">
    <tr>
        <td class="pcell" style="width:37%; padding-left:2mm">
            <table class="card">
                    <tr><td class="ch" colspan="2">البائع <span class="en">Seller</span></td></tr>
                    <tr><td class="k">الاسم</td><td class="v">{{ $inv['seller']['name'] ?? '—' }}</td></tr>
                    <tr><td class="k">الرقم الضريبي</td><td class="v" dir="ltr" style="text-align:right">{{ $inv['seller']['vat'] ?? '—' }}</td></tr>
                    @foreach($inv['seller']['ids'] ?? [] as $id)
                        <tr><td class="k">{{ $idLabels[$id['scheme']] ?? $id['scheme'] }}</td><td class="v" dir="ltr" style="text-align:right">{{ $id['value'] }}</td></tr>
                    @endforeach
                    <tr><td class="k">العنوان</td><td>{{ $inv['seller']['address'] ?? '—' }}</td></tr>
            </table>
        </td>
        <td class="pcell" style="width:37%; padding-left:2mm">
            <table class="card">
                    <tr><td class="ch" colspan="2">المشتري <span class="en">Buyer</span></td></tr>
                    <tr><td class="k">الاسم</td><td class="v">{{ $inv['buyer']['name'] ?? '—' }}</td></tr>
                    <tr><td class="k">رمز العميل</td><td class="v" dir="ltr" style="text-align:right">{{ $inv['buyer']['code'] ?? '—' }}</td></tr>
                    <tr><td class="k">الرقم الضريبي</td><td class="v" dir="ltr" style="text-align:right">{{ $inv['buyer']['vat'] ?? '—' }}</td></tr>
                    @foreach($inv['buyer']['ids'] ?? [] as $id)
                        <tr><td class="k">{{ $idLabels[$id['scheme']] ?? $id['scheme'] }}</td><td class="v" dir="ltr" style="text-align:right">{{ $id['value'] }}</td></tr>
                    @endforeach
                    <tr><td class="k">العنوان</td><td>{{ $inv['buyer']['address'] ?? '—' }}</td></tr>
            </table>
        </td>
        <td class="pcell" style="width:26%">
            <table class="qrbox">
                <tr><td>
                    @if($z['qr_png'])
                        <img src="{{ $z['qr_png'] }}" style="width:30mm; height:30mm" alt="ZATCA QR">
                    @else
                        <span style="color:#9ca3af; font-size:7.5pt">لا يوجد رمز QR معتمد لهذه الفاتورة</span>
                    @endif
                </td></tr>
                <tr><td style="font-size:6.6pt; color:#4b5563; padding-top:0">رمز التحقق — هيئة الزكاة والضريبة والجمارك</td></tr>
                <tr><td style="padding-top:0">
                    @if($z['status'] === 'CLEARED')
                        <span class="badge ok">مُجازة من الهيئة · CLEARED</span>
                    @elseif($z['status'] === 'REPORTED' || $z['reported'])
                        <span class="badge ok">مُبلَّغة للهيئة · REPORTED</span>
                    @else
                        <span class="badge no">غير مُبلَّغة</span>
                    @endif
                </td></tr>
            </table>
        </td>
    </tr>
</table>

{{-- ============ invoice details ============ --}}
<table class="meta">
    <tr>
        <td><div class="k">رقم الفاتورة <br><span class="ke">Invoice No.</span></div><div class="v" dir="ltr" style="text-align:right">{{ $inv['number'] }}</div></td>
        <td><div class="k">تاريخ الإصدار <br><span class="ke">Issue date</span></div><div class="v">{{ $date($inv['issue_date']) }} <span dir="ltr">{{ $inv['issue_time'] }}</span></div></td>
        <td><div class="k">تاريخ التوريد <br><span class="ke">Supply date</span></div><div class="v">{{ $date($inv['supply_date']) }}</div></td>
        <td><div class="k">تاريخ الاستحقاق <br><span class="ke">Due date</span></div><div class="v">{{ $date($inv['due_date']) }}</div></td>
        <td><div class="k">مرجع العميل <br><span class="ke">Customer ref.</span></div><div class="v" dir="ltr" style="text-align:right">{{ $inv['customer_ref'] ?: '—' }}</div></td>
        <td style="border-left:none"><div class="k">العملة <br><span class="ke">Currency</span></div><div class="v">{{ $inv['currency'] }}</div></td>
    </tr>
</table>

{{-- ============ lines ============ --}}
<table class="lines">
    <thead>
        <tr>
            <th style="width:4%">#</th>
            <th>البيان<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Description</span></th>
            <th style="width:8%">الكمية<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Qty</span></th>
            <th style="width:10%">سعر الوحدة<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Unit price</span></th>
            @if($hasDisc)<th style="width:6%">الخصم<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Disc. %</span></th>@endif
            <th style="width:11%">المبلغ الخاضع للضريبة<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Taxable amount</span></th>
            <th style="width:6%">نسبة الضريبة<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">VAT %</span></th>
            <th style="width:10%">مبلغ الضريبة<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">VAT amount</span></th>
            <th style="width:12%">الإجمالي شامل الضريبة<br><span style="color:#e8edf5; font-size:6pt; font-weight:normal; font-family:dejavusans">Total incl. VAT</span></th>
        </tr>
    </thead>
    <tbody>
        @foreach($inv['lines'] as $i => $l)
            <tr class="{{ $i % 2 ? 'alt' : '' }}">
                <td class="c">{{ $l['no'] }}</td>
                <td>
                    {{ $l['description'] }}
                    @if($l['code'] || $l['barcode'])
                        <br><span class="code">{{ $l['code'] }}{{ $l['barcode'] ? ' · ' . $l['barcode'] : '' }}</span>
                    @endif
                </td>
                <td class="c">{{ $qty($l['qty']) }}@if($l['unit']) <span class="code">{{ $l['unit'] }}</span>@endif</td>
                <td class="num">{{ $n($l['unit_price'], 2) }}</td>
                @if($hasDisc)<td class="c">{{ $l['discount'] > 0 ? $n($l['discount'], 2) . '%' : '' }}</td>@endif
                <td class="num">{{ $n($l['net']) }}</td>
                <td class="c">{{ rtrim(rtrim(number_format($l['vat_rate'], 2), '0'), '.') }}%</td>
                <td class="num">{{ $n($l['vat']) }}</td>
                <td class="num"><b>{{ $n($l['total']) }}</b></td>
            </tr>
        @endforeach
    </tbody>
</table>

{{-- ============ words / breakdown | totals ============ --}}
<table class="bottom">
    <tr>
        <td class="bcell" style="width:55%; padding-left:3mm">
            <table class="box">
                <tr><td class="h">المبلغ كتابةً <span class="en">Amount in words</span></td></tr>
                <tr><td style="font-size:8.6pt; font-weight:bold">{{ $inv['amount_words'] }}</td></tr>
            </table>
            @if(count($inv['vat_breakdown']))
                <table class="box">
                    <tr><td class="h">ملخص ضريبة القيمة المضافة <span class="en">VAT summary</span></td></tr>
                    <tr><td style="padding:0">
                    <table class="vatb">
                        <tr><th>الفئة</th><th>النسبة</th><th>المبلغ الخاضع للضريبة</th><th>مبلغ الضريبة</th></tr>
                        @foreach($inv['vat_breakdown'] as $vb)
                            <tr>
                                <td>{{ ['S' => 'خاضع للنسبة الأساسية', 'Z' => 'نسبة صفرية', 'E' => 'معفى', 'O' => 'خارج نطاق الضريبة'][$vb['category']] ?? $vb['category'] }}@if($vb['reason'])<br><span class="en">{{ $vb['reason'] }}</span>@endif</td>
                                <td>{{ rtrim(rtrim(number_format($vb['rate'], 2), '0'), '.') }}%</td>
                                <td dir="ltr">{{ $n($vb['taxable']) }}</td>
                                <td dir="ltr">{{ $n($vb['vat']) }}</td>
                            </tr>
                        @endforeach
                    </table>
                    </td></tr>
                </table>
            @endif
            @if($inv['notes'])
                <table class="box">
                    <tr><td class="h">ملاحظات <span class="en">Notes</span></td></tr>
                    <tr><td>{{ $inv['notes'] }}</td></tr>
                </table>
            @endif
        </td>
        <td class="bcell" style="width:45%">
            <table class="tot">
                <tr><td class="k">الإجمالي غير شامل الضريبة <span class="en">Total excl. VAT</span></td><td class="v">{{ $n($t['lines_net']) }} {{ $cur }}</td></tr>
                @if($t['discount'] > 0)
                    <tr><td class="k">الخصم <span class="en">Discount</span></td><td class="v">- {{ $n($t['discount']) }} {{ $cur }}</td></tr>
                @endif
                @foreach($inv['charges'] as $ch)
                    <tr><td class="k">مصاريف شحن — {{ $ch['name'] }} <span class="en">Charge</span></td><td class="v">{{ $n($ch['net']) }} {{ $cur }}</td></tr>
                @endforeach
                <tr class="sub"><td class="k"><b>الإجمالي الخاضع للضريبة</b> <span class="en">Taxable amount</span></td><td class="v">{{ $n($t['taxable']) }} {{ $cur }}</td></tr>
                <tr><td class="k">ضريبة القيمة المضافة <span class="en">VAT</span></td><td class="v">{{ $n($t['vat']) }} {{ $cur }}</td></tr>
                <tr class="sub"><td class="k"><b>الإجمالي شامل الضريبة</b> <span class="en">Total incl. VAT</span></td><td class="v">{{ $n($t['total']) }} {{ $cur }}</td></tr>
                @if($t['prepaid'] > 0)
                    <tr><td class="k">المبالغ المدفوعة مقدماً <span class="en">Prepaid</span></td><td class="v">- {{ $n($t['prepaid']) }} {{ $cur }}</td></tr>
                @endif
                @if(abs($t['rounding']) >= 0.01)
                    <tr><td class="k">فرق التقريب <span class="en">Rounding</span></td><td class="v">{{ $n($t['rounding']) }} {{ $cur }}</td></tr>
                @endif
                <tr class="grand"><td>المبلغ المستحق <span style="font-size:7pt; color:{{ $cOnAcc }}; font-family:dejavusans">Amount due</span></td><td style="text-align:left; direction:ltr">{{ $n($t['payable']) }} {{ $cur }}</td></tr>
            </table>
            <table style="width:100%; margin-top:1.5mm; font-size:7.4pt">
                <tr>
                    <td class="muted">حالة السداد</td>
                    <td style="text-align:left; font-weight:bold">
                        @if($inv['cancelled']) ملغاة
                        @elseif($t['balance'] <= 0.009) مسدَّدة بالكامل
                        @elseif($t['paid'] > 0) مسدَّد {{ $n($t['paid']) }} — المتبقي {{ $n($t['balance']) }} {{ $cur }}
                        @else غير مسدَّدة
                        @endif
                    </td>
                </tr>
            </table>
        </td>
    </tr>
</table>

{{-- ============ ZATCA footer ============ --}}
<div class="zfoot">
    @if($z['status'] === 'CLEARED')
        فاتورة إلكترونية مُجازة (Cleared) من هيئة الزكاة والضريبة والجمارك عبر منصة «فاتورة»
    @elseif($z['status'] === 'REPORTED' || $z['reported'])
        فاتورة إلكترونية مُبلَّغة (Reported) لهيئة الزكاة والضريبة والجمارك عبر منصة «فاتورة»
    @else
        نسخة مطبوعة من نظام SAP
    @endif
    @if($z['reported_at']) · بتاريخ <span dir="ltr">{{ $z['reported_at'] }}</span>@endif
    @if($z['icv']) · عدّاد الفاتورة <span dir="ltr">{{ $z['icv'] }}</span>@endif
    · طُبعت في <span dir="ltr">{{ $generated->format('d/m/Y H:i') }}</span>
    @if($z['hash'])<br><span class="hash">Invoice hash: {{ $z['hash'] }}</span>@endif
</div>

</body>
</html>
