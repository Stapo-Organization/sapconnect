/* Zooboxi v2 — motion. The characters act (hop, wow, celebrate, breathe,
   lean toward the pointer), the product flies into the cart, hearts burst
   on a favourite, sections arrive as they scroll in.
   Transform and opacity only; nothing runs off-screen, in a hidden tab, or
   for anyone who asked their device for reduced motion. */
(function () {
  'use strict';
  var doc = document;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hover = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var FX = window.ZVM_FX || {};
  if (reduce || !Element.prototype.animate) return;

  function qs(s, r) { return (r || doc).querySelector(s); }
  function qsa(s, r) { return Array.prototype.slice.call((r || doc).querySelectorAll(s)); }
  function rand(a, b) { return a + Math.random() * (b - a); }
  function visible() { return doc.visibilityState === 'visible'; }
  var idle = window.requestIdleCallback || function (fn) { return setTimeout(fn, 600); };

  /* ── Characters ───────────────────────────────────────────────── */
  var chars = qsa('[data-zv-char]');

  // Extra poses load once the page is quiet (the everyday ones), or when first
  // needed (the party pose); the resting pose is already there.
  var saveData = !!(navigator.connection && navigator.connection.saveData);
  function loadPoses(el, only) {
    el._poses = el._poses || {};
    var data = {};
    try { data = JSON.parse(el.getAttribute('data-poses') || '{}'); } catch (e) {}
    var host = qs('.zv-char__breath', el);
    Object.keys(data).forEach(function (name) {
      if (el._poses[name] || (only && only.indexOf(name) < 0)) return;
      var im = new Image();
      im.className = 'zv-char__pose';
      im.alt = '';
      im.decoding = 'async';
      im.setAttribute('data-pose', name);
      im.style.setProperty('--f', data[name][1]);
      im.src = data[name][0];
      host.appendChild(im);
      el._poses[name] = im;
    });
  }
  function pose(el, name) {
    var base = qs('[data-pose="base"]', el);
    var target = name && el._poses && el._poses[name];
    if (target && !target.complete) target = null; // never flash an unloaded picture
    qsa('.zv-char__pose', el).forEach(function (p) { p.classList.toggle('is-on', p === (target || base)); });
    el.classList.toggle('has-pose', !!target);
  }
  function move(el) { return qs('.zv-char__move', el); }
  function shadow(el) { return qs('.zv-char__shadow', el); }

  /* Beats. Each returns its duration; a character does one beat at a time. */
  var beats = {
    hop: function (el, big) {
      var h = big ? -34 : -24;
      move(el).animate([
        { transform: 'translateY(0) scale(1,1)' },
        { transform: 'translateY(0) scale(1.07,.9)', offset: 0.16 },
        { transform: 'translateY(' + h + '%) scale(.95,1.06)', offset: 0.46 },
        { transform: 'translateY(0) scale(1.08,.9)', offset: 0.74 },
        { transform: 'translateY(-3%) scale(.98,1.03)', offset: 0.87 },
        { transform: 'translateY(0) scale(1,1)' }
      ], { duration: 860, easing: 'cubic-bezier(.33,.66,.4,1)' });
      var sh = shadow(el);
      if (sh) sh.animate([{ transform: 'scale(1)', opacity: 1 }, { transform: 'scale(.55)', opacity: .45, offset: .46 }, { transform: 'scale(1.08)', opacity: 1, offset: .74 }, { transform: 'scale(1)', opacity: 1 }], { duration: 860 });
      setTimeout(function () { pose(el, 'jump'); }, 140);
      setTimeout(function () { pose(el, null); }, 640);
      return 900;
    },
    wow: function (el, hold) {
      pose(el, 'wow');
      move(el).animate([{ transform: 'scale(1)' }, { transform: 'scale(1.07,.94)' }, { transform: 'scale(.98,1.03)' }, { transform: 'scale(1)' }], { duration: 420, easing: 'ease-out' });
      if (!hold) setTimeout(function () { pose(el, null); }, 1500);
      return 1600;
    },
    sway: function (el) {
      move(el).animate([{ transform: 'rotate(0)' }, { transform: 'rotate(-4deg)' }, { transform: 'rotate(3.5deg)' }, { transform: 'rotate(-2deg)' }, { transform: 'rotate(0)' }], { duration: 1100, easing: 'ease-in-out' });
      return 1150;
    },
    celebrate: function (el) {
      beats.hop(el, true);
      setTimeout(function () { pose(el, 'celebrate'); }, 650);
      setTimeout(function () { pose(el, null); }, 2100);
      var r = el.getBoundingClientRect();
      setTimeout(function () { burst(r.left + r.width / 2, r.top + r.height * 0.2, { n: 12, kinds: ['star', 'heart'], spread: 1.3 }); }, 420);
      return 2200;
    }
  };
  function act(el, name, arg) {
    if (!el || el._busy) return;
    loadPoses(el, name === 'celebrate' ? ['celebrate', 'jump'] : ['wow', 'jump']);
    el._busy = true;
    var ms = beats[name](el, arg);
    setTimeout(function () { el._busy = false; }, ms);
  }

  // Breathe only while seen.
  var liveIO = new IntersectionObserver(function (es) {
    es.forEach(function (e) { e.target.classList.toggle('is-live', e.isIntersecting); });
  }, { rootMargin: '40px' });
  chars.forEach(function (el) { liveIO.observe(el); });
  qsa('[data-zv-live]').forEach(function (el) { liveIO.observe(el); });
  if (!saveData) idle(function () { chars.forEach(function (c) { loadPoses(c, ['wow', 'jump']); }); });

  /* ── The hero stage ───────────────────────────────────────────── */
  var stage = qs('[data-zv-stage]');
  if (stage) {
    var cast = qsa('[data-zv-char]', stage);
    var byWho = {};
    cast.forEach(function (c) { byWho[c.getAttribute('data-who')] = c; });

    // A beat every few seconds, taking turns, only while the stage is on screen.
    var turn = 0;
    var tick = function () {
      setTimeout(tick, rand(4800, 7600));
      if (!visible() || !cast.length || !cast[0].classList.contains('is-live')) return;
      var el = cast[turn++ % cast.length];
      var r = Math.random();
      act(el, r < 0.45 ? 'hop' : (r < 0.75 ? 'wow' : 'sway'));
    };
    setTimeout(tick, 2600); // after the entrance has landed

    cast.forEach(function (c) {
      c.addEventListener('mouseenter', function () {
        act(c, 'hop');
        var r = c.getBoundingClientRect();
        burst(r.left + r.width / 2, r.top + r.height * 0.15, { n: 5, kinds: ['heart'] });
      });
      c.addEventListener('click', function () {
        loadPoses(c, ['celebrate']);
        var im = c._poses.celebrate;
        var go = function () { c._busy = false; act(c, 'celebrate'); };
        if (im && !im.complete) { im.addEventListener('load', go, { once: true }); } else { go(); }
      });
    });

    // The shop buttons cue their pet.
    qsa('[data-zv-cue]').forEach(function (b) {
      var who = byWho[b.getAttribute('data-zv-cue')];
      if (!who) return;
      b.addEventListener('mouseenter', function () { who._busy = false; act(who, 'wow', true); });
      b.addEventListener('mouseleave', function () { pose(who, null); });
      b.addEventListener('focus', function () { who._busy = false; act(who, 'wow', true); });
      b.addEventListener('blur', function () { pose(who, null); });
    });

    // Depth: the cast leans toward the pointer.
    if (hover) {
      var hero = stage.closest('.zv-hero__stage') || stage;
      var raf = 0;
      hero.addEventListener('pointermove', function (e) {
        if (raf) return;
        raf = requestAnimationFrame(function () {
          raf = 0;
          var r = hero.getBoundingClientRect();
          stage.style.setProperty('--px', (((e.clientX - r.left) / r.width) * 2 - 1).toFixed(3));
          stage.style.setProperty('--py', (((e.clientY - r.top) / r.height) * 2 - 1).toFixed(3));
        });
      });
      hero.addEventListener('pointerleave', function () { stage.style.setProperty('--px', 0); stage.style.setProperty('--py', 0); });
    }
  }

  /* ── «لمين تتسوّق اليوم؟» — each pet reacts in its own way ─────── */
  qsa('.zv-pet').forEach(function (a) {
    var c = qs('[data-zv-char]', a);
    if (!c) return;
    var who = c.getAttribute('data-who');
    a.addEventListener('mouseenter', function () {
      if (who === 'cat' || who === 'dog') { c._busy = false; act(c, 'wow', true); }
      else act(c, 'hop');
    });
    a.addEventListener('mouseleave', function () { pose(c, null); });
  });

  /* ── Numbers count up once seen ───────────────────────────────── */
  var countIO = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (!e.isIntersecting) return;
      countIO.unobserve(e.target);
      var el = e.target, to = parseInt(el.getAttribute('data-zv-count'), 10) || 0, sfx = el.getAttribute('data-suffix') || '';
      var t0 = performance.now(), dur = 1300;
      var step = function (now) {
        var k = Math.min(1, (now - t0) / dur), v = Math.round(to * (1 - Math.pow(1 - k, 3)));
        el.textContent = v.toLocaleString('en-US') + sfx;
        if (k < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    });
  }, { threshold: 0.6 });
  qsa('[data-zv-count]').forEach(function (el) { countIO.observe(el); });

  /* ── Particles: hearts and stars from the brand library ───────── */
  var layer = null;
  function burst(x, y, o) {
    o = o || {};
    if (!layer) { layer = doc.createElement('div'); layer.className = 'zv-fx'; layer.setAttribute('aria-hidden', 'true'); doc.body.appendChild(layer); }
    var kinds = (o.kinds || ['heart']).filter(function (k) { return FX[k]; });
    if (!kinds.length) return;
    var n = o.n || 6, spread = o.spread || 1;
    for (var i = 0; i < n; i++) {
      var im = doc.createElement('img');
      im.src = FX[kinds[i % kinds.length]];
      im.alt = '';
      var s = rand(16, 30) * (o.scale || 1);
      im.style.cssText = 'left:' + (x - s / 2) + 'px;top:' + (y - s / 2) + 'px;width:' + s + 'px';
      layer.appendChild(im);
      var ang = rand(-Math.PI * 0.95, -Math.PI * 0.05), dist = rand(40, 95) * spread;
      var dx = Math.cos(ang) * dist, dy = Math.sin(ang) * dist, rot = rand(-50, 50);
      var a = im.animate([
        { transform: 'translate(0,0) scale(.2) rotate(0)', opacity: 0 },
        { transform: 'translate(' + dx * 0.55 + 'px,' + dy * 0.55 + 'px) scale(1.05) rotate(' + rot * 0.5 + 'deg)', opacity: 1, offset: 0.35 },
        { transform: 'translate(' + dx + 'px,' + (dy + 26) + 'px) scale(.7) rotate(' + rot + 'deg)', opacity: 0 }
      ], { duration: rand(720, 1050), easing: 'cubic-bezier(.2,.7,.3,1)', delay: i * 18 });
      a.onfinish = (function (node) { return function () { node.remove(); }; })(im);
    }
  }
  window.ZVM = { act: act, burst: burst };

  /* ── Into the cart ────────────────────────────────────────────── */
  function cartTarget() {
    var list = qsa('.zv-header .zv-cartbtn, .zv-tabbar [data-zv-open="cart"]');
    for (var i = 0; i < list.length; i++) {
      var r = list[i].getBoundingClientRect();
      if (r.width && r.bottom > 0 && r.top < innerHeight) return list[i];
    }
    return list[0] || null;
  }
  function bump(el) {
    if (!el) return;
    el.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.16,.9)' }, { transform: 'scale(.94,1.06)' }, { transform: 'scale(1)' }], { duration: 480, easing: 'ease-out' });
  }
  doc.addEventListener('zv:added', function (e) {
    var img = e.detail && e.detail.img, src = e.detail && e.detail.src;
    var cart = cartTarget();
    if (!img || !src || !cart) return;
    var a = img.getBoundingClientRect(), b = cart.getBoundingClientRect();
    if (!a.width || a.bottom < 0 || a.top > innerHeight) { bump(cart); return; }
    var size = Math.min(a.width, a.height, 160);
    var fly = doc.createElement('img');
    fly.src = src; fly.alt = ''; fly.className = 'zv-fly';
    fly.style.cssText = 'left:' + (a.left + a.width / 2 - size / 2) + 'px;top:' + (a.top + a.height / 2 - size / 2) + 'px;width:' + size + 'px;height:' + size + 'px';
    doc.body.appendChild(fly);
    var x0 = 0, y0 = 0, x1 = b.left + b.width / 2 - (a.left + a.width / 2), y1 = b.top + b.height / 2 - (a.top + a.height / 2);
    var cx = x1 * 0.35, cy = Math.min(y0, y1) - 140; // arc up, then down into the bag
    var frames = [];
    for (var i = 0; i <= 16; i++) {
      var t = i / 16, k = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      var x = (1 - k) * (1 - k) * x0 + 2 * (1 - k) * k * cx + k * k * x1;
      var y = (1 - k) * (1 - k) * y0 + 2 * (1 - k) * k * cy + k * k * y1;
      var sc = 1 - k * 0.82;
      frames.push({ transform: 'translate(' + x.toFixed(1) + 'px,' + y.toFixed(1) + 'px) scale(' + sc.toFixed(3) + ') rotate(' + (k * -18).toFixed(1) + 'deg)', opacity: t > 0.92 ? 0.4 : 1 });
    }
    fly.animate(frames, { duration: 780, easing: 'linear' }).onfinish = function () {
      fly.remove();
      var c = cartTarget();
      bump(c);
      var cnt = c && qs('.zv-cart-count', c);
      if (cnt) cnt.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.45)' }, { transform: 'scale(1)' }], { duration: 380, easing: 'cubic-bezier(.3,1.6,.5,1)' });
      if (c) { var r = c.getBoundingClientRect(); burst(r.left + r.width / 2, r.top + 4, { n: 5, kinds: ['star'], scale: 0.8, spread: 0.7 }); }
    };
  });

  /* ── Free delivery reached: the cat celebrates ────────────────── */
  var wasDone = !!qs('[data-zv-meter="done"]');
  doc.addEventListener('zv:fragments', function () {
    var m = qs('.zv-mc__body [data-zv-meter]') || qs('[data-zv-meter]');
    var done = !!(m && m.getAttribute('data-zv-meter') === 'done');
    if (done && !wasDone) {
      var target = (m.offsetParent ? m : null) || cartTarget();
      setTimeout(function () {
        var r = target.getBoundingClientRect();
        burst(r.left + r.width / 2, r.top + 10, { n: 14, kinds: ['star', 'heart'], spread: 1.4 });
      }, 820);
    }
    wasDone = done;
  });

  /* ── A favourite gets a little cloud of hearts ────────────────── */
  doc.addEventListener('click', function (e) {
    var f = e.target.closest && e.target.closest('.zbx-fav');
    if (!f || f.classList.contains('is-on')) return;
    var r = f.getBoundingClientRect();
    burst(r.left + r.width / 2, r.top + r.height / 2, { n: 7, kinds: ['heart'], scale: 0.85, spread: 0.8 });
  }, true);

  /* ── Sections arrive as they scroll in ────────────────────────── */
  var SEL = '.zv-section__head, .zv-card, .zv-band, .zv-brand, .zv-pet, .zv-trust li, .zv-bundle, .zv-why, .zv-acc, .zv-rail__end, .zv-empty';
  var queue = [], flushT = 0;
  var revealIO = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (!e.isIntersecting) return;
      revealIO.unobserve(e.target);
      queue.push(e.target);
    });
    clearTimeout(flushT);
    flushT = setTimeout(function () {
      queue.sort(function (a, b) {
        var ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
        return (ra.top - rb.top) || (doc.dir === 'rtl' ? rb.left - ra.left : ra.left - rb.left);
      });
      queue.forEach(function (el, i) {
        el.style.setProperty('--rvd', Math.min(i, 8) * 55 + 'ms');
        el.classList.add('zv-in');
        setTimeout(function () { el.classList.remove('zv-rv', 'zv-in'); el.style.removeProperty('--rvd'); }, 900 + Math.min(i, 8) * 55);
      });
      queue = [];
    }, 16);
  }, { rootMargin: '0px 0px -4% 0px', threshold: 0 });
  function scan(root, force) {
    qsa(SEL, root || doc).forEach(function (el) {
      if (el.closest('.zv-mega, .zv-sheet, .zv-hero')) return;
      // What is already on screen at load stays put — no blink.
      if (!force && el.getBoundingClientRect().top < innerHeight) return;
      el.classList.add('zv-rv');
      revealIO.observe(el);
    });
  }
  scan(doc);
  doc.addEventListener('zv:swapped', function (e) { scan(e.detail && e.detail.root, true); });

  /* ── The footer cat peeks when the page ends ──────────────────── */
  var peek = qs('[data-zv-peek]');
  if (peek) {
    new IntersectionObserver(function (es) {
      es.forEach(function (e) { peek.classList.toggle('is-up', e.isIntersecting); });
    }, { threshold: 0.2 }).observe(peek.parentNode);
  }
})();
