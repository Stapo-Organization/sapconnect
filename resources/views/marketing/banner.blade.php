<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<style>
@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&display=swap');
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:{{ $w }}px;height:{{ $h }}px;overflow:hidden;font-family:'Cairo',sans-serif}
.banner{
  position:relative;width:{{ $w }}px;height:{{ $h }}px;overflow:hidden;
  background:linear-gradient(135deg,{{ $accent }},{{ $accentDark }});
  -webkit-print-color-adjust:exact;print-color-adjust:exact;
}
@if($baseImage)
.bg{position:absolute;inset:0;background-image:url('file://{{ $baseImage }}');background-size:cover;background-position:center}
@endif
.scrim{position:absolute;inset:0;
  background:linear-gradient(270deg, rgba(8,30,40,.82) 0%, rgba(8,30,40,.55) 45%, rgba(8,30,40,.10) 100%);}
.content{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;
  padding:{{ max(24, intval($h*0.12)) }}px {{ max(28, intval($w*0.045)) }}px;gap:{{ max(6, intval($h*0.03)) }}px;color:#fff;
  width:{{ $format==='card' ? '100%' : '62%' }};}
.headline{font-weight:900;line-height:1.2;text-shadow:0 2px 14px rgba(0,0,0,.35);
  font-size:{{ max(20, intval($h*0.16)) }}px;}
.sub{font-weight:600;opacity:.92;line-height:1.5;
  font-size:{{ max(12, intval($h*0.072)) }}px;}
.cta{display:inline-flex;align-items:center;gap:8px;align-self:flex-start;margin-top:{{ max(6, intval($h*0.04)) }}px;
  background:{{ $accent }};color:#fff;font-weight:800;border-radius:999px;
  padding:{{ max(7, intval($h*0.035)) }}px {{ max(16, intval($h*0.09)) }}px;
  font-size:{{ max(12, intval($h*0.075)) }}px;box-shadow:0 6px 18px rgba(0,0,0,.25);}
.badge{position:absolute;top:{{ max(12, intval($h*0.06)) }}px;inset-inline-end:{{ max(12, intval($h*0.06)) }}px;
  background:#F4BE2C;color:#143966;font-weight:900;border-radius:999px;
  padding:{{ max(5, intval($h*0.03)) }}px {{ max(12, intval($h*0.06)) }}px;
  font-size:{{ max(11, intval($h*0.07)) }}px;box-shadow:0 4px 12px rgba(0,0,0,.25);}
.logo{position:absolute;bottom:{{ max(12, intval($h*0.05)) }}px;inset-inline-end:{{ max(16, intval($w*0.03)) }}px;
  color:#fff;font-weight:900;opacity:.92;letter-spacing:.5px;font-size:{{ max(12, intval($h*0.06)) }}px;
  display:flex;align-items:center;gap:6px;}
.logo .dot{width:{{ max(7, intval($h*0.035)) }}px;height:{{ max(7, intval($h*0.035)) }}px;border-radius:50%;background:#F4BE2C;display:inline-block}
@if($productImage)
.product{position:absolute;inset-inline-start:{{ max(20, intval($w*0.03)) }}px;top:50%;transform:translateY(-50%);
  height:{{ intval($h*0.78) }}px;width:{{ intval($w*0.34) }}px;
  background-image:url('{{ $productImage }}');background-size:contain;background-repeat:no-repeat;background-position:center;
  filter:drop-shadow(0 12px 24px rgba(0,0,0,.35));}
@endif
</style>
</head>
<body>
<div class="banner">
  @if($baseImage)<div class="bg"></div>@endif
  <div class="scrim"></div>
  @if($productImage)<div class="product"></div>@endif
  <div class="content">
    @if($headline)<div class="headline">{{ $headline }}</div>@endif
    @if($subheadline)<div class="sub">{{ $subheadline }}</div>@endif
    @if($cta)<div class="cta">{{ $cta }} <span>←</span></div>@endif
  </div>
  @if($badge)<div class="badge">{{ $badge }}</div>@endif
  <div class="logo"><span class="dot"></span> منتجات</div>
</div>
</body>
</html>
