/**
 * Zooboxi Delight Layer — microinteractions for the browse & buy journey.
 * CSS-first, IntersectionObserver-driven, fully disabled under
 * prefers-reduced-motion. No layout thrash: transforms/opacity only.
 */
(function () {
    'use strict';
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    /* ── 1. Scroll-reveal: sections rise softly, cards stagger in ── */
    function initReveal() {
        if (reduced || !('IntersectionObserver' in window)) return;

        var sections = document.querySelectorAll('.zb-rail, .zbx-brands-slider-container, .zbx-footer-card, .zb-promise');
        var grids = document.querySelectorAll('.woocommerce ul.products, ul.wc-block-product-template');

        var done = function (el) {
            el.classList.remove('zbx-io', 'zbx-in');
            el.style.transitionDelay = '';
        };

        var io = new IntersectionObserver(function (entries) {
            entries.forEach(function (en) {
                if (!en.isIntersecting) return;
                var el = en.target;
                io.unobserve(el);
                if (el.matches('ul')) {
                    // stagger the cards that are inside
                    var kids = el.querySelectorAll(':scope > li');
                    kids.forEach(function (li, i) {
                        li.style.transitionDelay = Math.min(i * 55, 440) + 'ms';
                        li.classList.add('zbx-in');
                        setTimeout(function () { done(li); }, 900 + Math.min(i * 55, 440));
                    });
                } else {
                    el.classList.add('zbx-in');
                    setTimeout(function () { done(el); }, 900);
                }
            });
        }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });

        sections.forEach(function (el) {
            if (el.dataset.zbxReveal) return;
            el.dataset.zbxReveal = '1';
            el.classList.add('zbx-io');
            io.observe(el);
        });
        grids.forEach(function (ul) {
            if (ul.dataset.zbxReveal) return;
            ul.dataset.zbxReveal = '1';
            ul.querySelectorAll(':scope > li').forEach(function (li) { li.classList.add('zbx-io'); });
            io.observe(ul);
        });
    }

    /* ── 2. Fly-to-cart: the product image arcs into the header bag ── */
    function cartAnchor() {
        var badge = document.querySelector('.zooboxi-cart-count');
        if (badge) { return badge.closest('a') || badge; }
        return document.querySelector('a[href*="/cart"]');
    }

    document.addEventListener('click', function (e) {
        if (reduced) return;
        var btn = e.target.closest('a.add_to_cart_button.ajax_add_to_cart');
        if (!btn || btn.classList.contains('product_type_variable') || btn.classList.contains('product_type_grouped')) return;
        var li = btn.closest('li');
        var img = li ? li.querySelector('img') : null;
        var target = cartAnchor();
        if (!img || !target || !img.getBoundingClientRect().width) return;

        var r = img.getBoundingClientRect();
        var c = target.getBoundingClientRect();
        var ghost = document.createElement('img');
        ghost.src = img.currentSrc || img.src;
        ghost.className = 'zbx-fly-img';
        ghost.style.left = r.left + 'px';
        ghost.style.top = r.top + 'px';
        ghost.style.width = r.width + 'px';
        ghost.style.height = r.height + 'px';
        document.body.appendChild(ghost);

        var dx = (c.left + c.width / 2) - (r.left + r.width / 2);
        var dy = (c.top + c.height / 2) - (r.top + r.height / 2);
        var anim = ghost.animate([
            { transform: 'translate(0,0) scale(1)', opacity: 0.95 },
            { transform: 'translate(' + dx * 0.55 + 'px,' + (dy - Math.max(90, Math.abs(dy) * 0.25)) + 'px) scale(0.45)', opacity: 0.9, offset: 0.6 },
            { transform: 'translate(' + dx + 'px,' + dy + 'px) scale(0.1)', opacity: 0.3 }
        ], { duration: 680, easing: 'cubic-bezier(.45,-0.05,.55,1)' });
        anim.onfinish = function () { ghost.remove(); };
        setTimeout(function () { if (ghost.parentNode) ghost.remove(); }, 1200);
    }, true);

    /* ── 3. Badge & stepper pops ── */
    function pop(el) {
        if (!el || reduced) return;
        el.classList.remove('zbx-pop');
        void el.offsetWidth;
        el.classList.add('zbx-pop');
    }

    if (window.jQuery) {
        jQuery(document.body).on('added_to_cart removed_from_cart updated_cart_totals wc_fragments_refreshed', function () {
            setTimeout(function () { pop(document.querySelector('.zooboxi-cart-count')); }, 60);
        });
    }

    document.addEventListener('click', function (e) {
        var sBtn = e.target.closest('.zbx-qty-btn');
        if (sBtn) {
            var v = sBtn.parentElement && sBtn.parentElement.querySelector('.zbx-qty-value');
            pop(v);
        }
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initReveal);
    } else {
        initReveal();
    }
    /* rails hydrate late (home-feed) — second sweep for content that arrived after load */
    setTimeout(initReveal, 2500);
})();

/* ── 4. Toast adoption: fixed-position breaks inside transformed ancestors
       (the mobile drawer transforms the page wrapper), so success notices
       are re-parented to <body> the moment they appear. ── */
(function () {
    function adopt() {
        document.querySelectorAll('.woocommerce-notices-wrapper .woocommerce-message, .wc-block-components-notice-banner.is-success').forEach(function (n) {
            if (n.parentElement !== document.body) {
                document.body.appendChild(n);
            }
        });
    }
    adopt();
    new MutationObserver(adopt).observe(document.body, { childList: true, subtree: true });
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', adopt);
    }
})();

/* ── 5. Checkout: keep the visible city/district in step with the map ── */
(function () {
    if (typeof jQuery === 'undefined') return;
    var $ = jQuery;

    function cityAr(name) {
        var key = String(name || '').trim().toLowerCase();
        return (typeof zbxCityMap !== 'undefined' && zbxCityMap[key]) ? zbxCityMap[key] : name;
    }

    function setField(sel, value) {
        if (!value) return;
        var $f = $(sel);
        if (!$f.length) return;
        if ($f.val() === value) return;
        $f.val(value).addClass('zbx-field-synced');
        setTimeout(function () { $f.removeClass('zbx-field-synced'); }, 1400);
    }

    function apply(data) {
        if (!data) return;
        setField('#billing_city', cityAr(data.city));
        setField('#billing_address_2', data.district);
    }

    // The map posts zooboxi_update_checkout_location on every drag; its response
    // carries the resolved city + district.
    $(document).ajaxSuccess(function (e, xhr, settings) {
        var d = settings && settings.data ? String(settings.data) : '';
        if (d.indexOf('zooboxi_update_checkout_location') === -1) return;
        var res = xhr.responseJSON;
        if (!res || !res.success) return;
        apply(res.data);
        // the plugin's own browser-side geocode lands slightly later and writes
        // the English name — re-apply the Arabic one after it settles
        setTimeout(function () { apply(res.data); }, 1500);
    });
})();

/* ── 6. Checkout: group the order lines by shipment so the customer can see
       exactly WHICH products arrive in 2 hours and which take 24. ── */
(function () {
    if (typeof jQuery === 'undefined') return;
    var $ = jQuery;

    var TIERS = {
        express:  { order: 1, icon: '⚡', title: 'توصيل سريع', note: 'خلال ساعتين' },
        standard: { order: 2, icon: '🚚', title: 'توصيل عادي', note: 'خلال 24 ساعة' },
        shipping: { order: 3, icon: '📦', title: 'شحن عادي', note: '4–5 أيام عمل' },
        unknown:  { order: 9, icon: '📍', title: 'التوصيل', note: '' }
    };

    function tierOf($row) {
        var badge = $row.find('[class*="zooboxi-cart-badge--"]').get(0);
        if (!badge) return 'unknown';
        var m = /zooboxi-cart-badge--([a-z_]+)/.exec(badge.className);
        return (m && TIERS[m[1]]) ? m[1] : 'unknown';
    }

    function label(n) {
        if (n === 1) return 'صنف واحد';
        if (n === 2) return 'صنفان';
        return n + (n <= 10 ? ' أصناف' : ' صنفاً');
    }

    function group() {
        var $tbody = $('.woocommerce-checkout-review-order-table tbody');
        if (!$tbody.length) return;
        $tbody.find('tr.zbx-tier-head').remove();

        var $rows = $tbody.find('tr.cart_item');
        if ($rows.length < 2) return;

        var buckets = {};
        $rows.each(function () {
            var t = tierOf($(this));
            (buckets[t] = buckets[t] || []).push(this);
        });
        var keys = Object.keys(buckets);
        if (keys.length < 2) return; // single shipment — the top banner already says it

        keys.sort(function (a, b) { return TIERS[a].order - TIERS[b].order; });
        keys.forEach(function (k) {
            var meta = TIERS[k];
            var $head = $('<tr class="zbx-tier-head zbx-tier-head--' + k + '"><td colspan="2">' +
                '<span class="zbx-tier-inner">' +
                '<span class="zbx-tier-ic">' + meta.icon + '</span>' +
                '<span class="zbx-tier-title">' + meta.title + (meta.note ? ' · ' + meta.note : '') + '</span>' +
                '<span class="zbx-tier-count">' + label(buckets[k].length) + '</span>' +
                '</span></td></tr>');
            $tbody.append($head);
            buckets[k].forEach(function (tr) { $tbody.append(tr); });
        });
        // the group header carries the promise now — the per-row pill is noise
        $tbody.find('tr.cart_item [class*="zooboxi-cart-badge--"]').addClass('zbx-badge-muted');
    }

    $(function () { group(); });
    $(document.body).on('updated_checkout', function () { setTimeout(group, 60); });
})();

/* ── 7. Never prompt for a location on the order-received page ── */
(function () {
    if (!document.body || document.body.className.indexOf('woocommerce-order-received') === -1) return;
    var kill = function () {
        document.querySelectorAll('.zooboxi-modal, #zooboxi-location-modal, #zbx-drift-modal').forEach(function (m) {
            m.style.display = 'none';
        });
        document.body.style.overflow = '';
    };
    kill();
    setTimeout(kill, 600);
    setTimeout(kill, 2000);
})();

/* ── 8. Checkout: keep map-written values Arabic & readable ──
   The plugin's own browser-side geocoder writes the raw Google values
   ("Riyadh Principality", "WQXJ+8W Ar Rimal…") straight into the DOM after
   every map idle, so a one-shot translation loses the race. Normalising on a
   light interval is the only reliable way without forking the plugin. */
(function () {
    if (typeof jQuery === 'undefined') return;
    if (!document.body || document.body.className.indexOf('woocommerce-checkout') === -1) return;
    var $ = jQuery;

    function cityAr(name) {
        var key = String(name || '').trim().toLowerCase();
        return (typeof zbxCityMap !== 'undefined' && zbxCityMap[key]) ? zbxCityMap[key] : name;
    }

    // "WQXJ+8W Ar Rimal, Riyadh" → "Ar Rimal, Riyadh" (plus codes mean nothing to a customer)
    function stripPlusCode(text) {
        return String(text || '').replace(/(^|📍\s*)[A-Z0-9]{4,6}\+[A-Z0-9]{2,4},?\s*/g, '$1');
    }

    function normalise() {
        var $city = $('#billing_city');
        if ($city.length) {
            var v = $city.val();
            var ar = cityAr(v);
            if (ar && ar !== v) $city.val(ar);
        }
        var addr = document.getElementById('zbx-checkout-address');
        if (addr && addr.textContent) {
            var clean = stripPlusCode(addr.textContent);
            if (clean !== addr.textContent) addr.textContent = clean;
        }
    }

    $(function () {
        normalise();
        setInterval(normalise, 700);
    });
})();
