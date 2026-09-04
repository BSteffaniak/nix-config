# Nix Configuration

Cross-platform Nix configuration for multiple machines, with a single flake and a home-manager-first module layout.

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
