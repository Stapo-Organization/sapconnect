"""Minimal inline-SVG chart helpers following the dataviz skill (thin marks, hairline grid, selective labels, hover layer via data attrs)."""
from __future__ import annotations
import math, html

def esc(s): return html.escape(str(s), quote=True)
def fmt(n, d=0):
    try: n = float(n)
    except Exception: return "—"
    if math.isnan(n): return "—"
    return f"{n:,.{d}f}"

def nice_ticks(vmax, n=4):
    if vmax <= 0: return [0]
    raw = vmax / n; mag = 10 ** math.floor(math.log10(raw)); r = raw / mag
    step = (1 if r <= 1 else 2 if r <= 2 else 2.5 if r <= 2.5 else 5 if r <= 5 else 10) * mag
    return [i * step for i in range(int(vmax // step) + 2)]

def bar_h(rows, *, width=760, bar=14, gap=10, label_w=230, value_fmt=lambda v: fmt(v), color="var(--series-1)", title=None, max_val=None, hover_key="value"):
    """rows: list of (label, value[, tooltip]) → horizontal bars, value at the tip, hit target per bar."""
    n = len(rows); h = n * (bar + gap) + 30; pw = width - label_w - 80
    vmax = max_val or max([r[1] for r in rows] + [1])
    ticks = nice_ticks(vmax); vmax = ticks[-1] if ticks[-1] >= vmax else vmax
    sx = lambda v: label_w + (v / vmax) * pw
    out = [f'<svg class="chart" viewBox="0 0 {width} {h}" width="100%" role="img" aria-label="{esc(title or "")}" direction="ltr">']
    for t in ticks:
        x = sx(t); out.append(f'<line x1="{x:.1f}" y1="8" x2="{x:.1f}" y2="{h-22}" class="grid"/><text x="{x:.1f}" y="{h-8}" class="tick" text-anchor="middle">{fmt(t)}</text>')
    for i, r in enumerate(rows):
        lab, val = r[0], r[1]; tip = r[2] if len(r) > 2 else f"{lab}: {value_fmt(val)}"
        y = 10 + i * (bar + gap); w = max(0.0, sx(val) - label_w)
        out.append(f'<g class="hit" data-tip="{esc(tip)}"><rect x="{label_w}" y="{y-4}" width="{pw+60}" height="{bar+8}" fill="transparent"/>')
        out.append(f'<rect x="{label_w}" y="{y}" width="{w:.1f}" height="{bar}" rx="0" fill="{color}" class="bar"/>')
        if w > 8: out.append(f'<rect x="{label_w + max(0, w-4):.1f}" y="{y}" width="{min(4,w):.1f}" height="{bar}" rx="3" fill="{color}" class="bar"/>')
        out.append(f'<text x="{label_w-8}" y="{y+bar-3}" class="lab" text-anchor="end">{esc(lab)}</text>')
        out.append(f'<text x="{label_w + w + 6:.1f}" y="{y+bar-3}" class="val">{esc(value_fmt(val))}</text></g>')
    out.append('</svg>'); return "".join(out)

def line_chart(series, *, width=760, height=240, xlabels=None, title=None, y_fmt=lambda v: fmt(v), legend=True, markers=False):
    """series: list of dicts {name, values (list of float|None), color}. xlabels: list of str (same length)."""
    n = max(len(s["values"]) for s in series); L, R, T, B = 52, 16, 14, 34; pw, ph = width - L - R, height - T - B
    vmax = max([v for s in series for v in s["values"] if v is not None] + [1]); ticks = nice_ticks(vmax); vmax = ticks[-1]
    sx = lambda i: L + (i / max(n - 1, 1)) * pw; sy = lambda v: T + ph - (v / vmax) * ph
    out = [f'<svg class="chart linechart" viewBox="0 0 {width} {height}" width="100%" role="img" aria-label="{esc(title or "")}" direction="ltr" data-n="{n}" data-l="{L}" data-pw="{pw:.1f}">']
    for t in ticks: out.append(f'<line x1="{L}" y1="{sy(t):.1f}" x2="{L+pw}" y2="{sy(t):.1f}" class="grid"/><text x="{L-6}" y="{sy(t)+4:.1f}" class="tick" text-anchor="end">{y_fmt(t)}</text>')
    if xlabels:
        step = max(1, n // 8)
        for i in range(0, n, step): out.append(f'<text x="{sx(i):.1f}" y="{height-10}" class="tick" text-anchor="middle">{esc(xlabels[i])}</text>')
    for s in series:
        pts = [(sx(i), sy(v)) for i, v in enumerate(s["values"]) if v is not None]
        if not pts: continue
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        out.append(f'<path d="{d}" fill="none" stroke="{s["color"]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>')
        if s.get("area"): out.append(f'<path d="{d} L{pts[-1][0]:.1f},{sy(0):.1f} L{pts[0][0]:.1f},{sy(0):.1f} Z" fill="{s["color"]}" opacity="0.10"/>')
        if markers:
            for x, y in pts: out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="{s["color"]}" stroke="var(--surface-1)" stroke-width="2"/>')
        x, y = pts[-1]; out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="{s["color"]}" stroke="var(--surface-1)" stroke-width="2"/>')
    # crosshair + tooltip layer (JS fills)
    data = esc(__import__("json").dumps({"x": xlabels or list(range(n)), "s": [{"n": s["name"], "v": s["values"], "c": s["color"]} for s in series]}, ensure_ascii=False))
    out.append(f'<line class="xhair" x1="0" y1="{T}" x2="0" y2="{T+ph}" style="display:none"/><rect class="hitall" x="{L}" y="{T}" width="{pw:.1f}" height="{ph:.1f}" fill="transparent" data-series="{data}"/>')
    out.append('</svg>')
    if legend and len(series) >= 2:
        out.append('<div class="legend">' + "".join(f'<span><i style="background:{s["color"]}"></i>{esc(s["name"])}</span>' for s in series) + '</div>')
    return "".join(out)

def sparkline(values, *, width=220, height=48, color="var(--series-1)", marks=None):
    n = len(values); vmax = max([v for v in values if v is not None] + [1]); 
    sx = lambda i: 4 + (i / max(n - 1, 1)) * (width - 8); sy = lambda v: height - 6 - (v / vmax) * (height - 12)
    pts = [(sx(i), sy(v)) for i, v in enumerate(values) if v is not None]
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) if pts else ""
    out = [f'<svg viewBox="0 0 {width} {height}" width="{width}" height="{height}" class="spark" direction="ltr"><line x1="4" y1="{sy(0):.1f}" x2="{width-4}" y2="{sy(0):.1f}" class="grid"/><path d="{d}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/>']
    for i in (marks or []):
        if 0 <= i < n and values[i] is not None: out.append(f'<circle cx="{sx(i):.1f}" cy="{sy(values[i]):.1f}" r="3" fill="var(--series-2)" stroke="var(--surface-1)" stroke-width="1.5"/>')
    out.append('</svg>'); return "".join(out)
