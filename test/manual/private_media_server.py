import argparse
import json
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--root',required=True)
p.add_argument('--port',type=int,required=True)
p.add_argument('--role',choices=['customer','courier'],required=True)
a=p.parse_args()
stats={'authorized':0,'unauthorized':0,'trap':0}
media=Path(__file__).resolve().parents[2] / 'build/g26-media'

class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,directory=a.root,**kwargs)
    def log_message(self,*args): pass
    def do_GET(self):
        if self.path=='/fixture-stats':
            self.reply(200,json.dumps(stats).encode(),'application/json');return
        if self.path=='/trap':
            stats['trap']+=1;self.reply(200,b'trap','text/plain');return
        if self.path.startswith('/api/'):
            if self.headers.get('Authorization')!='Bearer synthetic-fixture':
                stats['unauthorized']+=1;self.reply(401,b'{}','application/json');return
            stats['authorized']+=1
            if not self.path.startswith('/api/v1/'+a.role+'/chat-attachments/'):
                self.reply(404,b'{}','application/json');return
            if '22222222-' in self.path:
                self.reply(200,b'x'*1024,'application/pdf',length=False);return
            if '33333333-' in self.path:
                self.send_response(302);self.send_header('Location','/trap');self.end_headers();return
            if self.path.endswith('/preview'):
                self.reply(200,(media/'poster.jpg').read_bytes(),'image/jpeg');return
            if '44444444-' in self.path:
                self.reply(200,b'%PDF-1.4\n1234567890\n','application/pdf');return
            self.reply(200,(media/'video.mp4').read_bytes(),'video/mp4');return
        super().do_GET()
    def reply(self,status,body,mime,length=True):
        self.send_response(status)
        self.send_header('Content-Type',mime)
        self.send_header('Cache-Control','private, no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        if length:self.send_header('Content-Length',str(len(body)))
        self.send_header('Connection','close');self.end_headers()
        try:self.wfile.write(body)
        except (BrokenPipeError,ConnectionResetError):pass

print(f'Synthetic {a.role} media fixture on {a.port}',flush=True)
ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
