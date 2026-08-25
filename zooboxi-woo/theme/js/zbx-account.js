/**
 * Zooboxi Account — the interactive layer of the customer profile.
 *
 * Counters animate once on reveal, reorder posts to the cart without a page
 * change, and the phone-login button only appears if the OTP modal is present.
 * Everything degrades to plain HTML if JS fails.
 */
(function () {
    'use strict';
    if (typeof jQuery === 'undefined') return;
    var $ = jQuery;
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    /* ── 1. KPI counters count up the first time they scroll into view ── */
    function countUp(el) {
        var target = parseInt(el.getAttribute('data-count'), 10);
        if (!target || target > 100000 || reduced) return;
        var dur = 900, t0 = null;
        function tick(ts) {
            if (t0 === null) t0 = ts;
            var p = Math.min(1, (ts - t0) / dur);
            // easeOutCubic — fast start, gentle landing
            var eased = 1 - Math.pow(1 - p, 3);
            el.textContent = Math.round(target * eased).toLocaleString('en-US');
            if (p < 1) requestAnimationFrame(tick);
        }
        el.textContent = '0';
        requestAnimationFrame(tick);
    }

    function initCounters() {
        var nums = document.querySelectorAll('.zbx-kpi__n[data-count]');
        if (!nums.length) return;
        if (!('IntersectionObserver' in window)) {
            nums.forEach(countUp);
            return;
        }
        var io = new IntersectionObserver(function (entries) {
            entries.forEach(function (en) {
                if (!en.isIntersecting) return;
                io.unobserve(en.target);
                countUp(en.target);
            });
        }, { threshold: 0.4 });
        nums.forEach(function (n) { io.observe(n); });
    }

    /* ── 2. Cards rise in as you scroll ── */
    function initReveal() {
        if (reduced || !('IntersectionObserver' in window)) return;
        var els = document.querySelectorAll('.zbx-dash > section, .zbx-dash > nav, .zbx-order, .zbx-mine__item, .zbx-addr__card');
        if (!els.length) return;
        var io = new IntersectionObserver(function (entries) {
            entries.forEach(function (en) {
                if (!en.isIntersecting) return;
                io.unobserve(en.target);
                en.target.classList.add('zbx-up-in');
                setTimeout(function () {
                    en.target.classList.remove('zbx-up', 'zbx-up-in');
                }, 800);
            });
        }, { rootMargin: '0px 0px -6% 0px', threshold: 0.04 });
        els.forEach(function (el, i) {
            el.classList.add('zbx-up');
            el.style.transitionDelay = Math.min(i * 45, 260) + 'ms';
            io.observe(el);
        });
    }

    /* ── 3. Re-order a whole past order ── */
    $(document).on('click', '.zbx-obtn--reorder', function () {
        var $btn = $(this);
        if ($btn.hasClass('is-busy') || typeof zbxAccount === 'undefined') return;

        var original = $btn.html();
        $btn.addClass('is-busy').prop('disabled', true).html('<span class="zbx-spin" aria-hidden="true"></span> جاري الإضافة…');

        $.post(zbxAccount.ajax, {
            action: 'zbx_reorder',
            nonce: zbxAccount.nonce,
            order_id: $btn.data('order')
        }).done(function (res) {
            if (!res || !res.success) {
                fail(res && res.data ? res.data.message : 'تعذّرت الإضافة');
                return;
            }
            $btn.removeClass('is-busy').addClass('is-done').html('<span aria-hidden="true">✓</span> أُضيفت للسلة');
            $(document.body).trigger('wc_fragment_refresh');
            toast(res.data.message, res.data.missing);
            setTimeout(function () {
                window.location.href = zbxAccount.cart;
            }, 1100);
        }).fail(function (xhr) {
            var msg = (xhr.responseJSON && xhr.responseJSON.data && xhr.responseJSON.data.message) || 'تعذّرت الإضافة، حاول مرة أخرى';
            fail(msg);
        });

        function fail(msg) {
            $btn.removeClass('is-busy').prop('disabled', false).html(original);
            toast(msg, null, true);
        }
    });

    function toast(message, missing, isError) {
        $('.zbx-acct-toast').remove();
        var extra = (missing && missing.length)
            ? '<em>' + missing.length + ' صنف غير متوفر حالياً</em>'
            : '';
        var $t = $(
            '<div class="zbx-acct-toast' + (isError ? ' is-error' : '') + '" role="status">' +
            '<span class="zbx-acct-toast__ic" aria-hidden="true">' + (isError ? '⚠️' : '🛒') + '</span>' +
            '<span class="zbx-acct-toast__tx"><strong></strong>' + extra + '</span>' +
            '</div>'
        );
        $t.find('strong').text(message || '');
        $('body').append($t);
        setTimeout(function () { $t.addClass('is-in'); }, 20);
        setTimeout(function () {
            $t.removeClass('is-in');
            setTimeout(function () { $t.remove(); }, 400);
        }, isError ? 4200 : 2600);
    }

    /* ── 4. Password reveal ── */
    $(document).on('click', '.zbx-pw__eye', function () {
        var $i = $(this).siblings('input');
        var show = $i.attr('type') === 'password';
        $i.attr('type', show ? 'text' : 'password');
        $(this).text(show ? '🙈' : '👁️').attr('aria-label', show ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور');
    });

    /* ── 5. Phone login — only offered when the OTP modal actually exists ── */
    function initOtp() {
        var $btn = $('#zbx-auth-otp');
        if (!$btn.length || !$('#zbx-otp-modal').length) return;
        $btn.prop('hidden', false);
        $('#zbx-auth-or').prop('hidden', false);
        $btn.on('click', function () {
            // mirrors the plugin's own showModal(); its function is not exported
            $('#zbx-otp-modal').fadeIn(200);
            $('.zbx-otp-step').hide();
            $('#zbx-otp-step1').show();
            $('.zbx-otp-error').hide();
            $('#zbx-otp-phone').val('').trigger('focus');
        });
    }

    /* ── 6. Keep the active tab visible in the mobile nav strip ── */
    function centreActiveTab() {
        var nav = document.querySelector('.zbx-acct-nav ul');
        if (!nav || nav.scrollWidth <= nav.clientWidth) return;
        var active = nav.querySelector('.is-active a') || nav.querySelector('[aria-current="page"]');
        if (!active) return;
        var target = active.offsetLeft - (nav.clientWidth - active.offsetWidth) / 2;
        nav.scrollTo({ left: Math.max(0, target), behavior: reduced ? 'auto' : 'smooth' });
    }

    $(function () {
        initCounters();
        initReveal();
        initOtp();
        centreActiveTab();
    });
})();
