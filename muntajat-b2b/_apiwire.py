#!/usr/bin/env python3
"""
Rewire the mirrored storefront from inlined demo data to the live sapconnect API.

The demo shipped its catalogue baked into three <script type="application/json">
tags and invented stock with a hash function. This script replaces that with a
fetch of /api/store/b2b/catalog and real per-showroom stock, leaving the app's
own code otherwise untouched.

What it changes, per page:
  1. empties the store / brands / showrooms JSON blobs (~700 KB of demo data)
  2. defers the app script until the API payload has arrived
  3. swaps stockFor() from the hash generator to real warehouse quantities
  4. guards mapSrc() against showrooms with no coordinates

Idempotent: re-running on an already-wired page is a no-op.

    python3 _apiwire.py [api_base]        default: https://sapapi.muntajat.sa
"""
import re
import sys
import os
import glob
import json

HERE = os.path.dirname(os.path.abspath(__file__))
PAGES = ['index.html', 'store-demo.html']
API_BASE = sys.argv[1] if len(sys.argv) > 1 else 'https://sapapi.muntajat.sa'
MARK = 'data-b2b-wired'

BOOT = """<script id="b2b-boot">
/* Catalogue comes from sapconnect at runtime — nothing is stored in this page.
   Prices are SAP price list 2 ("Retail PL - Muntajat"); wholesale never leaves
   the server. See B2bCatalogController. */
(function () {
  /* Tries the deployed backend first, then a local `php artisan serve`, so the
     page works both in production and while the endpoint is still being rolled
     out. ?api=<base> forces one specific backend. */
  var forced = new URLSearchParams(location.search).get('api');
  var bases = forced ? [forced] : [%(api)r, 'http://127.0.0.1:8123'];

  function note(msg, bad) {
    var el = document.getElementById('b2b-status') || (function () {
      var d = document.createElement('div');
      d.id = 'b2b-status';
      d.style.cssText = 'padding:14px 18px;font:600 14px/1.7 system-ui,sans-serif;' +
        'text-align:center;position:relative;z-index:99';
      document.body.insertAdjacentElement('afterbegin', d);
      return d;
    })();
    el.style.background = bad ? '#fbe9e7' : '#eef4fb';
    el.style.color = bad ? '#8a2c1d' : '#24507f';
    el.innerHTML = msg;
  }

  function boot(d) {
    window.B2B_API = d.__base;                 // productView() lazy-loads from here
    d.store.stats = d.stats || {};             // headline figures ride along with S
    document.getElementById('store').textContent = JSON.stringify(d.store);
    document.getElementById('brands').textContent = JSON.stringify(d.brands);
    document.getElementById('showrooms').textContent = JSON.stringify(d.showrooms);
    var s = document.createElement('script');
    s.textContent = document.getElementById('b2b-app').textContent;
    document.body.appendChild(s);
    var el = document.getElementById('b2b-status');
    if (el) el.remove();
  }

  function attempt(i) {
    if (i >= bases.length) {
      note('تعذّر تحميل الكتالوج من sapconnect.<br>' +
           'جرّبنا: ' + bases.join(' ثم ') + '<br>' +
           'شغّل الباك-إند: <code>php artisan serve --port=8123</code>' +
           ' أو انشر الـendpoint على الخادم.', true);
      return;
    }
    note('جارٍ تحميل الكتالوج من ' + bases[i] + ' …', false);
    fetch(bases[i] + '/api/store/b2b/catalog', {cache: 'no-store'})
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(function (d) { d.__base = bases[i]; boot(d); })
      .catch(function () { attempt(i + 1); });
  }

  attempt(0);
})();
</script>"""

# Real per-showroom stock, keyed by SAP warehouse code, replacing the FNV hash
# that the demo used to fabricate quantities.
STOCK_FN = ("function stockFor(id,li){var p=S.products[id];var w=SHOW[li];"
            "if(!p||!w||!p.stock)return 0;return +(p.stock[w.code]||0);}")

# Showrooms have no coordinates in SAP; '' lets the caller drop the map frame
# instead of rendering a NaN bounding box.
MAP_GUARD = ("function mapSrc(i){const s=SHOW[i];"
             "if(!s||s.lat==null||s.lng==null)return '';")

# The home page repeated its headline figures as literals inside the copy as
# well as in the stat tiles. Turn the copy into tokens that B2B_APPLY_STATS()
# fills from the feed once it arrives.
STAT_TOKENS = {
    # `brands` is every brand carried; exclusivity is not recorded anywhere in
    # sapconnect, so the label must not assert it.
    "hp_st_brands:'Exclusive brands'": "hp_st_brands:'Brands carried'",
    "hp_st_brands:'علامة حصرية'": "hp_st_brands:'علامة تجارية'",
    # the figure is the registered trade-account total, not a 24-month cohort
    "hp_st_acct:'B2B accounts · 24 mo'": "hp_st_acct:'B2B accounts'",
    "hp_st_acct:'حساب B2B · 24 شهر'": "hp_st_acct:'حساب تجاري'",
    '880+ pet businesses': '{{accounts}} pet businesses',
    'أكثر من 880 نشاطاً':  '{{accounts}} نشاطاً',
    '38 exclusive brands and 4,452 active SKUs': '{{brands}} brands and {{products}} active SKUs',
    'لـ38 علامة حصرية و4,452 رمز تخزين فعّال': 'لـ{{brands}} علامة و{{products}} رمز تخزين فعّال',
    'Live stock · 10 showrooms': 'Live stock · {{showrooms}} showrooms',
    'مخزون مباشر · 10 معارض':    'مخزون مباشر · {{showrooms}} معرض',
}
STAT_TEXT = re.compile('|'.join(re.escape(k) for k in STAT_TOKENS))

STATS_JS = """
/* Headline figures come from the feed. The tiles read B2B_STAT(); the hero copy
   carries {{token}} placeholders that are filled in once, before first render.
   `brands` counts every brand carried — exclusivity is not recorded anywhere,
   so the copy must not claim it. */
function B2B_STAT(key, fallback){
  const v = (typeof S !== 'undefined' && S.stats) ? S.stats[key] : null;
  return (v === null || v === undefined) ? fallback : v;
}
function B2B_APPLY_STATS(){
  const s = (typeof S !== 'undefined' && S.stats) || {};
  const map = {
    accounts:  s.accounts,
    brands:    s.brands,
    products:  s.products,
    showrooms: s.showrooms,
  };
  Object.keys(UI).forEach(function (lng) {
    const dict = UI[lng];
    Object.keys(dict).forEach(function (k) {
      if (typeof dict[k] !== 'string' || dict[k].indexOf('{{') < 0) return;
      dict[k] = dict[k].replace(/\\{\\{(\\w+)\\}\\}/g, function (m, name) {
        const v = map[name];
        return (v === null || v === undefined) ? '' : Number(v).toLocaleString(
          lng === 'ar' ? 'ar-EG' : 'en-US');
      });
    });
  });
}
"""

MAP_FRAME = ('<div class="loc-map"><iframe id="locframe" title="Showroom map" '
             'loading="lazy" referrerpolicy="no-referrer-when-downgrade" '
             'src="${mapSrc(0)}"></iframe></div>')

# Features, ingredients and nutrition are far too bulky to ship for every
# product, so the catalogue carries only an `enr` flag and the copy is fetched
# when a product page is actually opened, then merged in and re-rendered.
LAZY_ENRICHMENT = """
function productView(id){
  const p = S.products && S.products[id];
  if (p && p.enr && !p._enrLoaded) {
    p._enrLoaded = 1;
    fetch((window.B2B_API || '') + '/api/store/b2b/product/' + encodeURIComponent(id),
          {cache: 'no-store'})
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d) return;
        Object.assign(p, d);
        if ((location.hash || '').indexOf('/p/' + id) >= 0) productViewRender(id);
      })
      .catch(function () { p._enrLoaded = 0; });   // let a later visit retry
  }
  return productViewRender(id);
}
"""


def depot_page_slugs():
    """Cash-and-carry pages that exist on disk.

    SAP has five Riyadh branches which all slug to "riyadh", and there is no
    riyadh.html — the published site had pages for two Riyadh districts that
    match none of them. Those branches fall back to the in-app showrooms view.
    """
    return sorted(
        os.path.basename(p)[:-5]
        for p in glob.glob(os.path.join(HERE, 'cash-and-carry', '*.html'))
        if os.path.basename(p) != 'index.html'
    )


def brand_page_slugs():
    """Slugs that actually have a static page on disk.

    The demo generated a brand page for every brand it shipped, so the app
    could assume "brand has products" meant "brand has a page". The live
    catalogue carries far more brands than there are pages, so that assumption
    now produces links to files that do not exist.
    """
    out = set()
    for p in glob.glob(os.path.join(HERE, 'brands', '*.html')):
        name = os.path.basename(p)[:-5]
        if name != 'index' and not name.endswith('-ar'):
            out.add(name)
    return sorted(out)


def replace_fn(src, decl, body):
    """Replace a whole JS function by brace matching (a lazy regex stops at the
    first inner `}` and silently truncates the body)."""
    i = src.find(decl)
    if i < 0:
        return src, 0
    j = src.index('{', i)
    depth, k, instr, esc = 0, j, None, False
    while k < len(src):
        c = src[k]
        if instr:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == instr:
                instr = None
        elif c in '"\'`':
            instr = c
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                break
        k += 1
    return src[:i] + body + src[k + 1:], 1


def patch(path):
    html = open(path, encoding='utf-8').read()
    if MARK in html:
        return 'already wired'

    out = html
    changes = []

    # 1. drop the baked catalogue
    for blob in ('store', 'brands', 'showrooms'):
        new, n = re.subn(
            r'(<script id="%s" type="application/json">).*?(</script>)' % blob,
            r'\1\2', out, flags=re.S)
        if not n:
            raise SystemExit(f'{path}: could not find the "{blob}" data blob')
        out = new
        changes.append(blob)

    # 2. hold the app script back until the payload lands
    new, n = re.subn(r'<script>(?=\s*/\*|\s*const|\s*\(function|\s*var|\s*!)',
                     '<script id="b2b-app" type="application/x-b2b-app">',
                     out, count=1)
    if not n:
        raise SystemExit(f'{path}: could not find the app script tag')
    out = new

    # 3. real stock instead of the hash generator
    out, n = replace_fn(out, 'function stockFor(id,li)', STOCK_FN)
    if not n:
        raise SystemExit(f'{path}: could not find stockFor()')
    changes.append('stockFor')

    # 4. no coordinates -> no map frame
    new, n = re.subn(r'function mapSrc\(i\)\{const s=SHOW\[i\];', MAP_GUARD,
                     out, count=1)
    if not n:
        raise SystemExit(f'{path}: could not find mapSrc()')
    out = new
    changes.append('mapSrc')

    # 5. only link to a brand page that exists; the rest open the in-app
    #    brand view (#/brand/<name>) the app already implements
    slugs = brand_page_slugs()
    # SAP and the page filenames disagree on word breaks ("My Family" vs
    # myfamily.html, "Babin" vs bab-in.html), so match on the slug with the
    # separators dropped as well.
    helper = ('\nconst B2B_BRAND_PAGES = %s;\n'
              'const B2B_BRAND_TIGHT = {};\n'
              'Object.keys(B2B_BRAND_PAGES).forEach(function(k){\n'
              '  B2B_BRAND_TIGHT[k.replace(/-/g, "")] = k;\n'
              '});\n'
              'function B2B_PAGEFOR(name){\n'
              '  const s = slug(name);\n'
              '  if (B2B_BRAND_PAGES[s]) return s;\n'
              '  return B2B_BRAND_TIGHT[s.replace(/-/g, "")] || null;\n'
              '}\n'
              'function B2B_HASPAGE(name){ return !!B2B_PAGEFOR(name); }\n'
              'const B2B_DEPOT_PAGES = %s;\n'
              '/* Six branches share the city "Riyadh", so a branch page is named\n'
              '   <city> when the city has one branch and <city>-<branch> when it\n'
              '   has several — the same rule _genbranches.py files them under. */\n'
              'function B2B_DEPOT(s){\n'
              '  if (!s) return "#/showrooms";\n'
              '  const city = slug(s.city);\n'
              '  const long = city + "-" + slug(s.name);\n'
              '  if (B2B_DEPOT_PAGES[long]) return "cash-and-carry/" + long + ".html";\n'
              '  if (B2B_DEPOT_PAGES[city]) return "cash-and-carry/" + city + ".html";\n'
              '  return "#/showrooms";\n'
              '}\n'
              '/* Pins on the Saudi map were a fixed array of 10 positions, one per\n'
              '   demo branch, indexed by position. The live branch list is a\n'
              '   different set in a different order, so every pin sat on the wrong\n'
              '   city — and an 11th branch read past the end of the array and threw.\n'
              '   Project from the branch coordinates instead. The constants are a\n'
              '   least-squares fit of the original ten pins against their real\n'
              '   lat/lng (equirectangular, max residual 0.7px). */\n'
              'function B2B_PIN(s, i){\n'
              '  if (s && s.lng != null && s.lat != null)\n'
              '    return [48.2626 * s.lng - 1665.1798, -54.6557 * s.lat + 1823.3191];\n'
              '  return (typeof PINXY !== "undefined" && PINXY[i]) || null;\n'
              '}\n'
              '/* Brand logos follow a filename convention and about one in six\n'
              '   has no file. Fall back to a product photo before giving up, so\n'
              '   a brand card shows something rather than an empty box. */\n'
              'function B2B_LOGOALT(b){\n'
              '  const id = (b && b.ids || [])[0];\n'
              '  const p = id && S.products[id];\n'
              '  return p ? p.img : "";\n'
              '}\n'
              'function B2B_LOGOERR(im, alt){\n'
              '  if (alt && im.getAttribute("src") !== alt) { im.src = alt; return; }\n'
              '  im.onerror = null; im.style.visibility = "hidden";\n'
              '}\n'
              % (json.dumps({s: 1 for s in slugs}),
                 json.dumps({s: 1 for s in depot_page_slugs()})))
    before = out
    out = out.replace('const has=b.ids.length>0;', 'const has=B2B_HASPAGE(b.name);')
    out = out.replace('b.logo&&b.ids.length', 'b.logo&&B2B_HASPAGE(b.name)')
    # and point the href at the file that exists, not at the raw slug
    out = out.replace('brands/${slug(b.name)}.html', 'brands/${B2B_PAGEFOR(b.name)}.html')
    out = out.replace('cash-and-carry/${slug(s.city)}.html', '${B2B_DEPOT(s)}')
    # 5b. the home-page headline figures were literals (22 / 38 / 4,452 / 880+).
    #     Only the showroom count was ever computed. Take them all from the feed.
    before_stats = out
    out = out.replace("${stS(22,'',t.hp_st_years)}", "${stS(B2B_STAT('years',22),'',t.hp_st_years)}")
    out = out.replace("${stS(38,'',t.hp_st_brands)}", "${stS(B2B_STAT('brands',BRANDS.length),'',t.hp_st_brands)}")
    out = out.replace("${stS(4452,'',t.hp_st_prod)}",
                      "${stS(B2B_STAT('products',Object.keys(S.products).length),'',t.hp_st_prod)}")
    out = out.replace("${stS(880,'+',t.hp_st_acct)}", "${stS(B2B_STAT('accounts',0),'',t.hp_st_acct)}")
    if out == before_stats:
        raise SystemExit(f'{path}: could not find the home-page stat literals')
    # the same numbers are spelled out again in the hero copy
    out = STAT_TEXT.sub(lambda m: STAT_TOKENS[m.group(0)], out)
    # Fill the copy tokens before the first render. `setLang();route();` appears
    # twice — once in the language toggle, once as the bootstrap on the last
    # line — and it is the bootstrap that matters, so patch both rather than
    # guessing an index. Re-applying is a no-op: substituted strings no longer
    # contain a token.
    out, n = re.subn(r'\bsetLang\(\);route\(\);', 'B2B_APPLY_STATS();setLang();route();', out)
    if n < 2:
        raise SystemExit(f'{path}: expected the bootstrap and the language toggle, found {n}')
    changes.append('home stats')

    # brand logo: try the logo, then a product photo, then hide
    out = out.replace('src="${esc(b.logo)}"${IE}',
                      'src="${esc(b.logo)}" onerror="B2B_LOGOERR(this,\'${esc(B2B_LOGOALT(b))}\')"')

    # map pins follow the branch coordinates rather than a fixed array
    before_pin = out
    out = out.replace('const xy=PINXY[i];return ',
                      "const xy=B2B_PIN(s,i);if(!xy)return '';return ")
    if out == before_pin:
        raise SystemExit(f'{path}: could not find the map-pin lookup')
    changes.append('map pins')
    if out == before:
        raise SystemExit(f'{path}: could not find the brand-link conditions')
    changes.append(f'brand links ({len(slugs)} pages)')

    # 6. lazy-load the marketing copy when a product page opens
    new, n = re.subn(r'function productView\(id\)\{',
                     'function productViewRender(id){', out, count=1)
    if not n:
        raise SystemExit(f'{path}: could not find productView()')
    # append inside the app script specifically — the empty JSON blobs above it
    # also end in </script>, so a plain replace would land in the wrong block
    # Prepend, don't append: the app calls route() on its last line, and a
    # `const` declared after that call is still in the temporal dead zone when
    # the first render reads it. Function declarations hoist either way.
    extra = helper + STATS_JS + LAZY_ENRICHMENT
    out, n = re.subn(r'(<script id="b2b-app"[^>]*>)(.*?)(</script>)',
                     lambda m: m.group(1) + extra + m.group(2) + m.group(3),
                     new, count=1, flags=re.S)
    if not n:
        raise SystemExit(f'{path}: could not extend the app script')
    changes.append('lazy enrichment')

    # 6. drop the map frame entirely when the showroom has no coordinates,
    #    rather than pointing an iframe at an empty src
    if MAP_FRAME in out:
        out = out.replace(MAP_FRAME, "${mapSrc(0)?`" + MAP_FRAME + "`:''}", 1)
        changes.append('map frame')

    out = out.replace('</body>', (BOOT % {'api': API_BASE}) + '\n</body>', 1)
    out = out.replace('<html ', '<html %s ' % MARK, 1)

    open(path, 'w', encoding='utf-8').write(out)
    before = len(html.encode())
    after = len(out.encode())
    return (f'wired ({", ".join(changes)}) — '
            f'{before:,} -> {after:,} bytes '
            f'({(before - after) / 1024:.0f} KB of demo data removed)')


if __name__ == '__main__':
    print(f'API base: {API_BASE}')
    for p in PAGES:
        full = os.path.join(HERE, p)
        if not os.path.exists(full):
            print(f'  {p}: MISSING')
            continue
        print(f'  {p}: {patch(full)}')
