#!/usr/bin/env python3
"""
Take the demo prices out of the static pages.

The 10 cash-and-carry pages print a price under every product tile and the 80
brand pages repeat one inside their schema.org Offer blocks. Both were demo
numbers (a 37-value band between SAR 107 and 197, unrelated to SAP).

  cash-and-carry/*.html : tile prices are filled at runtime from the catalogue
                          API, keyed by the item code in each tile's href.
  brands/*.html         : the fabricated Offer price is dropped. These are SEO
                          documents, so a real price has to be baked in at build
                          time by whatever regenerates them — injecting it from
                          the browser would not be seen by a crawler.

Idempotent.

    python3 _apiwire_pages.py [api_base]      default: https://sapapi.muntajat.sa
"""
import re
import os
import sys
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
API_BASE = sys.argv[1] if len(sys.argv) > 1 else 'https://sapapi.muntajat.sa'
MARK = 'b2b-prices'

PRICE_JS = """<script id="b2b-prices">
/* Tile prices come from sapconnect; this page stores none of its own. */
(function () {
  var forced = new URLSearchParams(location.search).get('api');
  var bases = forced ? [forced] : [%(api)r, 'http://127.0.0.1:8123'];

  function attempt(i) {
    if (i >= bases.length) return;             // leave the price blank
    fetch(bases[i] + '/api/store/b2b/catalog', {cache: 'no-store'})
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(fill)
      .catch(function () { attempt(i + 1); });
  }

  function fill(d) {
    var P = d.store.products;
    document.querySelectorAll('a.lp, a.bp-pcard').forEach(function (a) {
      var m = (a.getAttribute('href') || '').match(/\\/p\\/(P\\d+)/);
      var p = m && P[m[1]];
      var el = a.querySelector('.lp-pr, .bp-pprice');
      if (!el) return;
      if (!p) { a.style.display = 'none'; return; }   // no longer in catalogue
      el.textContent = %(fmt)s;
    });
  }

  attempt(0);
})();
</script>"""


# The English pages render "SAR 132.50", the Arabic ones "132.50 ر.س".
PRICE_EN = re.compile(r'(<div class="(?:lp-pr|bp-pprice)">)SAR [\d,.]+(</div>)')
PRICE_AR = re.compile(r'(<div class="(?:lp-pr|bp-pprice)">)[\d,.]+\s*ر\.س(</div>)')
FMT_EN = "'SAR ' + p.price"
FMT_AR = "p.price + ' ر.س'"


def blank_prices(html):
    """Strip the baked numbers; return (html, count, formatter for this page)."""
    html, n_en = PRICE_EN.subn(r'\1\2', html)
    html, n_ar = PRICE_AR.subn(r'\1\2', html)
    return html, n_en + n_ar, (FMT_AR if n_ar > n_en else FMT_EN)


def patch_location(path):
    html = open(path, encoding='utf-8').read()
    if MARK in html:
        return 'already wired'

    html, n, fmt = blank_prices(html)
    if n:
        html = html.replace('</body>',
                            (PRICE_JS % {'api': API_BASE, 'fmt': fmt}) + '\n</body>', 1)
    open(path, 'w', encoding='utf-8').write(html)
    return f'{n} tile prices now API-driven'


def patch_brand(path):
    """Strip the Offer price (SEO, must be baked) and make the visible
    product-card price API-driven like the location pages."""
    html = open(path, encoding='utf-8').read()
    if MARK in html:
        return 0, 0

    html, seo = re.subn(r'"price":\s*"[\d.]+",\s*"priceCurrency":\s*"SAR",\s*', '', html)
    html, tiles, fmt = blank_prices(html)
    if tiles:
        html = html.replace('</body>',
                            (PRICE_JS % {'api': API_BASE, 'fmt': fmt}) + '\n</body>', 1)
    open(path, 'w', encoding='utf-8').write(html)
    return seo, tiles


if __name__ == '__main__':
    print(f'API base: {API_BASE}')
    for p in sorted(glob.glob(os.path.join(HERE, 'cash-and-carry', '*.html'))):
        if os.path.basename(p) != 'index.html':
            print(f'  {os.path.relpath(p, HERE)}: {patch_location(p)}')
    seo = tiles = 0
    pages = sorted(glob.glob(os.path.join(HERE, 'brands', '*.html')))
    for p in pages:
        a, b = patch_brand(p)
        seo += a
        tiles += b
    print(f'  brands/*.html ({len(pages)} pages): {seo} fabricated Offer prices '
          f'removed, {tiles} card prices now API-driven')
