@php
    $cp = $palette[$s->stateColor()];
    $accent = $cp[0]; $soft = $cp[1]; $ink = $cp[2];
    $p = $s->progressPercent();
    $variant = $variant ?? 'list';
@endphp
<div class="ct-c {{ $variant === 'attn' ? 'ct-c-attn' : '' }}"
     style="--accent:{{ $accent }};"
     wire:click="$set('selected', '{{ $s->name }}')"
     wire:key="card-{{ $variant }}-{{ $s->name }}">
    <div class="ct-c-top">
        <span class="ct-chip" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->stateLabel() }}</span>
        <span class="ct-c-carrier">{{ $s->sealine_name ?: $s->sealine ?: 'ناقل غير محدد' }}</span>
    </div>

    <div class="ct-c-lane" dir="ltr">
        <span class="ep">{{ $s->originFlag() }} {{ $s->originShort() }}</span>
        <span class="arr">→</span>
        <span class="ep dest">{{ $s->destinationFlag() }} {{ $s->destinationShort() }}</span>
    </div>

    <div class="ct-journey" title="{{ $p }}%">
        <span class="jp">{{ $s->originFlag() }}</span>
        <div class="jtrack">
            <i style="width:{{ $p }}%;background:{{ $accent }};"></i>
            <b class="jship" style="inset-inline-start:calc({{ $p }}% - 8px);">🚢</b>
        </div>
        <span class="jp">{{ $s->destinationFlag() }}</span>
    </div>

    <div class="ct-c-foot">
        <span class="ct-tref">{{ $s->reference_number }}</span>
        @if (!$s->isPending() && !$s->isDelivered() && $s->remaining_days !== null)
            <span class="ct-days" style="background:{{ $soft }};color:{{ $ink }};">{{ $s->remainingLabel() }}</span>
        @elseif ($s->eta)
            <span class="ct-c-eta">🗓️ {{ $s->eta->translatedFormat('d M') }}</span>
        @else
            <span class="ct-c-eta">قيد التهيئة</span>
        @endif
    </div>
</div>
