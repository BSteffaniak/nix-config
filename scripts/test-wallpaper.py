#!/usr/bin/env python3
"""Offline regression tests for wallpaper cache and rotation."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "configs/waypaper/wallpaper.py"
spec = importlib.util.spec_from_file_location("wallpaper", MODULE)
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.config = {
            "directory": str(root / "images"),
            "stateDirectory": str(root / "state"),
            "source": "wallhaven",
            "wallhaven": {
                "query": "",
                "queries": ["mountains", "forest"],
                "categories": "100",
                "purity": "100",
                "sorting": "random",
                "ratios": ["16x9"],
                "atleast": "3840x2160",
                "imagesPerQuery": 2,
            },
            "retentionDays": 90,
            "maxImages": 200,
            "setDesktop": False,
            "platform": "darwin",
        }
        self.app = wallpaper.Wallpaper(self.config)

    def image(self, name):
        path = self.app.directory / name
        path.write_bytes(b"\xff\xd8\xffimage")
        return str(path)

    def test_shuffle_persists_and_does_not_repeat_across_cycles(self):
        images = {self.image(f"image-{i}.jpg") for i in range(5)}
        selections = []
        with patch.object(
            wallpaper.Wallpaper, "replenish", side_effect=AssertionError("network")
        ):
            for _ in range(3):
                cycle = []
                for _ in range(5):
                    # Fresh process-equivalent object on each invocation.
                    selected = wallpaper.Wallpaper(self.config).rotate()
                    if selections:
                        self.assertNotEqual(selected, selections[-1])
                    selections.append(selected)
                    cycle.append(selected)
                self.assertEqual(set(cycle), images)

    def test_apply_current_does_not_advance_history(self):
        for i in range(3):
            self.image(f"{i}.jpg")
        selected = self.app.rotate()
        history = (self.app.state / "seen.json").read_text()
        self.assertEqual(self.app.rotate(apply_current=True), selected)
        self.assertEqual((self.app.state / "seen.json").read_text(), history)

    def test_single_image_and_deleted_images(self):
        only = self.image("only.jpg")
        self.assertEqual(self.app.rotate(), only)
        self.assertEqual(self.app.rotate(), only)
        Path(only).unlink()
        other = self.image("other.png")
        self.assertEqual(self.app.rotate(), other)

    def test_failed_apply_preserves_state(self):
        self.image("one.jpg")
        self.image("two.jpg")
        self.app.rotate()
        before = self.app.current()
        history = (self.app.state / "seen.json").read_text()
        with patch.object(
            self.app, "apply", side_effect=subprocess.CalledProcessError(1, "setter")
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                self.app.rotate()
        self.assertEqual(self.app.current(), before)
        self.assertEqual((self.app.state / "seen.json").read_text(), history)

    def test_empty_cache_bootstraps_then_rotates_offline(self):
        with patch.object(
            self.app, "replenish", side_effect=lambda: self.image("boot.jpg")
        ) as replenish:
            self.app.rotate()
            self.app.rotate()
            self.assertEqual(replenish.call_count, 1)

    def test_refresh_independent_queries_and_partial_failure(self):
        def metadata(url):
            if "mountains" in url:
                raise ValueError("offline query")
            return {
                "data": [{"id": "abc123", "path": "https://w.wallhaven.cc/abc123.jpg"}]
            }

        with patch.object(
            self.app, "metadata", side_effect=metadata
        ) as fetch, patch.object(
            self.app,
            "download",
            side_effect=lambda url, path: path.write_bytes(b"\xff\xd8\xffimage"),
        ):
            with self.assertRaises(RuntimeError):
                self.app.replenish()
            self.assertEqual(fetch.call_count, 2)
        self.assertEqual(len(self.app.images()), 1)
        # Refresh does not select a wallpaper; the cache is usable despite failure.
        self.assertEqual(self.app.current(), "")
        self.app.rotate()

    def test_prune_preserves_current_and_user_images(self):
        current = self.image("wallhaven-current.jpg")
        wallpaper.atomic_write(self.app.state / "current", current)
        custom = self.image("my-photo.jpg")
        self.image("wallhaven-old.jpg")
        self.image("wallhaven-new.jpg")
        self.config["maxImages"] = 1
        self.app.prune()
        self.assertTrue(Path(current).exists())
        self.assertTrue(Path(custom).exists())
        self.assertLessEqual(len(self.app.images()), 3)

    def test_download_validation_and_cleanup(self):
        with patch.object(
            self.app,
            "download",
            side_effect=lambda url, path: path.write_text("not an image"),
        ):
            with self.assertRaises(ValueError):
                self.app.cache_image("https://example.org/a.jpg", "wallhaven-a.jpg")
        self.assertEqual(list(self.app.directory.iterdir()), [])

    def test_platform_setters(self):
        image = self.image("image with spaces.jpg")
        self.config["setDesktop"] = True
        with patch.object(wallpaper.subprocess, "run") as run:
            self.app.apply(image)
            self.assertEqual(run.call_args.args[0], ["/usr/bin/osascript", "-", image])
            self.config["platform"] = "linux"
            with patch.dict(wallpaper.os.environ, {"XDG_CURRENT_DESKTOP": "Hyprland"}):
                self.app.apply(image)
            self.assertEqual(run.call_args.args[0], ["waypaper", "--wallpaper", image])
            with patch.dict(
                wallpaper.os.environ,
                {
                    "XDG_CURRENT_DESKTOP": "ubuntu:GNOME",
                    "GSETTINGS_SCHEMA_DIR": "/wrong",
                },
            ):
                self.app.apply(image)
            self.assertEqual(
                run.call_args.args[0][-2:], ["picture-uri-dark", Path(image).as_uri()]
            )
            self.assertNotIn("GSETTINGS_SCHEMA_DIR", run.call_args.kwargs["env"])

    def test_prune_expired_download_but_not_current(self):
        current = self.image("wallhaven-current.jpg")
        expired = self.image("wallhaven-expired.jpg")
        wallpaper.atomic_write(self.app.state / "current", current)
        for path in (current, expired):
            wallpaper.os.utime(path, (0, 0))
        self.app.prune()
        self.assertTrue(Path(current).exists())
        self.assertFalse(Path(expired).exists())

    def test_cli_offline(self):
        self.image("local.jpg")
        config = Path(self.temp.name) / "settings.json"
        config.write_text(json.dumps(self.config))
        result = subprocess.run(
            ["python3", str(MODULE), "--config", str(config), "--rotate"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("local.jpg", result.stdout)


if __name__ == "__main__":
    unittest.main()
