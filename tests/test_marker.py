import json
from pathlib import Path
import runpy
import tempfile
import time
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'bin/omabot-watch'


class MarkerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.scope = runpy.run_path(str(HELPER))['marker'].__globals__
        self.scope['MARKER'] = str(self.state / 'sand-session-marker.json')
        self.sessions = self.state / 'dune-reliability' / 'sessions'
        self.sessions.mkdir(parents=True)
        self.scope['SESSIONS'] = str(self.sessions)

    def session(self, state='running', heartbeat_age=10):
        now = time.time() * 1000
        (self.sessions / ('5e55-10n.' + state + '.json')).write_text(json.dumps({
            'pid': 4242, 'identity': {'app': 'sand', 'appVersion': '0.75.0'},
            'startedAtMs': now - 600000, 'heartbeatAtMs': now - heartbeat_age * 1000,
            'quitRequestedAtMs': None, 'bootOutcome': 'ready', 'windowCrashSeen': False,
        }))

    def test_running_session_reports_running(self):
        self.session()
        app = self.scope['marker']()
        self.assertTrue(app['running'], 'Live 0.75 session read as not running')
        self.assertEqual(app['version'], '0.75.0')
        self.assertEqual(app['pid'], 4242)

    def test_stale_heartbeat_reports_not_running(self):
        self.session(heartbeat_age=600)
        self.assertFalse(self.scope['marker']()['running'], 'Crashed session read as running')

    def test_clean_exit_reports_not_running(self):
        self.session('clean')
        self.assertFalse(self.scope['marker']()['running'], 'Quit session read as running')

    def test_legacy_marker_still_reports_running(self):
        (self.state / 'sand-session-marker.json').write_text(json.dumps({
            'pid': 7, 'appVersion': '0.47.0', 'aliveAtMs': time.time() * 1000}))
        app = self.scope['marker']()
        self.assertTrue(app['running'], 'Pre-0.75 marker no longer read')
        self.assertEqual(app['version'], '0.47.0')


if __name__ == '__main__':
    unittest.main()
