"""Verify synthetic appearance fixtures with Chromium; no live API is used.

First build test/manual/appearance_browser_fixture.dart with local web resources
in build/appearance-browser-project. Run this script from the Flutter root.
"""
import base64
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request


def free_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        return listener.getsockname()[1]


def main():
    root = Path.cwd()
    courier = root.name == 'aisley_app'
    output = root / 'build/appearance-verification/browser'
    output.mkdir(parents=True, exist_ok=True)
    port, driver_port = free_port(), free_port()
    server = subprocess.Popen(['python3', '-m', 'http.server', str(port), '--bind', '127.0.0.1', '--directory', str(root / 'build/appearance-browser-project/build/web')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    driver = subprocess.Popen([shutil.which('chromedriver'), '--port=' + str(driver_port), '--allowed-ips=127.0.0.1'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    session = None

    def call(path, body=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(driver_port) + path, data=None if body is None else json.dumps(body).encode(), headers={'Content-Type': 'application/json'}, method=method)
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)['value']

    try:
        for _ in range(100):
            try:
                call('/status')
                break
            except urllib.error.URLError:
                time.sleep(.1)
        session = call('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:loggingPrefs': {'browser': 'ALL'},
            'goog:chromeOptions': {'binary': shutil.which('chromium'), 'args': [
                '--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
                '--user-data-dir=' + str(output / 'profile')]}}}})['sessionId']
        prefix = '/session/' + session

        def js(source):
            return call(prefix + '/execute/sync', {'script': source, 'args': []})

        def labels():
            js("document.querySelector('flt-semantics-placeholder')?.click();")
            return js("return document.body.innerText + '\\n' + [...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\\n');")

        def wheel(delta):
            call(prefix + '/goog/cdp/execute', {'cmd': 'Input.dispatchMouseEvent', 'params': {'type': 'mouseWheel', 'x': 150, 'y': min(300, js('return innerHeight;') - 150), 'deltaX': 0, 'deltaY': delta}})
            time.sleep(.2)

        def wait(label, scroll=False):
            for attempt in range(140):
                if label in labels():
                    return
                if scroll and attempt % 3 == 0:
                    wheel(250)
                time.sleep(.15)
            raise AssertionError('Missing UI: ' + label + ' / ' + labels())

        def click(label, role=None):
            wait(label, scroll=label == 'Appearance')
            selector = '[role=' + role + ']' if role else '[role=button],[role=tab],[aria-label],button'
            found = js("""
                const nodes=[...document.querySelectorAll(%s)];
                const label=%s;
                const match=nodes.find(e=>{
                  const name=e.getAttribute('aria-label') || e.textContent || '';
                  return name.trim()===label || name.split('\\n').map(s=>s.trim()).includes(label);
                });
                if(!match) return false;
                match.click(); return true;
            """ % (json.dumps(selector), json.dumps(label)))
            assert found, 'Missing action: ' + label + ' / ' + str(js("return [...document.querySelectorAll('[aria-label]')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label')}));"))
            time.sleep(.35)

        def screenshot(name):
            (output / (name + '.png')).write_bytes(base64.b64decode(call(prefix + '/screenshot')))

        def resize(width, height):
            call(prefix + '/goog/cdp/execute', {'cmd': 'Emulation.setDeviceMetricsOverride', 'params': {'width': width, 'height': height, 'deviceScaleFactor': 1, 'mobile': False}})
            time.sleep(.3)

        def account():
            wait('Account')
            if courier:
                click('Account')
            wait('Appearance', scroll=True)
            wheel(180)

        resize(390, 844)
        call(prefix + '/url', {'url': 'http://localhost:' + str(port)})
        account()
        results = []
        for mode in ['Dark', 'Light', 'System']:
            click('Appearance')
            wait('Use device setting')
            screenshot('dialog-' + mode.lower())
            click(mode, 'radio')
            wait('Appearance')
            screenshot('settings-' + mode.lower())
            results.append(mode + ' choice applies')
        # Save Dark, reload the application, and verify the current choice.
        click('Appearance')
        click('Dark', 'radio')
        call(prefix + '/refresh', {})
        account()
        click('Appearance')
        wait('Use device setting')
        checked = js("return [...document.querySelectorAll('[role=radio]')].filter(e=>e.getAttribute('aria-checked')==='true').map(e=>e.getAttribute('aria-label') || e.textContent).join(' ');")
        assert 'Dark' in checked, checked
        results.append('Dark survives application reload')
        click('Cancel')
        for width, height in [(320, 640), (390, 844), (768, 900), (1440, 1000), (640, 320)]:
            resize(width, height)
            assert js('return document.documentElement.scrollWidth <= innerWidth'), 'Page overflow'
            wait('Appearance', scroll=True)
            screenshot('dark-' + str(width))
            click('Appearance')
            wait('Use device setting')
            screenshot('dark-dialog-' + str(width))
            click('Cancel')
            results.append('Layout/dialog ' + str(width) + 'x' + str(height))
        log = call(prefix + '/log', {'type': 'browser'})
        severe = [entry for entry in log if entry['level'] == 'SEVERE' and 'favicon' not in entry['message']]
        (output / 'browser-log.json').write_text(json.dumps(log, indent=2))
        assert not severe, severe
        (output / 'results.json').write_text(json.dumps(results, indent=2))
        print(str(len(results)) + ' browser checks passed; captures at ' + str(output))
    except Exception:
        if session:
            (output / 'failure-dom.html').write_text(js('return document.body.outerHTML;'))
            (output / 'failure.png').write_bytes(base64.b64decode(call('/session/' + session + '/screenshot')))
        raise
    finally:
        if session:
            call('/session/' + session, method='DELETE')
        driver.terminate()
        server.terminate()


if __name__ == '__main__':
    main()
