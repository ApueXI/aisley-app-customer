"""Regression coverage for truthful readiness reporting and output privacy."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import verify_release as runner


class ReleaseRunnerTest(unittest.TestCase):
    def test_child_failure_is_reported_without_printing_its_payload(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = runner.execute('synthetic-failure', [
                runner.sys.executable, '-c',
                "print('PRIVATE_PAYLOAD_MUST_NOT_ESCAPE'); raise SystemExit(7)"])
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['exit_code'], 7)
        self.assertNotIn('PRIVATE_PAYLOAD', output.getvalue())
        self.assertEqual(runner.exit_code([result]), 1)

    def test_unavailable_tool_and_deadline_cannot_pass(self):
        with contextlib.redirect_stdout(io.StringIO()):
            missing = runner.execute('missing', ['buyer-nonexistent-executable'])
            deadline = runner.execute('deadline', [runner.sys.executable, '-c',
                                                   'import time; time.sleep(10)'], timeout=0.02)
        self.assertEqual(missing['status'], 'blocked')
        self.assertEqual(runner.exit_code([missing]), 2)
        self.assertEqual(deadline['status'], 'failed')
        self.assertEqual(runner.exit_code([missing, deadline]), 1)

    def test_success_exit_and_explicit_block_do_not_run_blocked_command(self):
        with contextlib.redirect_stdout(io.StringIO()):
            success = runner.execute('success', [runner.sys.executable, '-c', 'pass'])
            with patch.object(runner.subprocess, 'Popen') as start:
                blocked = runner.execute('live', ['flutter', 'test'], blocked='API unavailable.')
                start.assert_not_called()
        self.assertEqual(runner.exit_code([success]), 0)
        self.assertEqual(blocked['reason'], 'API unavailable.')

    def test_partial_live_run_retains_external_gates_and_sanitizes_environment(self):
        seen = []

        def execute(name, command, **kwargs):
            seen.append((name, kwargs['env']))
            return {'name': name, 'status': 'blocked' if kwargs.get('blocked') else 'passed',
                    'command': command, 'reason': kwargs.get('blocked')}

        with tempfile.TemporaryDirectory() as directory:
            with (patch.object(runner, 'ROOT', Path(directory)),
                  patch.object(runner, 'metadata', return_value={}),
                  patch.object(runner, 'execute', side_effect=execute),
                  patch.object(runner, 'reachable', return_value=False),
                  patch.dict(runner.os.environ, {'BUYER_LIVE_API': '1',
                                                'BUYER_SCREENSHOT': '/private/location'}),
                  contextlib.redirect_stdout(io.StringIO())):
                code = runner.main(['--checks', 'format', '--live', '--browser'])
            report = json.loads((Path(directory) / 'build/verification/release.json').read_text())
        self.assertEqual(code, 2)
        self.assertFalse(report['complete_local_suite'])
        self.assertIsNone(report['running_backend_revision'])
        self.assertTrue(report['external_gates'])
        self.assertNotIn('BUYER_LIVE_API', seen[0][1])
        self.assertEqual(seen[1][1]['BUYER_LIVE_API'], '1')
        self.assertTrue(all('BUYER_SCREENSHOT' not in env for _, env in seen))
        self.assertNotIn('/private/location', json.dumps(report))

    def test_failed_dependency_blocks_dependent_checks_but_runs_tooling(self):
        seen = {}

        def execute(name, command, **kwargs):
            seen[name] = kwargs.get('blocked')
            return {'name': name, 'status': 'failed' if name == 'dependencies' else
                    'blocked' if kwargs.get('blocked') else 'passed'}

        with tempfile.TemporaryDirectory() as directory:
            with (patch.object(runner, 'ROOT', Path(directory)),
                  patch.object(runner, 'metadata', return_value={}),
                  patch.object(runner, 'execute', side_effect=execute),
                  contextlib.redirect_stdout(io.StringIO())):
                code = runner.main(['--checks', 'unit', 'tooling', 'dependencies'])
        self.assertEqual(code, 1)
        self.assertIsNotNone(seen['unit'])
        self.assertIsNone(seen['tooling'])

    def test_report_name_cannot_escape_build_directory(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                runner.main(['--report-name', '../../private'])
        self.assertEqual(error.exception.code, 2)

    def test_readiness_probe_does_not_follow_redirects(self):
        handler = runner.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, '', {}, 'https://foreign.invalid'))
        with patch.object(runner.urllib.request, 'build_opener') as opener:
            opener.return_value.open.side_effect = OSError('private failure details')
            self.assertFalse(runner.reachable(runner.API))


if __name__ == '__main__':
    unittest.main()
