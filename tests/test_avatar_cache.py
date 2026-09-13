import base64
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'bin/omabot-watch'
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')


class AvatarCacheTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.cache = self.home / 'avatars'
        self.cache.mkdir()
        self.scope = runpy.run_path(str(HELPER))['avatars'].__globals__
        self.scope['CACHE'] = str(self.cache)
        self.blob = self.home / 'blob.json'
        self.revision = 0

    def update(self, version='v1', data=PNG, entries=None):
        if entries is None:
            entries = [{'id': 'bot', 'version': version,
                        'dataUrl': 'data:image/png;base64,' + base64.b64encode(data).decode()}]
        self.revision += 1
        self.blob.write_text(json.dumps({'value': {'entries': entries}}))
        return self.scope['avatars']({'roster.agent-avatars': (str(self.blob), self.revision)})

    def test_avatar_versions_cannot_write_outside_cache(self):
        escaped = self.home / 'outside.png'
        self.update('../outside')
        self.assertFalse(escaped.exists(), 'Relative version escaped the cache')
        self.update(str(self.home / 'absolute'))
        self.assertFalse((self.home / 'absolute.png').exists(), 'Absolute version escaped the cache')

    def test_predicted_temporary_symlink_does_not_overwrite_target(self):
        target = self.home / 'unrelated.txt'
        target.write_bytes(b'must survive')
        (self.cache / 'v1.png.part').symlink_to(target)
        result = self.update()
        self.assertEqual(target.read_bytes(), b'must survive')
        picture = Path(result['bot'])
        self.assertFalse(picture.is_symlink())
        self.assertEqual(picture.read_bytes(), PNG)

    def test_existing_avatar_symlink_is_not_served(self):
        target = self.home / 'private.png'
        target.write_bytes(PNG)
        (self.cache / 'v1.png').symlink_to(target)
        self.assertEqual(self.update(), {})
        self.assertEqual(target.read_bytes(), PNG)

    def test_symlinked_cache_or_parent_is_refused(self):
        outside = self.home / 'outside'
        outside.mkdir()
        self.cache.rmdir()
        self.cache.symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.update(), {})
        self.assertEqual(list(outside.iterdir()), [])
        self.scope['CACHE'] = str(self.cache / 'child')
        self.assertEqual(self.update(), {})
        self.assertEqual(list(outside.iterdir()), [])

    def test_rotation_retires_only_images_owned_by_this_watcher(self):
        unrelated = self.cache / 'notes.txt'
        unrelated.write_text('keep me')
        first = Path(self.update('v1')['bot'])
        second = Path(self.update('v2')['bot'])
        self.assertEqual(second.read_bytes(), PNG)
        self.assertFalse(first.exists())
        self.assertTrue(unrelated.exists(), 'Pruning deleted an unrelated cache file')
        self.assertEqual(unrelated.read_text(), 'keep me')
        self.assertEqual(second.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.cache.stat().st_mode & 0o777, 0o700)

    def test_invalid_update_does_not_prune_the_previous_picture(self):
        picture = Path(self.update()['bot'])
        self.assertEqual(self.update(entries=[{'id': 'bot', 'version': 'bad', 'dataUrl': 'not an image'}]), {})
        self.assertEqual(picture.read_bytes(), PNG)

    def test_cache_directory_swap_does_not_redirect_publication(self):
        original = self.home / 'original-avatars'
        outside = self.home / 'outside'
        outside.mkdir()
        real_decode = self.scope['base64'].b64decode

        def swap_then_decode(*args, **kwargs):
            if not original.exists():
                self.cache.rename(original)
                self.cache.symlink_to(outside, target_is_directory=True)
            return real_decode(*args, **kwargs)

        from unittest.mock import patch
        with patch.object(self.scope['base64'], 'b64decode', side_effect=swap_then_decode):
            self.update()
        self.assertEqual(list(outside.iterdir()), [], 'Publication re-resolved the replaced directory')

    def test_unchanged_blob_does_not_reuse_replaced_symlink(self):
        picture = Path(self.update()['bot'])
        target = self.home / 'private.png'
        target.write_bytes(PNG)
        picture.unlink()
        picture.symlink_to(target)
        result = self.scope['avatars']({'roster.agent-avatars': (str(self.blob), self.revision)})
        self.assertEqual(result, {})
        self.assertEqual(target.read_bytes(), PNG)

    def test_fifo_is_refused_without_waiting_for_a_writer(self):
        os.mkfifo(self.cache / 'v1.png')
        # Run in a child so a regression cannot hang the test process forever.
        import subprocess
        script = ('import runpy,sys; f=runpy.run_path(sys.argv[1])["avatars"]; '
                  'f.__globals__["CACHE"]=sys.argv[2]; '
                  'print(f({"roster.agent-avatars":(sys.argv[3],1)}))')
        self.blob.write_text(json.dumps({'value': {'entries': [{'id': 'bot', 'version': 'v1',
            'dataUrl': 'data:image/png;base64,' + base64.b64encode(PNG).decode()}]}}))
        result = subprocess.run(['python3', '-B', '-c', script, str(HELPER), str(self.cache), str(self.blob)],
                                capture_output=True, text=True, timeout=3, check=True)
        self.assertEqual(result.stdout.strip(), '{}')

    def test_oversized_avatar_is_rejected_without_pruning_valid_picture(self):
        picture = Path(self.update()['bot'])
        self.assertEqual(self.update('too-large', b'x' * (2 * 1024 * 1024 + 1)), {})
        self.assertEqual(picture.read_bytes(), PNG)
        self.assertFalse((self.cache / 'too-large.png').exists())


if __name__ == '__main__':
    unittest.main()
