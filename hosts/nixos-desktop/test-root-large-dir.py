#!/usr/bin/env python3
"""Unprivileged tests: only sparse temporary ext4 images, never a real device."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).with_name("root-large-dir.sh").read_text()
UUID = "015f9988-3f81-48a8-983c-a81166edcd18"


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="root-large-dir-test-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.image = self.directory / "root.ext4"
        with self.image.open("wb") as image:
            image.truncate(64 * 1024 * 1024)
        subprocess.run(
            [
                "mke2fs",
                "-q",
                "-t",
                "ext4",
                "-O",
                "^large_dir",
                "-U",
                UUID,
                str(self.image),
            ],
            check=True,
        )
        for name, content in {
            "cmdline": "quiet\n",
            "swaps": "Filename Type Size Used Priority\n",
            "mountinfo": "",
        }.items():
            (self.directory / name).write_text(content)
        # Test adapter: replace ONLY the device and kernel state inputs.
        script = SOURCE.replace(
            'device="/dev/disk/by-uuid/$expected_uuid"', f'device="{self.image}"'
        ).replace('[ -b "$device" ]', '[ -f "$device" ]')
        for kernel_path, fixture in {
            "/proc/cmdline": "cmdline",
            "/proc/swaps": "swaps",
            "/proc/self/mountinfo": "mountinfo",
        }.items():
            script = script.replace(kernel_path, str(self.directory / fixture))
        self.script = self.directory / "migration.sh"
        self.script.write_text(script)
        self.env = os.environ.copy()
        if os.environ.get("MIGRATION_TEST_UTILS"):
            self.env["PATH"] = (
                os.environ["MIGRATION_TEST_UTILS"] + os.pathsep + self.env["PATH"]
            )

    def run_migration(self, expected=0):
        result = subprocess.run(
            [os.environ.get("MIGRATION_TEST_SHELL", "bash"), str(self.script)],
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def features(self):
        return subprocess.check_output(["tune2fs", "-l", str(self.image)], text=True)

    def test_enable_and_rerun(self):
        self.assertNotIn("large_dir", self.features())
        self.assertIn("migration complete", self.run_migration())
        self.assertIn("large_dir", self.features())
        self.assertIn("already enabled", self.run_migration())

    def test_wrong_uuid(self):
        subprocess.run(["tune2fs", "-U", "random", str(self.image)], check=True)
        self.assertIn("UUID mismatch", self.run_migration(1))

    def test_mounted_device(self):
        # Regular test image has device number 0:0.
        (self.directory / "mountinfo").write_text("1 2 0:0 / /mnt rw - ext4 image rw\n")
        self.assertIn("already mounted", self.run_migration(1))
        self.assertNotIn("large_dir", self.features())

    def test_active_swap(self):
        (self.directory / "swaps").write_text("header\n/swap file 1 0 -2\n")
        self.assertIn("Swap is active", self.run_migration(1))

    def test_resume(self):
        (self.directory / "cmdline").write_text("quiet resume=/dev/test\n")
        self.assertIn("Resume is configured", self.run_migration(1))

    def mock_check(self, status):
        binary_dir = self.directory / "bin"
        binary_dir.mkdir()
        checker = binary_dir / "e2fsck"
        checker.write_text(f"#!/bin/sh\nexit {status}\n")
        checker.chmod(0o755)
        self.env["PATH"] = str(binary_dir) + os.pathsep + self.env["PATH"]

    def test_fsck_failure(self):
        self.mock_check(4)
        self.assertIn("e2fsck failed", self.run_migration(1))
        self.assertNotIn("large_dir", self.features())

    def test_fsck_reboot(self):
        self.mock_check(2)
        self.assertIn("requires a reboot", self.run_migration(2))
        self.assertNotIn("large_dir", self.features())

    def test_fsck_corrected(self):
        self.mock_check(1)
        self.assertIn("migration complete", self.run_migration())


if __name__ == "__main__":
    for tool in ("bash", "mke2fs", "tune2fs", "e2fsck", "blkid"):
        if not shutil.which(tool):
            raise SystemExit(f"Missing test prerequisite: {tool}")
    unittest.main()
