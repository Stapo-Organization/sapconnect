// Minimal PNG reader (no deps): alpha bounding box + dominant saturated colour of a cut-out.
// Supports 8-bit grey/RGB/palette/RGBA, non-interlaced; 16-bit is down-sampled. Enough for
// the character/sticker library and catalog product images.
import { inflateSync } from 'node:zlib';
import { readFileSync } from 'node:fs';

export function readPng(file) {
  const buf = readFileSync(file);
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG: ' + file);
  let pos = 8, w = 0, h = 0, depth = 8, ctype = 6, interlace = 0, idat = [], plte = null, trns = null;
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); const type = buf.toString('ascii', pos + 4, pos + 8); const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); depth = data[8]; ctype = data[9]; interlace = data[12]; }
    else if (type === 'PLTE') plte = data;
    else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (interlace) throw new Error('interlaced PNG unsupported: ' + file);
  const raw = inflateSync(Buffer.concat(idat));
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[ctype]; const bps = depth === 16 ? 2 : 1;
  const bpp = ch * bps; const stride = Math.ceil(w * ch * depth / 8);
  const out = Buffer.alloc(w * h * 4); // always RGBA8
  let prev = Buffer.alloc(stride), p = 0;
  for (let y = 0; y < h; y++) {
    const f = raw[p++]; const line = Buffer.from(raw.subarray(p, p + stride)); p += stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? line[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
      let v = line[i];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
      line[i] = v & 255;
    }
    for (let x = 0; x < w; x++) {
      const o = (y * w + x) * 4; let r, g, bl, al = 255;
      if (depth < 8) { // packed grey/palette
        const perByte = 8 / depth; const idx = (line[Math.floor(x / perByte)] >> (8 - depth * (1 + x % perByte))) & ((1 << depth) - 1);
        if (ctype === 3) { r = plte[idx * 3]; g = plte[idx * 3 + 1]; bl = plte[idx * 3 + 2]; al = trns && idx < trns.length ? trns[idx] : 255; }
        else { r = g = bl = idx * 255 / ((1 << depth) - 1); }
      } else {
        const i = x * bpp;
        if (ctype === 3) { const idx = line[i]; r = plte[idx * 3]; g = plte[idx * 3 + 1]; bl = plte[idx * 3 + 2]; al = trns && idx < trns.length ? trns[idx] : 255; }
        else if (ctype === 0) { r = g = bl = line[i]; al = 255; }
        else if (ctype === 4) { r = g = bl = line[i]; al = line[i + bps]; }
        else if (ctype === 2) { r = line[i]; g = line[i + bps]; bl = line[i + 2 * bps]; }
        else { r = line[i]; g = line[i + bps]; bl = line[i + 2 * bps]; al = line[i + 3 * bps]; }
      }
      out[o] = r; out[o + 1] = g; out[o + 2] = bl; out[o + 3] = al;
    }
    prev = line;
  }
  return { w, h, rgba: out, hasAlpha: ctype === 4 || ctype === 6 || (ctype === 3 && !!trns) };
}

function rgb2hls(r, g, b) {
  r /= 255; g /= 255; b /= 255; const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const l = (mx + mn) / 2; let h = 0, s = 0;
  if (mx !== mn) { const d = mx - mn; s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; h /= 6; }
  return [h, l, s];
}

/** alpha bbox (alpha > 10) + dominant saturated colour; a cut-out with no alpha gets the full frame and `opaque: true`. */
export function stats(file) {
  const { w, h, rgba, hasAlpha } = readPng(file);
  let x0 = w, y0 = h, x1 = -1, y1 = -1, opaqueEdge = 0, edgeN = 0;
  const acc = [0, 0, 0]; let n = 0; const step = Math.max(1, Math.floor(w / 90));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const o = (y * w + x) * 4; const a = rgba[o + 3];
    if (a > 10) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    if (x === 0 || y === 0 || x === w - 1 || y === h - 1) { edgeN++; if (a > 200) opaqueEdge++; }
    if (y % step === 0 && x % step === 0 && a >= 200) {
      const [, l, s] = rgb2hls(rgba[o], rgba[o + 1], rgba[o + 2]);
      if (s >= 0.35 && l >= 0.15 && l <= 0.85) { acc[0] += rgba[o]; acc[1] += rgba[o + 1]; acc[2] += rgba[o + 2]; n++; }
    }
  }
  if (x1 < 0) { x0 = 0; y0 = 0; x1 = w - 1; y1 = h - 1; }
  const hex = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0').toUpperCase();
  const dom = n ? '#' + hex(acc[0] / n) + hex(acc[1] / n) + hex(acc[2] / n) : null;
  // "opaque": no alpha channel, or the border is (almost) fully opaque → a photo on a background, not a cut-out
  const opaque = !hasAlpha || (edgeN && opaqueEdge / edgeN > 0.9);
  return { w, h, bbox: [x0, y0, x1 + 1, y1 + 1], dom, opaque };
}
