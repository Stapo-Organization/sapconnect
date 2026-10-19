/* Zooboxi v2 — storefront behaviour. Vanilla JS; jQuery only to speak to WooCommerce's events. */
(function () {
  'use strict';
  var Z = window.ZV || {};
  var T = Z.i18n || {};
  var $ = window.jQuery;
  var doc = document;
  var body = doc.body;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function qs(s, r) { return (r || doc).querySelector(s); }
  function qsa(s, r) { return Array.prototype.slice.call((r || doc).querySelectorAll(s)); }
  function on(type, sel, fn) {
    doc.addEventListener(type, function (e) {
      var t = e.target.closest ? e.target.closest(sel) : null;
      if (t) fn(e, t);
    });
  }
  function wcAjax(endpoint) { return (Z.wcAjax || '/?wc-ajax=%%endpoint%%').replace('%%endpoint%%', endpoint); }
  function post(url, data) {
    var fd = new URLSearchParams();
    Object.keys(data).forEach(function (k) { fd.append(k, data[k]); });
    return fetch(url, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' }, body: fd.toString() })
      .then(function (r) { return r.json(); });
  }
  function money(n) {
    var v = Number(n || 0).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return '<span class="zv-money"><bdi>' + v + '</bdi>&nbsp;<span class="zv-sar">﷼</span></span>';
  }
  function esc(s) { var d = doc.createElement('div'); d.textContent = s == null ? '' : String(s); return d.innerHTML; }

  /* ── Header shadow ─────────────────────────────────────────────── */
  var header = qs('[data-zv-header]');
  if (header) {
    var stuck = function () { header.classList.toggle('is-stuck', window.scrollY > 8); };
    window.addEventListener('scroll', stuck, { passive: true });
    stuck();
  }

  /* ── Panels: cart, drawer, location ────────────────────────────── */
  var scrim = qs('[data-zv-scrim]');
  var openPanel = null;
  var lastFocus = null;
  function open(name) {
    var p = qs('[data-zv-panel="' + name + '"]');
    if (!p) return;
    if (openPanel && openPanel !== p) close(true);
    lastFocus = doc.activeElement;
    p.hidden = false;
    scrim.hidden = false;
    body.classList.add('zv-lock');
    requestAnimationFrame(function () {
      p.classList.add('is-on');
      scrim.classList.add('is-on');
      var f = p.querySelector('button, a, input');
      if (f) f.focus({ preventScroll: true });
    });
    openPanel = p;
    if (name === 'location') initMap();
  }
  function close(keepScrim) {
    if (!openPanel) return;
    var p = openPanel;
    p.classList.remove('is-on');
    openPanel = null;
    if (!keepScrim) {
      scrim.classList.remove('is-on');
      body.classList.remove('zv-lock');
      setTimeout(function () { if (!openPanel) scrim.hidden = true; }, 260);
    }
    setTimeout(function () { if (openPanel !== p) p.hidden = true; }, 300);
    if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true });
  }
  on('click', '[data-zv-open]', function (e, t) { e.preventDefault(); open(t.getAttribute('data-zv-open')); });
  on('click', '[data-zv-close]', function (e) { e.preventDefault(); close(); });
  if (scrim) scrim.addEventListener('click', function () { close(); });
  doc.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    if (openPanel) close();
    var side = qs('.zv-listing__side.is-open');
    if (side) toggleFilters(false);
  });
  on('click', '[data-zv-focus-search]', function () {
    var q = qs('[data-zv-q]');
    if (q) { window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' }); setTimeout(function () { q.focus(); }, 250); }
  });

  /* Mega menu on touch: first tap opens, second follows the link. */
  on('click', '.zv-nav__item.has-mega > .zv-nav__link', function (e, a) {
    if (window.matchMedia('(hover: hover)').matches) return;
    var li = a.parentNode;
    if (!li.classList.contains('is-open')) {
      e.preventDefault();
      qsa('.zv-nav__item.is-open').forEach(function (x) { x.classList.remove('is-open'); });
      li.classList.add('is-open');
    }
  });
  doc.addEventListener('click', function (e) {
    if (!e.target.closest('.zv-nav')) qsa('.zv-nav__item.is-open').forEach(function (x) { x.classList.remove('is-open'); });
  });

  /* Mega panels: pictures load on the first open; a department shows its
     shelves on hover (after a beat, so a diagonal move toward the panel
     doesn't flip departments on the way), on focus, or on a first tap. */
  qsa('[data-zv-mega]').forEach(function (li) {
    var loaded = false, timer = null;
    var load = function () {
      if (loaded) return;
      loaded = true;
      qsa('img[data-src]', li).forEach(function (im) { im.src = im.getAttribute('data-src'); im.removeAttribute('data-src'); });
    };
    var show = function (a) {
      var key = a.getAttribute('data-zv-dept');
      qsa('[data-zv-dept]', li).forEach(function (x) { x.classList.toggle('is-on', x === a); });
      qsa('[data-zv-mpanel]', li).forEach(function (p) { p.hidden = p.getAttribute('data-zv-mpanel') !== key; });
    };
    li.addEventListener('mouseenter', load);
    li.addEventListener('focusin', load);
    li.addEventListener('touchstart', load, { passive: true });
    qsa('[data-zv-dept]', li).forEach(function (a) {
      a.addEventListener('mouseenter', function () { clearTimeout(timer); timer = setTimeout(function () { show(a); }, 110); });
      a.addEventListener('mouseleave', function () { clearTimeout(timer); });
      a.addEventListener('focus', function () { show(a); });
      a.addEventListener('click', function (e) {
        if (window.matchMedia('(hover: hover)').matches || a.classList.contains('is-on')) return;
        e.preventDefault();
        show(a);
      });
    });
  });

  /* ── Search suggestions (the app's own suggest endpoint) ───────── */
  var form = qs('[data-zv-search]');
  if (form && Z.rest) {
    var input = qs('[data-zv-q]', form);
    var box = qs('[data-zv-suggest]', form);
    var timer = null, seq = 0, active = -1;
    var hide = function () { box.hidden = true; active = -1; };
    var render = function (items, q) {
      if (!items.length) {
        box.innerHTML = '<div class="zv-suggest__empty">' + esc(T.noResults) + '</div>';
      } else {
        box.innerHTML = items.slice(0, 7).map(function (it) {
          return '<a class="zv-suggest__item" href="' + esc(it.url || ('/?post_type=product&p=' + it.id)) + '">' +
            '<img src="' + esc(it.image || '') + '" alt="" loading="lazy" width="52" height="52">' +
            '<span class="zv-suggest__name">' + esc(it.name) + '</span>' +
            '<span class="zv-suggest__price">' + (it.price ? money(it.price) : '') + '</span></a>';
        }).join('') + '<a class="zv-suggest__all" href="' + esc(form.action + '?s=' + encodeURIComponent(q) + '&post_type=product') + '">' + esc(T.allResults) + '</a>';
      }
      box.hidden = false;
      active = -1;
    };
    input.addEventListener('input', function () {
      var q = input.value.trim();
      clearTimeout(timer);
      if (q.length < 2) { hide(); return; }
      timer = setTimeout(function () {
        var my = ++seq;
        fetch(Z.rest + 'zooboxi/v2/catalog/search/suggest?q=' + encodeURIComponent(q), { credentials: 'same-origin' })
          .then(function (r) { return r.json(); })
          .then(function (j) { if (my === seq) render(((j && j.data && j.data.suggestions) || []), q); })
          .catch(function () {});
      }, 220);
    });
    input.addEventListener('keydown', function (e) {
      var items = qsa('.zv-suggest__item', box);
      if (box.hidden || !items.length) return;
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        active = (active + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
        items.forEach(function (x, i) { x.classList.toggle('is-active', i === active); });
      } else if (e.key === 'Enter' && active >= 0) {
        e.preventDefault();
        location.href = items[active].href;
      }
    });
    doc.addEventListener('click', function (e) { if (!e.target.closest('[data-zv-search]')) hide(); });
  }

  /* ── Cart: fragments, add, steppers ────────────────────────────── */
  var cartMap = {};
  function readMap() {
    var el = qs('#zv-cart-map');
    try { cartMap = el ? JSON.parse(el.textContent || '{}') : {}; } catch (e) { cartMap = {}; }
    paintCards();
  }
  function applyFragments(fr) {
    if (!fr) return;
    Object.keys(fr).forEach(function (sel) {
      qsa(sel).forEach(function (el) {
        var tmp = doc.createElement('div');
        tmp.innerHTML = fr[sel];
        var node = tmp.firstElementChild;
        if (node) el.replaceWith(node.cloneNode(true));
      });
    });
    readMap();
    doc.dispatchEvent(new CustomEvent('zv:fragments'));
  }
  function stepper(qty, max) {
    return '<div class="zv-step" data-zv-cardstep data-max="' + (max || 99) + '">' +
      '<button type="button" class="zv-step__btn" data-step="1" aria-label="+">' + icon('plus') + '</button>' +
      '<span class="zv-step__n" aria-live="polite">' + qty + '</span>' +
      '<button type="button" class="zv-step__btn" data-step="-1" aria-label="−">' + icon(qty <= 1 ? 'trash' : 'minus') + '</button></div>';
  }
  function icon(n) {
    var p = { plus: '<path d="M12 5v14M5 12h14"/>', minus: '<path d="M5 12h14"/>', trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>' }[n];
    return '<svg class="zv-i" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
  }
  function paintCards() {
    qsa('.zv-card[data-pid]').forEach(function (card) {
      var pid = card.getAttribute('data-pid');
      var foot = qs('.zv-card__foot', card);
      if (!foot) return;
      var add = qs('[data-zv-add]', foot);
      var st = qs('[data-zv-cardstep]', foot);
      var line = cartMap[pid];
      if (line && line.qty > 0) {
        var html = stepper(line.qty);
        if (st) { st.outerHTML = html; } else if (add) { add.outerHTML = html; }
      } else if (st) {
        st.outerHTML = '<button type="button" class="zv-add" data-zv-add="' + pid + '" aria-label="+">' + icon('plus').replace('width="16" height="16"', 'width="20" height="20"') + '</button>';
      }
    });
  }
  function toast(html, cls) {
    var wrap = qs('[data-zv-toasts]');
    if (!wrap) return;
    var t = doc.createElement('div');
    t.className = 'zv-toast' + (cls ? ' ' + cls : '');
    t.innerHTML = html;
    wrap.appendChild(t);
    setTimeout(function () { t.classList.add('is-out'); setTimeout(function () { t.remove(); }, 260); }, 3600);
  }
  function addToCart(pid, qty, btn, opts) {
    opts = opts || {};
    if (btn) btn.classList.add('is-busy');
    // Read the product's face now: the fragments below replace the button.
    var card = btn && btn.closest('.zv-card, [data-zv-pdp]');
    var img = card ? qs('.zv-card__media img, [data-zv-gallery-main]', card) : null;
    var imgSrc = img ? (img.currentSrc || img.src) : '';
    var name = card ? ((qs('.zv-card__name, .zv-pdp__title', card) || {}).textContent || '') : '';
    return post(wcAjax('add_to_cart'), { product_id: pid, quantity: qty || 1 }).then(function (res) {
      if (btn) btn.classList.remove('is-busy');
      if (!res || res.error) {
        if (res && res.product_url && !opts.quiet) { location.href = res.product_url; return false; }
        toast('<div><strong>' + esc(T.error) + '</strong></div>', 'zv-toast--error');
        return false;
      }
      // The motion layer flies the product's picture into the cart (zv-motion.js).
      doc.dispatchEvent(new CustomEvent('zv:added', { detail: { img: img, src: imgSrc } }));
      applyFragments(res.fragments);
      if ($) $(body).trigger('added_to_cart', [res.fragments, res.cart_hash, btn ? $(btn) : null]);
      if (!opts.quiet) {
        toast((imgSrc ? '<img src="' + esc(imgSrc) + '" alt="">' : '<span></span>') +
          '<div><strong>' + esc(T.added) + '</strong><span>' + esc((name || '').trim()) + '</span></div>' +
          '<button type="button" data-zv-open="cart">' + esc(T.viewCart) + '</button>');
      }
      return true;
    }).catch(function () {
      if (btn) btn.classList.remove('is-busy');
      toast('<div><strong>' + esc(T.error) + '</strong></div>', 'zv-toast--error');
      return false;
    });
  }
  function setQty(key, qty, el) {
    var row = el && el.closest('.zv-mc__item');
    if (row) row.classList.add('is-busy');
    return post(wcAjax('zv_set_qty'), { key: key, qty: qty }).then(function (res) {
      applyFragments(res && res.fragments);
      if ($) $(body).trigger(qty > 0 ? 'zv_qty_changed' : 'removed_from_cart', [res && res.fragments, res && res.cart_hash]);
    }).catch(function () { toast('<div><strong>' + esc(T.error) + '</strong></div>', 'zv-toast--error'); if (row) row.classList.remove('is-busy'); });
  }

  on('click', '[data-zv-add]', function (e, b) { e.preventDefault(); addToCart(b.getAttribute('data-zv-add'), 1, b); });
  on('click', '[data-zv-cardstep] .zv-step__btn', function (e, b) {
    var card = b.closest('.zv-card');
    var line = cartMap[card.getAttribute('data-pid')];
    if (!line) return;
    var n = Math.max(0, line.qty + parseInt(b.getAttribute('data-step'), 10));
    var max = parseInt(b.closest('.zv-step').getAttribute('data-max'), 10) || 99;
    if (n > max) return;
    line.qty = n;
    qs('.zv-step__n', b.closest('.zv-step')).textContent = n;
    setQty(line.key, n);
  });
  on('click', '.zv-mc__item .zv-step__btn', function (e, b) {
    var st = b.closest('.zv-step');
    var key = st.getAttribute('data-key');
    var n = parseInt(qs('.zv-step__n', st).textContent, 10) + parseInt(b.getAttribute('data-step'), 10);
    var max = parseInt(st.getAttribute('data-max'), 10) || 99;
    if (n > max) return;
    setQty(key, Math.max(0, n), b);
  });
  on('click', '[data-zv-remove]', function (e, b) { setQty(b.getAttribute('data-zv-remove'), 0, b); });

  if ($) {
    $(body).on('wc_fragments_refreshed wc_fragments_loaded updated_wc_div', readMap);
    $(body).on('added_to_cart', function (e, fr) { if (fr && !fr['script#zv-cart-map']) readMap(); });
  }
  readMap();

  /* Cart page: steppers drive WooCommerce's own cart form (cart.js recalculates). */
  on('click', '[data-zv-cartform] .zv-step__btn', function (e, b) {
    var st = b.closest('.zv-step');
    var inp = qs('input.qty', st);
    var max = parseInt(st.getAttribute('data-max'), 10) || 99;
    var n = Math.min(max, Math.max(0, (parseInt(inp.value, 10) || 0) + parseInt(b.getAttribute('data-step'), 10)));
    inp.value = n;
    if ($) $(inp).trigger('change');
    var upd = qs('[name="update_cart"]');
    if (upd) { upd.disabled = false; upd.click(); }
  });

  /* ── Product page ──────────────────────────────────────────────── */
  var pdp = qs('[data-zv-pdp]');
  if (pdp) {
    var buy = qs('[data-zv-buy]', pdp);
    var qtyBox = qs('[data-zv-qty]', pdp);
    var qtyIn = qtyBox && qs('input', qtyBox);
    var priceBox = qs('[data-zv-price]', pdp);
    var mainImg = qs('[data-zv-gallery-main]', pdp);

    qsa('.zv-opt input', pdp).forEach(function (r) {
      r.addEventListener('change', function () {
        qsa('.zv-opt', pdp).forEach(function (l) { l.classList.toggle('is-on', l.contains(r) && r.checked); });
        var vid = qs('[data-zv-vid]', pdp);
        if (vid) vid.value = r.value;
        var attrs = {};
        try { attrs = JSON.parse(r.getAttribute('data-attrs') || '{}'); } catch (e) {}
        Object.keys(attrs).forEach(function (k) {
          var h = qs('[data-zv-attr="' + k + '"]', pdp);
          if (h) h.value = attrs[k];
        });
        var price = parseFloat(r.getAttribute('data-price'));
        var reg = parseFloat(r.getAttribute('data-regular'));
        var kg = parseFloat(r.getAttribute('data-perkg'));
        if (priceBox) {
          var m = qs('.zv-money', priceBox);
          if (m) m.outerHTML = money(price).replace('zv-money', 'zv-money' + (reg > price ? ' is-sale' : ''));
          var u = qs('[data-zv-perkg]', priceBox);
          if (u) u.textContent = kg > 0 ? (Z.lang === 'en' ? kg.toFixed(2) + ' SAR/kg' : kg.toFixed(2) + ' ﷼ للكيلو') : '';
        }
        var lab = qs('[data-zv-opt-label]', pdp);
        if (lab) lab.textContent = r.getAttribute('data-label');
        var sl = qs('[data-zv-sticky-label]');
        if (sl) sl.textContent = r.getAttribute('data-label');
        var sp = qs('.zv-stickybuy__price .zv-money');
        if (sp) sp.outerHTML = money(price);
        var max = parseInt(r.getAttribute('data-max'), 10) || 99;
        if (qtyBox) { qtyBox.setAttribute('data-max', max); if (qtyIn) { qtyIn.max = max; if (+qtyIn.value > max) qtyIn.value = max; } }
        var im = r.getAttribute('data-image');
        if (im && mainImg) mainImg.src = im;
      });
    });
    if (qtyBox) {
      qsa('.zv-step__btn', qtyBox).forEach(function (b) {
        b.addEventListener('click', function () {
          var max = parseInt(qtyBox.getAttribute('data-max'), 10) || 99;
          qtyIn.value = Math.min(max, Math.max(1, (parseInt(qtyIn.value, 10) || 1) + parseInt(b.getAttribute('data-step'), 10)));
        });
      });
    }
    var buyNow = false;
    qsa('[data-zv-buy-now]', pdp).forEach(function (b) { b.addEventListener('click', function () { buyNow = true; }); });
    if (buy) {
      buy.addEventListener('submit', function (e) {
        e.preventDefault();
        var vid = qs('[data-zv-vid]', buy);
        var pid = vid ? vid.value : (qs('[name="add-to-cart"]', buy) || {}).value;
        var q = qtyIn ? parseInt(qtyIn.value, 10) || 1 : 1;
        var btn = buyNow ? qs('[data-zv-buy-now]', buy) : qs('[data-zv-add-form]', buy);
        var now = buyNow;
        buyNow = false;
        addToCart(pid, q, btn, { quiet: now }).then(function (ok) {
          if (ok && now) location.href = Z.checkoutUrl;
        });
      });
    }
    // Gallery
    qsa('.zv-gallery__thumb', pdp).forEach(function (t) {
      t.addEventListener('click', function () {
        qsa('.zv-gallery__thumb', pdp).forEach(function (x) { x.classList.toggle('is-on', x === t); });
        mainImg.src = t.getAttribute('data-src');
        mainImg.setAttribute('data-full', t.getAttribute('data-full'));
      });
    });
    if (mainImg) {
      mainImg.addEventListener('click', function () {
        var d = doc.createElement('dialog');
        d.className = 'zv-lightbox';
        d.innerHTML = '<img src="' + esc(mainImg.getAttribute('data-full') || mainImg.src) + '" alt="">';
        d.style.cssText = 'border:0;padding:0;background:#fff;border-radius:24px;max-width:min(92vw,900px);max-height:92vh';
        d.addEventListener('click', function () { d.close(); d.remove(); });
        body.appendChild(d);
        if (d.showModal) d.showModal();
      });
    }
    // Sticky buy bar once the real button leaves the screen
    var sticky = qs('[data-zv-stickybuy]');
    var addBtn = qs('[data-zv-add-form]', pdp);
    if (sticky && addBtn && 'IntersectionObserver' in window) {
      sticky.hidden = false;
      new IntersectionObserver(function (en) {
        var show = !en[0].isIntersecting && en[0].boundingClientRect.top < 0;
        sticky.classList.toggle('is-on', show);
        body.classList.toggle('zv-has-sticky', show);
      }).observe(addBtn);
      qs('[data-zv-sticky-add]', sticky).addEventListener('click', function () { addBtn.click(); });
    }
  }

  /* ── Listings: facets swap in place ───────────────────────────── */
  var listing = qs('[data-zv-listing]');
  function toggleFilters(show) {
    var side = qs('.zv-listing__side');
    if (!side) return;
    side.classList.toggle('is-open', show);
    body.classList.toggle('zv-lock', show);
  }
  on('click', '[data-zv-filters-open]', function () { toggleFilters(true); });
  on('click', '[data-zv-filters-close]', function () { toggleFilters(false); });
  on('click', '[data-zv-more]', function (e, b) {
    var list = b.previousElementSibling;
    if (list) list.classList.add('is-expanded');
    b.remove();
  });
  function loadListing(url, push) {
    if (!listing) { location.href = url; return; }
    listing.classList.add('is-loading');
    fetch(url, { credentials: 'same-origin', headers: { 'X-Requested-With': 'zv' } })
      .then(function (r) { return r.text(); })
      .then(function (html) {
        var d = new DOMParser().parseFromString(html, 'text/html');
        ['facets', 'active', 'results', 'count'].forEach(function (k) {
          var src = d.querySelector('[data-zv-region="' + k + '"]');
          var dst = qs('[data-zv-region="' + k + '"]');
          if (src && dst) dst.innerHTML = src.innerHTML;
        });
        var meta = d.querySelector('.zv-listhead__meta');
        var mine = qs('.zv-listhead__meta');
        if (meta && mine) mine.innerHTML = meta.innerHTML;
        var sel = d.querySelector('[data-zv-sort] select');
        var mySel = qs('[data-zv-sort] select');
        if (sel && mySel) mySel.innerHTML = sel.innerHTML;
        if (push) history.pushState({ zv: 1 }, '', url);
        listing.classList.remove('is-loading');
        readMap();
        doc.dispatchEvent(new CustomEvent('zv:swapped', { detail: { root: qs('[data-zv-region="results"]') } }));
        if (!qs('.zv-listing__side.is-open')) {
          var top = listing.getBoundingClientRect().top + window.scrollY - 140;
          if (window.scrollY > top) window.scrollTo({ top: top, behavior: reduce ? 'auto' : 'smooth' });
        }
      })
      .catch(function () { location.href = url; });
  }
  if (listing) {
    on('click', '[data-zv-link]', function (e, a) {
      if (e.metaKey || e.ctrlKey || e.shiftKey) return;
      e.preventDefault();
      loadListing(a.href, true);
    });
    var sortSel = qs('[data-zv-sort] select');
    if (sortSel) {
      sortSel.addEventListener('change', function () {
        var o = sortSel.options[sortSel.selectedIndex];
        loadListing(o.getAttribute('data-url'), true);
      });
    }
    window.addEventListener('popstate', function () { loadListing(location.href, false); });
  }

  /* ── Home tabs ─────────────────────────────────────────────────── */
  qsa('[data-zv-tabs]').forEach(function (box) {
    var tabs = qsa('[role="tab"]', box);
    tabs.forEach(function (t) {
      t.addEventListener('click', function () {
        tabs.forEach(function (x) {
          var sel = x === t;
          x.setAttribute('aria-selected', sel ? 'true' : 'false');
          var p = doc.getElementById(x.getAttribute('aria-controls'));
          if (p) p.hidden = !sel;
        });
      });
    });
  });

  /* ── Location sheet: Google Maps only when asked ──────────────── */
  var map = null, geocoder = null, mapLoading = false, picked = null;
  var sheet = qs('[data-zv-panel="location"]');
  function status(msg, err) {
    var s = qs('[data-zv-loc-status]', sheet);
    if (s) { s.textContent = msg || ''; s.classList.toggle('is-error', !!err); }
  }
  function initMap() {
    if (!sheet) return;
    if (map) return;
    if (!Z.mapsKey) { status(T.error, true); return; }
    if (mapLoading) return;
    mapLoading = true;
    window.zvMapReady = function () {
      var la = parseFloat(Z.lat) || 0, ln = parseFloat(Z.lng) || 0;
      var c = la && ln ? { lat: la, lng: ln } : { lat: 24.7136, lng: 46.6753 };
      map = new google.maps.Map(qs('[data-zv-map-canvas]', sheet), {
        center: c, zoom: la && ln ? 16 : 12, disableDefaultUI: true, zoomControl: true, gestureHandling: 'greedy',
        clickableIcons: false,
        styles: [{ featureType: 'poi', stylers: [{ visibility: 'off' }] }, { featureType: 'transit', stylers: [{ visibility: 'off' }] }]
      });
      geocoder = new google.maps.Geocoder();
      var t = null;
      var pin = qs('.zv-locsheet__pin', sheet);
      // The pin lifts while the map moves and drops onto the spot when it settles.
      map.addListener('dragstart', function () { if (pin) { pin.classList.remove('is-drop'); pin.classList.add('is-up'); } });
      map.addListener('idle', function () {
        if (pin && pin.classList.contains('is-up')) { pin.classList.remove('is-up'); void pin.offsetWidth; pin.classList.add('is-drop'); }
        var p = map.getCenter();
        if (!p) return;
        picked = { lat: p.lat(), lng: p.lng() };
        qs('[data-zv-loc-confirm]', sheet).disabled = false;
        clearTimeout(t);
        t = setTimeout(function () {
          geocoder.geocode({ location: picked, language: Z.lang === 'en' ? 'en' : 'ar' }, function (res, st) {
            var a = qs('[data-zv-addr]', sheet);
            if (st === 'OK' && res && res[0] && a) {
              a.textContent = res[0].formatted_address.replace(/^[A-Z0-9]{4,6}\+[A-Z0-9]{2,4}[،,]?\s*/, '');
            }
          });
        }, 350);
      });
    };
    var s = doc.createElement('script');
    s.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(Z.mapsKey) + '&language=' + (Z.lang === 'en' ? 'en' : 'ar') + '&region=SA&callback=zvMapReady';
    s.async = true;
    s.onerror = function () { status(T.error, true); mapLoading = false; };
    doc.head.appendChild(s);
  }
  on('click', '[data-zv-gps]', function () {
    if (!navigator.geolocation) { status(T.gpsDenied, true); return; }
    status(T.locating);
    navigator.geolocation.getCurrentPosition(function (p) {
      status('');
      if (map) { map.setCenter({ lat: p.coords.latitude, lng: p.coords.longitude }); map.setZoom(17); }
    }, function () { status(T.gpsDenied, true); }, { enableHighAccuracy: true, timeout: 9000 });
  });
  on('click', '[data-zv-loc-confirm]', function (e, b) {
    if (!picked || !window.zooboxiData) return;
    b.disabled = true;
    status(T.saving);
    post(window.zooboxiData.ajaxUrl, { action: 'zooboxi_detect_warehouse', nonce: window.zooboxiData.nonce, lat: picked.lat, lng: picked.lng })
      .then(function (res) {
        if (res && res.success) { location.reload(); return; }
        status((res && res.data && res.data.message) || T.outOfZone, true);
        b.disabled = false;
      })
      .catch(function () { status(T.error, true); b.disabled = false; });
  });

  /* ── Missing product pictures: the sleeping cat, never a broken image ── */
  function noImage(img) {
    if (!Z.noImage || img.dataset.zvNoimg) return;
    img.dataset.zvNoimg = '1';
    img.removeAttribute('srcset');
    img.src = Z.noImage;
    img.classList.add('is-noimg');
  }
  var PICS = '.zv-card__media img, .zv-mc__img img, [data-zv-gallery-main], .zv-pdp img, .zv-suggest__item img, .zv-mega img';
  doc.addEventListener('error', function (e) {
    var t = e.target;
    if (t && t.tagName === 'IMG' && t.matches(PICS)) noImage(t);
  }, true);
  qsa(PICS).forEach(function (img) { if (img.complete && img.naturalWidth === 0 && img.getAttribute('src')) noImage(img); });
})();
