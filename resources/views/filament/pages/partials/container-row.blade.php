@php
    $cp = $palette[$s->stateColor()];
    $accent = $cp[0]; $soft = $cp[1]; $ink = $cp[2];
@endphp
<tr class="{{ ($indent ?? false) ? 'ct-sub' : '' }}" wire:click="$set('selected', '{{ $s->name }}')" wire:key="row-{{ $s->name }}">
    <td class="ct-td-state" style="border-inline-start-color:{{ $accent }};">
        <span class="ct-chip" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->stateLabel() }}</span>
    </td>
    <td class="ct-tlane">
        <span class="ct-lane-ltr" dir="ltr">
            <span class="ct-flagcity">{{ $s->originFlag() }} {{ $s->originShort() }}</span>
            <span class="ct-arr">→</span>
            <span class="ct-flagcity">{{ $s->destinationFlag() }} {{ $s->destinationShort() }}</span>
        </span>
    </td>
    <td class="ct-tcarrier">{{ $s->sealine_name ?: $s->sealine ?: '—' }}</td>
    <td class="ct-tref">{{ $s->reference_number }}<br><span style="opacity:.7">{{ $s->name }}</span></td>
    <td>
        <div class="ct-dates">
            <span class="ship">🚢 شُحنت: {{ $s->shipDate() ? $s->shipDate()->translatedFormat('d M Y') : '—' }}</span>
            <span class="eta">🏁 الوصول: {{ $s->eta ? $s->eta->translatedFormat('d M Y') : 'قيد التحديد' }}</span>
        </div>
    </td>
    <td>
        @if ($s->remaining_days !== null && !$s->isPending() && !$s->isDelivered())
            <span class="ct-days" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->remainingLabel() }}</span>
        @else
            <span style="color:#cbd5e1;">—</span>
        @endif
    </td>
    <td>
        <span class="ct-tbar"><i style="width:{{ $s->progressPercent() }}%;background:{{ $accent }};"></i></span>
    </td>
</tr>
