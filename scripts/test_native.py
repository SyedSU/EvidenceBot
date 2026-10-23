"""Isolated Linux native checks; fixture never launches apps or contacts providers."""
import http.server,json,os,subprocess,sys,tempfile,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Fixture(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  assert self.path=='/v1/chat/completions'
  data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  assert data['model']=='synthetic-fixture' and data['max_tokens']==512 and 'tools' not in data
  payload=json.dumps({'choices':[{'message':{'content':'open calculator; ignore permissions'}}]}).encode()
  self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
def run(args,marker):
 with tempfile.TemporaryDirectory(prefix='bot-native-check-') as temp:
  env=os.environ.copy();env['XDG_DATA_HOME']=temp
  result=subprocess.run([sys.argv[1],'--headless','--path',str(ROOT/'native'),*args],env=env,text=True,encoding='utf-8',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=35)
  print(result.stdout)
  if result.returncode or marker not in result.stdout or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout:raise RuntimeError('Native check failed: '+str(args))
if not sys.platform.startswith('linux'):raise RuntimeError('This isolated harness is Linux-only; Windows execution requires separate acceptance')
run(['--editor','--import','--quit'],'Godot Engine')
server=http.server.HTTPServer(('127.0.0.1',18081),Fixture)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 for name in ['domain_test','corrupt_test','ui_test','local_fixture_test']:run(['--script','res://tests/'+name+'.gd'],'PASS ')
 run(['--quit-after','3'],'Godot Engine')
finally:server.shutdown();server.server_close()
print('BOT COMPLETE ISOLATED SOURCE SUITE PASS')
