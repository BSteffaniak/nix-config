# Agent Guidelines for Nix Configuration

This document provides guidance for AI agents and contributors working on this Nix configuration repository.

## Architecture Overview

This configuration manages multiple hosts across different platforms:

- **NixOS** (nixos-desktop) - Full NixOS system configuration
- **nix-darwin** (macbook-air, mac-studio, bs-mbpro) - macOS with nix-darwin
- **Standalone home-manager** (ubuntu-laptop) - Home-manager only on non-NixOS Linux

### Repository Layout

```text
flake.nix          Inputs + thin outputs; everything else is delegated
lib/               Pure Nix helpers (no package data)
  hosts.nix          Host discovery + nixos/darwin/home-manager builders
  dev-shell.nix      `nix develop` shell
  locked-source.nix  flake.lock rev lookup + stale-hash check for source builds
  read-json-dir.nix  Read a directory of *.json into an attrset
  mk-cask-module.nix Generate a `myConfig.darwin.<name>.enable` Homebrew cask option
overlays/          One file per overlay; `default.nix` returns the ordered list
pkgs/              Data for generated packages (source-builds, github-releases, minecraft-plugins, display-ctl)
modules/           System modules (common/, nixos/, darwin/)
home/              Home Manager modules (common/, modules/, plus nixos/, darwin/, standalone/ bridges)
hosts/             One directory per host (meta.nix, default.nix, home.nix)
scripts/           Operational scripts (see scripts/README.md)
configs/           Portable standalone dot-configs symlinked by home modules
```

### Host Auto-Discovery

Hosts are **automatically discovered** from `hosts/*/meta.nix` by `lib/hosts.nix`. It generates `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations` outputs from each host's `meta.nix`. Neither `flake.nix` nor `rebuild.sh` need manual edits when adding or removing hosts.

`meta.nix` is the single source of host identity. It drives `networking.hostName`, `system.primaryUser`, `home.username`, `home.homeDirectory`, `system.stateVersion`, and `home.stateVersion` (all as `mkDefault`, so a host file can still override).

### Private Hosts (git-sshripped)

Some host directories (e.g., `hosts/bs-mbpro/`) are encrypted via **[git-sshripped](https://github.com/BSteffaniak/git-sshripped)**, which uses SSH keys as recipients and Git filters for transparent encryption. On GitHub they appear as ciphertext. On machines whose SSH key is a recipient and that have run `git-sshripped unlock`, they are transparent. Encryption rules are defined in `.gitattributes`; recipient/key material lives in `.git-sshripped/`.

`meta.nix` files are intentionally excluded from encryption so host discovery works on machines without the key.

**Do not move host-private content out of an encrypted host directory into shared modules.** Refactoring within the directory is fine; anything that would put that content in plaintext elsewhere in the repo is not.

`git-sshripped` is built from source via `pkgs/source-builds/configs/git-sshripped.json` and is available in the repo dev shell (`nix develop` / direnv) and via `myConfig.cliTools.utilities.gitSshripped.enable`.

## Module Hierarchy

There are two module hierarchies with strictly separated responsibilities.

### 1. System Modules (`modules/`)

Location: `modules/common/`, `modules/nixos/`, `modules/darwin/`

These own things that require root or OS integration:

- Login shells (`myConfig.shell.{fish,bash,zsh,nushell}.enable`, `myConfig.shell.default`) — `/etc/shells`, default user shell
- Daemons and services (`myConfig.services.*`: sshd, tailscale, docker, avahi, observability, minecraft)
- Boot, hardware, networking, audio, locale, security (`modules/nixos/`)
- macOS system defaults, Homebrew casks, launchd daemons, Touch ID (`modules/darwin/`)

**Not available on standalone home-manager hosts** (e.g., ubuntu-laptop).

### 2. Home-Manager Modules (`home/modules/`)

Location: `home/modules/`, `home/common/`, plus platform bridges `home/nixos/`, `home/darwin/`, `home/standalone/`

These own **every user-facing tool and its configuration**: development toolchains, editors, CLI utilities, containers/devops CLIs, desktop apps and their configs, git/ssh client config, shell configuration.

**Advantages:**

- Portable across NixOS, nix-darwin, and standalone home-manager
- User-scoped, no root required
- Faster iteration than a full system rebuild

### Key Principle: user tools are declared once, in `home.nix`

There is exactly one place to enable a user tool: the host's `home.nix`. System modules do **not** re-declare user-tool options, and the platform bridges (`home/nixos`, `home/darwin`) mirror only genuinely system-owned settings into home-manager:

- `myConfig.shell.{default,fish,bash,zsh,nushell}` — so the login shell and the user shell config agree
- Hyprland/Waybar enablement (NixOS; compositor is installed at system level)
- Hex and Ghostty terminfo (Darwin; the apps are Homebrew casks)

```nix
# hosts/<host>/default.nix -- system only
myConfig = {
  shell.fish.enable = true;
  services.sshd.enable = true;
  darwin.homebrew.enable = true;
};

# hosts/<host>/home.nix -- everything the user touches
myConfig = {
  development.rust.enable = true;
  devops.kubernetes.enable = true;
  editors.neovim.enable = true;
  shell.git.enable = true;
  shell.ssh.enable = true;
};
```

## Configuration Options Pattern

All configurable features use the `myConfig.*` option namespace on both layers:

```nix
# Defining options (in module)
options.myConfig.tools.archiving.enable = lib.mkEnableOption "Archive tools (7-zip)";

# Using options (in host config)
myConfig.tools.archiving.enable = true;
```

Internal contribution points other modules write to are marked `internal = true`:

- `myConfig.shell.contrib.*` — aliases, functions, PATH entries, completion commands, init snippets contributed by modules. Host-facing `myConfig.shell.shared.*` overrides these on key collision.
- `myConfig.shell.resolved.*` — merged results (default shell path, merged aliases).

## Style

- No `with lib;`. Use `lib.` prefixes or `inherit (lib) …;`.
- Prefer precise option types (`attrsOf`, `submodule`, upstream types like `options.programs.ssh.matchBlocks.type`) over `types.attrs`, except for free-form JSON/TOML passthrough settings.
- Kebab-case file names; camelCase option names.
- Run `./fmt.sh` (nixfmt + prettier) before committing.

## Host Configuration Structure

Each host directory contains:

- `hosts/<hostname>/meta.nix` - **(required, plaintext)** identity and platform metadata
- `hosts/<hostname>/home.nix` - **(required)** user-level configuration
- `hosts/<hostname>/default.nix` - **(NixOS/nix-darwin only)** system-level configuration

**Metadata (`meta.nix`)**:

```nix
{
  type = "darwin";                  # "nixos" | "darwin" | "home-manager"
  system = "aarch64-darwin";
  hostname = "Bradens-MacBook-Air"; # As reported by `hostname`
  username = "braden";
  stateVersion = 6;                 # system.stateVersion (int on darwin, "24.11" string on NixOS)
  homeStateVersion = "24.11";       # home.stateVersion
  extraModules = [ "nix-minecraft" ]; # Optional; names resolved by lib/hosts.nix
}
```

**System config (`default.nix`)**: imports `modules/common` + the platform module directory, then sets only system-level `myConfig.*` flags plus anything host-specific (extra system packages, `networking.computerName`, user groups, fonts).

**Home config (`home.nix`)**: all user tools, editors, shell config, CLI utilities, desktop apps.

## Adding New Packages

1. **Determine scope**: root/daemon/OS integration → `modules/`; anything else → `home/modules/`.
2. **Create a feature flag**: `options.myConfig.<area>.<name>.enable = lib.mkEnableOption "…";`
3. **Enable it** in the relevant `home.nix` (or `default.nix` for system concerns).

### Adding a Homebrew cask (Darwin)

Add an entry to `simpleCasks` in `modules/darwin/casks.nix`. Casks that need extra config (launchd agents, defaults) get their own file using `lib/mk-cask-module.nix` — see `scroll-reverser.nix`.

### Adding Source-Built Packages

For packages built from Git source, use the auto-discovery source-build system. Simple Rust packages require only:

1. A flake input in `flake.nix` (`<name>-src`, `flake = false`)
2. `pkgs/source-builds/configs/<name>.json`:
   ```json
   {
     "flakeInput": "<name>-src",
     "buildSystem": "rust",
     "pname": "<name>",
     "hashField": "cargoHash"
   }
   ```
3. `nix flake lock && ./scripts/source-build.sh update <name>`
4. Use `pkgs.<name>`

`overlays/source-builds.nix` picks up configs automatically. Optional fields: `doCheck`, `cargoBuildFlags`, `nativeBuildInputs`, `buildInputs`, `rustToolchain` (`"stable"`/`"nightly"`), `env`, `postInstallFile`.

**Complex builds** set `"complex": true` and get a standalone file in `overlays/` (see `cronstrue.nix`, `sendsafely-java.nix`). Use `lib/locked-source.nix` for the flake.lock rev + stale-hash check.

### Overlays

`overlays/default.nix` returns the ordered overlay list; each file is `{ inputs }: final: prev: { … }`. Attribute _names_ in an overlay must not depend on `final` (use `prev.lib` for structural helpers) or evaluation recurses infinitely.

## Adding New Hosts

Run `./bootstrap.sh`, or manually create `hosts/<name>/{meta.nix,home.nix[,default.nix]}`. No other files need editing.

## Testing Changes

Always build before switching:

```bash
./rebuild.sh --diff          # build current host, diff against running system
./scripts/check-all-hosts.sh compare   # evaluate every host against a saved baseline
nix flake check              # same set of toplevels as a flake check
```

For refactors that should not change any host, save a baseline first (`./scripts/check-all-hosts.sh save`), make changes, then `compare`. Investigate any drift with `nix-diff`.

## Common Patterns

```nix
# Feature flag with a default that follows a group toggle
mkEnable = myLib.mkEnableOption' cfg.enableAll;
options.myConfig.cliTools.utilities.jq.enable = mkEnable "JSON processor";

# Conditional packages
home.packages = lib.optional cfg.encryption.enable pkgs.age;

# Platform-gated package
home.packages = lib.optional (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.csharp-ls) pkgs.csharp-ls;

# Unstable channel
home.packages = [ pkgs.unstable.some-package ];
```
