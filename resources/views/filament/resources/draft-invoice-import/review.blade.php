@php
    /** @var \App\Models\DraftInvoiceRun $run */
    $t = $run->totals ?? [];
    $groups = $t['warehouses'] ?? [];
    uasort($groups, fn ($a, $b) => ($b['net'] ?? 0) <=> ($a['net'] ?? 0));
    $isPost = $run->mode === 'post';
    $money = fn ($v) => number_format((float) $v, 2);
    $qty = fn ($v) => rtrim(rtrim(number_format((float) $v, 3), '0'), '.');
    $returns = $t['returns'] ?? ['lines' => 0, 'qty' => 0, 'value' => 0, 'unmatched' => 0, 'detail' => []];
    $dups = $t['duplicates'] ?? ['groups' => 0, 'extra_lines' => 0, 'value' => 0];
    $statusLabel = match ($run->status) {
        'pending' => 'بالانتظار', 'running' => 'يعمل الآن…', 'done' => 'اكتمل', 'failed' => 'فشل', default => $run->status,
    };
@endphp

<div class="dir-review" dir="rtl">
    <style>
        .dir-review { --bd: rgba(15, 23, 42, .09); --mut: #64748b; --card: rgba(15, 23, 42, .025); --ok: #047857; --okbg: rgba(16, 185, 129, .1); --warn: #b45309; --warnbg: rgba(245, 158, 11, .12); --err: #b91c1c; --errbg: rgba(239, 68, 68, .1); --acc: #4338ca; --accbg: rgba(99, 102, 241, .1); font-size: .875rem; }
        .dark .dir-review { --bd: rgba(255, 255, 255, .1); --mut: #94a3b8; --card: rgba(255, 255, 255, .03); --ok: #34d399; --warn: #fbbf24; --err: #f87171; --acc: #a5b4fc; }
        .dir-review .meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; color: var(--mut); font-size: .8rem; margin-bottom: 1rem; }
        .dir-review .meta b { color: inherit; font-weight: 600; }
        .dir-review .pill { display: inline-flex; align-items: center; gap: .35rem; padding: .15rem .6rem; border-radius: 999px; font-size: .75rem; font-weight: 600; }
        .dir-review .pill.ok { color: var(--ok); background: var(--okbg); }
        .dir-review .pill.warn { color: var(--warn); background: var(--warnbg); }
        .dir-review .pill.err { color: var(--err); background: var(--errbg); }
        .dir-review .pill.acc { color: var(--acc); background: var(--accbg); }
        .dir-review .banner { border-radius: .75rem; padding: .85rem 1rem; margin-bottom: 1rem; line-height: 1.7; }
        .dir-review .banner.err { color: var(--err); background: var(--errbg); }
        .dir-review .banner.ok { color: var(--ok); background: var(--okbg); }
        .dir-review .banner.acc { color: var(--acc); background: var(--accbg); }
        .dir-review .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: .75rem; margin-bottom: 1.25rem; }
        .dir-review .kpi { border: 1px solid var(--bd); background: var(--card); border-radius: .75rem; padding: .8rem .9rem; }
        .dir-review .kpi .l { color: var(--mut); font-size: .75rem; }
        .dir-review .kpi .v { font-size: 1.35rem; font-weight: 700; font-variant-numeric: tabular-nums; margin-top: .15rem; }
        .dir-review .kpi .s { color: var(--mut); font-size: .72rem; margin-top: .1rem; }
        .dir-review h4 { font-weight: 700; font-size: .9rem; margin: 1.25rem 0 .5rem; }
        .dir-review .tbl { border: 1px solid var(--bd); border-radius: .75rem; overflow: auto; max-height: 26rem; }
        .dir-review table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
        .dir-review th { position: sticky; top: 0; background: var(--card); backdrop-filter: blur(6px); text-align: right; font-weight: 600; font-size: .75rem; color: var(--mut); padding: .55rem .75rem; border-bottom: 1px solid var(--bd); white-space: nowrap; }
        .dir-review td { padding: .5rem .75rem; border-bottom: 1px solid var(--bd); white-space: nowrap; }
        .dir-review tr:last-child td { border-bottom: 0; }
        .dir-review td.n, .dir-review th.n { text-align: left; }
        .dir-review tfoot td { font-weight: 700; background: var(--card); }
        .dir-review .code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .78rem; color: var(--mut); }
        .dir-review .log { background: #0f172a; color: #e2e8f0; border-radius: .75rem; padding: .75rem; font-size: .72rem; direction: ltr; text-align: left; max-height: 16rem; overflow: auto; white-space: pre-wrap; }
        .dir-review ul.notes { margin: 0; padding: 0; list-style: none; }
        .dir-review ul.notes li { display: flex; justify-content: space-between; gap: 1rem; padding: .5rem .75rem; border-bottom: 1px solid var(--bd); }
        .dir-review ul.notes li:last-child { border-bottom: 0; }
    </style>

    <div class="meta">
        <span class="pill {{ $run->status === 'done' ? 'ok' : ($run->status === 'failed' ? 'err' : 'acc') }}">{{ $statusLabel }}</span>
        <span>{{ $isPost ? 'رفع إلى SAP' : 'تحليل قبل الرفع' }}</span>
        <span>الملف: <b>{{ $run->source_file }}</b></span>
        <span>قاعدة SAP: <b>{{ $run->company_db }}</b></span>
        <span>تاريخ المستند: <b>{{ optional($run->doc_date)->format('Y-m-d') }}</b></span>
        @if (!empty($t['period']['from']))
            <span>الطلبات من <b>{{ $t['period']['from'] }}</b> إلى <b>{{ $t['period']['to'] }}</b></span>
        @endif
    </div>

    @if (in_array($run->status, ['pending', 'running']))
        <div class="banner acc">العملية شغالة في الخلفية. تتحدث الصفحة تلقائياً، ويظهر التقرير هنا أول ما تخلص.</div>
        @if ($logTail)
            <div class="log">{{ $logTail }}</div>
        @endif
    @elseif ($run->status === 'failed')
        <div class="banner err"><b>العملية فشلت:</b> {{ $run->error }}</div>
    @endif

    @if ($t)
        @if (($t['errors'] ?? 0) > 0)
            <div class="banner err">
                <b>{{ $t['errors'] }} خطأ يمنع الرفع.</b> صحّح الملف ثم ارفعه من جديد للتحليل. التفاصيل في «الملاحظات» تحت وفي تقرير Excel.
            </div>
        @elseif (!$isPost && $run->status === 'done')
            <div class="banner ok">
                الملف جاهز للرفع: {{ $t['drafts'] }} مسودة لـ {{ count($groups) }} {{ count($groups) === 1 ? 'عميل' : 'عملاء' }}. اضغط «ارفع إلى SAP» من الجدول لما تكون راضي عن الأرقام.
            </div>
        @elseif ($isPost && $run->status === 'done')
            <div class="banner {{ ($t['failed'] ?? 0) ? 'err' : 'ok' }}">
                أُنشئت {{ $t['posted'] }} مسودة{{ ($t['skipped'] ?? 0) ? '، و' . $t['skipped'] . ' كانت مرفوعة من قبل' : '' }}{{ ($t['failed'] ?? 0) ? '، وفشلت ' . $t['failed'] . ' — أعد الرفع وتُكمَل الناقصة فقط' : '' }}.
                المسودات لا تُرحّل محاسبياً حتى تفتحها في SAP وتضغط Add.
            </div>
        @endif

        <div class="kpis">
            <div class="kpi"><div class="l">العملاء</div><div class="v">{{ count($groups) }}</div></div>
            <div class="kpi"><div class="l">المسودات</div><div class="v">{{ $t['drafts'] ?? 0 }}</div><div class="s">{{ $run->chunk_size }} سطر لكل مسودة</div></div>
            <div class="kpi"><div class="l">الأسطر</div><div class="v">{{ number_format($t['lines'] ?? 0) }}</div><div class="s">من {{ number_format($t['rows'] ?? 0) }} سطر في الملف</div></div>
            <div class="kpi"><div class="l">الصافي ﷼</div><div class="v">{{ $money($t['net_total'] ?? 0) }}</div><div class="s">بعد الخصم وقبل الضريبة</div></div>
            <div class="kpi"><div class="l">مرتجعات خُصمت</div><div class="v">{{ $returns['lines'] ?? 0 }}</div><div class="s">{{ $qty($returns['qty'] ?? 0) }} حبة · {{ $money($returns['value'] ?? 0) }} ﷼</div></div>
            <div class="kpi"><div class="l">أسطر مكررة</div><div class="v">{{ $dups['extra_lines'] ?? 0 }}</div><div class="s">{{ $money($dups['value'] ?? 0) }} ﷼ · مرفوعة كما هي</div></div>
        </div>

        @if ($groups)
            <h4>العملاء</h4>
            <div class="tbl">
                <table>
                    <thead>
                        <tr>
                            <th>المتجر</th>
                            <th>المستودع</th>
                            <th class="n">الأسطر</th>
                            <th class="n">الكمية</th>
                            <th class="n">مرتجع مخصوم</th>
                            <th class="n">الصافي ﷼</th>
                            <th class="n">المسودات</th>
                            @if ($isPost)<th>أرقام المسودات في SAP</th>@endif
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($groups as $key => $g)
                            <tr>
                                <td>{{ $g['name'] ?? '' }} <span class="code">{{ $g['card_code'] ?? $key }}</span></td>
                                <td class="code">{{ $g['warehouse'] ?? $key }}</td>
                                <td class="n">{{ number_format($g['lines'] ?? 0) }}</td>
                                <td class="n">{{ $qty($g['qty'] ?? 0) }}</td>
                                <td class="n">@if ($g['returns_qty'] ?? 0)<bdi>{{ $qty($g['returns_qty']) }}</bdi> حبة · <bdi>{{ $money($g['returns_value'] ?? 0) }}</bdi> ﷼@else — @endif</td>
                                <td class="n">{{ $money($g['net'] ?? 0) }}</td>
                                <td class="n">{{ $isPost ? ($g['posted'] ?? 0) + ($g['skipped'] ?? 0) . ' / ' : '' }}{{ $g['chunks'] ?? 0 }}</td>
                                @if ($isPost)<td class="code">{{ implode('، ', $g['doc_nums'] ?? []) ?: '—' }}</td>@endif
                            </tr>
                        @endforeach
                    </tbody>
                    <tfoot>
                        <tr>
                            <td>الإجمالي</td>
                            <td></td>
                            <td class="n">{{ number_format($t['lines'] ?? 0) }}</td>
                            <td class="n">{{ $qty($t['qty'] ?? 0) }}</td>
                            <td class="n">@if ($returns['qty'] ?? 0)<bdi>{{ $qty($returns['qty']) }}</bdi> حبة · <bdi>{{ $money($returns['value'] ?? 0) }}</bdi> ﷼@else — @endif</td>
                            <td class="n">{{ $money($t['net_total'] ?? 0) }}</td>
                            <td class="n">{{ $t['drafts'] ?? 0 }}</td>
                            @if ($isPost)<td></td>@endif
                        </tr>
                    </tfoot>
                </table>
            </div>
        @endif

        @if (!empty($returns['detail']))
            <h4>المرتجعات المخصومة من المبيعات</h4>
            <div class="tbl">
                <table>
                    <thead>
                        <tr><th>المتجر</th><th>طلب المرتجع</th><th>الصنف</th><th class="n">المرتجع</th><th class="n">خُصم</th><th class="n">القيمة ﷼</th><th>خُصم من</th></tr>
                    </thead>
                    <tbody>
                        @foreach ($returns['detail'] as $n)
                            <tr>
                                <td>{{ $n['store_name'] ?: $n['card_code'] }}</td>
                                <td class="code">{{ $n['order_number'] }}</td>
                                <td><span class="code">{{ $n['item_code'] }}</span> {{ \Illuminate\Support\Str::limit($n['item_name'] ?? '', 38) }}</td>
                                <td class="n">{{ $qty($n['return_qty']) }}</td>
                                <td class="n">
                                    {{ $qty($n['netted_qty']) }}
                                    @if (($n['unmatched_qty'] ?? 0) > 0)<span class="pill warn">لم يُخصم {{ $qty($n['unmatched_qty']) }}</span>@endif
                                </td>
                                <td class="n">{{ $money($n['value']) }}</td>
                                <td class="code">{{ $n['from_label'] ?? '' }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if (($returns['lines'] ?? 0) > count($returns['detail']))
                <div class="meta" style="margin-top:.5rem">يظهر أول {{ count($returns['detail']) }} مرتجع — القائمة الكاملة في تقرير Excel.</div>
            @endif
        @endif

        @if ($notes)
            <h4>الملاحظات</h4>
            <div class="tbl">
                <ul class="notes">
                    @foreach ($notes as $note)
                        <li>
                            <span>{{ $note['label'] }}</span>
                            <span class="pill {{ $note['blocking'] ? 'err' : 'warn' }}">{{ $note['blocking'] ? 'يمنع الرفع' : 'تنبيه' }} · {{ $note['count'] }}</span>
                        </li>
                    @endforeach
                </ul>
            </div>
        @endif
    @endif
</div>
