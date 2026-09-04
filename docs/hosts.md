# Hosts

Back to overview: `README.md`

This repository discovers hosts automatically from `hosts/*/meta.nix` (see `lib/hosts.nix`).

## Host Types

- `type = "nixos"`: full NixOS system + Home Manager
- `type = "darwin"`: nix-darwin system + Home Manager
- `type = "home-manager"`: standalone Home Manager only

## Host Directory Layout

Each host directory lives under `hosts/<hostname>/`.

- `meta.nix` (required, plaintext): identity and platform metadata
- `home.nix` (required): user-level configuration — every user tool is enabled here
- `default.nix` (NixOS/Darwin): system-level configuration — login shells, services, hardware, casks

`meta.nix` drives hostname, primary user, home directory, and both state versions, so `default.nix` no longer repeats them:

```nix
{
  type = "darwin";
  system = "aarch64-darwin";
  hostname = "Bradens-MacBook-Air";
  username = "braden";
  stateVersion = 6; # "24.11" on NixOS
  homeStateVersion = "24.11";
  # extraModules = [ "nix-minecraft" ];
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

## Private Hosts

Host directories can be encrypted with git-sshripped (see `.gitattributes`). Keep `meta.nix` plaintext so discovery works everywhere. Do not move private content out of an encrypted host directory.

## NixOS Hardware Detection

Before creating a NixOS host, you can inspect hardware support with:

```bash
./scripts/detect-hardware.sh
```

## Build Before Switching

```bash
./rebuild.sh --diff

# or manually
sudo nixos-rebuild build --flake .#<host>
darwin-rebuild build --flake .#<host>
home-manager build --flake .#<user>@<host>

# every host at once (evaluation only)
./scripts/check-all-hosts.sh eval
```
