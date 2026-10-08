#!/usr/bin/env python3
"""Validate portable links, Customer spec lengths, assets and Android boundaries."""
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify(root=ROOT):
    errors = []
    links = 0
    for document in [root / 'README.md', *sorted((root / 'docs').rglob('*.md'))]:
        contents = document.read_text()
        # Required progress archives preserve the original bytes, including links
        # authored relative to docs/. Other Markdown keeps its own directory base.
        link_base = document.parent
        if (document.parent == root / 'docs/logs' and
                re.fullmatch(r'PROGRESS-\d{4}-\d{2}-\d{2}(?:-\d+)?\.md', document.name)):
            link_base = root / 'docs'
        # Examples in fenced code are text, not navigable Markdown links.
        contents = re.sub(r'```.*?```', '', contents, flags=re.S)
        for target in re.findall(r'\]\(([^\s)]+)\)', contents):
            parts = urlsplit(target.strip('<>'))
            if parts.scheme or parts.netloc or not parts.path:
                continue
            links += 1
            if not (link_base / unquote(parts.path)).exists():
                errors.append(f'{document.relative_to(root)}: missing local link {parts.path}')
    specs = list((root / 'docs/features/customer').glob('*/spec*.md'))
    if len(specs) != 22:
        errors.append('Expected all 22 Customer specifications.')
    for spec in specs:
        content = spec.read_text()
        if not content.endswith('\n') or not 200 <= len(content.splitlines()) <= 230:
            errors.append(f'{spec.relative_to(root)}: spec must have 200–230 newline-terminated lines')
    manifest = json.loads((root / 'docs/assets/psgc/manifest.json').read_text())
    if len(manifest['files']) != 19:
        errors.append('Expected nineteen PSGC files.')
    pubspec = (root / 'pubspec.yaml').read_text()
    for item in manifest['files']:
        for prefix in ('docs/assets/psgc', 'assets/psgc'):
            path = root / prefix / item['file']
            if not path.exists():
                errors.append(f'{prefix}/{item["file"]}: missing asset')
                continue
            data = path.read_bytes()
            if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
                errors.append(f'{prefix}/{item["file"]}: checksum/size mismatch')
        asset = Path(item['file'])
        registration = str(asset) if asset.parent == Path('.') else str(asset.parent) + '/'
        if f'assets/psgc/{registration}' not in pubspec:
            errors.append(f'PSGC asset is not registered: {registration}')
    source = root / 'android/app/src'
    main = ET.parse(source / 'main/AndroidManifest.xml').getroot()
    application = main.find('application')
    for key in ('allowBackup', 'usesCleartextTraffic'):
        if application.get(ANDROID + key) != 'false':
            errors.append(f'Release Android {key} must be false.')
    permissions = {p.get(ANDROID + 'name') for p in main.findall('uses-permission')}
    expected = {'android.permission.INTERNET', 'android.permission.ACCESS_COARSE_LOCATION',
                'android.permission.ACCESS_FINE_LOCATION'}
    if permissions != expected:
        errors.append('Android permissions differ from the approved foreground-only set.')
    if application.get(ANDROID + 'networkSecurityConfig') is not None:
        errors.append('Local HTTP network security configuration must remain debug-only.')
    debug = ET.parse(source / 'debug/AndroidManifest.xml').getroot().find('application')
    if debug.get(ANDROID + 'networkSecurityConfig') != '@xml/local_network_security':
        errors.append('Debug Android must use the approved local network configuration.')
    profile = ET.parse(source / 'profile/AndroidManifest.xml').getroot().find('application')
    if profile is not None and any(profile.get(ANDROID + key) is not None for key in (
            'networkSecurityConfig', 'usesCleartextTraffic')):
        errors.append('Profile Android must not override the release network boundary.')
    network = ET.parse(source / 'debug/res/xml/local_network_security.xml').getroot()
    if network.find('base-config').get('cleartextTrafficPermitted') != 'false':
        errors.append('Debug default must deny cleartext.')
    domains = {element.text for element in network.findall('domain-config/domain')}
    if domains != {'localhost', '127.0.0.1', '10.0.2.2'}:
        errors.append('Debug HTTP hosts differ from approved loopback/emulator hosts.')
    if any(e.get('cleartextTrafficPermitted') != 'true' for e in network.findall('domain-config')):
        errors.append('Approved debug host exceptions must explicitly permit local HTTP.')
    if any(e.get('includeSubdomains', 'false') != 'false' for e in network.findall('domain-config/domain')):
        errors.append('Debug local HTTP exceptions must not include subdomains.')
    for filename in ('backup_rules.xml', 'data_extraction_rules.xml'):
        xml = ET.parse(source / 'main/res/xml' / filename).getroot()
        exclusions = xml.findall('exclude') if filename == 'backup_rules.xml' else [
            *xml.findall('cloud-backup/exclude'), *xml.findall('device-transfer/exclude')]
        required = 1 if filename == 'backup_rules.xml' else 2
        if sum(e.get('domain') == 'sharedpref' and e.get('path') == '.' for e in exclusions) != required:
            errors.append(f'{filename}: secure preferences must be excluded.')
    return errors, links


def main():
    errors, links = verify()
    for error in errors:
        print(error)
    if not errors:
        print(f'PASS: {links} local links, 22 Customer specs, 19 PSGC checksums/registrations, Android boundaries.')
    return int(bool(errors))


if __name__ == '__main__':
    sys.exit(main())
