# Packages and Modules

Back to overview: `README.md`

This repo is home-manager-first: every user-facing tool is declared in the host's `home.nix`, on every platform.

## Rule of Thumb

- User tool, editor, CLI, dev toolchain, desktop app config → Home Manager (`home/modules/`, `home.packages`)
- Needs root, a daemon, or OS integration → system modules (`modules/`)

## Module Hierarchy

System modules (`modules/`):

- `modules/common/` — login shells, sshd/tailscale options, baseline packages
- `modules/nixos/` — boot, hardware, desktop compositor, services, system settings
- `modules/darwin/` — Homebrew casks (`casks.nix`), system defaults, launchd daemons, security

Home Manager modules (`home/`):

- `home/common/` — shared for every host (imports `home/modules`)
- `home/modules/` — all feature modules, grouped by area
- `home/nixos/`, `home/darwin/`, `home/standalone/` — thin platform bridges

The bridges mirror only system-owned settings (login shells, compositor enablement, a couple of cask-backed apps) from `osConfig`. They do not mirror user tools.

## Where to Add Packages

- CLI tools: `home/modules/cli-tools/`
- Dev tools/languages: `home/modules/development/`
- DevOps tools: `home/modules/devops/`
- Containers: `home/modules/containers/`
- Desktop apps/utilities: `home/modules/desktop/`
- Other shared user tools: `home/modules/tools/`
- Shell config: `home/modules/shell/` (fish lives in `shell/fish/`)

System-level only when required:

- NixOS services/system features: `modules/nixos/`
- Darwin system settings/casks: `modules/darwin/` (one-line casks go in `casks.nix`)

Host-specific overrides:

- `hosts/<host>/home.nix` for user-scoped host changes
- `hosts/<host>/default.nix` for system-scoped host changes

## Feature Flags

Configurable behavior is exposed under `myConfig.*` on both layers.

```nix
options.myConfig.tools.encryption.enable = lib.mkEnableOption "Encryption tools";
```

```nix
myConfig.tools.encryption.enable = true;
```

Module-to-module contributions (aliases, PATH entries, completion hooks) go through the internal `myConfig.shell.contrib.*` options; host files use `myConfig.shell.shared.*`, which wins on collisions.

## Hex Voice Dictation

Enable the portable user-facing switch in `hosts/<host>/home.nix`:

```nix
myConfig.desktop.hex.enable = true;
```

- **x86_64 Linux:** installs the pinned Rust Linux beta via upstream's Nix package
  and Home Manager module, including the per-user `hex.service`. `openOnLogin`
  defaults to true; set it to false to start manually with `hex start`.
- **nix-darwin:** installs the existing `kitlangton-hex` Homebrew cask and manages
  its macOS preferences. This does not migrate macOS to the Rust beta.
  `showDockIcon` defaults to false. The old `myConfig.darwin.hex.enable` remains
  compatible, but new hosts should use only the home-level switch.
- **Other platforms:** warns and skips installation. Standalone macOS Home
  Manager cannot provision the Homebrew cask.

Linux requires working microphone/audio and Vulkan drivers (also for Settings
with CPU inference). Native Wayland currently supports compatible wlroots
compositors such as Hyprland/Sway, not GNOME/KDE. On standalone Linux, graphics
integration and input permissions must be supplied by the host OS.

For Wayland hotkeys on NixOS, explicitly opt in at system level in `default.nix`:

```nix
myConfig.desktop.hex.enableInputAccess = true;
```

This adds only users with Hex enabled to the `input` group. **Every process
running as those users can read raw keyboard events and other input devices.**
A system rebuild and logout/login are required; no device permissions are made
world-readable. Leave this off if that access is unacceptable.

Autostart follows `graphical-session.target`; the desktop session must import
its display environment into the systemd user manager and start/stop that
session target. The shared Hyprland home module also starts/stops Hex directly
with the compositor when `openOnLogin` is enabled, so direct Hyprland sessions
do not depend on a session manager starting that target. Override `myConfig.desktop.hex.systemdTarget` for other session
targets. The module does not create a desktop session or install GPU drivers.

After building and switching, run as your normal desktop user:

```sh
hex model install  # downloads a model to user data, not the Nix store
hex app            # Settings; choose microphone, model and shortcut
hex status         # service status
```

Linux preferences can be declared using the native JSON keys:

```nix
myConfig.desktop.hex.settings = {
  dictation_hotkey = {
    control = false;
    alt = true;
    shift = false;
    super_key = false;
    key = "space";
  };
  double_tap_lock = false;
  paste_with_shift = false;
  sound_effect_volume = 0.5;
  transcription = {
    model = "parakeet_unified_en";
    language = "en";
    recognition_hints = "";
  };
};
```

The default `settings = null` leaves UI-managed preferences untouched. When set,
activation installs a writable `linux-settings.json` in the user data directory;
Hex can still save UI changes, but the next activation restores the declared
settings. Restart Hex after activation to load changes. Settings are public Nix
store content: never include secrets. These native Linux settings are ignored
on macOS. Model downloads remain a separate manual step.

The local `linux-right-alt.patch` supports `dictation_hotkey.key = "right_alt"`
on native Wayland with all modifier flags false. Hold Right Alt to record and
release to paste globally; Left Alt does not trigger it. The key is observed,
not swallowed, so apps still receive Alt/AltGr. This config-only shortcut is not
supported by the X11 backend or UI shortcut capture. The UI label displays
“Right Alt”.

Use `hex restart` in your desktop session, without sudo. Upstream's CLI had a
10-second control timeout, shorter than its service's 30-second stop limit;
`linux-service-timeout.patch` allows 75 seconds for stop/start. This does not fix
an underlying shutdown hang: systemd may still force-kill the old process after
30 seconds. Check `hex status` and `journalctl --user -u hex.service` if restarting
is slow or fails.

Models are not downloaded during activation. Nix owns application updates;
update the `hex` flake input and rebuild. The pinned 2.1.25 source needs the
small borrow fix in `pkgs/hex/linux-gguf-path.patch`; remove it once upstream
contains the fix. Test recording and pasting in a disposable text field before
relying on dictation.

## Validate Changes

```bash
./rebuild.sh --diff                     # this host
./scripts/check-all-hosts.sh compare    # every host vs. saved baseline
```
