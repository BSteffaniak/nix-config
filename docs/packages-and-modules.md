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

## Validate Changes

```bash
./rebuild.sh --diff                     # this host
./scripts/check-all-hosts.sh compare    # every host vs. saved baseline
```
