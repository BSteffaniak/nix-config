# Nix Configuration

Cross-platform Nix configuration for multiple machines, with a single flake and
a home-manager-first module layout.

This repo manages:

- NixOS systems (`nixosConfigurations`)
- macOS systems via nix-darwin (`darwinConfigurations`)
- standalone Home Manager hosts (`homeConfigurations`)

## At a Glance

- One root `flake.nix` and `flake.lock` for all platforms
- Host auto-discovery from `hosts/*/meta.nix`
- Shared user tooling via Home Manager (`home.packages`)
- Platform-specific system modules for NixOS and Darwin

## Quick Start

Use `rebuild.sh` for normal day-to-day rebuilds:

```bash
# Preview changes without applying
./rebuild.sh --diff

# Apply configuration for the current host
./rebuild.sh
```

Manual build commands:

```bash
# NixOS
sudo nixos-rebuild build --flake .#<host>

# Darwin
darwin-rebuild build --flake .#<host>

# Standalone Home Manager
home-manager build --flake .#<user>@<host>
```

## Managed Configuration Files

Managed Home Manager files and system `/etc` files receive a generated-file
warning when their format supports comments. The warning points to
`~/.config/nix` (expanded for the configured user) and directs all editors to
change the sources there, then run `./rebuild.sh` from that checkout.

Set `myConfig.generatedFiles.repositoryPath` in the home or system configuration
if the checkout lives elsewhere. Set `myConfig.generatedFiles.enable = false`
to disable notices for that layer, or set `generatedHeader = false` on an
individual `home.file` or `environment.etc` entry to opt out.
For XDG entries, set the opt-out on the corresponding `home.file` target.

Headers use the format's comment syntax and preserve shebangs and XML
declarations. Strict JSON, binary files, unrecognized formats, and mutable
out-of-store symlinks remain unchanged. The complete managed-target lists and
editing instructions are in `~/.config/nix-managed-files.txt` and
`/etc/nix/managed-files.txt`, including targets without inline warnings.
Files installed outside these file-management options are not rewritten.

## Repository Layout

```text
.
├── flake.nix / flake.lock      # Inputs + thin outputs
├── hosts/                      # Per-host configs (auto-discovered from meta.nix)
├── home/                       # Home Manager modules and platform bridges
├── modules/                    # System-level modules (common/NixOS/Darwin)
├── lib/                        # Host discovery, dev shell, pure helpers
├── overlays/                   # nixpkgs overlays (one file each)
├── pkgs/                       # Data for generated packages (source builds, releases, plugins)
├── scripts/                    # Operational helper scripts
└── configs/                    # Portable standalone dot-configs
```

## Documentation Index

General docs:

- `docs/hosts.md` - host model, adding hosts, bootstrap/manual setup
- `docs/packages-and-modules.md` - module hierarchy and package placement rules
- `docs/overlays.md` - GitHub release and source-built overlay workflows
- `docs/updating-and-maintenance.md` - rebuild/update/maintenance workflow

Detailed script docs:

- `scripts/README.md`

Standalone config docs:

- `configs/neovim/README.md`
- `configs/tmux/README.md`
- `configs/wezterm/README.md`

Agent and contributor guidance:

- `AGENTS.md`

## Design Principles

- Every user tool is declared once, in `hosts/<name>/home.nix`, on every platform
- Use system modules only for true system concerns (login shells, services, drivers, boot, casks)
- `meta.nix` is the single source of host identity
- Keep module logic reusable and host files declarative
- Refactors are verified with `scripts/check-all-hosts.sh` (zero-diff against a saved baseline)
