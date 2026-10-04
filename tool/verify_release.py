#!/usr/bin/env python3
"""Local readiness checks, with explicit opt-in public API/browser verification."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASELINE = '57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50'
API = 'http://127.0.0.1:8000/api/v1/platform/policies/terms_of_service'
BROWSER = 'http://localhost:8766'
DEFINES = ['--dart-define=API_BASE_URL=https://api.example.invalid',
           '--dart-define=STOREFRONT_ORIGIN=https://shop.example.invalid']
DEFAULT_CHECKS = ('dependencies', 'format', 'analyze', 'unit', 'chrome',
                  'tooling', 'bundle', 'web-build', 'apk-build')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def reachable(url):
    try:
        request = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.build_opener(NoRedirect).open(request, timeout=5) as response:
            return response.status == 200
    except (OSError, urllib.error.URLError):
        return False


def metadata():
    result = {'app_revision': None, 'working_tree_dirty': None, 'flutter': None}
    try:
        revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT,
                                  capture_output=True, text=True, timeout=10)
        sha = revision.stdout.strip()
        if revision.returncode == 0 and re.fullmatch(r'[0-9a-f]{40}', sha):
            result['app_revision'] = sha
        status = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT,
                                capture_output=True, text=True, timeout=10)
        if status.returncode == 0:
            result['working_tree_dirty'] = bool(status.stdout)
        version = subprocess.run(['flutter', '--version', '--machine'], cwd=ROOT,
                                 capture_output=True, text=True, timeout=60)
        if version.returncode == 0:
            data = json.loads(version.stdout)
            # Only version identifiers enter reports, never arbitrary tool output.
            result['flutter'] = {key: value for key in (
                'frameworkVersion', 'frameworkRevision', 'dartSdkVersion', 'channel')
                if isinstance(value := data.get(key), str)
                and re.fullmatch(r'[A-Za-z0-9 .+_-]{1,100}', value)}
    except (OSError, subprocess.TimeoutExpired, ValueError):
        pass
    return result


def execute(name, command, *, env=None, timeout=1200, blocked=None):
    result = {'name': name, 'command': command, 'status': 'blocked',
              'duration_seconds': 0, 'exit_code': None, 'reason': blocked}
    started = time.monotonic()
    if not blocked and not shutil.which(command[0]):
        result['reason'] = 'Required executable is unavailable.'
    elif not blocked:
        process = None
        try:
            # Deliberately discard raw output: tools can print private fixtures/errors.
            process = subprocess.Popen(command, cwd=ROOT, env=env,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                       start_new_session=os.name == 'posix')
            while True:
                remaining = timeout - (time.monotonic() - started)
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    result['exit_code'] = process.wait(timeout=min(30, remaining))
                    break
                except subprocess.TimeoutExpired:
                    print(f'RUNNING: {name}', flush=True)
            result['status'] = 'passed' if result['exit_code'] == 0 else 'failed'
            result['reason'] = None if result['exit_code'] == 0 else (
                'Command failed; rerun the recorded command locally for diagnostics.')
        except subprocess.TimeoutExpired:
            result.update(status='failed', reason='Command exceeded its deadline.')
        except OSError:
            result['reason'] = 'Command could not start.'
        finally:
            if process is not None and process.poll() is None:
                if os.name == 'posix':
                    os.killpg(process.pid, signal.SIGTERM)
                else:
                    process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    if os.name == 'posix':
                        os.killpg(process.pid, signal.SIGKILL)
                    else:
                        process.kill()
                    process.wait(timeout=10)
    result['duration_seconds'] = round(time.monotonic() - started, 2)
    print(f"{result['status'].upper()}: {name}", flush=True)
    return result


def exit_code(results):
    if any(item['status'] == 'failed' for item in results):
        return 1
    return 2 if any(item['status'] == 'blocked' for item in results) else 0


def commands():
    return {
        'dependencies': ['flutter', 'pub', 'get', '--enforce-lockfile'],
        'format': ['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test'],
        'analyze': ['flutter', 'analyze', '--no-pub'],
        'unit': ['flutter', 'test', '--no-pub'],
        'chrome': ['flutter', 'test', '--no-pub', '--platform', 'chrome', 'test/web'],
        'tooling': [sys.executable, '-m', 'unittest', 'discover', '-s', 'tool', '-p', '*_test.py'],
        'bundle': [sys.executable, 'tool/verify_bundle.py'],
        'web-build': ['flutter', 'build', 'web', '--no-pub', *DEFINES],
        'apk-build': ['flutter', 'build', 'apk', '--release', '--no-pub', *DEFINES],
        'live': ['flutter', 'test', '--no-pub', 'test/live'],
        'browser': [sys.executable, 'tool/browser_smoke.py'],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true', help='Public/denial API checks only.')
    parser.add_argument('--browser', action='store_true', help='Smoke an already running Buyer/API.')
    parser.add_argument('--checks', nargs='+', choices=DEFAULT_CHECKS,
                        help='Run only selected local checks; report remains partial.')
    parser.add_argument('--report-name', default='release',
                        help='Simple report name under ignored build/verification/.')
    args = parser.parse_args(argv)
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', args.report_name):
        parser.error('Report name must contain only letters, digits, underscore or hyphen.')
    selected = [name for name in DEFAULT_CHECKS if name in (args.checks or DEFAULT_CHECKS)]
    if args.live:
        selected.append('live')
    if args.browser:
        selected.append('browser')
    environment = os.environ.copy()
    environment.pop('BUYER_LIVE_API', None)
    environment.pop('BUYER_SCREENSHOT', None)
    chrome = shutil.which('chromium') or shutil.which('google-chrome')
    if chrome:
        environment['CHROME_EXECUTABLE'] = chrome
    lockfile = ROOT / 'pubspec.lock'
    report = {
        'started_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        **metadata(), 'contract_baseline': BASELINE, 'running_backend_revision': None,
        'pubspec_lock_sha256': hashlib.sha256(lockfile.read_bytes()).hexdigest()
        if lockfile.exists() else None,
        'configuration': {'api': 'https://api.example.invalid/api/v1',
                          'storefront': 'https://shop.example.invalid',
                          'maps_enabled': False, 'browser_origin': BROWSER},
        'scope': 'local readiness; compilation placeholders and debug signing',
        'complete_local_suite': set(DEFAULT_CHECKS).issubset(selected),
        'checks': [],
        'external_gates': ['controlled authenticated acceptance', 'installed Android/TalkBack',
                           'deployed backend revision', 'Retry-After exposure',
                           'production origins/application ID/signing',
                           'remaining integration-gap owner decisions'],
    }
    dependency_failed = False
    for name in selected:
        blocked = None
        if dependency_failed and name in ('analyze', 'unit', 'chrome', 'web-build', 'apk-build', 'live'):
            blocked = 'Locked dependency resolution did not pass.'
        if name == 'chrome' and not chrome:
            blocked = 'Chromium/Chrome is unavailable.'
        if name in ('live', 'browser') and not reachable(API):
            blocked = 'Authorized localhost API is unreachable or its public policy is unavailable.'
        if name == 'browser' and not blocked:
            if not shutil.which('chromedriver') or not shutil.which('chromium'):
                blocked = 'Browser smoke requires chromium and chromedriver.'
            elif not reachable(BROWSER):
                blocked = 'Buyer must already be running at http://localhost:8766.'
        child_env = environment.copy()
        if name == 'live':
            child_env['BUYER_LIVE_API'] = '1'
        result = execute(name, commands()[name], env=child_env, blocked=blocked)
        report['checks'].append(result)
        if name == 'dependencies':
            dependency_failed = result['status'] != 'passed'
    report['exit_code'] = exit_code(report['checks'])
    report['finished_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    destination = ROOT / 'build' / 'verification'
    destination.mkdir(parents=True, exist_ok=True)
    path = destination / (args.report_name + '.json')
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Report: build/verification/{args.report_name}.json', flush=True)
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
