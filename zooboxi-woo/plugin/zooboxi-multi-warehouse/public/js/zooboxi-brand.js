/**
 * Zooboxi brand boutique page — curated-rail arrow scrolling (zooboxi-home.js is
 * not loaded here) + best-effort impression/click attribution for the AI hero and
 * promo tiles (reuses the existing admin-ajax `zooboxi_track` event spine).
 */
(function () {
    'use strict';

    /* ── Curated rail arrows ───────────────────────────── */
    function wireRails() {
        var rails = document.querySelectorAll('.zb-brand .zb-rail, .zb-brand-rail');
        rails.forEach(function (rail) {
            var scroller = rail.querySelector('.zb-rail__scroller');
            if (!scroller) {
                return;
            }
            var prev = rail.querySelector('.zb-rail__arrow--prev');
            var next = rail.querySelector('.zb-rail__arrow--next');
            function step(dir) {
                var amount = Math.max(240, scroller.clientWidth * 0.85) * dir;
                scroller.scrollBy({ left: amount, behavior: 'smooth' });
            }
            // RTL: ‹ (prev) reveals earlier cards, › (next) reveals later ones.
            if (prev) { prev.addEventListener('click', function () { step(1); }); }
            if (next) { next.addEventListener('click', function () { step(-1); }); }
        });
    }

    /* ── AI banner attribution (hero + tiles) ──────────── */
    function ajaxUrl() {
        if (window.zooboxiData && window.zooboxiData.ajaxUrl) {
            return window.zooboxiData.ajaxUrl;
        }
        return '/wp-admin/admin-ajax.php';
    }
    function anon() {
        try {
            var k = 'zb_anon', v = localStorage.getItem(k);
            if (!v) { v = Date.now().toString(36) + Math.random().toString(36).slice(2, 10); localStorage.setItem(k, v); }
            return v;
        } catch (e) { return ''; }
    }
    function track(type, el) {
        try {
            var body = new FormData();
            body.append('action', 'zooboxi_track');
            body.append('event_type', type);
            body.append('anon_id', anon());
            body.append('zone', el.getAttribute('data-zb-zone') || '');
            body.append('ab_variant', 'A');
            body.append('payload', JSON.stringify({ brand: 1 }));
            var url = ajaxUrl();
            if (type === 'impression' && navigator.sendBeacon) {
                navigator.sendBeacon(url, body);
            } else {
                fetch(url, { method: 'POST', body: body, keepalive: true });
            }
        } catch (e) {}
    }
    function wireTracking() {
        var els = document.querySelectorAll('.zb-brand-track[data-zb-zone]');
        if (!els.length) {
            return;
        }
        var seen = {};
        if ('IntersectionObserver' in window) {
            var io = new IntersectionObserver(function (entries) {
                entries.forEach(function (en) {
                    var z = en.target.getAttribute('data-zb-zone');
                    if (en.isIntersecting && en.intersectionRatio >= 0.5 && !seen[z]) {
                        seen[z] = 1;
                        track('impression', en.target);
                        io.unobserve(en.target);
                    }
                });
            }, { threshold: [0.5] });
            els.forEach(function (el) { io.observe(el); });
        }
        els.forEach(function (el) {
            el.addEventListener('click', function () { track('click', el); });
        });
    }

    function init() {
        wireRails();
        wireTracking();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
