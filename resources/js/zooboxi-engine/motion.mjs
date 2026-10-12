// Motion engine (approved week-1 model): role-tagged layers → preset per role → choreography per
// ad type → seeded variation → one timeline rendered as (a) animated SVG with CSS keyframes for the
// store and (b) discrete frames for the app's animated WebP. Smoothness rules: transform + opacity
// only, one iteration, hold the last frame, ≤ 12 moving layers, no motion on bg/logo/trust,
// prefers-reduced-motion → static.
import { DEFS } from './build.mjs';

export const DUR = 4.5; export const MAX_MOVING = 12;
const clamp = (t) => (t < 0 ? 0 : t > 1 ? 1 : t);
const seg = (t, a, b) => clamp((t - a) / Math.max(1e-6, b - a));
const easeOutBack = (t) => { const c1 = 1.70158, c3 = c1 + 1; t = clamp(t); return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2; };
const easeOutCubic = (t) => { t = clamp(t); return 1 - (1 - t) ** 3; };
const easeOutBounce = (t) => { t = clamp(t); const n1 = 7.5625, d1 = 2.75; if (t < 1 / d1) return n1 * t * t; if (t < 2 / d1) { t -= 1.5 / d1; return n1 * t * t + 0.75; } if (t < 2.5 / d1) { t -= 2.25 / d1; return n1 * t * t + 0.9375; } t -= 2.625 / d1; return n1 * t * t + 0.984375; };
const pc = (v) => (v * 100).toFixed(1) + '%';

// preset → { fn(t) → {s,dx,dy,rot,op}, keyframes, easing }
const P = {
  pop: (a, b) => ({ fn: (t) => ({ s: t >= a ? easeOutBack(seg(t, a, b)) : 0, op: t >= a ? 1 : 0 }), kf: `0%,${pc(a)}{transform:scale(0);opacity:0} ${pc(b)},100%{transform:scale(1);opacity:1}`, ease: 'cubic-bezier(.34,1.56,.64,1)' }),
  rise: (a, b, dist = 420) => ({ fn: (t) => ({ dy: t >= a ? (1 - easeOutBack(seg(t, a, b))) * dist : dist, op: t >= a ? 1 : 0 }), kf: `0%,${pc(a)}{transform:translateY(${dist}px);opacity:0} ${pc(a + 0.001)}{opacity:1} ${pc(b)},100%{transform:translateY(0);opacity:1}`, ease: 'cubic-bezier(.34,1.56,.64,1)' }),
  drop: (a, b, dist = 380) => ({ fn: (t) => ({ dy: t >= a ? -(1 - easeOutBounce(seg(t, a, b))) * dist : -dist, op: t >= a ? 1 : 0 }), kf: `0%,${pc(a)}{transform:translateY(-${dist}px);opacity:0} ${pc(a + 0.001)}{opacity:1} ${pc(b)},100%{transform:translateY(0);opacity:1}`, ease: 'cubic-bezier(.22,1,.36,1)' }),
  fall: (a, b, dist = 240) => ({ fn: (t) => ({ dy: t >= a ? -dist + easeOutCubic(seg(t, a, b)) * dist * 2 : -dist, op: Math.min(1, seg(t, a, a + 0.1)) * (1 - 0.3 * seg(t, b - 0.15, b)) }), kf: `0%,${pc(a)}{transform:translateY(-${dist}px);opacity:0} ${pc(a + 0.1)}{opacity:1} ${pc(b - 0.15)}{opacity:1} ${pc(b)},100%{transform:translateY(${dist}px);opacity:.7}`, ease: 'ease-out' }),
  burst: (a, b) => ({ fn: (t) => ({ s: t >= a ? easeOutCubic(seg(t, a, b)) * 1.15 : 0, op: t >= a ? 1 - seg(t, b, b + 0.35) : 0 }), kf: `0%,${pc(a)}{transform:scale(0);opacity:0} ${pc(a + 0.02)}{opacity:1} ${pc(b)}{transform:scale(1.15);opacity:1} ${pc(Math.min(1, b + 0.35))},100%{transform:scale(1.15);opacity:0}`, ease: 'ease-out' }),
  spin: (deg = 16) => ({ fn: (t) => ({ rot: deg * t }), kf: `0%{transform:rotate(0deg)} 100%{transform:rotate(${deg}deg)}`, ease: 'linear' }),
  pulse: (a) => ({ fn: (t) => { if (t < a) return { s: 0, op: 0 }; let base = easeOutBack(seg(t, a, a + 0.12)); if (t > a + 0.12) base = 1 + 0.05 * Math.sin((t - a - 0.12) * 2 * Math.PI * 1.6); return { s: base, op: 1 }; }, kf: `0%,${pc(a)}{transform:scale(0);opacity:0} ${pc(a + 0.12)}{transform:scale(1);opacity:1} ${pc(Math.min(1, a + 0.4))}{transform:scale(1.05)} ${pc(Math.min(1, a + 0.7))}{transform:scale(1)} 100%{transform:scale(1.05);opacity:1}`, ease: 'ease-in-out' }),
  static: () => ({ fn: () => ({}), kf: null, ease: null }),
};

// role → [family, entrance length (fraction of timeline), variants picked by seed]
export const ROLES = {
  bg: ['static', 0, []], glow: ['static', 0, []], rays: ['spin', 1, [12, 16, 20]], logo: ['static', 0, []], trust: ['static', 0, []],
  kicker: ['pop', .20, []], headline: ['pop', .28, []], sub: ['pop', .24, []], price: ['pop', .26, []],
  product: ['rise', .38, [380, 440, 500]], character: ['rise', .40, [360, 420, 480]],
  burst: ['burst', .16, []], sticker: ['pop', .22, []], confetti: ['fall', .58, [200, 240, 280]], badge: ['pop', .24, []], cta: ['pulse', 0, []],
};
// choreography per ad type: entrance order + spacing
export const CHOREO = {
  offer: { order: ['kicker', 'headline', 'sub', 'product', 'character', 'price', 'burst', 'badge', 'sticker', 'confetti', 'cta'], gap: .07, scale: 1.0 },
  carton: { order: ['product', 'kicker', 'headline', 'sub', 'character', 'price', 'burst', 'badge', 'sticker', 'confetti', 'cta'], gap: .07, scale: 1.0 },
  party: { order: ['kicker', 'headline', 'sub', 'burst', 'character', 'product', 'confetti', 'sticker', 'badge', 'price', 'cta'], gap: .05, scale: 0.9 },
  service: { order: ['character', 'headline', 'sub', 'kicker', 'product', 'sticker', 'badge', 'price', 'confetti', 'burst', 'cta'], gap: .08, scale: 1.1 },
  pair: { order: ['headline', 'sub', 'character', 'product', 'burst', 'badge', 'sticker', 'confetti', 'kicker', 'price', 'cta'], gap: .07, scale: 1.0 },
  hero: { order: ['product', 'headline', 'sub', 'kicker', 'character', 'price', 'badge', 'burst', 'sticker', 'confetti', 'cta'], gap: .07, scale: 1.0 },
};

function rng(seed) { let s = (seed * 9301 + 49297) % 233280; return () => { s = (s * 9301 + 49297) % 233280; return s / 233280; }; }
const uni = (rnd, a, b) => a + (b - a) * rnd();

/** One layer: { role, svg, cx, cy, preset?, dist?, delay?, stagger?, speed? } */
export function L(role, svg, cx, cy, kw = {}) { return { role, svg, cx, cy, ...kw }; }

function preset(fam, a, b, v) {
  if (fam === 'pop') return P.pop(a, b); if (fam === 'rise') return P.rise(a, b, v || 420); if (fam === 'drop') return P.drop(a, b, v || 380);
  if (fam === 'fall') return P.fall(a, b, v || 240); if (fam === 'burst') return P.burst(a, b); if (fam === 'spin') return P.spin(v || 16); if (fam === 'pulse') return P.pulse(a);
  return P.static();
}

export function choreograph(layers, adType = 'offer', seed = 1) {
  const rnd = rng(seed); const ch = CHOREO[adType] || CHOREO.offer; let t = 0.02 + uni(rnd, 0, 0.03); let starts = {};
  for (const role of ch.order) {
    if (!layers.some((l) => l.role === role)) continue; starts[role] = t; const [fam, ln] = ROLES[role];
    if (fam !== 'static' && fam !== 'spin') t += ln * ch.scale * 0.55 + ch.gap + uni(rnd, -0.01, 0.015);
  }
  const mx = Math.max(0, ...Object.values(starts)); if (mx > 0.66) for (const k in starts) starts[k] = starts[k] * 0.66 / mx;
  let moving = 0; const out = []; const count = {};
  for (const l of layers) {
    const [fam0, ln, variants] = ROLES[l.role] || ROLES.sticker; const fam = l.preset || fam0; const v = l.dist ?? (variants.length ? variants[Math.floor(rnd() * variants.length)] : null);
    const name = l.role + out.length;
    if (fam === 'static' || (moving >= MAX_MOVING && fam !== 'spin')) { out.push({ name, svg: l.svg, cx: l.cx, cy: l.cy, p: P.static() }); continue; }
    const k = count[l.role] || 0; count[l.role] = k + 1;
    let a = (starts[l.role] ?? 0.3) + k * (l.stagger ?? 0.06) + (l.delay ?? 0); const b = Math.min(0.97, a + ln * ch.scale * (l.speed ?? 1) + uni(rnd, -0.02, 0.02));
    if (fam === 'pulse') a = Math.min(0.8, a);
    out.push({ name, svg: l.svg, cx: l.cx, cy: l.cy, p: preset(fam, a, b, v) }); if (fam !== 'spin') moving++;
  }
  return out;
}

/** mode 'frame' → static SVG at time t (0..1); mode 'css' → animated SVG with keyframes. */
export function render(layers, W, H, bg, mode, t = 0) {
  const body = [], css = [];
  for (const Ly of layers) {
    if (mode === 'frame') {
      const v = Ly.p.fn(t); const s = v.s ?? 1, dx = v.dx ?? 0, dy = v.dy ?? 0, rot = v.rot ?? 0, op = v.op ?? 1;
      body.push(`<g transform="translate(${(Ly.cx + dx).toFixed(1)} ${(Ly.cy + dy).toFixed(1)}) scale(${s.toFixed(4)}) rotate(${rot.toFixed(2)}) translate(${(-Ly.cx).toFixed(1)} ${(-Ly.cy).toFixed(1)})" opacity="${op.toFixed(3)}">${Ly.svg}</g>`);
    } else {
      body.push(`<g class="L-${Ly.name}" style="transform-origin:${Ly.cx}px ${Ly.cy}px">${Ly.svg}</g>`);
      if (Ly.p.kf) css.push(`@keyframes k-${Ly.name}{${Ly.p.kf}} .L-${Ly.name}{animation:k-${Ly.name} ${DUR}s ${Ly.p.ease} 1 both}`);
    }
  }
  const style = mode === 'css' ? `<style>${css.join('')} @media (prefers-reduced-motion: reduce){[class^=L-]{animation:none!important}}</style>` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${style}<rect width="${W}" height="${H}" fill="${bg}"/>${body.join('')}</svg>`;
}
