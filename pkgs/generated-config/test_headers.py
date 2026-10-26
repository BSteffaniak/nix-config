"""Run with: python3 -m unittest discover -s pkgs/generated-config -p 'test_*.py'."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "add_header", Path(__file__).with_name("add-header.py")
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GeneratedHeaderTests(unittest.TestCase):
    def annotate(self, content, target):
        return module.annotate(content, target, "/home/test/.config/nix")

    def test_comment_formats(self):
        for name, prefix in [
            ("x.toml", b"#"),
            ("x.lua", b"--"),
            ("x.jsonc", b"//"),
            ("x.kdl", b"//"),
            ("x.css", b"/*"),
            ("x.xml", b"<!--"),
            (".ssh/config", b"#"),
            ("ghostty/config", b"#"),
        ]:
            with self.subTest(name=name):
                output = self.annotate(b"content\n", name)
                self.assertTrue(output.startswith(prefix))
                self.assertIn(b"/home/test/.config/nix", output)
                self.assertTrue(output.endswith(b"content\n"))
                self.assertEqual(self.annotate(output, name), output)

    def test_unsupported_and_binary_unchanged(self):
        for name, content in [
            ("settings.json", b'{"a": 1}'),
            ("unknown", b"text"),
            ("x.toml", b"binary\x00data"),
            ("x.ini", b"\xff"),
        ]:
            with self.subTest(name=name):
                self.assertEqual(self.annotate(content, name), content)

    def test_preambles(self):
        for name, preamble in [
            ("x.sh", b"#!/bin/sh\n"),
            ("x.xml", b'<?xml version="1.0"?>\n'),
            ("x.css", b'@charset "UTF-8";\n'),
            ("x.py", b"#!/usr/bin/python\n# coding: utf-8\n"),
        ]:
            with self.subTest(name=name):
                self.assertTrue(
                    self.annotate(preamble + b"body\n", name).startswith(preamble)
                )
        self.assertTrue(
            self.annotate(b"\xef\xbb\xbfbody", "x.toml").startswith(b"\xef\xbb\xbf#")
        )
        self.assertTrue(self.annotate(b"#!/bin/sh", "x.sh").startswith(b"#!/bin/sh\n#"))

    def test_conf_grammars(self):
        self.assertTrue(
            self.annotate(b"<?xml version='1.0'?>\n<root/>", "x.conf").startswith(
                b"<?xml version='1.0'?>\n<!--"
            )
        )
        self.assertEqual(self.annotate(b'{"a": 1}', "x.conf"), b'{"a": 1}')

    def test_systemd_dependency_links_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            unit = source / "home-manager-test.service"
            unit.write_text("[Service]\nType=oneshot\n")
            for suffix in ("wants", "requires", "upholds"):
                dependencies = source / ("multi-user.target." + suffix)
                dependencies.mkdir()
                (dependencies / unit.name).symlink_to("../" + unit.name)
            output = root / "out"
            module.generate(source, output, "systemd/system", "/checkout")
            for suffix in ("wants", "requires", "upholds"):
                link = output / ("multi-user.target." + suffix) / unit.name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.readlink(), Path("../" + unit.name))
                self.assertEqual(link.resolve(), (output / unit.name).resolve())
            self.assertIn("DO NOT EDIT", (output / unit.name).read_text())

    def test_directory_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            script = source / "run.sh"
            script.write_text("#!/bin/sh\necho test\n")
            script.chmod(0o755)
            (source / "settings.json").write_text('{"a":1}')
            (source / "mutable.toml").symlink_to(root / "external.toml")
            (root / "external.toml").write_text("x = 1\n")
            output = root / "out"
            module.generate(source, output, ".config/test", "/checkout")
            self.assertEqual((output / "run.sh").stat().st_mode & 0o777, 0o755)
            self.assertIn("DO NOT EDIT", (output / "run.sh").read_text())
            self.assertTrue((output / "settings.json").is_symlink())
            self.assertTrue((output / "mutable.toml").is_symlink())
            self.assertEqual((output / "mutable.toml").read_text(), "x = 1\n")


if __name__ == "__main__":
    unittest.main()
