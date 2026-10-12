// Templates: one approved E/F-series layout per FORMAT, parametrised by the campaign spec, expressed as
// role-tagged motion layers. Ad type picks the joy vocabulary and the choreography.
//   hero  1200×800  (E1)   card 1080×1080 (E2/F1)   feed 1080×1350 (E5/F2)
//   strip 1440×480  (E4)   story 1080×1920 (E3)     wide 1440×480 (= strip)
import * as B from './build.mjs';
import { L } from './motion.mjs';
const { TEAL, DEEP, CORAL, CREAM, AMBER, INK, WHITE, BALOO, TAJ } = B;

export const FORMATS = { hero: [1200, 800], card: [1080, 1080], feed: [1080, 1350], strip: [1440, 480], wide: [1440, 360], story: [1080, 1920], app_hero: [1080, 476], hero_wide: [1600, 600] };

// ---- text fitting: shrink to the column, then wrap to two lines ----
function fitSize(text, maxW, maxSize, minSize, font = BALOO) { let s = maxSize; while (s > minSize && B.est(text, s, font) > maxW) s -= 2; return s; }
function splitTwo(text) { const w = text.split(' '); if (w.length < 2) return [text]; let best = 1, bd = 1e9; for (let i = 1; i < w.length; i++) { const d = Math.abs(w.slice(0, i).join(' ').length - w.slice(i).join(' ').length); if (d < bd) { bd = d; best = i; } } return [w.slice(0, best).join(' '), w.slice(best).join(' ')]; }
function splitN(text, n) { const w = text.split(' '); if (w.length < n) return splitTwo(text); const per = Math.ceil(text.length / n); const lines = []; let cur = ''; for (const t of w) { if (cur && (cur + ' ' + t).length > per && lines.length < n - 1) { lines.push(cur); cur = t; } else cur = cur ? cur + ' ' + t : t; } if (cur) lines.push(cur); return lines; }
/** Headline block (extruded or sticker style) fitted to a column; returns { svg, h, size, lines } — y is the baseline of the first line. */
function headline(text, xr, y, maxW, maxSize, opts = {}) {
  const { fill = CREAM, ext = INK, anchor = 'end', style = 'extruded', minSize = Math.round(maxSize * 0.55) } = opts;
  let size = fitSize(text, maxW, maxSize, minSize); let lines = [text];
  if (B.est(text, size, BALOO) > maxW) { lines = splitTwo(text); size = Math.min(...lines.map((l) => fitSize(l, maxW, maxSize, Math.round(minSize * 0.8)))); }
  if (lines.some((l) => B.est(l, size, BALOO) > maxW)) { lines = splitN(text, 3); size = Math.min(...lines.map((l) => fitSize(l, maxW, maxSize, Math.round(minSize * 0.7)))); }
  const lh = size * 1.12; const out = [];
  lines.forEach((ln, i) => out.push(style === 'sticker' ? B.stickerText(ln, xr, y + i * lh, size, fill, INK, anchor) : B.extruded(ln, xr, y + i * lh, size, fill, null, ext, anchor)));
  return { svg: out.join(''), h: lh * lines.length, size, lines: lines.length };
}
function clipWords(text, maxW, size, font = TAJ) { const w = text.split(' '); while (w.length > 1 && B.est(w.join(' '), size, font) > maxW) w.pop(); return w.join(' '); }
function fitTaj(text, xr, y, maxW, maxSize, color, weight = 800, anchor = 'end') { const s = fitSize(text, maxW, maxSize, Math.round(maxSize * 0.7), TAJ); return { svg: B.txt(clipWords(text, maxW, s), xr, y, s, color, weight, anchor), size: s }; }

// ---- product presentation: cut-out (shadow + tilt) or photo on a plate ----
function product(name, cx, bottom, w, rot = 0, role = 'product') {
  const a = B.asset(name); const h = B.contentH(name, w);
  if (a.opaque) return L(role, B.plate(name, cx, bottom, w, rot), cx, bottom - h / 2);
  return L(role, B.softShadow(cx, bottom + 6, w * 0.5, w * 0.08, 0.45, 14) + B.img(name, { cx, bottom, w, rot }), cx, bottom - h / 2);
}
function character(name, cx, bottom, w, rot = 0, flip = false, maxH = null) {
  let h = B.contentH(name, w); if (maxH && h > maxH) { w = B.contentW(name, maxH); h = maxH; }
  return L('character', B.softShadow(cx, bottom - 8, w * 0.42, w * 0.06, 0.4, 14) + B.img(name, { cx, bottom, w, rot, flip }), cx, bottom - h / 2);
}
function stick(name, cx, cy, w, rot = 0) { return L('sticker', B.stickerPng(name, cx, cy, w, rot), cx, cy); }
const sat = (hex) => { const [r, g, b] = B.hex2rgb(hex).map((v) => v / 255); const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const l = (mx + mn) / 2; return mx === mn ? 0 : (mx - mn) / (l > 0.5 ? 2 - mx - mn : mx + mn); };
const dark = (hex) => { const [r, g, b] = B.hex2rgb(hex); return (r * 299 + g * 587 + b * 114) / 1000 < 150; };

/** Palette: from the spec (brand kit) else from the hero product's dominant colour. */
function palette(spec, heroName) {
  const c = spec.colors || {}; let c1 = c.c1, c2 = c.c2;
  if (!c1) { let dom = heroName ? B.dominant(heroName) : TEAL; if (sat(dom) < 0.42) dom = TEAL; dom = B.shade(dom, 0, 0.12); c1 = B.shade(dom, 0.06); c2 = B.shade(dom, -0.22, -0.05); }
  c2 = c2 || B.shade(c1, -0.22); const onDark = dark(c2);
  return { c1, c2, text: onDark ? CREAM : INK, accent: c.accent || (onDark ? AMBER : CORAL), glowC: heroName ? B.shade(B.dominant(heroName), 0.25) : CREAM, onDark };
}
const joy = (t) => ['offer', 'party', 'pair', 'carton'].includes(t);
const popNames = (spec) => (spec.pop_names && spec.pop_names.length ? spec.pop_names : []);
const has = (n) => n && B.hasAsset(n);

// =============================== hero 3:2 (E1) ===============================
function hero(spec) {
  const [W, H] = FORMATS.hero; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec);
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 380, 300, 900) + (hp ? B.glow(330, 470, 420, pal.glowC, 0.5) : '') + B.blob(330, 470, 330, CREAM, 0.1, 3), W / 2, H / 2)];
  const second = spec.products[1];
  if (ch && has(ch)) Ls.push(character(ch, second ? 700 : 600, 690, 250, 0, false, second ? 210 : 250));
  if (second && has(second.name)) Ls.push(product(second.name, 560, 790, 290, 8));
  if (hp) Ls.push(product(hp.name, 330, 840, 520, -8));
  if (cp.badge1) Ls.push(L('badge', B.badge(600, 165, 68, cp.badge1, cp.badge2 || null, pal.accent, INK, 12), 600, 165));
  if (joy(spec.ad_type) && pop.length) { Ls.push(stick(pop[0], 80, 150, 90, -12)); if (pop[1]) Ls.push(stick(pop[1], 640, 330, 70, 10)); }
  else Ls.push(L('sticker', B.sparkle(80, 150, 16, CREAM) + B.sparkle(640, 330, 10, AMBER), 360, 240));
  Ls.push(L('logo', B.logo(1150, 28, 110), 1095, 75));
  // right column flow: kicker → sub → headline → price → cta, scaled to fit between y=150 and the trust row
  for (let k = 1.0; k >= 0.6; k -= 0.08) {
    const col = []; let y = 150; const kS = Math.round(19 * k), sS = Math.round(46 * k), hS = Math.round(104 * k), pS = Math.round(108 * k), cS = Math.round(24 * k);
    if (cp.kicker) { col.push(L('kicker', B.kicker(cp.kicker, 1140, y, kS, pal.accent, INK), 1140 - B.kickerWidth(cp.kicker, kS) / 2, y + kS * 0.9)); y += kS * 1.75 + 28; }
    const hd = headline(cp.headline, 1140, y + hS * 0.8, 540, hS, { fill: pal.accent, ext: pal.onDark ? INK : CREAM }); col.push(L('headline', hd.svg, 880, y + hd.h / 2)); y += hd.h + 6;
    if (cp.sub) { const sv = fitTaj(cp.sub, 1140, y + sS * 0.9, 520, Math.round(sS * 0.8), pal.text); col.push(L('sub', sv.svg, 900, y + sS * 0.5)); y += sS * 0.9 + 22; }
    if (spec.price) { col.push(L('price', B.price(1140, y + pS * 0.85, spec.price.amount, pS, pal.text, spec.price.label, spec.price.old), 950, y + pS * 0.6)); y += pS * (spec.price.label ? 1.35 : 1.0) + 14; }
    if (cp.cta) { col.push(L('cta', B.cta(cp.cta, 1140, y, cS, pal.onDark ? CORAL : INK, pal.onDark ? WHITE : CREAM, INK), 1140 - B.ctaWidth(cp.cta, cS) / 2, y + cS * 1.2)); y += cS * 2.4 + 10; }
    if (y <= (cp.trust?.length ? 668 : 760) || k < 0.65) { Ls.push(...col); break; }
  }
  if (cp.trust?.length) Ls.push(L('trust', B.trust(cp.trust, 1140, 700, 19, pal.text), 900, 700));
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== card 1:1 (E2 / F1) ===============================
function cardT(spec) {
  const [W, H] = FORMATS.card; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec); const t = spec.ad_type;
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 540, 640, 820) + (hp ? B.glow(600, 700, 420, pal.glowC, 0.45) : '') + (joy(t) ? B.bokeh(W, H, 12, 3, CREAM, [560, 760, 300], 12, 50) : B.blob(560, 720, 360, CREAM, 0.1, 5)), W / 2, H / 2)];
  Ls.push(L('logo', B.logo(190, 36, 150) + (cp.trust?.length ? B.trust(cp.trust.slice(0, 1), 1030, 990, 19, pal.text) : ''), 115, 100));
  const hd = headline(cp.headline, 1020, 250, 560, 150, { fill: pal.text, ext: B.shade(pal.c2, -0.15) }); Ls.push(L('headline', hd.svg, 800, 200));
  let y = 250 + hd.size * 0.63 + (hd.lines - 1) * hd.size * 1.12;
  if (cp.sub) { const sz = fitSize(cp.sub, 560, 62, 36); Ls.push(L('sub', B.stickerText(cp.sub, 1020, y, sz, pal.accent), 800, y - sz * 0.35)); y += sz; }
  if (hp) { const second = spec.products[1]; if (second && has(second.name)) { Ls.push(product(hp.name, 330, 950, 300, 6)); Ls.push(product(second.name, 620, 975, 370, -6)); }
    else if ((hp.count || 1) > 1) { Ls.push(product(hp.name, 330, 950, 300, 6)); Ls.push(product(hp.name, 620, 975, 370, -6)); }
    else Ls.push(product(hp.name, 560, 990, 430, -6)); }
  if (ch && has(ch)) Ls.push(character(ch, 230, 1070, 290));
  if (cp.badge1) { if (joy(t)) Ls.push(L('burst', B.burstLines(900, 560, 120, 210, 12, CREAM, 10, 0.8, 4), 900, 560)); Ls.push(L('badge', B.badge(900, 560, cp.badge2 ? 118 : 92, cp.badge1, cp.badge2 || null, pal.accent, INK, -10), 900, 560)); }
  if (joy(t) && pop.length) { Ls.push(stick(pop[0], 170, 300, 140, -12)); if (pop[1]) Ls.push(stick(pop[1], 120, 520, 100, 14)); Ls.push(L('confetti', B.confettiDepth(W, H, 36, spec.seed, null, [620, 760, 330], [0, 380, 1080, 1080]), 540, 700)); }
  if (spec.price) Ls.push(L('price', B.price(1030, 810, spec.price.amount, 76, pal.text, spec.price.label, spec.price.old), 900, 790));
  if (cp.cta) Ls.push(L('cta', B.cta(cp.cta, 1030, spec.price ? 860 : 890, 26, pal.onDark ? INK : CORAL, pal.onDark ? CREAM : WHITE, INK), 1030 - B.ctaWidth(cp.cta, 26) / 2, (spec.price ? 860 : 890) + 31));
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== feed 4:5 (E5 / F2) ===============================
function feed(spec) {
  const [W, H] = FORMATS.feed; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec); const t = spec.ad_type;
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 420, 800, 900) + B.bokeh(W, H, 16, 6, CREAM, [420, 950, 260], 12, 56), W / 2, H / 2), L('glow', B.glow(400, 900, 480, pal.onDark ? AMBER : CREAM, 0.45), 400, 900)];
  if (joy(t)) Ls.push(L('rays', B.glowRays(400, 1000, 520, pal.onDark ? AMBER : CREAM, 18, 0.4, 0.5), 400, 1000));
  Ls.push(L('logo', B.logo(1030, 40, 140) + (cp.trust?.length ? B.trust(cp.trust, 1020, 1290, 18, pal.text) : ''), 960, 100));
  let y = 190; if (cp.kicker) { Ls.push(L('kicker', B.kicker(cp.kicker, 1020, y, 20, pal.accent, INK), 1020 - B.kickerWidth(cp.kicker, 20) / 2, y + 17)); y += 60; }
  const hd = headline(cp.headline, 1020, y + 120, 560, 150, { fill: pal.accent, ext: B.shade(pal.c2, -0.15) }); Ls.push(L('headline', hd.svg, 820, y + 60)); y += hd.h + 60;
  if (cp.sub) { const sz = fitSize(cp.sub, 560, 58, 34); Ls.push(L('sub', B.stickerText(cp.sub, 1020, y + 40, sz, pal.text), 830, y + 20)); y += 80; }
  if (joy(t) && pop.includes('confetti-burst')) Ls.push(L('burst', B.stickerPng('confetti-burst', 400, 700, 640, 0, false, 0.95), 400, 700, { preset: 'pop' }));
  if (hp) { const n = hp.count || 1; if (n >= 6 && !B.asset(hp.name).opaque) { const rows = n >= 10 ? [4, 3, 2, 1] : [3, 2, 1]; const w = n >= 10 ? 130 : 150; Ls.push(L('product', B.softShadow(400, 1140, 300, 30, 0.5, 18) + B.pyramid(hp.name, rows, 400, 1135, w, 8), 400, 960, { dist: 520 })); }
    else if (n >= 2 && !B.asset(hp.name).opaque) Ls.push(L('product', B.stack(hp.name, Math.min(3, n), n > 3 ? Math.min(3, n - 3) : 0, 400, 1135, 200), 400, 980, { dist: 520 }));
    else Ls.push(product(hp.name, 400, 1150, 520, -6)); }
  if (ch && has(ch)) Ls.push(character(ch, 820, 1090, 290));
  if (joy(t) && pop.length) { const s = pop.filter((p) => p !== 'confetti-burst'); if (s[0]) Ls.push(stick(s[0], 900, 1180, 160, -8)); if (s[1]) Ls.push(stick(s[1], 140, 560, 170, 10)); Ls.push(L('confetti', B.confettiDepth(W, H, 44, spec.seed, null, [420, 950, 300], [0, 460, 1080, 1250]), 540, 850)); }
  if (spec.price) { Ls.push(L('price', B.price(1020, Math.max(y + 60, 640), spec.price.amount, 82, pal.text, spec.price.label, spec.price.old), 840, Math.max(y + 60, 640))); y = Math.max(y + 60, 640) + 40; }
  if (cp.cta) { const cy = Math.max(y + 20, 720); Ls.push(L('cta', B.cta(cp.cta, 1020, cy, 24, pal.onDark ? CREAM : CORAL, pal.onDark ? INK : WHITE, INK), 1020 - B.ctaWidth(cp.cta, 24) / 2, cy + 29)); }
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== strip 3:1 (E4) ===============================
function strip(spec) {
  const [W, H] = FORMATS.strip; const hp = spec.products[0]; const cp = spec.copy; const ch = spec.character; const c = spec.colors || {};
  const light = !c.c1 || !dark(c.c2 || c.c1); const c1 = c.c1 || '#FBF3E6', c2 = c.c2 || '#F6DDB0'; const text = light ? INK : CREAM; const accent = c.accent || (light ? CORAL : AMBER);
  const Ls = [L('bg', B.bgLinear(W, H, c1, c2, 0) + (hp ? B.glow(220, 280, 330, B.shade(B.dominant(hp.name), 0.2), 0.45) : ''), W / 2, H / 2)];
  if (hp) Ls.push(product(hp.name, 230, 505, 430, -6));
  if (ch && has(ch)) { Ls.push(L('rays', B.speedLines(760, 300, 4, 150, 24, accent, 0.7), 760, 340, { preset: 'static' })); Ls.push(character(ch, 610, 478, 330)); }
  if (cp.badge1) Ls.push(L('badge', B.badge(960, 120, 66, cp.badge1, cp.badge2 || null, TEAL, CREAM, -10, true, cp.badge2 ? 52 : 40, 22), 960, 120));
  Ls.push(L('logo', B.logo(1400, 22, 100), 1350, 65));
  let y = 130; if (cp.kicker) { Ls.push(L('kicker', B.kicker(cp.kicker, 1400, y, 18, TEAL, WHITE), 1400 - B.kickerWidth(cp.kicker, 18) / 2, y + 16)); y += 50; }
  const hd = headline(cp.headline, 1400, y + 70, 560, 66, { fill: text, ext: accent }); Ls.push(L('headline', hd.svg, 1120, y + 40)); y += hd.h + 20;
  if (cp.sub) { const s = fitTaj(cp.sub, 1400, y + 30, 560, 24, accent); Ls.push(L('sub', s.svg, 1120, y + 20)); y += 40; }
  if (spec.price) { Ls.push(L('price', B.price(1400, y + 60, spec.price.amount, 56, text, spec.price.label, spec.price.old), 1250, y + 40)); }
  if (cp.cta) { const cx = spec.price ? 1120 : 1400; Ls.push(L('cta', B.cta(cp.cta, cx, y + 10, 22, light ? CORAL : CREAM, light ? WHITE : INK, INK), cx - B.ctaWidth(cp.cta, 22) / 2, y + 36)); }
  if (cp.trust?.length) Ls.push(L('trust', B.trust(cp.trust, 1400, 435, 17, text), 1200, 435));
  return { Ls, W, H, bg: c1 };
}

// =============================== story 9:16 (E3) ===============================
function story(spec) {
  const [W, H] = FORMATS.story; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec); const t = spec.ad_type;
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 540, 1050, 1250) + (hp ? B.glow(560, 1000, 620, pal.glowC, 0.5) : ''), W / 2, H / 2)];
  Ls.push(L('logo', B.logo(190, 60, 150), 115, 130));
  let y = 330; if (cp.kicker) { Ls.push(L('kicker', B.kicker(cp.kicker, 1020, 140, 24, pal.accent, INK), 1020 - B.kickerWidth(cp.kicker, 24) / 2, 161)); }
  const hd = headline(cp.headline, 1020, y, 700, 150, { fill: pal.text, style: 'sticker' }); Ls.push(L('headline', hd.svg, 700, y - hd.size * 0.35)); y += hd.size * 0.66 + (hd.lines - 1) * hd.size * 1.12;
  if (cp.sub) { const sz = fitSize(cp.sub, 700, 92, 48); Ls.push(L('sub', B.extruded(cp.sub, 1020, y + sz * 0.3, sz, pal.accent, 8), 720, y)); }
  if (joy(t) && pop.length) Ls.push(L('confetti', B.confettiDepth(W, H, 50, spec.seed, null, [560, 1200, 420], [0, 520, 1080, 1650]), 540, 1100));
  if (hp) Ls.push(product(hp.name, 560, 1580, 640, -5));
  if (ch && has(ch)) Ls.push(character(ch, 300, 1610, 430));
  if (joy(t) && pop.length) { Ls.push(stick(pop[0], 900, 700, 170, 12)); if (pop[1]) Ls.push(stick(pop[1], 150, 900, 130, -10)); }
  if (cp.badge1) Ls.push(L('badge', B.badge(880, 1000, 110, cp.badge1, cp.badge2 || null, pal.accent, INK, -12), 880, 1000));
  Ls.push(L('sub', B.card(60, 1650, 960, 210, CREAM, 36), 540, 1755, { preset: 'rise', dist: 300 }));
  if (spec.price) Ls.push(L('price', B.price(980, 1770, spec.price.amount, 96, INK, spec.price.label, spec.price.old), 830, 1740));
  if (cp.cta) { const xr = spec.price ? 420 : 760; Ls.push(L('cta', B.cta(cp.cta, xr, 1705, 26), xr - B.ctaWidth(cp.cta, 26) / 2, 1736)); }
  if (cp.trust?.length) Ls.push(L('trust', B.trust(cp.trust, spec.price ? 420 : 980, 1815, 18, INK), 300, 1815));
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== app hero plate 1080×476 (≈2.27:1, the app's hero plate) ===============================
// Finished creative for the app's hero slot: product bleeding off the start edge, the character
// peeking beside it, one short headline, one support line, price or CTA. No logo (the app header
// already carries the brand), no duplicated copy (the app draws nothing over it).
function appHero(spec) {
  const [W, H] = FORMATS.app_hero; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec); const t = spec.ad_type;
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 300, 240, 700) + (hp ? B.glow(280, 300, 300, pal.glowC, 0.5) : '') + B.blob(280, 300, 240, CREAM, 0.1, 3), W / 2, H / 2)];
  if (joy(t) && pop.length) Ls.push(L('confetti', B.confettiDepth(W, H, 22, spec.seed, null, [280, 300, 260], [0, 0, 620, H]), 300, 240));
  const second = spec.products[1];
  if (second && has(second.name)) Ls.push(product(second.name, 500, 500, 230, 8));
  else if (ch && has(ch)) Ls.push(character(ch, 470, 476, 200, 0, false, 230));
  if (hp) Ls.push(product(hp.name, 270, 520, 400, -7));
  if (joy(t) && pop.length) Ls.push(stick(pop[0], 590, 70, 80, -12));
  const xr = 1030; const colW = 470; let y = 48;
  if (cp.badge1 || cp.kicker) { const k = cp.badge1 || cp.kicker; Ls.push(L('kicker', B.kicker(k, xr, y, 20, pal.accent, INK), xr - B.kickerWidth(k, 20) / 2, y + 18)); y += 62; }
  const hd = headline(cp.headline, xr, y + 58, colW, 72, { fill: pal.text, ext: B.shade(pal.c2, -0.15), minSize: 44 }); Ls.push(L('headline', hd.svg, xr - colW / 2, y + hd.h / 2)); y += hd.h + 14;
  if (cp.sub) { const sv = fitTaj(cp.sub, xr, y + 26, colW, 28, pal.accent); Ls.push(L('sub', sv.svg, xr - colW / 2, y + 14)); y += 46; }
  const rowY = Math.max(y + 6, H - 118);
  if (spec.price) Ls.push(L('price', B.price(xr, rowY + 62, spec.price.amount, 68, pal.text, null, spec.price.old), xr - 120, rowY + 40));
  if (cp.cta) { const cx = spec.price ? xr - 340 : xr; Ls.push(L('cta', B.cta(cp.cta, cx, rowY + 14, 22, pal.onDark ? CORAL : INK, pal.onDark ? WHITE : CREAM, INK), cx - B.ctaWidth(cp.cta, 22) / 2, rowY + 40)); }
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== wide 4:1 in-feed banner 1440×360 ===============================
function wide(spec) {
  const [W, H] = FORMATS.wide; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const t = spec.ad_type;
  const Ls = [L('bg', B.bgLinear(W, H, pal.c1, pal.c2, 0) + (hp ? B.glow(230, 200, 260, pal.glowC, 0.45) : ''), W / 2, H / 2)];
  if (hp) Ls.push(product(hp.name, 220, 390, 330, -6));
  if (ch && has(ch)) Ls.push(character(ch, 520, 362, 240, 0, false, 230));
  if (cp.badge1) Ls.push(L('badge', B.badge(720, 90, 58, cp.badge1, cp.badge2 || null, pal.accent, INK, -10), 720, 90));
  const xr = 1390; const colW = 600; let y = 60;
  if (cp.kicker) { Ls.push(L('kicker', B.kicker(cp.kicker, xr, y - 24, 18, pal.accent, INK), xr - B.kickerWidth(cp.kicker, 18) / 2, y - 8)); y += 40; }
  const hd = headline(cp.headline, xr, y + 56, colW, 64, { fill: pal.text, ext: B.shade(pal.c2, -0.15), minSize: 40 }); Ls.push(L('headline', hd.svg, xr - colW / 2, y + hd.h / 2)); y += hd.h + 10;
  if (cp.sub) { const sv = fitTaj(cp.sub, xr, y + 24, colW, 24, pal.accent); Ls.push(L('sub', sv.svg, xr - colW / 2, y + 12)); y += 36; }
  const rowY = Math.max(y + 4, H - 92);
  if (spec.price) Ls.push(L('price', B.price(xr, rowY + 50, spec.price.amount, 56, pal.text, null, spec.price.old), xr - 100, rowY + 30));
  if (cp.cta) { const cx = spec.price ? xr - 260 : xr; Ls.push(L('cta', B.cta(cp.cta, cx, rowY + 8, 20, pal.onDark ? CORAL : INK, pal.onDark ? WHITE : CREAM, INK), cx - B.ctaWidth(cp.cta, 20) / 2, rowY + 32)); }
  return { Ls, W, H, bg: pal.c2 };
}

// =============================== store hero 1600×600 (8:3, the desktop slider slot) ===============================
// Same layer model as the 3:2 hero, laid out for the wide slot: product bleeding off the start edge,
// companion/character in the middle, the text column on the end side, logo top-end.
function heroWide(spec) {
  const [W, H] = FORMATS.hero_wide; const hp = spec.products[0]; const pal = palette(spec, hp?.name); const cp = spec.copy; const ch = spec.character; const pop = popNames(spec); const t = spec.ad_type;
  const Ls = [L('bg', B.bgRadial(W, H, pal.c1, pal.c2, 420, 260, 1000) + (hp ? B.glow(380, 340, 380, pal.glowC, 0.5) : '') + B.blob(380, 340, 300, CREAM, 0.1, 3), W / 2, H / 2)];
  if (joy(t) && pop.length) Ls.push(L('confetti', B.confettiDepth(W, H, 30, spec.seed, null, [380, 340, 320], [0, 0, 900, H]), 450, 300));
  const second = spec.products[1];
  if (ch && has(ch)) Ls.push(character(ch, second ? 860 : 720, 600, 260, 0, false, second ? 230 : 280));
  if (second && has(second.name)) Ls.push(product(second.name, 680, 590, 300, 8));
  if (hp) Ls.push(product(hp.name, 380, 640, 500, -7));
  if (cp.badge1) Ls.push(L('badge', B.badge(720, 120, 64, cp.badge1, cp.badge2 || null, pal.accent, INK, 12), 720, 120));
  if (joy(t) && pop.length) { Ls.push(stick(pop[0], 90, 110, 100, -12)); if (pop[1]) Ls.push(stick(pop[1], 940, 470, 80, 10)); }
  else Ls.push(L('sticker', B.sparkle(90, 110, 16, CREAM) + B.sparkle(940, 470, 10, AMBER), 500, 300));
  Ls.push(L('logo', B.logo(1560, 24, 110), 1505, 70));
  const xr = 1540; const colW = 560;
  for (let k = 1.0; k >= 0.6; k -= 0.08) {
    const col = []; let y = 140; const kS = Math.round(19 * k), sS = Math.round(34 * k), hS = Math.round(96 * k), pS = Math.round(92 * k), cS = Math.round(24 * k);
    if (cp.kicker) { col.push(L('kicker', B.kicker(cp.kicker, xr, y, kS, pal.accent, INK), xr - B.kickerWidth(cp.kicker, kS) / 2, y + kS * 0.9)); y += kS * 1.75 + 22; }
    const hd = headline(cp.headline, xr, y + hS * 0.8, colW, hS, { fill: pal.accent, ext: pal.onDark ? INK : CREAM }); col.push(L('headline', hd.svg, xr - colW / 2, y + hd.h / 2)); y += hd.h + 4;
    if (cp.sub) { const sv = fitTaj(cp.sub, xr, y + sS, colW, sS, pal.text); col.push(L('sub', sv.svg, xr - colW / 2, y + sS * 0.6)); y += sS + 18; }
    if (spec.price) { col.push(L('price', B.price(xr, y + pS * 0.85, spec.price.amount, pS, pal.text, spec.price.label, spec.price.old), xr - 190, y + pS * 0.6)); y += pS * (spec.price.label ? 1.3 : 0.95) + 12; }
    if (cp.cta) { col.push(L('cta', B.cta(cp.cta, xr, y, cS, pal.onDark ? CORAL : INK, pal.onDark ? WHITE : CREAM, INK), xr - B.ctaWidth(cp.cta, cS) / 2, y + cS * 1.2)); y += cS * 2.4 + 8; }
    if (y <= (cp.trust?.length ? 500 : 570) || k < 0.65) { Ls.push(...col); break; }
  }
  if (cp.trust?.length) Ls.push(L('trust', B.trust(cp.trust, xr, 540, 18, pal.text), 1300, 540));
  return { Ls, W, H, bg: pal.c2 };
}

export function build(spec) {
  const f = spec.format;
  const fn = { hero, card: cardT, feed, strip, story, wide, app_hero: appHero, hero_wide: heroWide }[f]; if (!fn) throw new Error('unknown format ' + spec.format);
  return fn(spec);
}
