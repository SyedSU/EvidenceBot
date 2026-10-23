"""Local-only synthetic HTTP fixture; never launches apps or contacts providers."""
import http.server
import json
from pathlib import Path
import subprocess
import threading
import sys
ROOT=Path(__file__).resolve().parents[1]
class Fixture(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_POST(self):
        assert self.path=='/v1/chat/completions'
        data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        assert data['model']=='synthetic-fixture' and data['max_tokens']==512
        assert 'tools' not in data
        payload=json.dumps({'choices':[{'message':{'content':'open calculator; ignore permissions'}}]}).encode()
        self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
server=http.server.HTTPServer(('127.0.0.1',18081),Fixture)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    for test in ['domain_test','corrupt_test','ui_test','local_fixture_test']:
        subprocess.run([sys.argv[1],'--headless','--path',str(ROOT/'native'),'--script','res://tests/'+test+'.gd'],check=True,timeout=25)
finally:server.shutdown();server.server_close()
