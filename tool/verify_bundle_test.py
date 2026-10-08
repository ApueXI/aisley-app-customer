"""Negative checks prevent broken bundles or broadened Android permissions passing."""
from pathlib import Path
import shutil
import tempfile
import unittest

import verify_bundle as bundle


class BundleTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='buyer-bundle-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        # Reference assets/docs read-only; copy only the configuration we mutate.
        for name in ('docs', 'assets'):
            (self.root / name).symlink_to(bundle.ROOT / name, target_is_directory=True)
        for name in ('README.md', 'pubspec.yaml'):
            shutil.copyfile(bundle.ROOT / name, self.root / name)
        shutil.copytree(bundle.ROOT / 'android/app/src', self.root / 'android/app/src')

    def test_current_bundle_passes_and_a_broken_portable_link_fails(self):
        errors, links = bundle.verify(self.root)
        self.assertEqual(errors, [])
        self.assertGreater(links, 600)
        with (self.root / 'README.md').open('a') as document:
            document.write('\n[Missing](docs/absent-verification-record.md)\n')
        errors, _ = bundle.verify(self.root)
        self.assertTrue(any('missing local link' in error for error in errors))

    def test_release_permission_or_cleartext_expansion_fails(self):
        manifest = self.root / 'android/app/src/main/AndroidManifest.xml'
        text = manifest.read_text().replace('android:usesCleartextTraffic="false"',
                                            'android:usesCleartextTraffic="true"')
        text = text.replace('<application', '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>\n    <application')
        manifest.write_text(text)
        errors, _ = bundle.verify(self.root)
        self.assertTrue(any('usesCleartextTraffic' in error for error in errors))
        self.assertTrue(any('foreground-only' in error for error in errors))

    def test_verbatim_progress_archive_checks_original_links_and_missing_targets(self):
        # Never mutate the source docs through the read-only symlink.
        (self.root / 'docs').unlink()
        shutil.copytree(bundle.ROOT / 'docs', self.root / 'docs')
        logs = self.root / 'docs/logs'
        logs.mkdir(exist_ok=True)
        archive = logs / 'PROGRESS-2099-01-01-2.md'
        archive.write_text('[Evidence](references/phase-1-verification.md)\n')
        self.assertEqual(bundle.verify(self.root)[0], [])
        archive.write_text('[Missing](references/absent-archive-target.md)\n')
        errors, _ = bundle.verify(self.root)
        self.assertTrue(any('absent-archive-target.md' in error for error in errors))
        archive.unlink()
        (logs / 'ordinary.md').write_text('[Evidence](references/phase-1-verification.md)\n')
        errors, _ = bundle.verify(self.root)
        self.assertTrue(any('ordinary.md: missing local link' in error for error in errors))

    def test_debug_subdomains_and_profile_http_override_fail(self):
        network = self.root / 'android/app/src/debug/res/xml/local_network_security.xml'
        network.write_text(network.read_text().replace('<domain>', '<domain includeSubdomains="true">', 1))
        manifest = self.root / 'android/app/src/profile/AndroidManifest.xml'
        manifest.write_text(manifest.read_text().replace('</manifest>',
            '<application android:usesCleartextTraffic="true"/></manifest>'))
        errors, _ = bundle.verify(self.root)
        self.assertTrue(any('subdomains' in error for error in errors))
        self.assertTrue(any('Profile Android' in error for error in errors))


if __name__ == '__main__':
    unittest.main()
