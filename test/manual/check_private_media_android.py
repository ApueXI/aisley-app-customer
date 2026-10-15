"""Verify real media adapters on an explicitly selected disposable Android emulator."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--role', choices=('customer', 'courier'), required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.serial.startswith('emulator-') or not (args.runtime / 'api/.g26-isolated').is_file():
        parser.error('An explicit disposable emulator and generated runtime are required')
    package = 'com.example.aisley_mobile_buyer' if args.role == 'customer' else 'com.example.aisley_app'
    args.output.mkdir(parents=True, exist_ok=True)
    checks = []

    def adb(*command, check=True, binary=False):
        result = subprocess.run([args.adb, '-s', args.serial, *command], capture_output=True, timeout=40)
        if check and result.returncode:
            raise AssertionError('Android test command failed: ' + command[0])
        return result.stdout if binary else result.stdout.decode(errors='replace').strip()

    def mark(label):
        checks.append(label)
        print('PASS: ' + label, flush=True)

    def tree():
        data = adb('exec-out', 'uiautomator', 'dump', '/dev/tty')
        start = data.find('<?xml')
        end = data.find('</hierarchy>')
        if start < 0 or end < 0:
            raise RuntimeError('Android accessibility tree temporarily unavailable')
        return ET.fromstring(data[start:end + len('</hierarchy>')])

    def label(node):
        return node.get('text', '') or node.get('content-desc', '')

    def wait(label_text, timeout=40):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                nodes = list(tree().iter('node'))
            except RuntimeError:
                time.sleep(.3)
                continue
            for node in nodes:
                if label_text.casefold() in label(node).casefold():
                    return node
            time.sleep(.3)
        raise AssertionError('Missing Android fixture state: ' + label_text)

    def center(node):
        points = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if len(points) != 4:
            raise AssertionError('Control has no accessible bounds')
        return (points[0] + points[2]) // 2, (points[1] + points[3]) // 2

    def tap(text):
        wait(text)
        node = next((n for n in tree().iter('node') if label(n).casefold() == text.casefold()), None)
        if node is None:
            raise AssertionError('Missing exact Android control: ' + text)
        x, y = center(node)
        adb('shell', 'input', 'tap', str(x), str(y))

    def screenshot(name):
        (args.output / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p', binary=True))

    def cache_files():
        data = adb('shell', 'run-as', package, 'find', 'cache/aisley-chat-playback', '-type', 'f', check=False)
        return [line for line in data.splitlines() if line.startswith('cache/')]

    def pdfs():
        return set(adb('shell', "find /sdcard/Download -maxdepth 1 -type f -name '*.pdf'").splitlines())

    def content(path):
        # Only paths enumerated on this fresh test emulator are used; no physical devices.
        return adb('exec-out', 'cat ' + shlex.quote(path), binary=True)

    def require(condition, message):
        if not condition:
            raise AssertionError(message)
    require(adb('shell', 'getprop', 'ro.kernel.qemu') == '1', 'Target is not an emulator')
    require(adb('shell', 'getprop', 'sys.boot_completed') == '1', 'Emulator has not booted')
    # The debug build is intentional: observe private generated playback-file cleanup.
    adb('shell', 'run-as', package, 'pwd')
    adb('shell', 'am', 'force-stop', package)
    adb('shell', 'am', 'start', '-n', package + '/.MainActivity')
    expected = (args.runtime / 'api/storage/framework/testing/chat-browser/details.pdf').read_bytes()
    session = json.loads((args.runtime / (args.role + '-session.json')).read_text())
    duration = round(next(a for a in session['attachments'] if a['kind'] == 'video')['duration_seconds'])
    report = {'role': args.role, 'checks': checks, 'android_sdk': adb('shell', 'getprop', 'ro.build.version.sdk'),
              'apk_sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(), 'passed': False}
    try:
        wait('Authenticated runtime ready')
        require(not cache_files(), 'Abandoned playback files survived startup')
        screenshot('runtime-cards')
        tap('Verify image send')
        wait('Image sent and replay verified')
        mark('installed native image upload/send/exact replay')

        tap('View video')
        play = wait('Play')
        require(len(cache_files()) == 1, 'Private native playback file missing')
        screenshot('runtime-player')
        x, y = center(play)
        require(duration >= 8, 'Use the eight-second native runtime fixture')
        adb('shell', f'input tap {x} {y}; sleep 2; input tap {x} {y}')
        positions = [re.search(r'(\d+) / (\d+) seconds', label(n)) for n in tree().iter('node')]
        require(any(m and 0 < int(m[1]) < duration for m in positions), 'Native video did not advance before Pause')
        wait('Play')
        seek = next((n for n in tree().iter('node') if n.get('class') == 'android.widget.SeekBar'), None)
        require(seek is not None, 'Video seek control missing')
        # Android exposes the Slider thumb's 48px bounds, not the whole track.
        # The production dialog/track is centered in this emulator's window.
        _, y = center(seek)
        x, _ = center(next(tree().iter('node')))
        adb('shell', 'input', 'tap', str(x), str(y))
        positions = [re.search(r'(\d+) / (\d+) seconds', label(n)) for n in tree().iter('node')]
        seek_position = next((int(m[1]) for m in positions if m), -1)
        require(abs(seek_position - duration / 2) <= 1, 'Native seek did not move playback position')
        tap('Play')
        adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        time.sleep(2)
        adb('shell', 'am', 'start', '-n', package + '/.MainActivity')
        wait('Play')
        positions = [re.search(r'(\d+) / (\d+) seconds', label(n)) for n in tree().iter('node')]
        require(any(m and int(m[1]) <= seek_position + 1 for m in positions), 'Native playback continued in the background')
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        wait('View video')
        for _ in range(20):
            if not cache_files():
                break
            time.sleep(.1)
        require(not cache_files(), 'Playback temporary files survived close')
        mark('native MP4 initialization/play/pause/seek/background pause/Back and temporary cleanup')

        before = pdfs()
        tap('Download')
        wait('Save')
        screenshot('save-as')
        require(pdfs() == before, 'Save picker wrote bytes before choosing a destination')
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        wait('Download cancelled')
        require(pdfs() == before, 'Cancelled Save As created a document')
        mark('system Save As cancellation writes no document')

        try:
            # Failure injection is limited to this disposable emulator and restored below.
            adb('shell', 'pm', 'disable-user', '--user', '0', 'com.android.documentsui')
            tap('Download')
            wait('Document unavailable')
            require(pdfs() == before, 'Unavailable picker left an incomplete export')
        finally:
            adb('shell', 'pm', 'enable', 'com.android.documentsui')
        mark('unavailable Android picker fails safely and remains retryable')

        tap('Download')
        tap('Save')
        wait('Download requested')
        saved = pdfs() - before
        require(len(saved) == 1, 'Save As did not create exactly one document')
        saved_path = saved.pop()
        require(content(saved_path) == expected, 'Saved Android document differs from received bytes')
        mark('system Save As retry exports the exact received PDF')

        tap('Sign out')
        wait('Runtime signed out')
        require(not cache_files(), 'Private playback files survived sign-out')
        require(content(saved_path) == expected, 'Explicit saved copy was removed on sign-out')
        request = urllib.request.Request(session['api_origin'] + session['attachments'][0]['content_url'],
                                         headers={'Accept': 'application/json', 'Authorization': 'Bearer ' + session['token']})
        try:
            urllib.request.urlopen(request, timeout=10).close()
            raise AssertionError('Logged-out bearer still reads private media')
        except urllib.error.HTTPError as error:
            require(error.code == 401, 'Logged-out media did not reject the bearer')
        screenshot('signed-out')
        mark('actual bearer revocation clears private state and preserves the explicitly saved copy')
        report['passed'] = True
    finally:
        (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
