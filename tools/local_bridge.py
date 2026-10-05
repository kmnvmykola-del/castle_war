"""Task-local Studio bridge: only serves this project's files and saves its place."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import shutil
import base64

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
BUILD.mkdir(exist_ok=True)
ORIGINAL=BUILD/'original-place.bin'
if not ORIGINAL.exists(): shutil.copy2(ROOT/'inex.rbxl',ORIGINAL)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        relative=self.path.split('?',1)[0].lstrip('/')
        target=(ROOT/relative).resolve()
        if not target.is_relative_to(ROOT) or not target.is_file():
            self.send_error(404)
            return
        data=target.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type','application/json' if target.suffix=='.json' else 'text/plain; charset=utf-8')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_POST(self):
        permitted={'/save-place':'inex.rbxl','/asset-ids':'assets/asset_ids.json','/qa':'build/qa.json','/runtime-export':'build/runtime.bin','/qa-v012':'build/qa-v012-report.json'}
        if self.path not in permitted:
            self.send_error(404)
            return
        size=int(self.headers.get('Content-Length','0'))
        if size<=0 or size>90_000_000:
            self.send_error(413)
            return
        data=self.rfile.read(size)
        target=ROOT/permitted[self.path]
        if self.path=='/runtime-export': data=base64.b64decode(data,validate=True)
        if self.path in ('/save-place','/runtime-export') and not data.startswith(b'<roblox!'):
            self.send_error(400,'Expected Roblox binary serialization')
            return
        if self.path not in ('/save-place','/runtime-export'): json.loads(data)
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self,fmt,*args):
        print(fmt%args,flush=True)

print('KINGDOMS_BRIDGE_READY http://127.0.0.1:8765',flush=True)
ThreadingHTTPServer(('127.0.0.1',8765),Handler).serve_forever()
