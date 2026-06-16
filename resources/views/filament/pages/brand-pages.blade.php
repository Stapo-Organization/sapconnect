<x-filament-panels::page>
    <style>
        .zb-bp{max-width:1120px;direction:rtl}
        .zb-bp__hint{color:#6b7280;font-size:.9rem;margin-bottom:1rem;line-height:1.7}
        .zb-bp__select{width:100%;max-width:480px;padding:.6rem .8rem;border:1px solid #d1d5db;border-radius:.6rem;background:#fff;font-size:1rem}
        .dark .zb-bp__select{background:#1f2937;border-color:#374151;color:#e5e7eb}
        .zb-bp__id{display:flex;gap:1rem;align-items:center;flex-wrap:wrap;margin:1.2rem 0;padding:1rem 1.2rem;border-radius:1rem;border:1px solid #e5e7eb;background:#fff}
        .dark .zb-bp__id{background:#1f2937;border-color:#374151}
        .zb-bp__logo{width:64px;height:64px;border-radius:.8rem;object-fit:contain;background:#f3f4f6;padding:6px;flex-shrink:0}
        .zb-bp__swatches{display:flex;gap:.4rem}
        .zb-bp__sw{width:34px;height:34px;border-radius:.5rem;border:1px solid rgba(0,0,0,.08)}
        .zb-bp__meta{display:flex;flex-direction:column;gap:.15rem}
        .zb-bp__name{font-size:1.15rem;font-weight:700}
        .zb-bp__tag{color:#6b7280;font-size:.9rem}
        .zb-bp__chips{display:flex;gap:.4rem;flex-wrap:wrap;margin-top:.2rem}
        .zb-bp__chip{font-size:.72rem;background:#f3f4f6;color:#374151;padding:.15rem .5rem;border-radius:.5rem}
        .dark .zb-bp__chip{background:#374151;color:#e5e7eb}
        .zb-bp__link{margin-inline-start:auto;font-size:.85rem;font-weight:600}
        .zb-bp__slots{display:grid;grid-template-columns:1fr;gap:1rem;margin-top:1rem}
        @media(min-width:780px){.zb-bp__slots{grid-template-columns:1fr 1fr}}
        .zb-bp__slot{border:1px solid #e5e7eb;border-radius:1rem;background:#fff;overflow:hidden}
        .dark .zb-bp__slot{background:#1f2937;border-color:#374151}
        .zb-bp__slot-head{display:flex;align-items:center;gap:.5rem;padding:.7rem 1rem;border-bottom:1px solid #f0f0f0}
        .dark .zb-bp__slot-head{border-color:#374151}
        .zb-bp__slot-title{font-weight:700}
        .zb-bp__badge{font-size:.7rem;font-weight:700;padding:.15rem .5rem;border-radius:.5rem;margin-inline-start:auto}
        .zb-bp__badge--live{background:#dcfce7;color:#166534}
        .zb-bp__badge--preview{background:#fef9c3;color:#854d0e}
        .zb-bp__badge--none{background:#f3f4f6;color:#6b7280}
        .zb-bp__badge--busy{background:#dbeafe;color:#1e40af}
        .zb-bp__badge--failed{background:#fee2e2;color:#991b1b}
        .zb-bp__preview{position:relative;background:#f8fafc;display:flex;align-items:center;justify-content:center;min-height:150px}
        .dark .zb-bp__preview{background:#111827}
        .zb-bp__preview img{width:100%;height:auto;display:block}
        .zb-bp__ph{color:#9ca3af;font-size:.85rem;text-align:center;padding:2rem 1rem}
        .zb-bp__busy{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;background:rgba(255,255,255,.7);font-weight:600;color:#1e40af}
        .dark .zb-bp__busy{background:rgba(17,24,39,.7);color:#93c5fd}
        .zb-bp__body{padding:.8rem 1rem;display:flex;flex-direction:column;gap:.5rem}
        .zb-bp__field label{font-size:.75rem;color:#6b7280;display:block;margin-bottom:.2rem}
        .zb-bp__field input,.zb-bp__field textarea{width:100%;padding:.45rem .6rem;border:1px solid #d1d5db;border-radius:.5rem;font-size:.9rem;background:#fff}
        .dark .zb-bp__field input,.dark .zb-bp__field textarea{background:#111827;border-color:#374151;color:#e5e7eb}
        .zb-bp__actions{display:flex;gap:.5rem;flex-wrap:wrap;margin-top:.3rem}
        .zb-bp__btn{font-size:.85rem;font-weight:600;padding:.45rem .9rem;border-radius:.6rem;border:0;cursor:pointer}
        .zb-bp__btn--gen{background:#0d9488;color:#fff}
        .zb-bp__btn--pub{background:#16a34a;color:#fff}
        .zb-bp__btn--stop{background:#f3f4f6;color:#374151}
        .dark .zb-bp__btn--stop{background:#374151;color:#e5e7eb}
        .zb-bp__btn:disabled{opacity:.5;cursor:not-allowed}
    </style>

    <div class="zb-bp">
        <p class="zb-bp__hint">
            اختر علامة تجارية، ثم ولّد بانر الهيرو والتايلات بهوية العلامة عبر الذكاء الاصطناعي، عاين وعدّل النص العربي،
            ثم اعتمد وانشر. لا يظهر أي تصميم للعملاء قبل النشر. صفحات العلامات للعرض فقط (بدون أسعار/خصومات).
        </p>

        <div class="zb-bp__field" style="margin-bottom:.6rem">
            <label for="zb-bp-brand">اختر العلامة التجارية</label>
            <select id="zb-bp-brand" class="zb-bp__select" wire:model.live="brandCode">
                <option value="">— اختر علامة —</option>
                @foreach ($this->brands as $code => $name)
                    <option value="{{ $code }}">{{ $name }} ({{ $code }})</option>
                @endforeach
            </select>
        </div>

        @if ($this->selectedBrand)
            @php $kit = $this->kit; @endphp

            <div class="zb-bp__id" style="border-inline-start:5px solid {{ $kit['accent'] ?? '#0d9488' }}">
                @if (!empty($kit['logo_image']))
                    <img class="zb-bp__logo" src="{{ $kit['logo_image'] }}" alt="{{ $this->selectedBrand->name }}"
                         onerror="this.style.display='none'">
                @endif
                <div class="zb-bp__swatches" title="ألوان الهوية">
                    <span class="zb-bp__sw" style="background:{{ $kit['accent'] ?? '#0d9488' }}"></span>
                    <span class="zb-bp__sw" style="background:{{ $kit['accent_dark'] ?? '#0a5560' }}"></span>
                    <span class="zb-bp__sw" style="background:{{ $kit['gold'] ?? '#F4BE2C' }}"></span>
                </div>
                <div class="zb-bp__meta">
                    <span class="zb-bp__name">{{ $this->selectedBrand->name }}</span>
                    @if (!empty($kit['tagline_ar']))
                        <span class="zb-bp__tag">{{ $kit['tagline_ar'] }}</span>
                    @endif
                    <div class="zb-bp__chips">
                        @if (!empty($kit['country']))<span class="zb-bp__chip">📍 {{ $kit['country'] }}</span>@endif
                        @if (!empty($kit['founded']))<span class="zb-bp__chip">🗓 {{ $kit['founded'] }}</span>@endif
                        @if (!empty($kit['headline_font']))<span class="zb-bp__chip">🅰 {{ $kit['headline_font'] }}</span>@endif
                        @if (!empty($kit['mood_ar']))<span class="zb-bp__chip">{{ $kit['mood_ar'] }}</span>@endif
                    </div>
                </div>
                <a class="zb-bp__link" href="{{ $this->brandUrl }}" target="_blank" rel="noopener">
                    فتح صفحة العلامة ↗
                </a>
            </div>

            <div class="zb-bp__slots" @if ($this->busy) wire:poll.6s @endif>
                @foreach ($this->slots as $p => $slot)
                    <div class="zb-bp__slot">
                        <div class="zb-bp__slot-head">
                            <span class="zb-bp__slot-title">{{ $slot['label'] }}</span>
                            <span class="zb-bp__chip">{{ $slot['format'] === 'hero' ? '3:2' : '1:1' }}</span>
                            @if ($slot['busy'])
                                <span class="zb-bp__badge zb-bp__badge--busy">جارٍ التوليد…</span>
                            @elseif ($slot['live'])
                                <span class="zb-bp__badge zb-bp__badge--live">منشور</span>
                            @elseif ($slot['creative_status'] === 'failed')
                                <span class="zb-bp__badge zb-bp__badge--failed">فشل التوليد</span>
                            @elseif ($slot['preview'])
                                <span class="zb-bp__badge zb-bp__badge--preview">معاينة</span>
                            @else
                                <span class="zb-bp__badge zb-bp__badge--none">لا يوجد</span>
                            @endif
                        </div>

                        <div class="zb-bp__preview">
                            @if ($slot['preview'])
                                <img src="{{ $slot['preview'] }}" alt="{{ $slot['label'] }}">
                            @else
                                <div class="zb-bp__ph">لا يوجد تصميم بعد — اكتب النص ثم اضغط «توليد».</div>
                            @endif
                            @if ($slot['busy'])
                                <div class="zb-bp__busy">جارٍ التوليد بالذكاء الاصطناعي…</div>
                            @endif
                        </div>

                        <div class="zb-bp__body">
                            <div class="zb-bp__field">
                                <label>العنوان</label>
                                <input type="text" wire:model="copy.{{ $p }}.headline_ar" placeholder="عنوان قصير بهوية العلامة">
                            </div>
                            @if ($slot['format'] === 'hero')
                                <div class="zb-bp__field">
                                    <label>العنوان الفرعي</label>
                                    <input type="text" wire:model="copy.{{ $p }}.subheadline_ar" placeholder="سطر داعم اختياري">
                                </div>
                            @endif
                            <div class="zb-bp__field">
                                <label>زر الإجراء (CTA)</label>
                                <input type="text" wire:model="copy.{{ $p }}.cta_ar" placeholder="تسوّق المجموعة">
                            </div>
                            <div class="zb-bp__field">
                                <label>ملاحظة تحسين للتصميم (اختياري)</label>
                                <input type="text" wire:model="copy.{{ $p }}.refinement_note" placeholder="مثال: اجعل الخلفية أفتح وأبرز الشعار">
                            </div>

                            <div class="zb-bp__actions">
                                <button type="button" class="zb-bp__btn zb-bp__btn--gen"
                                        wire:click="generate('{{ $p }}')"
                                        wire:loading.attr="disabled" wire:target="generate('{{ $p }}')">
                                    {{ $slot['preview'] ? 'إعادة التوليد' : 'توليد' }}
                                </button>

                                @if ($slot['preview'] && !$slot['live'])
                                    <button type="button" class="zb-bp__btn zb-bp__btn--pub"
                                            wire:click="publish('{{ $p }}')"
                                            @if ($slot['busy']) disabled @endif>
                                        اعتماد ونشر
                                    </button>
                                @endif

                                @if ($slot['live'])
                                    <button type="button" class="zb-bp__btn zb-bp__btn--stop"
                                            wire:click="unpublish('{{ $p }}')">
                                        إيقاف
                                    </button>
                                @endif
                            </div>
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </div>
</x-filament-panels::page>
