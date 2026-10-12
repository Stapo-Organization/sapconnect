#!/usr/bin/env python3
"""
Repoint every link that still names a branch SAP no longer has.

The hand-written brand pages, the branch index and the sitemap were all built
against the demo's ten branches. Five of those (Khobar, Buraydah, Hafar Al
Batin and two Riyadh districts) are not in SAP, and the six real Riyadh
branches did not exist as pages at all.

Each stale link is sent to the nearest surviving branch: same city if there is
one, otherwise the branch index. Depot lists that enumerated the old ten are
rebuilt from the live list.

    python3 _fixbranchlinks.py [api_base]
"""
import json
import os
import re
import sys
import glob
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API = sys.argv[1] if len(sys.argv) > 1 else 'https://sapapi.muntajat.sa'


def slug(s):
    return re.sub(r'(^-|-$)', '', re.sub(r'[^a-z0-9]+', '-', str(s).lower()))


def load():
    with urllib.request.urlopen(API + '/api/store/b2b/catalog', timeout=300) as r:
        return json.loads(r.read())['showrooms']


def main():
    showrooms = load()
    counts = {}
    for s in showrooms:
        counts[slug(s['city'])] = counts.get(slug(s['city']), 0) + 1

    def bslug(s):
        c = slug(s['city'])
        return c if counts[c] == 1 else f"{c}-{slug(s['name'])}"

    live = {bslug(s): s for s in showrooms}
    by_city = {}
    for s in showrooms:
        by_city.setdefault(slug(s['city']), []).append(s)

    # every slug the pages might still reference -> where it should go now
    redirect = {}
    for old in ('khobar', 'buraydah', 'hafar-al-batin',
                'riyadh-suwaidi', 'riyadh-aziziyah', 'riyadh'):
        if old in live:
            continue                     # that page exists again — leave it alone
        # "hafar-al-batin" is one city, not "hafar"; match the longest city slug
        # that the old name starts with rather than splitting on the first dash.
        city = max((c for c in by_city if old == c or old.startswith(c + '-')),
                   key=len, default=old.split('-')[0])
        if old in ('riyadh-suwaidi',) and 'riyadh' in by_city:
            # the demo's Suwaidi page maps onto the real Al Suwaidi branch
            m = next((s for s in by_city['riyadh'] if 'suwaidi' in s['name'].lower()), None)
            redirect[old] = bslug(m) if m else '/cash-and-carry/'
        elif city in by_city:
            redirect[old] = bslug(by_city[city][0])
        else:
            redirect[old] = None            # no branch in that city any more

    # depot list blocks rebuilt from the live branches
    depots = ''.join(
        f"<a class='bp-depot' href='/cash-and-carry/{bslug(s)}'>"
        f'<span><span class="c">{s["city"]}</span>'
        f'<span class="a">{s["name"]}</span></span>'
        f'<i class="ti ti-arrow-up-right"></i></a>' for s in showrooms)

    files = [p for p in glob.glob(os.path.join(HERE, '**', '*.html'), recursive=True)]
    files += glob.glob(os.path.join(HERE, '*.xml'))
    touched = 0
    for p in files:
        s = open(p, encoding='utf-8').read()
        orig = s

        # rebuild the "where to buy" strip wherever it lists branches
        if '<div class="bp-depots">' in s:
            s = re.sub(r'(<div class="bp-depots">).*?(</div>)\s*(?=<)',
                       lambda m: m.group(1) + depots + m.group(2), s, count=1, flags=re.S)

        for old, new in redirect.items():
            if new is None:
                target = '/cash-and-carry/'
            else:
                target = '/cash-and-carry/' + new
            s = re.sub(r'/cash-and-carry/%s(?=["\'#?/]|\.html)' % re.escape(old),
                       target.rstrip('/') if new else '/cash-and-carry/', s)
            s = s.replace('/cash-and-carry/%s.html' % old,
                          (target + '.html') if new else '/cash-and-carry/')

        if s != orig:
            open(p, 'w', encoding='utf-8').write(s)
            touched += 1

    print(f'live branches : {len(showrooms)}')
    print(f'redirects     : ' + ', '.join(f'{k}->{v or "index"}' for k, v in redirect.items()))
    print(f'files updated : {touched}')

    # sitemap
    sm = os.path.join(HERE, 'sitemap.xml')
    if os.path.exists(sm):
        s = open(sm, encoding='utf-8').read()
        base = 'https://muntajat-b2b.netlify.app'
        block = ''.join(f'<url><loc>{base}/cash-and-carry/{k}.html</loc></url>'
                        for k in sorted(live))
        s = re.sub(r'(<url><loc>[^<]*?/cash-and-carry/[^<]*?</loc></url>\s*)+', block, s, count=1)
        s = re.sub(r'<url><loc>[^<]*?/cash-and-carry/(?!\s)[^<]*?</loc></url>', '',
                   s.replace(block, '@@BLOCK@@')).replace('@@BLOCK@@', block)
        open(sm, 'w', encoding='utf-8').write(s)
        print('sitemap       : branch entries rebuilt')


if __name__ == '__main__':
    main()
