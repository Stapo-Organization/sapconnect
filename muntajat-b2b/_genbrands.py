#!/usr/bin/env python3
"""
Generate the missing brand pages from live sapconnect data.

The published storefront shipped a hand-written page for 40 brands. The live
catalogue carries 87, so the other 47 had no URL at all — /brands/kit-cat.html
was a 404.

This builds a page (English + Arabic) for every brand that lacks one, reusing
applaws.html as the structural template so the new pages are pixel-identical in
layout, navigation and styling to the hand-made ones.

What it fills from real data:
  brand name (EN + AR), logo, SKU count, the full product grid with images and
  category chips, the ten SAP showrooms, and the schema.org blocks.

What it deliberately omits:
  the "About the brand" essay. The 40 original pages each carry a hand-written
  brand history and tagline. Those cannot be derived from any Muntajat system,
  and inventing a founding story per brand would put false claims on a public
  page — so the section is dropped rather than filled with generated prose.
  Add copy later and the section can come back.

Idempotent — regenerating overwrites only the pages it created (a page carrying
GEN_MARK); hand-written pages are never touched.

    python3 _genbrands.py [api_base]      default: https://sapapi.muntajat.sa
"""
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API_BASE = sys.argv[1] if len(sys.argv) > 1 else 'https://sapapi.muntajat.sa'
LOCAL_API = 'http://127.0.0.1:8123'
GEN_MARK = '<!-- generated-from-sapconnect -->'
TPL_EN = 'applaws.html'
TPL_AR = 'applaws-ar.html'


def replace_div(html, opening, inner):
    """Swap the contents of a <div> found by its opening tag.

    A lazy regex cannot do this: the product cards nest divs, so `.*?</div>`
    stops inside the first card and leaves the rest of the template's cards in
    place. Count the tags instead.
    """
    i = html.find(opening)
    if i < 0:
        raise SystemExit(f'template is missing: {opening}')
    start = i + len(opening)
    depth, k = 1, start
    tag = re.compile(r'<(/?)div\b', re.I)
    while depth:
        m = tag.search(html, k)
        if not m:
            raise SystemExit(f'unbalanced div after: {opening}')
        depth += -1 if m.group(1) else 1
        k = m.end()
        if depth == 0:
            end = m.start()
    return html[:start] + inner + html[end:]


def esc(s):
    return (str(s).replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;').replace("'", '&#x27;'))


def slug(s):
    return re.sub(r'(^-|-$)', '', re.sub(r'[^a-z0-9]+', '-', str(s).lower()))


def fetch_catalog():
    for base in (LOCAL_API, API_BASE):
        try:
            with urllib.request.urlopen(base + '/api/store/b2b/catalog', timeout=300) as r:
                print(f'  catalogue from {base}')
                return json.loads(r.read())
        except Exception:
            continue
    raise SystemExit('could not reach the catalogue API — start `php artisan serve --port=8123`')


def existing_pages():
    out = set()
    for f in os.listdir(os.path.join(HERE, 'brands')):
        if not f.endswith('.html') or f == 'index.html':
            continue
        name = f[:-5]
        if name.endswith('-ar'):
            name = name[:-3]
        out.add(name)
    return out


def depot_href(city):
    """Match the SPA's rule: the real page if it exists, else the in-app view."""
    s = slug(city)
    if os.path.exists(os.path.join(HERE, 'cash-and-carry', s + '.html')):
        return '/cash-and-carry/' + s
    return '/store-demo#/showrooms'


# ── section builders ─────────────────────────────────────────────────────────

def build_chips(products, ar):
    by_cat = {}
    for p in products:
        cat = next(iter(p['cats'].values()), 'Other')
        by_cat.setdefault(cat, []).append(p)

    label_ar = {}
    for p in products:
        cat = next(iter(p['cats'].values()), 'Other')
        label_ar[cat] = p.get('_catar') or cat

    all_lbl = 'الكل' if ar else 'All'
    out = [f'<button class="bp-chip on" type="button" data-filter="all" '
           f'onclick="bpFilter(this)">{all_lbl} '
           f'<span class="bp-cn">{len(products)}</span></button>']

    for cat, items in sorted(by_cat.items(), key=lambda kv: -len(kv[1])):
        shown = label_ar.get(cat, cat) if ar else cat
        animal = next(iter(items[0]['pets']), '')
        more = (f'عرض كل {len(items)} {shown} في الكتالوج ←' if ar
                else f'View all {len(items)} {shown} in the catalogue →')
        href = f'../store-demo.html#/c/{animal}/{cat}'
        out.append(
            f'<button class="bp-chip" type="button" data-filter="{esc(cat)}" '
            f'data-full="{len(items)}" data-morelabel="{esc(more)}" '
            f'data-href="{esc(href)}" onclick="bpFilter(this)">{esc(shown)} '
            f'<span class="bp-cn">{len(items)}</span></button>')
    return ''.join(out)


def build_grid(products, ar):
    cards = []
    for p in products:
        cat = next(iter(p['cats'].values()), 'Other')
        shown_cat = (p.get('_catar') or cat) if ar else cat
        name = (p['tar'] or p['t']) if ar else p['t']
        cards.append(
            f"<a class='bp-pcard' data-cat='{esc(cat)}' href='/store-demo#/p/{p['id']}'>"
            f'<div class="bp-pim"><img loading="lazy" src="{esc(p["img"])}" '
            f'alt="{esc(name)}"></div>'
            f'<div class="bp-pb"><div class="bp-pcat">{esc(shown_cat)}</div>'
            f'<div class="bp-pn">{esc(name)}</div>'
            f'<div class="bp-pprice"></div></div></a>')
    return ''.join(cards)


def build_depots(showrooms, ar):
    out = []
    for s in showrooms:
        city = (s.get('city_ar') or s.get('name_ar') or s['city']) if ar else s['city']
        name = (s.get('name_ar') or city) if ar else s['name']
        out.append(
            f"<a class='bp-depot' href='{depot_href(s['city'])}'>"
            f'<span><span class="c">{esc(city)}</span>'
            f'<span class="a">{esc(name)}</span></span>'
            f'<i class="ti ti-arrow-up-right"></i></a>')
    return ''.join(out)


def build_ldjson(brand, brand_ar, logo, products, url, ar):
    name = brand_ar or brand if ar else brand
    items = [{
        '@type': 'ListItem', 'position': i + 1,
        'item': {
            '@type': 'Product',
            'name': (p['tar'] or p['t']) if ar else p['t'],
            'sku': p['sku'], 'image': p['img'],
            'brand': {'@type': 'Brand', 'name': brand},
            'url': f"https://muntajat-b2b.netlify.app/store-demo#/p/{p['id']}",
        },
    } for i, p in enumerate(products[:30])]

    blocks = [
        {'@context': 'https://schema.org', '@type': 'Brand', 'name': name,
         'logo': logo, 'url': url},
        {'@context': 'https://schema.org', '@type': 'ItemList',
         'name': f'{brand} products', 'numberOfItems': len(products),
         'itemListElement': items},
        {'@context': 'https://schema.org', '@type': 'BreadcrumbList',
         'itemListElement': [
             {'@type': 'ListItem', 'position': 1, 'name': 'Home',
              'item': 'https://muntajat-b2b.netlify.app/store-demo'},
             {'@type': 'ListItem', 'position': 2, 'name': 'Brands',
              'item': 'https://muntajat-b2b.netlify.app/brands/'},
             {'@type': 'ListItem', 'position': 3, 'name': brand, 'item': url},
         ]},
    ]
    return ''.join(
        f'<script type="application/ld+json">{json.dumps(b, ensure_ascii=False)}</script>'
        for b in blocks)


# ── page assembly ────────────────────────────────────────────────────────────

def make_page(tpl, brand, brand_ar, logo, products, showrooms, ar):
    s = tpl
    name = brand_ar or brand if ar else brand
    url = f'https://muntajat-b2b.netlify.app/brands/{slug(brand)}{"-ar" if ar else ""}.html'
    n = len(products)

    desc = (f'{name} في السعودية عبر الموزّع المعتمد منتجات — {n} منتجًا متوفرًا '
            f'في {len(showrooms)} معارض دفع واستلام في أنحاء المملكة.' if ar else
            f'{brand} in Saudi Arabia through Muntajat, the authorized distributor — '
            f'{n} products stocked across {len(showrooms)} cash & carry showrooms.')
    title = (f'{brand} السعودية | الموزّع المعتمد منتجات' if ar
             else f'{brand} Saudi Arabia | Muntajat Official Distributor')

    # head
    s = re.sub(r'<title>.*?</title>', f'<title>{esc(title)}</title>', s, count=1, flags=re.S)
    s = re.sub(r'(<meta name="description" content=")[^"]*(")', lambda m: m.group(1) + esc(desc) + m.group(2), s, count=1)
    s = re.sub(r'(<meta property="og:title" content=")[^"]*(")', lambda m: m.group(1) + esc(title) + m.group(2), s, count=1)
    s = re.sub(r'(<meta property="og:description" content=")[^"]*(")', lambda m: m.group(1) + esc(desc) + m.group(2), s, count=1)
    s = re.sub(r'(<meta property="og:url" content=")[^"]*(")', lambda m: m.group(1) + esc(url) + m.group(2), s, count=1)
    s = re.sub(r'(<meta property="og:image" content=")[^"]*(")', lambda m: m.group(1) + esc(logo) + m.group(2), s, count=1)
    s = re.sub(r'(<meta name="twitter:title" content=")[^"]*(")', lambda m: m.group(1) + esc(title) + m.group(2), s, count=1)
    s = re.sub(r'(<meta name="twitter:description" content=")[^"]*(")', lambda m: m.group(1) + esc(desc) + m.group(2), s, count=1)
    s = re.sub(r'(<meta name="twitter:image" content=")[^"]*(")', lambda m: m.group(1) + esc(logo) + m.group(2), s, count=1)
    s = re.sub(r'(<link rel="canonical" href=")[^"]*(")', lambda m: m.group(1) + esc(url) + m.group(2), s, count=1)
    s = re.sub(r'(<meta name="keywords" content=")[^"]*(")',
               lambda m: m.group(1) + esc(f'{brand}, {brand} Saudi Arabia, {name}, Muntajat') + m.group(2), s, count=1)

    # structured data
    s = re.sub(r'(<script type="application/ld\+json">.*?</script>\s*){3}',
               lambda m: build_ldjson(brand, brand_ar, logo, products, url, ar),
               s, count=1, flags=re.S)

    # breadcrumb + hero + partner
    s = re.sub(r"(<nav class=\"crumb\">.*?·\s*)Applaws(</nav>)",
               lambda m: m.group(1) + esc(brand) + m.group(2), s, count=1, flags=re.S)
    s = re.sub(r'(<div class="bp-logo"><img src=")[^"]*(" alt=")[^"]*(">)',
               lambda m: m.group(1) + esc(logo) + m.group(2) + esc(brand) + ' logo' + m.group(3),
               s, count=1)
    s = re.sub(r'<h1 class="bp-name">.*?</h1>', f'<h1 class="bp-name">{esc(brand)}</h1>',
               s, count=1, flags=re.S)
    # no verified tagline for these brands — show the Arabic name instead, or nothing
    tag = esc(brand_ar) if (brand_ar and not ar) else (esc(brand) if ar else '')
    s = re.sub(r'<div class="bp-tag">.*?</div>', f'<div class="bp-tag">{tag}</div>',
               s, count=1, flags=re.S)
    origin = f'{n} رمز تخزين' if ar else f'{n} active SKUs'
    s = re.sub(r'<div class="bp-origin">.*?</div>', f'<div class="bp-origin">{origin}</div>',
               s, count=1, flags=re.S)
    s = s.replace('Applaws', esc(brand))          # partner headline, CTA, alt text
    s = re.sub(r'(<div class="s"><b>)\d+(</b>)', lambda m: m.group(1) + str(n) + m.group(2),
               s, count=1)

    # the hand-written brand essay has no equivalent in any Muntajat system
    s = re.sub(r'<section class="sec bp-story">.*?</section>', '', s, count=1, flags=re.S)

    # products
    s = replace_div(s, '<div class="bp-chips" id="bp-filter">', build_chips(products, ar))
    s = replace_div(s, '<div class="bp-grid" id="bp-grid">', build_grid(products, ar))
    s = re.sub(r'(<h2><span class="kn">02</span>)[^<]*(</h2>)',
               lambda m: m.group(1) + (f'تصفّح {n} منتجًا' if ar else f'Browse {n} products') + m.group(2),
               s, count=1)

    # showrooms
    s = replace_div(s, '<div class="bp-depots">', build_depots(showrooms, ar))

    return s.replace('</head>', GEN_MARK + '</head>', 1)


def main():
    print(f'API base for the generated pages: {API_BASE}')
    d = fetch_catalog()
    products = d['store']['products']
    catlabels = d['store']['catlabels']
    showrooms = d['showrooms']

    by_brand = {}
    for p in products.values():
        if p['b']:
            p = dict(p)
            cat = next(iter(p['cats'].values()), 'Other')
            p['_catar'] = catlabels.get(cat) or cat
            by_brand.setdefault(p['b'], []).append(p)

    ar_name = {b['name']: b.get('name_ar', '') for b in d['brands']}
    logos = {b['name']: b['logo'] for b in d['brands']}

    have = existing_pages()
    tpl_en = open(os.path.join(HERE, 'brands', TPL_EN), encoding='utf-8').read()
    tpl_ar = open(os.path.join(HERE, 'brands', TPL_AR), encoding='utf-8').read()

    made = skipped = 0
    for brand, items in sorted(by_brand.items()):
        s = slug(brand)
        target = os.path.join(HERE, 'brands', s + '.html')
        if s in have and not (os.path.exists(target)
                              and GEN_MARK in open(target, encoding='utf-8').read()):
            skipped += 1
            continue

        items.sort(key=lambda p: p['id'])
        for ar, tpl in ((False, tpl_en), (True, tpl_ar)):
            page = make_page(tpl, brand, ar_name.get(brand, ''), logos.get(brand, ''),
                             items, showrooms, ar)
            path = os.path.join(HERE, 'brands', s + ('-ar' if ar else '') + '.html')
            open(path, 'w', encoding='utf-8').write(page)
        made += 1
        print(f'  {s:<28} {len(items):>4} products')

    print(f'\ngenerated {made} brands ({made * 2} pages); '
          f'left {skipped} hand-written brands untouched')


if __name__ == '__main__':
    main()
