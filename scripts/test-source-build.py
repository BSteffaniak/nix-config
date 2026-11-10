#!/usr/bin/env python3
"""Hash-update regressions without fetching dependencies or touching real pins."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class SourceBuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        (self.root / "pkgs/source-builds/configs").mkdir(parents=True)
        (self.root / "pkgs/source-builds/hashes").mkdir(parents=True)
        script = (REPO / "scripts/source-build.sh").read_text()
        self.assertTrue(script.endswith('main "$@"\n'))
        self.script = self.root / "scripts/source-build.sh"
        self.script.write_text(script.removesuffix('main "$@"\n'))
        self.config = self.root / "pkgs/source-builds/configs/example.json"
        self.config.write_text(
            json.dumps(
                {
                    "flakeInput": "example-src",
                    "pname": "example",
                    "buildSystem": "rust",
                    "hashField": "cargoHash",
                    "additionalCargoLocks": {"guestCargoHash": "guest/Cargo.lock.in"},
                }
            )
        )
        self.hash_file = self.root / "pkgs/source-builds/hashes/example.json"

    def update(self, initial, fail_guest=False):
        self.hash_file.write_text(json.dumps(initial))
        fail = "return 1" if fail_guest else 'echo "sha256-guest"'
        return subprocess.run(
            [
                "bash",
                "-c",
                f"""
source "{self.script}"
get_locked_rev() {{ echo current; }}
compute_cargo_hash() {{
    if [ -n "${{2:-}}" ]; then
        [ "$2" = guest/Cargo.lock.in ] || return 1
        {fail}
    else
        echo sha256-host
    fi
}}
update_project example
""",
            ],
            text=True,
            capture_output=True,
        )

    def test_missing_extra_hash_updates_even_at_same_revision(self):
        result = self.update({"rev": "current", "cargoHash": "sha256-old"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.hash_file.read_text()),
            {
                "rev": "current",
                "cargoHash": "sha256-host",
                "guestCargoHash": "sha256-guest",
            },
        )

    def test_guest_failure_preserves_entire_previous_hash_record(self):
        old = {
            "rev": "old",
            "cargoHash": "sha256-old",
            "guestCargoHash": "sha256-old-guest",
        }
        result = self.update(old, fail_guest=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(self.hash_file.read_text()), old)

    def test_current_complete_record_does_not_fetch(self):
        old = {
            "rev": "current",
            "cargoHash": "sha256-old",
            "guestCargoHash": "sha256-old-guest",
        }
        result = self.update(old, fail_guest=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.hash_file.read_text()), old)

    def test_stale_revision_refreshes_both_hashes(self):
        result = self.update(
            {
                "rev": "old",
                "cargoHash": "sha256-old",
                "guestCargoHash": "sha256-old-guest",
            }
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads(self.hash_file.read_text())
        self.assertEqual(record["rev"], "current")
        self.assertEqual(record["cargoHash"], "sha256-host")
        self.assertEqual(record["guestCargoHash"], "sha256-guest")


if __name__ == "__main__":
    unittest.main()
