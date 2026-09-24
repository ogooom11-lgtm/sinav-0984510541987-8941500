"""Dependency-free reference preview (not a compiled Flutter build)."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
os.chdir(Path(__file__).resolve().parent.parent)
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.split('?')[0] in ['/', '/style.css', '/app.js']:
            self.path = '/preview/' + ('index.html' if self.path == '/' else self.path.lstrip('/'))
        super().do_GET()
ThreadingHTTPServer(('0.0.0.0', 3000), Handler).serve_forever()
