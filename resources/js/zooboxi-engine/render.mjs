// CLI: node render.mjs <spec.json>
// Reads a campaign spec, composes the board from the approved template for its format, choreographs
// the motion, and writes three artefacts next to each other (spec.out.dir/spec.out.name.*):
//   .png   static (final frame)            → fallback, thumbnails, HUB preview
//   .svg   animated SVG (CSS keyframes)    → store zones (inline; images referenced by URL)
//   .webp  animated WebP (frames)          → app image slot (Flutter decodes it natively)
// Prints a JSON result line. Exit code ≠ 0 on failure.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { Resvg } from '@resvg/resvg-js';
import * as B from './build.mjs';
import { build } from './templates.mjs';
import { choreograph, render as renderMotion, DUR } from './motion.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const specPath = process.argv[2]; if (!specPath) { console.error('usage: render.mjs <spec.json>'); process.exit(2); }
const spec = JSON.parse(readFileSync(specPath, 'utf8'));
const out = spec.out; mkdirSync(out.dir, { recursive: true });

// ---- assets ----
const A = spec.assets;
B.setCache(A.cache || join(out.dir, '.assets-cache.json'));
if (A.chars_dir && existsSync(A.chars_dir)) B.registerAssetDir(A.chars_dir, readdirSync(A.chars_dir).filter((f) => f.endsWith('.png')).map((f) => f.slice(0, -4)));
if (A.pop_dir && existsSync(A.pop_dir)) B.registerAssetDir(A.pop_dir, readdirSync(A.pop_dir).filter((f) => f.endsWith('.png')).map((f) => f.slice(0, -4)));
B.registerAsset('logo', A.logo);
for (const p of spec.products || []) B.registerAsset(p.name, p.file);
spec.products = (spec.products || []).filter((p) => B.hasAsset(p.name));
if (spec.character && !B.hasAsset(spec.character)) spec.character = null;
spec.pop_names = (spec.pop_names || []).filter((n) => B.hasAsset(n));

// ---- fonts ----
const fontDir = A.font_dir || resolve(here, '../../fonts/zooboxi');
// resvg-js 2.6: fontBuffers breaks per-glyph fallback (whole runs turn to tofu) → load by file path.
const fontFiles = readdirSync(fontDir).filter((f) => /\.ttf$/i.test(f)).map((f) => join(fontDir, f));
const raster = (svg, width = null) => new Resvg(svg, { font: { fontFiles, loadSystemFonts: false, defaultFontFamily: 'Tajawal' }, shapeRendering: 2, textRendering: 2, imageRendering: 0, ...(width ? { fitTo: { mode: 'width', value: width } } : {}) }).render().asPng();

// ---- compose + choreograph ----
B.resetUid();
const { Ls, W, H, bg } = build(spec);
const layers = choreograph(Ls, spec.ad_type || 'offer', spec.seed || 1);
const base = join(out.dir, out.name);

// 1) static final frame
const finalSvg = B.substitute(renderMotion(layers, W, H, bg, 'frame', 1));
writeFileSync(base + '.png', raster(finalSvg));

if (out.static_only) { console.log(JSON.stringify({ ok: true, png: base + '.png', svg: null, webp: null, png_kb: Math.round(readFileSync(base + '.png').length / 1024), static_only: true, W, H })); process.exit(0); }

// 2) animated SVG for the store: assets by public URL (never data URIs → small file)
const urls = spec.asset_urls || {};
const cssSvg = renderMotion(layers, W, H, bg, 'css').replace(/\{\{([\w\-]+)\}\}/g, (m, n) => urls[n] || ('data:image/png;base64,' + readFileSync(B.asset(n).file).toString('base64')));
writeFileSync(base + '.svg', cssSvg);

// 3) animated WebP for the app — only the slots the app actually animates (hero/hero_wide are
// served to the store as inline SVG, so encoding a WebP for them is pure render time).
if (out.webp === false) { console.log(JSON.stringify({ ok: true, png: base + '.png', svg: base + '.svg', webp: null, png_kb: Math.round(readFileSync(base + '.png').length / 1024), svg_kb: Math.round(readFileSync(base + '.svg').length / 1024), W, H })); process.exit(0); }
// The app slot is drawn at the board's own width on a 3x phone, so app_w = the board width keeps
// text pixel-exact; play_ms is the animation's length on the phone (shorter than the store's
// 4.5 s: the plate is small and a slow entrance reads as lag).
const frames = out.frames || 36, appW = out.app_w || 640, q = out.quality || 72;
const playMs = out.play_ms || Math.round(DUR * 1000), holdMs = out.hold_ms === undefined ? 1500 : out.hold_ms;
const fdir = base + '-frames'; rmSync(fdir, { recursive: true, force: true }); mkdirSync(fdir);
for (let i = 0; i < frames; i++) writeFileSync(join(fdir, `f${String(i).padStart(3, '0')}.png`), raster(B.substitute(renderMotion(layers, W, H, bg, 'frame', i / (frames - 1))), appW));
const list = Array.from({ length: frames }, (_, i) => join(fdir, `f${String(i).padStart(3, '0')}.png`));
const ms = Math.max(20, Math.round(playMs / frames)); let tool = out.webp_tool || 'auto';
if (tool === 'auto') tool = spawnSync('img2webp', ['-version']).status === 0 ? 'img2webp' : 'convert';
let r;
// The app WebP loops (owner request): timeline, a hold on the last frame, again.
const loop = out.loop === undefined ? '0' : String(out.loop);
// Encoder effort: 6 is the smallest file, 4 encodes ~2x faster for ~8% more bytes (the render runs
// inside the approve→poll window, so the trade matters).
const method = String(out.webp_method || 4);
if (tool === 'img2webp') r = spawnSync('img2webp', ['-loop', loop, '-lossy', '-q', String(q), '-m', String(method), '-d', String(ms), ...list.slice(0, -1), '-d', String(holdMs), list[list.length - 1], '-o', base + '.webp']);
else r = spawnSync('convert', ['-delay', String(Math.round(ms / 10)), ...list.slice(0, -1), '-delay', String(Math.round(holdMs / 10)), list[list.length - 1], '-loop', loop, '-quality', String(q), '-define', 'webp:method=' + method, base + '.webp']);
if (r.status !== 0) { console.error('webp failed (' + tool + '): ' + (r.stderr || '').toString()); }
rmSync(fdir, { recursive: true, force: true });
const size = (f) => (existsSync(f) ? statSize(f) : 0); function statSize(f) { return readFileSync(f).length; }
console.log(JSON.stringify({ ok: true, png: base + '.png', svg: base + '.svg', webp: existsSync(base + '.webp') ? base + '.webp' : null, png_kb: Math.round(size(base + '.png') / 1024), svg_kb: Math.round(size(base + '.svg') / 1024), webp_kb: Math.round(size(base + '.webp') / 1024), frames, app_w: appW, fps: Math.round(1000 / ms), tool, W, H }));
