#!/usr/bin/env python3
"""
Build a deploy bundle for serving the storefront from a sub-path.

The mirror links with root-absolute URLs (/store-demo, /brands/, /assets/...)
because it was built to sit at a domain root. Dropped under /b2b those all
resolve one level too high, so every one is rebased here.

Produces  ../muntajat-b2b-deploy/  plus a tar.gz ready to scp.

  python3 _build_deploy.py [prefix] [host]
      prefix   default /b2b
      host     default http://sapapi.muntajat.sa      (used for canonical URLs)

What it changes versus the local copy:
  * root-absolute internal links get the prefix
  * the catalogue API is called same-origin (no cross-origin request, no CORS)
  * canonical / og:url / sitemap point at the new location
  * noindex, so a preview copy cannot compete with the published site for
    search rankings — remove the two marked lines to go live properly
  * .htaccess reproduces Netlify's extensionless URLs and keeps Laravel's
    front controller from swallowing them
  * the dev-only scripts in this folder are left out of the bundle
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PREFIX = (sys.argv[1] if len(sys.argv) > 1 else '/b2b').rstrip('/')
HOST = (sys.argv[2] if len(sys.argv) > 2 else 'http://sapapi.muntajat.sa').rstrip('/')
OUT = os.path.join(os.path.dirname(HERE), 'muntajat-b2b-deploy')
OLD_HOST = 'https://muntajat-b2b.netlify.app'

# files that exist only to build/serve locally
SKIP = {'_serve.py', '_apiwire.py', '_apiwire_pages.py', '_genbrands.py',
        '_build_deploy.py', '_MIRROR-README.md'}

HTACCESS = """# Storefront served from a sub-path of the Laravel public/ directory.
# Two jobs: reproduce Netlify's extensionless URLs, and stop Laravel's front
# controller from turning them into a 404.
#
# This directory is also registered in cPanel as the document root of the
# subdomain b2b.sapapi.muntajat.sa (created 2026-08-10, never given a DNS
# record). Creating it overwrote this file with Laravel's stock public/.htaccess
# and dropped a public/index.php alongside it; that index.php won DirectoryIndex
# over index.html and then fataled on a vendor/autoload.php one level up that
# does not exist -> HTTP 500 on the whole storefront. DirectoryIndex is stated
# first here so a reappearing index.php cannot shadow the site again.
DirectoryIndex index.html

<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase %(prefix)s/

  # /b2b/brands/acana -> /b2b/brands/acana.html
  RewriteCond %%{REQUEST_FILENAME} !-f
  RewriteCond %%{REQUEST_FILENAME} !-d
  RewriteCond %%{REQUEST_FILENAME}.html -f
  RewriteRule ^(.+)$ $1.html [L]
</IfModule>

# belt and braces: the bundle no longer ships these, but a stray copy on the
# server stays unreadable
<FilesMatch "^_">
  Require all denied
</FilesMatch>

<IfModule mod_headers.c>
  <FilesMatch "\\.html$">
    Header set Cache-Control "public, max-age=300"
  </FilesMatch>
  <FilesMatch "\\.(png|ico|svg|woff2?)$">
    Header set Cache-Control "public, max-age=2592000"
  </FilesMatch>
</IfModule>
""" % {'prefix': PREFIX}


def rebase(text):
    """Prefix root-absolute internal URLs. Order matters: the longest, most
    specific patterns first, so /store-demo.html is not hit twice."""
    for attr in ('href', 'src'):
        for q in ('"', "'"):
            # any root-absolute URL that is not already prefixed and not a
            # protocol-relative one
            text = re.sub(
                r'(%s=%s)/(?!/|%s/)' % (attr, q, re.escape(PREFIX.lstrip('/'))),
                r'\1%s/' % PREFIX, text)

    # links the app builds at runtime inside template literals
    text = text.replace("href='/store-demo", "href='%s/store-demo" % PREFIX)
    text = text.replace('href="/store-demo', 'href="%s/store-demo' % PREFIX)

    # Spell out the .html so the bundle works even where the .htaccess below is
    # ignored (AllowOverride off). The rewrite then only makes the prettier URL
    # an extra, not a requirement.
    def add_ext(m):
        path, frag = m.group('path'), m.group('frag') or ''
        if path.endswith('/') or re.search(r'\.[a-z0-9]{2,5}$', path, re.I):
            return m.group(0)
        return '%s=%s%s.html%s%s' % (m.group('attr'), m.group('q'), path,
                                     frag, m.group('q'))

    text = re.sub(
        r'(?P<attr>href|src)=(?P<q>["\'])(?P<path>%s/[^"\'#?]*)(?P<frag>[#?][^"\']*)?(?P=q)'
        % re.escape(PREFIX), add_ext, text)

    # canonical / og / twitter / sitemap all pointed at the old host
    text = text.replace(OLD_HOST + '/', HOST + PREFIX + '/')
    text = text.replace(OLD_HOST, HOST + PREFIX)

    # The catalogue API lives on this same host once deployed, so call it
    # same-origin: no cross-origin request, no CORS, and it keeps working if the
    # domain ever changes. The ?api= override still works for debugging.
    text = re.sub(r"var bases = forced \? \[forced\] : \[[^\]]*\];",
                  "var bases = forced ? [forced] : [''];", text)
    return text


NOINDEX = ('<meta name="robots" content="noindex,nofollow"><!-- preview: '
           'delete this line and the robots.txt Disallow to go live -->')


def main():
    if os.path.exists(OUT):
        shutil.rmtree(OUT)

    copied = 0
    for dp, _, fs in os.walk(HERE):
        rel = os.path.relpath(dp, HERE)
        for f in fs:
            # SKIP names the scripts explicitly; the underscore rule also
            # catches the branch template and anything added later, so a build
            # script can never end up readable on the public site.
            if f in SKIP or f.startswith(('.', '_')):
                continue
            src = os.path.join(dp, f)
            dst = os.path.join(OUT, rel, f) if rel != '.' else os.path.join(OUT, f)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if f.endswith(('.html', '.xml', '.txt')):
                s = open(src, encoding='utf-8').read()
                s = rebase(s)
                if f.endswith('.html'):
                    s = s.replace('<head>', '<head>' + NOINDEX, 1)
                    if NOINDEX not in s:            # no literal <head> tag
                        s = re.sub(r'(<meta charset[^>]*>)', r'\1' + NOINDEX, s, count=1)
                open(dst, 'w', encoding='utf-8').write(s)
            else:
                shutil.copy2(src, dst)
            copied += 1

    open(os.path.join(OUT, '.htaccess'), 'w').write(HTACCESS)
    open(os.path.join(OUT, 'robots.txt'), 'w').write(
        'User-agent: *\nDisallow: %s/\n' % PREFIX)

    tar = OUT + '.tar.gz'
    if os.path.exists(tar):
        os.remove(tar)
    subprocess.run(['tar', '-czf', tar, '-C', os.path.dirname(OUT),
                    os.path.basename(OUT)], check=True)

    size = os.path.getsize(tar) / 1024 / 1024
    print(f'prefix      : {PREFIX}')
    print(f'canonical   : {HOST}{PREFIX}/')
    print(f'files        : {copied} (+ .htaccess, robots.txt)')
    print(f'bundle      : {tar}  ({size:.1f} MB)')


if __name__ == '__main__':
    main()
