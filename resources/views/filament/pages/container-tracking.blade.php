@php
    $counts  = $this->counts();
    $ships   = $this->visibleShipments();
    $attn    = $this->attentionItems();
    $sel     = $this->selectedShipment();
    $synced  = $this->lastSyncedLabel();
    $sum     = $this->summary();

    // [accent, soft-bg, ink] per state — inline so nothing depends on Tailwind purge.
    $palette = [
        'cyan'    => ['#0e7490', '#ecfeff', '#0c4a6e'],
        'rose'    => ['#e11d48', '#fff1f2', '#9f1239'],
        'amber'   => ['#d97706', '#fffbeb', '#92400e'],
        'emerald' => ['#059669', '#ecfdf5', '#065f46'],
        'slate'   => ['#64748b', '#f8fafc', '#334155'],
    ];

    $filters = [
        'all'        => ['الكل',        'slate'],
        'overdue'    => ['متأخرة',      'rose'],
        'arriving'   => ['تصل قريباً',  'amber'],
        'in_transit' => ['في الطريق',   'cyan'],
        'pending'    => ['قيد التهيئة', 'slate'],
        'delivered'  => ['وصلت',        'emerald'],
    ];

    $sorts = ['urgency' => 'الأعجل', 'eta' => 'الأقرب وصولاً', 'added' => 'الأحدث'];

    $transportIcon = function ($t) {
        return match (strtoupper((string) $t)) {
            'VESSEL', 'SEA', 'BARGE' => '🚢',
            'TRUCK', 'LAND'          => '🚛',
            'RAIL', 'TRAIN'          => '🚆',
            default                  => '📍',
        };
    };
@endphp

<x-filament-panels::page>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <style>
        .ct-wrap { direction: rtl; font-family: 'Cairo', sans-serif; }

        /* ---- ocean banner ---- */
        .ct-banner {
            position:relative; overflow:hidden; border-radius:1.4rem; padding:1.5rem 1.6rem 2.2rem;
            background:linear-gradient(120deg,#0c4a6e 0%,#0e7490 55%,#0891b2 100%);
            color:#fff; margin-bottom:1.4rem; box-shadow:0 14px 34px rgba(8,72,90,.28);
        }
        .ct-banner::before { content:''; position:absolute; inset:0;
            background-image:radial-gradient(rgba(255,255,255,.14) 1px, transparent 1.4px);
            background-size:18px 18px; opacity:.5; }
        .ct-banner::after { content:''; position:absolute; left:0; right:0; bottom:-1px; height:34px;
            background:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1200 40' preserveAspectRatio='none'%3E%3Cpath d='M0 22 Q150 2 300 22 T600 22 T900 22 T1200 22 V40 H0Z' fill='%23ffffff' opacity='0.16'/%3E%3C/svg%3E") repeat-x; background-size:600px 34px; }
        .ct-banner-row { position:relative; z-index:1; display:flex; justify-content:space-between; align-items:flex-start; gap:1rem; flex-wrap:wrap; }
        .ct-banner h1 { font-size:1.45rem; font-weight:800; margin:0; display:flex; align-items:center; gap:.5rem; }
        .ct-banner p { font-size:.84rem; opacity:.9; margin:.35rem 0 0; }
        .ct-refresh { display:inline-flex; align-items:center; gap:.45rem; background:rgba(255,255,255,.16);
            border:1px solid rgba(255,255,255,.3); color:#fff; padding:.5rem .9rem; border-radius:.7rem;
            font-family:inherit; font-size:.82rem; font-weight:700; cursor:pointer; transition:.18s; }
        .ct-refresh:hover { background:rgba(255,255,255,.28); }
        .ct-banner-actions { display:flex; gap:.55rem; flex-wrap:wrap; }
        .ct-refresh svg { width:16px; height:16px; }
        .ct-spin { animation:ctspin 1s linear infinite; }
        @keyframes ctspin { to { transform:rotate(360deg); } }
        .ct-stats { position:relative; z-index:1; display:flex; gap:.7rem; margin-top:1.2rem; flex-wrap:wrap; }
        .ct-stat { background:rgba(255,255,255,.12); border-radius:.9rem; padding:.6rem 1rem; min-width:92px;
            backdrop-filter:blur(4px); border:1px solid rgba(255,255,255,.14); }
        .ct-stat b { display:block; font-size:1.35rem; font-weight:800; line-height:1.1; }
        .ct-stat span { font-size:.72rem; opacity:.88; font-weight:600; }
        .ct-stat.warn b { color:#fecaca; }

        /* ---- attention strip ---- */
        .ct-attn { margin-bottom:1.5rem; }
        .ct-attn-h { display:flex; align-items:center; gap:.5rem; font-size:.92rem; font-weight:800; color:#9f1239; margin:0 0 .7rem; }
        .ct-attn-h .dot { width:9px; height:9px; border-radius:50%; background:#e11d48; box-shadow:0 0 0 4px #fee2e2; animation:ctpulse 1.8s ease-in-out infinite; }
        @keyframes ctpulse { 0%,100%{ box-shadow:0 0 0 3px #fee2e2; } 50%{ box-shadow:0 0 0 7px rgba(225,29,72,.12); } }
        .ct-attn-scroll { display:flex; gap:.9rem; overflow-x:auto; padding:.2rem .2rem .6rem; scroll-snap-type:x mandatory; }
        .ct-attn-scroll > * { scroll-snap-align:start; flex:0 0 290px; }
        .ct-allgood { display:flex; align-items:center; gap:.6rem; background:#ecfdf5; color:#065f46; border:1px solid #a7f3d0;
            border-radius:1rem; padding:.9rem 1.2rem; font-weight:700; font-size:.9rem; margin-bottom:1.4rem; }

        /* ---- card (attention + mobile) ---- */
        .ct-c { background:#fff; border:1px solid #eef2f7; border-top:4px solid var(--accent,#0e7490);
            border-radius:1rem; padding:.9rem 1rem; cursor:pointer; transition:.2s; box-shadow:0 1px 3px rgba(15,23,42,.06);
            animation:ctUp .35s ease both; }
        .ct-c:hover { transform:translateY(-3px); box-shadow:0 12px 26px rgba(15,23,42,.13); }
        .dark .ct-c { background:#1f2937; border-color:#374151; }
        @keyframes ctUp { from{ opacity:0; transform:translateY(8px);} to{ opacity:1; transform:none;} }
        .ct-c-top { display:flex; align-items:center; justify-content:space-between; gap:.5rem; }
        .ct-c-carrier { font-size:.76rem; font-weight:700; color:#64748b; }
        .dark .ct-c-carrier { color:#9ca3af; }
        .ct-c-lane { margin:.6rem 0 .2rem; font-weight:800; font-size:.96rem; color:#0f172a; display:flex; align-items:center; gap:.5rem; flex-wrap:wrap; }
        .dark .ct-c-lane { color:#f1f5f9; }
        .ct-c-lane .arr { color:#94a3b8; font-weight:700; }
        .ct-c-lane .dest { color:#0e7490; }
        .ct-c-foot { display:flex; align-items:center; justify-content:space-between; gap:.5rem; margin-top:.7rem; }
        .ct-c-eta { font-size:.8rem; color:#64748b; font-weight:600; }

        /* ---- journey strip ---- */
        .ct-journey { display:flex; align-items:center; gap:.5rem; margin-top:.7rem; }
        .ct-journey .jp { font-size:1rem; flex:none; }
        .jtrack { position:relative; flex:1; height:6px; border-radius:999px; background:#eef2f7; }
        .dark .jtrack { background:#374151; }
        .jtrack > i { position:absolute; inset-block:0; inset-inline-start:0; border-radius:999px; }
        .jship { position:absolute; top:50%; transform:translateY(-50%); font-size:.8rem; line-height:1; animation:ctbob 3s ease-in-out infinite; }
        @keyframes ctbob { 0%,100%{ transform:translateY(-50%);} 50%{ transform:translateY(-72%);} }

        /* ---- shared chips / pills ---- */
        .ct-chip { font-size:.72rem; font-weight:800; padding:.25rem .6rem; border-radius:999px; white-space:nowrap; }
        .ct-days { font-size:.76rem; font-weight:800; padding:.2rem .55rem; border-radius:.55rem; white-space:nowrap; }
        .ct-tref { font-family:ui-monospace,monospace; font-size:.78rem; color:#94a3b8; letter-spacing:.4px; }

        /* ---- controls ---- */
        .ct-badges { display:flex; flex-wrap:wrap; gap:.55rem; margin-bottom:.9rem; }
        .ct-badge { display:flex; align-items:center; gap:.45rem; padding:.5rem .85rem; border-radius:1rem; cursor:pointer;
            border:1.5px solid transparent; background:#fff; transition:.18s; user-select:none; box-shadow:0 1px 2px rgba(15,23,42,.05); }
        .ct-badge:hover { transform:translateY(-1px); box-shadow:0 4px 12px rgba(15,23,42,.08); }
        .ct-badge .n { font-weight:800; font-size:1.02rem; line-height:1; }
        .ct-badge .l { font-size:.8rem; font-weight:600; }
        .ct-badge.active { color:#fff !important; }
        .dark .ct-badge { background:#1f2937; box-shadow:none; }

        .ct-tools { display:flex; align-items:center; justify-content:space-between; gap:.8rem; margin-bottom:.9rem; flex-wrap:wrap; }
        .ct-search { position:relative; flex:1; min-width:210px; max-width:340px; }
        .ct-search input { width:100%; padding:.55rem .95rem .55rem 2.2rem; border:1px solid #e2e8f0; border-radius:.7rem;
            font-family:inherit; font-size:.85rem; background:#fff; outline:none; transition:.15s; }
        .ct-search input:focus { border-color:#0e7490; box-shadow:0 0 0 3px rgba(14,116,144,.12); }
        .dark .ct-search input { background:#1f2937; border-color:#374151; color:#e5e7eb; }
        .ct-search .ic { position:absolute; inset-inline-start:.7rem; top:50%; transform:translateY(-50%); color:#94a3b8; }
        .ct-tools-end { display:flex; align-items:center; gap:.8rem; flex-wrap:wrap; }
        .ct-seg { display:inline-flex; background:#f1f5f9; border-radius:.7rem; padding:.2rem; gap:.15rem; }
        .dark .ct-seg { background:#0f1620; }
        .ct-seg button { border:none; background:transparent; font-family:inherit; font-size:.78rem; font-weight:700; color:#64748b;
            padding:.35rem .7rem; border-radius:.55rem; cursor:pointer; transition:.15s; }
        .ct-seg button.on { background:#fff; color:#0e7490; box-shadow:0 1px 3px rgba(15,23,42,.1); }
        .dark .ct-seg button.on { background:#1f2937; }
        .ct-toggle { display:inline-flex; align-items:center; gap:.5rem; cursor:pointer; font-size:.82rem; font-weight:700; color:#475569; user-select:none; }
        .dark .ct-toggle { color:#cbd5e1; }
        .ct-toggle input { width:40px; height:22px; -webkit-appearance:none; appearance:none; background:#cbd5e1; border-radius:999px;
            position:relative; cursor:pointer; transition:.2s; outline:none; flex:none; }
        .ct-toggle input:checked { background:#0e7490; }
        .ct-toggle input::after { content:''; position:absolute; top:2px; inset-inline-start:2px; width:18px; height:18px; background:#fff; border-radius:50%; transition:.2s; }
        .ct-toggle input:checked::after { inset-inline-start:20px; }

        /* ---- table (desktop) ---- */
        .ct-table-wrap { overflow-x:auto; border:1px solid #eef2f7; border-radius:1rem; background:#fff; box-shadow:0 1px 3px rgba(15,23,42,.06); }
        .dark .ct-table-wrap { background:#1f2937; border-color:#374151; }
        table.ct-table { width:100%; border-collapse:collapse; font-size:.86rem; }
        .ct-table thead th { text-align:start; font-size:.74rem; font-weight:800; color:#94a3b8; padding:.8rem 1rem; border-bottom:1px solid #eef2f7; white-space:nowrap; background:#fafbfc; }
        .dark .ct-table thead th { background:#111827; border-color:#374151; }
        .ct-table tbody tr { cursor:pointer; transition:background .15s; border-bottom:1px solid #f1f5f9; }
        .ct-table tbody tr:last-child { border-bottom:none; }
        .ct-table tbody tr:hover { background:#f8fafc; }
        .dark .ct-table tbody tr { border-color:#374151; }
        .dark .ct-table tbody tr:hover { background:#273244; }
        .ct-table td { padding:.75rem 1rem; vertical-align:middle; white-space:nowrap; }
        .ct-td-state { border-inline-start:4px solid transparent; }
        .ct-tlane { font-weight:700; color:#0f172a; }
        .dark .ct-tlane { color:#f1f5f9; }
        .ct-flagcity { white-space:nowrap; }
        .ct-lane-ltr { display:inline-flex; align-items:center; gap:.4rem; }
        .ct-arr { color:#94a3b8; }
        .ct-dates { display:flex; flex-direction:column; gap:.2rem; }
        .ct-dates .ship { font-size:.76rem; color:#94a3b8; font-weight:600; }
        .ct-dates .eta { font-size:.84rem; color:#0f172a; font-weight:500; }
        .dark .ct-dates .eta { color:#e5e7eb; }
        .ct-tcarrier { color:#475569; font-weight:600; }
        .dark .ct-tcarrier { color:#cbd5e1; }
        .ct-tbar { height:5px; width:84px; border-radius:999px; background:#eef2f7; overflow:hidden; display:inline-block; vertical-align:middle; }
        .dark .ct-tbar { background:#374151; }
        .ct-tbar > i { display:block; height:100%; border-radius:999px; }

        .ct-ghead td { background:#f1f5f9; color:#334155; font-weight:800; font-size:.82rem; padding:.55rem 1rem; border-bottom:1px solid #e2e8f0; }
        .dark .ct-ghead td { background:#0f1620; color:#cbd5e1; border-color:#374151; }
        .ct-ghead .cnt { font-size:.72rem; font-weight:800; padding:.12rem .5rem; border-radius:999px; background:#0e7490; color:#fff; margin-inline-start:.5rem; }
        .ct-ghead .ev { color:#64748b; font-weight:600; }
        .ct-sub > td:first-child { padding-inline-start:1.9rem; }

        /* ---- grouped: shipment blocks ---- */
        .ct-groups { display:flex; flex-direction:column; gap:1.1rem; }
        .ct-gblock { border:1px solid #e2e8f0; border-radius:1.1rem; overflow:hidden; background:#fff;
            box-shadow:0 2px 10px rgba(15,23,42,.06); border-inline-start:5px solid var(--accent,#0e7490); animation:ctUp .35s ease both; }
        .dark .ct-gblock { background:#1f2937; border-color:#374151; }
        .ct-gblock-head { display:flex; align-items:center; gap:.7rem; flex-wrap:wrap; padding:.8rem 1.15rem;
            background:#f8fafc; border-bottom:1px solid #eef2f7; }
        .dark .ct-gblock-head { background:#0f1620; border-color:#374151; }
        .ct-gblock-head .ttl { font-weight:800; font-size:.92rem; color:#0f172a; }
        .dark .ct-gblock-head .ttl { color:#f1f5f9; }
        .ct-gblock-head .meta { font-size:.8rem; color:#64748b; font-weight:600; }
        .dark .ct-gblock-head .meta { color:#94a3b8; }
        .ct-gblock-head .cnt { margin-inline-start:auto; font-size:.74rem; font-weight:800; padding:.22rem .65rem;
            border-radius:999px; background:var(--accent,#0e7490); color:#fff; white-space:nowrap; }
        .ct-gcards { display:grid; grid-template-columns:repeat(auto-fill,minmax(255px,1fr)); gap:.8rem; padding:1rem 1.15rem; }
        .ct-gcards .ct-c { box-shadow:none; animation:none; }
        .ct-gcards .ct-c:hover { box-shadow:0 8px 20px rgba(15,23,42,.12); }
        @media (max-width:768px){ .ct-gcards { grid-template-columns:1fr; padding:.8rem; } }
        .ct-gtbl-wrap { overflow-x:auto; }
        .ct-gtbl thead th { background:#fff; font-size:.7rem; padding:.5rem 1rem; color:#94a3b8; border-bottom:1px dashed #e2e8f0; }
        .dark .ct-gtbl thead th { background:#1f2937; border-color:#374151; }
        .ct-gtbl tbody tr:last-child { border-bottom:none; }

        /* ---- mobile cards list ---- */
        .ct-mobile { display:none; }
        .ct-mlist { display:flex; flex-direction:column; gap:.8rem; }
        .ct-mgroup { font-size:.8rem; font-weight:800; color:#334155; margin:.4rem .2rem -.2rem; }
        .dark .ct-mgroup { color:#cbd5e1; }
        @media (max-width:768px) {
            .ct-desktop { display:none; }
            .ct-mobile { display:block; }
            .ct-banner h1 { font-size:1.2rem; }
            .ct-stat { min-width:78px; flex:1; }
        }

        .ct-empty { text-align:center; padding:3rem 1rem; color:#94a3b8; }

        /* ---- detail drawer ---- */
        .ct-overlay { position:fixed; inset:0; background:rgba(15,23,42,.5); backdrop-filter:blur(2px); z-index:50;
            display:flex; justify-content:center; align-items:flex-start; padding:2.5vh 1rem; overflow:auto; animation:ctFade .2s ease; }
        @keyframes ctFade { from{ opacity:0;} to{ opacity:1;} }
        .ct-panel { background:#fff; border-radius:1.25rem; width:min(960px,100%); margin-block:auto;
            box-shadow:0 24px 60px rgba(2,6,23,.4); overflow:hidden; animation:ctRise .26s cubic-bezier(.2,.8,.2,1); }
        @keyframes ctRise { from{ opacity:0; transform:translateY(22px) scale(.98);} to{ opacity:1; transform:none;} }
        .dark .ct-panel { background:#111827; }
        .ct-phead { display:flex; align-items:center; justify-content:space-between; gap:1rem; padding:1.1rem 1.3rem; color:#fff; }
        .ct-phead h2 { font-size:1.12rem; font-weight:800; margin:0; }
        .ct-phead .sub { font-size:.82rem; opacity:.92; margin-top:.2rem; }
        .ct-x { background:rgba(255,255,255,.2); border:none; color:#fff; width:34px; height:34px; border-radius:50%; cursor:pointer; font-size:1.1rem; line-height:1; }
        .ct-x:hover { background:rgba(255,255,255,.32); }
        .ct-map { height:300px; width:100%; background:#e2e8f0; }
        .ct-pbody { padding:1.2rem 1.3rem; display:grid; grid-template-columns:1.4fr 1fr; gap:1.4rem; }
        @media (max-width:760px){ .ct-pbody { grid-template-columns:1fr; } .ct-map{ height:230px; } }
        .ct-sec-title { font-size:.8rem; font-weight:800; color:#94a3b8; margin:0 0 .7rem; letter-spacing:.5px; }
        .ct-etawarn { display:inline-flex; align-items:center; gap:.4rem; background:#fff7ed; color:#9a3412; border:1px solid #fed7aa;
            font-size:.78rem; font-weight:700; padding:.3rem .65rem; border-radius:.6rem; margin-bottom:.9rem; }

        .ct-tl { position:relative; padding-inline-start:1.1rem; }
        .ct-tl::before { content:''; position:absolute; inset-block:.4rem 0; inset-inline-start:4px; width:2px; background:#e2e8f0; }
        .dark .ct-tl::before { background:#374151; }
        .ct-ev { position:relative; padding:0 .9rem 1rem 0; }
        .ct-ev::before { content:''; position:absolute; inset-inline-start:-1.1rem; top:.25rem; width:10px; height:10px; border-radius:50%; background:#0e7490; box-shadow:0 0 0 3px #ecfeff; }
        .dark .ct-ev::before { box-shadow:0 0 0 3px #0b3a44; }
        .ct-ev.first::before { background:#e11d48; box-shadow:0 0 0 3px #ffe4e6; }
        .ct-ev .d { font-weight:700; font-size:.88rem; color:#0f172a; }
        .dark .ct-ev .d { color:#e5e7eb; }
        .ct-ev .m { font-size:.76rem; color:#94a3b8; margin-top:.15rem; }

        .ct-kv { display:flex; flex-direction:column; gap:.7rem; }
        .ct-kv .item { background:#f8fafc; border-radius:.7rem; padding:.6rem .8rem; }
        .dark .ct-kv .item { background:#1f2937; }
        .ct-kv .k { font-size:.72rem; color:#94a3b8; font-weight:700; }
        .ct-kv .v { font-size:.9rem; color:#0f172a; font-weight:700; margin-top:.15rem; }
        .dark .ct-kv .v { color:#f1f5f9; }
        .ct-sib { display:flex; flex-wrap:wrap; gap:.4rem; margin-top:.3rem; }
        .ct-sib a { font-family:ui-monospace,monospace; font-size:.76rem; font-weight:700; color:#0e7490; background:#ecfeff;
            border:1px solid #a5f3fc; padding:.25rem .55rem; border-radius:.5rem; cursor:pointer; text-decoration:none; }
        .ct-sib a:hover { background:#cffafe; }
        .ct-share { display:inline-flex; align-items:center; gap:.4rem; font-size:.8rem; font-weight:700; color:#0e7490; text-decoration:none; margin-top:.3rem; }
    </style>

    <div class="ct-wrap">

        {{-- ====== ocean banner ====== --}}
        <div class="ct-banner">
            <div class="ct-banner-row">
                <div>
                    <h1>🌊 تتبّع الحاويات الواردة</h1>
                    <p>الشحنات البحرية القادمة عبر Traqo · قراءة فقط @if ($synced) · آخر تحديث {{ $synced }} @endif</p>
                </div>
                <div class="ct-banner-actions">
                    <button class="ct-refresh" wire:click="refreshNow" wire:loading.attr="disabled">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"
                             wire:loading.class="ct-spin" wire:target="refreshNow">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992V4.356M3 12a9 9 0 1 0 2.636-6.364L1 10" transform="scale(-1,1) translate(-24,0)"/>
                        </svg>
                        <span wire:loading.remove wire:target="refreshNow">تحديث الآن</span>
                        <span wire:loading wire:target="refreshNow">جارٍ التحديث…</span>
                    </button>
                    <button class="ct-refresh" wire:click="export" wire:loading.attr="disabled" wire:target="export">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"/>
                        </svg>
                        <span>تصدير إكسل</span>
                    </button>
                    <button class="ct-refresh" wire:click="pushToSheet" wire:loading.attr="disabled" wire:target="pushToSheet">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"
                             wire:loading.class="ct-spin" wire:target="pushToSheet">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6"/>
                        </svg>
                        <span wire:loading.remove wire:target="pushToSheet">تحديث Google Sheet</span>
                        <span wire:loading wire:target="pushToSheet">جارٍ الكتابة…</span>
                    </button>
                </div>
            </div>
            <div class="ct-stats">
                <div class="ct-stat"><b>{{ $sum['total'] }}</b><span>حاوية متتبَّعة</span></div>
                <div class="ct-stat {{ $sum['overdue'] ? 'warn' : '' }}"><b>{{ $sum['overdue'] }}</b><span>متأخرة</span></div>
                <div class="ct-stat"><b>{{ $sum['arriving'] }}</b><span>تصل قريباً</span></div>
                <div class="ct-stat"><b>{{ $sum['nearest'] }}</b><span>أقرب وصول</span></div>
            </div>
        </div>

        {{-- ====== attention strip ====== --}}
        @if ($attn->isNotEmpty())
            <div class="ct-attn">
                <h3 class="ct-attn-h"><span class="dot"></span> تحتاج انتباهك — {{ $attn->count() }} حاوية</h3>
                <div class="ct-attn-scroll">
                    @foreach ($attn as $s)
                        @include('filament.pages.partials.container-card', ['s' => $s, 'palette' => $palette, 'variant' => 'attn'])
                    @endforeach
                </div>
            </div>
        @elseif ($counts['all'] > 0)
            <div class="ct-allgood">✅ كل الشحنات على المسار — لا متأخرات ولا وصول وشيك.</div>
        @endif

        {{-- ====== badges ====== --}}
        <div class="ct-badges">
            @foreach ($filters as $key => [$label, $color])
                @php $accent = $palette[$color][0]; $soft = $palette[$color][1]; @endphp
                <div class="ct-badge {{ $this->filter === $key ? 'active' : '' }}"
                     wire:click="$set('filter', '{{ $key }}')"
                     style="{{ $this->filter === $key ? "background:$accent;border-color:$accent;" : "border-color:$soft;" }}">
                    <span class="n" style="{{ $this->filter === $key ? '' : "color:$accent" }}">{{ $counts[$key] ?? 0 }}</span>
                    <span class="l">{{ $label }}</span>
                </div>
            @endforeach
        </div>

        {{-- ====== tools: search · sort · group ====== --}}
        <div class="ct-tools">
            <div class="ct-search">
                <span class="ic">🔎</span>
                <input type="text" wire:model.live.debounce.300ms="search" placeholder="ابحث برقم الحاوية أو الناقل أو الوجهة…">
            </div>
            <div class="ct-tools-end">
                <div class="ct-seg">
                    @foreach ($sorts as $k => $label)
                        <button class="{{ $this->sort === $k ? 'on' : '' }}" wire:click="$set('sort', '{{ $k }}')">{{ $label }}</button>
                    @endforeach
                </div>
                <label class="ct-toggle">
                    <input type="checkbox" wire:model.live="groupByShipment">
                    <span>تجميع حسب الشحنة</span>
                </label>
            </div>
        </div>

        {{-- ====== list ====== --}}
        @if ($ships->isEmpty())
            <div class="ct-empty">لا توجد شحنات مطابقة.</div>

        @elseif ($this->groupByShipment)
            {{-- grouped: one bordered block per shipment; body is a compact table --}}
            <div class="ct-groups">
                @foreach ($this->shipmentGroups() as $gkey => $group)
                    @php
                        $head  = $group->first();
                        $gv    = optional($head->currentVessel())['vessel'] ?? null;
                        $gcp   = $palette[$head->stateColor()];
                        $count = $group->count();
                    @endphp
                    <div class="ct-gblock" style="--accent:{{ $gcp[0] }};" wire:key="gb-{{ md5($gkey) }}">
                        <div class="ct-gblock-head">
                            <span class="ttl">🚢 {{ $gv ?: ($head->sealine_name ?: 'شحنة') }}</span>
                            <span class="meta">{{ $head->destinationFlag() }} {{ $head->destinationShort() }} · {{ $head->sealine_name }} · شحن {{ $head->shipDate() ? $head->shipDate()->translatedFormat('d M Y') : '—' }} · وصول {{ $head->eta ? $head->eta->translatedFormat('d M Y') : 'قيد التحديد' }}</span>
                            <span class="cnt">{{ $count > 1 ? $count . ' حاويات' : 'حاوية واحدة' }}</span>
                        </div>
                        <div class="ct-gtbl-wrap">
                            <table class="ct-table ct-gtbl">
                                <thead>
                                    <tr><th>الحالة</th><th>المنشأ</th><th>رقم الحاوية</th><th>المتبقّي</th><th>التقدّم</th></tr>
                                </thead>
                                <tbody>
                                    @foreach ($group as $s)
                                        @php $cp = $palette[$s->stateColor()]; $accent = $cp[0]; $soft = $cp[1]; $ink = $cp[2]; @endphp
                                        <tr wire:click="$set('selected', '{{ $s->name }}')" wire:key="gr-{{ $s->name }}">
                                            <td class="ct-td-state" style="border-inline-start-color:{{ $accent }};">
                                                <span class="ct-chip" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->stateLabel() }}</span>
                                            </td>
                                            <td class="ct-tlane">{{ $s->originFlag() }} {{ $s->originShort() }}</td>
                                            <td class="ct-tref">{{ $s->reference_number }}<br><span style="opacity:.7">{{ $s->name }}</span></td>
                                            <td>
                                                @if ($s->remaining_days !== null && !$s->isPending() && !$s->isDelivered())
                                                    <span class="ct-days" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->remainingLabel() }}</span>
                                                @else
                                                    <span style="color:#cbd5e1;">—</span>
                                                @endif
                                            </td>
                                            <td><span class="ct-tbar"><i style="width:{{ $s->progressPercent() }}%;background:{{ $accent }};"></i></span></td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    </div>
                @endforeach
            </div>

        @else
            {{-- flat: dense table on desktop, cards on mobile --}}
            <div class="ct-desktop">
                <div class="ct-table-wrap">
                    <table class="ct-table">
                        <thead>
                            <tr>
                                <th>الحالة</th><th>خط السير</th><th>الناقل</th>
                                <th>رقم الحاوية</th><th>الشحن / الوصول</th><th>المتبقّي</th><th>التقدّم</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($ships as $s)
                                @include('filament.pages.partials.container-row', ['s' => $s, 'palette' => $palette, 'indent' => false])
                            @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="ct-mobile">
                <div class="ct-mlist">
                    @foreach ($ships as $s)
                        @include('filament.pages.partials.container-card', ['s' => $s, 'palette' => $palette, 'variant' => 'list'])
                    @endforeach
                </div>
            </div>
        @endif
    </div>

    {{-- ====== detail drawer ====== --}}
    @if ($sel)
        @php
            [$accent, $soft, $ink] = $palette[$sel->stateColor()];
            $vessel = $sel->currentVessel();
            $events = collect($sel->events())->sortByDesc('timestamp')->values();
            $siblings = $this->siblingsOf($sel);
            $etaChanges = $sel->etaChangeCount();

            $segments = [];
            foreach ($sel->routeSegments() as $seg) {
                $path = $seg['path'] ?? [];
                if (count($path) >= 2) {
                    $segments[] = ['path' => $path, 'type' => $seg['type'] ?? 'sea'];
                }
            }
            $endpoints = [];
            if (!empty($segments)) {
                $first = $segments[0]['path'][0] ?? null;
                $lastSeg = end($segments)['path'];
                $last = $lastSeg[count($lastSeg) - 1] ?? null;
                if ($first) $endpoints['origin'] = [(float) $first[0], (float) $first[1]];
                if ($last)  $endpoints['dest']   = [(float) $last[0], (float) $last[1]];
            }
            $geo = [
                'segments' => $segments,
                'current'  => ($sel->latitude && $sel->longitude) ? [(float) $sel->latitude, (float) $sel->longitude] : null,
                'endpoints'=> $endpoints,
                'accent'   => $accent,
            ];
        @endphp

        <div class="ct-overlay" wire:click.self="$set('selected', null)">
            <div class="ct-panel">
                <div class="ct-phead" style="background:linear-gradient(135deg,{{ $accent }},{{ $ink }});">
                    <div>
                        <h2 dir="ltr" style="text-align:start;">{{ $sel->originFlag() }} {{ $sel->originShort() }} → {{ $sel->destinationFlag() }} {{ $sel->destinationShort() }}</h2>
                        <div class="sub">{{ $sel->sealine_name }} · {{ $sel->reference_number }} · {{ $sel->stateLabel() }} · {{ $sel->remainingLabel() }}</div>
                    </div>
                    <button class="ct-x" wire:click="$set('selected', null)">✕</button>
                </div>

                @if (!empty($segments) || $geo['current'])
                    <div class="ct-map" wire:ignore wire:key="map-{{ $sel->name }}" x-data="ctMap(@js($geo))" x-init="draw()"></div>
                @endif

                <div class="ct-pbody">
                    <div>
                        @if ($etaChanges > 0)
                            <div class="ct-etawarn">⚠ تغيّر موعد الوصول {{ $etaChanges }} مرة منذ بدء التتبّع</div>
                        @endif
                        <p class="ct-sec-title">سجلّ الأحداث</p>
                        @if ($events->isEmpty())
                            <p style="color:#94a3b8;font-size:.85rem;">لا توجد أحداث بعد — الشحنة قيد التهيئة لدى الناقل.</p>
                        @else
                            <div class="ct-tl">
                                @foreach ($events as $i => $ev)
                                    <div class="ct-ev {{ $i === 0 ? 'first' : '' }}">
                                        <div class="d">{{ $transportIcon($ev['transport_type'] ?? null) }} {{ $ev['description'] ?? ($ev['status_description'] ?? 'حدث') }}</div>
                                        <div class="m">
                                            {{ trim(($ev['location'] ?? '') . ($ev['country'] ? '، ' . $ev['country'] : ''), '، ') ?: '—' }}
                                            @if (!empty($ev['timestamp']))
                                                · {{ \Illuminate\Support\Carbon::parse($ev['timestamp'])->translatedFormat('d M Y — H:i') }}
                                            @endif
                                        </div>
                                    </div>
                                @endforeach
                            </div>
                        @endif
                    </div>

                    <div>
                        <p class="ct-sec-title">تفاصيل الشحنة</p>
                        <div class="ct-kv">
                            @if ($vessel)
                                <div class="item">
                                    <div class="k">الباخرة الحالية</div>
                                    <div class="v">🚢 {{ $vessel['vessel'] ?? '—' }}</div>
                                    <div class="k" style="margin-top:.4rem;">IMO {{ $vessel['imo'] ?? '—' }} · MMSI {{ $vessel['mmsi'] ?? '—' }}</div>
                                </div>
                            @endif
                            <div class="item">
                                <div class="k">تاريخ الشحن</div>
                                <div class="v">{{ $sel->shipDate() ? $sel->shipDate()->translatedFormat('d M Y') : '—' }}</div>
                            </div>
                            <div class="item">
                                <div class="k">الوصول المتوقّع</div>
                                <div class="v">{{ $sel->eta ? $sel->eta->translatedFormat('d M Y') : '—' }}</div>
                            </div>
                            <div class="item">
                                <div class="k">المدة الكلية / المتبقّي</div>
                                <div class="v">{{ $sel->total_days ?? '—' }} يوم · {{ $sel->remaining_days !== null ? $sel->remaining_days . ' متبقٍّ' : '—' }}</div>
                            </div>
                            @if ($siblings->isNotEmpty())
                                <div class="item">
                                    <div class="k">حاويات في نفس الشحنة</div>
                                    <div class="ct-sib">
                                        @foreach ($siblings as $sib)
                                            <a wire:click.stop="$set('selected', '{{ $sib->name }}')">{{ $sib->reference_number }}</a>
                                        @endforeach
                                    </div>
                                </div>
                            @endif
                            @if ($sel->shipment_public_url)
                                <a class="ct-share" href="{{ $sel->shipment_public_url }}" target="_blank" rel="noopener">🔗 صفحة التتبّع العامة</a>
                            @endif
                        </div>
                    </div>
                </div>
            </div>
        </div>
    @endif

    <script>
        function ctMap(geo) {
            return {
                draw() {
                    if (typeof L === 'undefined') { setTimeout(() => this.draw(), 150); return; }
                    const map = L.map(this.$el, { zoomControl: true, attributionControl: false });
                    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', { maxZoom: 18 }).addTo(map);

                    const pts = [];
                    (geo.segments || []).forEach(seg => {
                        const latlngs = (seg.path || []).map(p => [p[0], p[1]]);
                        latlngs.forEach(ll => pts.push(ll));
                        const isLand = (seg.type || 'sea').toLowerCase() === 'land';
                        L.polyline(latlngs, {
                            color: isLand ? '#94a3b8' : geo.accent,
                            weight: isLand ? 2.5 : 3.5,
                            dashArray: isLand ? '6,6' : null,
                            opacity: .9,
                        }).addTo(map);
                    });

                    const pin = (ll, label, color) => {
                        if (!ll) return;
                        pts.push(ll);
                        L.marker(ll, { icon: L.divIcon({ className: '', html:
                            `<div style="background:${color};color:#fff;font:700 10px Cairo,sans-serif;white-space:nowrap;padding:2px 6px;border-radius:6px;box-shadow:0 2px 6px rgba(0,0,0,.3);transform:translate(-50%,-120%)">${label}</div>` }) }).addTo(map);
                    };
                    pin(geo.endpoints && geo.endpoints.origin, 'المنشأ', '#475569');
                    pin(geo.endpoints && geo.endpoints.dest, 'الوجهة', '#0e7490');

                    if (geo.current) {
                        pts.push(geo.current);
                        L.circleMarker(geo.current, { radius: 7, color: '#fff', weight: 3, fillColor: geo.accent, fillOpacity: 1 })
                            .addTo(map).bindTooltip('الموقع الحالي', { direction: 'top' });
                    }

                    if (pts.length) { map.fitBounds(L.latLngBounds(pts).pad(0.25)); }
                    else { map.setView([21.5, 39.2], 3); }
                    setTimeout(() => map.invalidateSize(), 200);
                },
            };
        }
    </script>
</x-filament-panels::page>
