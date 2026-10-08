#!/usr/bin/env python3
"""Verify MapLibre at localhost:8766 with synthetic Laravel responses.

Requires a web build with MAPS_ENABLED=true, Chromium and chromedriver. Provider
responses are synthetic by default. --live-geoapify exercises the compiled public
key with public-landmark lookup and real tiles; it never writes to Laravel.
The plugin's pinned MapLibre JS/CSS/worker resources load from its default CDN.
"""
import argparse
import base64
import json
import shutil
import socket
import struct
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path

from browser_synthetic import fixture, ID


def tile_png():
    """Small deterministic road pattern, generated without external map data."""
    rows = b''.join(b'\0' + b''.join(
        bytes((245, 244, 239) if 110 < x < 146 or 110 < y < 146 else (205, 220, 204))
        for x in range(256)) for y in range(256))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))

    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 256, 256, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live-geoapify', action='store_true',
                        help='Use live Geoapify lookup/tiles with a public-key web build; Laravel remains synthetic.')
    live_provider = parser.parse_args().live_geoapify
    browser, driver = shutil.which('chromium'), shutil.which('chromedriver')
    if not browser or not driver:
        raise SystemExit('Chromium and chromedriver are required.')
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    profile = tempfile.TemporaryDirectory(prefix='buyer-maplibre-')
    process = subprocess.Popen([driver, '--port=' + str(port), '--allowed-ips=127.0.0.1'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    session = None

    def call(path, body=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={'Content-Type': 'application/json'}, method=method)
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)['value']
        if isinstance(result, dict) and 'error' in result:
            raise RuntimeError('Browser command failed: ' + result['error'])
        return result

    try:
        for _ in range(50):
            try:
                call('/status')
                break
            except urllib.error.URLError:
                time.sleep(.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:chromeOptions': {'binary': browser, 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
                '--window-size=390,844', '--user-data-dir=' + profile.name]}}}})['sessionId']
        prefix = '/session/' + session

        def script(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def wait_for(source, description):
            for _ in range(100):
                if script(source):
                    return
                time.sleep(.15)
            if live_provider:
                diagnostics = script("return {mapInstances:window.buyerMapInstances?.length ?? 0,tileStatus:window.buyerLiveTileStatus ?? null,lookupStatus:window.buyerLiveLookupStatus ?? null,rendererErrors:window.buyerRendererErrors ?? 0,mapFallback:document.body.innerText.includes('Retry map')};")
                print('Live check diagnostics (no URLs/credentials): ' + json.dumps(diagnostics))
            raise AssertionError(description)

        def text(value):
            wait_for("return (document.body.innerText + Array.from(document.querySelectorAll('[aria-label]')).map(e=>e.getAttribute('aria-label')).join(' ')).includes(" + json.dumps(value) + " );", 'Missing expected map screen text.')

        def click(label, exact=True):
            comparison = (' === ' + json.dumps(label)) if exact else ('.includes(' + json.dumps(label) + ')')
            for _ in range(25):
                if script("const b = Array.from(document.querySelectorAll('[role=button], [flt-tappable]')).find(e => (e.innerText || e.getAttribute('aria-label') || '').trim()" + comparison + "); if(b){b.click();return true;}return false;"):
                    time.sleep(.25)
                    return
                call(prefix + '/actions', {'actions': [{'type': 'wheel', 'id': 'map-scroll', 'actions': [
                    {'type': 'scroll', 'origin': 'viewport', 'x': 195, 'y': 400,
                     'deltaX': 0, 'deltaY': 300, 'duration': 120}]}]})
            raise AssertionError('Map action must be reachable: ' + label)

        identity = {'id': ID, 'displayName': 'Synthetic map Buyer', 'avatarUrl': None,
                    'role': 'customer', 'status': 'active'}
        address = fixture('address-book', 'op-015')
        address['data'][0].update(latitude=14.6, longitude=121, country='Philippines')
        if live_provider:
            # Public landmark, never a person's address or real customer record.
            address['data'][0].update(addressLine1='Rizal Park', addressLine2='',
                barangay='Ermita', cityMunicipality='Manila',
                province='National Capital Region (NCR)',
                region='National Capital Region (NCR)', postalCode='1000',
                latitude=14.5831, longitude=120.9794)
        replies = {
            '/api/v1/customer/auth/login': {'message': 'Synthetic sign-in', 'customer': identity, 'token': 'synthetic-map-session'},
            '/api/v1/customer/auth/me': {'customer': identity},
            '/api/v1/policy-consent/status': {'data': {'policies': [], 'all_required_accepted': True}},
            '/api/v1/customer/auth/logout': {'message': 'Synthetic sign-out'},
            '/api/v1/customer/home': fixture('customer-homepage', 'op-047'),
            '/api/v1/customer/addresses': address,
        }
        inject = '''
        const replies = REPLIES;
        const tile = TILE;
        const liveProvider = LIVE_PROVIDER;
        window.buyerMapRequests = []; window.buyerMapProviderDenied = false;
        window.buyerMapInstances = [];
        const realFetch = window.fetch;
        window.fetch = function(url, options) {
          const uri = new URL(String(url), location.href);
          if(uri.pathname.startsWith('/api/v1/')) {
            window.buyerMapRequests.push({kind:'api',method:options?.method ?? 'GET'});
            const body = replies[uri.pathname];
            return Promise.resolve(new Response(JSON.stringify(body ?? {message:'Synthetic unavailable'}),
              {status:body ? 200 : 404,headers:{'Content-Type':'application/json'}}));
          }
          if(uri.hostname.endsWith('geoapify.com')) {
            if(options?.headers && JSON.stringify(options.headers).toLowerCase().includes('authorization'))
              throw new Error('Private authorization reached provider');
            window.buyerMapRequests.push({kind:uri.pathname.includes('geocode') ? 'geocode' : 'tile'});
            if(window.buyerMapProviderDenied) return Promise.resolve(new Response('{}', {status:429,headers:{'Content-Type':'application/json'}}));
            if(liveProvider) return realFetch.apply(this, arguments).then(async response => {
              if(uri.pathname.includes('geocode')) {
                window.buyerLiveLookupStatus = response.status;
                if(response.ok) window.buyerLiveCandidate = (await response.clone().json()).results?.[0];
              } else window.buyerLiveTileStatus = response.status;
              return response;
            });
            if(uri.pathname.includes('geocode')) return Promise.resolve(new Response(JSON.stringify({results:[
              {lat:14.6,lon:121,country_code:'ph',formatted:'Synthetic lookup candidate'}]}),
              {headers:{'Content-Type':'application/json'}}));
            return realFetch('data:image/png;base64,' + tile);
          }
          return realFetch.apply(this, arguments);
        };
        // Capture the real renderer; replace worker tiles only in synthetic mode.
        const capture = new MutationObserver(() => {
          if(!document.querySelector('link[href*="unpkg.com/maplibre-gl"]')) return;
          capture.disconnect();
          // Install only after the default loader starts, so its initial
          // has-property check still triggers the real CDN import.
          let library;
          Object.defineProperty(window,'maplibregl',{configurable:true,get(){return library;},set(value){
          const MapEngine = value.Map;
          library = {...value, Map:class extends MapEngine {
            constructor(options){
              options.transformRequest = (url) => {
                if(url.includes('geoapify.com')) {
                  window.buyerMapRequests.push({kind:'renderer-tile'});
                  if(!liveProvider) return {url:'data:image/png;base64,' + tile};
                }
                return {url};
              };
              super(options);
              this.on('error',()=>{window.buyerRendererErrors=(window.buyerRendererErrors ?? 0)+1;});
              this.on('sourcedata',event=>{
                if(event.sourceId==='geoapify' && event.sourceDataType==='content')
                  window.buyerRasterContents=(window.buyerRasterContents ?? 0)+1;
              });
              this.on('click',()=>{window.buyerMapClickCount=(window.buyerMapClickCount ?? 0)+1;});
              window.buyerMapInstances.push(this);
            }
            remove(){
              window.buyerMapRemoved = (window.buyerMapRemoved ?? 0) + 1;
              return super.remove();
            }
          }};
          }});
        });
        capture.observe(document,{childList:true,subtree:true});
        '''.replace('REPLIES', json.dumps(replies)).replace('TILE', json.dumps(base64.b64encode(tile_png()).decode())).replace('LIVE_PROVIDER', json.dumps(live_provider))
        call(prefix + '/goog/cdp/execute', {'cmd': 'Page.addScriptToEvaluateOnNewDocument', 'params': {'source': inject}})
        call(prefix + '/goog/cdp/execute', {'cmd': 'Network.enable', 'params': {}})
        blocked = ['https://api.example.invalid/*']
        if not live_provider:
            blocked.append('*geoapify.com*')
        call(prefix + '/goog/cdp/execute', {'cmd': 'Network.setBlockedURLs', 'params': {'urls': blocked}})
        call(prefix + '/url', {'url': 'http://localhost:8766'})
        wait_for("const p=document.querySelector('flt-semantics-placeholder');if(p)p.click();return document.querySelector('input[aria-label=Email]') !== null;", 'Sign-in semantics unavailable.')
        for label, value in [('Email', 'synthetic@example.invalid'), ('Password', 'Synthetic123')]:
            element = next(iter(call(prefix + '/elements', {'using': 'css selector', 'value': 'input[aria-label="' + label + '"]'})[0].values()))
            call(prefix + '/element/' + element + '/click', {})
            call(prefix + '/element/' + element + '/value', {'text': value})
        click('Sign in')
        text('Search Products or Shops')
        assert script('return window.buyerMapInstances.length === 0;'), 'Maps must remain lazy.'
        script("window.location.hash = '/account/addresses/" + ID + "';")
        text('Edit address')
        click('Pin location or use GPS')
        text('Confirm address pin')
        wait_for("return window.buyerMapInstances.length === 1 && document.body.innerText.includes('© OpenMapTiles') && !document.querySelector('[role=progressbar]');", 'MapLibre pin did not become ready.')
        wait_for("return window.buyerMapInstances[0].areTilesLoaded() && window.buyerMapRequests.some(r=>r.kind==='renderer-tile');", 'Raster tiles must render.')
        if live_provider:
            assert script('return window.buyerLiveTileStatus === 200;'), 'Live Geoapify tile probe must succeed.'
            wait_for('return (window.buyerRasterContents ?? 0)>0;', 'Live raster content must reach MapLibre.')
            assert script('return (window.buyerRendererErrors ?? 0)===0;'), 'Live raster loading must have no SDK errors.'
        canvas = script("const c=document.querySelector('.maplibregl-canvas');c.scrollIntoView({block:'center'});const r=c.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};")
        # Actual browser map click, away from the centered pin.
        call(prefix + '/actions', {'actions': [{'type': 'pointer', 'id': 'map-tap', 'parameters': {'pointerType': 'mouse'}, 'actions': [
            {'type': 'pointerMove', 'origin': 'viewport', 'x': round(canvas['x'] + 50), 'y': round(canvas['y'] + 20)},
            {'type': 'pointerDown', 'button': 0}, {'type': 'pointerUp', 'button': 0}]}]})
        wait_for("return document.body.innerText.includes('Adjusted pin') && window.buyerMapClickCount === 1;", 'Map tap must update the selected pair.')
        assert script("return !window.buyerMapRequests.some(r=>r.kind==='geocode');"), 'Map tap must not trigger geocoding.'
        tapped = script("const f=window.buyerMapInstances[0].queryRenderedFeatures().find(f=>f.properties.draggable);return f?.geometry.coordinates;")
        time.sleep(.25)
        # Drag the actual native-style symbol, whose icon is anchored at its bottom.
        call(prefix + '/actions', {'actions': [{'type': 'pointer', 'id': 'map-drag', 'parameters': {'pointerType': 'mouse'}, 'actions': [
            {'type': 'pointerMove', 'origin': 'viewport', 'x': round(canvas['x'] + 50), 'y': round(canvas['y'] - 4)},
            {'type': 'pointerDown', 'button': 0},
            {'type': 'pointerMove', 'origin': 'viewport', 'x': round(canvas['x'] + 95), 'y': round(canvas['y'] - 30), 'duration': 500},
            {'type': 'pointerUp', 'button': 0}]}]})
        wait_for("const f=window.buyerMapInstances[0].queryRenderedFeatures().find(f=>f.properties.draggable);return f && JSON.stringify(f.geometry.coordinates) !== " + json.dumps(json.dumps(tapped, separators=(',', ':'))) + ";", 'Pin drag must update coordinates.')
        if not live_provider:
            directory = Path('build/verification/maplibre-screenshots')
            directory.mkdir(parents=True, exist_ok=True)
            (directory / 'address-pin.png').write_bytes(base64.b64decode(call(prefix + '/screenshot')))
        click('Find this address on the map')
        if live_provider:
            wait_for("const c=window.buyerLiveCandidate;return window.buyerLiveLookupStatus===200 && c && Number.isFinite(c.lat) && Number.isFinite(c.lon) && c.country_code==='ph';", 'Live public-landmark lookup must return valid Philippine coordinates.')
            wait_for("const label=window.buyerLiveCandidate.formatted;const b=Array.from(document.querySelectorAll('[flt-tappable]')).find(e=>(e.innerText || e.getAttribute('aria-label') || '').includes(label));if(b){b.click();return true;}return false;", 'Live lookup candidate must be selectable.')
            wait_for("const m=window.buyerMapInstances[0],c=window.buyerLiveCandidate;return Math.abs(m.getCenter().lat-c.lat)<.000001 && Math.abs(m.getCenter().lng-c.lon)<.000001;", 'Live candidate must recenter map.')
        else:
            text('Synthetic lookup candidate')
            click('Synthetic lookup candidate', exact=False)
            wait_for("return Math.abs(window.buyerMapInstances[0].getCenter().lat-14.6) < .000001;", 'Candidate selection must recenter map.')
        assert script("return window.buyerMapRequests.filter(r=>r.kind==='geocode').length === 1 && window.buyerMapInstances.length === 1;"), 'Lookup must retain the map instance.'
        for width, height in [(320, 640), (844, 390), (1440, 900)]:
            call(prefix + '/goog/cdp/execute', {'cmd': 'Emulation.setDeviceMetricsOverride', 'params': {'width': width, 'height': height, 'deviceScaleFactor': 1, 'mobile': False}})
            time.sleep(.4)
            assert script('return document.documentElement.scrollWidth <= innerWidth;')
        click('Cancel pin')
        text('Edit address')
        wait_for("return document.querySelector('.maplibregl-canvas') === null;", 'Map view must be disposed after Cancel.')
        assert script('return window.buyerMapRemoved === 1;'), 'MapLibre must release the renderer on Cancel.'
        # A new deliberate opening gets a quota failure before constructing a map.
        script('window.buyerMapProviderDenied = true;')
        click('Pin location or use GPS')
        text('Retry map')
        assert script('return window.buyerMapInstances.length === 1;')
        script('window.buyerMapProviderDenied = false;')
        click('Retry map')
        wait_for("return window.buyerMapInstances.length === 2 && !document.querySelector('[role=progressbar]');", 'Retry must build a fresh map.')
        click('Cancel pin')
        text('Edit address')
        wait_for('return window.buyerMapRemoved === 2;', 'Retry map must also release the renderer on Cancel.')
        assert script("return window.buyerMapRequests.filter(r=>r.kind==='api' && r.method==='POST').length === 1;"), 'Only the synthetic login may write to the API.'
        provider = 'live Geoapify with a public landmark' if live_provider else 'synthetic provider replies'
        print('PASS: actual MapLibre raster rendering, tap/drag, lookup/recenter, retained resizing, Cancel disposal, simulated quota fallback and deliberate Retry; ' + provider + '; Laravel replies synthetic only.')
    finally:
        if session:
            try:
                call('/session/' + session, method='DELETE')
            except Exception:
                pass
        process.terminate()
        process.wait(timeout=10)
        profile.cleanup()


if __name__ == '__main__':
    main()
