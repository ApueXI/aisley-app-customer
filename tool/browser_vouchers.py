#!/usr/bin/env python3
"""Synthetic G28/B09 browser journeys; requires built Buyer at localhost:8766."""
import base64
import copy
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
VOUCHER = '22222222-2222-4222-8222-222222222222'
APP = '33333333-3333-4333-8333-333333333333'


def main():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    process = subprocess.Popen([shutil.which('chromedriver'), '--port=' + str(port)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    profile = tempfile.TemporaryDirectory(prefix='buyer-voucher-browser-')
    session = None
    report = {'syntheticOnly': True, 'origin': 'http://localhost:8766', 'layouts': [], 'journeys': []}
    screenshots = ROOT / 'build/verification/vouchers'
    screenshots.mkdir(parents=True, exist_ok=True)

    def call(path, data=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path,
            data=None if data is None else json.dumps(data).encode(),
            headers={'Content-Type': 'application/json'}, method=method or ('POST' if data is not None else 'GET'))
        result = json.load(urllib.request.urlopen(request, timeout=30))['value']
        if isinstance(result, dict) and 'error' in result:
            raise RuntimeError('Browser command failed: ' + result['error'])
        return result

    try:
        for _ in range(40):
            try:
                call('/status')
                break
            except OSError:
                time.sleep(.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {'browserName': 'chrome',
            'goog:chromeOptions': {'binary': shutil.which('chromium'), 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session
        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})
        def wait(text):
            for _ in range(80):
                script("document.querySelector('flt-semantics-placeholder')?.click();")
                visible = script("return document.body.innerText + Array.from(document.querySelectorAll('[aria-label]')).map(e=>e.getAttribute('aria-label')).join(' ');")
                if text in visible:
                    return
                time.sleep(.15)
            raise AssertionError('Missing screen text: ' + text + '; ' + visible[:900])
        def route(path, text):
            script('window.location.hash=' + json.dumps(path) + ';')
            wait(text)
        def click(text):
            found = script("""const matches = Array.from(document.querySelectorAll('[role=button],[role=radio],[role=checkbox]')).filter(e=>
                e.innerText.trim()===%s || e.getAttribute('aria-label')===%s);
                const e = matches.at(%s === 'Back' ? -1 : 0);
                if (!e) return false; e.scrollIntoView({block:'center'}); e.click(); return true;""" % (json.dumps(text), json.dumps(text), json.dumps(text)))
            assert found, 'Missing action: ' + text
            time.sleep(.5)
        def screenshot(name):
            (screenshots / name).write_bytes(base64.b64decode(call(prefix + '/screenshot')))

        identity = {'id': ID, 'displayName': 'Synthetic Buyer', 'avatarUrl': None, 'role': 'customer', 'status': 'active'}
        responses = {
          '/api/v1/customer/auth/login': {'message': 'Synthetic', 'customer': identity, 'token': 'synthetic-browser-session'},
          '/api/v1/customer/auth/me': {'customer': identity},
          '/api/v1/customer/auth/logout': {'message': 'Synthetic'},
          '/api/v1/policy-consent/status': {'data': {'policies': [], 'all_required_accepted': True}},
        }
        for kind in ['terms_of_service', 'privacy_policy']:
            body = fixture('policy-viewing-consent', 'op-084')
            body['data']['type'] = kind
            responses['/api/v1/platform/policies/' + kind] = body
        for path, feature, op in [
          ('customer/home','customer-homepage','op-047'), ('customer/cart','view-cart','op-025'),
          ('customer/addresses','address-book','op-015'), ('products/'+ID,'view-product','op-024'),
          ('customer/shops/synthetic-shop','browse-shop','op-023'),
          ('customer/shops/synthetic-shop/products','browse-shop','op-022'),
          ('customer/checkout/logistics-options','checkout-order','op-096'),
          ('customer/checkout/quote','checkout-order','op-029')]:
            responses['/api/v1/' + path] = fixture(feature, op)
        responses['/api/v1/customer/shops/synthetic-shop']['data']['slug'] = 'synthetic-shop'
        responses['/api/v1/customer/shops/synthetic-shop/products']['shop']['slug'] = 'synthetic-shop'
        responses['/api/v1/customer/wishlist/status'] = {'data': {ID: False}}
        responses['/api/v1/customer/recently-viewed/' + ID] = {'data': {'productId':ID,'lastViewedAt':'2026-10-11T00:00:00Z'}}
        docs = json.loads((ROOT / 'docs/api/examples/voucher-collection.json').read_text())
        voucher = docs['operations'][0]['response_example']['items'][0]
        app = {**copy.deepcopy(voucher), 'id': APP, 'name':'Automatic Aisley offer','issuerType':'app',
               'shop': None, 'distributionMode':'automatic','collectionUrl':'/vouchers/'+APP,'canCollect':False}
        bootstrap = """
          window.voucherCalls=[]; window.voucherClaimed=false; window.voucherFirstClaim=true;
          window.voucherFailure=null; window.voucherCheckoutExtras=false;
          const responses=%s, shopOffer=%s, appOffer=%s;
          const replacementOffer={...appOffer,id:'44444444-4444-4444-8444-444444444444',
            name:'Replacement Aisley offer'};
          const shippingOffer={...appOffer,id:'55555555-5555-4555-8555-555555555555',
            name:'Shipping Aisley offer',benefitType:'shipping'};
          const originalFetch=window.fetch;
          const personal = (row, history=false) => ({...row, collected:row.id===shopOffer.id && window.voucherClaimed,
            collectedAt:row.id===shopOffer.id && window.voucherClaimed ? '2026-10-11T00:00:00Z' : null,
            remainingPersonalUses:history ? 0 : 2, walletStatus:history?'history':'available',
            availabilityReason:history?'VOUCHER_EXPIRED':null,
            canCollect:row.distributionMode==='claim_required' && !window.voucherClaimed});
          window.fetch=function(url,options) {
            const u=new URL(String(url),location.href), p=u.pathname, method=options?.method??'GET';
            if (!p.startsWith('/api/v1/')) return originalFetch.apply(this,arguments);
            window.voucherCalls.push({path:p,method,body:options?.body??null,credentials:options?.credentials,
              authorization:!!options?.headers?.Authorization,query:u.search});
            let body=structuredClone(responses[p]??null),status=body?200:404;
            const list=(items)=>({items,pagination:{currentPage:Number(u.searchParams.get('page')??1),lastPage:2,perPage:20,total:40}});
            if(p.endsWith('/voucher-statuses')) {body={items:[personal(shopOffer),personal(appOffer)].filter(v=>Array.from(u.searchParams.values()).includes(v.id))};status=200;}
            if(p==='/api/v1/customer/vouchers' || p.endsWith('/synthetic-shop/vouchers')) {
              body=list(p.includes('/shops/')?[shopOffer]:[shopOffer,appOffer]);status=200;
            }
            if(p==='/api/v1/customer/my-vouchers') {
              const tab=u.searchParams.get('status');body=list(tab==='upcoming'?[]:tab==='history'?[personal(shopOffer,true)]:[...(window.voucherClaimed?[personal(shopOffer)]:[]),personal(appOffer)]);status=200;
            }
            if(p.endsWith('/claim')) {
              window.voucherClaimed=true; body={data:personal(shopOffer)};status=200;
              if(window.voucherFirstClaim){window.voucherFirstClaim=false;status=503;body={message:'Synthetic response lost'};}
            }
            if(p.endsWith('/checkout/logistics-options')) body.data.address.id=JSON.parse(options.body).address_id;
            if(p.endsWith('/checkout/quote')) {
              const input=JSON.parse(options.body); body.data.mode=input.mode; body.data.address.id=input.address_id;
              body.data.expiresAt='2099-01-01T00:00:00Z';
              const group=body.data.groups[0];
              group.items[0].productId=input.buy_now.product_id;group.items[0].variantId=input.buy_now.variant_id;
              group.items[0].quantity=input.buy_now.quantity;
              group.availableVouchers=[{...shopOffer,eligible:window.voucherClaimed,
                reason:window.voucherClaimed?null:'VOUCHER_NOT_CLAIMED',saving:window.voucherClaimed?'10.00':'0.00',
                stackableWith:['app:shipping','shop:shipping']},
                ...(window.voucherCheckoutExtras?[appOffer,replacementOffer,shippingOffer].map(v=>({
                  ...v,eligible:true,reason:null,saving:'10.00',stackableWith:[]})):[])];
              group.appliedVouchers=(input.vouchers??[]).map(selection=>{
                const v=group.availableVouchers.find(v=>v.id===selection.voucher_id);
                return {id:v.id,name:v.name,code:v.code,issuerType:v.issuerType,benefitType:v.benefitType,
                  qualifyingBasis:'100.00',discountAmount:'10.00'};
              });
              if(new Set(group.appliedVouchers.map(v=>v.benefitType)).size!==group.appliedVouchers.length){
                status=422;body={code:'VOUCHER_BENEFIT_LIMIT'};
              }else{
                const discount=group.appliedVouchers.some(v=>v.benefitType==='discount')?10:0;
                const shipping=group.appliedVouchers.some(v=>v.benefitType==='shipping')?10:0;
                for(const totals of [group.totals,body.data.summary]){
                  totals.discount=discount.toFixed(2);totals.shippingDiscount=shipping.toFixed(2);
                  totals.payable=(200-discount-shipping).toFixed(2);
                }
              }
            }
            if(window.voucherFailure && p.endsWith('/vouchers')) {status=window.voucherFailure;body={};}
            return Promise.resolve(new Response(JSON.stringify(body??{}),{status,headers:{'Content-Type':'application/json',
              ...(status===429?{'Retry-After':'1'}:{})}}));
          };
        """ % (json.dumps(responses), json.dumps(voucher), json.dumps(app))
        call(prefix+'/goog/cdp/execute', {'cmd':'Page.addScriptToEvaluateOnNewDocument','params':{'source':bootstrap}})
        call(prefix+'/url', {'url':'http://localhost:8766/#/vouchers/' + VOUCHER})
        wait('Sign in with your approved Buyer account.')
        for label,value in [('Email','synthetic@example.invalid'),('Password','Synthetic123')]:
            elements=call(prefix+'/elements',{'using':'css selector','value':'input[aria-label="'+label+'"]'})
            eid=next(iter(elements[0].values()))
            call(prefix+'/element/'+eid+'/click',{}); call(prefix+'/element/'+eid+'/value',{'text':value})
        click('Sign in'); wait('Voucher details')
        assert not script("return window.voucherCalls.some(c=>c.path.endsWith('/claim'));")
        report['journeys'].append('login returns to voucher detail without collection')
        for width,height in [(320,640),(390,844),(600,960),(800,1280),(1024,768),(1440,900),(640,320)]:
            call(prefix+'/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{
                'width':width,'height':height,'deviceScaleFactor':1,'mobile':False}})
            for path,text in [('/vouchers','Discover vouchers'),('/vouchers/'+VOUCHER,'Voucher details'),
                              ('/account/vouchers','Available automatically'),('/shops/synthetic-shop','Shop vouchers')]:
                route(path,text);time.sleep(.25)
                assert script('return document.documentElement.scrollWidth<=innerWidth;')
                report['layouts'].append({'route':path,'width':width,'height':height})
            if width in [390,1440]:screenshot('shop-'+str(width)+'.png')
        route('/vouchers/'+VOUCHER,'Voucher details');click('Collect voucher');wait('Retry collection')
        click('Retry collection');wait('Collected')
        calls=script("return window.voucherCalls.filter(c=>c.path.endsWith('/claim'));")
        assert len(calls)==2 and all(c['path']=='/api/v1/customer/shops/synthetic-shop/vouchers/'+VOUCHER+'/claim' for c in calls)
        report['journeys'].append('lost collection response retries same Shop endpoint')
        route('/account/vouchers','Collected');click('History');wait('This voucher has expired.')
        click('Upcoming');wait('No vouchers in this tab.')
        report['journeys'].append('wallet available/history/upcoming-empty')
        script('window.voucherClaimed=false;window.voucherFirstClaim=false;')
        route('/products/'+ID,'Buy Now');click('Buy Now');wait('Review order');click('Review order')
        wait('Collect this voucher before selecting it at Checkout.');click('Collect voucher');wait('Voucher details')
        click('Collect voucher');wait('Collected');click('Back');wait('After collecting, review your order again')
        assert not script("return window.voucherCalls.some(c=>c.path.endsWith('/place'));")
        click('Review order');wait('Saving PHP 10.00')
        script("const e=document.querySelector('[role=checkbox]'); if(e){e.scrollIntoView({block:'center'});e.click();}")
        wait('Voucher selection changed.');click('Review order');wait('Applied ' + voucher['name']);wait('Code: SYNTHETIC');wait('Merchandise savings: PHP 10.00')
        assert not script("return window.voucherCalls.some(c=>c.path.endsWith('/place'));")
        report['journeys'].append('Checkout collect/Back/explicit requote/selection/review; no placement')
        screenshot('checkout-collected.png')
        script('window.voucherCheckoutExtras=true;')
        click('Review order');wait('Automatic Aisley offer')
        def choose_offer(name, expected):
            found=script("""const e=Array.from(document.querySelectorAll('[role=checkbox]')).find(e=>
                (e.textContent+' '+e.getAttribute('aria-label')).includes(%s));
                if(!e)return false;e.scrollIntoView({block:'center'});e.click();return true;""" % json.dumps(name))
            assert found, 'Missing voucher choice: ' + name
            wait('Voucher selection changed.');click('Review order');wait('Review your COD order')
            latest=script("return JSON.parse(window.voucherCalls.filter(c=>c.path.endsWith('/checkout/quote')).at(-1).body).vouchers;")
            assert latest==[{'voucher_id':value,'target_shop_id':ID} for value in expected], latest
        choose_offer('Automatic Aisley offer',[APP])
        wait('Applied Automatic Aisley offer')
        choose_offer('Replacement Aisley offer',['44444444-4444-4444-8444-444444444444'])
        wait('Applied Replacement Aisley offer')
        report['journeys'].append('B09 Shop/App and App/App same-benefit replacement keeps explicit Shop target')
        choose_offer('Shipping Aisley offer',['44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555'])
        wait('Shipping savings: PHP 10.00')
        report['journeys'].append('B09 opposite benefits pair with empty legacy stacking flags and server savings')
        for width in [320,390,768,1440]:
            call(prefix+'/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{
                'width':width,'height':844,'deviceScaleFactor':1,'mobile':False}})
            time.sleep(.25);wait('Applied Replacement Aisley offer')
            assert script('return document.documentElement.scrollWidth<=innerWidth;')
            screenshot('b09-checkout-'+str(width)+'.png')
            report['layouts'].append({'route':'/checkout','width':width,'height':844,'case':'B09 paired names'})
        choose_offer('Shipping Aisley offer',['44444444-4444-4444-8444-444444444444'])
        wait('Applied Replacement Aisley offer')
        assert not script("return window.voucherCalls.some(c=>c.path.endsWith('/place'));")
        report['journeys'].append('B09 deselection preserves opposite benefit and never automatically places')
        route('/vouchers','Discover vouchers');script('window.voucherFailure=503;');click('Refresh vouchers');wait('service is unavailable')
        script('window.voucherFailure=null;');click('Retry vouchers');wait('Discover vouchers')
        report['journeys'].append('failed refresh retains rows with explicit recovery')
        script('window.voucherFailure=429;');click('Refresh vouchers');wait('Too many attempts.');
        script('window.voucherFailure=null;');time.sleep(1.2);click('Retry vouchers');wait('Discover vouchers')
        report['journeys'].append('throttling shows cooldown and explicit Retry')
        script("document.querySelector('[role=button]')?.focus();")
        focused=script('return document.activeElement!==document.body;')
        assert focused
        report['journeys'].append('keyboard focus is reachable')
        public=script("return window.voucherCalls.filter(c=>c.path==='/api/v1/customer/vouchers'||c.path.endsWith('/synthetic-shop/vouchers'));")
        assert all(not c['authorization'] and c['credentials']=='omit' for c in public)
        report['journeys'].append('public voucher requests omit bearer and cookies')
        (screenshots/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print('PASS: '+str(len(report['layouts']))+' voucher layouts and '+str(len(report['journeys']))+' synthetic journeys')
    finally:
        if session:
            try: call('/session/'+session,method='DELETE')
            except Exception: pass
        process.terminate();process.wait(timeout=10);profile.cleanup()

if __name__=='__main__':main()
