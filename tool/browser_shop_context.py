#!/usr/bin/env python3
"""G32 regression against built Buyer at localhost:8766; synthetic HTTP only."""
import base64
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request

from browser_synthetic import fixture, ID

ROOT = Path(__file__).resolve().parents[1]
BASE = '/api/v1/customer/conversations'


def main():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    driver = subprocess.Popen([shutil.which('chromedriver'), '--port=' + str(port)],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    profile = tempfile.TemporaryDirectory(prefix='buyer-shop-context-')
    session = None
    out = ROOT / 'build/verification/shop-context'
    out.mkdir(parents=True, exist_ok=True)
    report = {'syntheticOnly': True, 'origin': 'http://localhost:8766', 'layouts': [], 'journeys': []}

    def call(path, data=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path,
            data=None if data is None else json.dumps(data).encode(),
            headers={'Content-Type': 'application/json'}, method=method or ('POST' if data is not None else 'GET'))
        value = json.load(urllib.request.urlopen(request, timeout=30))['value']
        if isinstance(value, dict) and 'error' in value:
            raise RuntimeError(value['error'])
        return value

    try:
        for _ in range(40):
            try:
                call('/status')
                break
            except OSError:
                time.sleep(.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:loggingPrefs': {'browser': 'ALL'},
            'goog:chromeOptions': {'binary': shutil.which('chromium'), 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
                '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session

        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def text():
            script("document.querySelector('flt-semantics-placeholder')?.click();")
            return script("return document.body.innerText + [...document.querySelectorAll('[aria-label],input,textarea')].map(e=>(e.getAttribute('aria-label')??'')+' '+(e.value??'')).join(' ');")

        def wait(label):
            for _ in range(100):
                if label in text():
                    return
                time.sleep(.1)
            raise AssertionError('Missing ' + label + ': ' + text()[:900])

        def click(label):
            for _ in range(20):
                if script("""const wanted=%s; const e=[...document.querySelectorAll('[role=button],[role=link]')]
                    .find(e=>(e.innerText.trim()===wanted||e.getAttribute('aria-label')===wanted)&&e.getAttribute('aria-disabled')!=='true');
                    if(!e)return false; e.scrollIntoView({block:'center'});e.click();return true;""" % json.dumps(label)):
                    time.sleep(.2)
                    return
                call(prefix + '/actions', {'actions': [{'type': 'wheel', 'id': 'scroll', 'actions': [
                    {'type': 'scroll', 'origin': 'viewport', 'x': 180, 'y': 300,
                     'deltaX': 0, 'deltaY': 450, 'duration': 100}]}]})
            raise AssertionError('Missing action ' + label)

        def enter(label, value):
            elements = call(prefix + '/elements', {'using': 'css selector',
                'value': 'input[aria-label="' + label + '"],textarea[aria-label="' + label + '"]'})
            assert elements, 'Missing input ' + label
            element = next(iter(elements[0].values()))
            call(prefix + '/element/' + element + '/click', {})
            call(prefix + '/element/' + element + '/value', {'text': value})

        def resize(width, height=844):
            call(prefix + '/goog/cdp/execute', {'cmd': 'Emulation.setDeviceMetricsOverride',
                'params': {'width': width, 'height': height, 'deviceScaleFactor': 1, 'mobile': False}})
            time.sleep(.2)

        def writes():
            return script("return window.shopCalls.filter(c=>c.method==='POST' && (c.path===" + json.dumps(BASE) + "||c.path.endsWith('/messages')));")

        identity = {'id': ID, 'displayName': 'Synthetic Buyer', 'avatarUrl': None, 'role': 'customer', 'status': 'active'}
        responses = {
            '/api/v1/customer/auth/login': {'message': 'Synthetic', 'customer': identity, 'token': 'synthetic-browser-session'},
            '/api/v1/customer/auth/me': {'customer': identity},
            '/api/v1/policy-consent/status': {'data': {'policies': [], 'all_required_accepted': True}},
        }
        for kind in ['terms_of_service', 'privacy_policy']:
            responses['/api/v1/platform/policies/' + kind] = fixture('policy-viewing-consent', 'op-084')
            responses['/api/v1/platform/policies/' + kind]['data']['type'] = kind
        for path, feature, op in [
            ('customer/home', 'customer-homepage', 'op-047'),
            ('customer/cart', 'view-cart', 'op-025'),
            ('customer/shops/synthetic-shop', 'browse-shop', 'op-023'),
            ('customer/shops/synthetic-shop/products', 'browse-shop', 'op-022'),
            ('products/' + ID, 'view-product', 'op-024'),
            ('customer/orders/' + ID, 'order-status', 'op-033'),
            ('customer/conversations', 'chat-messaging', 'op-057'),
            ('customer/conversations/' + ID, 'chat-messaging', 'op-059'),
            ('customer/conversations/' + ID + '/messages', 'chat-messaging', 'op-060'),
            ('customer/conversations/' + ID + '/read', 'chat-messaging', 'op-062'),
        ]:
            responses['/api/v1/' + path] = fixture(feature, op)
        responses['/api/v1/customer/shops/synthetic-shop']['data']['slug'] = 'synthetic-shop'
        responses['/api/v1/customer/wishlist/status'] = {'data': {ID: False}}
        responses['/api/v1/customer/recently-viewed/' + ID] = {'data': {'productId': ID, 'lastViewedAt': '2026-10-15T00:00:00Z'}}
        bootstrap = """
          const responses=%s, base=%s, id=%s;
          window.shopCalls=[];window.shopFailure=null;window.shopLost=false;window.shopCommitted=false;
          const scenario=new URLSearchParams(location.search).get('scenario')??'new';
          const oldFetch=window.fetch;
          const summary=()=>({...responses[base+'/'+id].data,send_allowed:scenario!=='offline',
            shop:{id,name:'Synthetic Shop',slug:null,availability:scenario.includes('vacation')?'vacation':scenario==='offline'?'offline':'online'}});
          window.fetch=function(url,options){
            const u=new URL(String(url),location.href),path=u.pathname,method=options?.method??'GET';
            if(!path.startsWith('/api/v1/'))return oldFetch.apply(this,arguments);
            const headers=new Headers(options?.headers);
            const body=typeof options?.body==='string'?JSON.parse(options.body):null;
            window.shopCalls.push({path,method,body,key:headers.get('Idempotency-Key'),
              authorized:headers.has('Authorization'),credentials:options?.credentials});
            let data=structuredClone(responses[path]??null),status=data?200:404;
            if(path===base+'/shops/'+id){
              data={data:{shop:summary().shop,conversation_id:scenario.startsWith('existing')||scenario==='offline'||window.shopCommitted?id:null,
                send_allowed:scenario!=='offline'&&!scenario.includes('vacation')}};status=200;
              if(window.shopFailure){status=window.shopFailure;data={};}
            }else if(path===base+'/'+id||path===base+'/'+id+'/read'){
              data={data:summary()};status=200;
            }else if(path===base+'/'+id+'/messages'&&method==='GET'){
              data={items:[responses[base+'/'+id+'/messages'].items[0]],next_cursor:null};status=200;
            }else if(method==='POST'&&(path===base||path===base+'/'+id+'/messages')){
              window.shopCommitted=true;data={conversation:summary(),message:%s};status=201;
              if(window.shopLost){window.shopLost=false;status=503;data={};}
            }
            return Promise.resolve(new Response(JSON.stringify(data??{}),{status,headers:{'Content-Type':'application/json'}}));
          };
        """ % (json.dumps(responses), json.dumps(BASE), json.dumps(ID),
               json.dumps(fixture('chat-messaging', 'op-058')['message']))
        call(prefix + '/goog/cdp/execute', {'cmd': 'Page.addScriptToEvaluateOnNewDocument', 'params': {'source': bootstrap}})
        resize(390)
        call(prefix + '/url', {'url': 'http://localhost:8766/'})
        wait('Sign in with your approved Buyer account.')
        enter('Email', 'synthetic@example.invalid')
        enter('Password', 'Synthetic123')
        click('Sign in')
        wait('Search Products or Shops')

        def open_entry(scenario, path):
            print('CHECK: ' + scenario + ' ' + path, flush=True)
            call(prefix + '/url', {'url': 'about:blank'})
            call(prefix + '/url', {'url': 'http://localhost:8766/?scenario=' + scenario + '#' + path})
            wait('Message Shop')
            click('Message Shop')
            wait('Shop on vacation' if 'vacation' in scenario else 'Shop unavailable' if scenario == 'offline' else 'Shop available')
            assert not writes(), 'Opening context must create no message'

        for path, kind in [('/shops/synthetic-shop', None), ('/products/' + ID, 'product'), ('/orders/' + ID, 'order')]:
            open_entry('existing', path)
            wait('You')
            calls = script('return window.shopCalls;')
            assert any(c['path'] == BASE + '/shops/' + ID for c in calls)
            assert any(c['path'] == BASE + '/' + ID + '/messages' and c['method'] == 'GET' for c in calls)
            enter('Message', 'Synthetic browser context')
            click('Send message')
            last = writes()[-1]
            assert last['path'] == BASE + '/' + ID + '/messages'
            assert 'shop_id' not in last['body']
            if kind:
                assert last['body']['context_type'] == kind and last['body']['context_id'] == ID
            report['journeys'].append('existing thread reused from ' + (kind or 'shop'))

        open_entry('new', '/shops/synthetic-shop')
        for width, height in [(320, 640), (390, 844), (600, 960), (800, 960), (1024, 768), (1440, 900), (740, 360)]:
            resize(width, height)
            wait('Shop available')
            assert script('return document.documentElement.scrollWidth<=innerWidth;')
            (out / ('available-' + str(width) + '.png')).write_bytes(base64.b64decode(call(prefix + '/screenshot')))
            report['layouts'].append({'width': width, 'height': height})
        resize(390)
        enter('Message', 'Original synthetic message')
        script('window.shopLost=true;')
        click('Send message')
        wait('Retry exact message')
        first = writes()[0]
        click('Refresh conversation')
        wait('Retry exact message')
        assert len(writes()) == 1
        click('Retry exact message')
        wait('You')
        assert writes() == [first, first], 'Retry must preserve endpoint, body and UUID key'
        report['journeys'].append('uncertain start retains endpoint/body/key after discovery finds committed thread')

        open_entry('vacation', '/shops/synthetic-shop')
        assert script("const e=document.querySelector('input[aria-label=Message],textarea[aria-label=Message]');return !e||e.disabled;")
        report['journeys'].append('generic vacation start disabled')
        open_entry('existing-vacation', '/shops/synthetic-shop')
        wait('You')
        enter('Message', 'Reply while Shop is on vacation')
        click('Send message')
        assert writes()[-1]['path'].endswith('/messages')
        report['journeys'].append('existing vacation thread keeps authoritative reply permission')
        open_entry('vacation', '/orders/' + ID)
        enter('Message', 'About my owned Order')
        click('Send message')
        assert writes()[-1]['body']['context_type'] == 'order'
        report['journeys'].append('owned-Order vacation start remains available for server validation')

        call(prefix + '/url', {'url': 'http://localhost:8766/?scenario=new#/shops/synthetic-shop'})
        wait('Message Shop')
        script('window.shopFailure=503;')
        click('Message Shop')
        wait('The service is unavailable. Please retry.')
        assert not writes()
        script('window.shopFailure=null;')
        click('Refresh conversation')
        wait('Shop available')
        report['journeys'].append('failed discovery blocks send and explicit refresh recovers')
        private_calls = script('return window.shopCalls.filter(c=>c.path.includes("/conversations"));')
        assert all(c['authorized'] and c['credentials'] == 'omit' for c in private_calls)
        report['journeys'].append('private context uses bearer with cookies omitted')
        errors = [e['message'] for e in call(prefix + '/log', {'type': 'browser'})
                  if 'Uncaught' in e.get('message', '')]
        assert not errors, errors
        report['passed'] = True
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print('PASS: ' + str(len(report['layouts'])) + ' layouts / ' + str(len(report['journeys'])) + ' synthetic G32 journeys')
    except Exception:
        if session:
            (out / 'failure.png').write_bytes(base64.b64decode(call('/session/' + session + '/screenshot')))
        raise
    finally:
        if session:
            try:
                call('/session/' + session, method='DELETE')
            except OSError:
                pass
        driver.terminate()
        driver.wait(timeout=10)
        profile.cleanup()


if __name__ == '__main__':
    main()
