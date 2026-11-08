#!/usr/bin/env python3
"""Onboarding regressions; isolated fixtures never rename or activate the real host."""
import os
import pty
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class OnboardingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        (self.root / "hosts").mkdir()
        for name in ("host-common.sh", "new-host-template.sh", "rebuild-onboarding.sh"):
            shutil.copy(REPO / "scripts" / name, self.root / "scripts" / name)
        shutil.copy(REPO / "rebuild.sh", self.root / "rebuild.sh")

    def generate(self, host="example", *extra):
        return subprocess.run(
            [
                "bash",
                str(self.root / "scripts/new-host-template.sh"),
                "--platform",
                "darwin",
                "--arch",
                "aarch64-darwin",
                "--hostname",
                host,
                "--username",
                "elise",
                "--fullname",
                'Elise "${literal}"',
                *extra,
            ],
            text=True,
            capture_output=True,
        )

    def test_minimal_default_and_overwrite(self):
        self.assertEqual(self.generate().returncode, 0)
        host = self.root / "hosts/example"
        self.assertIn('username = "elise";', (host / "meta.nix").read_text())
        self.assertIn("ssh.fleet.enable = true", (host / "home.nix").read_text())
        self.assertNotIn("development.", (host / "home.nix").read_text())
        original = (host / "home.nix").read_bytes()
        self.assertNotEqual(self.generate().returncode, 0)
        self.assertEqual(original, (host / "home.nix").read_bytes())

    def test_reject_path_traversal_and_bad_architecture(self):
        self.assertNotEqual(self.generate("../escape").returncode, 0)
        self.assertNotEqual(
            self.generate("bad", "--arch", "x86_64-linux").returncode, 0
        )
        self.assertEqual(list((self.root / "hosts").iterdir()), [])

    def test_custom_generation_and_string_escaping(self):
        result = self.generate(
            "custom", "--custom", "--computer-name", 'Elise "${literal}"'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        text = (self.root / "hosts/custom/default.nix").read_text()
        self.assertIn(r"Elise \"\${literal}\"", text)
        self.assertIn(
            "development.rust.enable = true",
            (self.root / "hosts/custom/home.nix").read_text(),
        )

    def mock_mac(self, hostname="unknown", fail_rename=False, missing_account=False):
        self.assertEqual(self.generate().returncode, 0)
        bindir = self.root / "bin"
        bindir.mkdir()
        (self.root / "hostname").write_text(hostname)
        commands = {
            "hostname": f"cat '{self.root}/hostname'",
            "uname": 'case "$1" in -s) echo Darwin;; -m) echo arm64;; esac',
            "id": "exit 1" if missing_account else "exit 0",
            "sudo": 'exec "$@"',
            "scutil": (
                f'if [ "$1" = --set ]; then echo "$*" >> "{self.root}/renames"; '
                + (
                    "exit 1; "
                    if fail_rename
                    else f'if [ "$2" = HostName ]; then echo "$3" > "{self.root}/hostname"; fi; '
                )
                + "else echo old-local-name; fi"
            ),
            "darwin-rebuild": f'echo "$*" >> "{self.root}/builds"',
            "nvd": "exit 0",
        }
        for name, body in commands.items():
            path = bindir / name
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        return {**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}"}

    def interactive_rebuild(self, answers, env, *args):
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(
                ["bash", str(self.root / "rebuild.sh"), *args],
                stdin=slave,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=self.root,
                env=env,
            )
            os.write(master, answers.encode())
            try:
                output, _ = process.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()
                raise
            return process.returncode, output
        finally:
            os.close(master)
            os.close(slave)

    def test_interactive_rename_builds_only(self):
        env = self.mock_mac()
        code, output = self.interactive_rebuild("example\ny\n", env)
        self.assertEqual(code, 0, output)
        self.assertEqual((self.root / "hostname").read_text().strip(), "example")
        renames = (self.root / "renames").read_text()
        self.assertIn("--set LocalHostName example", renames)
        self.assertNotIn("ComputerName", renames)
        builds = (self.root / "builds").read_text()
        self.assertIn("build --flake path:", builds)
        self.assertNotIn("switch", builds)

    def test_interactive_cancel(self):
        env = self.mock_mac()
        code, _ = self.interactive_rebuild("example\nn\n", env)
        self.assertNotEqual(code, 0)
        self.assertFalse((self.root / "renames").exists())
        self.assertFalse((self.root / "builds").exists())

    def test_interactive_rename_failure(self):
        env = self.mock_mac(fail_rename=True)
        code, _ = self.interactive_rebuild("example\ny\n", env)
        self.assertNotEqual(code, 0)
        self.assertFalse((self.root / "builds").exists())

    def test_interactive_missing_account(self):
        env = self.mock_mac(missing_account=True)
        code, output = self.interactive_rebuild("example\ny\n", env)
        self.assertNotEqual(code, 0)
        self.assertIn("does not exist", output)
        self.assertFalse((self.root / "renames").exists())

    def test_interactive_incompatible_architecture(self):
        env = self.mock_mac()
        meta = self.root / "hosts/example/meta.nix"
        meta.write_text(meta.read_text().replace("aarch64-darwin", "x86_64-darwin"))
        code, output = self.interactive_rebuild("example\ny\n", env)
        self.assertNotEqual(code, 0)
        self.assertIn("incompatible", output)
        self.assertFalse((self.root / "renames").exists())

    def test_matching_hostname_diff_does_not_prompt_or_rename(self):
        env = self.mock_mac(hostname="example")
        code, output = self.interactive_rebuild("", env, "--diff")
        self.assertEqual(code, 0, output)
        self.assertFalse((self.root / "renames").exists())
        self.assertIn("build --flake", (self.root / "builds").read_text())

    def test_first_time_darwin_diff_never_activates(self):
        env = self.mock_mac(hostname="example")
        (self.root / "bin/darwin-rebuild").unlink()
        nix = self.root / "bin/nix"
        nix.write_text(f'#!/bin/sh\necho "$*" > "{self.root}/builds"\n')
        nix.chmod(0o755)
        code, output = self.interactive_rebuild("", env, "--diff")
        self.assertEqual(code, 0, output)
        self.assertIn("No activation performed", output)
        self.assertNotIn("switch", (self.root / "builds").read_text())

    def test_unknown_host_noninteractive_and_diff_never_mutate(self):
        self.assertEqual(self.generate().returncode, 0)
        bindir = self.root / "bin"
        bindir.mkdir()
        marker = self.root / "mutated"
        for name, body in {
            "hostname": "echo unknown-test-machine",
            "sudo": f"touch '{marker}'; exit 99",
        }.items():
            path = bindir / name
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        for args in ([], ["--diff"], ["--compare"]):
            result = subprocess.run(
                ["bash", str(self.root / "rebuild.sh"), *args],
                input="example\ny\n",
                text=True,
                capture_output=True,
                env={**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}"},
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No changes made", result.stdout)
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
