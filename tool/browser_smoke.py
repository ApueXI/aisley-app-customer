#!/usr/bin/env python3
"""Read-only Chrome smoke checks. Run the Buyer web server on localhost:8766 first."""
import base64
import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    driver = shutil.which('chromedriver')
    browser = shutil.which('chromium')
    if not driver or not browser:
        raise SystemExit('chromedriver and chromium are required; no installation is attempted.')
    profile = tempfile.TemporaryDirectory(prefix='buyer-browser-')
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    process = subprocess.Popen([driver, '--port=' + str(port), '--allowed-ips=127.0.0.1'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    session = None

    def call(path, body=None, method=None):
        payload = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path, data=payload,
                                         headers={'Content-Type': 'application/json'}, method=method)
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)
        value = result.get('value')
        if isinstance(value, dict) and 'error' in value:
            raise RuntimeError('Browser command failed: ' + value['error'])
        return value

    try:
        for _ in range(40):
            try:
                call('/status')
                break
            except urllib.error.URLError:
                time.sleep(0.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:chromeOptions': {'binary': browser, 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--window-size=390,844',
                '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session

        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def wait_text(expected):
            for _ in range(100):
                script("document.querySelector('flt-semantics-placeholder')?.click();")
                if script('return document.body.innerText;').find(expected) >= 0:
                    return
                time.sleep(0.2)
            raise AssertionError('Expected public screen did not render: ' + expected)

        call(prefix + '/url', {'url': 'http://localhost:8766'})
        wait_text('Search Products and Shops')
        script("""
          window.buyerFetchCalls = [];
          const originalFetch = window.fetch;
          window.fetch = function(url, options) {
            if (['http://localhost:8000/api/v1/', 'http://127.0.0.1:8000/api/v1/']
                .some(base => String(url).startsWith(base))) {
              window.buyerFetchCalls.push({credentials: options?.credentials, redirect: options?.redirect});
            }
            return originalFetch.apply(this, arguments);
          };
        """)
        for route, expected in [('/login', 'Sign in with your approved Buyer account.'),
                                ('/register', 'Registration requires Admin approval before you can sign in.'),
                                ('/forgot-password', 'Enter your email to request password recovery.'),
                                ('/policies/terms_of_service', 'Version'),
                                ('/policies/privacy_policy', 'Version'),
                                ('/search?q=shirt&mode=products', 'Products'),
                                ('/search?q=shop&mode=shops', 'Shops'),
                                ('/shops', 'Shops'),
                                ('/account/wishlist', 'Sign in with your approved Buyer account.'),
                                ('/account/addresses', 'Sign in with your approved Buyer account.'),
                                ('/cart', 'Sign in with your approved Buyer account.'),
                                ('/checkout', 'Sign in with your approved Buyer account.'),
                                ('/orders', 'Sign in with your approved Buyer account.'),
                                ('/orders/11111111-1111-4111-8111-111111111111', 'Sign in with your approved Buyer account.'),
                                ('/checkout/result/11111111-1111-4111-8111-111111111111', 'Sign in with your approved Buyer account.')]:
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text(expected)
        discovery = call(prefix + '/execute/async', {'script': """
          const done = arguments[arguments.length - 1];
          fetch('http://127.0.0.1:8000/api/v1/customer/home', {credentials:'omit',redirect:'error',headers:{Accept:'application/json'}})
            .then(response => response.json()).then(body => {
              const product = [...body.recommendations.items, ...body.topProducts][0];
              done(product ? {id:product.id,title:product.title,shop:product.shop} : null);
            }).catch(() => done(null));
        """, 'args': []})
        assert discovery is not None, 'A public Product is needed for detail smoke acceptance.'
        script('window.location.hash = ' + json.dumps('/products/' + discovery['id']) + ';')
        wait_text(discovery['title'])
        wait_text('Add to Cart')
        script('window.location.hash = ' + json.dumps('/shops/' + discovery['shop']['slug']) + ';')
        wait_text(discovery['shop']['name'])
        assert 'This Shop is unavailable.' not in script('return document.body.innerText;')
        transport = script('return window.buyerFetchCalls;')
        assert len(transport) >= 2 and all(item['credentials'] == 'omit' and item['redirect'] == 'error' for item in transport)
        result = call(prefix + '/execute/async', {'script': """
          const done = arguments[arguments.length - 1];
          Promise.all(['terms_of_service', 'privacy_policy'].map(async type => {
            const response = await fetch('http://localhost:8000/api/v1/platform/policies/' + type,
              {credentials: 'omit', headers: {Accept: 'application/json'}});
            const body = await response.json();
            return {status: response.status, type: body.data.type,
              version: body.data.version.version,
              retryAfterExposed: response.headers.has('Retry-After')};
          })).then(done).catch(() => done({error: 'Browser API exchange failed'}));
        """, 'args': []})
        assert isinstance(result, list) and len(result) == 2
        assert all(item['status'] == 200 and isinstance(item['version'], int) for item in result)
        denial = call(prefix + '/execute/async', {'script': """
          const done = arguments[arguments.length - 1];
          fetch('http://localhost:8000/api/v1/customer/auth/me',
            {credentials: 'omit', headers: {Accept: 'application/json', Authorization: 'Bearer invalid-smoke-test'}})
            .then(response => done({status: response.status})).catch(() => done({status: 0}));
        """, 'args': []})
        assert denial['status'] == 401  # Also exercises a real Authorization preflight.
        commerce_denial = call(prefix + '/execute/async', {'script': """
          const done = arguments[arguments.length - 1];
          Promise.all([
            ['POST', 'customer/checkout/place'],
            ['PATCH', 'customer/orders/11111111-1111-4111-8111-111111111111/modification']
          ].map(async ([method, path]) => {
            const response = await fetch('http://127.0.0.1:8000/api/v1/' + path,
              {method, credentials:'omit', redirect:'error', body:'{}', headers:{
                Accept:'application/json', 'Content-Type':'application/json',
                Authorization:'Bearer invalid-smoke-test',
                'Idempotency-Key':'11111111-1111-4111-8111-111111111111'}});
            return response.status;
          })).then(done).catch(() => done([]));
        """, 'args': []})
        assert commerce_denial == [401, 401], 'Commerce idempotency-header preflights must allow denial responses.'
        script("window.location.hash = '/';")
        wait_text('Search Products and Shops')
        screenshot = os.environ.get('BUYER_SCREENSHOT')
        if screenshot:
            with open(screenshot, 'wb') as output:
                output.write(base64.b64decode(call(prefix + '/screenshot')))
        print('PASS: Home, Products/Shops search, public Product/Shop detail, protected account/Cart/checkout/Order guards, idempotency preflights, live policies, cookie/redirect isolation, CORS and invalid-bearer denial.')
    finally:
        if session:
            try:
                call('/session/' + session, method='DELETE')
            except (OSError, RuntimeError):
                pass
        process.terminate()
        process.wait(timeout=10)
        profile.cleanup()


if __name__ == '__main__':
    main()
