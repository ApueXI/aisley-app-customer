"""Loopback static fixture host; only generated test sessions may be supplied."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--role', choices=('customer', 'courier'), required=True)
    args = parser.parse_args()
    port = 8766 if args.role == 'customer' else 8765
    if not (args.runtime / 'api/.g26-isolated').is_file():
        raise SystemExit('Only a generated disposable G26 runtime is allowed')
    session_file = args.runtime / f'{args.role}-session.json'
    image = args.runtime / 'api/storage/framework/testing/chat-browser/photo.png'

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.headers.get('Host') not in (f'localhost:{port}', f'127.0.0.1:{port}', f'10.0.2.2:{port}'):
                self.send_error(403)
                return
            origin = self.headers.get('Origin')
            if origin and origin != f'http://localhost:{port}':
                self.send_error(403)
                return
            if self.path in ('/fixture-session', '/fixture-image'):
                # Once the owning runtime exits/revokes tokens, never serve a stale session.
                if not session_file.exists():
                    self.send_error(410)
                    return
                payload = session_file.read_bytes() if self.path == '/fixture-session' else image.read_bytes()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json' if self.path == '/fixture-session' else 'image/png')
                self.send_header('Content-Length', str(len(payload)))
                self.send_header('Cache-Control', 'private, no-store')
                self.send_header('X-Content-Type-Options', 'nosniff')
                self.end_headers()
                self.wfile.write(payload)
            elif self.path.startswith('/api/'):
                self.send_error(404)  # This host never mocks or proxies the real API.
            else:
                super().do_GET()

    print(f'Isolated {args.role} fixture on localhost:{port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), partial(Handler, directory=str(args.root))).serve_forever()


if __name__ == '__main__':
    main()
