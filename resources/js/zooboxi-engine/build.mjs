// Zooboxi zero-cost ad compositor — SVG primitives (Node port of the approved scratchpad build.py).
// Brand layer + real product cut-outs + one-time character/sticker library → SVG string.
// Text rule: every line is wrapped in RLM marks so resvg lays it out as a true RTL paragraph;
// "%" becomes "٪"; the riyal sign U+FDFC is merged into the bundled fonts.
import { stats } from './png.mjs';
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';

export const TEAL = '#429D9C', DEEP = '#2C7B7A', CORAL = '#E35F3A', CREAM = '#FBF3E6', AMBER = '#E9B36A', INK = '#5A2C2F', WHITE = '#ffffff';
export const BALOO = 'Baloo Bhaijaan 2', TAJ = 'Tajawal';

// ---------- assets ----------
// Asset registry: name → absolute png path (filled by the CLI from the spec). Stats cached beside the assets dir.
const registry = new Map(); let cacheFile = null; let cache = {};
export function registerAssetDir(dir, names) {
  for (const n of names) registry.set(n, join(dir, n + '.png'));
}
export function registerAsset(name, file) { registry.set(name, file); }
export function setCache(file) { cacheFile = file; cache = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {}; }
export function asset(name) {
  const f = registry.get(name);
  if (!f || !existsSync(f)) throw new Error('missing asset: ' + name);
  const m = statSync(f).mtimeMs;
  if (!cache[f] || cache[f].mtime !== m) { cache[f] = { ...stats(f), mtime: m }; if (cacheFile) writeFileSync(cacheFile, JSON.stringify(cache)); }
  return { ...cache[f], file: f };
}
export function hasAsset(name) { const f = registry.get(name); return !!f && existsSync(f); }
export function dominant(name) { return asset(name).dom || TEAL; }

// ---------- text ----------
const r0 = (v) => Math.round(v).toString();
export function est(text, size, font = TAJ) {
  const k = font === BALOO ? 0.62 : 0.56; let w = 0;
  for (const ch of text) {
    if (ch === ' ') w += 0.26;
    else if (/\d/.test(ch)) w += 0.56;
    else if ('+%'.includes(ch)) w += 0.6;
    else if (ch === '' || ch === '﷼') w += 0.9;
    else if (ch === 'ـ') w += 0.4;
    else if ('اأإآدذرزوؤ'.includes(ch)) w += 0.32;
    else if (ch === 'ل') w += 0.38;
    else w += k;
  }
  return w * size;
}
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
export function rtxt(text) { return '&#x200F;' + esc(String(text).replace(/%/g, '٪')) + '&#x200F;'; }
export function txt(text, x, y, size, color = CREAM, weight = 800, anchor = 'end', font = TAJ, extra = '') {
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${font}" font-weight="${weight}" font-size="${size}" fill="${color}" ${extra}>${rtxt(text)}</text>`;
}
export function pill(text, xr, yt, size = 18, bg = CREAM, fg = DEEP, pad = null, font = TAJ, weight = 800) {
  pad = pad ?? size * 0.9; const w = est(text, size, font) + 2 * pad, h = size * 1.75; const cx = xr - w / 2;
  return `<rect x="${r0(xr - w)}" y="${yt}" width="${r0(w)}" height="${r0(h)}" rx="${r0(h / 2)}" fill="${bg}"/>` + txt(text, r0(cx), r0(yt + h * 0.66), size, fg, weight, 'middle', font);
}
export function cta(text, xr, yt, size = 22, bg = CORAL, fg = WHITE, stroke = INK, pad = null) {
  pad = pad ?? size * 1.35; const w = est(text, size) + 2 * pad, h = size * 2.4;
  return `<rect x="${r0(xr - w)}" y="${yt + 6}" width="${r0(w)}" height="${r0(h)}" rx="${r0(h / 2)}" fill="${stroke}"/>`
    + `<rect x="${r0(xr - w)}" y="${yt}" width="${r0(w)}" height="${r0(h)}" rx="${r0(h / 2)}" fill="${bg}" stroke="${stroke}" stroke-width="4"/>`
    + txt(text, r0(xr - w / 2), r0(yt + h * 0.64), size, fg, 800, 'middle');
}
export function ctaC(text, cx, yt, size = 24, bg = CORAL, fg = WHITE, stroke = INK) { const w = est(text, size) + size * 2.7; return cta(text, cx + w / 2, yt, size, bg, fg, stroke); }
export function ctaWidth(text, size = 22) { return est(text, size) + 2 * size * 1.35; }
export function kicker(text, xr, y, size = 20, fill = AMBER, fg = INK) { return pill(text, xr, y, size, fill, fg, size * 1.1, TAJ, 800); }
export function kickerWidth(text, size = 20) { return est(text, size) + 2 * size * 1.1; }

// ---------- images ----------
export function img(name, { x = null, y = null, w = null, h = null, cx = null, bottom = null, flip = false, rot = 0, shadow = true, opacity = 1 } = {}) {
  const a = asset(name); const [x0, y0, x1, y1] = a.bbox; const cw = x1 - x0, ch = y1 - y0;
  const s = w ? w / cw : h / ch; const W = a.w * s, H = a.h * s, vw = cw * s, vh = ch * s;
  if (cx !== null) x = cx - vw / 2; if (bottom !== null) y = bottom - vh;
  const ix = x - x0 * s, iy = y - y0 * s, ccx = x + vw / 2, ccy = y + vh / 2; const tf = [];
  if (rot) tf.push(`rotate(${rot} ${r0(ccx)} ${r0(ccy)})`); if (flip) tf.push(`translate(${r0(2 * ccx)} 0) scale(-1 1)`);
  const t = tf.length ? ` transform="${tf.join(' ')}"` : ''; const f = shadow ? ' filter="url(#ds)"' : ''; const o = opacity !== 1 ? ` opacity="${opacity}"` : '';
  return `<image href="{{${name}}}" x="${r0(ix)}" y="${r0(iy)}" width="${r0(W)}" height="${r0(H)}"${t}${f}${o}/>`;
}
export function contentH(name, w) { const a = asset(name); const [x0, y0, x1, y1] = a.bbox; return (y1 - y0) * w / (x1 - x0); }
export function contentW(name, h) { const a = asset(name); const [x0, y0, x1, y1] = a.bbox; return (x1 - x0) * h / (y1 - y0); }
export function logo(xr, y, w) { return img('logo', { x: xr - w, y, w, shadow: false }); }
export function floorShadow(cx, cy, rx, ry, opacity = 0.22) { return `<ellipse cx="${cx}" cy="${cy}" rx="${r0(rx)}" ry="${r0(ry)}" fill="${INK}" opacity="${opacity}"/>`; }
export function pyramid(name, rows, cx, bottom, w, gap = null) {
  gap = gap ?? w * 0.04; const out = []; const h = contentH(name, w); let y = bottom;
  for (const n of rows) { const tot = n * w + (n - 1) * gap; const x = cx - tot / 2; for (let i = 0; i < n; i++) out.push(img(name, { cx: x + w / 2 + i * (w + gap), bottom: y, w })); y -= h * 0.9; }
  return out.join('');
}
export function stack(name, nFront, nBack, cx, bottom, w, gap = null, backScale = 0.9, backRaise = null) {
  gap = gap ?? w * 0.08; const out = []; const wb = w * backScale; const br = backRaise ?? w * 0.22;
  if (nBack) { const tot = nBack * wb + (nBack - 1) * gap; const x = cx - tot / 2 + (nBack === nFront ? (w + gap) / 2 : 0);
    for (let i = 0; i < nBack; i++) { const c = x + wb / 2 + i * (wb + gap); out.push(floorShadow(r0(c), r0(bottom - br + 4), wb * 0.5, wb * 0.09, 0.16)); out.push(img(name, { cx: c, bottom: bottom - br, w: wb })); } }
  const tot = nFront * w + (nFront - 1) * gap; const x = cx - tot / 2;
  for (let i = 0; i < nFront; i++) { const c = x + w / 2 + i * (w + gap); out.push(floorShadow(r0(c), r0(bottom + 6), w * 0.52, w * 0.1, 0.2)); out.push(img(name, { cx: c, bottom, w })); }
  return out.join('');
}

// ---------- board ----------
export const DEFS = '<defs><filter id="ds" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#5A2C2F" flood-opacity="0.28"/></filter>'
  + '<filter id="soft" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#5A2C2F" flood-opacity="0.18"/></filter></defs>';
export function board(W, H, bg, parts, radius = 0) {
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}<rect width="${W}" height="${H}" fill="${bg}" rx="${radius}"/>${parts.join('')}</svg>`;
}
/** Replace {{asset}} references with data URIs (local render) — the store/app never see them: they get PNG/WebP. */
export function substitute(svg) {
  return svg.replace(/\{\{([\w\-]+)\}\}/g, (m, n) => 'data:image/png;base64,' + readFileSync(asset(n).file).toString('base64'));
}

// ---------- colour ----------
let _uid = 0; export function uid(p = 'g') { return p + (++_uid); }
export function resetUid() { _uid = 0; }
export function hex2rgb(h) { h = h.replace('#', ''); return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)); }
export function rgb2hex(r, g, b) { const c = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0').toUpperCase(); return '#' + c(r) + c(g) + c(b); }
function rgb2hls(r, g, b) {
  r /= 255; g /= 255; b /= 255; const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const l = (mx + mn) / 2; let h = 0, s = 0;
  if (mx !== mn) { const d = mx - mn; s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn); h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; h /= 6; }
  return [h, l, s];
}
function hls2rgb(h, l, s) {
  if (s === 0) return [l * 255, l * 255, l * 255];
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  const f = (t) => { t = (t + 1) % 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6; return p; };
  return [f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255];
}
export function shade(hex, dl = 0, ds = 0) { const [r, g, b] = hex2rgb(hex); let [h, l, s] = rgb2hls(r, g, b); l = Math.max(0, Math.min(1, l + dl)); s = Math.max(0, Math.min(1, s + ds)); return rgb2hex(...hls2rgb(h, l, s)); }

// ---------- pro layer model (E-series, approved) ----------
export function bgRadial(W, H, inner, outer, cx = null, cy = null, r = null) {
  cx = cx ?? W / 2; cy = cy ?? H / 2; r = r ?? Math.max(W, H) * 0.75; const i = uid('rg');
  return `<defs><radialGradient id="${i}" gradientUnits="userSpaceOnUse" cx="${r0(cx)}" cy="${r0(cy)}" r="${r0(r)}"><stop offset="0" stop-color="${inner}"/><stop offset="1" stop-color="${outer}"/></radialGradient></defs><rect width="${W}" height="${H}" fill="url(#${i})"/>`;
}
export function bgLinear(W, H, c1, c2, angle = 90) {
  const i = uid('lg'); const a = angle * Math.PI / 180; const x2 = 50 + 50 * Math.cos(a), y2 = 50 + 50 * Math.sin(a), x1 = 100 - x2, y1 = 100 - y2;
  return `<defs><linearGradient id="${i}" x1="${r0(x1)}%" y1="${r0(y1)}%" x2="${r0(x2)}%" y2="${r0(y2)}%"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient></defs><rect width="${W}" height="${H}" fill="url(#${i})"/>`;
}
export function glow(cx, cy, r, color, opacity = 0.55) {
  const i = uid('gl');
  return `<defs><radialGradient id="${i}"><stop offset="0" stop-color="${color}" stop-opacity="${opacity}"/><stop offset="0.55" stop-color="${color}" stop-opacity="${(opacity * 0.35).toFixed(2)}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs><circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#${i})"/>`;
}
export function softShadow(cx, cy, rx, ry, opacity = 0.4, blur = 14, color = INK) {
  const i = uid('bl');
  return `<defs><filter id="${i}" x="-50%" y="-100%" width="200%" height="300%"><feGaussianBlur stdDeviation="${blur}"/></filter></defs><ellipse cx="${r0(cx)}" cy="${r0(cy)}" rx="${r0(rx)}" ry="${r0(ry)}" fill="${color}" opacity="${opacity}" filter="url(#${i})"/>`;
}
export function blob(cx, cy, r, color, opacity = 1, seed = 1) {
  const rnd = rng(seed); const pts = [];
  for (let k = 0; k < 8; k++) { const a = 2 * Math.PI * k / 8; const rr = r * (0.9 + 0.2 * rnd()); pts.push([cx + rr * Math.cos(a), cy + rr * Math.sin(a)]); }
  let d = `M${r0(pts[0][0])},${r0(pts[0][1])}`;
  for (let k = 0; k < 8; k++) { const p0 = pts[k], p1 = pts[(k + 1) % 8], c = 0.36; const cp1 = [p0[0] - (p0[1] - cy) * c, p0[1] + (p0[0] - cx) * c], cp2 = [p1[0] + (p1[1] - cy) * c, p1[1] - (p1[0] - cx) * c];
    d += ` C${r0(cp1[0])},${r0(cp1[1])} ${r0(cp2[0])},${r0(cp2[1])} ${r0(p1[0])},${r0(p1[1])}`; }
  return `<path d="${d}Z" fill="${color}" opacity="${opacity}"/>`;
}
export function extruded(text, x, y, size, fill = CREAM, depth = null, ext = INK, anchor = 'end', font = BALOO, dx = 1, dy = 1, stroke = null) {
  depth = depth ?? Math.max(4, Math.round(size * 0.09)); const out = [];
  for (let k = depth; k > 0; k--) out.push(txt(text, (Number(x) + dx * k).toFixed(1), (Number(y) + dy * k).toFixed(1), size, ext, 800, anchor, font));
  const st = stroke ? `stroke="${stroke}" stroke-width="${(size * 0.06).toFixed(1)}" paint-order="stroke" stroke-linejoin="round"` : '';
  out.push(txt(text, x, y, size, fill, 800, anchor, font, st)); return out.join('');
}
export function stickerText(text, x, y, size, fill = CREAM, ink = INK, anchor = 'end', font = BALOO) {
  return txt(text, x, Number(y) + size * 0.07, size, ink, 800, anchor, font, `stroke="${ink}" stroke-width="${(size * 0.11).toFixed(1)}" stroke-linejoin="round"`)
    + txt(text, x, y, size, fill, 800, anchor, font, `stroke="${ink}" stroke-width="${(size * 0.11).toFixed(1)}" paint-order="stroke" stroke-linejoin="round"`);
}
export function price(xr, y, amount, size = 96, color = CREAM, label = null, old = null, font = BALOO) {
  const aw = est(amount, size, font); const out = [txt(amount, xr, y, size, color, 800, 'end', font)]; const rx = xr - aw - size * 0.12;
  out.push(txt('﷼', r0(rx), r0(y - size * 0.02), size * 0.34, color, 800, 'end', TAJ));
  if (label) out.push(txt(label, xr, r0(y + size * 0.42), size * 0.26, color, 700, 'end', TAJ));
  if (old) { const oy = y - size * 0.02; out.push(txt(old + ' ﷼', r0(rx - size * 0.55), r0(oy), size * 0.34, color, 700, 'end', TAJ, 'opacity="0.75"'));
    const w = est(old + ' ﷼', size * 0.34, TAJ);
    out.push(`<line x1="${r0(rx - size * 0.55 - w)}" y1="${r0(oy - size * 0.11)}" x2="${r0(rx - size * 0.55)}" y2="${r0(oy - size * 0.11)}" stroke="${color}" stroke-width="${(size * 0.035).toFixed(1)}" opacity="0.85"/>`); }
  return out.join('');
}
export const ICONS = {
  clock: 'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20zM12 6v6l4 2',
  truck: 'M1 6h13v9H1zM14 9h4l3 3v3h-7zM5 18a2 2 0 1 0 0.01 0zM17 18a2 2 0 1 0 0.01 0z',
  cash: 'M2 6h20v12H2zM12 9a3 3 0 1 0 0.01 0zM5 9v0M19 15v0',
  gift: 'M3 9h18v4H3zM5 13h14v8H5zM12 9v12M12 9c-2-4-6-4-6-1s4 1 6 1zM12 9c2-4 6-4 6-1s-4 1-6 1',
  shield: 'M12 2l8 3v6c0 5-3.5 9-8 11c-4.5-2-8-6-8-11V5z',
  bolt: 'M13 2L3 14h8l-1 8l10-12h-8z',
  paw: 'M12 13c-3 0-5 2-5 4.5c0 1.5 1 2.5 2.5 2.5c1 0 1.5-.5 2.5-.5s1.5.5 2.5.5c1.5 0 2.5-1 2.5-2.5c0-2.5-2-4.5-5-4.5zM7 8a1.8 1.8 0 1 0 0.01 0zM17 8a1.8 1.8 0 1 0 0.01 0zM9.5 4.5a1.8 1.8 0 1 0 0.01 0zM14.5 4.5a1.8 1.8 0 1 0 0.01 0z',
  tag: 'M3 3h8l10 10l-8 8L3 11zM7.5 7.5a1 1 0 1 0 0.01 0z',
};
export function icon(name, x, y, size, color) { const s = size / 24; return `<path d="${ICONS[name] || ICONS.paw}" transform="translate(${r0(x)} ${r0(y)}) scale(${s.toFixed(3)})" fill="none" stroke="${color}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>`; }
export function trust(items, xr, y, size = 20, color = CREAM, gap = null) {
  gap = gap ?? size * 1.6; const out = []; let x = xr;
  for (const [ic, t] of items) { const w = est(t, size); out.push(txt(t, r0(x - size * 1.4), r0(y + size * 0.36), size, color, 700, 'end')); out.push(icon(ic, x - size * 1.15, y - size * 0.55, size * 1.15, color)); x -= size * 1.4 + w + gap; }
  return out.join('');
}
export function trustWidth(items, size = 20, gap = null) { gap = gap ?? size * 1.6; let w = 0; for (const [, t] of items) w += size * 1.4 + est(t, size) + gap; return w - gap; }
export function badge(cx, cy, r, l1, l2 = null, fill = AMBER, fg = INK, rot = -12, ring = true, s1 = null, s2 = null) {
  s1 = s1 || r * 0.55; s2 = s2 || r * 0.34;
  const out = [`<g transform="rotate(${rot} ${cx} ${cy})">`, `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" stroke="${INK}" stroke-width="${r0(Math.max(3, r * 0.06))}"/>`];
  if (ring) out.push(`<circle cx="${cx}" cy="${cy}" r="${r0(r * 0.82)}" fill="none" stroke="${fg}" stroke-width="2" stroke-dasharray="6 6" opacity="0.7"/>`);
  if (l2) { out.push(txt(l1, cx, r0(cy - s1 * 0.05), s1, fg, 800, 'middle', BALOO)); out.push(txt(l2, cx, r0(cy + s2 * 1.2), s2, fg, 800, 'middle', TAJ)); }
  else out.push(txt(l1, cx, r0(cy + s1 * 0.36), s1, fg, 800, 'middle', BALOO));
  out.push('</g>'); return out.join('');
}
export function speedLines(x, y, n = 4, length = 120, gap = 22, color = CREAM, opacity = 0.8, taper = true) {
  const out = []; for (let k = 0; k < n; k++) { const L = taper ? length * (1 - 0.18 * k) : length; out.push(`<line x1="${x}" y1="${y + k * gap}" x2="${r0(x + L)}" y2="${y + k * gap}" stroke="${color}" stroke-width="7" stroke-linecap="round" opacity="${opacity}"/>`); }
  return out.join('');
}
export function card(x, y, w, h, fill = CREAM, r = 32, shadow = true) {
  return (shadow ? `<rect x="${x}" y="${y + 10}" width="${w}" height="${h}" rx="${r}" fill="${INK}" opacity="0.25"/>` : '') + `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}"/>`;
}
/** Product photo that is NOT a cut-out (opaque background): a tilted white plate with a soft shadow carries it. */
export function plate(name, cx, bottom, w, rot = 0) {
  const h = contentH(name, w); const pad = w * 0.06; const x = cx - w / 2 - pad, y = bottom - h - pad; const ccx = cx, ccy = bottom - h / 2;
  return `<g transform="rotate(${rot} ${r0(ccx)} ${r0(ccy)})"><rect x="${r0(x)}" y="${r0(y + 10)}" width="${r0(w + 2 * pad)}" height="${r0(h + 2 * pad)}" rx="${r0(w * 0.06)}" fill="${INK}" opacity="0.25"/>`
    + `<rect x="${r0(x)}" y="${r0(y)}" width="${r0(w + 2 * pad)}" height="${r0(h + 2 * pad)}" rx="${r0(w * 0.06)}" fill="${WHITE}"/>` + img(name, { cx, bottom, w, shadow: false }) + '</g>';
}

// ---------- pop & joy: generated stickers + depth-aware code effects ----------
export function rng(seed) { let s = (seed * 9301 + 49297) % 233280; return () => { s = (s * 9301 + 49297) % 233280; return s / 233280; }; }
const uni = (rnd, a, b) => a + (b - a) * rnd();
export function stickerPng(name, cx, cy, w, rot = 0, flip = false, opacity = 1, shadow = false) { const h = contentH(name, w); return img(name, { cx, bottom: cy + h / 2, w, rot, flip, shadow, opacity }); }
export function joyStickers(W, H, names, n = 8, seed = 3, avoid = null, region = null, wmin = 70, wmax = 150, rotmax = 25, depth = true) {
  const rnd = rng(seed); const out = []; let tries = 0; const [x0, y0, x1, y1] = region || [0, 0, W, H]; const placed = []; const av = avoid ? (Array.isArray(avoid[0]) ? avoid : [avoid]) : [];
  while (out.length < n && tries < n * 50) {
    tries++; const x = uni(rnd, x0, x1), y = uni(rnd, y0, y1);
    if (av.some((a) => Math.hypot(x - a[0], y - a[1]) < a[2])) continue;
    const w = uni(rnd, wmin, wmax);
    if (placed.some(([px, py, pw]) => Math.hypot(x - px, y - py) < (w + pw) * 0.55)) continue;
    placed.push([x, y, w]); const t = (w - wmin) / Math.max(1, wmax - wmin);
    out.push(stickerPng(names[Math.floor(rnd() * names.length)], r0(x), r0(y), w, uni(rnd, -rotmax, rotmax).toFixed(0), rnd() < 0.3, depth ? +(0.75 + 0.25 * t).toFixed(2) : 1));
  }
  return out.join('');
}
export function blurFilter(std) { const i = uid('bf'); return [i, `<defs><filter id="${i}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="${std}"/></filter></defs>`]; }
export function confettiDepth(W, H, n = 60, seed = 1, colors = null, avoid = null, region = null) {
  colors = colors || [CORAL, AMBER, TEAL, CREAM, '#F2A7C3']; const rnd = rng(seed); const out = []; const [fid, fdef] = blurFilter(3); out.push(fdef); const [x0, y0, x1, y1] = region || [0, 0, W, H];
  const layers = [[Math.floor(n * 0.45), 6, 12, 0.45, true], [Math.floor(n * 0.35), 12, 22, 0.85, false], [Math.floor(n * 0.2), 22, 40, 1.0, false]];
  for (const [cnt, smin, smax, op, blur] of layers) {
    let tries = 0, k = 0;
    while (k < cnt && tries < cnt * 30) {
      tries++; const x = uni(rnd, x0, x1), y = uni(rnd, y0, y1);
      if (avoid && Math.hypot(x - avoid[0], y - avoid[1]) < avoid[2]) continue;
      k++; const s = uni(rnd, smin, smax); const c = colors[Math.floor(rnd() * colors.length)]; const rot = uni(rnd, 0, 360); const kind = rnd();
      const g = `<g transform="rotate(${r0(rot)} ${r0(x)} ${r0(y)})" opacity="${op}"${blur ? ` filter="url(#${fid})"` : ''}>`;
      if (kind < 0.55) out.push(g + `<rect x="${r0(x - s * 0.7)}" y="${r0(y - s * 0.22)}" width="${r0(s * 1.4)}" height="${r0(s * 0.44)}" rx="${r0(s * 0.08)}" fill="${c}"/><rect x="${r0(x)}" y="${r0(y - s * 0.22)}" width="${r0(s * 0.7)}" height="${r0(s * 0.44)}" rx="${r0(s * 0.08)}" fill="${shade(c, -0.12)}"/></g>`);
      else if (kind < 0.8) out.push(g + `<circle cx="${r0(x)}" cy="${r0(y)}" r="${r0(s * 0.3)}" fill="${c}"/><circle cx="${r0(x - s * 0.09)}" cy="${r0(y - s * 0.09)}" r="${r0(s * 0.1)}" fill="${WHITE}" opacity="0.7"/></g>`);
      else out.push(g + `<path d="M${r0(x - s * 0.8)},${r0(y)} q${r0(s * 0.4)},${r0(-s * 0.6)} ${r0(s * 0.8)},0 t${r0(s * 0.8)},0" fill="none" stroke="${c}" stroke-width="${r0(s * 0.28)}" stroke-linecap="round"/></g>`);
    }
  }
  return out.join('');
}
export function glowRays(cx, cy, r, color = CREAM, n = 18, opacity = 0.35, width = 0.5) {
  const i = uid('ry'); const out = [`<defs><radialGradient id="${i}" gradientUnits="userSpaceOnUse" cx="${cx}" cy="${cy}" r="${r}"><stop offset="0" stop-color="${color}" stop-opacity="${opacity}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs><g fill="url(#${i})">`];
  for (let k = 0; k < n; k++) { const a0 = 2 * Math.PI * k / n, a1 = a0 + 2 * Math.PI / n * width; out.push(`<polygon points="${cx},${cy} ${r0(cx + r * Math.cos(a0))},${r0(cy + r * Math.sin(a0))} ${r0(cx + r * Math.cos(a1))},${r0(cy + r * Math.sin(a1))}"/>`); }
  out.push('</g>'); return out.join('');
}
export function burstLines(cx, cy, rA, rB, n = 12, color = CREAM, w = 10, opacity = 0.9, seed = 2) {
  const rnd = rng(seed); const out = [];
  for (let k = 0; k < n; k++) { const a = 2 * Math.PI * k / n + uni(rnd, -0.1, 0.1); const L0 = rA * uni(rnd, 0.9, 1.1), L1 = rB * uni(rnd, 0.8, 1.15); const px = -Math.sin(a), py = Math.cos(a);
    const x0 = cx + L0 * Math.cos(a), y0 = cy + L0 * Math.sin(a), x1 = cx + L1 * Math.cos(a), y1 = cy + L1 * Math.sin(a);
    out.push(`<polygon points="${r0(x0 + px * w / 2)},${r0(y0 + py * w / 2)} ${r0(x0 - px * w / 2)},${r0(y0 - py * w / 2)} ${r0(x1)},${r0(y1)}" fill="${color}" opacity="${opacity}"/>`); }
  return out.join('');
}
export function bokeh(W, H, n = 14, seed = 4, color = CREAM, avoid = null, rmin = 14, rmax = 60) {
  const rnd = rng(seed); const [fid, fdef] = blurFilter(6); const out = [fdef];
  for (let k = 0; k < n; k++) { const x = uni(rnd, 0, W), y = uni(rnd, 0, H); if (avoid && Math.hypot(x - avoid[0], y - avoid[1]) < avoid[2]) continue;
    const r = uni(rnd, rmin, rmax); out.push(`<circle cx="${r0(x)}" cy="${r0(y)}" r="${r0(r)}" fill="${color}" opacity="${uni(rnd, 0.08, 0.22).toFixed(2)}" filter="url(#${fid})"/>`); }
  return out.join('');
}
const strokeAttr = (ink, w) => `stroke="${ink}" stroke-width="${w.toFixed(1)}" stroke-linejoin="round" stroke-linecap="round"`;
export function heart3d(cx, cy, r, color = CORAL, rot = 0, ink = INK) {
  const i = uid('hg'); const d = `M${cx},${cy + r * 0.95} C${cx - r * 1.5},${cy - r * 0.1} ${cx - r * 0.9},${cy - r * 1.1} ${cx},${cy - r * 0.45} C${cx + r * 0.9},${cy - r * 1.1} ${cx + r * 1.5},${cy - r * 0.1} ${cx},${cy + r * 0.95} Z`;
  return `<defs><radialGradient id="${i}" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="${shade(color, 0.22)}"/><stop offset="0.6" stop-color="${color}"/><stop offset="1" stop-color="${shade(color, -0.18)}"/></radialGradient></defs>`
    + `<g transform="rotate(${rot} ${cx} ${cy})"><path d="${d}" fill="${ink}" opacity="0.25" transform="translate(${r0(r * 0.08)} ${r0(r * 0.14)})"/><path d="${d}" fill="url(#${i})" ${strokeAttr(ink, Math.max(2, r * 0.13))}/>`
    + `<ellipse cx="${r0(cx - r * 0.45)}" cy="${r0(cy - r * 0.5)}" rx="${r0(r * 0.2)}" ry="${r0(r * 0.11)}" fill="${WHITE}" opacity="0.9" transform="rotate(-35 ${r0(cx - r * 0.45)} ${r0(cy - r * 0.5)})"/></g>`;
}
export function star3d(cx, cy, r, color = AMBER, rot = 0, ink = INK) {
  const i = uid('sg'); const pts = [];
  for (let k = 0; k < 10; k++) { const rr = k % 2 === 0 ? r : r * 0.46; const a = -Math.PI / 2 + Math.PI * k / 5; pts.push(`${(cx + rr * Math.cos(a)).toFixed(1)},${(cy + rr * Math.sin(a)).toFixed(1)}`); }
  return `<defs><radialGradient id="${i}" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="${shade(color, 0.25)}"/><stop offset="0.6" stop-color="${color}"/><stop offset="1" stop-color="${shade(color, -0.2)}"/></radialGradient></defs>`
    + `<g transform="rotate(${rot} ${cx} ${cy})"><polygon points="${pts.join(' ')}" fill="${ink}" opacity="0.25" transform="translate(${r0(r * 0.08)} ${r0(r * 0.14)})"/><polygon points="${pts.join(' ')}" fill="url(#${i})" ${strokeAttr(ink, Math.max(2, r * 0.12))}/>`
    + `<circle cx="${r0(cx - r * 0.22)}" cy="${r0(cy - r * 0.28)}" r="${r0(r * 0.12)}" fill="${WHITE}" opacity="0.9"/></g>`;
}
export function sparkle(cx, cy, r, color = AMBER) { return `<path d="M${cx} ${cy - r} Q${cx} ${cy} ${cx + r} ${cy} Q${cx} ${cy} ${cx} ${cy + r} Q${cx} ${cy} ${cx - r} ${cy} Q${cx} ${cy} ${cx} ${cy - r}Z" fill="${color}"/>`; }
export function patternPaws(W, H, color, opacity = 0.1, step = 170, r = 26) {
  const out = [`<g fill="${color}" opacity="${opacity}">`]; let row = 0;
  for (let y = step / 2; y < H + step; y += step) { const off = (row++ % 2) * step / 2; for (let x = off; x < W + step; x += step) out.push(paw(x, y, r)); }
  out.push('</g>'); return out.join('');
}
export function paw(cx, cy, r, color = null, opacity = null) {
  const f = color ? ` fill="${color}"` : ''; const o = opacity !== null ? ` opacity="${opacity}"` : '';
  return `<g${f}${o}><ellipse cx="${cx}" cy="${cy + r * 0.35}" rx="${r0(r * 0.62)}" ry="${r0(r * 0.5)}"/><circle cx="${r0(cx - r * 0.62)}" cy="${r0(cy - r * 0.25)}" r="${r0(r * 0.22)}"/><circle cx="${r0(cx - r * 0.22)}" cy="${r0(cy - r * 0.6)}" r="${r0(r * 0.22)}"/><circle cx="${r0(cx + r * 0.22)}" cy="${r0(cy - r * 0.6)}" r="${r0(r * 0.22)}"/><circle cx="${r0(cx + r * 0.62)}" cy="${r0(cy - r * 0.25)}" r="${r0(r * 0.22)}"/></g>`;
}
