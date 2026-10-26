#!/usr/bin/env python3
"""Synthetic Messages checks against the Buyer web build at localhost:8766."""
import base64
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

from browser_synthetic import ID, fixture


def responses():
    identity = {'id': ID, 'displayName': 'Synthetic Buyer', 'avatarUrl': None,
                'role': 'customer', 'status': 'active'}
    data = {
        '/api/v1/customer/auth/login': {'message': 'OK', 'customer': identity,
                                       'token': 'synthetic-browser-session'},
        '/api/v1/customer/auth/me': {'customer': identity},
        '/api/v1/customer/auth/logout': {'message': 'OK'},
        '/api/v1/policy-consent/status': {'data': {'policies': [], 'all_required_accepted': True}},
    }
    entries = [
        ('customer/home', 'customer-homepage', 'op-047'),
        ('customer/shops', 'browse-shop', 'op-021'),
        ('customer/cart', 'view-cart', 'op-025'),
        ('customer/recently-viewed', 'recently-viewed-items', 'op-042'),
        ('products/' + ID, 'view-product', 'op-024'),
        ('customer/notifications', 'notifications', 'op-054'),
    ]
    for channel, feature, offset in [('conversations', 'chat-messaging', 57),
                                     ('logistics-conversations', 'logistics-messaging', 64),
                                     ('courier-conversations', 'courier-messaging', 70)]:
        entries.extend([
            ('customer/' + channel, feature, 'op-%03d' % offset),
            ('customer/' + channel + '/' + ID, feature, 'op-%03d' % (offset + 2)),
            ('customer/' + channel + '/' + ID + '/messages', feature, 'op-%03d' % (offset + 3)),
            ('customer/' + channel + '/' + ID + '/read', feature, 'op-%03d' % (offset + 5)),
        ])
    for path, feature, op in entries:
        data['/api/v1/' + path] = fixture(feature, op)
    for kind in ['terms_of_service', 'privacy_policy']:
        body = fixture('policy-viewing-consent', 'op-084')
        body['data']['type'] = kind
        data['/api/v1/platform/policies/' + kind] = body
    return data


def main():
    browser, driver = shutil.which('chromium'), shutil.which('chromedriver')
    if not browser or not driver:
        raise SystemExit('Existing chromium and chromedriver are required.')
    out = Path('build/verification/messages')
    out.mkdir(parents=True, exist_ok=True)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    process = subprocess.Popen([driver, '--port=' + str(port), '--allowed-ips=127.0.0.1'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    profile = tempfile.TemporaryDirectory(prefix='buyer-messages-browser-')
    session = None

    def call(path, body=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path,
                                         data=None if body is None else json.dumps(body).encode(),
                                         headers={'Content-Type': 'application/json'}, method=method)
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)['value']

    try:
        for _ in range(50):
            try:
                call('/status')
                break
            except urllib.error.URLError:
                time.sleep(.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:loggingPrefs': {'browser': 'ALL'},
            'goog:chromeOptions': {'binary': browser, 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
                '--window-size=390,844', '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session

        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def text():
            script("document.querySelector('flt-semantics-placeholder')?.click();")
            return script("return document.body.innerText + '\\n' + [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join('\\n');")

        def wait_text(label):
            for _ in range(100):
                if label in text():
                    return
                time.sleep(.1)
            capture('failure')
            (out / 'failure-state.json').write_text(json.dumps({
                'expected': label,
                'visible_labels': text(),
                'requests': script('return window.messageCalls;'),
            }, indent=2))
            raise AssertionError('Missing synthetic UI: ' + label)

        def click(label):
            for _ in range(40):
                found = script(r"""
                    const wanted = %s;
                    const candidates = [...document.querySelectorAll('[role=button],[role=tab],[role=link],button,a')];
                    const nameOf = e => e.getAttribute('aria-label') || e.innerText || '';
                    const node = candidates.find(e => { const name = nameOf(e);
                        return name.trim() === wanted ||
                          name.split(String.fromCharCode(10)).map(v => v.trim()).includes(wanted); });
                    const target = node || candidates.find(e =>
                        nameOf(e).startsWith(wanted + ',') || nameOf(e).startsWith(wanted + ' '));
                    if (!target) return false;
                    target.click(); return true;
                """ % json.dumps(label))
                if found:
                    time.sleep(.3)
                    return
                text()
                time.sleep(.1)
            capture('failure')
            (out / 'failure-state.json').write_text(json.dumps({
                'action': label, 'visible_labels': text(),
            }, indent=2))
            raise AssertionError('Missing synthetic action: ' + label)

        def resize(width, height=900):
            call(prefix + '/goog/cdp/execute', {'cmd': 'Emulation.setDeviceMetricsOverride',
                 'params': {'width': width, 'height': height, 'deviceScaleFactor': 1, 'mobile': False}})
            time.sleep(.3)

        def capture(name):
            (out / (name + '.png')).write_bytes(base64.b64decode(call(prefix + '/screenshot')))

        startup = r"""
            window.messageFixtures = %s;
            window.messageCalls = [];
            window.chatUnread = 1;
            window.brokenLogistics = false;
            const original = window.fetch;
            window.fetch = function(url, options) {
              const path = new URL(String(url), location.href).pathname;
              if (!path.startsWith('/api/v1/')) return original.apply(this, arguments);
              window.messageCalls.push({path, method: options?.method || 'GET'});
              let value = window.messageFixtures[path];
              if (value) value = JSON.parse(JSON.stringify(value));
              const list = ['conversations', 'logistics-conversations', 'courier-conversations']
                .includes(path.split('/').at(-1));
              const broken = list && path.endsWith('/logistics-conversations') && window.brokenLogistics;
              if (list && value) {
                const rows = value.items || value.data;
                const channel = path.endsWith('/logistics-conversations') ? 'Logistics' :
                    path.endsWith('/courier-conversations') ? 'Courier' : 'Shop';
                rows.forEach(row => {
                  row.unread_count = window.chatUnread;
                  row.last_message_preview = 'Synthetic ' + channel + ' preview';
                  if (row.shop) row.shop.name = 'Synthetic Shop';
                  else row.counterparty_label = 'Synthetic ' + channel;
                });
                (value.meta || value).unread_count = window.chatUnread;
              }
              return Promise.resolve(new Response(JSON.stringify(broken ? {} : value || {}), {
                status: broken ? 503 : value ? 200 : 404,
                headers: {'Content-Type':'application/json'}
              }));
            };
        """ % json.dumps(responses())
        call(prefix + '/goog/cdp/execute', {'cmd': 'Page.addScriptToEvaluateOnNewDocument',
             'params': {'source': startup}})
        call(prefix + '/url', {'url': 'http://localhost:8766'})
        wait_text('Sign in with your approved Buyer account.')
        assert script('return Array.isArray(window.messageCalls);'), 'API interception must precede sign-in'
        for label, value in [('Email', 'synthetic@example.invalid'), ('Password', 'Synthetic1')]:
            elements = call(prefix + '/elements', {'using': 'css selector',
                            'value': 'input[aria-label="' + label + '"]'})
            assert elements, 'Synthetic sign-in field must be accessible: ' + label
            element = next(iter(elements[0].values()))
            call(prefix + '/element/' + element + '/click', {})
            call(prefix + '/element/' + element + '/value', {'text': value})
        click('Sign in')
        wait_text('Search Products or Shops')
        wait_text('Messages, 3 unread')
        results = []
        for width in [320, 390, 600, 800, 1024, 1440]:
            resize(width)
            for label, route in [('Shops', '/shops'), ('Cart', '/cart'), ('Account', '/account')]:
                click(label)
                time.sleep(.3)
                assert 'Search Products or Shops' not in text(), route + ' must omit header search'
                assert 'Messages,' in text(), route + ' must retain Messages'
                assert script('return document.documentElement.scrollWidth <= innerWidth;')
            click('AISLEY' if width >= 1024 else 'Home')
            wait_text('Search Products or Shops')
            click('Messages')
            wait_text('Synthetic Shop preview')
            wait_text('Synthetic Logistics preview')
            wait_text('Synthetic Courier preview')
            assert 'Search Products or Shops' not in text()
            assert not script("return window.messageCalls.some(c => c.path.endsWith('/read'));")
            capture('inbox-' + str(width))
            click('Back')
            wait_text('Search Products or Shops')
            results.append({'width': width, 'home_search_and_tabs_and_combined_inbox': 'pass'})
        resize(390)
        script('window.chatUnread = 2;')
        wait_text('Messages, 6 unread')
        click('Messages')
        for channel in ['Shops', 'Logistics', 'Courier']:
            click(channel)
            expected = 'Shop' if channel == 'Shops' else channel
            wait_text('Synthetic ' + expected + ' preview')
            click('Synthetic ' + expected)
            wait_text('Read only')
            click('Back')
        click('All')
        script('window.brokenLogistics = true;')
        click('Refresh messages')
        wait_text('Retry')
        wait_text('Synthetic Shop preview')
        script('window.brokenLogistics = false;')
        click('Retry')
        wait_text('Synthetic Logistics preview')
        capture('recovered-390')
        logs = call(prefix + '/log', {'type': 'browser'}, method='POST')
        errors = [entry['message'] for entry in logs
                  if any(term in entry['message'] for term in
                         ['overflowed by', 'EXCEPTION CAUGHT BY WIDGETS', 'EXCEPTION CAUGHT BY RENDERING'])]
        assert not errors, 'Flutter layout/runtime errors in synthetic browser'
        report = {'origin': 'http://localhost:8766', 'transport': 'synthetic interception only',
                  'layouts': results, 'foreground_unread_update': 'pass',
                  'channel_filters_and_threads': 'pass', 'partial_failure_and_retry': 'pass'}
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        for name in ['failure.png', 'failure-state.json']:
            (out / name).unlink(missing_ok=True)
        print(json.dumps(report, indent=2))
    finally:
        if session:
            try:
                call('/session/' + session, method='DELETE')
            except (urllib.error.URLError, OSError):
                pass
        process.terminate()
        process.wait(timeout=10)
        profile.cleanup()


if __name__ == '__main__':
    main()
