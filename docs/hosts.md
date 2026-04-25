# Hosts

Back to overview: `README.md`

This repository discovers hosts automatically from `hosts/*/meta.nix`.

## Host Types

- `type = "nixos"`: full NixOS system + Home Manager
- `type = "darwin"`: nix-darwin system + Home Manager
- `type = "home-manager"`: standalone Home Manager only

## Host Directory Layout

Each host directory lives under `hosts/<hostname>/`.

- `meta.nix` (required): host metadata used for auto-discovery
- `home.nix` (required): user-level configuration
- `default.nix` (required for NixOS/Darwin): system-level configuration

Example metadata:

```nix
{
  type = "darwin";
  system = "aarch64-darwin";
  hostname = "Bradens-MacBook-Air";
  username = "braden";
}
```

## Add a New Host

Recommended:

```bash
./bootstrap.sh
```

Manual flow:

1. Create `hosts/<new-host>/`
2. Add `hosts/<new-host>/meta.nix`
3. Add `hosts/<new-host>/home.nix`
4. Add `hosts/<new-host>/default.nix` for NixOS/Darwin hosts

No flake edits are required for host registration.

## NixOS Hardware Detection

Before creating a NixOS host, you can inspect hardware support with:

```bash
./scripts/detect-hardware.sh
```

## Build Before Switching

```bash
# NixOS
sudo nixos-rebuild build --flake .#<host>

# Darwin
darwin-rebuild build --flake .#<host>

# Standalone Home Manager
home-manager build --flake .#<user>@<host>
```
