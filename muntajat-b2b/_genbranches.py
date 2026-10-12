#!/usr/bin/env python3
"""
Generate a cash-and-carry page for every real SAP branch.

The published storefront shipped ten branch pages — for Khobar, Buraydah, Hafar
Al Batin and two Riyadh districts that no longer exist in SAP, alongside five
that do. SAP and zooboxi_warehouses between them describe eleven real branches.

This rebuilds the set from live data, using khobar.html as the structural
template so the pages keep the same layout, map, hours block and FAQ.

Per branch, from real data:
  Arabic and English name, city, region, address, coordinates (real map and pin),
  the in-stock product grid for that branch only, the category chips, the
  live in-stock count, and the "other branches" cross-links.

Pages for branches that are not in SAP are removed, and any page still linking
to them is repointed.

    python3 _genbranches.py [api_base]
"""
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, 'cash-and-carry')
API_BASE = sys.argv[1] if len(sys.argv) > 1 else 'https://sapapi.muntajat.sa'
LOCAL_API = 'http://127.0.0.1:8123'
GEN_MARK = '<!-- generated-from-sapconnect -->'
# The template lives outside cash-and-carry/ because that directory is
# rebuilt from scratch on every run — keeping it inside meant the second run
# had no template left.
TEMPLATE = os.path.join(HERE, '_branch-template.html')
MAX_CARDS = 144          # what the template shipped; keeps the page ~90 KB


def esc(s):
    return (str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            .replace('"', '&quot;').replace("'", '&#x27;'))


def slug(s):
    return re.sub(r'(^-|-$)', '', re.sub(r'[^a-z0-9]+', '-', str(s).lower()))


def branch_slug(s):
    """Riyadh has six branches, so the city alone is not a unique filename."""
    city = slug(s['city'])
    same_city = branch_slug.counts.get(city, 0)
    return city if same_city == 1 else f"{city}-{slug(s['name'])}"


def fetch():
    # An explicit base wins; otherwise try local first, then production. The
    # local warehouses table can lag production, so pass the live URL when the
    # branch list matters.
    bases = [sys.argv[1]] if len(sys.argv) > 1 else [LOCAL_API, API_BASE]
    for base in bases:
        try:
            with urllib.request.urlopen(base + '/api/store/b2b/catalog', timeout=300) as r:
                print(f'  catalogue from {base}')
                return json.loads(r.read())
        except Exception:
            continue
    raise SystemExit('catalogue API unreachable — start `php artisan serve --port=8123`')


def replace_div(html, opening, inner):
    """Swap a <div>'s contents by counting tags; the product cards nest divs so
    a lazy regex would stop inside the first one."""
    i = html.find(opening)
    if i < 0:
        raise SystemExit(f'template missing: {opening}')
    start = i + len(opening)
    depth, k, end = 1, start, None
    tag = re.compile(r'<(/?)div\b', re.I)
    while depth:
        m = tag.search(html, k)
        if not m:
            raise SystemExit(f'unbalanced div after {opening}')
        depth += -1 if m.group(1) else 1
        k = m.end()
        if depth == 0:
            end = m.start()
    return html[:start] + inner + html[end:]


def make(tpl, s, products, catlabels, others, total_branches):
    name, name_ar = s['name'], s['name_ar'] or s['name']
    city, city_ar = s['city'], s['city_ar'] or s['city']
    region = s['region'] or ''
    code = s['code']
    url = f"https://muntajat-b2b.netlify.app/cash-and-carry/{branch_slug(s)}.html"

    # products actually in stock at this branch
    here = [p for p in products if float((p['stock'] or {}).get(code, 0)) > 0]
    here.sort(key=lambda p: -float(p['stock'][code]))
    shown = here[:MAX_CARDS]

    by_cat = {}
    for p in here:
        by_cat.setdefault(next(iter(p['cats'].values()), 'Other'), []).append(p)
    brands = len({p['b'] for p in here if p['b']})

    h = tpl
    title = f'Muntajat Cash &amp; Carry — {esc(name)} | Wholesale Pet Supplies'
    desc = (f'Muntajat cash &amp; carry in {esc(city)} — {len(here):,} products in stock '
            f'from {brands} brands. Wholesale pet food, supplies and grooming. '
            f'Trade and retail buyers welcome.')

    h = re.sub(r'<title>.*?</title>', f'<title>{title}</title>', h, count=1, flags=re.S)
    for prop, val in (('name="description"', desc), ('property="og:title"', title),
                      ('property="og:description"', desc), ('property="og:url"', esc(url))):
        h = re.sub(r'(<meta %s content=")[^"]*(")' % prop,
                   lambda m: m.group(1) + val + m.group(2), h, count=1)
    h = re.sub(r'(<link rel="canonical" href=")[^"]*(")',
               lambda m: m.group(1) + esc(url) + m.group(2), h, count=1)

    # breadcrumb + hero
    h = re.sub(r"(<nav class=\"crumb\">.*?·\s*)Khobar(</nav>)",
               lambda m: m.group(1) + esc(name) + m.group(2), h, count=1, flags=re.S)
    h = re.sub(r'<div class="kicker">.*?</div>',
               f'<div class="kicker">Cash &amp; Carry · {esc(region)}</div>', h, count=1, flags=re.S)
    h = re.sub(r'<h1>.*?</h1>', f'<h1>{esc(name)}</h1>', h, count=1, flags=re.S)
    h = re.sub(r'<div class="h1ar">.*?</div>',
               f'<div class="h1ar">كاش آند كاري منتجات — {esc(name_ar)}</div>', h, count=1, flags=re.S)
    h = re.sub(r'<div class="livebadge">.*?</div>',
               f'<div class="livebadge"><span class="live-dot"></span><b>{len(here):,}</b> '
               f'of {len(products):,} products in stock now</div>', h, count=1, flags=re.S)
    h = re.sub(r'<p class="lede">.*?</p>',
               f'<p class="lede">Wholesale pet food, supplies, grooming and accessories from '
               f'{brands} brands — in stock daily in {esc(city)}. Trade and retail buyers '
               f'welcome.</p>', h, count=1, flags=re.S)

    # map + directions
    if s['lat'] is not None and s['lng'] is not None:
        lat, lng = s['lat'], s['lng']
        bbox = f'{lng - .045:.4f},{lat - .03:.4f},{lng + .045:.4f},{lat + .03:.4f}'
        h = re.sub(r'(<iframe loading="lazy" title=")[^"]*(" referrerpolicy="[^"]*" src=")[^"]*(")',
                   lambda m: (m.group(1) + f'Map of Muntajat {esc(name)}' + m.group(2)
                              + f'https://www.openstreetmap.org/export/embed.html?bbox={bbox}'
                                f'&amp;layer=mapnik&amp;marker={lat},{lng}' + m.group(3)),
                   h, count=1)
    if s['map']:
        h = re.sub(r'(href=")https://maps\.app\.goo\.gl/[^"]*(")',
                   lambda m: m.group(1) + esc(s['map']) + m.group(2), h)
    else:  # no shortlink recorded — point at the coordinates instead
        if s['lat'] is not None:
            h = re.sub(r'(href=")https://maps\.app\.goo\.gl/[^"]*(")',
                       lambda m: m.group(1)
                       + f'https://www.google.com/maps/search/?api=1&amp;query={s["lat"]},{s["lng"]}'
                       + m.group(2), h)

    # facts strip
    h = re.sub(r'(<span class="lf-lbl">Address</span><div class="lf-v">)[^<]*(</div><div class="ar">)[^<]*(</div>)',
               lambda m: m.group(1) + esc(s['addr'] or city) + m.group(2)
               + esc(s['addr_ar'] or city_ar) + m.group(3), h, count=1)
    h = re.sub(r'(<span class="lf-lbl">Region</span><div class="lf-v">)[^<]*(</div>)',
               lambda m: m.group(1) + esc(region) + m.group(2), h, count=1)
    if s.get('phone'):
        h = re.sub(r'https://wa\.me/\d+', 'https://wa.me/' + str(s['phone']), h)

    # category chips
    chips = [f'<button class="lc on" type="button" data-filter="all" onclick="filterCat(this)">'
             f'<span class="lc-n">All</span><span class="lc-c">{len(here):,}</span></button>']
    for cat, items in sorted(by_cat.items(), key=lambda kv: -len(kv[1])):
        animal = next(iter(items[0]['pets']), '')
        chips.append(
            f'<button class="lc" type="button" data-filter="{esc(cat)}" data-full="{len(items)}" '
            f'data-label="{esc(cat)}" data-href="/store-demo.html#/c/{esc(animal)}/{esc(cat)}" '
            f'onclick="filterCat(this)"><span class="lc-n">{esc(cat)}</span>'
            f'<span class="lc-c">{len(items)}</span></button>')
    h = replace_div(h, '<div class="loc-cats" id="catfilter">', ''.join(chips))

    # product grid — this branch's stock only
    cards = []
    for p in shown:
        cat = next(iter(p['cats'].values()), 'Other')
        cards.append(
            f"<a class='lp' data-cat='{esc(cat)}' href='/store-demo#/p/{p['id']}'>"
            f'<div class="lp-im"><img loading="lazy" src="{esc(p["img"])}" alt="{esc(p["t"])}"></div>'
            f'<div class="lp-b"><div class="lp-nm">{esc(p["t"])}</div>'
            f'<div class="lp-pr"></div></div></a>')
    h = replace_div(h, '<div class="loc-prods" id="prodgrid">', ''.join(cards)) \
        if '<div class="loc-prods" id="prodgrid">' in h \
        else replace_div(h, '<div class="loc-prods">', ''.join(cards))

    # other branches
    ocards = ''.join(
        f"<a class='ocard' href='/cash-and-carry/{branch_slug(o)}'>"
        f'<span><span class="oc-city">{esc(o["name"])}</span>'
        f'<span class="oc-reg">{esc(o["region"] or o["city"])}</span></span>'
        f'<i class="ti ti-arrow-up-right"></i></a>' for o in others)
    h = replace_div(h, '<div class="others">', ocards)

    h = re.sub(r'<div class="mini-cap">.*?</div>',
               f'<div class="mini-cap"><i class="ti ti-map-pin" style="color:var(--goldd)"></i> '
               f'{esc(name)} — one of {total_branches} cash &amp; carry depots across the Kingdom</div>',
               h, count=1, flags=re.S)

    # remaining prose still naming the template branch. Only the bare name is
    # swapped — stripping a leading "Al " here also mangled "Al Madinah Province".
    h = h.replace('Al Khobar', esc(name)).replace('Khobar', esc(name))
    h = h.replace('الخبر', esc(name_ar))

    return h.replace('</head>', GEN_MARK + '</head>', 1)


def main():
    d = fetch()
    showrooms = d['showrooms']
    products = list(d['store']['products'].values())
    catlabels = d['store']['catlabels']

    counts = {}
    for s in showrooms:
        counts[slug(s['city'])] = counts.get(slug(s['city']), 0) + 1
    branch_slug.counts = counts

    tpl = open(TEMPLATE, encoding='utf-8').read()
    keep = set()
    for s in showrooms:
        others = [o for o in showrooms if o['code'] != s['code']][:6]
        page = make(tpl, s, products, catlabels, others, len(showrooms))
        fn = branch_slug(s) + '.html'
        open(os.path.join(DIR, fn), 'w', encoding='utf-8').write(page)
        keep.add(fn)
        n = sum(1 for p in products if float((p['stock'] or {}).get(s['code'], 0)) > 0)
        print(f'  {fn:<28} {n:>5} products in stock')

    keep.add('index.html')
    removed = []
    for f in sorted(os.listdir(DIR)):
        if f.endswith('.html') and f not in keep:
            os.remove(os.path.join(DIR, f))
            removed.append(f)
    print(f'\ngenerated {len(showrooms)} branches; removed {len(removed)} obsolete: '
          f'{", ".join(removed) if removed else "none"}')
    return removed


if __name__ == '__main__':
    main()
