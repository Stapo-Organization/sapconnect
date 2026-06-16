// Generic SVG → PNG rasteriser for the ad-banner compositor.
// Uses @resvg/resvg-js (Rust/rustybuzz — correct Arabic shaping, no browser,
// no system libs, no root → runs on the AlmaLinux backend with Node).
//
// Usage: node render-banner.mjs <svgPath> <outPngPath> <fontDir>
// Fonts: all Cairo-*.ttf in <fontDir> are loaded; SVG text must OMIT font-family
// (resvg uses defaultFontFamily 'Cairo') — that is what makes shaping work.

import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const [, , svgPath, outPath, fontDir] = process.argv;
if (!svgPath || !outPath || !fontDir) {
  console.error('usage: render-banner.mjs <svg> <out> <fontDir>');
  process.exit(2);
}

const svg = readFileSync(svgPath, 'utf8');
const fontBuffers = readdirSync(fontDir)
  .filter((f) => /\.ttf$/i.test(f))
  .map((f) => readFileSync(join(fontDir, f)));

const resvg = new Resvg(svg, {
  font: { fontBuffers, loadSystemFonts: false, defaultFontFamily: 'Cairo' },
  shapeRendering: 2,
  textRendering: 2,
});

writeFileSync(outPath, resvg.render().asPng());
console.log('ok ' + outPath);
