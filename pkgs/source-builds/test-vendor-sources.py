#!/usr/bin/env python3
"""Offline regression tests; pass the patched fetch-cargo-vendor-util path.

Uses real Cargo resolution to verify equal crate versions from distinct sources
remain distinct, rather than merely checking that copying no longer fails.
"""

import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import unittest

UTIL = sys.argv.pop(1)
REGISTRY = "registry+https://github.com/rust-lang/crates.io-index"
GIT = "git+https://example.invalid/fixture?rev="


class VendorSourcesTest(unittest.TestCase):
    def check_sources(self, sources):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging"
            staging.mkdir()
            packages = []
            aliases = []
            dependencies = []
            for index, source in enumerate(sources):
                manifest = (
                    '[package]\nname = "fixture"\nversion = "1.0.0"\nedition = "2021"\n'
                )
                files = {
                    "Cargo.toml": manifest,
                    "src/lib.rs": f"pub const ORIGIN: usize = {index};\n",
                }
                package = (
                    '\n[[package]]\nname = "fixture"\nversion = "1.0.0"\nsource = '
                    + json.dumps(source)
                    + "\n"
                )
                if source == REGISTRY:
                    tarballs = staging / "tarballs"
                    tarballs.mkdir(exist_ok=True)
                    archive = tarballs / "fixture-1.0.0.tar.gz"
                    with tarfile.open(archive, "w:gz") as tar:
                        for name, text in files.items():
                            data = text.encode()
                            entry = tarfile.TarInfo("fixture-1.0.0/" + name)
                            entry.size = len(data)
                            tar.addfile(entry, io.BytesIO(data))
                    package += (
                        "checksum = "
                        + json.dumps(hashlib.sha256(archive.read_bytes()).hexdigest())
                        + "\n"
                    )
                    dependency = '{ package = "fixture", version = "=1.0.0" }'
                else:
                    revision = source.split("#")[1]
                    tree = staging / "git" / revision
                    for name, text in files.items():
                        target = tree / name
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_text(text)
                    dependency = (
                        '{ package = "fixture", git = "https://example.invalid/fixture", rev = '
                        + json.dumps(revision)
                        + " }"
                    )
                packages.append(package)
                aliases.append(f"origin{index} = {dependency}\n")
                dependencies.append(f"fixture 1.0.0 ({source})")

            lock = "version = 4\n" + "".join(packages)
            lock += (
                '\n[[package]]\nname = "consumer"\nversion = "0.1.0"\ndependencies = '
                + json.dumps(dependencies)
                + "\n"
            )
            (staging / "Cargo.lock").write_text(lock)
            vendor = root / "vendor"
            subprocess.run(
                [UTIL, "create-vendor", str(staging), str(vendor)], check=True
            )

            consumer = root / "consumer"
            (consumer / "src").mkdir(parents=True)
            (consumer / "src/lib.rs").write_text("")
            (consumer / "Cargo.toml").write_text(
                '[package]\nname = "consumer"\nversion = "0.1.0"\nedition = "2021"\n[dependencies]\n'
                + "".join(aliases)
            )
            (consumer / "Cargo.lock").write_text(lock)
            (consumer / ".cargo").mkdir()
            config = (
                (vendor / ".cargo/config.toml")
                .read_text()
                .replace("@vendor@", str(vendor))
            )
            tomllib.loads(config)
            (consumer / ".cargo/config.toml").write_text(config)
            result = subprocess.run(
                ["cargo", "metadata", "--offline", "--locked", "--format-version", "1"],
                cwd=consumer,
                check=True,
                capture_output=True,
                text=True,
            )
            resolved = [
                p
                for p in json.loads(result.stdout)["packages"]
                if p["name"] == "fixture"
            ]
            self.assertEqual(len(resolved), len(sources))
            self.assertEqual(len({p["manifest_path"] for p in resolved}), len(sources))
            for package in resolved:
                origin = sources.index(package["source"])
                self.assertIn(
                    f"= {origin};",
                    Path(package["manifest_path"])
                    .with_name("src")
                    .joinpath("lib.rs")
                    .read_text(),
                )

    def test_registry_only(self):
        self.check_sources([REGISTRY])

    def test_registry_and_git(self):
        self.check_sources([REGISTRY, GIT + "a" * 40 + "#" + "a" * 40])

    def test_two_git_revisions(self):
        self.check_sources([GIT + rev * 40 + "#" + rev * 40 for rev in ["a", "b"]])


if __name__ == "__main__":
    unittest.main()
