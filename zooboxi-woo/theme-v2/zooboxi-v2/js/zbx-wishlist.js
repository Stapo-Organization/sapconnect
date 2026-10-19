/**
 * Zooboxi Wishlist — the heart on every product.
 *
 * Server-rendered hearts already carry their state; this script handles the
 * toggle, the header badge, block-based product cards (which no PHP loop hook
 * can reach), and the guest flow: stash the intent, open the store's phone
 * login, then save it automatically once they're back.
 */
(function () {
    'use strict';
    if (typeof jQuery === 'undefined' || typeof zbxFav === 'undefined') return;
    var $ = jQuery;
    var PENDING = 'zbxPendingFav';

    var ICON = '<svg class="zbx-fav__ic" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
        '<path d="M12 20.5s-7.5-4.7-9.4-9A5.1 5.1 0 0 1 12 6.2a5.1 5.1 0 0 1 9.4 5.3c-1.9 4.3-9.4 9-9.4 9Z"' +
        ' fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>';

    /* ── pending intents (guests) ───────────────────────────────── */
    function pending() {
        try { return JSON.parse(localStorage.getItem(PENDING) || '[]'); } catch (e) { return []; }
    }
    function pendingSet(list) {
        try { localStorage.setItem(PENDING, JSON.stringify(list.slice(0, 30))); } catch (e) {}
    }
    function pendingAdd(id) {
        var l = pending();
        if (l.indexOf(id) === -1) l.push(id);
        pendingSet(l);
    }

    /* ── Cards the PHP loop hook can't reach ──────────────────────
       Two kinds: WooCommerce Blocks grids, and the home page's own rails,
       which build their <li> markup directly instead of going through
       wc_get_template_part(). Both carry the product id in a post-<id> class,
       so one injector covers every card in the store. */
    function injectHearts() {
        document.querySelectorAll('li.product, li.wc-block-product').forEach(function (li) {
            if (li.classList.contains('product-category')) return;   // a category tile, not a product

            // a promo badge owns the top corner; CSS drops the heart below it
            if (li.querySelector('.zb-badge-card')) li.classList.add('zbx-has-badge');

            if (li.querySelector('.zbx-fav')) return;                // already server-rendered
            var m = /(?:^|\s)post-(\d+)(?:\s|$)/.exec(li.className);
            if (!m) return;

            var id = parseInt(m[1], 10);
            var on = zbxFav.ids.indexOf(id) !== -1;
            var b = document.createElement('button');
            b.type = 'button';
            b.className = 'zbx-fav zbx-fav--loop' + (on ? ' is-on' : '');
            b.setAttribute('data-product', id);
            b.setAttribute('aria-pressed', on ? 'true' : 'false');
            b.setAttribute('aria-label', on ? 'إزالة من المفضلة' : 'أضف للمفضلة');
            b.innerHTML = ICON;
            li.insertBefore(b, li.firstChild);
        });
    }

    /* Rails and block grids hydrate after load — watch instead of guessing. */
    var sweepTimer = null;
    function scheduleSweep() {
        clearTimeout(sweepTimer);
        sweepTimer = setTimeout(injectHearts, 220);
    }

    /* ── paint every heart for a product id ─────────────────────── */
    function paint(id, on) {
        $('.zbx-fav[data-product="' + id + '"]').each(function () {
            $(this).toggleClass('is-on', on)
                .attr('aria-pressed', on ? 'true' : 'false')
                .attr('aria-label', on ? 'إزالة من المفضلة' : 'أضف للمفضلة')
                .attr('title', on ? 'إزالة من المفضلة' : 'أضف للمفضلة');
            $(this).find('.zbx-fav__tx').text(on ? 'في المفضلة' : 'أضف للمفضلة');
        });
        var i = zbxFav.ids.indexOf(id);
        if (on && i === -1) zbxFav.ids.push(id);
        if (!on && i !== -1) zbxFav.ids.splice(i, 1);
    }

    function badge(count) {
        var $b = $('.zbx-fav-count');
        if (!$b.length) return;
        $b.text(count).toggleClass('is-empty', !count);
        if (count) {
            $b.removeClass('zbx-pop');
            void $b[0].offsetWidth;
            $b.addClass('zbx-pop');
        }
    }

    function toast(msg, isError) {
        $('.zbx-fav-toast').remove();
        var $t = $('<div class="zbx-fav-toast' + (isError ? ' is-error' : '') + '" role="status"></div>').text(msg);
        $('body').append($t);
        setTimeout(function () { $t.addClass('is-in'); }, 20);
        setTimeout(function () {
            $t.removeClass('is-in');
            setTimeout(function () { $t.remove(); }, 350);
        }, 2400);
    }

    /* ── open the store's own phone-login modal ─────────────────── */
    function askLogin() {
        var $m = $('#zbx-otp-modal');
        if (!$m.length) {
            window.location.href = zbxFav.url || '/my-account/';
            return;
        }
        $m.fadeIn(200);
        $('.zbx-otp-step').hide();
        $('#zbx-otp-step1').show();
        $('.zbx-otp-error').hide();
        $('#zbx-otp-phone').val('').trigger('focus');
    }

    /* ── the click ──────────────────────────────────────────────── */
    $(document).on('click', '.zbx-fav', function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $btn = $(this);
        var id = parseInt($btn.data('product'), 10);
        if (!id || $btn.hasClass('is-busy')) return;

        if (!zbxFav.loggedIn) {
            pendingAdd(id);
            paint(id, true);                       // optimistic — it will be saved on login
            toast('سجّل دخولك لحفظ المفضلة');
            askLogin();
            return;
        }

        var next = !$btn.hasClass('is-on');
        paint(id, next);                           // optimistic
        $btn.addClass('is-busy');

        $.post(zbxFav.ajax, {
            action: 'zbx_fav_toggle',
            nonce: zbxFav.nonce,
            product_id: id,
            force: next ? '1' : '0'
        }).done(function (res) {
            if (!res || !res.success) { paint(id, !next); toast('تعذّر الحفظ', true); return; }
            badge(res.data.count);
            toast(res.data.message);
            if (!next) removeCard(id);
        }).fail(function () {
            paint(id, !next);                      // roll back
            toast('تعذّر الحفظ، حاول مرة أخرى', true);
        }).always(function () {
            $btn.removeClass('is-busy');
        });
    });

    /* On the wishlist page, un-hearting removes the card. */
    function removeCard(id) {
        var $card = $('[data-fav-card="' + id + '"]');
        if (!$card.length) return;
        $card.addClass('is-going');
        setTimeout(function () {
            $card.remove();
            if (!$('.zbx-fav-card').length) window.location.reload();
        }, 260);
    }

    /* ── flush anything hearted before logging in ───────────────── */
    function flushPending() {
        var list = pending();
        if (!zbxFav.loggedIn || !list.length) return;
        $.post(zbxFav.ajax, {
            action: 'zbx_fav_sync',
            nonce: zbxFav.nonce,
            ids: JSON.stringify(list)
        }).done(function (res) {
            pendingSet([]);
            if (res && res.success) {
                zbxFav.ids = res.data.ids || [];
                zbxFav.ids.forEach(function (id) { paint(id, true); });
                badge(res.data.count);
                toast('حفظنا مفضلتك 💚');
            }
        });
    }

    $(function () {
        injectHearts();
        flushPending();

        if (window.MutationObserver) {
            new MutationObserver(function (records) {
                for (var i = 0; i < records.length; i++) {
                    if (records[i].addedNodes.length) { scheduleSweep(); return; }
                }
            }).observe(document.body, { childList: true, subtree: true });
        } else {
            setTimeout(injectHearts, 1800);
        }

        $(document.body).on('updated_wc_div wc-blocks_render_blocks_frontend', injectHearts);
    });
})();
