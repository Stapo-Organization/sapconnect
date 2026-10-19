/**
 * Zooboxi Checkout Experience
 * A guided, reassuring checkout: progress stepper, numbered sections,
 * live field validation, a sticky total bar, and trust cues.
 * Purely additive — no WooCommerce field is moved or renamed.
 */
(function () {
    'use strict';
    if (typeof jQuery === 'undefined') return;
    var $ = jQuery;

    var STEPS = [
        { key: 'location', icon: '📍', label: 'موقع التوصيل' },
        { key: 'details',  icon: '🧾', label: 'بياناتك' },
        { key: 'payment',  icon: '💳', label: 'الدفع' }
    ];

    /* ── progress stepper ───────────────────────────────── */
    function buildStepper() {
        var $form = $('form.checkout');
        if (!$form.length || $('.zbx-steps').length) return;

        var html = '<div class="zbx-steps" role="list">';
        STEPS.forEach(function (s, i) {
            html += '<div class="zbx-step" data-step="' + s.key + '" role="listitem">' +
                '<span class="zbx-step-dot"><span class="zbx-step-ic">' + s.icon + '</span></span>' +
                '<span class="zbx-step-label">' + s.label + '</span>' +
                '</div>';
            if (i < STEPS.length - 1) html += '<span class="zbx-step-line"></span>';
        });
        html += '</div>';
        $form.prepend(html);
    }

    function val(sel) { var e = $(sel); return e.length ? String(e.val() || '').trim() : ''; }

    function phoneOk(v) {
        var d = (v || '').replace(/[^\d]/g, '');
        return /^05\d{8}$/.test(d) || /^9665\d{8}$/.test(d) || /^5\d{8}$/.test(d);
    }

    function stepState() {
        var located = !!(val('[name="billing_zooboxi_lat"]') || val('#billing_city'));
        var details = !!val('#billing_first_name') && phoneOk(val('#billing_phone'));
        return { location: located, details: details, payment: located && details };
    }

    function paintSteps() {
        var st = stepState();
        var current = !st.location ? 'location' : (!st.details ? 'details' : 'payment');
        $('.zbx-step').each(function () {
            var k = $(this).data('step');
            $(this).toggleClass('is-done', !!st[k] && k !== current)
                   .toggleClass('is-current', k === current);
        });
    }

    /* ── numbered section headings ──────────────────────── */
    function sectionHead(n, icon, title, sub) {
        return $('<div class="zbx-sec-head"><span class="zbx-sec-num">' + n + '</span>' +
            '<span class="zbx-sec-txt"><span class="zbx-sec-title">' + icon + ' ' + title + '</span>' +
            (sub ? '<span class="zbx-sec-sub">' + sub + '</span>' : '') + '</span></div>');
    }

    function buildSections() {
        if (!$('.zbx-sec-head').length) {
            var $map = $('#zbx-checkout-map-section');
            if ($map.length) $map.before(sectionHead(1, '📍', 'أين نوصّل طلبك؟', 'حرّك الدبوس على موقعك بدقة'));

            var $fields = $('.woocommerce-billing-fields__field-wrapper');
            if ($fields.length) $fields.before(sectionHead(2, '🧾', 'بياناتك', 'نحتاجها للتواصل معك وقت التسليم'));
        }
        if (!$('#payment .zbx-sec-head').length) {
            $('#payment').prepend(sectionHead(3, '💳', 'طريقة الدفع', 'كل الوسائل آمنة ومشفّرة'));
        }
    }

    /* ── live validation ticks ──────────────────────────── */
    function markField($f, ok, msg) {
        var $row = $f.closest('.form-row');
        $row.toggleClass('zbx-valid', !!ok).toggleClass('zbx-invalid', ok === false);
        var $msg = $row.find('.zbx-field-msg');
        if (msg) {
            if (!$msg.length) { $msg = $('<span class="zbx-field-msg"></span>').appendTo($row); }
            $msg.text(msg);
        } else if ($msg.length) { $msg.remove(); }
    }

    function validate() {
        var $name = $('#billing_first_name');
        if ($name.length) markField($name, val('#billing_first_name').length >= 2 ? true : null);

        var $phone = $('#billing_phone');
        if ($phone.length) {
            var v = val('#billing_phone');
            if (!v) markField($phone, null);
            else markField($phone, phoneOk(v), phoneOk(v) ? '' : 'أدخل رقم جوال سعودي مثل 05XXXXXXXX');
        }

        var $city = $('#billing_city');
        if ($city.length) markField($city, val('#billing_city') ? true : null);

        var $mail = $('#billing_email');
        if ($mail.length) {
            var m = val('#billing_email');
            if (!m) markField($mail, null);
            else markField($mail, /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(m), /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(m) ? '' : 'تأكد من صيغة البريد');
        }
        paintSteps();
    }

    /* ── sticky total bar (mobile) ──────────────────────── */
    function buildStickyBar() {
        if ($('.zbx-sticky-bar').length) return;
        $('body').append(
            '<div class="zbx-sticky-bar" hidden>' +
            '<div class="zbx-sticky-total"><span class="zbx-sticky-cap">الإجمالي</span>' +
            '<strong class="zbx-sticky-amount"></strong></div>' +
            '<button type="button" class="zbx-sticky-cta">متابعة الدفع</button>' +
            '</div>'
        );
        $('.zbx-sticky-cta').on('click', function () {
            var $target = $('#payment');
            if (!$target.length) return;
            $('html, body').animate({ scrollTop: $target.offset().top - 20 }, 450);
            $target.addClass('zbx-pulse');
            setTimeout(function () { $target.removeClass('zbx-pulse'); }, 1200);
        });
    }

    function syncSticky() {
        var $bar = $('.zbx-sticky-bar');
        if (!$bar.length) return;
        var amount = $('.woocommerce-checkout-review-order-table .order-total td .woocommerce-Price-amount').first().html();
        if (amount) $bar.find('.zbx-sticky-amount').html(amount);
        $bar.prop('hidden', !amount);
    }

    /* ── trust cues under the pay button ────────────────── */
    function buildTrust() {
        if ($('.zbx-trust').length) return;
        var $anchor = $('#payment .place-order');
        if (!$anchor.length) return;
        $anchor.append(
            '<div class="zbx-trust">' +
            '<span>🔒 دفع آمن ومشفّر</span>' +
            '<span>🔄 استبدال وإرجاع سهل</span>' +
            '<span>💬 دعم يرد بسرعة</span>' +
            '</div>'
        );
    }

    function boot() {
        buildStepper();
        buildSections();
        buildStickyBar();
        buildTrust();
        validate();
        syncSticky();
    }

    $(function () {
        if (!$('form.checkout').length) return;
        boot();
        $(document.body).on('input change', 'form.checkout input, form.checkout select', validate);
        $(document.body).on('updated_checkout', function () {
            buildSections();
            buildTrust();
            syncSticky();
            validate();
        });
    });
})();
