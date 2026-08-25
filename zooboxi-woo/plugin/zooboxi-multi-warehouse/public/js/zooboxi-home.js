/* Zooboxi dynamic homepage — client-side hydration + interactions.
 *
 * The page ships a cacheable shell with empty/skeleton slots. This script reads the
 * visitor's location + recently-viewed cookies and login state, asks the no-store
 * /home-feed endpoint for personalized HTML, and swaps it into the slots. It also
 * wires rail arrows, the gentle phone-login invite, the "set location" chip, and the
 * impression/click beacon (zone-aware, mirroring the campaign tracker). */
(function () {
    'use strict';

    var CFG = window.zbHome || {};
    var LOGIN_DISMISS_KEY = 'zbHome_login_dismissed';
    var LOGIN_DISMISS_DAYS = 7;

    /* ── helpers ─────────────────────────────────── */
    function cookie(name) {
        var m = document.cookie.match('(?:^|; )' + name.replace(/([.$?*|{}()\[\]\\\/+^])/g, '\\$1') + '=([^;]*)');
        return m ? decodeURIComponent(m[1]) : '';
    }

    function recentIds() {
        var raw = cookie('zooboxi_recently_viewed');
        if (!raw) { return ''; }
        try {
            var arr = JSON.parse(raw);
            if (Array.isArray(arr)) {
                return arr.map(function (n) { return parseInt(n, 10) || 0; })
                          .filter(Boolean).slice(0, 12).join(',');
            }
        } catch (e) {}
        return '';
    }

    function anonId() {
        try {
            var k = 'zb_anon', v = localStorage.getItem(k);
            if (!v) { v = (Date.now().toString(36) + Math.random().toString(36).slice(2, 10)); localStorage.setItem(k, v); }
            return v;
        } catch (e) { return ''; }
    }

    function track(type, zone, itemCode) {
        try {
            var url = CFG.ajaxUrl;
            if (!url) { return; }
            var body = new FormData();
            body.append('action', 'zooboxi_track');
            body.append('event_type', type);
            body.append('anon_id', anonId());
            if (zone) { body.append('zone', zone); }
            if (itemCode) { body.append('item_code', itemCode); }
            if (type === 'impression' && navigator.sendBeacon) { navigator.sendBeacon(url, body); }
            else { fetch(url, { method: 'POST', body: body, keepalive: true, credentials: 'same-origin' }); }
        } catch (e) {}
    }

    function loginDismissed() {
        try {
            var until = parseInt(localStorage.getItem(LOGIN_DISMISS_KEY) || '0', 10);
            return until && Date.now() < until;
        } catch (e) { return false; }
    }

    /* ── hydration ───────────────────────────────── */
    function hydrate() {
        var slots = {};
        document.querySelectorAll('.zb-home [data-zb-feed]').forEach(function (el) {
            slots[el.getAttribute('data-zb-feed')] = el;
        });
        if (!Object.keys(slots).length) { return; }

        var params = new URLSearchParams();
        var lat = cookie('zooboxi_lat'), lng = cookie('zooboxi_lng'), city = cookie('zooboxi_city');
        if (lat) { params.set('lat', lat); }
        if (lng) { params.set('lng', lng); }
        if (city) { params.set('city', city); }
        var rec = recentIds();
        if (rec) { params.set('recent_ids', rec); }

        var url = CFG.feedUrl + (CFG.feedUrl.indexOf('?') > -1 ? '&' : '?') + params.toString();

        var headers = { 'Accept': 'application/json' };
        if (CFG.restNonce) { headers['X-WP-Nonce'] = CFG.restNonce; }

        fetch(url, { credentials: 'same-origin', headers: headers })
            .then(function (r) { return r.ok ? r.json() : {}; })
            .then(function (data) { applyFeed(slots, data || {}); })
            .catch(function () { applyFeed(slots, {}); });
    }

    function applyFeed(slots, data) {
        Object.keys(slots).forEach(function (key) {
            var el = slots[key];
            var html = data[key];

            // buy-again container falls back to the login invite for guests.
            if (!html) {
                var fb = el.getAttribute('data-zb-feed-fallback');
                if (fb && data[fb]) {
                    if (fb === 'login' && loginDismissed()) { remove(el); return; }
                    html = data[fb];
                }
            }
            if (!html) { remove(el); return; }
            el.innerHTML = html;
            el.classList.add('zb-home-slot--filled');
            initRails(el);
            observe(el);
            // Let the shared cart layer wrap the foot row + sync steppers on injected cards.
            if (window.zbxCards && window.zbxCards.refresh) { window.zbxCards.refresh(el); }
        });

        bindLoginCard();
        bindPromise();
        dedupeShellRails();
    }

    function remove(el) { if (el && el.parentNode) { el.parentNode.removeChild(el); } }

    /* ── cross-rail dedup ────────────────────────── */
    // Products surfaced in the personalized rails (مختار لك / اطلبها مجدداً / مدينتك)
    // shouldn't repeat in the global shell rails below. Remove the duplicates client-side
    // (the shell is page-cached, so this can't be done server-side per visitor).
    function pidOf(li) {
        var m = (li.className || '').match(/(?:^|\s)post-(\d+)/);
        return m ? m[1] : null;
    }
    function dedupeShellRails() {
        var seen = {};
        ['foryou', 'buyagain', 'incity'].forEach(function (k) {
            var slot = document.querySelector('.zb-home [data-zb-feed="' + k + '"]');
            if (!slot) { return; }
            slot.querySelectorAll('li.product').forEach(function (li) {
                var p = pidOf(li); if (p) { seen[p] = 1; }
            });
        });
        if (!Object.keys(seen).length) { return; }
        var removed = false;
        document.querySelectorAll('.zb-home .zb-rail').forEach(function (rail) {
            if (rail.closest('[data-zb-feed]')) { return; } // skip the personalized rails themselves
            rail.querySelectorAll('li.product').forEach(function (li) {
                var p = pidOf(li);
                if (p && seen[p]) { li.parentNode && li.parentNode.removeChild(li); removed = true; }
            });
        });
        // Let the rail arrow/fit logic recompute after card removal.
        if (removed) { window.dispatchEvent(new Event('resize')); }
        removeEmptyRails();
    }

    // Drop any rail whose products were all removed by dedup (e.g. "most wanted"
    // fully overlapping the in-city rail) so no empty titled section is left behind.
    function removeEmptyRails() {
        document.querySelectorAll('.zb-home .zb-rail:not(.zb-rail--skel)').forEach(function (rail) {
            if (!rail.querySelector('li.product')) {
                var slot = rail.closest('.zb-home-slot');
                remove(slot && !slot.querySelector('li.product') ? slot : rail);
            }
        });
    }

    /* ── rails: arrows + click tracking ──────────── */
    // Move the delivery badge out of the image overlay to sit just above the product
    // name — avoids colliding with the HOT/category badge on the image corner.
    function relocateBadges(rail) {
        rail.querySelectorAll('li.product').forEach(function (card) {
            var badge = card.querySelector('.zooboxi-delivery-badge:not(.zb-relocated)');
            if (!badge) { return; }
            var title = card.querySelector('.woocommerce-loop-product__title');
            if (title && title.parentNode) {
                title.parentNode.insertBefore(badge, title);
                badge.classList.add('zb-relocated');
            }
        });
    }

    function initRails(scope) {
        (scope || document).querySelectorAll('.zb-rail:not(.zb-rail--bound)').forEach(function (rail) {
            rail.classList.add('zb-rail--bound');
            var scroller = rail.querySelector('.zb-rail__scroller');
            var prev = rail.querySelector('.zb-rail__arrow--prev');
            var next = rail.querySelector('.zb-rail__arrow--next');
            if (!scroller || !prev || !next) { return; }

            var step = function () {
                var card = scroller.querySelector('li.product');
                return (card ? card.offsetWidth : 220) * 2 + 32;
            };
            // RTL: scrollLeft is <= 0; "next" (›, toward the end) goes more negative.
            next.addEventListener('click', function () { scroller.scrollBy({ left: -step(), behavior: 'smooth' }); });
            prev.addEventListener('click', function () { scroller.scrollBy({ left: step(), behavior: 'smooth' }); });

            var update = function () {
                var overflow = scroller.scrollWidth - scroller.clientWidth;
                var fits = overflow <= 4;
                // Center sparse rails (no scroll) so a lone card isn't jammed to one side.
                rail.classList.toggle('zb-rail--fits', fits);
                if (fits) {
                    prev.style.display = next.style.display = 'none';
                    return;
                }
                prev.style.display = next.style.display = '';
                var x = Math.abs(scroller.scrollLeft); // RTL → magnitude
                next.disabled = x >= overflow - 4;     // at the end
                prev.disabled = x <= 4;                 // at the start
            };
            scroller.addEventListener('scroll', update, { passive: true });
            window.addEventListener('resize', update);
            // Run after layout settles (images/fonts can change widths).
            update();
            setTimeout(update, 300);
        });
    }

    // Delegated click attribution for rail product cards.
    document.addEventListener('click', function (e) {
        var link = e.target.closest('.zb-rail a');
        if (!link) { return; }
        var rail = link.closest('.zb-rail');
        if (!rail) { return; }
        var zone = rail.getAttribute('data-zb-zone') || '';
        var li = link.closest('li.product');
        var marker = li ? li.querySelector('.zb-rail-item') : null;
        track('click', zone, marker ? marker.getAttribute('data-zb-item') : '');
    }, true);

    /* ── impressions ─────────────────────────────── */
    var seen = {};
    var io = ('IntersectionObserver' in window) ? new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
            var zone = en.target.getAttribute('data-zb-zone');
            if (en.isIntersecting && en.intersectionRatio >= 0.5 && zone && !seen[zone]) {
                seen[zone] = 1;
                track('impression', zone, '');
                io.unobserve(en.target);
            }
        });
    }, { threshold: [0.5] }) : null;

    function observe(scope) {
        if (!io) { return; }
        (scope || document).querySelectorAll('.zb-rail[data-zb-zone]').forEach(function (r) { io.observe(r); });
    }

    /* ── login invite ────────────────────────────── */
    function bindLoginCard() {
        var btn = document.getElementById('zb-login-card-btn');
        if (btn && !btn.dataset.bound) {
            btn.dataset.bound = '1';
            btn.addEventListener('click', function () {
                document.body.dispatchEvent(new CustomEvent('zbx:open-otp'));
            });
        }
        var later = document.getElementById('zb-login-card-later');
        if (later && !later.dataset.bound) {
            later.dataset.bound = '1';
            later.addEventListener('click', function () {
                try { localStorage.setItem(LOGIN_DISMISS_KEY, String(Date.now() + LOGIN_DISMISS_DAYS * 864e5)); } catch (e) {}
                var card = document.getElementById('zb-login-card');
                var slot = card && card.closest('.zb-home-slot');
                remove(slot || card);
            });
        }
    }

    /* ── delivery promise: open location chooser ─── */
    function openLocation() {
        var sel = ['#zooboxi-location-trigger', '.zooboxi-location-trigger', '.zbx-location-btn',
                   '[data-zooboxi-location]', '.zooboxi-location-selector'];
        for (var i = 0; i < sel.length; i++) {
            var t = document.querySelector(sel[i]);
            if (t) { t.click(); return true; }
        }
        document.body.dispatchEvent(new CustomEvent('zbx:open-location'));
        return false;
    }
    function bindPromise() {
        ['zb-promise-locate', 'zb-promise-edit'].forEach(function (id) {
            var el = document.getElementById(id);
            if (el && !el.dataset.bound) {
                el.dataset.bound = '1';
                el.addEventListener('click', function (e) { e.preventDefault(); openLocation(); });
            }
        });
    }

    /* ── hero slider ─────────────────────────────── */
    function initHero() {
        var hero = document.querySelector('.zb-hero');
        if (!hero || hero.dataset.bound) { return; }
        hero.dataset.bound = '1';
        var track = hero.querySelector('.zb-hero__track');
        var slides = hero.querySelectorAll('.zb-hero__slide');
        if (!track || slides.length === 0) { return; }

        var dots = hero.querySelectorAll('.zb-hero__dot');
        var n = slides.length, idx = 0, timer = null;
        var delay = parseInt(hero.getAttribute('data-zb-autoplay') || '6000', 10);
        var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        function go(i) {
            idx = (i + n) % n;
            track.style.transform = 'translateX(' + (-idx * 100) + '%)';
            for (var d = 0; d < dots.length; d++) { dots[d].classList.toggle('is-active', d === idx); }
            trackCampaign(slides[idx]);
        }
        function next() { go(idx + 1); }
        function prev() { go(idx - 1); }
        function start() { if (n > 1 && !reduce && !timer) { timer = setInterval(next, delay); } }
        function stop() { if (timer) { clearInterval(timer); timer = null; } }

        var seenCamp = {};
        function trackCampaign(slide) {
            if (!slide) { return; }
            var cid = slide.getAttribute('data-zb-campaign');
            if (cid && !seenCamp[cid]) {
                seenCamp[cid] = 1;
                beaconCampaign('impression', slide);
            }
        }
        function beaconCampaign(type, slide) {
            try {
                var url = CFG.ajaxUrl; if (!url) { return; }
                var body = new FormData();
                body.append('action', 'zooboxi_track');
                body.append('event_type', type);
                body.append('anon_id', anonId());
                body.append('zone', slide.getAttribute('data-zb-zone') || 'home:hero');
                body.append('ab_variant', slide.getAttribute('data-zb-variant') || 'A');
                body.append('item_code', slide.getAttribute('data-zb-item') || '');
                body.append('payload', JSON.stringify({ campaign_id: parseInt(slide.getAttribute('data-zb-campaign') || '0', 10) }));
                if (type === 'impression' && navigator.sendBeacon) { navigator.sendBeacon(url, body); }
                else { fetch(url, { method: 'POST', body: body, keepalive: true, credentials: 'same-origin' }); }
            } catch (e) {}
        }

        var nextBtn = hero.querySelector('.zb-hero__arrow--next');
        var prevBtn = hero.querySelector('.zb-hero__arrow--prev');
        if (nextBtn) { nextBtn.addEventListener('click', function (e) { e.preventDefault(); next(); stop(); start(); }); }
        if (prevBtn) { prevBtn.addEventListener('click', function (e) { e.preventDefault(); prev(); stop(); start(); }); }
        for (var d = 0; d < dots.length; d++) {
            (function (di) { dots[di].addEventListener('click', function (e) { e.preventDefault(); go(di); stop(); start(); }); })(d);
        }

        // Click attribution for campaign slides.
        for (var s = 0; s < slides.length; s++) {
            slides[s].addEventListener('click', function () {
                if (this.getAttribute('data-zb-campaign')) { beaconCampaign('click', this); }
            });
        }

        // Touch swipe (RTL-aware via physical deltaX).
        var x0 = null;
        hero.addEventListener('touchstart', function (e) { x0 = e.touches[0].clientX; stop(); }, { passive: true });
        hero.addEventListener('touchend', function (e) {
            if (x0 === null) { return; }
            var dx = e.changedTouches[0].clientX - x0;
            if (Math.abs(dx) > 40) { dx < 0 ? next() : prev(); }
            x0 = null; start();
        }, { passive: true });

        hero.addEventListener('mouseenter', stop);
        hero.addEventListener('mouseleave', start);
        document.addEventListener('visibilitychange', function () { document.hidden ? stop() : start(); });

        go(0);
        start();
    }

    /* ── brand HTML hero: scale the fixed 1600×600 stage to the slide width ── */
    function scaleBrandHero() {
        document.querySelectorAll('.zb-bh-wrap').forEach(function (wrap) {
            var stage = wrap.querySelector('.zb-bh');
            if (!stage) { return; }
            var w = wrap.clientWidth;
            if (w > 0) { stage.style.transform = 'scale(' + (w / 1600) + ')'; }
        });
    }
    window.addEventListener('resize', scaleBrandHero);

    /* ── boot ────────────────────────────────────── */
    function boot() {
        scaleBrandHero();
        initHero();
        // Re-scale once fonts/images settle (clientWidth can be 0 pre-layout).
        setTimeout(scaleBrandHero, 60);
        setTimeout(scaleBrandHero, 400);
        initRails(document); // shell rails are already in the DOM
        observe(document);
        hydrate();
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
