#!/usr/bin/env python3
"""Local static server for the muntajat-b2b mirror.

Replicates Netlify's "Pretty URLs" behaviour: /brands/acana -> brands/acana.html
The mirrored pages link to root-absolute, extensionless URLs, so plain
`python3 -m http.server` (and file://) will 404 on them. Use this instead.

    python3 _serve.py            # http://localhost:8899
    python3 _serve.py 3000       # custom port
"""
import os
import sys
import functools
import http.server

ROOT = os.path.dirname(os.path.abspath(__file__))


class PrettyURLHandler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        full = super().translate_path(path)
        if os.path.isdir(full) or os.path.exists(full):
            return full
        if os.path.exists(full + ".html"):          # /brands/acana -> acana.html
            return full + ".html"
        return full

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *a):
        sys.stderr.write("  %s\n" % (fmt % a))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    handler = functools.partial(PrettyURLHandler, directory=ROOT)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"muntajat-b2b mirror  ->  http://localhost:{port}/   (Ctrl+C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")


if __name__ == "__main__":
    main()
