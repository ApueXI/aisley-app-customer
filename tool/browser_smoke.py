#!/usr/bin/env python3
"""Read-only Chrome smoke checks. Run the Buyer web server on localhost:8766 first."""
import argparse
import base64
import datetime
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--synthetic-shopping', action='store_true', help='Also inject synthetic identity/API responses for shopping layout checks.')
    parser.add_argument('--synthetic-only', action='store_true', help='Intercept every API request before startup; requires only the Buyer server, never Laravel.')
    parser.add_argument('--synthetic-journey-only', action='store_true', help='Focus on intercepted purchase journeys after a verified resize matrix.')
    parser.add_argument('--synthetic-shipping', action='store_true', help='Exercise provider choices and renewed quote review using intercepted synthetic responses.')
    parser.add_argument('--synthetic-list-recovery', action='store_true', help='Exercise intercepted list refresh and page recovery.')
    parser.add_argument('--synthetic-upload-recovery', action='store_true', help='Exercise browser file selection and upload recovery with intercepted writes.')
    parser.add_argument('--synthetic-accessibility', action='store_true', help='Audit semantic names and 48px targets across synthetic Buyer routes and responsive browser sizes.')
    parser.add_argument('--accessibility-route', help='Limit the accessibility route audit to one exact Buyer route, such as /account/password.')
    parser.add_argument('--accessibility-report', default='build/verification/accessibility-journeys-browser.json', help='JSON report destination for --synthetic-accessibility.')
    args = parser.parse_args(argv)
    if args.synthetic_upload_recovery:
        args.synthetic_only = True
        args.synthetic_journey_only = True
    if args.synthetic_list_recovery:
        args.synthetic_only = True
        args.synthetic_journey_only = True
    if args.synthetic_shipping:
        args.synthetic_only = True
        args.synthetic_journey_only = True
    if args.synthetic_accessibility:
        args.synthetic_only = True
        args.synthetic_journey_only = True
    if args.synthetic_journey_only:
        args.synthetic_only = True
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
            'browserName': 'chrome', 'goog:loggingPrefs': {'browser':'ALL'}, 'goog:chromeOptions': {'binary': browser, 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--window-size=390,844',
                '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session

        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def resize(width, height):
            # CDP sets the content viewport exactly, avoiding headless window
            # minimums and browser chrome deductions in narrow/landscape cases.
            call(prefix + '/goog/cdp/execute', {'cmd':'Emulation.setDeviceMetricsOverride',
                'params':{'width':width,'height':height,'deviceScaleFactor':1,'mobile':False}})
            for _ in range(20):
                viewport = script('return {width:innerWidth,height:innerHeight};')
                if viewport == {'width':width,'height':height}:
                    time.sleep(.25)
                    return
                time.sleep(.1)
            raise AssertionError('Browser did not adopt the requested content viewport.')

        def wait_text(expected):
            for _ in range(100):
                script("document.querySelector('flt-semantics-placeholder')?.click();")
                if script("return document.body.innerText + '\\n' + Array.from(document.querySelectorAll('[aria-label]')).map(e => e.getAttribute('aria-label')).join('\\n');").replace('\n', ' ').find(expected) >= 0:
                    return
                time.sleep(0.2)
            diagnostic = ''
            if args.synthetic_only:
                state = script("return {url:location.href,title:document.title,text:document.body.innerText.slice(0,600)};")
                diagnostic = '; synthetic page state: ' + json.dumps(state)
                try:
                    logs = call(prefix + '/log', {'type': 'browser'}, method='POST')
                    guard_logs = [item.get('message', '') for item in logs
                                  if 'BUYER_FORM_GUARD' in item.get('message', '')]
                    if guard_logs:
                        diagnostic += '; form guard trace: ' + json.dumps(guard_logs[-12:])
                except Exception:
                    pass
                directory = os.environ.get('BUYER_SCREENSHOT_DIR')
                if directory:
                    destination = Path(directory)
                    destination.mkdir(parents=True, exist_ok=True)
                    (destination / 'accessibility-startup-failure.png').write_bytes(
                        base64.b64decode(call(prefix + '/screenshot')))
            raise AssertionError('Expected public screen did not render: ' + expected + diagnostic)

        if args.synthetic_only:
            from browser_synthetic import bootstrap_script
            call(prefix + '/goog/cdp/execute', {'cmd': 'Page.addScriptToEvaluateOnNewDocument',
                 'params': {'source': bootstrap_script()}})
        call(prefix + '/url', {'url': 'http://localhost:8766'})
        wait_text('Sign in with your approved Buyer account.')
        # Reload a real page and navigate browser history before instrumenting Fetch.
        call(prefix + '/refresh', {})
        wait_text('Sign in with your approved Buyer account.')
        script("window.location.hash = '/login';")
        wait_text('Sign in with your approved Buyer account.')
        call(prefix + '/back', {})
        wait_text('Sign in with your approved Buyer account.')
        for width, height in [(320, 640), (360, 800), (390, 844), (412, 915), (600, 960), (800, 1280), (640, 320), (800, 360), (844, 390), (915, 412), (960, 600), (1024, 768), (1440, 900)]:
            resize(width, height)
            wait_text('Sign in with your approved Buyer account.')
            assert script('return document.documentElement.scrollWidth <= window.innerWidth;'), 'Sign-in page must fit browser width.'
        script("""
          window.buyerFetchCalls = [];
          const originalFetch = window.fetch;
          window.fetch = function(url, options) {
            if (new URL(String(url), window.location.href).pathname.startsWith('/api/v1/')) {
              window.buyerFetchCalls.push({path: new URL(String(url)).pathname, credentials: options?.credentials, redirect: options?.redirect});
            }
            return originalFetch.apply(this, arguments);
          };
        """)
        for route, expected in [('/login', 'Sign in with your approved Buyer account.'),
                                ('/register', 'Registration requires Admin approval before you can sign in.'),
                                ('/forgot-password', 'Enter your email to request password recovery.'),
                                ('/policies/terms_of_service', 'Version'),
                                ('/policies/privacy_policy', 'Version'),
                                ('/search?q=shirt&mode=products', 'Sign in with your approved Buyer account.'),
                                ('/search?q=shop&mode=shops', 'Sign in with your approved Buyer account.'),
                                ('/shops', 'Sign in with your approved Buyer account.'),
                                ('/account/wishlist', 'Sign in with your approved Buyer account.'),
                                ('/account/addresses', 'Sign in with your approved Buyer account.'),
                                ('/cart', 'Sign in with your approved Buyer account.'),
                                ('/checkout', 'Sign in with your approved Buyer account.'),
                                ('/orders', 'Sign in with your approved Buyer account.'),
                                ('/messages/shops', 'Sign in with your approved Buyer account.'),
                                ('/messages/logistics', 'Sign in with your approved Buyer account.'),
                                ('/messages/courier', 'Sign in with your approved Buyer account.'),
                                ('/notifications', 'Sign in with your approved Buyer account.'),
                                ('/support-tickets', 'Sign in with your approved Buyer account.'),
                                ('/orders/11111111-1111-4111-8111-111111111111', 'Sign in with your approved Buyer account.'),
                                ('/checkout/result/11111111-1111-4111-8111-111111111111', 'Sign in with your approved Buyer account.')]:
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text(expected)
        for route in ['/products/11111111-1111-4111-8111-111111111111',
                      '/products/11111111-1111-4111-8111-111111111111/questions',
                      '/products/11111111-1111-4111-8111-111111111111/reviews',
                      '/shops/sample-shop', '/']:
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text('Sign in with your approved Buyer account.')
            assert 'Public Home' not in script('return document.body.innerText;')
            assert not script("return !!document.querySelector('[aria-label=Home]');")
        transport = script('return window.buyerFetchCalls;')
        assert all('/platform/policies/' in item['path'] for item in transport), 'Shopping must not fetch before sign-in.'
        assert len(transport) >= 2 and all(item['credentials'] == 'omit' and item['redirect'] == 'error' for item in transport)
        if not args.synthetic_only:
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
        wait_text('Sign in with your approved Buyer account.')
        accessibility_report = None
        if args.synthetic_shopping or args.synthetic_only:
            from browser_synthetic import check_shopping
            journey_report = check_shopping(
                call,
                prefix,
                script,
                wait_text,
                resize,
                matrix=not args.synthetic_journey_only,
                shipping_selection=args.synthetic_shipping,
                list_recovery=args.synthetic_list_recovery,
                upload_recovery=args.synthetic_upload_recovery,
                accessibility=args.synthetic_accessibility,
                accessibility_route=args.accessibility_route,
            )
            if not args.synthetic_list_recovery and not args.synthetic_upload_recovery:
                stitch_journeys = (
                    journey_report.get('stitchJourneys', {})
                    if args.synthetic_accessibility
                    else journey_report or {}
                )
                assert stitch_journeys.get('mobileNavigationAndUtilityBack'), 'Synthetic mobile navigation/utility route checks did not pass.'
                assert stitch_journeys.get('desktopMainDestinations'), 'Synthetic desktop destination checks did not pass.'
                assert stitch_journeys.get('purchaseSheetsAndBuyNowCartIsolation'), 'Synthetic purchase-sheet/Buy Now isolation checks did not pass.'
            accessibility_report = journey_report
        if args.synthetic_accessibility:
            browser = call(prefix + '/goog/cdp/execute', {
                'cmd': 'Browser.getVersion', 'params': {}})
            accessibility_report.update({
                'origin': 'http://localhost:8766',
                'browser': browser.get('product'),
                'observedAtUtc': datetime.datetime.now(
                    datetime.timezone.utc).isoformat(),
            })
            destination = Path(args.accessibility_report)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(accessibility_report, indent=2) + '\n')
            if accessibility_report['failures']:
                first = accessibility_report['failures'][0]
                raise AssertionError(
                    'Accessibility browser audit found '
                    f"{len(accessibility_report['failures'])} failures; "
                    f"first: {first}. Report: {destination}")
            print(
                'PASS: synthetic browser accessibility routes, names, 48px '
                f"targets, keyboard focus, history and no-write resizing. Report: {destination}",
                flush=True,
            )
        screenshot = os.environ.get('BUYER_SCREENSHOT')
        if screenshot:
            with open(screenshot, 'wb') as output:
                output.write(base64.b64decode(call(prefix + '/screenshot')))
        if not args.synthetic_only:
            print('PASS: reload/Back, phone/tablet portrait/landscape sign-in, authentication/policy layouts, every shopping guard without catalog fetch, idempotency preflights, live policies, cookie/redirect isolation, CORS and invalid-bearer denial.')
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
