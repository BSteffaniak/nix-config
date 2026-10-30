"""Regression checks for the Home Manager SSH fleet activation helper."""

import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "fleet", Path(__file__).resolve().parents[1] / "home/modules/shell/ssh-fleet.py"
)
fleet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fleet)


class FleetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def test_authorization_preserves_existing_and_revokes_managed(self):
        path = self.directory / "authorized_keys"
        path.write_text("existing-key\n")
        fleet.update_authorized_keys(path, ["fleet-key"])
        original = path.read_bytes()
        fleet.update_authorized_keys(path, ["fleet-key"])
        self.assertEqual(original, path.read_bytes())
        self.assertEqual(len(list(self.directory.glob("*.backup-*"))), 1)
        fleet.update_authorized_keys(path, [])
        self.assertEqual(path.read_text(), "existing-key\n")
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_symlink_and_malformed_block_rejected(self):
        path = self.directory / "authorized_keys"
        path.symlink_to(self.directory / "missing")
        with self.assertRaises(RuntimeError):
            fleet.update_authorized_keys(path, ["key"])
        path.unlink()
        path.write_text(fleet.BEGIN + "\n")
        with self.assertRaises(RuntimeError):
            fleet.update_authorized_keys(path, [])

    def test_key_is_stable_and_public_can_be_recovered(self):
        path = self.directory / "id_ed25519_fleet"
        keygen = shutil.which("ssh-keygen")
        self.assertIsNotNone(keygen)
        fleet.ensure_key(path, keygen)
        original = path.read_bytes()
        public = Path(str(path) + ".pub")
        original_public = public.read_bytes()
        fleet.ensure_key(path, keygen)
        self.assertEqual(original, path.read_bytes())
        public.unlink()
        fleet.ensure_key(path, keygen)
        self.assertEqual(original_public, public.read_bytes())
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        path.unlink()
        with self.assertRaises(RuntimeError):
            fleet.ensure_key(path, keygen)


if __name__ == "__main__":
    unittest.main()
