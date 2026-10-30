"""Maintain local fleet credentials; invoked by Home Manager, never by a build."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

BEGIN = "# BEGIN NIX-MANAGED SSH FLEET"
END = "# END NIX-MANAGED SSH FLEET"


def update_authorized_keys(path, keys):
    # Do not replace a file owned by another declarative configuration.
    if path.is_symlink():
        raise RuntimeError(f"Refusing to replace symlink: {path}")
    old = path.read_text() if path.exists() else ""
    if old.count(BEGIN) != old.count(END) or old.count(BEGIN) > 1:
        raise RuntimeError("Malformed fleet block in authorized_keys")
    if BEGIN in old:
        start = old.index(BEGIN)
        finish = old.index(END) + len(END)
        if finish < start:
            raise RuntimeError("Reversed fleet block in authorized_keys")
        if old[finish : finish + 1] == "\n":
            finish += 1
        before, after = old[:start], old[finish:]
    else:
        before, after = old, ""
    block = "\n".join([BEGIN, *keys, END]) + "\n" if keys else ""
    new = (
        before
        + ("\n" if before and not before.endswith("\n") and block else "")
        + block
        + after
    )
    if new == old:
        return
    if path.exists():
        shutil.copy2(path, str(path) + f".backup-fleet-{time.time_ns()}")
    fd, name = tempfile.mkstemp(prefix=".authorized_keys-fleet-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(new)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def ensure_key(path, keygen):
    if path.is_symlink() or Path(str(path) + ".pub").is_symlink():
        raise RuntimeError("Fleet key paths must not be symlinks")
    public = Path(str(path) + ".pub")
    if not path.exists():
        if public.exists():
            raise RuntimeError(
                "Public fleet key exists without private key; refusing rotation"
            )
        # Generate inside a private temporary directory, then publish without
        # overwriting any concurrent activation's private key.
        with tempfile.TemporaryDirectory(prefix=".fleet-key-", dir=path.parent) as tmp:
            generated = Path(tmp) / "key"
            subprocess.run(
                [
                    keygen,
                    "-q",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-C",
                    "nix-ssh-fleet",
                    "-f",
                    str(generated),
                ],
                check=True,
            )
            try:
                os.link(generated, path)
            except FileExistsError:
                pass
    path.chmod(0o600)
    derived = subprocess.check_output(
        [keygen, "-y", "-P", "", "-f", str(path)], text=True
    ).strip()
    if public.exists():
        if public.read_text().split()[:2] != derived.split()[:2]:
            raise RuntimeError(
                "Fleet public/private key mismatch; refusing replacement"
            )
    else:
        with public.open("x") as stream:
            stream.write(derived + " nix-ssh-fleet\n")
    public.chmod(0o644)


def main():
    os.umask(0o077)
    directory = Path.home() / ".ssh"
    directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    ensure_key(directory / "id_ed25519_fleet", sys.argv[1])
    keys = json.loads(Path(sys.argv[2]).read_text())
    update_authorized_keys(directory / "authorized_keys", keys)


if __name__ == "__main__":
    main()
