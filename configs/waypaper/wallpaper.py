"""Cached wallpaper downloads and persistent shuffle rotation (macOS/Wayland)."""

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time
from urllib.parse import urlencode, urlparse


def atomic_write(path, text):
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(text)
    temporary.replace(path)


class Wallpaper:
    def __init__(self, config):
        self.config = config
        self.directory = Path(os.path.expandvars(config["directory"])).expanduser()
        self.state = Path(config["stateDirectory"])
        self.directory.mkdir(parents=True, exist_ok=True)
        self.state.mkdir(parents=True, exist_ok=True)

    @contextlib.contextmanager
    def lock(self, name):
        with (self.state / (name + ".lock")).open("w") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            yield

    def current(self):
        path = self.state / "current"
        return path.read_text().strip() if path.exists() else ""

    def images(self):
        return sorted(
            str(path)
            for path in self.directory.iterdir()
            if path.is_file()
            and path.suffix.lower() in (".jpg", ".jpeg", ".png")
            and path.stat().st_size > 0
        )

    def download(self, url, destination):
        # curl uses the same Nix-provided CA configuration as the old downloader.
        subprocess.run(
            [
                "curl",
                "--fail",
                "--location",
                "--silent",
                "--show-error",
                "--retry",
                "2",
                "--connect-timeout",
                "10",
                "--max-time",
                "90",
                url,
                "--output",
                str(destination),
            ],
            check=True,
        )

    def metadata(self, url):
        path = self.state / "metadata.tmp"
        try:
            self.download(url, path)
            return json.loads(path.read_text())
        finally:
            path.unlink(missing_ok=True)

    def cache_image(self, url, name):
        destination = self.directory / name
        if destination.exists() and destination.stat().st_size:
            return
        temporary = destination.with_name(destination.name + ".tmp")
        try:
            self.download(url, temporary)
            with temporary.open("rb") as handle:
                magic = handle.read(8)
            if not (magic.startswith(b"\xff\xd8\xff") or magic == b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Download is not a JPEG or PNG")
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)

    def replenish(self):
        with self.lock("download"):
            failures = []
            if self.config["source"] == "wallhaven":
                wallhaven = self.config["wallhaven"]
                queries = (
                    [wallhaven["query"]] if wallhaven["query"] else wallhaven["queries"]
                )
                for query in queries:
                    try:
                        params = {
                            "q": query,
                            "categories": wallhaven["categories"],
                            "purity": wallhaven["purity"],
                            "sorting": wallhaven["sorting"],
                            "ratios": ",".join(wallhaven["ratios"]),
                            "atleast": wallhaven["atleast"],
                        }
                        data = self.metadata(
                            "https://wallhaven.cc/api/v1/search?" + urlencode(params)
                        )
                        if not data["data"]:
                            raise ValueError(f"No results for {query!r}")
                        for image in data["data"][: wallhaven["imagesPerQuery"]]:
                            try:
                                image_id = image["id"]
                                if not image_id.isalnum():
                                    raise ValueError("Invalid Wallhaven image ID")
                                extension = Path(
                                    urlparse(image["path"]).path
                                ).suffix.lower()
                                if extension not in (".jpg", ".jpeg", ".png"):
                                    raise ValueError(
                                        "Unsupported Wallhaven image format"
                                    )
                                self.cache_image(
                                    image["path"], f"wallhaven-{image_id}{extension}"
                                )
                            except (
                                OSError,
                                ValueError,
                                KeyError,
                                subprocess.CalledProcessError,
                            ) as error:
                                failures.append(str(error))
                    except (
                        OSError,
                        ValueError,
                        KeyError,
                        subprocess.CalledProcessError,
                    ) as error:
                        failures.append(str(error))
            else:
                try:
                    params = urlencode(
                        {
                            "format": "js",
                            "idx": 0,
                            "n": 1,
                            "mkt": self.config["bing"]["market"],
                        }
                    )
                    image = self.metadata(
                        "https://www.bing.com/HPImageArchive.aspx?" + params
                    )["images"][0]
                    name = "bing-" + time.strftime("%Y%m%d") + ".jpg"
                    preferred = (
                        "https://www.bing.com"
                        + image["urlbase"]
                        + "_"
                        + self.config["bing"]["resolution"]
                        + ".jpg"
                    )
                    try:
                        self.cache_image(preferred, name)
                    except (OSError, ValueError, subprocess.CalledProcessError):
                        self.cache_image("https://www.bing.com" + image["url"], name)
                except (
                    OSError,
                    ValueError,
                    KeyError,
                    IndexError,
                    subprocess.CalledProcessError,
                ) as error:
                    failures.append(str(error))
            self.prune()
            for failure in failures:
                print("Wallpaper download: " + failure, file=sys.stderr)
            if failures:
                raise RuntimeError(
                    "Some wallpaper downloads failed; cached rotation remains available"
                )

    def prune(self):
        # Never remove user-supplied images or the currently applied wallpaper.
        # Serialize cleanup with selection so an image cannot disappear mid-apply.
        with self.lock("rotation"):
            current = self.current()
            generated = sorted(
                (
                    Path(path)
                    for path in self.images()
                    if Path(path).name.startswith(("wallhaven-", "bing-"))
                ),
                key=lambda path: path.stat().st_mtime,
                reverse=True,
            )
            days = self.config["retentionDays"]
            for index, path in enumerate(generated):
                expired = days > 0 and time.time() - path.stat().st_mtime > days * 86400
                if str(path) != current and (
                    expired or index >= self.config["maxImages"]
                ):
                    path.unlink()

    def apply(self, image):
        if not self.config["setDesktop"]:
            return
        if self.config["platform"] == "darwin":
            subprocess.run(
                ["/usr/bin/osascript", "-", image],
                input="""on run argv
  tell application "System Events"
    repeat with aDesktop in desktops
      set picture of aDesktop to item 1 of argv
    end repeat
  end tell
end run
""",
                text=True,
                check=True,
            )
        elif "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
            # Use Ubuntu's native schemas rather than Nix's unrelated schema path.
            environment = os.environ.copy()
            environment.pop("GSETTINGS_SCHEMA_DIR", None)
            for key in ("picture-uri", "picture-uri-dark"):
                subprocess.run(
                    [
                        "/usr/bin/gsettings",
                        "set",
                        "org.gnome.desktop.background",
                        key,
                        Path(image).as_uri(),
                    ],
                    env=environment,
                    check=True,
                )
        else:
            # Waypaper also persists the selection for its UI/restore command.
            subprocess.run(["waypaper", "--wallpaper", image], check=True)

    def rotate(self, apply_current=False):
        # Bootstrap only when empty. Normal rotation never needs the network.
        if not self.images():
            try:
                self.replenish()
            except RuntimeError as error:
                print(error, file=sys.stderr)
        with self.lock("rotation"):
            images = self.images()
            if not images:
                raise RuntimeError("No cached wallpaper images available")
            current = self.current()
            if apply_current and current in images:
                self.apply(current)
                return current
            history_path = self.state / "seen.json"
            seen = (
                set(json.loads(history_path.read_text()))
                if history_path.exists()
                else set()
            )
            seen.intersection_update(images)
            candidates = set(images) - seen - {current}
            if not candidates:
                seen = set()
                candidates = set(images) - {current}
            selected = random.choice(sorted(candidates or set(images)))
            self.apply(selected)
            # Commit only after the platform setter succeeds.
            atomic_write(self.state / "current", selected + "\n")
            atomic_write(history_path, json.dumps(sorted(seen | {selected})))
            print(selected)
            return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument(
        "--refresh",
        action="store_true",
        help="Replenish cache without changing wallpaper",
    )
    modes.add_argument("--apply-current", action="store_true")
    modes.add_argument("--rotate", action="store_true")
    args = parser.parse_args()
    wallpaper = Wallpaper(json.loads(Path(args.config).read_text()))
    if args.refresh:
        wallpaper.replenish()
    else:
        wallpaper.rotate(args.apply_current)


if __name__ == "__main__":
    main()
