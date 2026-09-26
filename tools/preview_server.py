"""Development preview: limited public files and gzip for the expanded bank."""
import gzip
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import unquote, urlsplit
ROOT=Path(__file__).resolve().parent.parent
os.chdir(ROOT)
CACHE={}
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        route=unquote(urlsplit(self.path).path)
        routes={'/':'preview/lessons/index.html','/legacy':'preview/index.html','/lessons/engine.js':'preview/lessons/engine.js','/lessons/app.js':'preview/lessons/app.js','/lessons/style.css':'preview/lessons/style.css','/style.css':'preview/style.css','/app.js':'preview/app.js','/learning.js':'preview/learning.js'}
        if route in routes:
            target=ROOT/routes[route]
        elif route in ['/assets/data/lessons.json','/assets/data/questions.json','/assets/data/types.json','/assets/data/coverage.json'] or route.startswith('/assets/fonts/'):
            target=(ROOT/route.lstrip('/')).resolve()
            if not target.is_relative_to(ROOT/'assets') or (route.startswith('/assets/fonts/') and not target.is_relative_to(ROOT/'assets/fonts')):
                self.send_error(404);return
        else:
            self.send_error(404);return
        if not target.is_file():
            self.send_error(404);return
        if target.suffix=='.json' and 'gzip' in self.headers.get('Accept-Encoding',''):
            key=(str(target),target.stat().st_mtime_ns)
            if key not in CACHE:
                CACHE.clear();CACHE[key]=gzip.compress(target.read_bytes(),compresslevel=5)
            payload=CACHE[key]
            self.send_response(200)
            self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Encoding','gzip')
            self.send_header('Vary','Accept-Encoding')
            self.send_header('Content-Length',str(len(payload)))
            self.send_header('Cache-Control','no-cache')
            self.end_headers();self.wfile.write(payload);return
        self.path='/'+str(target.relative_to(ROOT))
        super().do_GET()
    def do_HEAD(self):
        self.send_error(405)
ThreadingHTTPServer(('0.0.0.0',3000),Handler).serve_forever()
